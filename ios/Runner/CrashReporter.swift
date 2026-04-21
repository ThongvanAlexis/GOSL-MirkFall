// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import Darwin
import Foundation

/// Best-effort native crash reporter for sideloaded iOS builds.
///
/// ## Why this exists
///
/// Sideloaded apps (SideStore / AltStore) are excluded from iOS
/// `ReportCrash`, so `.ips` files never land in Settings →
/// Privacy & Security → Analytics & Improvements → Analytics Data —
/// regardless of the "Share iPhone Analytics" toggle. Combined with the
/// fact that native crashes (SIGABRT, EXC_BAD_ACCESS, Objective-C
/// uncaught exceptions) kill the process before the Dart VM can flush
/// the FileLogger, every native crash historically left zero trace on
/// device.
///
/// This file installs two last-resort hooks BEFORE any Flutter /
/// MapLibre code runs:
///
/// 1. `NSSetUncaughtExceptionHandler` — catches Objective-C uncaught
///    exceptions (`NSException`). Empirically ~80% of MapLibre crashes
///    surface as `NSInternalInconsistencyException`,
///    `NSRangeException`, etc.
/// 2. POSIX signal handlers for SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGFPE,
///    SIGPIPE — catches the C / Metal / memory-corruption path. SIGABRT
///    also fires when an Objective-C exception is raised but the default
///    handler was re-raising it, so belt-and-braces.
///
/// Each hook appends a raw dump to `<AppSupport>/ios_crash.log` then
/// re-raises the signal (or re-throws the exception) so the OS still
/// tears the process down and the default kernel coredump / jetsam
/// accounting still applies.
///
/// On the next app launch, `IosCrashLogReader` (Dart side) reads the file,
/// emits it at SHOUT through `FileLogger`, and deletes it — so the crash
/// trail is visible in today's log and shareable via the debug menu's
/// existing "Partager les logs" flow. A dedicated "Voir dernier crash"
/// entry in the debug menu surfaces the file directly for quick sharing.
///
/// ## Async-signal-safety
///
/// The signal handler in [signalHandler] runs in signal-delivery context.
/// POSIX rules forbid calling into `malloc`, Foundation / Swift stdlib
/// allocations, `NSLog`, or any function that could take a lock a crashed
/// thread might already hold.
///
/// The code therefore relies exclusively on:
/// - `open(2)` / `write(2)` / `close(2)` — all async-signal-safe.
/// - `backtrace(3)` / `backtrace_symbols_fd(3)` — safe on Darwin for
///   signal context (Apple's `man 3 backtrace` says so explicitly).
/// - Pre-computed C strings stored in a fileprivate global at install-
///   time (no per-crash allocations).
///
/// Timestamp is written as a raw integer (seconds since epoch) via
/// `time(2)` — strftime would be unsafe (allocates). The Dart-side reader
/// prettifies it.
///
/// The NSException path runs in normal (non-signal) context, so it is
/// free to use Foundation APIs; it shares the same file-write target via
/// a `FileManager`-based append.
///
/// ## GOSL compliance
///
/// - Local file only (`<AppSupport>/ios_crash.log`). No network calls,
///   no SDK, no symbol uploads, no third-party service.
/// - Idempotent install: [install] guards with a file-scope flag so
///   double-registration from hot-restart scenarios is a no-op.

// MARK: - Fileprivate state

/// Deep-copied, NUL-terminated path to the crash log. Allocated once by
/// [CrashReporter.install], intentionally leaked for process lifetime —
/// the signal handler must not free it (free is not async-signal-safe).
///
/// File-scope so the top-level signal handler can read it without going
/// through a static class var (reading static class vars from a
/// `@convention(c)` context is fragile).
fileprivate var gCrashLogPath: UnsafePointer<CChar>?

/// Scratch buffer used by [writeInt64] / [writeHex] / [writeSignalName]
/// to format digits into a byte-array without heap allocation. Swift's
/// `[CChar](repeating:count:)` triggers a heap allocation on every call
/// (Array has no inline storage), which is NOT async-signal-safe. By
/// pre-allocating a single 64-byte buffer at install time and reusing it,
/// the formatting helpers stay purely stack-local.
///
/// Not thread-safe by design — signal delivery on Darwin is serialised
/// per-thread, and in the pathological case of two signals racing across
/// threads the worst outcome is slightly interleaved output bytes, which
/// is still more useful than zero output.
///
/// Sized to 64 bytes: enough for Int64 decimal (20 digits + sign = 21),
/// UInt64 hex (16 digits), or any signal name literal. Never freed.
fileprivate var gScratchBuffer: UnsafeMutablePointer<CChar>?
fileprivate let kScratchBufferSize = 64

/// Pre-allocated backtrace frame buffer — [backtrace(3)] fills this with
/// return addresses. Allocated once at install time to avoid the heap
/// allocation Array initialisation would do per-crash.
fileprivate var gBacktraceFrames: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
fileprivate let kMaxBacktraceFrames: Int32 = 128

/// Guard against double-install (hot restart, re-entrant
/// didFinishLaunchingWithOptions).
fileprivate var gInstalled = false

// MARK: - Public API

@objc class CrashReporter: NSObject {

    /// Installs the Objective-C uncaught-exception handler and the POSIX
    /// signal handlers.
    ///
    /// Must be called BEFORE `GeneratedPluginRegistrant.register(with:)`
    /// so any crash during plugin init is captured too.
    @objc static func install() {
        if gInstalled { return }
        gInstalled = true

        // Pre-compute the crash log file path as a C string and stash it
        // in [gCrashLogPath]. The signal handler must not call `URL.path`
        // / `String.withCString` — both may allocate. Doing the work
        // once at install time sidesteps async-signal-safety on the hot
        // path.
        let url = crashLogURL()
        url.path.withCString { src in
            let len = strlen(src)
            // +1 for the NUL terminator. `strcpy` copies the NUL too.
            let buf = UnsafeMutablePointer<CChar>.allocate(capacity: len + 1)
            strcpy(buf, src)
            gCrashLogPath = UnsafePointer(buf)
        }

        // Pre-allocate the scratch formatting buffer (see [gScratchBuffer]
        // doc) + the backtrace frame buffer. malloc is called exactly
        // twice here; the signal handler never allocates.
        gScratchBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: kScratchBufferSize)
        gBacktraceFrames = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: Int(kMaxBacktraceFrames))

        // Ensure the Application Support directory exists. `open(O_CREAT)`
        // in signal context creates the file, not the parent directory.
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                  withIntermediateDirectories: true)

        // Objective-C uncaught exceptions.
        NSSetUncaughtExceptionHandler(nsExceptionHandler)

        // POSIX signals that typically indicate a fatal crash. Tight set
        // — don't install on SIGTERM / SIGINT / SIGHUP, those are
        // legitimate lifecycle signals iOS or the debugger can send.
        //
        // SIGPIPE is included because an unhandled pipe write (e.g. the
        // Flutter engine socket closed mid-send) manifests as a
        // terminated process with no backtrace otherwise.
        let fatalSignals: [Int32] = [SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGFPE, SIGPIPE]
        for sig in fatalSignals {
            var action = sigaction()
            // SA_SIGINFO gives us siginfo_t (useful for the faulting
            // address on SEGV / BUS). The handler variant takes three
            // args.
            action.__sigaction_u.__sa_sigaction = signalHandler
            action.sa_flags = SA_SIGINFO
            sigemptyset(&action.sa_mask)
            sigaction(sig, &action, nil)
        }
    }

    /// Returns the URL of the crash log file. Public so the debug menu
    /// can read / share it.
    @objc static func crashLogPath() -> String {
        return crashLogURL().path
    }

    /// Resolves the Application Support directory and returns the crash
    /// log URL. Called once at install time, never from signal context.
    private static func crashLogURL() -> URL {
        // `.applicationSupportDirectory` mirrors what
        // `path_provider.getApplicationSupportDirectory()` exposes on the
        // Dart side — the reader resolves the SAME directory. On iOS
        // this path is not backed up to iCloud by default, matching the
        // POC privacy guarantees.
        if let dir = FileManager.default.urls(for: .applicationSupportDirectory,
                                               in: .userDomainMask).first {
            return dir.appendingPathComponent("ios_crash.log")
        }
        // Fallback — tmp is volatile but losing the file on reboot beats
        // crashing on a missing Application Support dir.
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ios_crash.log")
    }
}

// MARK: - Objective-C uncaught-exception handler

/// Top-level function (not a method) because `NSSetUncaughtExceptionHandler`
/// takes a C function pointer — Swift only exposes those for top-level
/// `@convention(c)` functions.
///
/// Runs in normal context (the exception has already propagated up; the
/// runtime has already decided we're about to die), so Foundation / Swift
/// stdlib are safe here.
private func nsExceptionHandler(exception: NSException) {
    var dump = "=== NSException ===\n"
    dump += "ts_epoch_seconds=\(Int(Date().timeIntervalSince1970))\n"
    dump += "name=\(exception.name.rawValue)\n"
    dump += "reason=\(exception.reason ?? "(nil)")\n"
    if let userInfo = exception.userInfo, !userInfo.isEmpty {
        dump += "userInfo=\(userInfo)\n"
    }
    dump += "callStackSymbols:\n"
    for frame in exception.callStackSymbols {
        dump += "  \(frame)\n"
    }
    dump += "===\n"

    appendToCrashLog(dump)
}

/// Appends [text] to the crash log via the normal (non-signal) Foundation
/// path. Used by the NSException handler.
private func appendToCrashLog(_ text: String) {
    let url = URL(fileURLWithPath: CrashReporter.crashLogPath())
    let data = text.data(using: .utf8) ?? Data()
    if FileManager.default.fileExists(atPath: url.path) {
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        }
    } else {
        try? data.write(to: url, options: .atomic)
    }
}

// MARK: - POSIX signal handler

/// Top-level signal handler. MUST be async-signal-safe — see the file
/// header for the exhaustive rules. If you modify this function, verify
/// every call against Apple's `man 2 sigaction` "Async-signal-safe
/// functions" list.
private func signalHandler(sig: Int32, info: UnsafeMutablePointer<siginfo_t>?, context: UnsafeMutableRawPointer?) {
    // Resolve the crash-log fd. `open(O_APPEND)` is async-signal-safe.
    guard let pathPtr = gCrashLogPath else {
        // No path installed — re-raise immediately so the OS can take
        // over. Can only happen if a signal arrives before `install`
        // finished setup (theoretically impossible in practice).
        reRaise(sig)
        return
    }

    // O_WRONLY | O_CREAT | O_APPEND. Mode 0644.
    let fd = open(pathPtr, O_WRONLY | O_CREAT | O_APPEND, 0o644)
    if fd < 0 {
        reRaise(sig)
        return
    }

    writeCString(fd, "=== POSIX signal ===\n")

    // Timestamp — `time(2)` returns seconds since epoch. Formatting it
    // as decimal without allocating a String: write digits via a stack
    // buffer.
    writeCString(fd, "ts_epoch_seconds=")
    writeInt64(fd, Int64(time(nil)))
    writeCString(fd, "\n")

    writeCString(fd, "signal=")
    writeInt64(fd, Int64(sig))
    writeCString(fd, " (")
    writeSignalName(fd, sig)
    writeCString(fd, ")\n")

    if let info = info {
        writeCString(fd, "si_code=")
        writeInt64(fd, Int64(info.pointee.si_code))
        writeCString(fd, "\n")
        // Faulting address — most useful for SIGSEGV / SIGBUS.
        writeCString(fd, "si_addr=0x")
        writeHex(fd, UInt64(UInt(bitPattern: info.pointee.si_addr)))
        writeCString(fd, "\n")
    }

    // Backtrace. `backtrace(3)` fills an array of return addresses;
    // `backtrace_symbols_fd(3)` writes human-readable (dladdr-resolved)
    // frames directly to a file descriptor. Both are documented as
    // signal-safe on Darwin (Apple `man 3 backtrace`). The frame buffer
    // is pre-allocated in `install` so no heap allocation happens here.
    writeCString(fd, "backtrace:\n")
    if let framesPtr = gBacktraceFrames {
        let captured = backtrace(framesPtr, kMaxBacktraceFrames)
        backtrace_symbols_fd(framesPtr, captured, fd)
    }

    writeCString(fd, "===\n")

    // fsync is safe; then close and re-raise. Re-raising gives the OS
    // the original termination semantics (coredump / jetsam accounting).
    fsync(fd)
    close(fd)

    reRaise(sig)
}

// MARK: - Async-signal-safe write helpers

/// Re-raises [sig] with the default handler so the OS takes over. The
/// standard incantation is `signal(sig, SIG_DFL); raise(sig);`.
private func reRaise(_ sig: Int32) {
    signal(sig, SIG_DFL)
    raise(sig)
}

/// Writes a NUL-terminated C string to [fd]. Async-signal-safe.
private func writeCString(_ fd: Int32, _ str: StaticString) {
    str.withUTF8Buffer { buf in
        _ = write(fd, buf.baseAddress, buf.count)
    }
}

/// Writes a signed int64 as decimal to [fd] without using String or
/// allocating. Handles negative numbers and zero. Async-signal-safe —
/// uses the pre-allocated [gScratchBuffer].
private func writeInt64(_ fd: Int32, _ value: Int64) {
    guard let buf = gScratchBuffer else { return }
    // Max Int64 is 19 digits plus sign = 20 chars — fits easily in 64.
    var idx = kScratchBufferSize
    let negative = value < 0
    // Work in unsigned to sidestep overflow at Int64.min.
    var uv: UInt64 = negative ? UInt64(bitPattern: ~value &+ 1) : UInt64(value)
    repeat {
        idx -= 1
        buf[idx] = CChar(UInt8(uv % 10) + UInt8(ascii: "0"))
        uv /= 10
    } while uv != 0
    if negative {
        idx -= 1
        buf[idx] = CChar(UInt8(ascii: "-"))
    }
    _ = write(fd, buf.advanced(by: idx), kScratchBufferSize - idx)
}

/// Writes an unsigned int64 as lowercase hex (no `0x` prefix) to [fd].
/// Async-signal-safe — uses the pre-allocated [gScratchBuffer].
private func writeHex(_ fd: Int32, _ value: UInt64) {
    guard let buf = gScratchBuffer else { return }
    var idx = kScratchBufferSize
    var uv = value
    if uv == 0 {
        idx -= 1
        buf[idx] = CChar(UInt8(ascii: "0"))
    } else {
        repeat {
            idx -= 1
            let nibble = UInt8(uv & 0xF)
            buf[idx] = nibble < 10
                ? CChar(nibble + UInt8(ascii: "0"))
                : CChar(nibble - 10 + UInt8(ascii: "a"))
            uv >>= 4
        } while uv != 0
    }
    _ = write(fd, buf.advanced(by: idx), kScratchBufferSize - idx)
}

/// Writes a short name for [sig] (e.g. "SIGABRT"). Async-signal-safe.
private func writeSignalName(_ fd: Int32, _ sig: Int32) {
    switch sig {
    case SIGABRT: writeCString(fd, "SIGABRT")
    case SIGSEGV: writeCString(fd, "SIGSEGV")
    case SIGBUS:  writeCString(fd, "SIGBUS")
    case SIGILL:  writeCString(fd, "SIGILL")
    case SIGFPE:  writeCString(fd, "SIGFPE")
    case SIGPIPE: writeCString(fd, "SIGPIPE")
    default:      writeCString(fd, "UNKNOWN")
    }
}

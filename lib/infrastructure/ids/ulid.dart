// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:math';

/// Hand-rolled ULID generator (Crockford base32, zero dep).
///
/// 26-char identifiers split into:
/// - First 10 chars: 48 bits of UTC milliseconds (k-sortable — later
///   timestamp produces a lexically greater string).
/// - Last 16 chars: 80 bits of randomness (collision-resistant; for two
///   IDs minted in the same millisecond, the chance of collision is
///   2^-80 ≈ 10^-24).
///
/// Alphabet excludes `I`, `L`, `O`, `U` so a copy-pasted ID is never
/// ambiguous (`O`/`0`, `I`/`1`) — ULID spec Crockford convention.
///
/// Reference: https://github.com/ulid/spec
class Ulid {
  // Static-only namespace; instantiation has no meaning.
  Ulid._();

  /// Crockford base32 alphabet — 32 chars, no `I`, `L`, `O`, `U`.
  static const String _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  /// Number of chars used to encode the 48-bit timestamp.
  static const int _timeChars = 10;

  /// Number of chars used to encode the 80-bit random tail.
  static const int _randomChars = 16;

  /// Number of random bytes consumed per ULID — 80 bits = 10 bytes.
  ///
  /// 16 base32 chars × 5 bits/char = 80 bits = 10 bytes; we pack the 10
  /// random bytes into 16 chars (the spec allocates the full 16 chars
  /// even though only 80 bits of entropy are present — bit 0 of the
  /// first random char carries no information and is always 0).
  static const int _randomBytes = 10;

  /// Returns a 26-char ULID built from [now]'s UTC millisecond value
  /// and 80 bits of randomness drawn from [rng].
  static String generate({required DateTime now, required Random rng}) {
    final timestampMs = now.toUtc().millisecondsSinceEpoch;
    final timePart = _encodeTime(timestampMs);
    final randomPart = _encodeRandom(rng);
    return timePart + randomPart;
  }

  /// Encodes [ms] (treated as a 48-bit unsigned integer) into [_timeChars]
  /// base32 chars, most-significant char first — preserves k-sortability.
  static String _encodeTime(int ms) {
    final buffer = StringBuffer();
    for (var i = _timeChars - 1; i >= 0; i--) {
      final shift = i * 5;
      final index = (ms >> shift) & 0x1F;
      buffer.write(_alphabet[index]);
    }
    return buffer.toString();
  }

  /// Pulls [_randomBytes] bytes from [rng] and packs them into [_randomChars]
  /// base32 chars (bit-streaming — accumulate 8 bits per byte, emit 5 bits
  /// per char, pad the trailing partial group).
  static String _encodeRandom(Random rng) {
    final bytes = List<int>.generate(_randomBytes, (_) => rng.nextInt(256));
    final buffer = StringBuffer();
    var accumulator = 0;
    var accumulatedBits = 0;
    for (final byte in bytes) {
      accumulator = (accumulator << 8) | byte;
      accumulatedBits += 8;
      while (accumulatedBits >= 5) {
        accumulatedBits -= 5;
        buffer.write(_alphabet[(accumulator >> accumulatedBits) & 0x1F]);
      }
    }
    if (accumulatedBits > 0) {
      // Drain the trailing partial group by left-shifting to fill 5 bits.
      buffer.write(_alphabet[(accumulator << (5 - accumulatedBits)) & 0x1F]);
    }
    // 80 bits / 5 = 16 chars exactly — no padding loop needed in steady state,
    // but defend against future entropy-tuning by padding/truncating to fit.
    final encoded = buffer.toString();
    if (encoded.length == _randomChars) return encoded;
    if (encoded.length < _randomChars) {
      return encoded.padRight(_randomChars, _alphabet[0]);
    }
    return encoded.substring(0, _randomChars);
  }
}

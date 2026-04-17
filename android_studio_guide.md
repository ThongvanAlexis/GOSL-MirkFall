# Android Studio — Setup guide pour MirkFall

Guide d'onboarding pour configurer Android Studio comme IDE principal de développement MirkFall sur Windows.

Projet configuré avec `minSdk 24` (Android 7.0+), `compileSdk` et `targetSdk` délégués à Flutter.

---

## Pré-requis

- Flutter 3.41.x installé (vérifier avec `flutter --version`)
- Android Studio téléchargé depuis https://developer.android.com/studio
- Windows 10/11 64-bit, ~10 GB d'espace disque libre (SDK + émulateur + system image)

---

## Phase A — Premier lancement (Setup Wizard)

Au premier lancement d'Android Studio :

1. **Import settings?** → "Do not import settings"
2. **Welcome screen** → choisir **"Standard"** installation (pas Custom — Standard télécharge tout ce qu'il faut)
3. **Theme** → Darcula/Dark recommandé (au choix)
4. **Verify Settings** → Next
5. **License Agreement** → accepter les ~3 licences (Android SDK, SDK Build Tools, etc.) une par une → "Accept" + Finish
6. **Download en cours** (~3-5 GB) — platform-tools, SDK API 34, emulator, system images. 10-30 min selon connexion.

Quand c'est fini, tu arrives sur l'écran "Welcome to Android Studio".

---

## Phase B — Plugin Flutter

1. Welcome screen → **⚙ (Customize)** en bas gauche → **"All settings..."**
   (ou si projet déjà ouvert : **File → Settings**)
2. **Plugins** (colonne gauche)
3. Onglet **Marketplace**
4. Chercher **"Flutter"** → Install
5. Il propose d'installer aussi **Dart** → Accept
6. **Restart IDE** (bouton apparaît en bas)

---

## Phase C — Pointer vers le Flutter SDK existant

**Important** : ne pas laisser AS télécharger un deuxième Flutter SDK. Utiliser celui déjà installé.

1. **File → Settings** (ou ⚙)
2. **Languages & Frameworks → Flutter**
3. **Flutter SDK path** → naviguer vers l'install existant. Pour trouver le chemin :
   ```powershell
   where.exe flutter
   ```
   En général `C:\flutter`, `C:\src\flutter` ou `%LOCALAPPDATA%\flutter`. Sélectionner le **dossier parent de `bin/`** (ex. `C:\flutter`, pas `C:\flutter\bin`).
4. "Flutter 3.41.x • channel stable" s'affiche en dessous → Apply → OK

---

## Phase D — Ouvrir le projet

1. Welcome screen → **Open**
2. Naviguer vers le dossier racine `GOSL-MirkFall`
3. Sélectionner le **dossier** (pas un fichier) → OK
4. Dialog "Trust project?" → **Trust Project**
5. Android Studio détecte le projet Flutter et lance Gradle sync automatiquement

**Premier Gradle sync : 5-15 min** (télécharge Gradle wrapper, dépendances AndroidX, etc.). Regarder la bottom bar pour la progression.

Si Gradle sync échoue avec une erreur SDK licenses :
```powershell
flutter doctor --android-licenses
```
Accepter tout (taper `y` à chaque prompt).

---

## Phase E — Configurer code style (convention projet)

Le projet utilise **160 caractères** par ligne (CLAUDE.md §Longueur de ligne), pas le défaut Dart de 80.

1. **File → Settings**
2. **Editor → Code Style → Dart**
3. **Line length** → `160`
4. Apply → OK

---

## Phase F — Créer un émulateur (AVD)

1. **Tools → Device Manager** (menu ou panneau droit de l'IDE)
2. Clic **"+ Create Device"** (ou "Create virtual device")
3. **Category: Phone** → choisir **Pixel 7** ou **Pixel 8** (moderne, bonne résolution) → Next
4. **System Image** :
   - Onglet **Recommended**
   - Ligne **UpsideDownCake (API 34)** ou plus récent
   - ABI : **x86_64** (Windows x64)
   - Clic **Download** si pas encore téléchargé (~1.5 GB)
   - Une fois téléchargé → Next
5. **Verify configuration** :
   - AVD Name : garde le défaut ou "Pixel 7 API 34"
   - Startup orientation : Portrait
   - **Advanced Settings** (facultatif) : RAM 2048 MB, VM heap 256 MB (défauts OK)
6. Finish → l'AVD apparaît dans Device Manager

**Launch l'émulateur** : clic le bouton ▶ à côté de l'AVD dans Device Manager. Premier boot : 1-3 min.

---

## Phase G — Vérifier que tout est câblé

Dans le terminal PowerShell :
```powershell
flutter doctor -v
```

Attendu :
```
[✓] Flutter
[✓] Windows Version
[✓] Android toolchain
[✓] Chrome
[✓] Visual Studio
[✓] Android Studio
[✓] Connected device (4 available — inclut ton AVD)
[✓] Network resources
```

Si Android toolchain a encore un ✗ :
```powershell
flutter doctor --android-licenses
flutter config --android-sdk "C:\Users\<user>\AppData\Local\Android\Sdk"
```
Le chemin exact est visible dans AS : **Settings → Languages & Frameworks → Android SDK → Android SDK Location**.

---

## Phase H — Run l'app sur l'émulateur

Avec l'AVD lancé (téléphone visible à l'écran) :

**Via IDE** :
1. Dropdown device en haut à droite → sélectionner l'AVD
2. Bouton ▶ Run (Shift+F10)

**Via CLI** :
```powershell
flutter run -d <device-id>
# ou simplement, si un seul AVD lancé :
flutter run
```

L'app MirkFall doit boot avec le texte "MirkFall — bootstrap OK" + logger JSONL actif + 7-tap sur `/about` → debug menu.

---

## Setup complémentaire — Build Windows desktop

Pour `flutter run -d windows` (recommandé CLAUDE.md §Plateformes), il faut des composants Visual Studio supplémentaires :

1. Activer **Developer Mode** Windows :
   ```powershell
   start ms-settings:developers
   # toggle "Developer Mode" → On, redémarrer PowerShell
   ```

2. Installer le composant **ATL** via Visual Studio Installer :
   - Ouvrir Visual Studio Installer
   - Modify sur "Visual Studio Build Tools 2022"
   - Onglet **Individual components** → rechercher "ATL"
   - Cocher ✅ **C++ ATL for latest v143 build tools (x86 & x64)**
   - Modify → installer (~500 MB)

Requis par `flutter_local_notifications_windows` (include `atlbase.h`).

---

## Troubleshooting

| Problème | Fix |
|----------|-----|
| Gradle sync "Could not resolve dependencies" | `flutter clean && flutter pub get` puis Gradle Sync dans IDE |
| Émulateur "hardware acceleration not available" | Activer **Hyper-V** ou **Hypervisor Platform** dans Windows Features (redémarrage requis) |
| "ANDROID_HOME not set" | Settings → Build Tools → Gradle → Gradle JDK = JDK 17 (AS en fournit un). Et `flutter config --android-sdk <path>` |
| Flutter plugin bouton Run grisé | Ouvrir `pubspec.yaml` au moins une fois pour qu'AS parse le projet Flutter |
| `flutter run -d windows` : symlink error | Developer Mode pas activé — cf. section "Build Windows desktop" |
| `flutter run -d windows` : `atlbase.h` not found | ATL pas installé — cf. section "Build Windows desktop" |

---

## Notes version

- Guide rédigé pour Flutter 3.41.x + Android Studio 2024.x
- `minSdk 24` (Android 7.0 Nougat, choisi par Plan 01-01 pour couvrir 96%+ des devices actifs tout en gardant les API `java.time` sans backport)
- Projet testé sur Windows 10 64-bit (Build Tools 2022 17.12.3)

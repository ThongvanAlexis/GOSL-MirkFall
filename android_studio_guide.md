# Android Studio — Setup guide pour MirkFall

Guide d'onboarding pour configurer Android Studio comme IDE principal de développement MirkFall sur Windows.

Projet configuré avec `minSdk 24` (Android 7.0+), `compileSdk` et `targetSdk` délégués à Flutter (~35).

**Ordre des phases** : A → B → **D → C** (oui, D avant C — cf. Phase C) → E → F → G → H.

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

**Depuis le Welcome screen** (projet pas encore ouvert) :

1. Dans la **barre latérale gauche** du Welcome screen :
   ```
   Projects
   Customize
   Plugins      ← clic ici
   Learn
   ```
2. Onglet **Marketplace** en haut
3. Recherche **"Flutter"** → Install
4. AS propose d'installer aussi **Dart** → Accept
5. **Restart IDE** (bouton apparaît en bas)

> Note : ne pas passer par la roue crantée ⚙ en bas gauche → Settings. Sur AS récent, ce Settings est un sous-ensemble réduit qui ne montre pas les plugins ni Languages & Frameworks. Passer directement par la sidebar **Plugins**.

**Alternative si sidebar absente** (rare, config corporate ou UI custom) :
- Télécharger le plugin depuis https://plugins.jetbrains.com/plugin/9212-flutter
- Settings → Plugins → icône ⚙ en haut → "Install Plugin from Disk..." → sélectionner le `.zip`

---

## Phase D — Ouvrir le projet (AVANT Phase C)

Il faut ouvrir le projet avant Phase C parce que **Languages & Frameworks → Flutter** n'apparaît pas dans Settings du Welcome screen ; seulement une fois un projet ouvert.

1. Welcome screen → **Open**
2. Naviguer vers le dossier racine `GOSL-MirkFall`
3. Sélectionner le **dossier** (pas un fichier) → OK
4. Dialog "Trust project?" → **Trust Project**

**Note importante sur Gradle** : contrairement à un projet Android natif, Android Studio en mode Flutter **ne lance pas Gradle sync automatiquement** à l'ouverture. Gradle ne se réveille qu'au premier `flutter run` vers Android (ou si tu modifies `android/app/build.gradle.kts`). C'est normal. Pas la peine de chercher "File → Sync Project with Gradle Files", il n'existe pas dans ce mode.

Si tu veux forcer un sync pour tester tout de suite, ouvre le terminal intégré (**View → Tool Windows → Terminal**) et lance :
```powershell
flutter pub get
```

---

## Phase C — Vérifier/configurer le Flutter SDK

**Important** : ne pas laisser AS télécharger un deuxième Flutter SDK. Utiliser celui déjà installé.

Sur AS récent avec le plugin Flutter installé, le SDK est souvent **auto-détecté** à l'ouverture du projet. Pour vérifier :

1. **File → Settings** (raccourci `Ctrl+Alt+S` une fois le projet ouvert)
2. **Languages & Frameworks → Flutter**
3. **Flutter SDK path** → doit pointer vers ton install (ex. `C:\flutter`)
   - Si vide : clic folder → sélectionner le **dossier parent de `bin/`**. Trouve le chemin avec :
     ```powershell
     where.exe flutter
     ```
4. "Flutter 3.41.x • channel stable" doit s'afficher en dessous → Apply → OK

---

## Phase E — Configurer code style (convention projet)

Le projet utilise **160 caractères** par ligne (CLAUDE.md §Longueur de ligne), pas le défaut Dart de 80.

1. **File → Settings**
2. **Editor → Code Style → Dart**
3. **Line length** → `160`
4. Apply → OK

---

## Phase F — Créer un émulateur (AVD)

**Stratégie** : matcher l'émulateur au device physique de test. Tu as un Pixel 4a réel → émule un Pixel 4a.

1. **Tools → Device Manager** (menu, ou panneau droit de l'IDE)
2. Clic **"+ Create Device"** (ou "Create virtual device")
3. **Category: Phone** → choisir le device matching ton hardware réel (ex. **Pixel 4a**) → Next
4. **System Image** :
   - Onglet **Recommended**
   - Pick l'**API level matching ton device réel** :
     - Pixel 4a : **API 33 (Android 13)** — dernière version officielle
     - Pixel 7 / 8 : API 34 ou 35 selon updates reçues
     - Sinon : Settings → About phone sur ton device réel pour voir la version
   - ABI : **x86_64** (Windows x64)
   - Clic **Download** si pas encore téléchargé (~1.5 GB)
   - Une fois téléchargé → Next
5. **Verify configuration** :
   - AVD Name : par défaut ou explicite (ex. "Pixel 4a API 33")
   - Startup orientation : Portrait
   - **Advanced Settings** (facultatif) : RAM 2048 MB, VM heap 256 MB (défauts OK)
6. Finish → l'AVD apparaît dans Device Manager

**Launch l'émulateur** : bouton ▶ à côté de l'AVD dans Device Manager. Premier boot : 1-3 min.

### SDK compatibility quick-ref

| Setting | Valeur projet | Rôle |
|---------|---------------|------|
| `minSdk` | **24** (Android 7.0) | Version **minimum** pour installer l'app. Device < 24 → incompatible |
| `compileSdk` | ~35 (délégué Flutter) | Version contre laquelle le code est **compilé**. Définit les APIs utilisables |
| `targetSdk` | ~35 (délégué Flutter) | Version que l'app **déclare** cibler (runtime behaviors, permissions) |

Tant que ton device (émulateur ou physique) tourne Android 7.0+ (API 24+), il peut run MirkFall. Un Pixel 4a ship en Android 10 (API 29) et update jusqu'à Android 13 (API 33) — 100% compatible.

Tu peux créer plusieurs AVDs (ex. un API 33 pour matcher le Pixel 4a réel, un API 35 pour valider sur Android neuf).

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

Le premier `flutter run -d android` déclenche Gradle sync (5-10 min la première fois). L'app MirkFall doit boot avec le texte "MirkFall — bootstrap OK" + logger JSONL actif + 7-tap sur `/about` → debug menu.

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

3. Ajouter la plateforme Windows au projet Flutter (une fois, si pas déjà fait) :
   ```powershell
   flutter create --platforms=windows .
   ```

Requis par `flutter_local_notifications_windows` (include `atlbase.h`).

---

## Troubleshooting

| Problème | Fix |
|----------|-----|
| Welcome screen Settings sans "Languages & Frameworks" ni "Plugins" | Normal — scope réduit. Passer par Plugins dans la sidebar Welcome, ou ouvrir le projet d'abord |
| Pas de "Sync Project with Gradle Files" dans File menu | Normal en mode Flutter. Gradle se syncera au premier `flutter run -d android` |
| Gradle JDK absent de Settings → Build Tools → Gradle | Pas encore de module Gradle monté (avant premier build Android). Ignorer tant que Phase H n'échoue pas dessus |
| Gradle sync "Could not resolve dependencies" (au build) | `flutter clean && flutter pub get` puis retry |
| Émulateur "hardware acceleration not available" | Activer **Hyper-V** ou **Hypervisor Platform** dans Windows Features (redémarrage requis) |
| "ANDROID_HOME not set" au premier build | `flutter config --android-sdk <path-visible-dans-AS-SDK-Manager>` |
| Flutter plugin bouton Run grisé | Ouvrir `pubspec.yaml` au moins une fois pour qu'AS parse le projet Flutter |
| `flutter run -d windows` : symlink error | Developer Mode pas activé — cf. section "Build Windows desktop" |
| `flutter run -d windows` : `atlbase.h` not found | ATL pas installé — cf. section "Build Windows desktop" |
| `flutter run -d windows` : "No Windows desktop project configured" | Lancer `flutter create --platforms=windows .` une fois |

---

## Notes version

- Guide rédigé pour Flutter 3.41.x + Android Studio 2024.x (UI "New UI")
- `minSdk 24` (Android 7.0 Nougat, choisi par Plan 01-01 pour couvrir 96%+ des devices actifs tout en gardant les API `java.time` sans backport)
- Projet testé sur Windows 10 64-bit (Build Tools 2022 17.12.3)
- Device physique cible pour dev : Pixel 4a (Android 13 / API 33)

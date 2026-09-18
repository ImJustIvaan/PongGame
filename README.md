# 🏓 Pong Game

A high-performance, cross-platform Pong arcade game built with **Flutter**. Designed for **Android**, **iOS**, **Windows**, **macOS**, and **Web** with automated **GitHub Actions CI/CD**.

---

## ✨ Features

- 🎮 **Multiple Game Modes**:
  - **1 Player vs AI**: 4 smart AI difficulty levels (`Easy`, `Medium`, `Hard`, `Cyber Pro`).
  - **2 Players (Local)**: Touch split-screen on mobile or dual keyboard (`W/S` vs `Up/Down`) on desktop/web.
  - **Practice Rally**: Solo rebound wall with continuous streak tracking.
  - **Attract Mode**: Background demo AI vs AI playing in the main menu!
- 🎨 **Visual Themes**:
  - *Cyber Neon* (Glow effects, Cyan & Magenta paddles)
  - *Retro CRT* (1972 phosphor arcade look with scanlines)
  - *Synthwave* (Vibrant 80s sunset palette)
  - *Monochrome* (Minimalist modern high contrast)
- ⚡ **Physical Simulation**:
  - Paddle impact angle reflection (edges deflect sharper).
  - Progressive rally acceleration (speeds up with each hit!).
  - Particle sparks on paddle collisions and goal explosions.
  - Screen shake on heavy hits.
  - Haptic feedback & sound effects.
- 💾 **Persistent Stats**: Saves high scores, longest rally, selected theme, and difficulty via local storage.

---

## 🚀 Controls

| Platform | Player 1 | Player 2 | Extra Controls |
| :--- | :--- | :--- | :--- |
| **Mobile (Android / iOS)** | Touch/Drag Left Half | Touch/Drag Right Half | Tap to serve |
| **Desktop / Web** | `W` (Up) / `S` (Down) | `↑` (Up) / `↓` (Down) | `Space` to Pause / Serve, `Esc` to Exit |

---

## 🛠️ Running Locally

### 1. Test in Web / Chrome
```bash
flutter run -d chrome
```

### 2. Run on Connected Android Device or Emulator
```bash
flutter run -d android
```

### 3. Run on Connected iOS Device or Simulator
```bash
flutter run -d ios
```

### 4. Run on Windows Desktop
```bash
flutter run -d windows
```

---

## 🤖 GitHub Actions CI/CD

The repository includes a battle-tested GitHub Actions workflow in `.github/workflows/build.yml`.

Whenever you push to `main` or trigger a manual dispatch:
1. **Tests & Lints**: Automatically verifies code formatting, analysis, and unit test pass.
2. **Android**: Builds `app-release.apk` and uploads it to GitHub Actions artifacts for instant download.
3. **iOS**: Archives the iOS release package ready for TestFlight or export.
4. **Web**: Compiles an optimized Web build ready to host on GitHub Pages.
5. **Windows**: Compiles native Windows 64-bit `.exe` release bundle.

### How to use GitHub Actions:
1. Initialize git in this directory:
   ```bash
   git init
   git add .
   git commit -m "feat: initial Pong Game release"
   ```
2. Create a new repository on [GitHub](https://github.com/new).
3. Push your code:
   ```bash
   git remote add origin https://github.com/YOUR_USERNAME/pong-game.git
   git branch -M main
   git push -u origin main
   ```
4. Click on the **Actions** tab in your GitHub repository:
   - You will see the build pipeline running.
   - Once completed, download the **PongGame-Android-Release** artifact to get your `.apk`!

---

## 📦 Project Structure

```
pong_game/
├── .github/
│   └── workflows/
│       └── build.yml             # GitHub Actions CI/CD
├── lib/
│   ├── game/
│   │   ├── game_theme.dart       # Theme definitions (Neon, CRT, etc.)
│   │   └── pong_engine.dart      # Pure Dart physics & AI engine
│   ├── screens/
│   │   ├── game_screen.dart      # Game loop, HUD & gesture handling
│   │   └── main_menu_screen.dart # Arcade menu with attract mode
│   ├── services/
│   │   ├── sound_service.dart    # Haptic and audio cues
│   │   └── storage_service.dart  # High score & settings persistence
│   ├── widgets/
│   │   └── pong_canvas.dart      # Hardware-accelerated 60/120fps CustomPainter
│   └── main.dart                 # App bootstrap
└── test/
    └── pong_engine_test.dart     # Engine unit tests
```

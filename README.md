# Lavawake Rush

Control a living lava flow, absorb your enemies and rush through the volcanic
world before the mountain reclaims you.

## The game

- **Rush runs** — steer the flow through collapsing volcanic terrain, dodge
  obstacles and swallow everything softer than you are.
- **Campaign** — a map of chapters, each with a brief, a target and its own
  hazards.
- **Growth** — spend what you absorb on upgrades, perks and forge recipes; the
  flow changes shape as it grows.
- **Collection** — skins, a bestiary of everything you have devoured, quests,
  achievements and statistics.
- **Profile** — pick an avatar from the camera or the gallery; the picture
  never leaves the device.

## Building

Requires the Flutter SDK and, for iOS, Xcode 15 or newer.

```bash
flutter pub get
cd ios && pod install && cd ..
flutter run
```

Open `ios/Runner.xcworkspace` in Xcode — never `Runner.xcodeproj`, which does
not know about the pods.

## Layout

| Path | Contents |
|---|---|
| `lib/game/` | run engine, painter and sprite cache |
| `lib/screens/` | every screen, from the loader to the results card |
| `lib/state/` | save file, settings, audio and progression |
| `lib/data/` | levels, enemies, skins, perks and the asset catalogue |
| `lib/core/` | theme, palette and shared widgets |

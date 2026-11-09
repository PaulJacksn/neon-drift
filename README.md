# Neon Drift

A polished 3D neon tunnel-runner mobile game built with Godot 4.7 (GDScript).
Pilot a hover-ship through an endless synthwave tunnel: one-finger drag to
steer, dodge barriers, thread the glowing rings, chase near-miss bonuses.

## Play

Live build (GitHub Pages): https://pauljacksn.github.io/neon-drift/

- Tap to start. Drag to steer. Fly through rings for points, near misses
  pay +50. Crash ends the run; best score is saved.
- Audio starts after the first tap (mobile autoplay policy): procedural
  synthwave loop plus gate chimes, near-miss whooshes and a crash thud,
  all synthesized in code.

## Project

- Engine: Godot 4.7.2 stable, GL Compatibility renderer (web).
- Source lives in this repo on `main`. The playable web export is on the
  `gh-pages` branch (single-threaded build, so it runs without COOP/COEP
  headers).
- `verify/` holds Playwright probe screenshots from each verification pass.

## Build locally

1. Open the project with Godot 4.7.2.
2. Export with the `Web` preset (single-threaded) to `../neon-drift-web/`.
3. Serve the export over HTTP and open `index.html`.

Android APK export is a later step (needs Android SDK + keystore).

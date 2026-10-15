# Zayn's Letter Adventure

An offline typing and alphabet game for a 4-year-old, as one HTML file plus an optional
full-screen Mac app.

- `mac-app/` — the game page (`Zayn-Letter-Adventure.html`) and a small Swift wrapper that
  shows it full screen with the Dock, menu bar and Command-key shortcuts blocked.
  `bash mac-app/build.sh` builds it on a Mac.
- `.github/workflows/mac-app.yml` — builds the same app on GitHub (Apple chip + Intel) and
  attaches `Zayn-Letter-Adventure-Mac.zip` to the run.

Grown-ups: hold the gear for 2 seconds for settings; quit with Control + Option + Command + Q.

# Release builds

Preserve the existing Star Trek / LCARS styling and orange, purple, and dark
palette in the app and overlay. The game overlay displays only detected ore names
near the top center; keep waiting, setup, and error messages inside the app.

The user wants only the most current Windows app executable in `dist` after every
update. Always use the stable name `Ops Helper.exe`. Use
`launcher/Build-Windows.ps1`, which removes older ORE-OPS executable releases and
unfinished build files only after installing a successful new build. Do not
delete source, data, assets, or macOS releases as part of this cleanup. If a running
app locks an old executable, report that remaining file rather than stopping the
user's app or claiming cleanup succeeded.

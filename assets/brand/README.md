# MoneyFlow identity

The coin above an open savings pocket represents setting money aside. Green and charcoal match the app, with no lettering or fine detail to lose at launcher sizes.

- `moneyflow-master.png`: source artwork at its original resolution.
- `play-store-icon.png`: 512px store artwork.
- `windows-256.png`: source for the Windows ICO container.
- `../../tool/export-brand-icons.ps1`: repeatable platform size exports (Windows System.Drawing).

Android adaptive/themed icons use the matching vector coin/pocket silhouette in `android/app/src/main/res/drawable/ic_launcher_foreground.xml`. Both normal and round adaptive resources reference it. The charcoal background fills the launcher mask; the foreground remains inside the safe central region.

Raster icons serve Android legacy launchers, iOS, macOS, web and Windows. Android packaging is checked; other native platforms require their own build/device validation. Launchers may cache an older icon until the app is updated or the launcher refreshes.

# QuickSnip

**Text expansion that just works.** Type a short abbreviation anywhere on your Mac and get the full text instantly — in any app, with no subscription, no account, and no cloud.

[**→ Download**](https://github.com/jbnash/quicksnip/releases/latest/download/QuickSnip.zip) · [Landing page](https://jbnash.github.io/quicksnip)

---

## Features

- **Instant** — fires the moment you finish typing, no delimiter needed
- **Offline** — everything runs locally, your snippets never leave your Mac
- **Date/time macros** — `%B %e, %Y` → `April 8, 2026`
- **Rich text** — formatted snippets paste with their formatting intact
- **Searchable library** — browse and double-click to paste anywhere
- **Free forever** — no trial, no tier, no upgrade prompt

## Install

1. [Download QuickSnip.zip](https://github.com/jbnash/quicksnip/releases/latest/download/QuickSnip.zip)
2. Unzip and move `QuickSnip.app` to your `/Applications` folder
3. Right-click → **Open** (first launch only — bypasses Gatekeeper for unsigned apps)
4. **System Settings → Privacy & Security → Accessibility** → add QuickSnip → toggle ON
5. Click ⚡ in the menu bar → **Restart Monitoring**

## Migrating from TextExpander

Click **⚡ → Load Backup File…** and point it at your `.textexpbackup` file. Every snippet comes right over — no conversion needed.

## Building from source

Requires macOS 13+, Swift (Xcode Command Line Tools).

```bash
git clone https://github.com/jbnash/quicksnip.git
cd quicksnip
bash build.sh
cp -r QuickSnip.app /Applications/
```

## Date & time codes

| Code | Output |
|------|--------|
| `%B %e, %Y` | April 8, 2026 |
| `%1I:%M %p` | 2:30 PM |
| `%Y-%m-%d` | 2026-04-08 |
| `%A` | Wednesday |

Full reference in **⚡ → Help…** inside the app.

## License

MIT

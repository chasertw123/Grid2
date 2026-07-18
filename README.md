# Grid2 (Ascension / WoW 3.3.5a)

A fork of [Grid2](https://github.com/bkader/Grid2-WoTLK) — the modular, lightweight, screen‑estate‑saving party/raid unit‑frame addon — for **World of Warcraft 3.3.5a (WotLK)**, built and tested on the **Ascension** private server, including the classless **Conquest of Azeroth** realm. It layers a set of custom enhancements and reliability fixes on top of the r736 WotLK port.

[![Latest release](https://img.shields.io/github/v/release/chasertw123/Grid2)](https://github.com/chasertw123/Grid2/releases/latest)
![WoW 3.3.5a](https://img.shields.io/badge/WoW-3.3.5a%20(30300)-blue)

## What's included

| Addon | Purpose |
| --- | --- |
| **Grid2** | The unit‑frame grid (required). |
| **Grid2Options** | In‑game configuration UI (load‑on‑demand; needed to configure Grid2). |
| **Grid2AoeHeals** | Optional companion that highlights the best AoE‑heal targets. |

## Installation

1. Download **`Grid2-<version>.zip`** from the [latest release](https://github.com/chasertw123/Grid2/releases/latest).
2. Extract it into your `Interface/AddOns` folder. The zip already contains the three folders, so you end up with:
   ```
   Interface/AddOns/Grid2/
   Interface/AddOns/Grid2Options/
   Interface/AddOns/Grid2AoeHeals/
   ```
3. Restart the client (or reload), enable the addons at the character‑select screen, then type `/grid2` to configure.

## Enhancements in this fork

Everything below is on top of the upstream r736 WotLK port.

**Layouts**
- **Per‑layout overrides** — each layout can use its own position, scale, and geometry instead of the global settings.
- **Self‑contained per‑layout pet separation** — give pets their own container / scale / growth for a single layout, without needing the global "position pet frames separately" toggle.
- **Separate pet‑frame customization** — independent pet size, appearance, positioning, frame‑lock, backdrop/border, and growth direction.
- **Faithful layout preview** — the "Test" button renders real Grid2 frames with your actual indicators and coloring, so the preview matches the live frames.

**Sorting**
- **Party/raid sorting** by Name or Role, with a reverse toggle and a configurable tank/healer/dps order.
- Falls back to the native, combat‑updatable **NAME** sort automatically when no role actually splits the roster.
- Honors **Main Tank / Main Assist** assignments as tanks in raids (which have no LFG roles).

**Configuration UX**
- **Per‑indicator Load tab** — load an indicator only for a chosen player class and unit type (player, group members, pets).
- Larger default config window and a de‑scrolled, tree‑navigated General settings page.

**Custom‑server compatibility**
- AoE Heals uses the native `UnitGetIncomingHeals` where available (fixes incoming‑heal display on custom cores).
- Threat/target attribution tuned for the server's combat log.

**Reliability**
- A batch of correctness fixes from an adversarial review of the codebase — including a client‑freezing infinite loop in the layouts menu, empty health bars after a group member dies and leaves, stale token‑keyed caches on roster reindex, indicator timer/teardown leaks, post‑combat roster refresh, and layout mis‑centering on load.

## Releasing

Releases are automated by [GitHub Actions](.github/workflows/release.yml). Push a semver tag and the workflow builds `Grid2-<version>.zip` (all three addons, with the version stamped into their `.toc` files) and publishes a GitHub Release:

```sh
git tag v1.1.0
git push origin v1.1.0
```

You can also trigger it manually from **Actions → Release → Run workflow**.

## Credits

Grid2 is by **Kader (bkader)** — [Grid2‑WoTLK](https://github.com/bkader/Grid2-WoTLK) — based on the original Grid2 by Michael, Pastamancer &amp; Maia, Jerry, and Toadkiller. This repository is a personal fork with server‑specific enhancements; all upstream credit and licensing belong to the original authors.

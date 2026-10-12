# Hackathon 3 – Roblox game (Stijn & Andy)

Twee mensen werken hier tegelijk aan, elk met een eigen Claude Code-sessie. Houd je aan deze regels om conflicten en dubbel werk te voorkomen.

## Communicatie tussen de twee Claude-sessies
- Lees bij de start van elke sessie `LOG.md` (na `git pull origin main`).
- Na elke afgeronde taak of belangrijke beslissing: voeg bovenaan in `LOG.md` een korte regel toe (datum, naam, wat er veranderd is, vragen voor de ander) en push.
- Vragen aan de ander zet je onder "Open vragen" in `LOG.md`. Beantwoord vragen die aan jouw persoon gericht zijn.

## Setup (eenmalig per laptop)
- Rojo **7.7.0** (zelfde versie als in `rokit.toml`). Via Rokit: `rokit install`. Of los: download `rojo` van https://github.com/rojo-rbx/rojo/releases/tag/v7.7.0.
- Rojo-plugin in Studio: `rojo plugin install`. Werkt dat niet ("Couldn't find registry keys"), download dan `Rojo.rbxm` van dezelfde release naar `%LOCALAPPDATA%\Roblox\Plugins\`.
- Starten: `rojo serve` in de repo-map, dan in Studio een Baseplate openen, Rojo → **Connect** → **Accept**.
- Test: druk op Play, in Output moeten `[Server] started` en `[Client] started` staan.

## Structuur (Rojo)
- `src/server/` → ServerScriptService.Server (server scripts, `*.server.luau`)
- `src/client/` → StarterPlayerScripts.Client (client scripts, `*.client.luau`)
- `src/shared/` → ReplicatedStorage.Shared (ModuleScripts, `*.luau`)
- Code staat alleen in deze bestanden, nooit direct in Studio aanpassen.
- Gedeelde Team Create-place `hackathon3`: alleen voor map/models. Scripts test je met Rojo in een eigen lokale Baseplate; in de gedeelde place alleen `main` syncen (zie Afspraken in `LOG.md`).

## Werkwijze
- Werk op je eigen branch (`andy` of `stijn`), nooit direct op `main`.
- Begin altijd met `git pull origin main` op je branch.
- Kijk in `TASKS.md` vóór je begint. Pak alleen taken die aan jouw persoon hangen of vrij zijn, en claim ze eerst (commit + push).
- Kleine commits, vaak een pull request naar `main`.

## Eigenaarschap
- Raak alleen bestanden aan in de mappen/systemen van jouw persoon (zie `TASKS.md`).
- `src/shared/` is gedeeld: wijzig bestaande modules alleen na overleg. Nieuwe bestanden toevoegen mag.
- Alle RemoteEvents staan in `src/shared/Remotes.luau`. Alleen namen toevoegen, nooit hernoemen of verwijderen zonder overleg.

## Code
- Luau, tabs voor inspringen.
- Gebruik `game:GetService(...)`, geen `game.Workspace` e.d.
- Valideer altijd data die van de client komt op de server.

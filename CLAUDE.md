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
Twee places, elk een eigen Rojo-project:
- **Game** = `default.project.json` (`rojo serve`, poort 34872): de map + het monster.
  - `src/server/` → ServerScriptService.Server (`*.server.luau`)
  - `src/client/` → StarterPlayerScripts.Client (`*.client.luau`)
  - `maps/Hospital.model.json` → Workspace.Hospital (gegenereerd door `tools/maps/hospital.py`, niet met de hand aanpassen)
  - Lighting-instellingen van de game staan in `default.project.json`.
- **Lobby** = `lobby.project.json` (`rojo serve lobby.project.json`, poort 34873): queues, lobby-UI.
  - `src/lobby/server/`, `src/lobby/client/`; de lobby-map zelf bouw je met `tools/build_lobby.luau` (command bar).
- Gedeeld door beide: `src/shared/` → ReplicatedStorage.Shared, `src/common/server/` → ServerScriptService.Common (bv. `Flicker`).
- Code staat alleen in deze bestanden, nooit direct in Studio aanpassen.
- Map aanpassen: wijzig `tools/maps/hospital.py`, run `python tools/maps/hospital.py`. Preview zonder Studio: `blender --background --python tools/maps/preview.py -- maps/Hospital.model.json <map> plan|shots`.
- Gedeelde Team Create-place `hackathon3`: alleen voor map/models. Scripts test je met Rojo in een eigen lokale Baseplate; in de gedeelde place alleen `main` syncen (zie Afspraken in `LOG.md`).

## Werkwijze
- Iedereen werkt direct op `main`, geen pull requests (we zijn met z'n tweeën).
- Begin altijd met `git pull origin main`, en pull opnieuw vlak vóór je pusht.
- Kijk in `TASKS.md` vóór je begint. Pak alleen taken die aan jouw persoon hangen of vrij zijn, en claim ze eerst (commit + push).
- Kleine commits en vaak pushen, dan blijven merge-conflicten klein.

## Eigenaarschap
- Raak alleen bestanden aan in de mappen/systemen van jouw persoon (zie `TASKS.md`).
- `src/shared/` is gedeeld: wijzig bestaande modules alleen na overleg. Nieuwe bestanden toevoegen mag.
- Alle RemoteEvents staan in `src/shared/Remotes.luau`. Alleen namen toevoegen, nooit hernoemen of verwijderen zonder overleg.

## Code
- Luau, tabs voor inspringen.
- Gebruik `game:GetService(...)`, geen `game.Workspace` e.d.
- Valideer altijd data die van de client komt op de server.

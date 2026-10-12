# Hackathon 3 – Roblox game (Stijn & Andy)

Twee mensen werken hier tegelijk aan, elk met een eigen Claude Code-sessie. Houd je aan deze regels om conflicten en dubbel werk te voorkomen.

## Structuur (Rojo)
- `src/server/` → ServerScriptService.Server (server scripts, `*.server.luau`)
- `src/client/` → StarterPlayerScripts.Client (client scripts, `*.client.luau`)
- `src/shared/` → ReplicatedStorage.Shared (ModuleScripts, `*.luau`)
- Code staat alleen in deze bestanden, nooit direct in Studio aanpassen.

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

# Log

Gedeeld logboek tussen Andy en Stijn (en hun Claude-sessies). Nieuwste bovenaan. Zie `CLAUDE.md` voor hoe je dit gebruikt.

## Open vragen
- **@stijn**: Wil je PR #1 (`andy` → `main`) reviewen en mergen? Daarna `git pull origin main` op je `stijn`-branch.
- **@beiden**: Wat voor spel maken we? Daarna verdelen we de taken in `TASKS.md`.

## Afspraken
- **Team Create + Rojo**: in de gedeelde place `hackathon3` (Team Create) bouwen we samen map/models. Scripts test ieder met Rojo in een eigen lokale Baseplate. In de gedeelde place wordt alleen `main` via Rojo gesynct, door één persoon tegelijk. Nooit je eigen branch in de gedeelde place syncen.

## Updates
- **2026-10-12 – Andy**: Spel wordt een **horrorgame**. Enge lobby gemaakt: `tools/build_lobby.luau` (plakken in Studio command bar → bouwt `Workspace.Lobby` + donkere Lighting: mist, dode bomen, kerkhof, lantaarns, verlaten huis met rood `PlayPortal` in de deur). `src/server/LobbyFlicker.server.luau` laat lampen met tag `Flicker` flikkeren. `PlayPortal` doet nog niks: hier moet later de teleport/queue naar de game komen.
- **2026-10-12 – Andy**: Andy zit in de gedeelde Team Create-place `hackathon3`. Afspraak over Team Create + Rojo toegevoegd (zie Afspraken). @stijn: akkoord?
- **2026-10-12 – Andy**: Rojo-setup staat en werkt (getest in Studio: server + client scripts draaien). Rojo naar 7.7.0 gezet. Setup-stappen staan in `CLAUDE.md`. `LOG.md` toegevoegd om te communiceren.

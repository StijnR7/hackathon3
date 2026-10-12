# Log

Gedeeld logboek tussen Andy en Stijn (en hun Claude-sessies). Nieuwste bovenaan. Zie `CLAUDE.md` voor hoe je dit gebruikt.

## Open vragen
- **@stijn**: Nieuwe PR `andy` → `main` met de lobby + queues. Reviewen en mergen? Daarna `git pull origin main` op je `stijn`-branch.
- **@beiden**: Wat is de core loop van de horrorgame? De lobby stuurt groepen van 1–4 naar de game-place. Wie maakt de game-place?
- **@stijn**: Mag de lobby in de gedeelde place? Dan run ik `tools/build_lobby.luau` daar (verandert Lighting, spawn, baseplate en terrain).

## Afspraken
- **Team Create + Rojo**: in de gedeelde place `hackathon3` (Team Create) bouwen we samen map/models. Scripts test ieder met Rojo in een eigen lokale Baseplate. In de gedeelde place wordt alleen `main` via Rojo gesynct, door één persoon tegelijk. Nooit je eigen branch in de gedeelde place syncen.

## Updates
- **2026-10-12 – Andy**: Lobby v2 + queuesysteem.
  - **Modellen**: `tools/blender/lobby_models.py` maakt 17 modellen in Blender (bomen, graven, crypte, lantaarns, hek, poort, rotsen, doodskist). Al geüpload; mesh-ids staan in `tools/build_lobby.luau`. Opnieuw maken: `blender --background --python tools/blender/lobby_models.py -- tools/blender/out` (met `LOBBY_ONLY=Crypt` voor één model), daarna importeren via Studio → Import 3D en de nieuwe id in de builder zetten.
  - **Lobby bouwen**: `tools/build_lobby.luau` in de command bar → terrain, kerkhof, plein met hangboom, 3 crypten.
  - **Queues**: elke crypte is een queue (`Workspace.Lobby.Queues.QueueN`, tag `Queue`). Eerste speler = host, kiest 1–4 spelers en drukt Start → 5s countdown → teleport naar `GameConfig.GamePlaceId` (reserved server). Staat nu op 0 → spelers krijgen "The game isn't ready yet". Server: `QueueService.server.luau`, client: `QueueUI.client.luau`. Nieuwe remotes: `QueueState`, `QueueAction`, `QueueNotice`.
  - **Geluid**: ids in `src/shared/SoundIds.luau`, afgespeeld door `LobbyAmbience.client.luau` (en hartslag/klok in de queue-UI).
  - **Intro**: `LobbyIntro.client.luau`, titel uit `GameConfig.GameName`.
  - Getest met 2 spelers (Studio server + 2 clients): joinen, host-rol, groepsgrootte, countdown en terugzetten werken.
- **2026-10-12 – Andy**: Spel wordt een **horrorgame**. Enge lobby gemaakt: `tools/build_lobby.luau` (plakken in Studio command bar → bouwt `Workspace.Lobby` + donkere Lighting: mist, dode bomen, kerkhof, lantaarns, verlaten huis met rood `PlayPortal` in de deur). `src/server/LobbyFlicker.server.luau` laat lampen met tag `Flicker` flikkeren. `PlayPortal` doet nog niks: hier moet later de teleport/queue naar de game komen.
- **2026-10-12 – Andy**: Andy zit in de gedeelde Team Create-place `hackathon3`. Afspraak over Team Create + Rojo toegevoegd (zie Afspraken). @stijn: akkoord?
- **2026-10-12 – Andy**: Rojo-setup staat en werkt (getest in Studio: server + client scripts draaien). Rojo naar 7.7.0 gezet. Setup-stappen staan in `CLAUDE.md`. `LOG.md` toegevoegd om te communiceren.

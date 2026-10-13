# Log

Gedeeld logboek tussen Andy en Stijn (en hun Claude-sessies). Nieuwste bovenaan. Zie `CLAUDE.md` voor hoe je dit gebruikt.

## Open vragen
- **@andy**: De Crawler doodt een speler nu direct (Health = 0) en spawnt bij een part `CrawlerSpawn`. Past dat bij jouw gameplay/map, of wil je een andere afhandeling (bv. een event)?
- **@beiden**: Wat is de core loop van de horrorgame? De lobby stuurt groepen van 1–4 naar de game-place (waar de Crawler rondloopt?). Wie maakt de game-place?
- **@stijn**: Mag de lobby in de gedeelde place? Dan run ik `tools/build_lobby.luau` daar (verandert Lighting, spawn, baseplate en terrain).

## Afspraken
- **Geen pull requests meer**: we zijn met z'n tweeën, dus we pushen direct naar `main`. Altijd eerst `git pull origin main`, dan pas pushen.
- **Team Create + Rojo**: in de gedeelde place `hackathon3` (Team Create) bouwen we samen map/models. Scripts test ieder met Rojo in een eigen lokale Baseplate. In de gedeelde place wordt alleen `main` via Rojo gesynct, door één persoon tegelijk.

## Updates
- **2026-10-13 – Andy**: Eerste game-map: **verlaten ziekenhuis** + lobby/game gesplitst.
  - **Twee Rojo-projecten**: `default.project.json` = game (jouw Crawler + de map), `lobby.project.json` = lobby. Mijn lobby-scripts staan nu in `src/lobby/`, `Flicker` in `src/common/server/`. Jouw bestanden heb ik niet verplaatst.
  - **Map**: `maps/Hospital.model.json` (gegenereerd door `tools/maps/hospital.py`) wordt door Rojo direct in Workspace gezet. Receptie (voordeur vastgeketend), hoofdgang + dwarsgang, kamers 101–104, verpleegpost, toiletten, zaal B (6 bedden), OK, **mortuarium met `CrawlerSpawn`**, archief, opslag, kantoor, ingestort trappenhuis. Flikkerende tl-lampen, noodlampjes, maanlicht door dichtgetimmerde ramen, ingestorte plafondtegels, bloed en teksten op de muren.
  - **@stijn**: alle deuren zijn 6–8 studs breed, plafond 14 studs. De Crawler spawnt in het mortuarium (17, 0.5, -62). Zie de plattegrond met `tools/maps/preview.py`.
  - **Speler**: `src/client/Flashlight.client.luau` (zaklamp, F), `src/client/HospitalAmbience.client.luau` + `src/shared/HospitalSounds.luau` (geluid).
- **2026-10-13 – Stijn**: Crawler is uit te zetten om te testen: `Enabled` in `CrawlerConfig` (voor iedereen), of per place een boolean-attribuut `CrawlerEnabled` op Workspace (vinkje uit = geen Crawler; werkt ook tijdens het spelen).
- **2026-10-13 – Stijn**: First-person toegevoegd (`src/client/FirstPerson.client.luau`): soepel rondkijken, sprinten met Shift (12 → 20 studs/s) met een lichte camera-bob, en een brede ^-crosshair. **@andy**: staat automatisch uit als er een `Workspace.Lobby` is, zodat je in de lobby de muis houdt voor de queue-knoppen.
- **2026-10-13 – Stijn**: Crawler omgebouwd. Geen procedurele IK meer: hij speelt een loopanimatie die in Blender is gemaakt (`src/shared/Monsters/CrawlerWalk.rbxmx`, KeyframeSequence; omzetten met `tools/crawler_anim_to_rbxmx.py`). Tegen een muur of plafond klapt hij er meteen op. Op de vloer loopt hij via PathfindingService. De animatie draait nu via een tijdelijk Studio-id; voor een echte server moet hij één keer gepubliceerd worden en moet het id in `CrawlerConfig.WalkAnimationId`.
- **2026-10-12 – Andy (einde dag)**: Alles staat op `main`. Volgende stap: lobby en game splitsen in twee places (nu draaien alle scripts, ook de Crawler, in dezelfde Rojo-project/place). Daarna game-place maken en `GamePlaceId` invullen.
- **2026-10-12 – Stijn**: Crawler aangepast voor een huis/appartement. Hij is nu zo groot als een speler (`Scale = 0.35` in `CrawlerConfig`) en gebruikt PathfindingService op de vloer (door deuren, om meubels heen). Bij een onbereikbare speler sluipt hij rond, verder springt hij of klimt hij via de muur. Poten gaan niet meer door blokken: een poot die ergens in komt stapt in z'n eentje op het blok, de rest blijft staan. **Let op @andy**: deuren moeten minstens 4 studs breed zijn, anders vindt de padvinding geen route.
- **2026-10-12 – Andy**: Workflow aangepast: geen PR's meer, iedereen pusht direct naar `main` (zie Afspraken + `CLAUDE.md`). Lobby + queues staan nu op `main`.
- **2026-10-12 – Andy**: Lobby v2 + queuesysteem.
  - **Modellen**: `tools/blender/lobby_models.py` maakt 17 modellen in Blender (bomen, graven, crypte, lantaarns, hek, poort, rotsen, doodskist). Al geüpload; mesh-ids staan in `tools/build_lobby.luau`. Opnieuw maken: `blender --background --python tools/blender/lobby_models.py -- tools/blender/out` (met `LOBBY_ONLY=Crypt` voor één model), daarna importeren via Studio → Import 3D en de nieuwe id in de builder zetten.
  - **Lobby bouwen**: `tools/build_lobby.luau` in de command bar → terrain, kerkhof, plein met hangboom, 3 crypten.
  - **Queues**: elke crypte is een queue (`Workspace.Lobby.Queues.QueueN`, tag `Queue`). Eerste speler = host, kiest 1–4 spelers en drukt Start → 5s countdown → teleport naar `GameConfig.GamePlaceId` (reserved server). Staat nu op 0 → spelers krijgen "The game isn't ready yet". Server: `QueueService.server.luau`, client: `QueueUI.client.luau`. Nieuwe remotes: `QueueState`, `QueueAction`, `QueueNotice`.
  - **Geluid**: ids in `src/shared/SoundIds.luau`, afgespeeld door `LobbyAmbience.client.luau` (en hartslag/klok in de queue-UI).
  - **Intro**: `LobbyIntro.client.luau`, titel uit `GameConfig.GameName`.
  - Getest met 2 spelers (Studio server + 2 clients): joinen, host-rol, groepsgrootte, countdown en terugzetten werken.
- **2026-10-12 – Stijn**: Crawler werkt. Model in `src/shared/Monsters/Crawler.rbxm` (via Rojo in ReplicatedStorage). `src/server/CrawlerAI.server.luau` spawnt hem bij een part `CrawlerSpawn` in Workspace (anders op 0,5,-40). Hij kruipt over vloer, muren en plafond naar de dichtstbijzijnde speler, springt naar spelers die hij niet kan bereiken, valt van het plafond en doodt bij aanraking. `src/client/CrawlerAnimator.client.luau` doet de procedurele IK-animatie. Instellingen staan in `src/shared/CrawlerConfig.luau` (nieuw bestand). Er zijn nog geen Remotes nodig.
- **2026-10-12 – Stijn**: Rojo getest op mijn branch met een lokale Baseplate (niet de Team Create-place): `[Server] started` + `[Client] started` werken. Monster "Crawler" (Blender, rig met 40 botten, 4,2 m / ~15 studs) toegevoegd in `assets/monster/`. `.mcp.json` voor de Roblox Studio MCP toegevoegd. Volgende stap: Crawler importeren + IK-animatie + achtervolg-AI.
- **2026-10-12 – Andy**: Spel wordt een **horrorgame**. Enge lobby gemaakt (eerste versie, vervangen door lobby v2). `src/server/LobbyFlicker.server.luau` laat lampen met tag `Flicker` flikkeren.
- **2026-10-12 – Andy**: Andy zit in de gedeelde Team Create-place `hackathon3`. Afspraak over Team Create + Rojo toegevoegd (zie Afspraken).
- **2026-10-12 – Andy**: Rojo-setup staat en werkt (getest in Studio: server + client scripts draaien). Rojo naar 7.7.0 gezet. Setup-stappen staan in `CLAUDE.md`. `LOG.md` toegevoegd om te communiceren.

# Log

Gedeeld logboek tussen Andy en Stijn (en hun Claude-sessies). Nieuwste bovenaan. Zie `CLAUDE.md` voor hoe je dit gebruikt.

## Open vragen
- **@andy**: De Crawler doodt een speler nu direct (Health = 0) en spawnt bij een part `CrawlerSpawn`. Past dat bij jouw gameplay/map, of wil je een andere afhandeling (bv. een event)?
- **@stijn**: Wil je PR #1 (`andy` → `main`) reviewen en mergen? Daarna `git pull origin main` op je `stijn`-branch.
- **@beiden**: Wat voor spel maken we? Daarna verdelen we de taken in `TASKS.md`.

## Updates
- **2026-10-12 – Stijn**: Crawler aangepast voor een huis/appartement. Hij is nu zo groot als een speler (`Scale = 0.35` in `CrawlerConfig`) en gebruikt PathfindingService op de vloer (door deuren, om meubels heen). Bij een onbereikbare speler sluipt hij rond, verder springt hij of klimt hij via de muur. Poten gaan niet meer door blokken: een poot die ergens in komt stapt in z'n eentje op het blok, de rest blijft staan. **Let op @andy**: deuren moeten minstens 4 studs breed zijn, anders vindt de padvinding geen route.
- **2026-10-12 – Stijn**: Crawler werkt. Model in `src/shared/Monsters/Crawler.rbxm` (via Rojo in ReplicatedStorage). `src/server/CrawlerAI.server.luau` spawnt hem bij een part `CrawlerSpawn` in Workspace (anders op 0,5,-40). Hij kruipt over vloer, muren en plafond naar de dichtstbijzijnde speler, springt naar spelers die hij niet kan bereiken, valt van het plafond en doodt bij aanraking. `src/client/CrawlerAnimator.client.luau` doet de procedurele IK-animatie. Instellingen staan in `src/shared/CrawlerConfig.luau` (nieuw bestand). Er zijn nog geen Remotes nodig.
- **2026-10-12 – Stijn**: Rojo getest op mijn branch met een lokale Baseplate (niet de Team Create-place): `[Server] started` + `[Client] started` werken. Monster "Crawler" (Blender, rig met 40 botten, 4,2 m / ~15 studs) toegevoegd in `assets/monster/`. `.mcp.json` voor de Roblox Studio MCP toegevoegd. Volgende stap: Crawler importeren + IK-animatie + achtervolg-AI.
- **2026-10-12 – Andy**: Rojo-setup staat en werkt (getest in Studio: server + client scripts draaien). Rojo naar 7.7.0 gezet. Setup-stappen staan in `CLAUDE.md`. `LOG.md` toegevoegd om te communiceren.

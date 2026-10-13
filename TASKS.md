# Taken

Claim een taak door je naam erachter te zetten en te pushen **vóór** je begint.

## Verdeling
- Andy: lobby (map, queues, UI, geluid)
- Stijn: monster "Crawler" (model, animatie, AI) → `src/server/Crawler*`, `src/client/Crawler*`, `src/shared/Monsters/`, `src/shared/CrawlerConfig.luau`

## Open
- [ ] Definitieve gamenaam (nu werktitel `THE CRYPTS` in `GameConfig.GameName`)

## Bezig
- [ ] Map veel groter maken (vleugels, binnenplaatsen, meer kamersoorten) — @andy (`tools/maps/hospital.py`; Stijns markers blijven: FuseSpawn, FuseBox, ExitZone, Mirror, CrawlerSpawn, voordeur)
- [ ] MVP-ronde: 3 zekeringen zoeken → stroomkast bij receptie → voordeur open → ontsnappen; gepakt = dood + meekijken; einde → terug naar lobby — @stijn (`src/server/Round.server.luau`, `src/client/RoundUI.client.luau`, `src/shared/RoundConfig.luau`, markers in `tools/maps/hospital.py`)
- [ ] Publiceren: lobby = startplace van de bestaande experience, game = tweede place, place-ids in `GameConfig` — @stijn

## Klaar
- [x] Spiegel: elk part met tag `Mirror` toont je reflectie (met de kamer erachter), maar met een enge grijns — @stijn
- [x] Lobby en game gesplitst in twee Rojo-projecten — @andy
- [x] Map 1: verlaten ziekenhuis (+ zaklamp, geluid) — @andy
- [x] First-person camera (soepel rondkijken), sprinten (Shift) met lichte camera-bob, ^-crosshair — @stijn
- [x] Crawler: procedurele IK-animatie (vloer/muur/plafond) — @stijn
- [x] Crawler: AI die spelers achtervolgt (klimmen, springen, van plafond vallen) — @stijn
- [x] Crawler-model geïmporteerd (`src/shared/Monsters/Crawler.rbxm`) — @stijn
- [x] Rojo-projectstructuur — @andy
- [x] Enge lobby: Blender-modellen, terrain, sfeer, flikkerende lampen — @andy
- [x] 3 queues (crypten) met host, groepsgrootte 1–4, start + countdown + teleport — @andy
- [x] Lobby-UI (queue-paneel, intro, hint) en geluid — @andy

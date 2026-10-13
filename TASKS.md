# Taken

Claim een taak door je naam erachter te zetten en te pushen **vóór** je begint.

## Verdeling
- Andy: lobby (map, queues, UI, geluid)
- Stijn: monster "Crawler" (model, animatie, AI) → `src/server/Crawler*`, `src/client/Crawler*`, `src/shared/Monsters/`, `src/shared/CrawlerConfig.luau`

## Open
- [ ] Definitieve gamenaam (nu werktitel `THE CRYPTS` in `GameConfig.GameName`)

## Bezig

## Klaar
- [x] MVP-ronde: 3 zekeringen → stroomkast → voordeur open → ontsnappen; gepakt = dood + meekijken; einde → terug naar lobby — @stijn
- [x] Gepubliceerd in experience `hackathon3`: lobby = startplace (134559509231211), game = place 124517980036287 — @stijn
- [x] Ziekenhuis-map veel groter: 90 kamers, 17 soorten, 2 binnenplaatsen — @andy
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

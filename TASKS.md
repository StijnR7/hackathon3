# Taken

Claim een taak door je naam erachter te zetten en te pushen **vóór** je begint.

## Verdeling
- Andy: lobby (map, queues, UI, geluid)
- Stijn: monster "Crawler" (model, animatie, AI) → `src/server/Crawler*`, `src/client/Crawler*`, `src/shared/Monsters/`, `src/shared/CrawlerConfig.luau`

## Open
- [ ] Game-idee en core loop vastleggen (horror, 1–4 spelers per groep)
- [ ] Game-place maken en `GamePlaceId` invullen in `src/shared/GameConfig.luau`
- [ ] Definitieve gamenaam (nu werktitel `THE CRYPTS` in `GameConfig.GameName`)

## Bezig
- [ ] Spiegel (part met tag `Mirror`) met je reflectie, maar met een enge grijns — @stijn (`src/client/Mirror.client.luau`, `src/shared/MirrorConfig.luau`)

## Klaar
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

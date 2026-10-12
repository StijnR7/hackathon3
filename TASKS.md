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

## Klaar
- [x] Crawler: procedurele IK-animatie (vloer/muur/plafond) — @stijn
- [x] Crawler: AI die spelers achtervolgt (klimmen, springen, van plafond vallen) — @stijn
- [x] Crawler-model geïmporteerd (`src/shared/Monsters/Crawler.rbxm`) — @stijn
- [x] Rojo-projectstructuur — @andy
- [x] Enge lobby: Blender-modellen, terrain, sfeer, flikkerende lampen — @andy
- [x] 3 queues (crypten) met host, groepsgrootte 1–4, start + countdown + teleport — @andy
- [x] Lobby-UI (queue-paneel, intro, hint) en geluid — @andy

-- Instellingen voor het Crawler-monster. Gedeeld door server (AI) en client (animatie).
-- Afstanden zijn in studs en gelden voor het geschaalde model (Scale).
return {
	Tag = "Crawler", -- CollectionService-tag op elk Crawler-model in Workspace

	-- Aan/uit. Testen zonder monster kan ook per place, zonder code te wijzigen: geef Workspace een
	-- boolean-attribuut "CrawlerDisabled" met vinkje aan (werkt ook tijdens het spelen).
	-- (Het attribuut "CrawlerEnabled" wordt door de ronde gezet: pas los na de veilige periode.)
	Enabled = true,

	-- Grootte t.o.v. het originele model (1 = ~14 studs hoog). 0.35 ≈ zo hoog als een speler,
	-- past door deuren en onder plafonds van een appartement.
	Scale = 0.35,

	-- Beweging (studs / seconde)
	WalkSpeed = 8,
	ChaseSpeed = 17,
	TurnSpeed = 5, -- radialen per seconde
	Gravity = 120,
	ProbeHeight = 1, -- hoogte van de vooruit-straal boven het oppervlak
	ClimbProbe = 0.5, -- marge vóór de kop waarbinnen hij op een muur/plafond klapt

	-- AI
	PathRadius = 1, -- straal voor PathfindingService; groter past niet door een deur van 4 studs
	DetectRange = 150,
	CatchRange = 3.5, -- afstand van speler tot kop of lijf
	CatchCooldown = 2,
	CeilingDropRange = 4, -- valt van het plafond als een speler horizontaal zo dichtbij is
	StuckTime = 3, -- seconden zonder voortgang → andere kant op / loslaten

	-- Loopanimatie (gemaakt in Blender, zie tools/crawler_anim_to_rbxmx.py)
	-- Leeg = de KeyframeSequence Shared.Monsters.CrawlerWalk gebruiken (werkt alleen in Studio).
	-- Voor een echte server: publiceer de animatie (Animation Editor → Publish) en zet hier het id.
	WalkAnimationId = "",
	WalkStride = 3, -- studs die hij aflegt per keer dat de animatie (1 s) helemaal afspeelt
}

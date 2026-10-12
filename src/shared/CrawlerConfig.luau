-- Instellingen voor het Crawler-monster. Gedeeld door server (AI) en client (animatie).
-- Afstanden zijn in studs en gelden voor het geschaalde model (Scale).
return {
	Tag = "Crawler", -- CollectionService-tag op elk Crawler-model in Workspace

	-- Grootte t.o.v. het originele model (1 = ~14 studs hoog). 0.35 ≈ zo hoog als een speler,
	-- past door deuren en onder plafonds van een appartement.
	Scale = 0.35,

	-- Beweging (studs / seconde)
	WalkSpeed = 8,
	ChaseSpeed = 17,
	TurnSpeed = 5, -- radialen per seconde
	SurfaceAlignSpeed = 16, -- hoe snel het lijf naar een nieuwe muur/plafond draait
	Gravity = 120,
	ProbeHeight = 1, -- hoogte van de vooruit-straal boven het oppervlak
	ClimbProbe = 0.6, -- marge vóór de kop waarbinnen hij op een muur overstapt
	ClimbBackDelay = 1.5, -- seconden voordat hij terug mag naar het vlak waar hij net vandaan kwam
	BodyHeight = 4.5, -- hoogte incl. ellebogen/knieën: past hij hier niet onder, dan klimt hij erover

	-- AI
	PathRadius = 1, -- straal voor PathfindingService; groter past niet door een deur van 4 studs
	DetectRange = 150,
	CatchRange = 3.5, -- afstand van speler tot kop of lijf
	CatchCooldown = 2,
	CeilingDropRange = 4, -- valt van het plafond als een speler horizontaal zo dichtbij is
	StuckTime = 3, -- seconden zonder voortgang → valt los en probeert opnieuw
	LeapRange = 18, -- springt naar een speler die hij over het oppervlak niet bereikt
	LeapMinHeight = 4.5, -- speler moet minstens zo ver "boven" het oppervlak zitten
	LeapCooldown = 3,

	-- Procedurele animatie (client)
	StepDistance = 1.8, -- poot zet een stap als hij zo ver achterloopt
	StepTime = 0.14,
	StepHeight = 1,
	StepLead = 0.25, -- seconden vooruit voorspellen in de looprichting
	MaxReach = 7, -- verder dan dit → poot springt direct naar de nieuwe plek
	FootClearance = 0.15, -- poot blijft zoveel boven het oppervlak (tegen wegzakken)
}

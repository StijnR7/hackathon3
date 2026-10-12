-- Instellingen voor het Crawler-monster. Gedeeld door server (AI) en client (animatie).
return {
	Tag = "Crawler", -- CollectionService-tag op elk Crawler-model in Workspace

	-- Beweging (studs / seconde)
	WalkSpeed = 14,
	ChaseSpeed = 22,
	TurnSpeed = 4, -- radialen per seconde
	SurfaceAlignSpeed = 8, -- hoe snel het lijf naar een nieuwe muur/plafond draait
	Gravity = 120,

	-- AI
	DetectRange = 250,
	CatchRange = 7, -- afstand van speler tot kop
	CatchCooldown = 2,
	CeilingDropRange = 10, -- valt van het plafond als een speler horizontaal zo dichtbij is
	StuckTime = 3, -- seconden zonder voortgang → valt los en probeert opnieuw
	LeapRange = 35, -- springt naar een speler die hij over het oppervlak niet bereikt
	LeapCooldown = 3,

	-- Procedurele animatie (client)
	StepDistance = 4.5, -- poot zet een stap als hij zo ver achterloopt
	StepTime = 0.16,
	StepHeight = 2.5,
	StepLead = 0.35, -- seconden vooruit voorspellen in de looprichting
	MaxReach = 18, -- verder dan dit → poot springt direct naar de nieuwe plek
}

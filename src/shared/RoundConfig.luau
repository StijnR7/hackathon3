-- Instellingen voor een ronde in de game-place (zie src/server/Round.server.luau).
-- Doel: vind de zekeringen, stop ze in de stroomkast bij de receptie, dan gaat de voordeur open.
return {
	FuseCount = 3, -- zoveel zekeringen liggen er per ronde (gekozen uit de FuseSpawn-markers in de map)
	JoinWait = 8, -- seconden wachten op de rest van de groep na de eerste speler
	IntroTime = 6, -- seconden tussen spawnen en "ga!"
	GracePeriod = 20, -- seconden voordat de Crawler losgelaten wordt
	TimeLimit = 600, -- maximale rondeduur in seconden; daarna is iedereen die nog binnen is af
	EndDelay = 10, -- seconden uitslagscherm voor het terugsturen naar de lobby
	PickupHold = 0.4, -- seconden ingedrukt houden om een zekering op te pakken
	InsertHold = 1.2, -- seconden ingedrukt houden om zekeringen in de stroomkast te stoppen
	PromptDistance = 8,
}

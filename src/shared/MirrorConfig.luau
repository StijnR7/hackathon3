-- Instellingen voor spiegels. Elk part met de tag "Mirror" wordt een spiegel (de voorkant / Front face).
return {
	Tag = "Mirror",
	-- Mond die je spiegelbeeld krijgt i.p.v. je eigen gezicht
	FaceImage = "rbxassetid://5980075803",
	FaceColor = Color3.new(0.290196, 0.0980392, 0.0980392),
	FaceAspect = 1.59, -- breedte/hoogte van het mond-plaatje (zoals het Mouth-part: 4.3 x 2.7)
	FaceDrop = 0.12, -- hoeveel (deel van de hoofdhoogte) de mond onder het midden van het gezicht zit
	Range = 45, -- binnen deze afstand werkt de spiegel (en worden spelers gespiegeld)
	EnvironmentRadius = 70, -- delen van de kamer binnen deze straal worden mee gespiegeld (ook de muur achter je)
	PixelsPerStud = 150, -- scherpte van het spiegelbeeld
	MaxPixels = 2048, -- grootste beeld dat Roblox op een SurfaceGui scherp tekent; daarboven zakt de scherpte iets
	Tint = Color3.fromRGB(205, 215, 220), -- licht koele glastint
	Ambient = Color3.fromRGB(110, 110, 115),
	LightColor = Color3.fromRGB(190, 185, 175),
}

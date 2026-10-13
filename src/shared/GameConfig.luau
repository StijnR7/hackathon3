-- Instellingen voor lobby en queues.
return {
	-- Werktitel van de game (intro-scherm in de lobby).
	GameName = "THE CRYPTS",
	-- PlaceId van de game-place waar de queue naartoe teleporteert. 0 = nog niet ingesteld (dan alleen een test-melding).
	GamePlaceId = 124517980036287, -- place "Hospital" in de experience
	-- PlaceId van de lobby (startplace). De game stuurt iedereen hierheen terug na een ronde.
	LobbyPlaceId = 134559509231211, -- startplace "hackathon3" (lobby)
	MaxPlayers = 4,
	CountdownSeconds = 5,
}

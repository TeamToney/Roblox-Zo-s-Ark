--!strict
-- Only these curated search terms can reach Roblox's music-library API.
local MusicCatalog = {}
MusicCatalog.Order = {"lofi", "hiphop", "pop", "club", "trap", "ambient"}
MusicCatalog.Styles = {
	lofi = {name="Lofi", keyword="lofi", description="Laid-back beats for wandering the islands."},
	hiphop = {name="Hip Hop", keyword="hip hop instrumental", description="Head-nodding grooves for your next expedition."},
	pop = {name="Pop", keyword="pop instrumental", description="Bright melodies for a sunny day at the Ark."},
	club = {name="Club", keyword="dance electronic", description="Dance-floor energy for sailing and exploring."},
	trap = {name="Trap", keyword="trap instrumental", description="Deep bass and rolling hats for the chase."},
	ambient = {name="Ambient", keyword="ambient relaxing", description="Gentle soundscapes for the open sea."},
} :: {[string]: {name: string, keyword: string, description: string}}
MusicCatalog.MaxTracks = 12
MusicCatalog.SearchInterval = 8
MusicCatalog.RetrySeconds = 45
-- Optional owner-curated replacements. Only add music permitted for this
-- experience: {Id=123, Title="Track title", Artist="Artist credit", Duration=120}.
MusicCatalog.Tracks = {} :: {[string]: {any}}
return MusicCatalog

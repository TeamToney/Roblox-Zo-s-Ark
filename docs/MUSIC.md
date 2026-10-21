# Ark Radio

The Music page and N shortcut open the radio. It starts on Lofi at 25% volume, with Hip Hop, Pop, Club, Trap and Ambient available. Players can mute, adjust volume, select tracks or skip forward/backward. Tracks repeat through the selected playlist. Controls are local to each player and remain through character respawns; there is no saved-profile change. Turning music off restarts the selected track when turned on again.

The default playlists are discovered at runtime using Roblox's [AssetService.SearchAudioAsync](https://create.roblox.com/docs/reference/engine/classes/AssetService#SearchAudioAsync) with fixed MusicCatalog terms, Music subtype and 60–360-second durations. No player-supplied search or asset ID reaches the service. MusicLibrary normalizes up to twelve unique positive asset IDs and title/artist credits. It caches successful results for the server session, spaces searches by eight seconds, coalesces in-flight searches and retries failed/empty searches after 45 seconds. The dedicated MusicPlaylist remote has a one-second per-player request limit and changes no journal data.

MusicPlayer owns local Sound instances under SoundService and a separate music SoundGroup. It fades transitions, times out track loads after twelve seconds and skips failed assets. Exhausted lists stop with another-style/Retry controls. Search requests time out in the UI after 28 seconds. Generation checks prevent delayed search, load and ended callbacks from playing after a mute or a newer selection. Music remains independent of the notebook request lock. Chest scenes reduce the selected music volume to 25% and restore it afterward; restoring never enables a muted radio.

## Review and pin a release playlist

Dynamic catalog results can change and audio access depends on Roblox. Audition all styles in the target staging experience before publishing, including permissions, genre fit and credits. The cloud build has not performed those listening or service tests. Keep audio permitted for this experience when adding your own tracks.

For a fixed reviewed playlist, set the corresponding entry in src/shared/MusicCatalog.luau:

```lua
MusicCatalog.Tracks.lofi = {
    -- Replace the example ID with a reviewed, playable asset permitted here.
    {Id=123456789, Title="Your reviewed track", Artist="Artist credit", Duration=120},
}
```

A nonempty valid curated list replaces search for that genre. Empty/unconfigured genres use library search. Rebuild with bash scripts/check.sh and python3 scripts/package_studio.py; restart the staging server to refresh cached results. Do not copy the example asset ID into a release playlist without replacing it.

Runtime asset delivery, search throttling, mix levels and the compact touch/controller UI require the manual cases in TESTING.md. Automated tests use injected fake library responses and do not establish audible playback or rights to a specific track.

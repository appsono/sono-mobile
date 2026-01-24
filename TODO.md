## TODO

- [x] Move all API keys, exposed URLs, etc. into an `.env`
- [x] Fix lag when opening the album page
- [x] Make the app use `.env` variables
- [x] Create a theme file with all shared values
- [x] Fix app not showing database playlists
- [x] Fix player crashes and random skipping
- [x] Migrate app to use theme variables instead of hard-coded values
- [x] Fix Sono Audio Stream (SAS)
  UI does not refresh automatically when like/favorite state changes
- [x] When the host stops SAS, connected devices still have songs loaded in their players
- [x] Mobile player, fullscreen player, and media controls still show the old player context  (SAS)
- [x] Player initializes but is not visible and does not start playback
- [x] Audio playback delay still exists even when delay is set to `0ms`  (SAS)
- [x] Sono account sessions do not auto-refresh on app start.
- [x] Clear app RAM when usage is too high
- [x] App player does not clean up properly after SAS sessions
- [x] App stops playing after the second song
- [x] Seek bar is laggy in fullscreen player
- [x] Add swipe-down gesture to minimize fullscreen player (respect safe area)
- [x] Add swipe-up gesture on mini player to open fullscreen player
  and swipe-down to dismiss the player (stop player, not app, respect safe area)
- [ ] Restore fullscreen player animation when switching songs
- [ ] Skipping songs in fullscreen player is buggy and sometimes takes a long time
- [x] Liking songs, favoriting artists, and favoriting albums Lists only update after a full app restart
- [x] Fix Update Service: Update Service pops up, but doesn't actually download APK
- [ ] Re-design search page, from scratch
- [ ] Add new API features: Account Settings, TOS and PRIVACY acceptance, reset password, announcements, adming dash (use web view inside app to open web.sono.wtf/admin). (NO COLLECTIONS FOR NOW) (API_REFERENCE.md)
- [x] Remove weird pinkish background, when scrolling, from all headers
- [ ] Make mini-player visible on all pages that it would be useful to see on
- [ ] Make Bottom Nav visible on all pages that it would be useful to see on

## Long-term tasks

- [ ] Add Tag Editor
- [ ] Add Themes (for App, Player components etc.)
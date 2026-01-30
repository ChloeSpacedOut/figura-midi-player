# Installation
The basic installation steps are as follows:
1. Add `midiPlayerClient.lua` to your avatar's script files
2. In your avatar's action wheel script, require the `midiPlayerClient` script. For example:
```lua
local midiPlayer = require("midiPlayerClient")
```
3. Run `addMidiPlayer()` with your desired action wheel page. For example:
```lua
midiPlayer:addMidiPlayer(myActionWheelPage)
```
Your final script may look something like this:
```lua
-- require midi player
local midiPlayer = require("midiPlayerClient")

-- standard action wheel host check
if not host:isHost() then return end

-- create action wheel
local mainPage = action_wheel:newPage("mainPage")
action_wheel:setPage(mainPage)

-- set up midi player
midiPlayer:addMidiPlayer(mainPage)
```
With this done, you should see the midi player icon in your action wheel!
# Setup
Before you can use the midi player, you will need to set the midi player cloud avatar to MAX perms. To do so:
1. Load your avatar with the midi player set up
2. Go to the Figura `Permissions` screen
3. Click `Show disconnected avatars` on the top right of the permissions window
4. Scroll down (not search!) until you find `Midi Player Cloud`, and change its permissions to `MAX`
5. Reload your avatar
# Usage
## Song Selector
With this done, you should now be able to access the midi player menu!
To the left is the song selector. You can add midi songs to it by adding them to `figura/data/ChloesMidiPlayer`. The song selector supports subfolders, so be as organised as you need!
Songs played will first be compressed, then pinged to other clients. Once done, it will decompress and load your song, and only then will you be able to play it. You can either toggle `local mode` in settings, or hold `ctrl` when clicking a song to immediately play the song on your client (once it's loaded).
## Settings
### Volume
Sets the volume of songs **locally** for your client. Holding `ctrl` while scrolling gives more precision.
### Ping Size
How much data will be sent per second with pings. Setting this too low will break, and too high will get you rate limited by the Figura cloud. Holding `ctrl` while scrolling lets you change the size faster.
### Ratelimit Roleback
How many pings will be reverted every time the Figura cloud rate limit is reached. This helps prevent rate limits breaking your upload. Setting this too high may reset too much of your upload, and too low data may be lost. Holding `ctrl` while scrolling lets you change the rollback faster.
### Toggle Local Mode
Toggles local mode. With local mode toggled, songs will not be sent to other clients, allowing you to listen to songs faster. With local mode toggled on, using `alt local mode` when selecting a song will instead upload it.
### Refresh Files
Refreshes midi file data, allowing you to add new songs to `figura/data/ChloesMidiPlayer` and use them without reloading your avatar.
## Controls
### Host Controls
- `left click`: play / pause song or enter folder
- `right click`: exit folder
- `shift` + `right click`: stop current song
- `ctrl` + `left click`: alt local mode
- `ctrl` + `right click`: clear song
- `scroll`: navigate songs
- `alt` + `scroll`: fast navigate songs or settings
### Non-Host Controls
While looking at an avatar playing a midi, crouch. A volume bar will appear. By scrolling, you can change volume. You can also change the distance a song can be heard from by attempting to scroll greater than the maximum or minimum of the volume bar.

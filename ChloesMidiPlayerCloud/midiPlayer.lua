local midi = require("midiAPI")
local soundfont = require("soundfont")

local midiPlayer = {
    instances = {}
}

local function progressMidi(instance,activeSong,sysTime,deltaTime)
    activeSong.clock = activeSong.clock + (deltaTime / (activeSong.tempo / (activeSong.ticksPerQuaterNote * 1000)))
    for trackID, activeTrack in pairs(activeSong.tracks) do
        if not instance.tracks[trackID] then
            instance.tracks[trackID] = {}
        end
        for i = activeTrack.sequenceIndex, #activeTrack.sequence do
            if not activeTrack.lastEventTime then
                activeTrack.lastEventTime = activeSong.clock
            end
            local eventDeltaTime = activeSong.clock - activeTrack.lastEventTime
            local targetDelta = activeTrack.sequence[i].deltaTime
            if eventDeltaTime >= targetDelta then
                local typeFunction = midi.events[activeTrack.sequence[i].type]
                if typeFunction then
                    typeFunction(instance,activeTrack.sequence[i],sysTime,activeTrack,trackID,activeSong)
                end
                activeTrack.lastEventTime = activeSong.clock - (eventDeltaTime - targetDelta)
            else
                activeTrack.sequenceIndex = i
                break
            end
         end
    end
end

local function updateNotes(instance,sysTime)
    for _,channel in pairs(instance.tracks) do
        for _,note in pairs(channel) do
            local instrument = soundfont.instruments[note.instrument.index]
            local noteVol = 1
            local pitchMod = 1 + (note.pitch/192)
            local resonanceMod = 1
            if instrument.resonance ~= 0 and note.state == "RELEASED" and note.instrument.Sustain then
                resonanceMod = math.clamp(instrument.resonance^(((sysTime - note.releaseTime)/100)*pitchMod),0,1)
            end
            if instrument.sustain ~= 0 then
                noteVol = math.clamp(instrument.sustain^(((sysTime - note.initTime)/100)*pitchMod),instrument.minVol,1)
                if (note.initTime + math.floor((note.duration * (1/note.soundPitch)) - 7) <= sysTime) and (not note.loopSound) then
                    note:sustain()
                end
                if note.state == "RELEASED" then
                    if instrument.resonance ~= 0 then
                        if note.loopSound then
                            note.loopSound:setVolume(noteVol * resonanceMod * note.velocity)
                        elseif note.sound then
                            note.sound:setVolume(noteVol * resonanceMod * note.velocity)
                        end
                    else
                        note:stop()
                    end
                elseif note.state == "SUSTAINING" then
                    note.loopSound:setVolume(noteVol * note.velocity)
                elseif note.state == "PLAYING" then
                    note.sound:setVolume(noteVol * note.velocity) -- idk if this accounts for loop only samples
                end
            end
            if instrument.resonance ~= 0 and note.state == "RELEASED" then
                if (noteVol * resonanceMod) < 0.01 then
                    note:stop()
                end
            end
            if (not note.loopSound) and (instrument.resonance == 1) and (not note.sound:isPlaying()) then
                note:stop()
            end
        end
    end
end

local lastSysTime = client.getSystemTime()
function midiPlayer.render(instance)
    local activeSong = instance.songs[instance.activeSong]
    if activeSong and activeSong.state == "PLAYING" then
        local sysTime = client.getSystemTime()
        local deltaTime = sysTime - lastSysTime
        lastSysTime = sysTime
        progressMidi(instance,activeSong,sysTime,deltaTime)
        updateNotes(instance,sysTime)
    end
end

return midiPlayer

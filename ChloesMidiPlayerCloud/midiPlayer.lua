local midi = require("midiAPI")
local soundfont = require("soundfont")

local midiPlayer = {
    instances = {}
}

local function progressMidi(instance,activeSong,sysTime,deltaTime)
    if activeSong.state == "PAUSED" or activeSong.state == "STOPPED" then return end
    activeSong.clock = activeSong.clock + (deltaTime / (activeSong.tempo / (activeSong.ticksPerQuarterNote * 1000))) * activeSong.speed
    activeSong.time = activeSong.time + (sysTime - activeSong.lastSysTime) * activeSong.speed
    activeSong.lastSysTime = sysTime
    local isSongEnded = true
    for trackID, activeTrack in pairs(activeSong.tracks) do
        if not activeTrack.isEnded then
            isSongEnded = false
            if not instance.tracks[trackID] then
                instance.tracks[trackID] = {}
            end
            for i = activeTrack.sequenceIndex, #activeTrack.sequence do
                if not activeTrack.lastEventTime then
                    activeTrack.lastEventTime = activeSong.clock
                end
                local eventDeltaTime = activeSong.clock - activeTrack.lastEventTime
                local targetDelta = activeTrack.sequence[i].deltaTime
                if targetDelta > 100000000 then -- i hate midi
                    targetDelta = 0
                end
                if eventDeltaTime >= targetDelta then
                    local typeFunction = midi.events[activeTrack.sequence[i].type]
                    if instance.onMidiEvent then
                        instance:onMidiEvent(activeTrack.sequence[i], activeTrack, trackID, activeSong)
                    end
                    if typeFunction then
                        typeFunction(instance, activeTrack.sequence[i], sysTime, activeTrack, trackID, activeSong)
                    end
                    activeTrack.lastEventTime = activeSong.clock - (eventDeltaTime - targetDelta)
                else
                    activeTrack.sequenceIndex = i
                    break
                end
            end
        end
    end
    if isSongEnded then
        if activeSong.loopState then
            if activeSong.post then
                activeSong:post(true)
            end
            activeSong:stop()
            activeSong:play()
        else
            if activeSong.post then
                activeSong:post(false)
            end
            activeSong:stop()
        end
    end
end

local function updateNotes(instance,sysTime)
    local targetPos
    if type(instance.target) == "Vector3" then
        targetPos = instance.target
    else
        if not instance.target.getPos then
            return
        end
        targetPos = instance.target:getPos()
    end
    for _,track in pairs(instance.tracks) do
        for _,note in pairs(track) do
            local notePos
            if note.pos then 
                notePos = note.pos
            else
                notePos = targetPos
            end
            local channel = note.instance.channels[note.channel]
            local pitch = note.soundPitch * 2^(math.map(channel.pitchBend,0,16383,-channel.pitchBendRange,channel.pitchBendRange)/12)
            if note.sound then
                note.sound:pos(notePos)
                    :pitch(pitch)
            end
            if note.loopSound then
                note.loopSound:pos(notePos)
                    :pitch(pitch)
            end
            local instrument = soundfont.instruments[note.instrument.index]
            local noteVol = 1
            local pitchMod = 1 + (note.pitch/192)
            local resonanceMod = 1
            if instrument.resonance ~= 0 and note.state == "RELEASED" and note.instrument.Sustain then
                resonanceMod = math.clamp(instrument.resonance^(((sysTime - note.releaseTime)/100)*pitchMod),0,1)
            end
            if instrument.sustain ~= 0 then
                noteVol = math.clamp(instrument.sustain^(((sysTime - note.initTime)/100)*pitchMod),instrument.minVol,1)
                if (note.initTime + math.floor((note.duration * (1/pitch)) - 7) <= sysTime) and (not note.loopSound) then
                    note:sustain()
                end
                if note.state == "RELEASED" then
                    if instrument.resonance ~= 0 then
                        if note.loopSound then
                            note.loopSound:volume(noteVol * resonanceMod * note.velocity * channel.volume * instance.volume)
                                :attenuation(note.instance.attenuation)
                        elseif note.sound then
                            note.sound:volume(noteVol * resonanceMod * note.velocity * channel.volume * instance.volume)
                                :attenuation(note.instance.attenuation)
                        end
                    else
                        note:stop()
                    end
                elseif note.state == "SUSTAINING" then
                    note.loopSound:volume(noteVol * note.velocity * channel.volume * instance.volume)
                        :attenuation(note.instance.attenuation)
                elseif note.state == "PLAYING" then
                    note.sound:volume(noteVol * note.velocity * channel.volume * instance.volume)
                        :attenuation(note.instance.attenuation)
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

function midiPlayer.updatePlayer(instance)
    local sysTime = client.getSystemTime()
    local deltaTime = sysTime - instance.lastSysTime
    instance.lastSysTime = sysTime
    instance.lastUpdated = sysTime
    local activeSong = instance.songs[instance.activeSong]
    if activeSong and activeSong.state == "PLAYING" then
        progressMidi(instance,activeSong,sysTime,deltaTime)
        updateNotes(instance,sysTime)
    elseif not activeSong then
        updateNotes(instance,sysTime)
    end
end

return midiPlayer

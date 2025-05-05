-- Minify client (minecraft spotify)
-- Powered by VoMP (Voice Over Minenet Protocol)
-- Requires server connection
-- Requires basic wireless modem and speaker

local modem   = peripheral.find("modem"  ) or error("Error: No modem attached",   0)
local speaker = peripheral.find("speaker") or error("Error: No speaker attached", 0)
local dfpwm   = require("cc.audio.dfpwm")

-- Opens on port 2 for VoMP
modem.open(2)

-- Global variable initialisations
local computerId      = os.getComputerID()
local decoder         = dfpwm.make_decoder()
local minifyServerId  = 2 -- Must be manually set
local w, h            = term.getSize()
local input           = ""
local buffer          = {}
local receivedList    = false
local currentSong     = nil
local currentStreamId = nil
local gotFirstChunk   = false

-- Redraws UI
local function reDraw()
    term.setCursorPos(1,1)   term.clearLine()
    term.setCursorPos(1,2)   term.clearLine() term.write("         *********************************")
    term.setCursorPos(1,3)   term.clearLine() term.write("         * Minify music streaming client *")
    term.setCursorPos(1,4)   term.clearLine() term.write("         *********************************")
    term.setCursorPos(1,5)   term.clearLine()
    term.setCursorPos(1,6)   term.clearLine() term.write(" For command list please type halp minify in shell")
    term.setCursorPos(1,7)   term.clearLine()
    term.setCursorPos(1,h)   term.clearLine() term.write("Minify> "..input)
    term.setCursorBlink(true)
end

-- Print to console in correct format
local function output(text)
    term.scroll(1)
    term.setCursorPos(1,h-1)
    term.clearLine()
    term.write(text)
    reDraw()
end

-- Stop the current stream immediately
local function stopStream()
    currentStreamId = nil
    buffer = {}
end

-- Start playing a new song
local function playSong(name)
    currentStreamId = math.random(1,2^30)
    gotFirstChunk   = false
    buffer          = {}
    speaker.stop()
    currentSong     = name
    local packet = {
        protocol = "vomp",
        type     = "songRequest",
        sender   = computerId,
        receiver = minifyServerId,
        data     = { name = name, id = currentStreamId }
    }
    modem.transmit(2,2,packet)

    local deadline = os.clock() + 2

    while not gotFirstChunk and os.clock() < deadline do
        os.sleep(0.05)
    end

    if (not gotFirstChunk) and (not (currentStreamId == nil))  then
        output("Error: Connection to server timed out.")
        stopStream()
    end
end

-- Handle incoming modem packets
local function modemEventHandler()
    while true do
        local _,side,channel,reply,pkt = os.pullEvent("modem_message")
        if channel == 2
        and pkt.protocol == "vomp"
        and pkt.receiver == computerId
        then
            if pkt.type == "songListResponse" then
                if not pkt.data then
                    output("No songs available.")
                else
                    output("Available songs:")
                    for i,name in ipairs(pkt.data) do
                        output("  "..tostring(name))
                    end
                end
                receivedList = true

            elseif pkt.type == "songResponse" then
                if not pkt.data then
                    output("Could not find song.")
                    stopStream()
                else
                    local id      = pkt.data.id
                    local content = pkt.data.content
                    if id == currentStreamId then
                        table.insert(buffer,content)
                        if not gotFirstChunk then
                            gotFirstChunk = true
                            os.queueEvent("songStart")
                        end
                    end
                end
            end
        end
    end
end

-- Handle audio playback from buffer
local function playbackLoop()
    while true do
        -- wait for the very first chunk of this song
        while not gotFirstChunk do
            os.sleep(0)   -- just yield, let the modem handler fill buffer & flip gotFirstChunk
        end

        output("Now playing: " .. tostring(currentSong))
        local lastReceive = os.clock()

        -- drain everything that's already in the buffer
        while #buffer > 0 do
            local chunk = table.remove(buffer,1)
            lastReceive = os.clock()
            local pcm = decoder(chunk)
            while not speaker.playAudio(pcm) do
                os.pullEvent("speaker_audio_empty")
            end
        end

        -- now continue playing until either:
        --  • the user hits STOP (playSong/stopStream sets currentStreamId=nil), or
        --  • 1 second passes with no new chunks
        while currentStreamId do
            if #buffer > 0 then
                local chunk = table.remove(buffer,1)
                lastReceive = os.clock()
                local pcm = decoder(chunk)
                while not speaker.playAudio(pcm) do
                    os.pullEvent("speaker_audio_empty")
                end
            else
                -- no data: if 1s since last receive, end playback
                if os.clock() - lastReceive >= 1 then
                    break
                end
                os.sleep(0)
            end
        end

        -- clean up
        speaker.stop()
        output("Playback finished.")

        -- reset gotFirstChunk so the next playSong will wake this loop again
        gotFirstChunk = false
        -- outer while → loop back to waiting for the next song
    end
end

-- Handle keypresses other than alphanumeric characters
local function keyEventHandler()
    while true do
        local _,key = os.pullEvent("key")
        if key == keys.backspace then
            input = input:sub(1,-2)

        elseif key == keys.enter then
            if input ~= "" then
                if input == "list" then
                    receivedList = false
                    modem.transmit(2,2,{
                        protocol = "vomp",
                        type     = "songListRequest",
                        sender   = computerId,
                        receiver = minifyServerId,
                        data     = nil
                    })

                    input = ""
                    reDraw()

                    os.sleep(2)
                    if not receivedList then
                        output("Error: Connection to server timed out.")
                    else
                        receivedList = false
                    end

                elseif input == "stop" then
                    stopStream()
                    
                    input = ""
                    reDraw()

                elseif input:match("^play%s+") then
                    local name = input:match("^play%s+(.+)")

                    input = ""
                    reDraw()

                    if name then
                        stopStream()
                        os.sleep(0.5)
                        playSong(name)
                    else
                        output("Usage: play <songName>")
                    end

                else
                    output("Error: Invalid command.")
                end
            end
        end
        reDraw()
    end
end

-- Handle alphanumeric character keypresses
local function charEventHandler()
    while true do
        local _,char = os.pullEvent("char")
        input = input .. char
        reDraw()
    end
end

-- Initialise UI
term.clear()
reDraw()

-- Start parallel processing
parallel.waitForAll(
    modemEventHandler,
    charEventHandler,
    keyEventHandler,
    playbackLoop
)
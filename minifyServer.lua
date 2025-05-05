-- Minify server
-- Powered by VoMP (Voice Over Minenet Protocol)
-- Requires ender modem

local modem = peripheral.find("modem")
local computerId = os.getComputerID()
modem.open(2)

local streams = {}

term.clear()
term.setCursorPos(1, 1)
print("Minify Server")
print("Powered by minenet")
print("-------------------")

-- Searches ./songs/ folder for music files and returns a list
-- Songs must be stored in .dfpwm format, they can be converted to this at https://music.madefor.cc/
local function fetchSongList()
    -- Normalize path
    local path = "./songs/"

    local entries = fs.list(path)    -- get raw entries
    local result = {}

    for _, name in ipairs(entries) do
        -- name might be "foo.txt", "bar.lua", "baz" or even "dirName"
        -- Strip only the last extension if present:
        local base = name:match("(.+)%.[^%.]+$") or name
        table.insert(result, base)
    end

    return result
end

-- Function to handle loading and breaking up song into packets
local function spawnStream(songData, destination)
    local instance = coroutine.create(function()
        local songName = songData["name"]
        local streamId = songData["id"]
        local songDir = "./songs/" .. songName .. ".dfpwm"

        -- If file does not exist send nil packet
        if not (fs.exists(songDir)) then
            local packet = {
                protocol = "vomp",
                type = "songResponse",
                sender = computerId,
                receiver = destination,
                data = nil
            }

            modem.transmit(2, 2, packet)
            return
        end

        -- If file exists 
        local song = fs.open(songDir, "rb")

        -- Break song into smaller packets to stream
        while true do
            local chunk = song.read(1024)
            if not chunk then song.close() end
            local packet = {
                protocol = "vomp",
                type = "songResponse",
                sender = computerId,
                receiver = destination,
                data = {id = streamId, content = chunk}
            }
            modem.transmit(2, 2, packet)
            coroutine.yield()

        end
    end)
    table.insert(streams, instance)
end

-- Scheduler advances all coroutines by one packet
local function coroutineScheduler()
    while true do
        for i = #streams, 1, -1 do
            local instance = streams[i]
            coroutine.resume(instance)
            if (coroutine.status(instance) == "dead") then
                table.remove(streams, i)
            end
        end
        os.sleep(0)
    end
end

-- Function to handle incoming modem messages
local function modemEventHandler()
    while true do
        local _, _, channel, _, data = os.pullEvent("modem_message")

        if channel == 2 then
            if (data["protocol"] == "vomp") and (data["receiver"] == computerId) then
                if (data["type"] == "songRequest") then
                    spawnStream(data["data"], data["sender"])
                elseif (data["type"] == "songListRequest") then
                    local packet = {
                        protocol = "vomp",
                        type = "songListResponse",
                        sender = computerId,
                        receiver = data["sender"],
                        data = fetchSongList()
                    }

                    modem.transmit(2, 2, packet)
                end
            end
        end
    end
end

parallel.waitForAll(modemEventHandler, coroutineScheduler)
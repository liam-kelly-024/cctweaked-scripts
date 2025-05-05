-- Minenet Relay Chat client
-- Requires server connection
-- Requires basic wireless modem

local modem = peripheral.find("modem")
local computerId = os.getComputerID()
local computerName = os.getComputerLabel()
local mrcServerId = 2 -- Must be manually set
local w, h = term.getSize()

if (computerName == nil) then 
    error("Error: Please set a label for the computer.", 0)
end

modem.open(1)

local function requestChatHistory() -- Requests chatlog from server
    local packet = {
        protocol = "mrc",
        type = "historyRequest",
        sender = computerId,
        receiver = mrcServerId,
        data = nil
    }
    modem.transmit(1, 1 , packet)

    -- 2-second timeout
    local timerId = os.startTimer(2)

    while (true) do
        local event, p1, p2, _, p4 = os.pullEvent()

        if (event == "timer") then
            local eventTimerId = p1
            if (eventTimerId == timerId) then
                error("Error: Connection to server timed out.", 0)
            end
        elseif (event == "modem_message") then
            local channel = p2
            local data = p4

            if (channel == 1) then
                if (data["protocol"] == "mrc") and (data["type"] == "historyResponse") and (data["sender"] == mrcServerId) and (data["receiver"] == computerId) then
                    return data["data"]
                end
            end
        end
    end
end

-- Print chat history
local chatHistory = requestChatHistory()

term.clear()
if not (chatHistory == nil) then
    for _, line in ipairs(chatHistory) do
        local name = line["name"]

        if (name == computerName) then
            name = "You"
        end

        local message = name .. "> " .. line["content"]

        term.setCursorPos(1, h)
        term.write(message)
        term.scroll(1)
    end
end

term.setCursorPos(1, 1)
term.clearLine()
term.write("Minenet Relay Chat Client v1.0")

term.setCursorPos(1, h)
term.write("You> ")
term.setCursorBlink(true)

local input = ""

local function reDraw() -- For redrawing text input
    term.setCursorPos(1, 1)
    term.clearLine()
    term.write("Minenet Relay Chat Client v1.0")

    term.setCursorPos(1, h)
    term.clearLine()
    term.write("You> " .. input)
    term.setCursorBlink(true)
end

while true do
    local event, p1, p2, p3, p4 = os.pullEvent()

    -- Handle incoming modem messages
    if (event == "modem_message") then
        local channel = p2
        local data = p4

        if (channel == 1) then
            -- Check if message is of valid protocol and type and that it comes from the correct server
            if (data["protocol"] == "mrc") and (data["type"] == "messageReceive") and (data["sender"] == mrcServerId) then
                local message = data["data"]["name"] .. "> " .. data["data"]["content"]

                -- Check that message did not come from self
                if not (data["receiver"] == computerId) then
                    -- Print to terminal with correct formatting
                    term.clearLine()
                    term.setCursorPos(1, h)
                    term.write(message)
                    term.scroll(1)

                    reDraw()
                end
            end
        end

    -- Handle alphanumeric character keypresses
    elseif (event == "char") then
        local character = p1
        input = input .. character
        reDraw()

    -- Handle keypresses other than alphanumeric characters
    elseif event == "key" then
        local key = p1

        -- Delete character from input
        if key == keys.backspace then
            input = input:sub(1, -2)
            reDraw()

        -- Send message over MRC
        elseif key == keys.enter then
            if not (input == "") then
                local message = {name = computerName, content = input}
                local packet = {
                    protocol = "mrc",
                    type = "messageSend",
                    sender = computerId,
                    receiver = mrcServerId,
                    data = message
                }
                modem.transmit(1, 1, packet)

                -- 2-second timeout
                local timerId = os.startTimer(2)
                term.setCursorBlink(false)

                while (true) do
                    local eventMsg, a1, a2, _, a4 = os.pullEvent()

                    if (eventMsg == "timer") then
                        local eventTimerId = a1
                        if (eventTimerId == timerId) then
                            term.scroll(1)
                            term.setCursorPos(1, h)
                            error("Error: Connection to server timed out.", 0)
                        end
                    elseif (eventMsg == "modem_message") then
                        local channel = a2
                        local data = a4

                        if (channel == 1) then
                            if (data["protocol"] == "mrc") and (data["type"] == "messageReceive") and (data["sender"] == mrcServerId) and (data["receiver"] == computerId) then
                                break
                            end
                        end
                    end
                end

                -- Display your own message locally
                term.clearLine()
                term.setCursorPos(1, h)
                term.write("You> " .. input)
                term.scroll(1)

                input = ""
                reDraw()
            end
        end
    end
end
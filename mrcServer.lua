-- Minenet Relay Chat server
-- Requires ender modem

local modem = peripheral.find("modem")
local computerId = os.getComputerID()
modem.open(1)

local function loadHistory() -- Load last 20 chat messages
    local history = {}
    if fs.exists("chatlog.txt") then
        local file = fs.open("chatlog.txt", "r")
        while true do
            local line = file.readLine()
            if not line then break end
            local message = textutils.unserializeJSON(line)
            table.insert(history, message)
        end
        file.close()
    else
        return nil
    end

    -- Only return the last 20 messages
    local total = #history
    if total > 20 then
        local recent = {}
        for i = total - 19, total do
            table.insert(recent, history[i])
        end
        return recent
    else
        return history
    end
end

term.clear()
term.setCursorPos(1, 1)
print("Minenet Relay Chat")
print("Powered by minenet")
print("-------------------")

while true do
    local _, _, channel, replyChannel, data = os.pullEvent("modem_message")

    if channel == 1 then
        if (data["protocol"] == "mrc") and (data["receiver"] == computerId) then
            if (data["type"] == "historyRequest") then
                local packet = {
                    protocol = "mrc",
                    type = "historyResponse",
                    sender = os.getComputerID(),
                    receiver = data["sender"],
                    data = loadHistory()
                }

                modem.transmit(replyChannel, 1, packet)
            elseif (data["type"] == "messageSend") then
                local packet = {
                    protocol = "mrc",
                    type = "messageReceive",
                    sender = os.getComputerID(),
                    receiver = data["sender"],
                    data = data["data"]
                }

                print(data["data"]["name"] .. "> " .. data["data"]["content"])

                -- Save to logs
                local message = data["data"]
                local file = fs.open("chatlog.txt", "a")
                file.writeLine(textutils.serializeJSON(message))
                file.close()

                modem.transmit(replyChannel, 1, packet)
            end
        end
    end
end
-- Server program for minefax 
-- requires ender modem

local modem = peripheral.find("modem") or error("No modem attached", 0)
modem.open(40)

local function loadContacts()
    local file = fs.open("contacts.txt", "r")
    if not file then
        error("Error: Failed to open contacts")
    end

    local content = ""

    while true do
        local line = file.readLine()
        if not line then break end
        content = content .. line .. " "
    end

    file.close()
    return content:match("^%s*(.-)%s*$")  -- Trim any leading/trailing whitespace
end

local contacts = loadContacts()

term.clear()
term.setCursorPos(1, 1)
print("Relaying fax...")
print("I/O stream:")
print("\n")
while true do
    local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
    
    if channel == 40 then
        print(message)
        local flag = string.sub(message, 1, 3)
        local destination = string.sub(message, 4, 6)

        if flag == "SND" then --Code for relaying fax messags
            if destination == "BRD" then
                local sender = string.sub(message, 7, 9)
                message = string.sub(message, 10)
            
                local transmitMessage = "REC" .. "BRD" .. sender .. message
                print(transmitMessage)
                modem.transmit(41, 0, transmitMessage) 
            elseif destination == "ACK" then
                local newDestination = string.sub(message, 7, 9)
                local transmitMessage = "ACK" .. newDestination
                print(transmitMessage)
                modem.transmit(41, 0, transmitMessage)
            else
                message = string.sub(message, 7)

                local transmitMessage = "REC" .. destination .. message
                print(transmitMessage)
                modem.transmit(41, 0, transmitMessage)
            end
        elseif flag == "REQ" then --Code for sending contact information
            local transmitMessage = "CTS" .. destination .. contacts
            print(transmitMessage)
            modem.transmit(41, 0, transmitMessage)
        end
    end
end
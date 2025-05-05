-- Minecraft cc tweaked lua fax client
-- Requires server connection
-- Requires basic wireless modem and printer

local modem = peripheral.find("modem") or error("Error: No modem attached", 0)
local printer = peripheral.find("printer") or error("Error: No printer attached", 0)
modem.open(41)

local pageWidth = 25
local pageHeight = 40
local computerId = os.getComputerID()

-- Parse contacts from received message
local function parseToTable(input)
    local result = {}
    local words = {}

    for word in input:gmatch("%S+") do
        table.insert(words, word)
    end

    for i = 1, #words, 2 do
        local key = words[i]
        local value = words[i + 1]
        if key and value then
            result[key] = value
        end
    end

    return result
end

-- Request contacts from server
local function loadContacts()
    modem.transmit(40, 0, "REQ" .. string.format("%03d", computerId))
    
    local timerId = os.startTimer(2) -- 2-second timeout

    while true do
        local event, side, channel, replyChannel, message = os.pullEvent()

        if event == "modem_message" and channel == 41 then
            local flag = string.sub(message, 1, 3)
            local destination = string.sub(message, 4, 6)
            message = string.sub(message, 7)

            if flag == "CTS" and tonumber(destination) == computerId then
                return parseToTable(message)
            end
        elseif event == "timer" and side == timerId then
            error("Error: Timeout waiting for server response.")
        end
    end
end

-- Wrap text to more lines or pages as neccessary
local function wrapText(text, width)
    local lines = {}
    local line = ""

    local function splitLongWord(word)
        local parts = {}
        local i = 1
        while i <= #word do
            table.insert(parts, word:sub(i, i + width - 1))
            i = i + width
        end
        return parts
    end

    for word in text:gmatch("%S+") do
        -- Split the word into chunks if it's longer than width
        local wordParts = #word > width and splitLongWord(word) or { word }

        for _, part in ipairs(wordParts) do
            if #line + #part + 1 <= width then
                if line == "" then
                    line = part
                else
                    line = line .. " " .. part
                end
            else
                table.insert(lines, line)
                line = part
            end
        end
    end

    if line ~= "" then
        table.insert(lines, line)
    end

    return lines
end

-- Print wrapped text with cursor position and page management
local function printText(text)
    local lines = wrapText(text, pageWidth)
    local y = 1

    printer.setPageTitle("MineFax message")
    for _, line in ipairs(lines) do
        if y > pageHeight then
            printer.endPage()
            if not printer.newPage() then
                print("\nError: Failed to print, check printer.")
                term.write("MineFax> ")
                term.setCursorBlink(true)
                return false
            end
            printer.setPageTitle("MineFax message")
            y = 1
        end
        printer.setCursorPos(1, y)
        printer.write(line)
        y = y + 1
    end
    printer.endPage()
end

local contacts = loadContacts()

term.clear()
term.setCursorPos(0,1)
print("\n                    MineFax")
print("                     ---------\n")
print("       *************************************")
print("       *The Premiere Hyperborean Fax Client*")
print("       *************************************\n")
print("To send a message write the recipients name followed by the contents of the message.\n")

term.write("MineFax> ")
term.setCursorBlink(true)
while true do
    local event, side, channel, replyChannel, message = os.pullEvent()
    if event == "modem_message" then --Check for modem message
        if channel == 41 then
            local flag = string.sub(message, 1, 3)
            local destination = string.sub(message, 4, 6)
            local sender = string.sub(message, 7, 9)

            if (flag == "REC" and tonumber(destination) == computerId) then
                message = string.sub(message, 10)

                if not printer.newPage() then
                    print("\nError: Failed to print, check printer.")
                    term.write("MineFax> ")
                    term.setCursorBlink(true)
                else
                    print("\nYou got mail!")
                    
                    local transmitMessage = "SND" .. "ACK" .. sender
                    modem.transmit(40, 0, transmitMessage)

                    term.write("MineFax> ")
                    term.setCursorBlink(true)
                    printText(message)
                end
            elseif (flag == "REC" and destination == "BRD") then
                if not (tonumber(sender) == computerId) then
                    message = string.sub(message, 10)

                    if not printer.newPage() then
                        print("\nError: Failed to print, check printer.")
                        term.write("MineFax> ")
                        term.setCursorBlink(true)
                    else
                        print("\nYou got mail!")
                        term.write("MineFax> ")
                        term.setCursorBlink(true)
                        printText(message)
                    end
                end
            end
        end
    elseif event == "key" then --Allow sending fax
        local toSend = read()
        contacts = loadContacts()
        local destination, messageBody = toSend:match("^(%S+)%s*(.*)$")
        toSend = messageBody

        if destination == "ALL" then
            modem.transmit(40, 0, ("SND" .. "BRD" .. string.format("%03d", computerId) .. toSend))
        elseif contacts[destination] then
            modem.transmit(40, 0, "SND" .. contacts[destination] .. string.format("%03d", computerId) .. toSend)
            term.write("Message sending... ")
        
            local timerId = os.startTimer(2) -- 2-second timeout
        
            while true do
                local event, side, channel, replyChannel, message = os.pullEvent()
        
                if event == "modem_message" and channel == 41 then
                    local flag = string.sub(message, 1, 3)
                    local destination = string.sub(message, 4, 6)
        
                    if flag == "ACK" and tonumber(destination) == tonumber(computerId) then
                        term.write("Success!")
                        print()
                        break
                    end
                elseif event == "timer" and side == timerId then
                    term.write("Failed to send.")
                    print()
                    break
                end
            end
        else
            print("Error: Contact does not exist")
        end

        term.write("MineFax> ")
        term.setCursorBlink(true)
    end
end
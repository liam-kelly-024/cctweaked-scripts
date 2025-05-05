-- Minefax client v2
-- Unfinished rewrite, does not currently work

local modem = peripheral.find("modem") or error("Error: No modem attached", 0)
local printer = peripheral.find("printer") or error("Error: No printer attached", 0)
local rsa = require("rsa") -- Modified version of RSA encryption library from 1lann

local pageWidth = 25
local pageHeight = 21
local computerId = os.getComputerID()
local computerName = os.getComputerLabel() or computerId
local faxServerId = 2 -- Must be manually set
local w, h = term.getSize()
local timeoutId = nil

local encrypted = false
local input = ""
local contacts = {}

modem.open(3)

-- Redraws UI
local function reDraw()
    term.setCursorPos(1,1) term.clearLine()
    term.setCursorPos(1,2) term.clearLine() term.write("               *********************")
    term.setCursorPos(1,3) term.clearLine() term.write("               *  Minefax  client  *")
    term.setCursorPos(1,4) term.clearLine() term.write("               *********************")
    term.setCursorPos(1,5) term.clearLine()
    term.setCursorPos(1,6) term.clearLine() term.write("        The Premiere Hyperborean Fax Client")
    term.setCursorPos(1,7) term.clearLine() term.write("            Type halp for commands list")
    term.setCursorPos(1,8) term.clearLine()
    term.setCursorPos(1,h) term.clearLine() term.write("Minefax> ".. input)
    term.setCursorBlink(true)
end

-- Prints to terminal with correct formatting
local function output(text)
    term.scroll(1)
    term.setCursorPos(1, h - 1)
    term.clearLine()
    term.write(text)
    reDraw()
end

-- Request contacts list from server
local function requestContacts()
    local packet = {
        protocol = "fomp",
        type     = "contactsListRequest",
        sender   = computerId,
        receiver = faxServerId,
        data     = nil
    }

    modem.transmit(3, 3, packet)
    timeoutId = os.startTimer(2)
end

-- Wrap text to correctly fit on printed page
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

    printer.setPageTitle("Minefax message")
    for _, line in ipairs(lines) do
        if y > pageHeight then
            printer.endPage()
            if not printer.newPage() then
                print("\nError: Failed to print, check printer.")
                term.write("Minefax> ")
                term.setCursorBlink(true)
                return false
            end
            printer.setPageTitle("Minefax message")
            y = 1
        end
        printer.setCursorPos(1, y)
        printer.write(line)
        y = y + 1
    end
    printer.endPage()
end

-- Main loop
local function main()
    requestContacts()
    while true do
        local event, a, b, c, d = os.pullEvent()

        -- Handle incoming modem messages
        if event == "modem_message" then
            local msgContent = d

            if (msgContent["receiver"] == computerId) and (msgContent["sender"] == faxServerId) and (msgContent["protocol"] == "fomp") then
                if msgContent["type"] == "contactsListResponse" then
                    os.cancelTimer(timeoutId)
                    timeoutId = nil

                    contacts = msgContent["data"]
                end
            end

        -- Add character to input buffer
        elseif event == "char" then
            local char = a

            input = input .. char
            reDraw()
        
        -- Handle non-alphanumeric keyboard input
        elseif event == "key" then
            local key = a

            -- Delete character from input buffer
            if key == keys.backspace then
                input = input:sub(1,-2)
    
            -- Determine command from input buffer
            elseif key == keys.enter then
                if input ~= "" then
                    if input == "send" then
                        
                    elseif input:match("^send%s+") then
                        local message = input:match("^send%s+(.+)")
                        local packet

                        if encrypted then
                            packet = {
                                protocol = "fomp",
                                type     = "faxSend",
                                sender   = computerId,
                                receiver = faxServerId,
                                data     = rsa.encryptString()
                            }
                        else

                        end

                    -- Allow toggling encryption
                    elseif input:match("^encrypt%s+") then
                        local message = input:match("^encrypt%s+(.+)")

                        if message == "on" then
                            encrypted = true

                        elseif message == "off" then
                            encrypted = false

                        end

                    else
                        output("Error: Invalid command.")
                    end

                    input = ""
                end
            end

            reDraw()
        elseif event == "timer" then
            error("Error: Server connection timed out.", 0)
        end
    end
end

term.clear()
reDraw()

main()
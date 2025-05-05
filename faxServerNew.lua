-- Minefax server v2
-- Unfinished rewrite, does not currently work

local computerId = os.getComputerID()
local modem = peripheral.find("modem")
modem.open(3)

local _, _, _, _, data = os.pullEvent("modem_message")
if data["type"] == "contactsListRequest" then
    local packet = {
        protocol = "fomp",
        type     = "contactsListResponse",
        sender   = computerId,
        receiver = data["sender"],
        data     = {}
    }

    modem.transmit(3, 3, packet)
end
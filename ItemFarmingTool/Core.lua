-- SPDX-License-Identifier: GPL-3.0-or-later
local addon, ns = ...
ns.MAX_ITEMS, ns.MAX_GOAL = 100, 999999

local function integer(value, maximum)
    local number = tonumber(value)
    if number and number == number and number >= 1 and number <= maximum and number % 1 == 0 then
        return number
    end
end
ns.Integer = integer

function ns.Print(message)
    print("|cff66d9b3ItemFarmingTool:|r " .. tostring(message))
end

function ns.LoadSettings()
    if ns.db then return end
    if type(ItemFarmingToolDB) ~= "table" then ItemFarmingToolDB = {} end
    ns.db = ItemFarmingToolDB
    local clean, seen = {}, {}
    if type(ns.db.items) == "table" then
        for _, entry in ipairs(ns.db.items) do
            if type(entry) == "table" then
                local id, goal = integer(entry.id, 2147483647), integer(entry.goal, ns.MAX_GOAL)
                if id and goal and not seen[id] and #clean < ns.MAX_ITEMS then
                    clean[#clean + 1] = { id = id, goal = goal }
                    seen[id] = true
                end
            end
        end
    end
    ns.db.items = clean
    local bank = {}
    if type(ns.db.bankCounts) == "table" then
        for id in pairs(seen) do
            local count = ns.db.bankCounts[id]
            if type(count) == "number" and count >= 0 and count <= 2147483647 and count % 1 == 0 then
                bank[id] = count
            end
        end
    end
    ns.db.bankCounts = bank
    if not integer(ns.db.bankUpdatedAt, 32503680000) then ns.db.bankUpdatedAt = nil end
    ns.db.hidden = ns.db.hidden == true
    ns.db.locked = ns.db.locked == true
    ns.db.collapsed = ns.db.collapsed == true
    local p = ns.db.position
    local points = {TOPLEFT=true, TOP=true, TOPRIGHT=true, LEFT=true, CENTER=true,
        RIGHT=true, BOTTOMLEFT=true, BOTTOM=true, BOTTOMRIGHT=true}
    local function offset(n)
        return type(n) == "number" and n == n and math.abs(n) < 100000
    end
    if type(p) ~= "table" or not points[p.point] or not points[p.relativePoint]
        or not offset(p.x) or not offset(p.y) then ns.db.position = nil end
end

function ns.Find(id)
    for index, entry in ipairs(ns.db.items) do
        if entry.id == id then return entry, index end
    end
end

function ns.ItemInfo(item)
    local get = C_Item and C_Item.GetItemInfo or GetItemInfo
    if get then return get(item) end
end

function ns.ResolveItem(text)
    if type(text) ~= "string" then return nil end
    text = text:match("^%s*(.-)%s*$")
    local id = integer(text, 2147483647) or integer(text:match("item:(%d+)"), 2147483647)
    if id then return id end
    local _, link = ns.ItemInfo(text)
    return link and integer(link:match("item:(%d+)"), 2147483647)
end

function ns.AddItem(text, goal)
    local id = ns.ResolveItem(text)
    goal = integer(goal, ns.MAX_GOAL)
    if not id then return false, "Enter an item ID, item link, or a cached exact item name." end
    if not goal then return false, "Goal must be a whole number from 1 to " .. ns.MAX_GOAL .. "." end
    local entry = ns.Find(id)
    if entry then
        entry.goal = goal
    else
        if #ns.db.items >= ns.MAX_ITEMS then return false, "Track up to 100 items; remove one first." end
        ns.db.items[#ns.db.items + 1] = { id = id, goal = goal }
    end
    -- Keep the ID even when item data is not cached. The item-info event updates the label.
    local name = ns.ItemInfo(id)
    if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    ns.Refresh()
    return true
end

function ns.RemoveItem(id)
    local _, index = ns.Find(id)
    if index then
        table.remove(ns.db.items, index)
        ns.db.bankCounts[id] = nil
        ns.Refresh()
    end
end

-- Scan only actual carried bag slots. GetItemCount can include equipped items;
-- bank storage is counted separately so equipment never inflates the goals.
function ns.CountBags()
    local counts = {}
    local slots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    local info = C_Container and C_Container.GetContainerItemInfo or GetContainerItemInfo
    if not slots or not info then return counts end
    local last = NUM_BAG_SLOTS or 4
    local reagent = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
    if type(reagent) == "number" and reagent > last then last = reagent end
    for bag = 0, last do
        for slot = 1, slots(bag) do
            local first, stack, _, _, _, _, link, _, _, legacyID = info(bag, slot)
            local id
            if type(first) == "table" then
                id, stack = first.itemID, first.stackCount
                if not id and first.hyperlink then id = tonumber(first.hyperlink:match("item:(%d+)")) end
            else
                id = legacyID or (link and tonumber(link:match("item:(%d+)")))
            end
            if integer(id, 2147483647) and type(stack) == "number" and stack > 0 then
                counts[id] = (counts[id] or 0) + stack
            end
        end
    end
    return counts
end

function ns.UpdateBank()
    if not ns.bankOpen then return end
    local get = C_Item and C_Item.GetItemCount or GetItemCount
    if not get then return end
    local updated = false
    for _, entry in ipairs(ns.db.items) do
        -- Both calls include equipment, so subtracting cancels it out. Request
        -- personal/reagent bank storage only; account/guild banks are excluded.
        local okTotal, total = pcall(get, entry.id, true, false, true, false)
        local okCarried, carried = pcall(get, entry.id, false, false, false, false)
        if okTotal and okCarried and type(total) == "number" and type(carried) == "number"
            and total >= carried and total <= 2147483647 and carried >= 0
            and total % 1 == 0 and carried % 1 == 0 then
            ns.db.bankCounts[entry.id] = total - carried
            updated = true
        else
            -- A failed scan must not present an older value as freshly checked.
            ns.db.bankCounts[entry.id] = nil
        end
    end
    if updated then ns.db.bankUpdatedAt = time() end
end

function ns.Refresh()
    ns.counts = ns.CountBags()
    ns.UpdateBank()
    if ns.Render then ns.Render() end
end

function ns.RequestRefresh()
    if ns.refreshPending then return end
    ns.refreshPending = true
    local function update()
        ns.refreshPending = nil
        if ns.db then ns.Refresh() end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.1, update) else update() end
end

function ns.Command(message)
    local command, rest = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "" or command == "show" then
        ns.db.hidden = false; ns.Render()
    elseif command == "hide" then
        ns.db.hidden = true; ns.Render()
    elseif command == "lock" or command == "unlock" then
        ns.db.locked = command == "lock"; ns.Render()
    elseif command == "reset" then
        ns.db.position = nil; ns.db.hidden = false
        ns.ApplyPosition(); ns.Render()
    elseif command == "add" then
        local item, goal = rest:match("^(.-)%s+(%S+)$")
        local ok, err = ns.AddItem(item, goal)
        if not ok then ns.Print(err) end
    elseif command == "remove" then
        local id = ns.ResolveItem(rest)
        if id and ns.Find(id) then ns.RemoveItem(id) else ns.Print("That item is not tracked.") end
    else
        ns.Print("/ift show | hide | lock | unlock | reset")
        ns.Print("/ift add <item ID, link or exact name> <goal> | /ift remove <item>")
    end
end

local events = CreateFrame("Frame")
ns.events = events
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" and name == addon then
        ns.LoadSettings()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        ns.LoadSettings()
        ns.CreateUI()
        SlashCmdList.ITEMFARMINGTOOL = ns.Command
        SLASH_ITEMFARMINGTOOL1, SLASH_ITEMFARMINGTOOL2 = "/ift", "/itemfarmingtool"
        for _, e in ipairs({"BAG_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD", "GET_ITEM_INFO_RECEIVED",
            "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED"}) do
            self:RegisterEvent(e)
        end
        ns.Refresh()
    elseif ns.db then
        if event == "BANKFRAME_OPENED" then
            ns.bankOpen = true
        elseif event == "BANKFRAME_CLOSED" or event == "PLAYER_ENTERING_WORLD" then
            ns.bankOpen = false
        end
        -- Capture inventory changes immediately while bank data is accessible,
        -- even when the bank closes before the batched visual update runs.
        if ns.bankOpen then ns.UpdateBank() end
        if event ~= "GET_ITEM_INFO_RECEIVED" or ns.Find(name) then ns.RequestRefresh() end
    end
end)

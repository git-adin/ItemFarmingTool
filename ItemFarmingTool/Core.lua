-- SPDX-License-Identifier: GPL-3.0-or-later
local addon, ns = ...
ns.MAX_ITEMS, ns.MAX_GOAL = 100, 999999
local publicAPI

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
        for key, count in pairs(ns.db.bankCounts) do
            local id = integer(key, 2147483647)
            if id and type(count) == "number" and count >= 0 and count <= 2147483647 and count % 1 == 0 then
                bank[id] = count
            end
        end
    end
    ns.db.bankCounts = bank
    ns.db.includeBank = ns.db.includeBank ~= false
    if not integer(ns.db.bankUpdatedAt, 32503680000) then ns.db.bankUpdatedAt = nil end
    ns.db.bankSnapshotComplete = ns.db.bankSnapshotComplete == true and ns.db.bankUpdatedAt ~= nil
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
    ItemFarmingToolAPI = publicAPI
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

local function RequestItemData(id)
    -- Keep the ID even when item data is not cached. The item-info event updates the label.
    if not ns.ItemInfo(id) and C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(id)
    end
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
    RequestItemData(id)
    ns.Refresh()
    return true
end

function ns.RemoveItem(id)
    local _, index = ns.Find(id)
    if index then
        table.remove(ns.db.items, index)
        ns.Refresh()
    end
end

function ns.ClearItems()
    ns.db.items = {}
    ns.Refresh() -- Bank snapshots and other saved settings are independent.
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

function ns.BankCount(id)
    local count = ns.db.bankCounts[id]
    if count ~= nil then return count end
    if ns.db.bankSnapshotComplete then return 0 end
end

local function bankContainers()
    local indices = Enum and Enum.BagIndex or {}
    local containers, allowed = {}, {}
    -- Forever has nine character-bank containers, not the legacy -1 bank.
    -- Enumerate their names so account tabs and the keyring cannot be included.
    for name, id in pairs(indices) do
        if name:match("^CharacterBankTab_%d+$") then allowed[id] = true end
    end
    if next(allowed) then
        local character = Enum.BankType and Enum.BankType.Character
        if C_Bank and character and C_Bank.CanUseBank and not C_Bank.CanUseBank(character) then return end
        if C_Bank and character and C_Bank.FetchPurchasedBankTabData then
            local tabs = C_Bank.FetchPurchasedBankTabData(character)
            if type(tabs) ~= "table" or #tabs == 0 then return end
            local seen = {}
            for _, tab in ipairs(tabs) do
                if type(tab) ~= "table" or not allowed[tab.ID] or seen[tab.ID] then return end
                containers[#containers + 1], seen[tab.ID] = tab.ID, true
            end
        else
            for id in pairs(allowed) do containers[#containers + 1] = id end
        end
    else
        -- Legacy clients expose the main bank plus purchased bank bag slots.
        containers[1] = indices.Bank or BANK_CONTAINER or -1
        for name, id in pairs(indices) do
            if name:match("^BankBag_%d+$") then containers[#containers + 1] = id end
        end
        if #containers == 1 then
            for bag = 1, (NUM_BANKBAGSLOTS or 7) do
                containers[#containers + 1] = (NUM_BAG_SLOTS or 4) + bag
            end
        end
        local reagent = indices.Reagentbank or REAGENTBANK_CONTAINER
        if reagent then containers[#containers + 1] = reagent end
    end
    table.sort(containers)
    return containers, next(allowed) and indices.CharacterBankTab_1 or (indices.Bank or BANK_CONTAINER or -1)
end

local function scanBank()
    local containers, mainBank = bankContainers()
    local slots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    local info = C_Container and C_Container.GetContainerItemInfo or GetContainerItemInfo
    local itemID = C_Container and C_Container.GetContainerItemID or GetContainerItemID
    if not containers or not slots or not info then return end
    local counts, totalSlots, mainReady = {}, 0, false
    for _, bag in ipairs(containers) do
        local size = slots(bag)
        if type(size) ~= "number" or size < 0 or size > 1000 or size % 1 ~= 0 then return end
        totalSlots = totalSlots + size
        if bag == mainBank and size > 0 then mainReady = true end
        for slot = 1, size do
            local first, stack, _, _, _, _, link, _, _, legacyID = info(bag, slot)
            local id
            if type(first) == "table" then
                id, stack = first.itemID, first.stackCount
                if not id and first.hyperlink then id = tonumber(first.hyperlink:match("item:(%d+)")) end
            else
                id = legacyID or (link and tonumber(link:match("item:(%d+)")))
            end
            local knownID = itemID and itemID(bag, slot)
            id = id or knownID
            -- Reject partially available occupied slots; never publish half a bank.
            if first or knownID then
                if not integer(id, 2147483647) or not integer(stack, 2147483647) then return end
                counts[id] = (counts[id] or 0) + stack
            end
        end
    end
    if totalSlots == 0 or not mainReady then return end -- Not loaded is different from empty.
    return counts
end

function ns.UpdateBank()
    if not ns.bankOpen or not ns.bankScanReady then return false end
    local ok, counts = pcall(scanBank)
    if not ok or not counts then
        ns.bankScanFailed = true
        return false -- Keep the last valid snapshot and its original timestamp.
    end
    ns.db.bankCounts = counts
    ns.db.bankSnapshotComplete = true
    ns.db.bankUpdatedAt = time()
    ns.bankScanFailed, ns.bankScanPending = false, false
    return true
end

function ns.BeginBankScan()
    ns.bankGeneration = (ns.bankGeneration or 0) + 1
    local generation, attempts = ns.bankGeneration, 0
    ns.bankScanReady, ns.bankScanPending = false, true
    local function scan()
        if not ns.bankOpen or ns.bankGeneration ~= generation then return end
        attempts = attempts + 1
        ns.bankScanReady = true
        local ok = ns.UpdateBank()
        if not ok and attempts < 4 and C_Timer and C_Timer.After then
            C_Timer.After(0.3, scan)
        else ns.bankScanPending = false end
        if ns.Render then ns.Render() end
    end
    -- BANKFRAME_OPENED can precede the container data. Wait briefly and retry
    -- only a bounded number of times; closing/reloading cancels the callbacks.
    if C_Timer and C_Timer.After then C_Timer.After(0.2, scan) else scan() end
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

local function GetTrackedGoals()
    local goals = {}
    for _, entry in ipairs(ns.db.items) do
        goals[entry.id] = entry.goal
    end
    return goals
end

local function ApplyMinimumGoals(goals, showTracker)
    local isSecret = issecretvalue
    if (isSecret and isSecret(goals)) or type(goals) ~= "table" then
        return false, "Provide a list of item goals."
    end
    if (isSecret and isSecret(showTracker)) or (showTracker ~= nil and type(showTracker) ~= "boolean") then
        return false, "The tracker visibility option must be true or false."
    end
    local count = #goals
    for index in pairs(goals) do
        if type(index) ~= "number" or not integer(index, count) then
            return false, "Provide a list of item goals with no gaps."
        end
    end

    local existing = {}
    for _, entry in ipairs(ns.db.items) do
        existing[entry.id] = entry
    end
    local pending, order = {}, {}
    local newCount = 0
    for index = 1, count do
        local goal = rawget(goals, index)
        if (isSecret and isSecret(goal)) or type(goal) ~= "table" then
            return false, "Each goal must contain an item ID and quantity."
        end
        local id, quantity = rawget(goal, "id"), rawget(goal, "quantity")
        if (isSecret and (isSecret(id) or isSecret(quantity)))
            or type(id) ~= "number" or not integer(id, 2147483647)
            or type(quantity) ~= "number" or not integer(quantity, ns.MAX_GOAL) then
            return false, "Cannot export an unresolved item or invalid quantity."
        end
        if not pending[id] then
            order[#order + 1] = id
            if not existing[id] then newCount = newCount + 1 end
        end
        pending[id] = math.max(pending[id] or 0, quantity)
    end
    if #ns.db.items + newCount > ns.MAX_ITEMS then
        return false, "ItemFarmingTool would exceed " .. ns.MAX_ITEMS .. " items. Remove some goals first."
    end

    local changed = {}
    for _, id in ipairs(order) do
        local entry = existing[id]
        if not entry then
            ns.db.items[#ns.db.items + 1] = { id = id, goal = pending[id] }
            changed[#changed + 1] = id
        elseif entry.goal < pending[id] then
            entry.goal = pending[id]
            changed[#changed + 1] = id
        end
    end
    local reveal = showTracker == true and ns.db.hidden
    if reveal then ns.db.hidden = false end
    for _, id in ipairs(changed) do RequestItemData(id) end
    if reveal or #changed > 0 then ns.Refresh() end
    return true
end

publicAPI = {
    GetTrackedGoals = GetTrackedGoals,
    ApplyMinimumGoals = ApplyMinimumGoals,
}

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
            "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED", "BANK_TABS_CHANGED", "PLAYER_LOGOUT"}) do
            self:RegisterEvent(e)
        end
        ns.Refresh()
    elseif ns.db then
        if event == "BANKFRAME_OPENED" then
            ns.bankOpen = true
            ns.BeginBankScan()
        elseif event == "BANKFRAME_CLOSED" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGOUT" then
            ns.bankOpen = false
            ns.bankScanReady, ns.bankScanPending = false, false
            ns.bankGeneration = (ns.bankGeneration or 0) + 1
        end
        -- Capture inventory changes immediately while bank data is accessible,
        -- even when the bank closes before the batched visual update runs.
        if ns.bankOpen and (event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED"
            or event == "PLAYERBANKSLOTS_CHANGED" or event == "BANK_TABS_CHANGED") then ns.UpdateBank() end
        if event == "PLAYER_LOGOUT" then return end -- WoW saves the existing DB table.
        if event ~= "GET_ITEM_INFO_RECEIVED" or ns.Find(name) then ns.RequestRefresh() end
    end
end)

-- SPDX-License-Identifier: GPL-3.0-or-later
local _, ns = ...
local WIDTH, ROW_HEIGHT, VISIBLE_ROWS = 340, 44, 8
local rows = {}
local frame, editor, scroll, content, itemInput, goalInput, errorText, empty, summary, collapse, lock

local function label(parent, text, size)
    local font = parent:CreateFontString(nil, "OVERLAY", size or "GameFontHighlightSmall")
    font:SetText(text)
    return font
end

local function button(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function input(parent, width, numeric)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, 22)
    box:SetAutoFocus(false)
    box:SetMaxLetters(numeric and 6 or 512)
    if numeric then box:SetNumeric(true) end
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return box
end

function ns.ApplyPosition()
    frame:ClearAllPoints()
    local p = ns.db.position
    if p then frame:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
    else frame:SetPoint("CENTER", UIParent, "CENTER", 250, 100) end
end

local function openEditor(id)
    ns.db.collapsed = false
    editor:Show()
    local entry = id and ns.Find(id)
    itemInput:SetText(id and tostring(id) or "")
    goalInput:SetText(entry and tostring(entry.goal) or "1")
    errorText:SetText("")
    ns.Render()
    if id then goalInput:SetFocus(); goalInput:HighlightText() else itemInput:SetFocus() end
end

local function save()
    local ok, err = ns.AddItem(itemInput:GetText(), goalInput:GetText())
    if not ok then errorText:SetText(err); return end
    itemInput:ClearFocus(); goalInput:ClearFocus()
    editor:Hide()
    ns.Render()
end

local function receiveItem()
    local kind, id = GetCursorInfo()
    if kind ~= "item" then return end
    openEditor(id)
    ClearCursor()
end

local function makeRow(index)
    local row = CreateFrame("Button", nil, content)
    row:SetSize(302, ROW_HEIGHT - 2)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(28, 28)
    row.icon:SetPoint("LEFT", 2, 2)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.name = label(row, "", "GameFontHighlightSmall")
    row.name:SetPoint("TOPLEFT", 38, -3)
    row.name:SetSize(158, 14)
    row.name:SetJustifyH("LEFT")
    row.count = label(row, "")
    row.count:SetPoint("TOPRIGHT", -24, -3)
    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetSize(236, 5)
    row.bar:SetPoint("TOPLEFT", 38, -21)
    row.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    row.bar:SetMinMaxValues(0, 1)
    local background = row.bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.15, 0.18, 0.21, 0.9)
    row.detail = label(row, "")
    row.detail:SetPoint("TOPLEFT", 38, -29)
    row.detail:SetTextColor(0.55, 0.62, 0.67)
    row.remove = button(row, "x", 20, function() ns.RemoveItem(row.id) end)
    row.remove:SetPoint("TOPRIGHT", 1, 0)
    row:SetScript("OnClick", function() openEditor(row.id) end)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetHyperlink("item:" .. self.id)
        GameTooltip:AddLine("Click to edit goal. x removes this item.", 0.4, 0.85, 0.7)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

function ns.Render()
    if not frame then return end
    local total, complete = #ns.db.items, 0
    for index, entry in ipairs(ns.db.items) do
        local row = rows[index]
        if not row then row = makeRow(index); rows[index] = row end
        row.id = entry.id
        local name, _, _, _, _, _, _, _, _, icon = ns.ItemInfo(entry.id)
        local count = ns.counts and ns.counts[entry.id] or 0
        local done = count >= entry.goal
        if done then complete = complete + 1 end
        row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.name:SetText(name or ("Item #" .. entry.id))
        row.count:SetText(count .. " / " .. entry.goal)
        row.count:SetTextColor(done and 0.4 or 1, done and 0.9 or 0.85, done and 0.65 or 0.5)
        row.bar:SetValue(math.min(count / entry.goal, 1))
        row.bar:SetStatusBarColor(done and 0.3 or 0.25, done and 0.85 or 0.65, done and 0.55 or 0.95)
        row.detail:SetText(done and "Goal reached" or ((entry.goal - count) .. " still needed"))
        row:Show()
    end
    for index = total + 1, #rows do rows[index]:Hide() end
    summary:SetText(complete .. " / " .. total .. " goals  |  Bags only")
    collapse:SetText(ns.db.collapsed and "+" or "-")
    lock:SetText(ns.db.locked and "Unlock" or "Lock")
    if ns.db.collapsed then
        editor:Hide(); itemInput:ClearFocus(); goalInput:ClearFocus()
        scroll:Hide(); empty:Hide(); summary:Hide()
        frame:SetHeight(36)
    else
        local editorHeight = editor:IsShown() and 138 or 0
        local height = math.max(1, math.min(total, VISIBLE_ROWS)) * ROW_HEIGHT
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", 12, -40 - editorHeight)
        scroll:SetSize(304, height)
        content:SetHeight(math.max(height, total * ROW_HEIGHT))
        scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(), math.max(0, total * ROW_HEIGHT - height)))
        scroll:Show()
        empty:SetShown(total == 0)
        summary:Show()
        frame:SetHeight(40 + editorHeight + height + 28)
    end
    frame:SetShown(not ns.db.hidden)
end

function ns.CreateUI()
    frame = CreateFrame("Frame", "ItemFarmingToolFrame", UIParent, "BackdropTemplate")
    ns.frame = frame
    frame:SetSize(WIDTH, 112)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
    frame:SetBackdropColor(0.035, 0.05, 0.065, 0.94)
    frame:SetBackdropBorderColor(0.18, 0.3, 0.34, 1)
    frame:SetScript("OnDragStart", function(self) if not ns.db.locked then self:StartMoving() end end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        ns.db.position = {point=point, relativePoint=relativePoint, x=x, y=y}
    end)
    frame:SetScript("OnReceiveDrag", receiveItem)
    frame:SetScript("OnHide", function()
        frame:StopMovingOrSizing()
        itemInput:ClearFocus(); goalInput:ClearFocus()
    end)
    local title = label(frame, "Item Farming", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -12)
    title:SetTextColor(0.4, 0.85, 0.7)
    local close = button(frame, "x", 22, function() ns.db.hidden = true; ns.Render() end)
    close:SetPoint("TOPRIGHT", -6, -7)
    collapse = button(frame, "-", 22, function() ns.db.collapsed = not ns.db.collapsed; ns.Render() end)
    collapse:SetPoint("RIGHT", close, "LEFT", -2, 0)
    local add = button(frame, "Add", 40, function()
        if editor:IsShown() then editor:Hide(); itemInput:ClearFocus(); goalInput:ClearFocus(); ns.Render()
        else openEditor() end
    end)
    add:SetPoint("RIGHT", collapse, "LEFT", -2, 0)
    lock = button(frame, "Lock", 52, function() ns.db.locked = not ns.db.locked; ns.Render() end)
    lock:SetPoint("RIGHT", add, "LEFT", -2, 0)
    editor = CreateFrame("Frame", nil, frame)
    editor:SetPoint("TOPLEFT", 12, -40)
    editor:SetSize(316, 134)
    local itemLabel = label(editor, "Item ID, link or exact name")
    itemLabel:SetPoint("TOPLEFT", 2, 0)
    itemInput = input(editor, 298)
    itemInput:SetPoint("TOPLEFT", 6, -19)
    itemInput:SetScript("OnReceiveDrag", receiveItem)
    itemInput:SetScript("OnMouseDown", function() if GetCursorInfo() == "item" then receiveItem() end end)
    local goalLabel = label(editor, "Goal")
    goalLabel:SetPoint("TOPLEFT", 2, -51)
    goalInput = input(editor, 82, true)
    goalInput:SetPoint("TOPLEFT", 42, -46)
    goalInput:SetText("1")
    goalInput:SetScript("OnEnterPressed", save)
    itemInput:SetScript("OnEnterPressed", function() goalInput:SetFocus(); goalInput:HighlightText() end)
    itemInput:SetScript("OnTabPressed", function() goalInput:SetFocus(); goalInput:HighlightText() end)
    goalInput:SetScript("OnTabPressed", function() itemInput:SetFocus() end)
    local saveButton = button(editor, "Save goal", 86, save)
    saveButton:SetPoint("TOPLEFT", 142, -46)
    local cancel = button(editor, "Cancel", 68, function()
        editor:Hide(); itemInput:ClearFocus(); goalInput:ClearFocus(); ns.Render()
    end)
    cancel:SetPoint("LEFT", saveButton, "RIGHT", 6, 0)
    local hint = label(editor, "Drop an item here, or focus the item field and Shift-click.")
    hint:SetPoint("TOPLEFT", 2, -77)
    hint:SetWidth(310)
    hint:SetJustifyH("LEFT")
    hint:SetTextColor(0.55, 0.62, 0.67)
    errorText = label(editor, "")
    errorText:SetPoint("TOPLEFT", 2, -98)
    errorText:SetSize(310, 32)
    errorText:SetJustifyH("LEFT")
    errorText:SetJustifyV("TOP")
    errorText:SetTextColor(1, 0.4, 0.35)
    editor:Hide()
    scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(302, ROW_HEIGHT)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScroll() - delta * ROW_HEIGHT,
            math.max(0, content:GetHeight() - self:GetHeight()))))
    end)
    empty = label(content, "No items yet. Click Add or drop an item here.")
    empty:SetPoint("TOPLEFT", 2, -14)
    summary = label(frame, "")
    summary:SetPoint("BOTTOMLEFT", 12, 10)
    summary:SetTextColor(0.55, 0.62, 0.67)
    if hooksecurefunc and type(HandleModifiedItemClick) == "function" then
        hooksecurefunc("HandleModifiedItemClick", function(link)
            if editor:IsShown() and itemInput:HasFocus() and IsShiftKeyDown() and ns.ResolveItem(link) then
                itemInput:SetText(link); errorText:SetText("")
            end
        end)
    end
    ns.editor, ns.itemInput, ns.goalInput = editor, itemInput, goalInput
    ns.ApplyPosition()
end

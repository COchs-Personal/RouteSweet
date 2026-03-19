-- UI/SettingsFrame.lua
-- RouteSweet Settings Window
-- Left panel : scrollable profile list + create button
-- Right panel: single ScrollFrame with two collapsible sections
--              (Activity Weight / Reward Weight)
--
-- Profile active vs viewed are independent:
--   checkbox on each row = active (drives route)
--   clicking a row body  = viewed/edited in right panel

RS.Settings = RS.Settings or {}

-- ============================================================
-- LAYOUT CONSTANTS
-- ============================================================
local SW   = 660    -- window width
local SH   = 520    -- window height
local LW   = 210    -- left panel width (profiles)
local PAD  = 6      -- gap between panels / edges
local TH   = 34     -- title bar height
local BTN  = 32     -- "create profile" button height reserve
local ROW_H = 30    -- weight row height
local SEC_H = 28    -- collapsible section header height

local RW = SW - LW - PAD * 3   -- right panel inner usable width (~438)

-- ============================================================
-- COLOURS
-- ============================================================
local C = {
    BG       = { 0.04,  0.04,  0.09,  0.97 },
    PANEL    = { 0.07,  0.06,  0.13,  1    },
    BORDER   = { 0.20,  0.18,  0.30,  1    },
    VOID_DIM = { 0.29,  0.19,  0.48,  0.90 },
    ACTIVE   = { 0.25,  0.15,  0.45,  1    },
    ROW_ODD  = { 0.06,  0.06,  0.12,  1    },
    ROW_EVEN = { 0.09,  0.08,  0.16,  1    },
    GOLD     = { 0.784, 0.663, 0.431       },
    SUBTEXT  = { 0.50,  0.60,  0.70        },
    VOID_ACC = { 0.482, 0.310, 0.808, 0.80 },
}

-- ============================================================
-- TEXTURES  (Blizzard built-ins, no external assets)
-- ============================================================
local TEX = {
    GEAR       = "|TInterface\\Buttons\\UI-OptionsButton:16:16:0:0|t",
    LOCK       = "|TInterface\\PaperDollInfoFrame\\UI-GearManager-LeatherJournal:14:14:0:0|t",
    DRAG       = "|TInterface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up:12:7:0:0|t",
    CLOSE      = "|TInterface\\Buttons\\UI-StopButton:12:12:0:0|t",
    EXPAND     = "|TInterface\\Buttons\\Arrow-Down-Up:12:12:0:0|t",
    COLLAPSE   = "|TInterface\\Buttons\\Arrow-Up-Up:12:12:0:0|t",
}

-- ============================================================
-- DRAG STATE
-- ============================================================
local drag = { active=false, listKey=nil, fromIdx=nil, proxy=nil }

-- ============================================================
-- HELPERS
-- ============================================================

local function setBG(frame, r, g, b, a)
    local t = frame:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

local function getRelevantRewards(activityOrder)
    local enabled = {}
    for _, e in ipairs(activityOrder) do
        if e.enabled then enabled[e.id] = true end
    end
    local seen = {}
    for _, act in ipairs(RS.Zones and RS.Zones.STATIC_ACTIVITIES or {}) do
        if enabled[act.type] then
            for _, r in ipairs(act.rewards or {}) do seen[r] = true end
        end
    end
    local dbMap = {
        WEEKLY_EVENT   = { "rep","cache","cosmetics","brimming_arcana","coffer_key_shards" },
        WEEKLY         = { "rep","cache","cosmetics","brimming_arcana","coffer_key_shards" },
        DUNGEON        = { "gear","cache","rep" },
        HOUSING        = { "community_coupons","house_xp","housing_decor" },
        ROTATING_EVENT = { "gold","mounts","professions" },
        WORLD_QUEST    = { "gear","rep","gold" },
        DELVE          = { "gear","cache","gold" },
        BATTLEGROUND   = { "gear","rep","gold" },
    }
    for typeID, rewards in pairs(dbMap) do
        if enabled[typeID] then
            for _, r in ipairs(rewards) do seen[r] = true end
        end
    end
    return seen
end

local REWARD_LABELS = {
    gear              = "Equipment",
    cache             = "Apex Cache",
    rep               = "Reputation",
    gold              = "Gold",
    voidlight_marl    = "Voidlight Marl",
    community_coupons = "Community Coupons",
    brimming_arcana   = "Brimming Arcana",
    coffer_key_shards = "Coffer Key Shards",
    mounts            = "Mounts",
    cosmetics         = "Cosmetics",
    housing_decor     = "Housing Decor",
    professions       = "Professions",
    house_xp          = "House XP",
    spark_of_radiance = "Spark of Radiance",
}

local function getEditableProfile()
    local name = RS.Settings.viewedProfile or RS_Settings.activeProfile or "Default"
    if name == "Default" then return nil end
    return RS_Settings.profiles and RS_Settings.profiles[name]
end

-- ============================================================
-- SCROLL FRAME FACTORY
-- Returns scrollFrame, scrollChild
-- Child grows downward; caller sets child height after populating.
-- ============================================================
local function makeScrollFrame(parent, w, h)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    sf:SetSize(w, h)
    sf:SetClipsChildren(true)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(w, 1)
    sf:SetScrollChild(child)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local cur  = self:GetVerticalScroll()
        local maxV = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(maxV, cur - delta * ROW_H * 2)))
    end)
    return sf, child
end

-- ============================================================
-- COLLAPSIBLE SECTION HEADER
-- ============================================================
local function makeSectionHeader(parent, label, startOpen, onToggle)
    local hdr = CreateFrame("Button", nil, parent)
    hdr:SetHeight(SEC_H)

    local bg = hdr:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(C.VOID_DIM[1], C.VOID_DIM[2], C.VOID_DIM[3], C.VOID_DIM[4])

    local arrow = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    arrow:SetPoint("LEFT", hdr, "LEFT", 6, 0)
    arrow:SetText(startOpen and TEX.COLLAPSE or TEX.EXPAND)

    local lbl = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("LEFT", arrow, "RIGHT", 4, 0)
    lbl:SetText("|cffC8A96E" .. label .. "|r")

    hdr.isOpen = startOpen

    hdr:SetScript("OnClick", function(self)
        self.isOpen = not self.isOpen
        arrow:SetText(self.isOpen and TEX.COLLAPSE or TEX.EXPAND)
        onToggle(self.isOpen)
    end)
    hdr:SetScript("OnEnter", function() bg:SetAlpha(1) end)
    hdr:SetScript("OnLeave", function() bg:SetAlpha(C.VOID_DIM[4]) end)

    return hdr
end

-- ============================================================
-- WEIGHT ROW BUILDER
-- Populates `cont` with rows from `list`.
-- yOffset: pixels from cont top to start first row (always 0 for us).
-- Returns total pixel height consumed.
-- ============================================================
-- Find an entry's real index in the full (unfiltered) profile list by ID.
-- The display list may be filtered (rewards), so visual index i may
-- not match the profile list index.
local function findRealIndex(tgt, entryId)
    for ri = 1, #tgt do
        if tgt[ri].id == entryId then return ri end
    end
    return nil
end

local function buildWeightRows(settings, listKey, cont, rowsTable, list, isLocked, yOffset)
    for _, r in ipairs(rowsTable) do r:Hide() end
    wipe(rowsTable)

    for i, entry in ipairs(list) do
        local row = CreateFrame("Frame", nil, cont)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT",  cont, "TOPLEFT",  0, -(yOffset + (i-1)*ROW_H))
        row:SetPoint("TOPRIGHT", cont, "TOPRIGHT", 0, -(yOffset + (i-1)*ROW_H))

        setBG(row,
            i%2==1 and C.ROW_ODD[1] or C.ROW_EVEN[1],
            i%2==1 and C.ROW_ODD[2] or C.ROW_EVEN[2],
            i%2==1 and C.ROW_ODD[3] or C.ROW_EVEN[3])

        -- Priority score badge: position 1 = score 10, position 2 = 8, etc. (floor 1)
        -- Higher score = stronger influence on routing order.
        local weightVal = math.max(1, 12 - i*2)
        local badge = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        badge:SetPoint("LEFT", row, "LEFT", 4, 0)
        badge:SetWidth(20)
        badge:SetJustifyH("RIGHT")
        badge:SetText("|cff6677aa" .. weightVal .. "|r")
        -- Tooltip on badge explaining the number
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Priority Score: " .. weightVal, 1, 0.82, 0.27)
            GameTooltip:AddLine("Higher = stronger influence on route order.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine("Drag rows or use arrows to reorder.", 0.6, 0.6, 0.6, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Drag handle
        local handle = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        handle:SetPoint("LEFT", badge, "RIGHT", 2, 0)
        handle:SetText(TEX.DRAG)

        -- Checkbox
        local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        cb:SetSize(22, 22)
        cb:SetPoint("LEFT", handle, "RIGHT", 2, 0)
        cb:SetChecked(entry.enabled)

        -- Label
        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("LEFT",  cb,  "RIGHT", 4, 0)
        lbl:SetPoint("RIGHT", row, "RIGHT", -36, 0)
        lbl:SetJustifyH("LEFT")
        lbl:SetText(entry.label or entry.id)
        if not entry.enabled then
            lbl:SetTextColor(C.SUBTEXT[1], C.SUBTEXT[2], C.SUBTEXT[3])
        end

        -- Up / Down buttons
        local upBtn = CreateFrame("Button", nil, row)
        upBtn:SetSize(16, 13)
        upBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -2)
        upBtn:SetNormalTexture("Interface\\Buttons\\Arrow-Up-Up")
        upBtn:SetPushedTexture("Interface\\Buttons\\Arrow-Up-Down")
        upBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

        local dnBtn = CreateFrame("Button", nil, row)
        dnBtn:SetSize(16, 13)
        dnBtn:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 2)
        dnBtn:SetNormalTexture("Interface\\Buttons\\Arrow-Down-Up")
        dnBtn:SetPushedTexture("Interface\\Buttons\\Arrow-Down-Down")
        dnBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

        if isLocked then
            cb:Disable()
            upBtn:Disable(); upBtn:SetAlpha(0.3)
            dnBtn:Disable(); dnBtn:SetAlpha(0.3)
            handle:SetAlpha(0.3)
        else
            cb:SetScript("OnClick", function(self)
                local p = getEditableProfile()
                if not p then return end
                local tgt = (listKey=="activity") and p.activityOrder or p.rewardOrder
                local realIdx = findRealIndex(tgt, entry.id)
                if realIdx and tgt[realIdx] then
                    tgt[realIdx].enabled = self:GetChecked()
                    lbl:SetTextColor(
                        tgt[realIdx].enabled and 1         or C.SUBTEXT[1],
                        tgt[realIdx].enabled and 1         or C.SUBTEXT[2],
                        tgt[realIdx].enabled and 0.95      or C.SUBTEXT[3])
                    settings:RefreshWeights()
                    RS:BuildRoute()
                    if RS.UI.Refresh then RS.UI:Refresh() end
                end
            end)

            upBtn:SetScript("OnClick", function()
                local p = getEditableProfile()
                if not p then return end
                local tgt = (listKey=="activity") and p.activityOrder or p.rewardOrder
                local realIdx = findRealIndex(tgt, entry.id)
                if not realIdx or realIdx <= 1 then return end
                tgt[realIdx], tgt[realIdx-1] = tgt[realIdx-1], tgt[realIdx]
                settings:RefreshWeights()
                RS:BuildRoute()
                if RS.UI.Refresh then RS.UI:Refresh() end
            end)

            dnBtn:SetScript("OnClick", function()
                local p = getEditableProfile()
                if not p then return end
                local tgt = (listKey=="activity") and p.activityOrder or p.rewardOrder
                local realIdx = findRealIndex(tgt, entry.id)
                if not realIdx or realIdx >= #tgt then return end
                tgt[realIdx], tgt[realIdx+1] = tgt[realIdx+1], tgt[realIdx]
                settings:RefreshWeights()
                RS:BuildRoute()
                if RS.UI.Refresh then RS.UI:Refresh() end
            end)

            -- Drag reorder
            row:EnableMouse(true)
            row:RegisterForDrag("LeftButton")
            row:SetScript("OnDragStart", function()
                drag.active  = true
                drag.listKey = listKey
                drag.fromIdx = i
                drag.fromEntryId = entry.id
                if not drag.proxy then
                    local f = CreateFrame("Frame", nil, UIParent)
                    f:SetFrameStrata("TOOLTIP")
                    f:SetSize(RW - 40, ROW_H)
                    local bg = f:CreateTexture(nil, "BACKGROUND")
                    bg:SetAllPoints()
                    bg:SetColorTexture(C.VOID_ACC[1], C.VOID_ACC[2], C.VOID_ACC[3], 0.85)
                    local txt = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    txt:SetPoint("LEFT", 8, 0)
                    f._text = txt
                    drag.proxy = f
                end
                drag.proxy._text:SetText("|cffC8A96E" .. i .. ".|r " .. (entry.label or entry.id))
                drag.proxy:Show()

                -- Track cursor on the proxy frame (row OnUpdate may not fire during drag)
                drag.proxy:SetScript("OnUpdate", function(self)
                    local x, y = GetCursorPosition()
                    local sc = UIParent:GetEffectiveScale()
                    self:ClearAllPoints()
                    self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x/sc+12, y/sc-8)
                end)

                -- Dim the source row to show it's being moved
                row:SetAlpha(0.3)
            end)
            row:SetScript("OnDragStop", function()
                if not drag.active then return end
                drag.active = false
                if drag.proxy then
                    drag.proxy:SetScript("OnUpdate", nil)
                    drag.proxy:Hide()
                end
                row:SetAlpha(1)

                local p = getEditableProfile()
                if not p then return end
                local tgt = (drag.listKey=="activity") and p.activityOrder or p.rewardOrder

                -- Calculate drop index from cursor position relative to rows
                local _, curY = GetCursorPosition()
                local sc = cont:GetEffectiveScale()
                curY = curY / sc
                local _, contTop = cont:GetTop() and cont:GetTop() or 0
                -- Use the container's actual top in screen coords
                contTop = cont:GetTop() or 0

                local toIdx = #tgt  -- default to last if below all rows
                for ri = 1, #tgt do
                    local rowTop = contTop - (ri - 1) * ROW_H
                    local rowMid = rowTop - ROW_H / 2
                    if curY >= rowMid then
                        toIdx = ri
                        break
                    end
                end
                -- Clamp
                if toIdx < 1 then toIdx = 1 end
                if toIdx > #tgt then toIdx = #tgt end

                -- Find real index of the dragged item in the full profile list
                local realFromIdx = nil
                if drag.fromEntryId then
                    for ri = 1, #tgt do
                        if tgt[ri].id == drag.fromEntryId then
                            realFromIdx = ri
                            break
                        end
                    end
                end

                if realFromIdx and toIdx ~= realFromIdx then
                    local item = table.remove(tgt, realFromIdx)
                    -- Adjust toIdx if removal shifted positions
                    if realFromIdx < toIdx then toIdx = toIdx - 1 end
                    if toIdx < 1 then toIdx = 1 end
                    if toIdx > #tgt + 1 then toIdx = #tgt + 1 end
                    table.insert(tgt, toIdx, item)
                    settings:RefreshWeights()
                    RS:BuildRoute()
                    if RS.UI.Refresh then RS.UI:Refresh() end
                end
                drag.fromIdx = nil
                drag.fromEntryId = nil
                drag.listKey = nil
            end)
            row:SetScript("OnUpdate", function()
                -- Cursor tracking moved to proxy:OnUpdate (fires reliably during drag)
            end)
        end

        table.insert(rowsTable, row)
        row:Show()
    end

    return #list * ROW_H
end

-- ============================================================
-- MAIN INIT
-- ============================================================
RS.Settings.viewedProfile = nil
RS.Settings.actOpen       = true
RS.Settings.rewOpen       = true
RS.Settings.zoneOpen      = false

function RS.Settings:Init()
    if self.frame then return end

    -- ── OUTER WINDOW ─────────────────────────────────────────
    local f = CreateFrame("Frame", "RSSettingsFrame", UIParent, "BackdropTemplate")
    f:SetSize(SW, SH)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if RS.RaiseFrame then RS.RaiseFrame(self) end
        self:StartMoving()
    end)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetScript("OnMouseDown", function(self)
        if RS.RaiseFrame then RS.RaiseFrame(self) end
    end)
    f:Hide()
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left=3, right=3, top=3, bottom=3 },
    })
    f:SetBackdropColor(C.BG[1], C.BG[2], C.BG[3], C.BG[4])
    f:SetBackdropBorderColor(C.BORDER[1], C.BORDER[2], C.BORDER[3], C.BORDER[4])

    -- ── TITLE BAR ────────────────────────────────────────────
    local titleBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT")
    titleBar:SetPoint("TOPRIGHT")
    titleBar:SetHeight(TH)
    titleBar:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8" })
    titleBar:SetBackdropColor(C.VOID_DIM[1], C.VOID_DIM[2], C.VOID_DIM[3], C.VOID_DIM[4])

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    title:SetText(TEX.GEAR .. " |cffC8A96ERouteSweet Settings|r")
    title:SetFont("Fonts\\MORPHEUS.TTF", 13, "OUTLINE")

    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetSize(28, 28)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -3, 0)
    closeBtn:SetScript("OnClick", function() RS.Settings:Hide() end)

    -- ── LEFT PANEL ───────────────────────────────────────────
    local leftPanel = CreateFrame("Frame", nil, f, "BackdropTemplate")
    leftPanel:SetPoint("TOPLEFT",    f, "TOPLEFT",    PAD, -(TH + PAD))
    leftPanel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD,  PAD)
    leftPanel:SetWidth(LW)
    leftPanel:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8" })
    leftPanel:SetBackdropColor(C.PANEL[1], C.PANEL[2], C.PANEL[3], C.PANEL[4])

    local leftTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    leftTitle:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 10, -10)
    leftTitle:SetText("|cffC8A96EProfiles|r")

    -- Separator above Create button
    local sep = leftPanel:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("BOTTOMLEFT",  leftPanel, "BOTTOMLEFT",  8, BTN + 6)
    sep:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -8, BTN + 6)
    sep:SetColorTexture(C.BORDER[1], C.BORDER[2], C.BORDER[3], 0.8)

    -- Create button pinned to bottom of left panel
    local createBtn = CreateFrame("Button", nil, leftPanel, "UIPanelButtonTemplate")
    createBtn:SetSize(LW - 16, BTN - 6)
    createBtn:SetPoint("BOTTOM", leftPanel, "BOTTOM", 0, 8)
    createBtn:SetText("+ Create New Profile")
    createBtn:SetScript("OnClick", function() RS.Settings:ShowNameEntry() end)
    self.createBtn = createBtn

    -- Profile ScrollFrame: fills between title label and separator
    local profSF, profChild = makeScrollFrame(leftPanel, LW - 8, 100)
    profSF:SetPoint("TOPLEFT",     leftTitle, "BOTTOMLEFT",  0, -6)
    profSF:SetPoint("BOTTOMRIGHT", sep,       "TOPRIGHT",    0,  4)
    self.profSF    = profSF
    self.profChild = profChild
    self.profileRows = {}

    -- ── RIGHT PANEL ──────────────────────────────────────────
    local rightPanel = CreateFrame("Frame", nil, f, "BackdropTemplate")
    rightPanel:SetPoint("TOPLEFT",     leftPanel, "TOPRIGHT",    PAD,  0)
    rightPanel:SetPoint("BOTTOMRIGHT", f,         "BOTTOMRIGHT", -PAD, PAD)
    rightPanel:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8" })
    rightPanel:SetBackdropColor(C.PANEL[1], C.PANEL[2], C.PANEL[3], C.PANEL[4])

    -- Lock overlay
    local lockOverlay = CreateFrame("Frame", nil, rightPanel, "BackdropTemplate")
    lockOverlay:SetAllPoints()
    lockOverlay:SetFrameLevel(rightPanel:GetFrameLevel() + 20)
    lockOverlay:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8" })
    lockOverlay:SetBackdropColor(0.02, 0.02, 0.05, 0.78)
    lockOverlay:Hide()
    local lockMsg = lockOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    lockMsg:SetPoint("CENTER", lockOverlay, "CENTER", 0, 20)
    lockMsg:SetText(TEX.LOCK .. " |cffC8A96EDefault Profile|r")
    local lockSub = lockOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lockSub:SetPoint("TOP", lockMsg, "BOTTOM", 0, -8)
    lockSub:SetText("|cff8899aaCannot be edited.\nCreate a new profile to customise.|r")
    lockSub:SetJustifyH("CENTER")
    self.lockOverlay = lockOverlay

    -- Right ScrollFrame fills entire right panel
    local rightSF, rightChild = makeScrollFrame(rightPanel, rightPanel:GetWidth() or RW, 100)
    rightSF:SetPoint("TOPLEFT",     rightPanel, "TOPLEFT",     4, -4)
    rightSF:SetPoint("BOTTOMRIGHT", rightPanel, "BOTTOMRIGHT", -4,  4)
    self.rightSF    = rightSF
    self.rightChild = rightChild

    -- ── GENERAL SETTINGS SECTION ─────────────────────────────
    -- Sits at the very top of the right scroll child, above Activity Weight.
    -- Contains non-profile settings like combat visibility.
    local COMBAT_STATES = {
        { id = "always",           label = "Always show",              desc = "Never hide during combat." },
        { id = "hide_show_on_exit",label = "Hide: restore on exit",    desc = "Hides during combat, auto-shows when combat ends." },
        { id = "hide_until_toggle",label = "Hide: manual restore",     desc = "Hides during combat, stays hidden until you reopen manually." },
    }
    local function getCombatStateIndex()
        local cur = RS_Settings and RS_Settings.combatHide or "hide_show_on_exit"
        for i, s in ipairs(COMBAT_STATES) do
            if s.id == cur then return i end
        end
        return 2
    end

    local genHdr = makeSectionHeader(rightChild, "General", true, function(isOpen)
        RS.Settings.genOpen = isOpen
        RS.Settings:RefreshWeights()
    end)
    genHdr:SetPoint("TOPLEFT",  rightChild, "TOPLEFT",  0,  0)
    genHdr:SetPoint("TOPRIGHT", rightChild, "TOPRIGHT", 0,  0)
    self.genHdr = genHdr

    local genCont = CreateFrame("Frame", nil, rightChild)
    genCont:SetPoint("TOPLEFT",  genHdr, "BOTTOMLEFT",  0, 0)
    genCont:SetPoint("TOPRIGHT", genHdr, "BOTTOMRIGHT", 0, 0)
    genCont:SetHeight(ROW_H + 4)
    self.genCont = genCont

    -- Row background
    local genRowBg = genCont:CreateTexture(nil, "BACKGROUND")
    genRowBg:SetPoint("TOPLEFT",  genCont, "TOPLEFT",  0, -2)
    genRowBg:SetPoint("BOTTOMRIGHT", genCont, "BOTTOMRIGHT", 0, 2)
    genRowBg:SetColorTexture(C.ROW_ODD[1], C.ROW_ODD[2], C.ROW_ODD[3])

    local genLabel = genCont:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    genLabel:SetPoint("LEFT", genCont, "LEFT", 8, 0)
    genLabel:SetText("Combat visibility")
    genLabel:SetTextColor(C.GOLD[1], C.GOLD[2], C.GOLD[3])

    -- Cycle button showing current state
    local combatBtn = CreateFrame("Button", nil, genCont, "UIPanelButtonTemplate")
    combatBtn:SetSize(160, 22)
    combatBtn:SetPoint("RIGHT", genCont, "RIGHT", -8, 0)
    local function refreshCombatBtn()
        local idx = getCombatStateIndex()
        combatBtn:SetText(COMBAT_STATES[idx].label)
    end
    refreshCombatBtn()
    combatBtn:SetScript("OnClick", function()
        local idx = getCombatStateIndex()
        idx = (idx % #COMBAT_STATES) + 1
        if RS_Settings then RS_Settings.combatHide = COMBAT_STATES[idx].id end
        refreshCombatBtn()
    end)
    combatBtn:SetScript("OnEnter", function(self)
        local idx = getCombatStateIndex()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Combat Visibility", 1, 0.82, 0.27)
        for _, s in ipairs(COMBAT_STATES) do
            local bullet = (s.id == COMBAT_STATES[idx].id) and "|cff88ff88>> |r" or "    "
            GameTooltip:AddLine(bullet .. s.label, 0.9, 0.9, 0.9)
            GameTooltip:AddLine("    " .. s.desc, 0.6, 0.6, 0.6)
        end
        GameTooltip:AddLine("Click to cycle states.", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    combatBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.combatBtn = combatBtn

    -- Activity section header (anchored below genCont now)
    local actHdr = makeSectionHeader(rightChild, "Activity Weight", self.actOpen,
        function(isOpen)
            RS.Settings.actOpen = isOpen
            RS.Settings:RefreshWeights()
        end)
    actHdr:SetPoint("TOPLEFT",  genCont, "BOTTOMLEFT",  0, -4)
    actHdr:SetPoint("TOPRIGHT", genCont, "BOTTOMRIGHT", 0, -4)
    self.actHdr = actHdr

    -- Activity content container
    local actCont = CreateFrame("Frame", nil, rightChild)
    actCont:SetPoint("TOPLEFT",  actHdr, "BOTTOMLEFT",  0, 0)
    actCont:SetPoint("TOPRIGHT", actHdr, "BOTTOMRIGHT", 0, 0)
    actCont:SetHeight(1)
    self.actCont = actCont
    self.actRows = {}

    -- Reward section header (anchored to actCont, repositioned in RefreshWeights)
    local rewHdr = makeSectionHeader(rightChild, "Reward Weight", self.rewOpen,
        function(isOpen)
            RS.Settings.rewOpen = isOpen
            RS.Settings:RefreshWeights()
        end)
    rewHdr:SetPoint("TOPLEFT",  actCont, "BOTTOMLEFT",  0, -4)
    rewHdr:SetPoint("TOPRIGHT", actCont, "BOTTOMRIGHT", 0, -4)
    self.rewHdr = rewHdr

    -- Reward content container
    local rewCont = CreateFrame("Frame", nil, rightChild)
    rewCont:SetPoint("TOPLEFT",  rewHdr, "BOTTOMLEFT",  0, 0)
    rewCont:SetPoint("TOPRIGHT", rewHdr, "BOTTOMRIGHT", 0, 0)
    rewCont:SetHeight(1)
    self.rewCont = rewCont
    self.rewRows = {}

    -- ── ZONE PREFERENCES SECTION ────────────────────────────
    local zoneHdr = makeSectionHeader(rightChild, "Zone Preferences", self.zoneOpen,
        function(isOpen)
            RS.Settings.zoneOpen = isOpen
            RS.Settings:RefreshWeights()
        end)
    zoneHdr:SetPoint("TOPLEFT",  rewCont, "BOTTOMLEFT",  0, -4)
    zoneHdr:SetPoint("TOPRIGHT", rewCont, "BOTTOMRIGHT", 0, -4)
    self.zoneHdr = zoneHdr

    local zoneCont = CreateFrame("Frame", nil, rightChild)
    zoneCont:SetPoint("TOPLEFT",  zoneHdr, "BOTTOMLEFT",  0, 0)
    zoneCont:SetPoint("TOPRIGHT", zoneHdr, "BOTTOMRIGHT", 0, 0)
    zoneCont:SetHeight(1)
    self.zoneCont = zoneCont
    self.zoneRows = {}

    -- ── NAME ENTRY POPUP ─────────────────────────────────────
    local namePopup = CreateFrame("Frame", nil, f, "BackdropTemplate")
    namePopup:SetSize(220, 56)
    namePopup:SetPoint("BOTTOM", leftPanel, "BOTTOM", 0, BTN + 12)
    namePopup:SetFrameLevel(f:GetFrameLevel() + 30)
    namePopup:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets   = { left=2, right=2, top=2, bottom=2 },
    })
    namePopup:SetBackdropColor(0.06, 0.05, 0.14, 0.98)
    namePopup:SetBackdropBorderColor(C.GOLD[1], C.GOLD[2], C.GOLD[3], 1)
    namePopup:Hide()
    self.namePopup = namePopup

    local nameHint = namePopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameHint:SetPoint("TOPLEFT", namePopup, "TOPLEFT", 10, -8)
    nameHint:SetText("|cff8899aaProfile name:|r")

    local nameBox = CreateFrame("EditBox", "RSProfileNameBox", namePopup, "InputBoxTemplate")
    nameBox:SetSize(148, 20)
    nameBox:SetPoint("TOPLEFT", nameHint, "BOTTOMLEFT", 0, -2)
    nameBox:SetAutoFocus(true)
    nameBox:SetMaxLetters(32)
    nameBox:SetScript("OnEnterPressed", function(self)
        RS.Settings:ConfirmNewProfile(self:GetText())
    end)
    nameBox:SetScript("OnEscapePressed", function() namePopup:Hide() end)
    self.nameBox = nameBox

    local nameOK = CreateFrame("Button", nil, namePopup, "UIPanelButtonTemplate")
    nameOK:SetSize(40, 20)
    nameOK:SetPoint("LEFT", nameBox, "RIGHT", 4, 0)
    nameOK:SetText("OK")
    nameOK:SetScript("OnClick", function()
        RS.Settings:ConfirmNewProfile(nameBox:GetText())
    end)

    self.frame = f
    self:RefreshProfiles()
    self:RefreshWeights()
end

-- ============================================================
-- PROFILE LIST
-- ============================================================
function RS.Settings:RefreshProfiles()
    if not self.profileRows then return end

    if not self.viewedProfile then
        self.viewedProfile = RS_Settings.activeProfile or "Default"
    end

    for _, r in ipairs(self.profileRows) do r:Hide() end
    self.profileRows = {}

    local names  = RS:GetProfileNames()
    local active = RS_Settings.activeProfile or "Default"
    local viewed = self.viewedProfile
    local child  = self.profChild

    for i, name in ipairs(names) do
        local row = CreateFrame("Button", nil, child)
        row:SetHeight(34)
        row:SetPoint("TOPLEFT",  child, "TOPLEFT",  0, -(i-1)*36)
        row:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, -(i-1)*36)

        -- Background
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        if name == viewed then
            bg:SetColorTexture(C.ACTIVE[1], C.ACTIVE[2], C.ACTIVE[3], C.ACTIVE[4])
        else
            bg:SetColorTexture(0.08, 0.07, 0.14, 1)
        end

        -- Active checkbox
        local activeCb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        activeCb:SetSize(20, 20)
        activeCb:SetPoint("LEFT", row, "LEFT", 4, 0)
        activeCb:SetChecked(name == active)
        activeCb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Set Active Profile", 1, 0.82, 0.27)
            GameTooltip:AddLine("This profile drives route calculations.", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        activeCb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        activeCb:SetScript("OnClick", function()
            RS_Settings.activeProfile = name
            RS.Settings:RefreshProfiles()
            RS:BuildRoute()
            if RS.UI.Refresh then RS.UI:Refresh() end
        end)

        -- Label
        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("LEFT",  activeCb, "RIGHT", 4,   0)
        lbl:SetPoint("RIGHT", row,      "RIGHT", -26, 0)
        lbl:SetJustifyH("LEFT")
        if name == "Default" then
            lbl:SetText(TEX.LOCK .. " |cffC8A96EDefault|r")
        elseif name == viewed then
            lbl:SetText("|cffddddff" .. name .. "|r")
        else
            lbl:SetText("|cff8899aa" .. name .. "|r")
        end

        -- Delete button (custom profiles only)
        if name ~= "Default" then
            local delBtn = CreateFrame("Button", nil, row)
            delBtn:SetSize(20, 20)
            delBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            local delTex = delBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            delTex:SetAllPoints()
            delTex:SetJustifyH("CENTER")
            delTex:SetText(TEX.CLOSE)
            delBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Delete Profile", 1, 0.3, 0.3)
                GameTooltip:Show()
            end)
            delBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            delBtn:SetScript("OnClick", function()
                if RS.Settings.viewedProfile == name then
                    RS.Settings.viewedProfile = RS_Settings.activeProfile or "Default"
                end
                RS:DeleteProfile(name)
                RS.Settings:RefreshProfiles()
                RS.Settings:RefreshWeights()
                RS:BuildRoute()
                if RS.UI.Refresh then RS.UI:Refresh() end
            end)
        end

        -- Row click = change viewed profile
        row:SetScript("OnClick", function()
            RS.Settings.viewedProfile = name
            RS.Settings:RefreshProfiles()
            RS.Settings:RefreshWeights()
        end)

        table.insert(self.profileRows, row)
        row:Show()
    end

    -- Grow child frame to fit all rows (enables scroll)
    local totalH = #names * 36
    child:SetHeight(math.max(totalH, 1))

    -- Lock overlay on right panel when viewed profile is Default
    if self.lockOverlay then
        if self.viewedProfile == "Default" then
            self.lockOverlay:Show()
        else
            self.lockOverlay:Hide()
        end
    end
end

-- ============================================================
-- NAME ENTRY
-- ============================================================
function RS.Settings:ShowNameEntry()
    if self.namePopup then
        self.nameBox:SetText("")
        self.namePopup:Show()
        self.nameBox:SetFocus()
    end
end

function RS.Settings:ConfirmNewProfile(name)
    name = name and name:match("^%s*(.-)%s*$")
    if not name or name == "" or name == "Default" then
        self.namePopup:Hide()
        return
    end
    if RS_Settings.profiles and RS_Settings.profiles[name] then
        self.nameBox:SetText("")
        return
    end
    RS:CreateProfile(name)
    RS_Settings.activeProfile = name
    self.viewedProfile         = name
    self.namePopup:Hide()
    self:RefreshProfiles()
    self:RefreshWeights()
    RS:BuildRoute()
    if RS.UI.Refresh then RS.UI:Refresh() end
end

-- ============================================================
-- WEIGHT SECTIONS
-- ============================================================
function RS.Settings:RefreshWeights()
    if not self.rightChild then return end

    -- General section collapse
    local genH = 0
    if self.genCont then
        local genOpen = (RS.Settings.genOpen ~= false)  -- default open
        if genOpen then
            self.genCont:Show()
            genH = ROW_H + 4
        else
            self.genCont:Hide()
        end
        self.genCont:SetHeight(math.max(genH, 1))
    end
    -- Reanchor actHdr below genCont
    if self.actHdr and self.genCont then
        self.actHdr:ClearAllPoints()
        self.actHdr:SetPoint("TOPLEFT",  self.genCont, "BOTTOMLEFT",  0, -4)
        self.actHdr:SetPoint("TOPRIGHT", self.genCont, "BOTTOMRIGHT", 0, -4)
    end

    local viewed = self.viewedProfile or RS_Settings.activeProfile or "Default"
    local isDefault = (viewed == "Default")
    local profile
    if isDefault then
        profile = RS.DEFAULT_PROFILE
    else
        profile = RS_Settings.profiles and RS_Settings.profiles[viewed]
        if not profile then profile = RS.DEFAULT_PROFILE end
    end

    -- Activity rows
    local actH = 0
    if self.actOpen then
        actH = buildWeightRows(self, "activity", self.actCont, self.actRows,
            profile.activityOrder, isDefault, 0)
    else
        for _, r in ipairs(self.actRows) do r:Hide() end
        wipe(self.actRows)
    end
    self.actCont:SetHeight(math.max(actH, 1))

    -- Reanchor reward header below activity content
    self.rewHdr:ClearAllPoints()
    self.rewHdr:SetPoint("TOPLEFT",  self.actCont, "BOTTOMLEFT",  0, -4)
    self.rewHdr:SetPoint("TOPRIGHT", self.actCont, "BOTTOMRIGHT", 0, -4)

    -- Build filtered reward list
    local relevant = getRelevantRewards(profile.activityOrder)
    local filtered, inOrder = {}, {}
    for _, e in ipairs(profile.rewardOrder) do inOrder[e.id] = true end
    for _, e in ipairs(profile.rewardOrder) do
        if relevant[e.id] then table.insert(filtered, e) end
    end
    for rewardID in pairs(relevant) do
        if not inOrder[rewardID] and REWARD_LABELS[rewardID] then
            local ne = { id=rewardID, label=REWARD_LABELS[rewardID], enabled=true }
            table.insert(filtered, ne)
            if not isDefault then table.insert(profile.rewardOrder, ne) end
        end
    end

    -- Reward rows
    local rewH = 0
    if self.rewOpen then
        rewH = buildWeightRows(self, "reward", self.rewCont, self.rewRows,
            filtered, isDefault, 0)
    else
        for _, r in ipairs(self.rewRows) do r:Hide() end
        wipe(self.rewRows)
    end
    self.rewCont:ClearAllPoints()
    self.rewCont:SetPoint("TOPLEFT",  self.rewHdr, "BOTTOMLEFT",  0, 0)
    self.rewCont:SetPoint("TOPRIGHT", self.rewHdr, "BOTTOMRIGHT", 0, 0)
    self.rewCont:SetHeight(math.max(rewH, 1))

    -- Reanchor zone header below reward content
    self.zoneHdr:ClearAllPoints()
    self.zoneHdr:SetPoint("TOPLEFT",  self.rewCont, "BOTTOMLEFT",  0, -4)
    self.zoneHdr:SetPoint("TOPRIGHT", self.rewCont, "BOTTOMRIGHT", 0, -4)

    -- Zone preference rows
    local zoneH = 0
    for _, r in ipairs(self.zoneRows) do r:Hide() end
    wipe(self.zoneRows)

    if self.zoneOpen then
        local ZONE_ROW_H = ROW_H or 28
        local scanZones = RS.Expansion:GetAllScanZoneIDs()
        -- Exclude hub zones (Silvermoon, Arcantina) — only routable quest zones
        local hubZones = { [2393] = true, [2541] = true }
        local zones = {}
        local seen = {}
        for _, mapID in ipairs(scanZones) do
            if not hubZones[mapID] and not seen[mapID] then
                seen[mapID] = true
                table.insert(zones, mapID)
            end
        end

        for zi, mapID in ipairs(zones) do
            local row = CreateFrame("Frame", nil, self.zoneCont)
            row:SetHeight(ZONE_ROW_H)
            row:SetPoint("TOPLEFT",  self.zoneCont, "TOPLEFT",  0, -(zi-1)*ZONE_ROW_H)
            row:SetPoint("TOPRIGHT", self.zoneCont, "TOPRIGHT", 0, -(zi-1)*ZONE_ROW_H)

            setBG(row,
                zi%2==1 and C.ROW_ODD[1] or C.ROW_EVEN[1],
                zi%2==1 and C.ROW_ODD[2] or C.ROW_EVEN[2],
                zi%2==1 and C.ROW_ODD[3] or C.ROW_EVEN[3])

            local zoneName = RS.Zones:GetZoneName(mapID) or ("Zone " .. mapID)
            local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            lbl:SetPoint("LEFT", row, "LEFT", 8, 0)
            lbl:SetWidth(160)
            lbl:SetJustifyH("LEFT")
            lbl:SetText(zoneName)

            -- "First" checkbox — forces this zone to top of route order
            local firstCB = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            firstCB:SetSize(20, 20)
            firstCB:SetPoint("RIGHT", row, "RIGHT", -90, 0)
            local isFirst = profile.zoneFirst and profile.zoneFirst[mapID] or false
            firstCB:SetChecked(isFirst)

            local firstLbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            firstLbl:SetPoint("RIGHT", firstCB, "LEFT", -2, 0)
            firstLbl:SetText("|cffC8A96EFirst|r")

            if isDefault then
                firstCB:Disable()
                firstCB:SetAlpha(0.3)
            else
                firstCB:SetScript("OnClick", function(self)
                    local p = getEditableProfile()
                    if not p then return end
                    if not p.zoneFirst then p.zoneFirst = {} end
                    p.zoneFirst[mapID] = self:GetChecked() or nil
                    RS:BuildRoute()
                    if RS.UI.Refresh then RS.UI:Refresh() end
                end)
            end

            firstCB:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Route First", 1, 0.82, 0.27)
                GameTooltip:AddLine("When checked, activities in this zone are routed", 0.8, 0.8, 0.8, true)
                GameTooltip:AddLine("before all non-First zones. Within First zones,", 0.8, 0.8, 0.8, true)
                GameTooltip:AddLine("Prefer/Avoid and TSP still apply.", 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            firstCB:SetScript("OnLeave", function() GameTooltip:Hide() end)

            -- 3-state cycle button: Normal → Prefer → Avoid
            local pref = (profile.zonePreferences and profile.zonePreferences[mapID]) or "normal"
            local stateBtn = CreateFrame("Button", nil, row)
            stateBtn:SetSize(80, 18)
            stateBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)

            local stateTxt = stateBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            stateTxt:SetPoint("CENTER")

            local function updateZoneBtn(state)
                if state == "prefer" then
                    stateTxt:SetText("|cff00ff00Prefer|r")
                    lbl:SetTextColor(0.2, 1, 0.2)
                elseif state == "avoid" then
                    stateTxt:SetText("|cffff4444Avoid|r")
                    lbl:SetTextColor(1, 0.3, 0.3)
                else
                    stateTxt:SetText("|cff888888Normal|r")
                    lbl:SetTextColor(1, 1, 0.95)
                end
            end
            updateZoneBtn(pref)

            stateBtn:SetScript("OnClick", function()
                if isDefault then return end
                local p = getEditableProfile()
                if not p then return end
                if not p.zonePreferences then p.zonePreferences = {} end
                local cur = p.zonePreferences[mapID] or "normal"
                local next
                if cur == "normal" then next = "prefer"
                elseif cur == "prefer" then next = "avoid"
                else next = "normal" end
                p.zonePreferences[mapID] = next
                updateZoneBtn(next)
                RS:BuildRoute()
                if RS.UI.Refresh then RS.UI:Refresh() end
            end)

            -- Tooltip
            stateBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Zone Priority", 1, 0.82, 0.27)
                GameTooltip:AddLine("Click to cycle: Normal → Prefer → Avoid", 0.8, 0.8, 0.8, true)
                GameTooltip:AddLine("Prefer: +20 score to all activities in this zone.", 0.2, 1, 0.2, true)
                GameTooltip:AddLine("Avoid: -20 score to all activities in this zone.", 1, 0.3, 0.3, true)
                GameTooltip:Show()
            end)
            stateBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

            table.insert(self.zoneRows, row)
            zoneH = zoneH + ZONE_ROW_H
        end
    end

    self.zoneCont:ClearAllPoints()
    self.zoneCont:SetPoint("TOPLEFT",  self.zoneHdr, "BOTTOMLEFT",  0, 0)
    self.zoneCont:SetPoint("TOPRIGHT", self.zoneHdr, "BOTTOMRIGHT", 0, 0)
    self.zoneCont:SetHeight(math.max(zoneH, 1))

    -- Total scroll child height (genH + 4 sections: general, activity, reward, zone)
    local totalH = SEC_H + genH + 4 + SEC_H + actH + 4 + SEC_H + rewH + 4 + SEC_H + zoneH + 8
    self.rightChild:SetHeight(math.max(totalH, 1))

    -- Clamp scroll position
    local maxV = self.rightSF:GetVerticalScrollRange()
    local curV = self.rightSF:GetVerticalScroll()
    if curV > maxV then self.rightSF:SetVerticalScroll(maxV) end
end

-- ============================================================
-- SHOW / HIDE / TOGGLE
-- ============================================================
function RS.Settings:Show()
    if not self.frame then self:Init() end
    self:RefreshProfiles()
    self:RefreshWeights()
    self.frame:Show()
end

function RS.Settings:Hide()
    if self.frame then self.frame:Hide() end
end

function RS.Settings:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

-- ============================================================
-- REGISTER WITH WOW ADDON SETTINGS PANEL
-- ============================================================
local function registerAddonSettings()
    if not Settings or not Settings.RegisterCanvasLayoutCategory then return end
    local category, layout = Settings.RegisterCanvasLayoutCategory(
        CreateFrame("Frame"), "RouteSweet")
    layout:SetCanvas(CreateFrame("Frame"))
    Settings.RegisterAddOnCategory(category)
    local panel = nil
    if category.GetCanvasFrame then
        panel = category:GetCanvasFrame()
    end
    if panel then
        panel:SetScript("OnShow", function() RS.Settings:Show() end)
    end
end

local regFrame = CreateFrame("Frame")
regFrame:RegisterEvent("ADDON_LOADED")
regFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "RouteSweet" then
        pcall(registerAddonSettings)
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

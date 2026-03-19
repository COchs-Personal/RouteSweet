-- UI/MainFrame.lua
-- Main route display window
-- Clean dark elven aesthetic matching Midnight's visual style

RS.UI = RS.UI or {}

local FRAME_W    = 420
local FRAME_H    = 580
local FRAME_MIN_H = 300
local FRAME_MAX_H = 1200
local ROW_H      = 56
local MAX_ROWS   = 8
local SCROLL_H   = MAX_ROWS * ROW_H

local COLOR = {
    GOLD      = { r=0.784, g=0.663, b=0.431 },  -- #C8A96E
    VOID      = { r=0.482, g=0.310, b=0.808 },  -- #7B4FCF
    WHITE     = { r=0.9,   g=0.9,   b=0.95  },
    SUBTEXT   = { r=0.5,   g=0.6,   b=0.7   },
    URGENT    = { r=1.0,   g=0.4,   b=0.3   },
    DONE      = { r=0.3,   g=0.8,   b=0.3   },
    BG        = { r=0.04,  g=0.04,  b=0.09  },
    BORDER    = { r=0.2,   g=0.18,  b=0.3   },
    ROW_ODD   = { r=0.06,  g=0.06,  b=0.12  },
    ROW_EVEN  = { r=0.08,  g=0.07,  b=0.14  },
}

-- Type icons: |T path:h:w:x:y|t  — all Interface\ paths, no external assets.
-- These are small 12×12 inline textures prepended to activity names in the list.
-- Using stable Blizzard UI icons that ship with every retail client.
local TYPE_ICON = {
    WEEKLY         = "|TInterface\\Icons\\INV_Misc_Note_01:12:12:0:0|t",
    WEEKLY_EVENT   = "|TInterface\\Icons\\Achievement_Quests_Completed_Daily:12:12:0:0|t",
    WORLD_QUEST    = "|TInterface\\Icons\\INV_Misc_Map_01:12:12:0:0|t",
    DUNGEON        = "|TInterface\\Icons\\Achievement_Dungeon_GloryoftheHero:12:12:0:0|t",
    DELVE          = "|TInterface\\Icons\\INV_Misc_Dungeon_01:12:12:0:0|t",
    ROTATING_EVENT = "|TInterface\\Icons\\INV_Misc_StarFall_01:12:12:0:0|t",
    HOUSING        = "|TInterface\\Icons\\INV_Housing_LightWoodDoor01:12:12:0:0|t",
    BATTLEGROUND   = "|TInterface\\Icons\\PVPCurrency-Honor-Alliance:12:12:0:0|t",
    TIMED_EVENT    = "|TInterface\\Icons\\Ability_Warrior_HeroicFury:12:12:0:0|t",
    RARE           = "|TInterface\\Icons\\INV_Misc_Head_Dragon_01:12:12:0:0|t",
    PROFESSION     = "|TInterface\\Icons\\INV_Misc_Book_09:12:12:0:0|t",
    DECOR          = "|TInterface\\Icons\\INV_Misc_Statue_01:12:12:0:0|t",
    PORTAL         = "|TInterface\\Icons\\Spell_Arcane_TeleportSilvermoon:12:12:0:0|t",
    -- Leveling types
    CAMPAIGN       = "|TInterface\\Icons\\Achievement_Quests_Completed_08:12:12:0:0|t",
    IMPORTANT      = "|TInterface\\Icons\\INV_Misc_Note_06:12:12:0:0|t",
    QUESTLINE      = "|TInterface\\Icons\\INV_Misc_Book_07:12:12:0:0|t",
    BONUS_OBJECTIVE = "|TInterface\\Icons\\Ability_Skyreach_FlashBang:12:12:0:0|t",
    NORMAL         = "|TInterface\\Icons\\INV_Misc_Note_02:12:12:0:0|t",
    LEGENDARY      = "|TInterface\\Icons\\INV_Misc_Coin_17:12:12:0:0|t",
}

-- ── Travel note inline icons (10×10, offset 0) ───────────────
-- Prepended to the grey subtext portal/travel notes in each row.
local TRAVEL_ICON = {
    portal   = "|TInterface\\Icons\\Spell_Arcane_TeleportSilvermoon:10:10:0:0|t",
    hearth   = "|TInterface\\Icons\\INV_Misc_Rune_08:10:10:0:0|t",
    key      = "|TInterface\\Icons\\INV_Misc_Key_15:10:10:0:0|t",
    flight   = "|TInterface\\Icons\\Ability_Mount_FlyingCarpet:10:10:0:0|t",
}

-- ── Short display names for bind locations ───────────────────
-- GetBindLocation() returns the inn subzone name. We show a short version.
-- "Wayfarer's Rest" is the Silvermoon City inn — display as "Silvermoon".
-- "your inn" is the WoW default string returned before the client resolves the name,
-- or when the hearthstone is bound to a generic/unnamed inn.
local HEARTH_SHORT_NAME = {
    ["your inn"]              = "Inn",       -- WoW default before name resolves
    ["an inn"]                = "Inn",
    ["Wayfarer's Rest"]       = "Silvermoon",
    ["Silvermoon City"]       = "Silvermoon",
    ["Fairbreeze Village"]    = "Fairbreeze",
    ["Tranquillien"]          = "Tranquillien",
    ["Ghostlands"]            = "Ghostlands",
    ["Zul'Aman"]              = "Zul'Aman",
    ["Amani'shi Outpost"]     = "Amani Outpost",
    ["Harandar"]              = "Harandar",
    ["Thornwall Bastion"]     = "Thornwall",
    ["Harandar's Watch"]      = "Harandar Watch",
    ["Voidstorm"]             = "Voidstorm",
    ["The Obsidian Citadel"]  = "Citadel",
    ["Stormrift Post"]        = "Stormrift",
    ["Sun's Reach Harbor"]    = "Sun's Reach",
    ["Isle of Quel'Danas"]    = "Quel'Danas",
    ["The Arcantina"]         = "Arcantina",
}

-- ============================================================
-- FRAME SETUP
-- ============================================================
function RS.UI:Init()
    if self.frame then return end

    local f = CreateFrame("Frame", "QTRMainFrame", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    -- Foreground switching: both RS frames stay at DIALOG strata (plays nice
    -- with bags, other addons, etc.). Clicking/dragging one raises it above
    -- the other by bumping frame level. RS.RaiseFrame is shared with SettingsFrame.
    RS._frameLevel = RS._frameLevel or 100
    function RS.RaiseFrame(frame)
        RS._frameLevel = RS._frameLevel + 2
        frame:SetFrameLevel(RS._frameLevel)
    end

    f:SetScript("OnDragStart", function(self)
        RS.RaiseFrame(self)
        self:StartMoving()
    end)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScript("OnMouseDown", function(self)
        RS.RaiseFrame(self)
    end)

    f:Hide()

    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left=3, right=3, top=3, bottom=3 },
    })
    f:SetBackdropColor(COLOR.BG.r, COLOR.BG.g, COLOR.BG.b, 0.97)
    f:SetBackdropBorderColor(COLOR.BORDER.r, COLOR.BORDER.g, COLOR.BORDER.b, 1)

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    titleBar:SetHeight(34)
    titleBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    titleBar:SetBackdropColor(COLOR.VOID.r * 0.6, COLOR.VOID.g * 0.6, COLOR.VOID.b * 0.6, 0.9)

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    title:SetText("|cffC8A96ERouteSweet|r")
    title:SetFont("Fonts\\MORPHEUS.TTF", 14, "OUTLINE")

    -- Close button — inside frame, vertically centred in title bar
    -- UIPanelCloseButton is 32x32; title bar is 34px tall → 1px inset top/bottom
    -- Keep same inset from right as top/bottom gap = 1px → offset -1,-1 from TOPRIGHT of titleBar
    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetSize(28, 28)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -3, 0)
    closeBtn:SetScript("OnClick", function() RS.UI:Hide() end)

    -- Settings gear button — same vertical centre, 4px to the left of close button
    local settingsBtn = CreateFrame("Button", nil, titleBar, "UIPanelButtonTemplate")
    settingsBtn:SetSize(24, 24)
    settingsBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    settingsBtn:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    settingsBtn:SetPushedTexture("Interface\\Buttons\\UI-OptionsButton")
    settingsBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    settingsBtn:SetScript("OnClick", function()
        if RS.Settings then RS.Settings:Toggle() end
    end)
    settingsBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("RouteSweet Settings", 1, 0.82, 0.27)
        GameTooltip:AddLine("Profiles, activity weights, reward weights", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    settingsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- ── ICON BUTTON FACTORY ───────────────────────────────────
    -- Creates a square SecureActionButtonTemplate with:
    --   • item/spell icon via GetItemIcon / GetSpellTexture
    --   • dark square background + 1px border
    --   • highlight overlay on hover
    --   • CooldownFrame child for swipe animation
    --   • status FontString overlay (bottom-centre, small, shadow)
    -- Returns: btn, statusLabel, cooldownFrame
    local ICON_SIZE = 28
    local function MakeIconButton(name, parent, iconSource, iconID)
        local btn = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
        btn:SetSize(ICON_SIZE, ICON_SIZE)

        -- Dark backing
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\Buttons\\WHITE8x8")
        bg:SetVertexColor(0.05, 0.05, 0.10, 1)

        -- Item / spell icon
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT",     btn, "TOPLEFT",     1,  -1)
        icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1,  1)
        if iconSource == "item" then
            local fileID = GetItemIcon and GetItemIcon(iconID)
            if fileID then icon:SetTexture(fileID) end
        elseif iconSource == "spell" then
            local tex = GetSpellTexture and GetSpellTexture(iconID)
            if tex then
                icon:SetTexture(tex)
            elseif iconID == 436854 then
                -- Confirmed FileDataID for ability_dragonriding_swapflightstyles01
                icon:SetTexture(5145511)
            end
        elseif iconSource == "fileID" then
            icon:SetTexture(iconID)
        end
        btn._icon = icon

        -- Thin border (1px inset, recoloured by state)
        local border = btn:CreateTexture(nil, "OVERLAY")
        border:SetPoint("TOPLEFT",     btn, "TOPLEFT",     0,  0)
        border:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0,  0)
        border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        border:SetBlendMode("ADD")
        border:SetAlpha(0.5)
        btn._border = border

        -- Highlight on hover
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture("Interface\\Buttons\\WHITE8x8")
        hl:SetVertexColor(1, 1, 1, 0.15)

        -- Pushed overlay
        local pushed = btn:CreateTexture(nil, "OVERLAY")
        pushed:SetAllPoints()
        pushed:SetTexture("Interface\\Buttons\\WHITE8x8")
        pushed:SetVertexColor(0, 0, 0, 0.3)
        pushed:Hide()
        btn:SetScript("OnMouseDown", function() pushed:Show() end)
        btn:SetScript("OnMouseUp",   function() pushed:Hide() end)

        -- Cooldown swipe (standard Blizzard CooldownFrame)
        local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
        cd:SetAllPoints(icon)
        cd:SetDrawEdge(false)
        cd:SetDrawBling(false)
        btn._cd = cd

        -- Status label: tiny text centred below icon (for "15m", "No key", etc.)
        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("BOTTOM", btn, "BOTTOM", 0, 1)
        lbl:SetWidth(ICON_SIZE)
        lbl:SetJustifyH("CENTER")
        lbl:SetTextColor(1, 1, 1, 0)   -- hidden by default; shown when there's something to say
        lbl:SetShadowOffset(1, -1)
        btn._lbl = lbl

        btn:RegisterForClicks("AnyUp", "AnyDown")
        return btn
    end

    -- ── TOOLBAR (row 1): Scan | Start  ···  total time ──────────
    local toolbar = CreateFrame("Frame", nil, f)
    toolbar:SetPoint("TOPLEFT",  f, "TOPLEFT",  8, -36)
    toolbar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -36)
    toolbar:SetHeight(ICON_SIZE + 2)

    -- Scan button (left side)
    local scanBtn = CreateFrame("Button", nil, toolbar, "UIPanelButtonTemplate")
    scanBtn:SetSize(70, 22)
    scanBtn:SetPoint("LEFT", toolbar, "LEFT", 0, 0)
    scanBtn:SetText("Scan")
    scanBtn:SetScript("OnClick", function()
        RS:ScanQuests()
        RS:BuildRoute()
        RS.UI:Refresh()
    end)

    -- Start/Stop navigation button (right of Scan)
    local navBtn = CreateFrame("Button", nil, toolbar, "UIPanelButtonTemplate")
    navBtn:SetSize(70, 22)
    navBtn:SetPoint("LEFT", scanBtn, "RIGHT", 4, 0)
    navBtn:SetText("Start")
    self.navBtn = navBtn
    navBtn:SetScript("OnClick", function()
        if RS.Waypoint.IsActive and RS.Waypoint:IsActive() then
            if RS.Waypoint.Stop then RS.Waypoint:Stop() end
            RS.UI:UpdateNavBtn()
            RS.UI:UpdateProgressBar()
        else
            local route = RS.currentRoute
            if route and route.stops and #route.stops > 0 then
                if RS.Waypoint.Start then RS.Waypoint:Start(route.stops) end
                RS.UI:UpdateNavBtn()
            else
                print("|cffC8A96ERouteSweet:|r No route to navigate. Try scanning first.")
            end
        end
    end)

    -- Total time label (right-aligned, won't overlap the buttons which are left-anchored)
    local timeLabel = toolbar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    timeLabel:SetPoint("RIGHT", toolbar, "RIGHT", 0, 0)
    timeLabel:SetTextColor(COLOR.GOLD.r, COLOR.GOLD.g, COLOR.GOLD.b)
    self.timeLabel = timeLabel

    -- ── TRAVEL TOOLS BAR (row 2) ──────────────────────────────
    -- Sky switch | Hearthstone | Arcantina Key  — all icon buttons in one row
    local toolBar = CreateFrame("Frame", nil, f)
    toolBar:SetPoint("TOPLEFT",  f, "TOPLEFT",  8, -36 - ICON_SIZE - 6)
    toolBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -36 - ICON_SIZE - 6)
    toolBar:SetHeight(ICON_SIZE + 2)

    -- ── SKYRIDING SWITCH BUTTON (leftmost in row 2) ───────────
    local skyBtn = MakeIconButton("RSSkySwitchBtn", toolBar, "spell", 436854)
    skyBtn:SetPoint("LEFT", toolBar, "LEFT", 0, 0)
    skyBtn:SetAttribute("type", "spell")
    skyBtn:SetAttribute("spell", "Switch Flight Style")
    skyBtn:SetScript("PostClick", function()
        RS_Settings.useSkyriding = not RS_Settings.useSkyriding
        RS_Settings.detectedFlightMode = nil
        RS.UI:UpdateSkyBtn()
        RS:BuildRoute()
        RS.UI:Refresh()
    end)
    skyBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Switch Flight Style", 1, 0.82, 0.27)
        GameTooltip:AddLine("Toggles between Skyriding and Steady Flight.", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("Steady Flight requires Midnight Pathfinder.", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    skyBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.skyBtn = skyBtn

    -- Sky mode readout label beside the icon
    local skyLabel = toolBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    skyLabel:SetPoint("LEFT", skyBtn, "RIGHT", 4, 0)
    skyLabel:SetWidth(90)
    skyLabel:SetJustifyH("LEFT")
    self.skyLabel = skyLabel

    -- ── HEARTHSTONE ICON BUTTON ───────────────────────────────
    local hearthBtn = MakeIconButton("RSHearthBtn", toolBar, "item", 6948)
    hearthBtn:SetPoint("LEFT", skyBtn, "RIGHT", 94, 0)  -- after sky label
    hearthBtn:SetAttribute("type", "macro")
    hearthBtn:SetAttribute("macrotext", "/use Hearthstone")
    hearthBtn:SetScript("PreClick", function(self, button)
        if button == "RightButton" then
            self:SetAttribute("type", "")
            RS:BuildRoute(); RS.UI:Refresh()
        else
            self:SetAttribute("type", "macro")
        end
    end)
    hearthBtn:SetScript("OnEnter", function(self)
        local loc = GetBindLocation and GetBindLocation() or "Unknown"
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Hearthstone", 1, 0.82, 0.27)
        GameTooltip:AddLine("Bound to: " .. (loc or "Unknown"), 0.9, 0.9, 0.9)
        GameTooltip:AddLine("Left-click: use Hearthstone", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Right-click: rebuild route", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    hearthBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.hearthBtn = hearthBtn

    -- Text label to the right of Hearthstone icon
    local hearthLabel = toolBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hearthLabel:SetPoint("LEFT", hearthBtn, "RIGHT", 4, 0)
    hearthLabel:SetWidth(110)
    hearthLabel:SetJustifyH("LEFT")
    self.hearthLabel = hearthLabel

    -- ── ARCANTINA KEY ICON BUTTON ─────────────────────────────
    local arcantinaBtn = MakeIconButton("RSArcantinaBtn", toolBar, "item", 253629)
    arcantinaBtn:SetPoint("LEFT", hearthBtn, "RIGHT", 114, 0)  -- after hearth label
    arcantinaBtn:SetAttribute("type", "toy")
    arcantinaBtn:SetAttribute("toy", 253629)
    arcantinaBtn:SetScript("PreClick", function(self, button)
        if button == "RightButton" then
            self:SetAttribute("type", "")
            RS:BuildRoute(); RS.UI:Refresh()
            return
        end
        local owned = (C_ToyBox and C_ToyBox.HasToy and C_ToyBox.HasToy(253629))
            or (IsQuestFlaggedCompleted and IsQuestFlaggedCompleted(86903))
            or (RS_Settings and RS_Settings.hasArcantinaKey)
        if not owned then
            self:SetAttribute("type", "")
            print("|cffC8A96ERouteSweet:|r Complete 'The Arcantina' quest to get the Personal Key.")
        else
            self:SetAttribute("type", "toy")
            self:SetAttribute("toy", 253629)
        end
    end)
    arcantinaBtn:SetScript("OnEnter", function(self)
        local owned = (C_ToyBox and C_ToyBox.HasToy and C_ToyBox.HasToy(253629))
            or (IsQuestFlaggedCompleted and IsQuestFlaggedCompleted(86903))
            or (RS_Settings and RS_Settings.hasArcantinaKey)
        local cdSecs = RS.Flight and RS.Flight.ArcantinaCDRemaining and RS.Flight:ArcantinaCDRemaining() or 0
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Personal Key to the Arcantina", 1, 0.82, 0.27)
        if not owned then
            GameTooltip:AddLine("Not obtained — complete 'The Arcantina' questline.", 1, 0.4, 0.4)
        elseif cdSecs > 2 then
            GameTooltip:AddLine(string.format("On cooldown: %dm %ds remaining", math.floor(cdSecs/60), cdSecs%60), 1, 0.6, 0.4)
        else
            GameTooltip:AddLine("Ready  |  Key -> Arcantina -> Silvermoon Inn (~38s)", 0.4, 1, 0.4)
        end
        GameTooltip:AddLine("15 min cooldown  |  Warband Toy (item 253629)", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Left-click: use toy  |  Right-click: rebuild route", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    arcantinaBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.arcantinaBtn = arcantinaBtn

    -- Text label to the right of Arcantina icon
    local arcantinaLabel = toolBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    arcantinaLabel:SetPoint("LEFT", arcantinaBtn, "RIGHT", 4, 0)
    arcantinaLabel:SetWidth(60)
    arcantinaLabel:SetJustifyH("LEFT")
    self.arcantinaLabel = arcantinaLabel

    -- ── GREAT VAULT BUTTON (toolbar row 2, after Arcantina) ──
    local vaultBtn = CreateFrame("Button", "RSVaultBtn", toolBar)
    vaultBtn:SetSize(ICON_SIZE + 6, ICON_SIZE + 6)
    vaultBtn:SetPoint("RIGHT", toolBar, "RIGHT", 0, 0)
    local vaultIcon = vaultBtn:CreateTexture(nil, "ARTWORK")
    vaultIcon:SetAllPoints()
    vaultIcon:SetAtlas("UI-Journeys-GreatVault-Button")
    vaultBtn._icon = vaultIcon
    -- Highlight on hover (inset to stay inside icon bounds)
    local vaultHL = vaultBtn:CreateTexture(nil, "HIGHLIGHT")
    vaultHL:SetPoint("TOPLEFT", 2, -2)
    vaultHL:SetPoint("BOTTOMRIGHT", -2, 2)
    vaultHL:SetColorTexture(1, 1, 1, 0.15)
    -- Push feedback: slightly shrink icon on click
    vaultBtn:SetScript("OnMouseDown", function(self)
        self._icon:SetPoint("TOPLEFT", 1, -1)
        self._icon:SetPoint("BOTTOMRIGHT", -1, 1)
    end)
    vaultBtn:SetScript("OnMouseUp", function(self)
        self._icon:ClearAllPoints()
        self._icon:SetAllPoints()
    end)
    vaultBtn:SetScript("OnClick", function()
        C_AddOns.LoadAddOn("Blizzard_WeeklyRewards")
        if WeeklyRewardsFrame and WeeklyRewardsFrame:IsShown() then
            WeeklyRewardsFrame:Hide()
        elseif WeeklyRewardsFrame then
            WeeklyRewardsFrame:Show()
        end
    end)
    vaultBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Great Vault", 1, 0.82, 0.27)
        GameTooltip:AddLine("Click to open the Great Vault preview.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    vaultBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.vaultBtn = vaultBtn

    -- ── COLUMN HEADERS ────────────────────────────────────────
    local headers = CreateFrame("Frame", nil, f, "BackdropTemplate")
    headers:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, -36 - (ICON_SIZE + 2) * 2 - 8)
    headers:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -36 - (ICON_SIZE + 2) * 2 - 8)
    headers:SetHeight(18)
    headers:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    headers:SetBackdropColor(0.12, 0.10, 0.20, 1)

    local function HeaderText(parent, text, anchor, xOff)
        local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", parent, "LEFT", xOff, 0)
        fs:SetText(text)
        fs:SetTextColor(COLOR.GOLD.r, COLOR.GOLD.g, COLOR.GOLD.b)
        return fs
    end
    HeaderText(headers, "#",       headers, 6)
    HeaderText(headers, "Activity", headers, 26)
    HeaderText(headers, "Zone",    headers, 160)
    HeaderText(headers, "Travel",  headers, 244)
    HeaderText(headers, "Est.",    headers, 296)
    HeaderText(headers, "Total",   headers, 344)

    -- ── SCROLL FRAME ─────────────────────────────────────────
    -- UIPanelScrollFrameTemplate places its 20px scrollbar flush to the right
    -- edge of the ScrollFrame itself. We leave 24px on the right (4px margin +
    -- 20px scrollbar) so the scrollbar sits inside the main frame border.
    local scrollFrame = CreateFrame("ScrollFrame", "RSScrollFrame", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     f, "TOPLEFT",     4, -36 - (ICON_SIZE + 2) * 2 - 8 - 18 - 2)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -24, 60)
    self.scrollFrame = scrollFrame

    -- scrollChild width = scrollFrame width (FRAME_W - 4 left - 24 right = 392px).
    -- Rows span the full scrollChild; scrollbar is outside the scrollFrame to the right.
    local scrollChild = CreateFrame("Frame", "RSScrollChild", scrollFrame)
    scrollChild:SetSize(FRAME_W - 28, 1)   -- 420 - 4 left - 24 right = 392
    scrollFrame:SetScrollChild(scrollChild)
    self.scrollChild = scrollChild
    self.rowFrames = {}

    -- ── FOOTER ───────────────────────────────────────────────
    local footer = CreateFrame("Frame", nil, f, "BackdropTemplate")
    footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    footer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    footer:SetHeight(58)
    footer:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    footer:SetBackdropColor(0.06, 0.05, 0.12, 0.95)

    -- Progress bar background
    local progBg = footer:CreateTexture(nil, "BACKGROUND")
    progBg:SetPoint("TOPLEFT", footer, "TOPLEFT", 8, -6)
    progBg:SetPoint("TOPRIGHT", footer, "TOPRIGHT", -8, -6)
    progBg:SetHeight(10)
    progBg:SetColorTexture(0.12, 0.10, 0.22, 1)
    self.progBg = progBg

    -- Progress bar fill
    local progFill = footer:CreateTexture(nil, "ARTWORK")
    progFill:SetPoint("TOPLEFT", progBg, "TOPLEFT", 0, 0)
    progFill:SetHeight(10)
    progFill:SetWidth(1)  -- updated dynamically
    progFill:SetColorTexture(COLOR.VOID.r, COLOR.VOID.g, COLOR.VOID.b, 0.9)
    self.progFill = progFill

    -- Progress label
    local progLabel = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    progLabel:SetPoint("TOPLEFT", progBg, "BOTTOMLEFT", 0, -2)
    progLabel:SetTextColor(COLOR.SUBTEXT.r, COLOR.SUBTEXT.g, COLOR.SUBTEXT.b)
    progLabel:SetText("")
    self.progLabel = progLabel

    local footerText = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footerText:SetPoint("BOTTOMLEFT", footer, "BOTTOMLEFT", 10, 6)
    footerText:SetTextColor(COLOR.SUBTEXT.r, COLOR.SUBTEXT.g, COLOR.SUBTEXT.b)
    footerText:SetText("Left-click: Set waypoint  |  Right-click: Mark done")
    self.footerText = footerText

    -- ── RESIZE GRIP ──────────────────────────────────────────
    -- Drag the bottom-right corner to resize vertically
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
    grip:SetFrameLevel(f:GetFrameLevel() + 10)

    local gripTex = grip:CreateTexture(nil, "OVERLAY")
    gripTex:SetAllPoints()
    gripTex:SetColorTexture(COLOR.VOID.r, COLOR.VOID.g, COLOR.VOID.b, 0.6)

    -- Draw a small ╗-style resize indicator (3 diagonal lines)
    local function addGripLine(xOff, yOff)
        local l = grip:CreateTexture(nil, "OVERLAY")
        l:SetSize(8 - xOff, 2)
        l:SetPoint("BOTTOMRIGHT", grip, "BOTTOMRIGHT", -xOff, yOff)
        l:SetColorTexture(1, 1, 1, 0.5)
    end
    addGripLine(0, 2); addGripLine(0, 5); addGripLine(0, 8)

    grip:EnableMouse(true)
    grip:SetScript("OnEnter", function() gripTex:SetColorTexture(COLOR.GOLD.r, COLOR.GOLD.g, COLOR.GOLD.b, 0.8) end)
    grip:SetScript("OnLeave", function() gripTex:SetColorTexture(COLOR.VOID.r, COLOR.VOID.g, COLOR.VOID.b, 0.6) end)

    local dragging = false
    local dragStartY, dragStartH
    grip:SetScript("OnMouseDown", function(_, btn)
        if btn == "LeftButton" then
            dragging = true
            dragStartY = select(2, GetCursorPosition())
            dragStartH = f:GetHeight()
        end
    end)
    grip:SetScript("OnMouseUp", function()
        dragging = false
        -- Persist height across sessions
        if RS_Settings then RS_Settings.frameHeight = f:GetHeight() end
    end)
    grip:SetScript("OnUpdate", function()
        if not dragging then return end
        local curY = select(2, GetCursorPosition())
        local delta = (dragStartY - curY) / UIParent:GetScale()
        local newH = math.max(FRAME_MIN_H, math.min(FRAME_MAX_H, dragStartH + delta))
        f:SetHeight(newH)
    end)

    self.frame = f
    self:UpdateSkyBtn()
    self:UpdateToolBar()
    self:UpdateNavBtn()

    -- Restore saved height if available
    if RS_Settings and RS_Settings.frameHeight then
        f:SetHeight(math.max(FRAME_MIN_H, math.min(FRAME_MAX_H, RS_Settings.frameHeight)))
    end
end

function RS.UI:UpdateSkyBtn()
    if not self.skyBtn or not self.skyLabel then return end

    local mode, speedYps, source, hasSkyridingAura, flying = RS.DB:DetectFlightMode()

    if RS_Settings then
        RS_Settings.detectedFlightMode = mode
        RS_Settings.useSkyriding = (mode == "skyriding")
    end

    -- Ground-truth flight style buff (set by Switch Flight Style spell 436854)
    local flightStyleBuff = "skyriding"
    if AuraUtil and AuraUtil.FindAuraByName then
        if AuraUtil.FindAuraByName("Flight Style: Steady", "player") then
            flightStyleBuff = "steady"
        end
    end

    local speedStr = ""
    if speedYps and speedYps > 2 then
        speedStr = string.format("  %.0f y/s", speedYps)
    end

    local confident = hasSkyridingAura or flying

    -- RSSkySwitchBtn is a SecureActionButtonTemplate.
    -- Show() and Hide() on secure frames are protected functions — calling them
    -- during combat lockdown raises ADDON_ACTION_BLOCKED. When in combat we can
    -- still safely update non-secure children (FontStrings, Textures) because
    -- those are not protected. We just skip the Show/Hide on the button itself.
    local inCombat = InCombatLockdown()

    if confident then
        -- Flying: hide the button, show the text label instead.
        -- Only hide the button when we're NOT in combat; in combat leave it
        -- in whatever state it's already in and just update the label text.
        if not inCombat then
            self.skyBtn:Hide()
            self.skyLabel:Show()
        end
        if mode == "skyriding" then
            self.skyLabel:SetText("|cff88aaffSkyriding|r" .. speedStr)
        else
            self.skyLabel:SetText("|cffaaaaaaStatic flight|r" .. speedStr)
        end
    else
        -- On ground: show the button, update its border colour and label.
        -- Again, skip Show/Hide in combat.
        if not inCombat then
            self.skyLabel:Hide()
            self.skyBtn:Show()
        end
        if flightStyleBuff == "skyriding" then
            self.skyBtn._border:SetVertexColor(0.8, 0.7, 0.2, 0.7)
            self.skyBtn._lbl:SetText("SKY")
            self.skyBtn._lbl:SetTextColor(0.8, 0.7, 0.2, 1)
        else
            self.skyBtn._border:SetVertexColor(0.5, 0.6, 0.8, 0.7)
            self.skyBtn._lbl:SetText("STD")
            self.skyBtn._lbl:SetTextColor(0.6, 0.7, 0.9, 1)
        end
        self.skyBtn._lbl:SetAlpha(1)
        if RS_Settings then
            RS_Settings.useSkyriding = (flightStyleBuff == "skyriding")
        end
    end
end

-- ============================================================
-- ROW RENDERING
-- ============================================================
function RS.UI:GetOrCreateRow(index)
    if not self.rowFrames[index] then
        local row = CreateFrame("Button", nil, self.scrollChild)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 0, -(index - 1) * ROW_H)
        row:SetPoint("TOPRIGHT", self.scrollChild, "TOPRIGHT", 0, -(index - 1) * ROW_H)

        -- Background
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        row.bg = bg

        -- Index number
        row.indexText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.indexText:SetPoint("LEFT", row, "LEFT", 4, 8)
        row.indexText:SetWidth(24)
        row.indexText:SetJustifyH("RIGHT")

        -- Activity name (truncated with ellipsis in Refresh; tooltip shows full name)
        row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.nameText:SetPoint("TOPLEFT", row, "TOPLEFT", 32, -8)
        row.nameText:SetWidth(124)
        row.nameText:SetJustifyH("LEFT")

        -- Notes / portal subtext
        row.notesText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.notesText:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 26, 6)
        row.notesText:SetWidth(130)
        row.notesText:SetJustifyH("LEFT")
        row.notesText:SetTextColor(COLOR.SUBTEXT.r, COLOR.SUBTEXT.g, COLOR.SUBTEXT.b)

        -- Zone
        row.zoneText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.zoneText:SetPoint("TOPLEFT", row, "TOPLEFT", 160, -10)
        row.zoneText:SetWidth(80)
        row.zoneText:SetJustifyH("LEFT")

        -- Travel time
        row.travelText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.travelText:SetPoint("LEFT", row, "LEFT", 244, 0)
        row.travelText:SetWidth(48)
        row.travelText:SetJustifyH("CENTER")

        -- Activity / Est. time
        row.actText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.actText:SetPoint("LEFT", row, "LEFT", 296, 0)
        row.actText:SetWidth(44)
        row.actText:SetJustifyH("CENTER")

        -- Cumulative total — x=344, width=48 → ends at 392, safely inside 396px usable width
        row.totalText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.totalText:SetPoint("LEFT", row, "LEFT", 344, 0)
        row.totalText:SetWidth(48)
        row.totalText:SetJustifyH("RIGHT")

        -- Hover: highlight bg + show full activity detail tooltip
        row:SetScript("OnEnter", function(self)
            self.bg:SetColorTexture(0.2, 0.15, 0.35, 0.6)
            local act = self._activity
            if not act then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(act.name or "?", 1, 0.82, 0.27)
            if act.notes and act.notes ~= "" then
                GameTooltip:AddLine(act.notes, 0.9, 0.9, 0.9, true)
            end
            local stop = RS.currentRoute and RS.currentRoute.stops and RS.currentRoute.stops[self._index]
            if stop then
                GameTooltip:AddLine(" ", 1, 1, 1)
                GameTooltip:AddDoubleLine("Travel:",   RS.Flight:FormatTime(stop.travelSecs),    0.7,0.7,0.7, 0.4,1,0.4)
                GameTooltip:AddDoubleLine("Est. time:", RS.Flight:FormatTime(stop.activitySecs), 0.7,0.7,0.7, 0.8,0.8,1)
                GameTooltip:AddDoubleLine("Cumulative total:", RS.Flight:FormatTime(stop.departureSecs), 0.7,0.7,0.7, 1,0.85,0.3)
            end
            -- Rewards — read live from quest APIs when available
            local qID = act.questID
            if qID then
                local rewardLines = {}

                -- Check if reward data is loaded; if not, request it and show placeholder
                local haveData = true
                if HaveQuestRewardData then
                    haveData = HaveQuestRewardData(qID)
                end
                if not haveData then
                    -- Request preload for next hover
                    if C_TaskQuest and C_TaskQuest.RequestPreloadRewardData then
                        pcall(C_TaskQuest.RequestPreloadRewardData, qID)
                    end
                    table.insert(rewardLines, {
                        left = "Rewards loading...", right = "",
                        lr = 0.5, lg = 0.5, lb = 0.5, rr = 0.5, rg = 0.5, rb = 0.5,
                    })
                end

                if haveData then
                    -- ── Currencies (confirmed working: C_QuestLog.GetQuestRewardCurrencies) ──
                    pcall(function()
                        local currencies = C_QuestLog.GetQuestRewardCurrencies(qID)
                        for _, cur in ipairs(currencies or {}) do
                            local cName = cur.name or ""
                            if cur.currencyID then
                                pcall(function()
                                    local info = C_CurrencyInfo.GetCurrencyInfo(cur.currencyID)
                                    if info and info.name and info.name ~= "" then cName = info.name end
                                end)
                            end
                            if cName == "" then cName = "Currency" end
                            local amt = cur.totalRewardAmount or cur.amount or cur.quantity or 0
                            if amt > 0 then
                                table.insert(rewardLines, {
                                    left = cName, right = tostring(amt),
                                    lr = 0.6, lg = 0.85, lb = 1, rr = 1, rg = 1, rb = 1,
                                })
                            end
                        end
                    end)

                    -- ── Items (GetNumQuestLogRewards + GetQuestLogRewardInfo) ──
                    pcall(function()
                        local numItems = GetNumQuestLogRewards(qID) or 0
                        for ri = 1, numItems do
                            local iName, _, iCount, iQuality, _, iID, iLvl = GetQuestLogRewardInfo(ri, qID)
                            if type(iName) == "string" and iName ~= "" then
                                local label = iName
                                if iID and iID > 0 then
                                    pcall(function()
                                        local link = C_Item.GetItemLink(iID)
                                        if link then label = link end
                                    end)
                                end
                                local qr, qg, qb = 0.9, 0.9, 0.9
                                if iQuality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[iQuality] then
                                    local qc = ITEM_QUALITY_COLORS[iQuality]
                                    qr, qg, qb = qc.r, qc.g, qc.b
                                end
                                local rightText = ""
                                if iLvl and iLvl > 0 then rightText = "ilvl " .. iLvl
                                elseif iCount and iCount > 1 then rightText = "x" .. iCount end
                                table.insert(rewardLines, {
                                    left = label, right = rightText,
                                    lr = qr, lg = qg, lb = qb, rr = 0.7, rg = 0.7, rb = 0.7,
                                })
                            end
                        end
                    end)

                    -- ── Gold ──
                    pcall(function()
                        local gold = GetQuestLogRewardMoney(qID) or 0
                        if gold > 0 then
                            local g = math.floor(gold / 10000)
                            local s = math.floor((gold % 10000) / 100)
                            local gs = ""
                            if g > 0 then gs = g .. "g " end
                            if s > 0 then gs = gs .. s .. "s" end
                            if gs == "" then gs = (gold % 100) .. "c" end
                            table.insert(rewardLines, {
                                left = "Gold", right = gs,
                                lr = 1, lg = 0.82, lb = 0, rr = 1, rg = 0.82, rb = 0,
                            })
                        end
                    end)

                    -- ── XP ──
                    pcall(function()
                        local xp = GetQuestLogRewardXP(qID) or 0
                        if xp > 0 then
                            table.insert(rewardLines, {
                                left = "Experience", right = tostring(xp),
                                lr = 0.6, lg = 0.4, lb = 1, rr = 1, rg = 1, rb = 1,
                            })
                        end
                    end)

                    -- ── Faction / reputation rewards ───────────────────────────
                    -- GetNumQuestLogRewardFactions() and GetQuestLogRewardFactionInfo(i)
                    -- return data for the CURRENTLY SELECTED quest in the quest log.
                    -- We must select our target quest first, then restore the previous selection.
                    -- Wrapped in pcall because SelectQuestByID may error if quest isn't in log.
                    pcall(function()
                        local prevIdx = C_QuestLog and C_QuestLog.GetSelectedQuest and
                                        C_QuestLog.GetSelectedQuest() or nil
                        -- Select our quest so the no-arg faction APIs read the right data
                        if C_QuestLog and C_QuestLog.SetSelectedQuest then
                            C_QuestLog.SetSelectedQuest(qID)
                        end
                        local numFactions = GetNumQuestLogRewardFactions and
                                            GetNumQuestLogRewardFactions() or 0
                        for fi = 1, numFactions do
                            local factionID, rawAmt = GetQuestLogRewardFactionInfo(fi)
                            if factionID and rawAmt then
                                local repAmt = math.floor(rawAmt / 100)
                                local factionName = GetFactionInfoByID and GetFactionInfoByID(factionID)
                                if factionName and repAmt ~= 0 then
                                    local sign = repAmt > 0 and "+" or ""
                                    table.insert(rewardLines, {
                                        left  = factionName .. " rep",
                                        right = sign .. repAmt,
                                        lr = 0.6, lg = 1, lb = 0.6,
                                        rr = 0.7, rg = 1, rb = 0.7,
                                    })
                                end
                            end
                        end
                        -- Restore previous selection
                        if prevIdx and C_QuestLog and C_QuestLog.SetSelectedQuest then
                            C_QuestLog.SetSelectedQuest(prevIdx)
                        end
                    end)

                    -- ── Warband reputation bonus flag ─────────────────────────
                    local hasWarbandBonus = false
                    pcall(function()
                        if C_QuestLog.QuestContainsFirstTimeRepBonusForPlayer then
                            hasWarbandBonus = C_QuestLog.QuestContainsFirstTimeRepBonusForPlayer(qID)
                        end
                    end)
                    if not hasWarbandBonus and act.warbandRepBonus then
                        hasWarbandBonus = true
                    end
                    if hasWarbandBonus then
                        table.insert(rewardLines, {
                            left  = "Warband reputation bonus",
                            right = "",
                            lr = 0.85, lg = 0.7, lb = 1,
                            rr = 1,   rg = 1,   rb = 1,
                        })
                    end
                end  -- close haveData check

                if #rewardLines > 0 then
                    GameTooltip:AddLine(" ", 1, 1, 1)
                    GameTooltip:AddLine("Rewards:", 0.9, 0.82, 0.5)
                    for _, rl in ipairs(rewardLines) do
                        if rl.right and rl.right ~= "" then
                            GameTooltip:AddDoubleLine(rl.left, rl.right,
                                rl.lr, rl.lg, rl.lb, rl.rr, rl.rg, rl.rb)
                        else
                            GameTooltip:AddLine(rl.left, rl.lr, rl.lg, rl.lb)
                        end
                    end
                elseif act.rewards and #act.rewards > 0 then
                    GameTooltip:AddLine(" ", 1, 1, 1)
                    GameTooltip:AddLine("Rewards:", 0.9, 0.82, 0.5)
                    for _, tag in ipairs(act.rewards) do
                        GameTooltip:AddLine("  " .. tag, 0.7, 0.7, 0.9)
                    end
                end
            elseif act.rewards and #act.rewards > 0 then
                GameTooltip:AddLine(" ", 1, 1, 1)
                GameTooltip:AddLine("Rewards:", 0.9, 0.82, 0.5)
                for _, tag in ipairs(act.rewards) do
                    GameTooltip:AddLine("  " .. tag, 0.7, 0.7, 0.9)
                end
            end
            -- Personal timing stats
            if RS.Timing then
                local timingLine = RS.Timing:TooltipLine(act)
                if timingLine then
                    GameTooltip:AddLine(" ", 1, 1, 1)
                    GameTooltip:AddLine(timingLine, 1, 0.73, 0.27)
                else
                    GameTooltip:AddLine(" ", 1, 1, 1)
                    GameTooltip:AddLine("No personal timing data yet.", 0.5, 0.5, 0.5)
                    GameTooltip:AddLine("Complete via nav to start tracking.", 0.4, 0.4, 0.4)
                end
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(self)
            RS.UI:SetRowColor(self, self._isOdd)
            GameTooltip:Hide()
        end)

        -- Left-click: set waypoint / jump chain to this stop
        row:SetScript("OnClick", function(self, button)
            if button == "LeftButton" and self._activity then
                RS.UI:SetWaypoint(self._activity, self._index)
            elseif button == "RightButton" and self._activity then
                -- If this is the active stop, advance the chain
                local curIdx = RS.Waypoint:GetCurrent()
                if RS.Waypoint:IsActive() and curIdx == self._index then
                    RS.Waypoint:Complete()
                else
                    RS.Scanner:MarkCompleted(self._activity.id)
                    RS:BuildRoute()
                    RS.UI:Refresh()
                end
                RS.UI:UpdateProgressBar()
            end
        end)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        -- Divider line
        local divider = row:CreateTexture(nil, "OVERLAY")
        divider:SetHeight(1)
        divider:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 4, 0)
        divider:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 0)
        divider:SetColorTexture(0.15, 0.12, 0.25, 0.8)

        self.rowFrames[index] = row
    end
    return self.rowFrames[index]
end

function RS.UI:HighlightActiveRow(index)
    if not self.rowFrames then return end
    for i, row in ipairs(self.rowFrames) do
        if row._activity then
            if i == index then
                row.bg:SetColorTexture(0.3, 0.18, 0.55, 0.85)
                row.indexText:SetTextColor(1, 0.85, 0.3)
            else
                self:SetRowColor(row, row._isOdd)
                row.indexText:SetTextColor(0.784, 0.663, 0.431)
            end
        end
    end
end

function RS.UI:SetRowColor(row, isOdd)
    if isOdd then
        row.bg:SetColorTexture(COLOR.ROW_ODD.r, COLOR.ROW_ODD.g, COLOR.ROW_ODD.b, 1)
    else
        row.bg:SetColorTexture(COLOR.ROW_EVEN.r, COLOR.ROW_EVEN.g, COLOR.ROW_EVEN.b, 1)
    end
end

-- ============================================================
-- REFRESH — repopulates the scroll list from current route
-- ============================================================
function RS.UI:Refresh()
    if not self.frame or not self.frame:IsShown() then return end

    local route = RS.currentRoute
    if not route then
        RS:BuildRoute()
        route = RS.currentRoute
    end

    -- Hide all existing rows
    for _, row in ipairs(self.rowFrames) do
        row:Hide()
    end

    if not route or not route.stops or #route.stops == 0 then
        self.timeLabel:SetText("No activities found")
        self.scrollChild:SetHeight(60)
        return
    end

    local stops = route.stops
    self.scrollChild:SetHeight(math.max(#stops * ROW_H, 60))

    for i, stop in ipairs(stops) do
        local row = self:GetOrCreateRow(i)
        local act = stop.activity
        row._activity = act
        row._isOdd = (i % 2 == 1)
        row._index = i
        row:Show()

        self:SetRowColor(row, row._isOdd)

        -- Index
        row.indexText:SetText(i)
        row.indexText:SetTextColor(COLOR.GOLD.r, COLOR.GOLD.g, COLOR.GOLD.b)

        -- Name (colour-coded by urgency; truncated with ellipsis, full name in tooltip)
        local icon = TYPE_ICON[act.type] or "|TInterface\\Icons\\INV_Misc_QuestionMark:12:12:0:0|t"
        local displayName = act.name or "?"
        -- FontString width is 150px; approximate char limit ~22 chars at normal font size
        if #displayName > 24 then displayName = displayName:sub(1, 22) .. "..." end
        if stop.isUrgent then
            row.nameText:SetText("|cffFF6644" .. icon .. " " .. displayName .. "|r")
        else
            row.nameText:SetText(icon .. " " .. displayName)
            row.nameText:SetTextColor(0.91, 0.83, 0.63)  -- warm parchment
        end

        -- Notes / portal label — prepend appropriate travel icon
        local rawNote = stop.portalNote or act.notes or ""
        -- Truncate the raw plain text BEFORE prepending the icon tag.
        -- The |T...|t tag is ~50 chars but renders as one tiny image;
        -- if we truncate after prepending we'll cut mid-tag and it renders as literal text.
        local rawDisplay = rawNote
        if #rawDisplay > 32 then rawDisplay = rawDisplay:sub(1, 29) .. "..." end
        -- Strip old UTF-8 arrow bytes (→ = 226,134,146) left by Routing.lua note strings
        rawDisplay = rawDisplay:gsub("\226\134\146", ">")

        local noteLine = rawDisplay
        if rawDisplay ~= "" then
            local lower = rawDisplay:lower()
            if lower:find("arcantina") then
                noteLine = TRAVEL_ICON.key .. " " .. rawDisplay
            elseif lower:find("hearth") then
                noteLine = TRAVEL_ICON.hearth .. " " .. rawDisplay
            elseif lower:find("portal") then
                noteLine = TRAVEL_ICON.portal .. " " .. rawDisplay
            elseif lower:find("flight") then
                noteLine = TRAVEL_ICON.flight .. " " .. rawDisplay
            end
        end
        row.notesText:SetText(noteLine)

        -- Zone name (shortened)
        local zoneName = RS.Zones:GetZoneName(act.mapID)
        if #zoneName > 14 then zoneName = zoneName:sub(1,13) .. "…" end
        row.zoneText:SetText(zoneName)
        row.zoneText:SetTextColor(COLOR.SUBTEXT.r, COLOR.SUBTEXT.g, COLOR.SUBTEXT.b)

        -- Travel time
        local travelStr = RS.Flight:FormatTime(stop.travelSecs)
        row.travelText:SetText(travelStr)
        -- Colour-code: fast=green, slow=orange, very slow=red
        if stop.travelSecs < 90 then
            row.travelText:SetTextColor(0.3, 0.9, 0.3)
        elseif stop.travelSecs < 240 then
            row.travelText:SetTextColor(COLOR.GOLD.r, COLOR.GOLD.g, COLOR.GOLD.b)
        else
            row.travelText:SetTextColor(1, 0.5, 0.2)
        end

        -- Activity time — show personal avg if available (amber ~Xm), else category default (white)
        local personalAvg = RS.Timing and RS.Timing:GetPersonalAvg(act)
        if personalAvg then
            row.actText:SetText("|cffFFBB44~" .. RS.Flight:FormatTime(personalAvg) .. "|r")
        else
            row.actText:SetText(RS.Flight:FormatTime(stop.activitySecs))
            row.actText:SetTextColor(COLOR.WHITE.r, COLOR.WHITE.g, COLOR.WHITE.b)
        end

        -- Cumulative total at departure — compact format fits the narrow column
        row.totalText:SetText(RS.Flight:FormatTimeCompact(stop.departureSecs))
        row.totalText:SetTextColor(COLOR.SUBTEXT.r, COLOR.SUBTEXT.g, COLOR.SUBTEXT.b)
    end

    -- Update total time in toolbar
    local totalStr = RS.Flight:FormatTimeCompact(route.totalSecs)
    local travelStr = RS.Flight:FormatTimeCompact(route.totalTravelSecs)
    -- Append warband XP bonus for leveling characters
    local warbandNote = ""
    local activeExps = RS.Expansion._active or {}
    for _, expName in ipairs(activeExps) do
        if expName == "Leveling" then
            local exp = RS.Expansion:GetExpansion("Leveling")
            if exp and exp.db and exp.db.GetWarbandXPBonus then
                local bonus = exp.db:GetWarbandXPBonus()
                if bonus > 0 then
                    warbandNote = string.format("  |cff88ff88+%d%% WB XP|r", bonus)
                end
            end
            break
        end
    end
    self.timeLabel:SetText(string.format("|cffC8A96E%s|r  (%s travel)%s", totalStr, travelStr, warbandNote))

    -- Update footer: show prey hunt state if active, else default help text
    if self.footerText then
        local preyText = nil
        if RS.DB and RS.DB.GetPreyHuntState then
            local hunt = RS.DB:GetPreyHuntState()
            if hunt then
                local stateColors = {
                    Cold  = "6688cc",
                    Warm  = "ff8800",
                    Hot   = "ff0000",
                    Final = "00ff00",
                    Away  = "999999",
                }
                local stateLabels = {
                    Cold  = "Cold",
                    Warm  = "Warm",
                    Hot   = "Hot!",
                    Final = "FOUND!",
                    Away  = "Away",
                }
                local c = stateColors[hunt.state] or "888888"
                local l = stateLabels[hunt.state] or hunt.state
                local zoneName = hunt.zone and RS.Zones:GetZoneName(hunt.zone) or "?"
                preyText = string.format("Prey: |cff%s%s|r  (%s)", c, l, zoneName)
            end
        end
        self.footerText:SetText(preyText or "Left-click: Set waypoint  |  Right-click: Mark done")
    end

    -- Re-apply active stop highlight and progress bar after refresh
    local curIdx = RS.Waypoint.GetCurrent and RS.Waypoint:GetCurrent()
    if curIdx then
        self:HighlightActiveRow(curIdx)
    end
    self:UpdateProgressBar()
    self:UpdateNavBtn()
end

-- ============================================================
-- WAYPOINT INTEGRATION
-- Left-click a row: jump the active chain to that stop (or start it)
-- Right-click: mark done, advance chain, refresh
-- ============================================================
function RS.UI:SetWaypoint(activity, rowIndex)
    if not activity then return end

    if RS.Waypoint.IsActive and RS.Waypoint:IsActive() then
        -- Chain already running — jump to the clicked stop
        if RS.Waypoint.JumpTo then RS.Waypoint:JumpTo(rowIndex) end
    else
        -- Start a fresh chain from this stop onwards
        local route = RS.currentRoute
        if route and route.stops and RS.Waypoint.Start then
            RS.Waypoint:Start(route.stops, rowIndex)
            self:UpdateNavBtn()
        end
    end
    self:UpdateProgressBar()
end

function RS.UI:UpdateToolBar()
    if not self.hearthBtn or not self.arcantinaBtn then return end

    -- ── HEARTHSTONE ──────────────────────────────────────────
    local bindLoc = GetBindLocation and GetBindLocation() or nil
    local hearthReady = true
    local hearthCDSecs = 0
    do
        local start, dur
        if C_Container and C_Container.GetItemCooldown then
            start, dur = C_Container.GetItemCooldown(6948)
        elseif GetItemCooldown then
            start, dur = GetItemCooldown(6948)
        end
        if start and dur and dur > 0 then
            hearthCDSecs = math.max(0, math.ceil((start + dur) - GetTime()))
            if hearthCDSecs > 2 then hearthReady = false end
        end
    end

    -- Icon: desaturate if on CD or no bind location
    local hearthHasLoc = bindLoc and bindLoc ~= ""
    if hearthHasLoc and hearthReady then
        self.hearthBtn._icon:SetDesaturated(false)
        self.hearthBtn._icon:SetAlpha(1)
        self.hearthBtn._border:SetVertexColor(0.6, 0.8, 0.6, 0.6)  -- green tint = ready
    elseif not hearthHasLoc then
        self.hearthBtn._icon:SetDesaturated(true)
        self.hearthBtn._icon:SetAlpha(0.5)
        self.hearthBtn._border:SetVertexColor(0.4, 0.4, 0.4, 0.4)  -- grey = unset
    else
        self.hearthBtn._icon:SetDesaturated(false)
        self.hearthBtn._icon:SetAlpha(0.7)
        self.hearthBtn._border:SetVertexColor(0.9, 0.3, 0.3, 0.6)  -- red = on CD
    end

    -- CooldownFrame swipe
    if not hearthReady and hearthCDSecs > 2 then
        local start, dur
        if C_Container and C_Container.GetItemCooldown then
            start, dur = C_Container.GetItemCooldown(6948)
        end
        if start and dur then
            self.hearthBtn._cd:SetCooldown(start, dur)
        end
    else
        self.hearthBtn._cd:Clear()
    end

    -- Side label: bind location (short name) + CD if active
    if self.hearthLabel then
        local rawLoc = hearthHasLoc and bindLoc or nil
        -- Use short name from table, else use raw loc trimmed to fit, else "Unset"
        local locStr
        if rawLoc then
            locStr = HEARTH_SHORT_NAME[rawLoc]
            if not locStr then
                -- Not in our table — display raw, truncated
                locStr = (#rawLoc > 14) and (rawLoc:sub(1,12) .. "..") or rawLoc
            end
        else
            locStr = "Unset"
        end
        if not hearthReady and hearthCDSecs > 2 then
            local m = math.floor(hearthCDSecs / 60)
            local s = hearthCDSecs % 60
            self.hearthLabel:SetText(string.format("|cffff8888%s\n%dm %ds|r", locStr, m, s))
        else
            self.hearthLabel:SetText("|cffcccccc" .. locStr .. "|r")
        end
    end

    -- ── ARCANTINA KEY ─────────────────────────────────────────
    local arcOwned = (C_ToyBox and C_ToyBox.HasToy and C_ToyBox.HasToy(253629))
        or (IsQuestFlaggedCompleted and IsQuestFlaggedCompleted(86903))
        or (RS_Settings and RS_Settings.hasArcantinaKey)
    local arcCD = RS.Flight and RS.Flight.ArcantinaCDRemaining and RS.Flight:ArcantinaCDRemaining() or 0

    if not arcOwned then
        self.arcantinaBtn._icon:SetDesaturated(true)
        self.arcantinaBtn._icon:SetAlpha(0.35)
        self.arcantinaBtn._border:SetVertexColor(0.3, 0.3, 0.3, 0.4)
        self.arcantinaBtn._cd:Clear()
    elseif arcCD > 2 then
        self.arcantinaBtn._icon:SetDesaturated(false)
        self.arcantinaBtn._icon:SetAlpha(0.7)
        self.arcantinaBtn._border:SetVertexColor(0.9, 0.3, 0.3, 0.6)
        -- Feed the CooldownFrame
        if GetSpellCooldown then
            local start, dur = GetSpellCooldown(1255801)
            if start and dur then
                self.arcantinaBtn._cd:SetCooldown(start, dur)
            end
        end
    else
        self.arcantinaBtn._icon:SetDesaturated(false)
        self.arcantinaBtn._icon:SetAlpha(1)
        self.arcantinaBtn._border:SetVertexColor(0.6, 0.8, 0.6, 0.6)
        self.arcantinaBtn._cd:Clear()
    end

    -- Side label
    if self.arcantinaLabel then
        if not arcOwned then
            self.arcantinaLabel:SetText("|cff888888No Key|r")
        elseif arcCD > 2 then
            local m = math.floor(arcCD / 60)
            local s = arcCD % 60
            self.arcantinaLabel:SetText(string.format("|cffff8888%dm %ds|r", m, s))
        else
            self.arcantinaLabel:SetText("|cff88ff88Ready|r")
        end
    end
end

function RS.UI:UpdateNavBtn()
    if not self.navBtn then return end
    if RS.Waypoint.IsActive and RS.Waypoint:IsActive() then
        self.navBtn:SetText("Stop")
    else
        self.navBtn:SetText("Start")
    end
end

function RS.UI:UpdateProgressBar()
    if not self.progFill or not self.progBg then return end
    if not RS.Waypoint.GetProgress then return end

    local progress = RS.Waypoint:GetProgress()
    local idx, act = RS.Waypoint:GetCurrent()
    local route = RS.currentRoute
    local total = route and route.stops and #route.stops or 0

    -- Width of the background bar
    local bgWidth = self.progBg:GetWidth()
    local fillW = math.max(1, math.floor(bgWidth * progress))
    self.progFill:SetWidth(fillW)

    if RS.Waypoint:IsActive() and act and total > 0 then
        self.progLabel:SetText(string.format(
            "Navigating: Stop %d/%d — %s",
            idx, total, act.name or "?"
        ))
        -- Colour shifts void → gold as route completes
        local t = progress
        self.progFill:SetColorTexture(
            COLOR.VOID.r + (COLOR.GOLD.r - COLOR.VOID.r) * t,
            COLOR.VOID.g + (COLOR.GOLD.g - COLOR.VOID.g) * t,
            COLOR.VOID.b + (COLOR.GOLD.b - COLOR.VOID.b) * t,
            0.9
        )
    else
        self.progFill:SetWidth(1)
        self.progLabel:SetText("")
    end
end

-- ============================================================
-- SHOW / HIDE / TOGGLE
-- ============================================================
function RS.UI:Show()
    if not self.frame then self:Init() end
    RS:ScanQuests()
    RS:BuildRoute()
    self:Refresh()
    self.frame:Show()
    self.isOpen = true
end

function RS.UI:Hide()
    if self.frame then
        self.frame:Hide()
        self.isOpen = false
    end
end

function RS.UI:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

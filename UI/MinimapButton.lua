-- UI/MinimapButton.lua
-- Draggable minimap button, verified against live Blizzard source
-- (Gethe/wow-ui-source refs/heads/live, Blizzard_Minimap/Mainline/Minimap.xml)
--
-- Confirmed facts from live XML:
--   • MinimapCluster  (256×256) → MinimapContainer (215×226) → Minimap (198×198)
--   • Global "Minimap" IS the 198×198 map frame — GetWidth() returns 198, reliable
--   • Button orbit radius = Minimap:GetWidth()/2 + 10 = 109
--   • MiniMap-TrackingBorder texture REMOVED in retail (atlas-only now); use atlas
--   • MinimapBackdrop is a child of Minimap (child frame, NOT a sibling)
--   • Correct parent for addon buttons = Minimap  (confirmed from XML hierarchy)
--   • MinimapCluster.ZoneTextButton, .Tracking, .IndicatorFrame, .MinimapContainer
--     are the live child key names

RS.Minimap = RS.Minimap or {}

function RS.Minimap:Init()
    if self.button then return end

    -- Parent to the Minimap frame (198×198 map widget)
    -- Named globally so /fstack can identify it
    -- Standard minimap button layout matching LibDBIcon-1.0 / Blizzard style.
    -- Uses the same textures and sizes as every other addon minimap button.
    local button = CreateFrame("Button", "RSMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFixedFrameStrata(true)
    button:SetFrameLevel(8)
    button:SetFixedFrameLevel(true)
    button:RegisterForClicks("anyUp")

    -- Background circle (dark minimap background)
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(24, 24)
    bg:SetPoint("CENTER")
    bg:SetTexture(136467)  -- "Interface\\Minimap\\UI-Minimap-Background"

    -- Addon icon (centered in the circle)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER")
    if not icon:SetTexture("Interface\\AddOns\\RouteSweet\\Textures\\MinimapIcon") then
        icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    end
    button._icon = icon

    -- Golden border ring (standard MiniMap-TrackingBorder)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(50, 50)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetTexture(136430)  -- "Interface\\Minimap\\MiniMap-TrackingBorder"
    button._border = border

    -- Highlight (set on button, not as child texture — matches LibDBIcon)
    button:SetHighlightTexture(136477)  -- "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"

    -- Tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cffC8A96ERouteSweet|r")
        GameTooltip:AddLine("Left-click: Open/Close route", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click: Settings",        0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag: Reposition",             0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Click handler (suppressed during drag)
    button:SetScript("OnClick", function(self, btn)
        if RS.Minimap.isDragging then return end
        if btn == "RightButton" then
            if RS.Settings then RS.Settings:Toggle() end
        else
            RS.UI:Toggle()
        end
    end)

    -- Drag to reposition around the minimap edge.
    -- 4-px movement threshold so normal clicks still fire.
    button:SetScript("OnMouseDown", function(self, btn)
        if btn == "LeftButton" then
            RS.Minimap.isDragging = false
            RS.Minimap._dragX, RS.Minimap._dragY = GetCursorPosition()
            button:SetScript("OnUpdate", function()
                local cx, cy = GetCursorPosition()
                if not RS.Minimap.isDragging then
                    local dx = cx - (RS.Minimap._dragX or cx)
                    local dy = cy - (RS.Minimap._dragY or cy)
                    if dx*dx + dy*dy > 16 then
                        RS.Minimap.isDragging = true
                    else
                        return
                    end
                end
                -- Minimap:GetCenter() returns screen coords in Minimap's own
                -- coordinate space.  Divide cursor by UIParent scale to match.
                local mx, my = Minimap:GetCenter()
                local scale  = UIParent:GetEffectiveScale()
                RS.Minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
                RS.Minimap:UpdatePosition()
            end)
        end
    end)
    button:SetScript("OnMouseUp", function(self, btn)
        if btn == "LeftButton" then
            button:SetScript("OnUpdate", nil)
            if RS.Minimap.isDragging then
                RS.Minimap.isDragging = false
                if RS_Settings then RS_Settings.minimapAngle = RS.Minimap.angle end
            end
        end
    end)

    -- Hide if user disabled the minimap button in settings
    if RS_Settings and RS_Settings.showMinimapButton == false then
        button:Hide()
    end

    self.button = button

    -- Position is set after button exists
    self.angle = (RS_Settings and RS_Settings.minimapAngle) or 220
    self:UpdatePosition()
end

function RS.Minimap:UpdatePosition()
    if not self.button then return end
    -- Minimap frame is 198×198 (confirmed in live Minimap.xml).
    -- Orbit just outside the circle: radius = 198/2 + 10 = 109.
    -- ExpansionLandingPageMinimapButton uses TOPLEFT -3,-150 on MinimapBackdrop
    -- (215×226), which puts it ~113px from Minimap center — consistent.
    local radius = 109
    local angle  = math.rad(self.angle or 220)
    self.button:ClearAllPoints()
    self.button:SetPoint("CENTER", Minimap, "CENTER",
        radius * math.cos(angle),
        radius * math.sin(angle))
end

function RS.Minimap:SetShown(shown)
    if self.button then
        if shown then self.button:Show() else self.button:Hide() end
    end
end

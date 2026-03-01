-- ProfitCraft: minimap.lua
-- Creates a minimap button for quick access to the dashboard.
-- Compatible with both standard minimap and pfUI's minimap replacement.

local minimapButton = CreateFrame("Button", "ProfitCraftMinimapButton", Minimap)
minimapButton:SetWidth(31)
minimapButton:SetHeight(31)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)
minimapButton:EnableMouse(true)
minimapButton:SetMovable(true)
minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
minimapButton:RegisterForDrag("LeftButton")

-- Position: default angle around the minimap (in degrees, 0 = top)
local defaultAngle = 225
local minimapRadius = 80

-- Textures
local overlay = minimapButton:CreateTexture(nil, "OVERLAY")
overlay:SetWidth(53)
overlay:SetHeight(53)
overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
overlay:SetPoint("TOPLEFT")

local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
icon:SetWidth(20)
icon:SetHeight(20)
icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
icon:SetPoint("CENTER", minimapButton, "CENTER", 0, 1)

local highlight = minimapButton:CreateTexture(nil, "HIGHLIGHT")
highlight:SetWidth(24)
highlight:SetHeight(24)
highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
highlight:SetPoint("CENTER")
highlight:SetBlendMode("ADD")

-- Position calculation
local function UpdatePosition(angle)
    local rads = math.rad(angle)
    local x = math.cos(rads) * minimapRadius
    local y = math.sin(rads) * minimapRadius
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Dragging around minimap
local isDragging = false

minimapButton:SetScript("OnDragStart", function()
    isDragging = true
    this:LockHighlight()
end)

minimapButton:SetScript("OnDragStop", function()
    isDragging = false
    this:UnlockHighlight()
end)

minimapButton:SetScript("OnUpdate", function()
    if not isDragging then return end

    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale

    local angle = math.deg(math.atan2(cy - my, cx - mx))

    -- Save position
    if ProfitCraftDB then
        ProfitCraftDB.minimapAngle = angle
    end

    UpdatePosition(angle)
end)

-- Click handlers
minimapButton:SetScript("OnClick", function()
    if arg1 == "LeftButton" then
        ProfitCraft_ToggleDashboard()
    elseif arg1 == "RightButton" then
        -- Right-click: show help in chat
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[ProfitCraft]|r Commands:")
            DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/pc|r — Toggle dashboard")
            DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/pc clear|r — Clear shopping list")
            DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/pc help|r — Show all commands")
            DEFAULT_CHAT_FRAME:AddMessage("  |cFF888888Left-click minimap icon to toggle|r")
            DEFAULT_CHAT_FRAME:AddMessage("  |cFF888888Right-click minimap icon for this help|r")
        end
    end
end)

-- Tooltip
minimapButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:AddLine("ProfitCraft", 0, 1, 0)
    GameTooltip:AddLine("|cFFFFFFFFLeft-click:|r Toggle Dashboard", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("|cFFFFFFFFRight-click:|r Show Commands", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("|cFFFFFFFFDrag:|r Move this button", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Initialize position (called after SavedVariables are loaded)
function ProfitCraft_InitMinimapButton()
    local angle = defaultAngle
    if ProfitCraftDB and ProfitCraftDB.minimapAngle then
        angle = ProfitCraftDB.minimapAngle
    end
    UpdatePosition(angle)
end

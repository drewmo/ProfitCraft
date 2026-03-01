-- ProfitCraft: minimap.lua
-- Creates a minimap button for quick access to the dashboard.
-- Handles both default Minimap and pfUI-style replacements.

local defaultAngle = 225
local currentAnchor = nil
local isDragging = false
local reanchorElapsed = 0

local function NormalizeAngle(angle)
    if type(angle) ~= "number" then
        return defaultAngle
    end

    angle = math.mod(angle, 360)
    if angle < 0 then
        angle = angle + 360
    end
    return angle
end

local function GetSavedAngle()
    if ProfitCraftDB and type(ProfitCraftDB.minimapAngle) == "number" then
        return NormalizeAngle(ProfitCraftDB.minimapAngle)
    end
    return defaultAngle
end

local function SaveAngle(angle)
    if not ProfitCraftDB then
        ProfitCraftDB = {}
    end
    ProfitCraftDB.minimapAngle = NormalizeAngle(angle)
end

local function GetMinimapAnchor()
    if pfMinimap and pfMinimap:IsVisible() then
        return pfMinimap
    end
    if Minimap and Minimap:IsVisible() then
        return Minimap
    end
    if pfMinimap then
        return pfMinimap
    end
    if Minimap then
        return Minimap
    end
    if MinimapCluster then
        return MinimapCluster
    end
    return UIParent
end

local function GetMinimapRadius(anchor)
    local radius = 78
    if anchor and anchor.GetWidth and anchor.GetHeight then
        local width = anchor:GetWidth() or 0
        local height = anchor:GetHeight() or 0
        local half = math.min(width, height) / 2
        if half > 0 then
            radius = half + 6
        end
    end

    if radius < 52 then radius = 52 end
    if radius > 92 then radius = 92 end
    return radius
end

local minimapButton = CreateFrame("Button", "ProfitCraftMinimapButton", UIParent)
minimapButton:SetWidth(31)
minimapButton:SetHeight(31)
minimapButton:SetFrameStrata("HIGH")
minimapButton:SetFrameLevel(10)
minimapButton:EnableMouse(true)
minimapButton:SetMovable(true)
minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
minimapButton:RegisterForDrag("LeftButton")
if minimapButton.SetClampedToScreen then
    minimapButton:SetClampedToScreen(true)
end

local overlay = minimapButton:CreateTexture(nil, "OVERLAY")
overlay:SetWidth(53)
overlay:SetHeight(53)
overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
overlay:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 0, 0)

local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
icon:SetWidth(20)
icon:SetHeight(20)
icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
icon:SetPoint("CENTER", minimapButton, "CENTER", 0, 1)

local highlight = minimapButton:CreateTexture(nil, "HIGHLIGHT")
highlight:SetWidth(24)
highlight:SetHeight(24)
highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
highlight:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)
highlight:SetBlendMode("ADD")

local function UpdatePosition(angle)
    local anchor = GetMinimapAnchor()
    currentAnchor = anchor

    local safeAngle = NormalizeAngle(angle)
    local radius = GetMinimapRadius(anchor)
    local rads = math.rad(safeAngle)
    local x = math.cos(rads) * radius
    local y = math.sin(rads) * radius

    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", anchor, "CENTER", x, y)

    local anchorLevel = 0
    if anchor and anchor.GetFrameLevel then
        anchorLevel = anchor:GetFrameLevel() or 0
    end
    minimapButton:SetFrameStrata("HIGH")
    minimapButton:SetFrameLevel(anchorLevel + 8)
    minimapButton:Show()
end

minimapButton:SetScript("OnDragStart", function()
    isDragging = true
    this:LockHighlight()
end)

minimapButton:SetScript("OnDragStop", function()
    isDragging = false
    this:UnlockHighlight()
    UpdatePosition(GetSavedAngle())
end)

minimapButton:SetScript("OnUpdate", function()
    if isDragging then
        local anchor = GetMinimapAnchor()
        if not anchor or not anchor.GetCenter then return end

        local mx, my = anchor:GetCenter()
        if not mx or not my then return end

        local cx, cy = GetCursorPosition()
        local scale = anchor:GetEffectiveScale() or 1
        if scale == 0 then scale = 1 end
        cx, cy = cx / scale, cy / scale

        local angle = NormalizeAngle(math.deg(math.atan2(cy - my, cx - mx)))
        SaveAngle(angle)
        UpdatePosition(angle)
        return
    end

    reanchorElapsed = reanchorElapsed + (arg1 or 0)
    if reanchorElapsed < 0.5 then
        return
    end
    reanchorElapsed = 0

    local anchor = GetMinimapAnchor()
    if anchor ~= currentAnchor then
        UpdatePosition(GetSavedAngle())
    end
end)

minimapButton:SetScript("OnClick", function()
    if arg1 == "LeftButton" then
        ProfitCraft_ToggleDashboard()
    elseif arg1 == "RightButton" then
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

function ProfitCraft_InitMinimapButton()
    SaveAngle(GetSavedAngle())
    UpdatePosition(GetSavedAngle())
end

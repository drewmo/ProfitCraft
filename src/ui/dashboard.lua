-- ProfitCraft: dashboard.lua
-- Handles population, sorting, and display of the Dashboard UI.

-- This array will hold the calculated recipes to be displayed
ProfitCraft_List = {}

-- Create the buttons when the frame loads
function ProfitCraft_Dashboard_OnLoad(frame)
    if not frame then frame = ProfitCraftDashboard end
    
    for i = 1, 10 do
        local btn = CreateFrame("Button", "ProfitCraftDashboardEntry"..i, frame, "ProfitCraftEntryTemplate")
        if i == 1 then
            btn:SetPoint("TOPLEFT", ProfitCraftDashboardScrollFrame, "TOPLEFT", 8, -4)
        else
            btn:SetPoint("TOPLEFT", "ProfitCraftDashboardEntry"..(i-1), "BOTTOMLEFT", 0, 0)
        end
        -- Initially hide them
        btn:Hide()
    end
end

-- Helper to convert copper values into printable Gold, Silver, Copper strings
function ProfitCraft_FormatCurrency(copper)
    if not copper or copper == 0 then return "0c" end
    
    local isNegative = copper < 0
    if isNegative then copper = math.abs(copper) end

    local g = math.floor(copper / 10000)
    local s = math.floor(math.mod(copper / 100, 100))
    local c = math.mod(copper, 100)

    local str = ""
    if g > 0 then str = str .. g .. "g " end
    if s > 0 or g > 0 then str = str .. s .. "s " end
    str = str .. c .. "c"
    
    if isNegative then
        return "|cFFFF0000-" .. str .. "|r"
    else
        return "|cFF00FF00" .. str .. "|r"
    end
end

-- Refresh the ScrollFrame Data
function ProfitCraft_DashboardUpdate()
    local scrollFrame = getglobal("ProfitCraftDashboardScrollFrame")
    if not scrollFrame then return end
    
    -- In Vanilla, you must define the count of items to dictate scrollbar size
    -- Currently a placeholder until XML list elements are generated
    local numItems = table.getn(ProfitCraft_List)
    
    -- FauxScrollFrame_Update(frame, numItems, numLinesToDisplay, lineHeight)
    FauxScrollFrame_Update(scrollFrame, numItems, 10, 24)
    
    -- NOTE: In the next iteration, we will dynamically write values to the
    -- 10 font strings stacked inside the scroll frame based on the offset.
    local offset = FauxScrollFrame_GetOffset(scrollFrame)
    for i = 1, 10 do
        local index = offset + i
        local button = getglobal("ProfitCraftDashboardEntry"..i)
        
        if button then
            if index <= numItems then
                local data = ProfitCraft_List[index]
                getglobal("ProfitCraftDashboardEntry"..i.."Name"):SetText(data.name)
                getglobal("ProfitCraftDashboardEntry"..i.."Profit"):SetText(ProfitCraft_FormatCurrency(data.profit))
                button:Show()
            else
                button:Hide()
            end
        end
    end
end

-- Button logic to show the dashboard
function ProfitCraft_ToggleDashboard()
    if not ProfitCraftDashboard then
        DEFAULT_CHAT_FRAME:AddMessage("ProfitCraft Error: Dashboard UI frame is missing or failed to render.")
        return
    end

    if ProfitCraftDashboard:IsVisible() then
        ProfitCraftDashboard:Hide()
    else
        ProfitCraftDashboard:Show()
        ProfitCraft_DashboardUpdate()
    end
end

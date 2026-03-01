-- ProfitCraft Addon
-- 1.12.1 Client Compatibility (Turtle WoW)

local addonName = "ProfitCraft"

local frame = CreateFrame("Frame", addonName.."Frame")

-- Helper to print messages to the default chat frame
local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00["..addonName.."]|r " .. msg)
    end
end

-- ============================================================================
-- Aux Pricing Integration
-- ============================================================================

-- Try multiple known Aux API paths for maximum compatibility across
-- different Turtle WoW Aux versions.
local function GetAuxMarketValue(itemLink)
    if not itemLink then return 0 end

    local _, _, itemId = string.find(itemLink, "item:(%d+):")
    if not itemId then return 0 end

    local item_key = itemId .. ":0"

    -- Method 1: Aux.history.price_data (most common on Turtle WoW)
    if Aux and Aux.history and Aux.history.price_data then
        local ok, price_data = pcall(Aux.history.price_data, item_key)
        if ok and price_data then
            -- price_data contains: market_value, min_buyout, max_price, data (11 daily points)
            if price_data.market_value and price_data.market_value > 0 then
                return price_data.market_value
            end
            if price_data.min_buyout and price_data.min_buyout > 0 then
                return price_data.min_buyout
            end
        end
    end

    -- Method 2: aux.history.value (some forks)
    if aux and aux.history and aux.history.value then
        local ok, val = pcall(aux.history.value, itemId)
        if ok and val and val > 0 then
            return val
        end
    end

    -- Method 3: direct persistence lookup (some newer forks)
    if Aux and Aux.persistence and Aux.persistence.get then
        local ok, val = pcall(Aux.persistence.get, item_key)
        if ok and val and type(val) == "number" and val > 0 then
            return val
        end
    end

    return 0
end

-- ============================================================================
-- Events
-- ============================================================================

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("TRADE_SKILL_SHOW")
frame:RegisterEvent("TRADE_SKILL_UPDATE")

local hasAux = false
local lastCalcTime = 0
local CALC_THROTTLE = 1 -- seconds between recalculations

frame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == addonName then
        Print("v1.1.0 loaded. Open a profession window to begin.")

        -- Check if Aux is available
        if Aux and Aux.history then
            hasAux = true
            Print("aux-addon detected — pricing active.")
        elseif aux and aux.history then
            hasAux = true
            Print("aux-addon detected (alt API) — pricing active.")
        else
            Print("|cFFFF8800Warning:|r aux-addon not detected. Prices will show as 0c.")
            Print("Install aux-addon for accurate market pricing.")
        end

        -- Initialize SavedVariables
        if not ProfitCraftDB then
            ProfitCraftDB = {}
        end

    elseif event == "TRADE_SKILL_SHOW" then
        ProfitCraft_CalculateProfits()

    elseif event == "TRADE_SKILL_UPDATE" then
        -- Throttle updates to avoid spam during rapid events
        local now = GetTime()
        if (now - lastCalcTime) > CALC_THROTTLE then
            lastCalcTime = now
            ProfitCraft_CalculateProfits()
        end
    end
end)

-- ============================================================================
-- Slash Command
-- ============================================================================

SLASH_PROFITCRAFT1 = "/profitcraft"
SLASH_PROFITCRAFT2 = "/pc"
SlashCmdList["PROFITCRAFT"] = function(msg)
    if msg == "help" then
        Print("Commands:")
        Print("  /pc - Toggle the ProfitCraft dashboard")
        Print("  /pc help - Show this help message")
    else
        ProfitCraft_ToggleDashboard()
    end
end

-- ============================================================================
-- Core Profit Calculation
-- ============================================================================

function ProfitCraft_CalculateProfits()
    local numSkills = GetNumTradeSkills()
    if not numSkills or numSkills == 0 then return end

    local skillName, skillRank, skillMaxRank = GetTradeSkillLine()
    if not skillName then return end

    Print("Scanning " .. skillName .. " (" .. skillRank .. "/" .. skillMaxRank .. ")...")

    -- Clear previous results
    ProfitCraft_List = {}

    -- Build a lookup of learned recipe names so we can exclude them from unlearned
    local learnedNames = {}

    -- ----------------------------------------------------------------
    -- Pass 1: Learned recipes from the TradeSkill window
    -- ----------------------------------------------------------------
    for i = 1, numSkills do
        local name, skillType, numAvailable, isExpanded = GetTradeSkillInfo(i)

        -- Skip headers and nil entries
        if name and skillType ~= "header" then
            learnedNames[name] = true

            local itemLink = GetTradeSkillItemLink(i)
            local itemValue = 0
            if itemLink then
                itemValue = GetAuxMarketValue(itemLink)
            end

            local numReagents = GetTradeSkillNumReagents(i)
            local totalReagentCost = 0
            local reagents = {}

            for r = 1, numReagents do
                local rName, rTexture, rCount, rPlayerCount = GetTradeSkillReagentInfo(i, r)
                local rLink = GetTradeSkillReagentItemLink(i, r)
                local rValue = 0
                if rLink then
                    rValue = GetAuxMarketValue(rLink)
                end
                totalReagentCost = totalReagentCost + (rValue * rCount)

                table.insert(reagents, {
                    name = rName or "Unknown",
                    count = rCount,
                    playerCount = rPlayerCount or 0,
                    unitCost = rValue,
                    link = rLink,
                })
            end

            local profit = itemValue - totalReagentCost

            table.insert(ProfitCraft_List, {
                name = name,
                itemLink = itemLink,
                marketValue = itemValue,
                cost = totalReagentCost,
                profit = profit,
                isLearned = true,
                source = "Learned",
                sourceDetails = nil,
                reagents = reagents,
                skillType = skillType,
            })
        end
    end

    -- ----------------------------------------------------------------
    -- Pass 2: Unlearned recipes from our Recipe Database
    -- ----------------------------------------------------------------
    local unlearned = ProfitCraft_GetUnlearnedRecipes(skillName, skillRank)
    if unlearned then
        for _, recipe in ipairs(unlearned) do
            -- Skip if player already knows this recipe
            if not learnedNames[recipe.name] then
                -- For unlearned recipes we can try to look up the item price
                -- using the recipe's item ID
                local itemValue = 0
                if recipe.id then
                    local fakeKey = recipe.id .. ":0"
                    if Aux and Aux.history and Aux.history.price_data then
                        local ok, price_data = pcall(Aux.history.price_data, fakeKey)
                        if ok and price_data then
                            itemValue = (price_data.market_value or 0)
                        end
                    end
                end

                table.insert(ProfitCraft_List, {
                    name = recipe.name,
                    itemLink = nil,
                    marketValue = itemValue,
                    cost = 0,           -- Can't calculate cost for unlearned (no reagent links)
                    profit = itemValue, -- Best estimate: full value since cost unknown
                    isLearned = false,
                    source = recipe.source or "Unknown",
                    sourceDetails = recipe.details or nil,
                    reagents = {},
                    skillType = nil,
                })
            end
        end
    end

    -- Apply sort and filter then refresh the UI
    ProfitCraft_ApplySortAndFilter()

    -- Show the dashboard
    if ProfitCraftDashboard then
        if not ProfitCraftDashboard:IsVisible() then
            ProfitCraftDashboard:Show()
        end
        ProfitCraft_DashboardUpdate()
        ProfitCraft_UpdateTracker()
    end

    local learnedCount = 0
    local unlearnedCount = 0
    for _, entry in ipairs(ProfitCraft_List) do
        if entry.isLearned then
            learnedCount = learnedCount + 1
        else
            unlearnedCount = unlearnedCount + 1
        end
    end
    Print("Found " .. learnedCount .. " learned + " .. unlearnedCount .. " unlearned recipes.")
end

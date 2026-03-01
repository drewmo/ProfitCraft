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
-- OldManAlpha/aux-addon uses a custom module system via require().
-- The history module is at 'aux.core.history' and exposes:
--   .value(item_key)        -> weighted median of last 11 daily min buyouts
--   .market_value(item_key) -> today's daily minimum buyout
-- Item keys are formatted as "itemId:suffixId" e.g. "2318:0"

local aux_history = nil
local aux_info = nil
local hasAux = false

local function InitAuxAPI()
    -- Try the module require system (OldManAlpha/aux-addon)
    if require then
        local ok, hist = pcall(require, 'aux.core.history')
        if ok and hist and hist.value then
            aux_history = hist
            hasAux = true
            return true
        end
    end

    -- Fallback: check global namespace variants
    if Aux and Aux.history and Aux.history.price_data then
        hasAux = true
        return true
    end

    return false
end

local function GetAuxMarketValue(itemLink)
    if not hasAux or not itemLink then return 0 end

    local _, _, itemId = string.find(itemLink, "item:(%d+):")
    if not itemId then return 0 end

    local item_key = itemId .. ":0"

    -- Method 1: aux.core.history module (OldManAlpha fork — Turtle WoW standard)
    if aux_history then
        -- .value() = weighted historical median (best for profit calculations)
        local ok, val = pcall(aux_history.value, item_key)
        if ok and val and val > 0 then
            return val
        end
        -- .market_value() = today's daily min buyout
        local ok2, val2 = pcall(aux_history.market_value, item_key)
        if ok2 and val2 and val2 > 0 then
            return val2
        end
    end

    -- Method 2: Legacy Aux.history.price_data (older forks)
    if Aux and Aux.history and Aux.history.price_data then
        local ok, price_data = pcall(Aux.history.price_data, item_key)
        if ok and price_data then
            if price_data.market_value and price_data.market_value > 0 then
                return price_data.market_value
            end
            if price_data.min_buyout and price_data.min_buyout > 0 then
                return price_data.min_buyout
            end
        end
    end

    return 0
end

-- Get value by raw item ID (for unlearned recipes where we don't have item links)
local function GetAuxValueByID(itemId)
    if not hasAux or not itemId then return 0 end

    local item_key = tostring(itemId) .. ":0"

    if aux_history then
        local ok, val = pcall(aux_history.value, item_key)
        if ok and val and val > 0 then return val end
        local ok2, val2 = pcall(aux_history.market_value, item_key)
        if ok2 and val2 and val2 > 0 then return val2 end
    end

    if Aux and Aux.history and Aux.history.price_data then
        local ok, pd = pcall(Aux.history.price_data, item_key)
        if ok and pd then
            return (pd.market_value or pd.min_buyout or 0)
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

local lastCalcTime = 0
local CALC_THROTTLE = 1

frame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == addonName then
        Print("v1.2.0 loaded. Open a profession window or type /pc")

        -- Initialize Aux API
        InitAuxAPI()
        if hasAux then
            Print("aux-addon detected — pricing active.")
        else
            Print("|cFFFF8800Warning:|r aux-addon not found. Prices will show as '-'.")
        end

        -- Initialize SavedVariables
        if not ProfitCraftDB then
            ProfitCraftDB = {}
        end

    elseif event == "TRADE_SKILL_SHOW" then
        -- Re-check Aux on first use (it may load after us)
        if not hasAux then InitAuxAPI() end
        ProfitCraft_CalculateProfits()

    elseif event == "TRADE_SKILL_UPDATE" then
        local now = GetTime()
        if (now - lastCalcTime) > CALC_THROTTLE then
            lastCalcTime = now
            ProfitCraft_CalculateProfits()
        end
    end
end)

-- ============================================================================
-- Slash Commands
-- ============================================================================

SLASH_PROFITCRAFT1 = "/profitcraft"
SLASH_PROFITCRAFT2 = "/pc"
SlashCmdList["PROFITCRAFT"] = function(msg)
    if msg == "help" then
        Print("Commands:")
        Print("  /pc — Toggle the dashboard")
        Print("  /pc clear — Clear the shopping list")
        Print("  /pc help — Show this help")
    elseif msg == "clear" then
        ProfitCraft_ShoppingList = {}
        ProfitCraft_UpdateTracker()
        Print("Shopping list cleared.")
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

    ProfitCraft_List = {}
    local learnedNames = {}

    -- Pass 1: Learned recipes
    for i = 1, numSkills do
        local name, skillType, numAvailable, isExpanded = GetTradeSkillInfo(i)
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

    -- Pass 2: Unlearned recipes
    local unlearned = ProfitCraft_GetUnlearnedRecipes(skillName, skillRank)
    if unlearned then
        for _, recipe in ipairs(unlearned) do
            if not learnedNames[recipe.name] then
                local itemValue = 0
                if recipe.id then
                    itemValue = GetAuxValueByID(recipe.id)
                end

                table.insert(ProfitCraft_List, {
                    name = recipe.name,
                    itemLink = nil,
                    marketValue = itemValue,
                    cost = 0,
                    profit = itemValue,
                    isLearned = false,
                    source = recipe.source or "Unknown",
                    sourceDetails = recipe.details or nil,
                    reagents = {},
                    skillType = nil,
                })
            end
        end
    end

    -- Apply filters and sort, then refresh UI
    ProfitCraft_ApplySortAndFilter()

    if ProfitCraftDashboard then
        if not ProfitCraftDashboard:IsVisible() then
            ProfitCraftDashboard:Show()
        end
        ProfitCraft_DashboardUpdate()
        ProfitCraft_UpdateTracker()
    end

    local lc, uc = 0, 0
    for _, e in ipairs(ProfitCraft_List) do
        if e.isLearned then lc = lc + 1 else uc = uc + 1 end
    end
    Print("Found " .. lc .. " learned + " .. uc .. " unlearned recipes.")
end

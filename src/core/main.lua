-- ProfitCraft Addon
-- 1.12.1 Client Compatibility

local addonName = "ProfitCraft"
local frame = CreateFrame("Frame", addonName.."Frame")

-- Helper to print messages to the default chat frame
local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00["..addonName.."]|r: " .. msg)
end

-- Hook into specific events
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("TRADE_SKILL_SHOW")
frame:RegisterEvent("TRADE_SKILL_UPDATE")

frame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == addonName then
        Print("Loaded successfully. Waiting for profession window.")
        -- Initialize SavedVariables here if they don't exist
        if not ProfitCraftDB then
            ProfitCraftDB = {}
        end
    elseif event == "TRADE_SKILL_SHOW" then
        -- Print("Trade skill window opened.")
        ProfitCraft_CalculateProfits()
    elseif event == "TRADE_SKILL_UPDATE" then
        -- This can be a bit spammy, will need to throttle it eventually
        -- ProfitCraft_CalculateProfits()
    end
end)

-- Helper to extract Aux price safely
local function GetAuxMarketValue(itemLink)
    if not Aux or not Aux.history then return 0 end
    
    local _, _, itemId = string.find(itemLink, "item:(%d+):")
    if itemId then
        local item_key = itemId .. ":0"
        local price_data = Aux.history.price_data(item_key)
        
        -- Default to the minimum buyout or median if available
        if price_data then
            -- Note: price_data structure depends on exact Aux version, usually: 
            -- price_data.market_value or iterating through the history points to get median
            -- We will placeholder this with an assumption that price_data returns a straight value, 
            -- or we write a more robust integration later when testing in the client.
            -- This function currently represents the entry point for that hook.
            -- For now, return a random or zeroed out placeholder based on what is parsed.
            return price_data.value or 0 
        end
    end
    return 0
end

-- Calculation logic
function ProfitCraft_CalculateProfits()
    local numSkills = GetNumTradeSkills()
    if numSkills == 0 then return end
    
    local skillName, skillRank, skillMaxRank = GetTradeSkillLine()
    Print("Calculating profits for: " .. skillName .. " (" .. skillRank .. "/" .. skillMaxRank .. ")")
    
    -- Clear previous results
    ProfitCraft_List = {}
    
    for i = 1, numSkills do
        local name, type, numAvailable, isExpanded = GetTradeSkillInfo(i)
        if type ~= "header" then
            local itemLink = GetTradeSkillItemLink(i)
            if itemLink then
                local itemValue = GetAuxMarketValue(itemLink)
                
                local numReagents = GetTradeSkillNumReagents(i)
                local totalReagentCost = 0
                
                for r = 1, numReagents do
                    local rName, rTexture, rCount, rPlayerCount = GetTradeSkillReagentInfo(i, r)
                    local rLink = GetTradeSkillReagentItemLink(i, r)
                    if rLink then
                        local rValue = GetAuxMarketValue(rLink)
                        totalReagentCost = totalReagentCost + (rValue * rCount)
                    end
                end
                
                local profit = itemValue - totalReagentCost
                
                -- Cache result to display in the dashboard
                table.insert(ProfitCraft_List, {
                    name = name,
                    itemLink = itemLink,
                    marketValue = itemValue,
                    cost = totalReagentCost,
                    profit = profit,
                    isLearned = true,
                    -- Could pass required skill and source here if we cross reference
                })
                
                if profit > 0 then
                    Print("Recipe: " .. name .. " - PROFIT: " .. ProfitCraft_FormatCurrency(profit))
                end
            end
        end
    end
    
    -- Now append any Unlearned recipes from our Recipe Database
    local unlearned = ProfitCraft_GetUnlearnedRecipes(skillName, skillRank)
    if unlearned then
        for _, recipe in ipairs(unlearned) do
            -- In a real implementation we would fetch the exact itemLink for the recipe.id here
            -- and then calculate its profit via GetAuxMarketValue(id).
        end
    end
    
    -- Sort list by profit highest -> lowest
    table.sort(ProfitCraft_List, function(a, b) return a.profit > b.profit end)
    
    -- Update UI
    if not ProfitCraftDashboard:IsVisible() then
        ProfitCraft_ToggleDashboard() -- Auto open for testing purposes
    else
        ProfitCraft_DashboardUpdate()
    end
end

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

local SETTINGS_DEFAULTS = {
    showLearned = true,
    showUnlearned = true,
    showQuest = true,
    showTrainer = true,
    showVendor = true,
    showDrop = true,
    showShoppingOnly = false,
    autoOpenMerchant = true,
    autoOpenAuction = true,
    autoOpenShoppingOnly = true,
}

function ProfitCraft_EnsureSettings()
    if not ProfitCraftDB then ProfitCraftDB = {} end
    if not ProfitCraftDB.settings then ProfitCraftDB.settings = {} end

    for key, defaultValue in pairs(SETTINGS_DEFAULTS) do
        if ProfitCraftDB.settings[key] == nil then
            ProfitCraftDB.settings[key] = defaultValue
        end
    end

    return ProfitCraftDB.settings
end

function ProfitCraft_GetSetting(key, fallback)
    local settings = ProfitCraft_EnsureSettings()
    local value = settings[key]

    if value == nil and fallback ~= nil then
        settings[key] = fallback
        return fallback
    end

    return value
end

function ProfitCraft_SetSetting(key, value)
    local settings = ProfitCraft_EnsureSettings()
    settings[key] = value and true or false
end

local TRACKED_PROFESSIONS = {
    ["Alchemy"] = true,
    ["Blacksmithing"] = true,
    ["Cooking"] = true,
    ["Enchanting"] = true,
    ["Engineering"] = true,
    ["First Aid"] = true,
    ["Fishing"] = true,
    ["Herbalism"] = true,
    ["Leatherworking"] = true,
    ["Mining"] = true,
    ["Skinning"] = true,
    ["Tailoring"] = true,
}

local GetAuxMarketValue

local function NormalizeRecipeName(name)
    if not name then return nil end
    return string.lower(name)
end

local function TrimText(value)
    if not value then return nil end
    local trimmed = string.gsub(value, "^%s+", "")
    trimmed = string.gsub(trimmed, "%s+$", "")
    return trimmed
end

local function GetItemIDFromLink(itemLink)
    if not itemLink then return nil end
    local _, _, itemId = string.find(itemLink, "item:(%d+):")
    if not itemId then return nil end
    return tonumber(itemId)
end

local function GetCharacterKey()
    local playerName = UnitName("player") or "UnknownPlayer"
    local realmName = "UnknownRealm"
    if GetRealmName then
        local resolvedRealmName = GetRealmName()
        if resolvedRealmName and resolvedRealmName ~= "" then
            realmName = resolvedRealmName
        end
    end
    return realmName .. "-" .. playerName
end

local function EnsureCharacterData()
    if not ProfitCraftDB then ProfitCraftDB = {} end
    if not ProfitCraftDB.characters then ProfitCraftDB.characters = {} end

    local charKey = GetCharacterKey()
    if not ProfitCraftDB.characters[charKey] then
        ProfitCraftDB.characters[charKey] = {
            professions = {},
            knownRecipes = {},
            trainerRecipes = {},
            discoveredRecipes = {},
            learnedRecipes = {},
            shoppingList = {},
        }
    end

    local data = ProfitCraftDB.characters[charKey]
    if not data.professions then data.professions = {} end
    if not data.knownRecipes then data.knownRecipes = {} end
    if not data.trainerRecipes then data.trainerRecipes = {} end
    if not data.discoveredRecipes then data.discoveredRecipes = {} end
    if not data.learnedRecipes then data.learnedRecipes = {} end
    if not data.shoppingList then data.shoppingList = {} end

    return data
end

function ProfitCraft_GetStoredProfessions()
    local data = EnsureCharacterData()
    return data.professions
end

local function ClampShoppingQty(qty)
    qty = tonumber(qty) or 1
    if qty < 1 then return 1 end
    if qty > 99 then return 99 end
    return qty
end

local function CloneRecipeSnapshot(recipe)
    if not recipe or not recipe.name then
        return nil
    end

    local snapshot = {
        name = recipe.name,
        itemLink = recipe.itemLink,
        marketValue = recipe.marketValue or 0,
        cost = recipe.cost or 0,
        profit = recipe.profit or 0,
        level = recipe.level or 0,
        isLearned = recipe.isLearned and true or false,
        source = recipe.source,
        sourceDetails = recipe.sourceDetails,
        skillType = recipe.skillType,
        profession = recipe.profession,
        reagents = {},
    }

    if recipe.reagents then
        for _, reagent in ipairs(recipe.reagents) do
            table.insert(snapshot.reagents, {
                name = reagent.name or "Unknown",
                count = reagent.count or 0,
                playerCount = reagent.playerCount or 0,
                unitCost = reagent.unitCost or 0,
                link = reagent.link,
            })
        end
    end

    return snapshot
end

function ProfitCraft_SaveShoppingList(entries)
    local data = EnsureCharacterData()
    data.shoppingList = {}

    if not entries then
        return
    end

    for _, entry in ipairs(entries) do
        local recipe = entry.recipe
        local recipeName = nil
        local professionName = nil

        if recipe and recipe.name then
            recipeName = recipe.name
            professionName = recipe.profession
        elseif entry.recipeName then
            recipeName = entry.recipeName
            professionName = entry.profession
        end

        if recipeName then
            table.insert(data.shoppingList, {
                qty = ClampShoppingQty(entry.qty),
                recipeName = recipeName,
                profession = professionName,
                recipe = CloneRecipeSnapshot(recipe),
            })
        end
    end
end

function ProfitCraft_LoadShoppingList()
    local data = EnsureCharacterData()
    local restored = {}

    for _, entry in ipairs(data.shoppingList) do
        local recipeSnapshot = nil
        local recipeName = entry.recipeName
        local professionName = entry.profession

        if entry.recipe and entry.recipe.name then
            recipeSnapshot = CloneRecipeSnapshot(entry.recipe)
            recipeName = recipeSnapshot.name
            professionName = recipeSnapshot.profession or professionName
        end

        if recipeName then
            table.insert(restored, {
                qty = ClampShoppingQty(entry.qty),
                recipeName = recipeName,
                profession = professionName,
                recipe = recipeSnapshot,
            })
        end
    end

    return restored
end

local function IsTrackedProfession(skillName)
    if not skillName or skillName == "" then
        return false
    end
    if TRACKED_PROFESSIONS[skillName] then
        return true
    end
    if ProfitCraft_RecipeDB and ProfitCraft_RecipeDB[skillName] then
        return true
    end
    return false
end

local function StoreProfessionState(profession, rank, maxRank)
    if not IsTrackedProfession(profession) then return end

    local data = EnsureCharacterData()
    local saved = data.professions[profession]
    if not saved then
        saved = {}
        data.professions[profession] = saved
    end

    saved.rank = rank or 0
    saved.maxRank = maxRank or 0
    saved.lastSeen = (GetTime and GetTime()) or 0
end

function ProfitCraft_RefreshProfessionSnapshot()
    if not GetNumSkillLines or not GetSkillLineInfo then
        return
    end

    local numSkillLines = GetNumSkillLines()
    if not numSkillLines or numSkillLines == 0 then
        return
    end

    for i = 1, numSkillLines do
        local skillName, isHeader, isExpanded, skillRank, numTempPoints, skillModifier, skillMaxRank = GetSkillLineInfo(i)
        if skillName and not isHeader and IsTrackedProfession(skillName) then
            StoreProfessionState(skillName, skillRank, skillMaxRank)
        end
    end
end

local function StoreTrainerRecipe(profession, recipeName, requiredSkill, trainerDetails)
    if not IsTrackedProfession(profession) then return end

    local recipeKey = NormalizeRecipeName(recipeName)
    if not recipeKey then return end

    local data = EnsureCharacterData()
    if not data.trainerRecipes[profession] then
        data.trainerRecipes[profession] = {}
    end

    local byProfession = data.trainerRecipes[profession]
    local existing = byProfession[recipeKey]
    if not existing then
        existing = {}
        byProfession[recipeKey] = existing
    end

    existing.name = recipeName
    existing.source = "Trainer"
    existing.reqSkill = requiredSkill or existing.reqSkill or 1
    existing.details = trainerDetails or existing.details
    existing.lastSeen = (GetTime and GetTime()) or 0
end

local function StoreDiscoveredRecipe(profession, recipeName, requiredSkill, source, details, itemId)
    if not IsTrackedProfession(profession) then return end

    local recipeKey = NormalizeRecipeName(recipeName)
    if not recipeKey then return end

    local data = EnsureCharacterData()
    if not data.discoveredRecipes[profession] then
        data.discoveredRecipes[profession] = {}
    end

    local byProfession = data.discoveredRecipes[profession]
    local existing = byProfession[recipeKey]
    if not existing then
        existing = {}
        byProfession[recipeKey] = existing
    end

    existing.name = recipeName
    existing.reqSkill = requiredSkill or existing.reqSkill or 1
    existing.source = source or existing.source or "Drop"
    existing.details = details or existing.details
    existing.id = itemId or existing.id
    existing.lastSeen = (GetTime and GetTime()) or 0
end

local function IsProfessionRankTraining(serviceName, professionName)
    if not serviceName or not professionName then
        return false
    end

    local lowerName = string.lower(serviceName)
    local lowerProfession = string.lower(professionName)

    if lowerName == lowerProfession then
        return true
    end

    local mentionsProfession = string.find(lowerName, lowerProfession, 1, true) ~= nil
    if not mentionsProfession then
        return false
    end

    if string.find(lowerName, "apprentice", 1, true) then return true end
    if string.find(lowerName, "journeyman", 1, true) then return true end
    if string.find(lowerName, "expert", 1, true) then return true end
    if string.find(lowerName, "artisan", 1, true) then return true end
    if string.find(lowerName, "master", 1, true) then return true end

    return false
end

local scanTooltip = CreateFrame("GameTooltip", "ProfitCraftScanTooltip", nil, "GameTooltipTemplate")
if scanTooltip and scanTooltip.SetOwner and WorldFrame then
    scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
end

local function ParseRecipeItemTooltip(itemLink)
    if not scanTooltip or not scanTooltip.SetHyperlink then
        return nil
    end
    if not itemLink then
        return nil
    end

    -- Some APIs can surface non-item hyperlinks (e.g. enchant/spell links).
    -- Only parse recipe data from actual item links.
    local isItemLink = string.find(itemLink, "|Hitem:", 1, true) ~= nil
        or string.find(itemLink, "^item:") ~= nil
    if not isItemLink then
        return nil
    end

    scanTooltip:ClearLines()
    local ok = pcall(scanTooltip.SetHyperlink, scanTooltip, itemLink)
    if not ok then
        return nil
    end

    local professionName = nil
    local requiredSkill = nil
    local taughtRecipeName = nil

    for i = 2, 30 do
        local line = getglobal("ProfitCraftScanTooltipTextLeft" .. i)
        if line then
            local text = line:GetText()
            if text and text ~= "" then
                local reqProfession, reqValue = string.match(text, "^Requires%s+(.+)%s+%((%d+)%)$")
                reqProfession = TrimText(reqProfession)

                if reqProfession and IsTrackedProfession(reqProfession) then
                    professionName = reqProfession
                    requiredSkill = tonumber(reqValue) or requiredSkill
                end

                local taughtName = string.match(text, "^Use:%s+Teaches you how to make%s+(.+)%.$")
                taughtName = TrimText(taughtName)
                if taughtName and taughtName ~= "" then
                    taughtRecipeName = taughtName
                end
            end
        end
    end

    if not professionName or not taughtRecipeName then
        return nil
    end

    return {
        profession = professionName,
        reqSkill = requiredSkill or 1,
        name = taughtRecipeName,
    }
end

local function CacheRecipeFromItemLink(itemLink, source, details)
    local parsed = ParseRecipeItemTooltip(itemLink)
    if not parsed then
        return false
    end

    local itemId = GetItemIDFromLink(itemLink)
    StoreDiscoveredRecipe(
        parsed.profession,
        parsed.name,
        parsed.reqSkill,
        source,
        details,
        itemId
    )

    return true
end

function ProfitCraft_CacheTrainerRecipes()
    if not GetNumTrainerServices or not GetTrainerServiceInfo then
        return
    end

    local trainerName = UnitName("npc")
    local zoneName = GetZoneText and GetZoneText() or nil
    local trainerDetails = nil
    if trainerName and trainerName ~= "" then
        if zoneName and zoneName ~= "" then
            trainerDetails = "Trainer: " .. trainerName .. " (" .. zoneName .. ")"
        else
            trainerDetails = "Trainer: " .. trainerName
        end
    end

    local numServices = GetNumTrainerServices()
    if not numServices or numServices == 0 then
        return
    end

    for i = 1, numServices do
        local serviceName, serviceSubText, serviceType = GetTrainerServiceInfo(i)
        local isServiceRecipe = serviceName and (serviceType == "available" or serviceType == "unavailable")
        if isServiceRecipe and GetTrainerServiceSkillReq then
            local professionName, requiredSkillLevel = GetTrainerServiceSkillReq(i)
            if IsTrackedProfession(professionName) then
                if not IsProfessionRankTraining(serviceName, professionName) then
                    StoreTrainerRecipe(professionName, serviceName, requiredSkillLevel, trainerDetails)
                end
            end
        end
    end
end

function ProfitCraft_CacheBagRecipeItems()
    if not GetContainerNumSlots or not GetContainerItemLink then
        return
    end

    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            for slot = 1, numSlots do
                local itemLink = GetContainerItemLink(bag, slot)
                if itemLink then
                    CacheRecipeFromItemLink(itemLink, "Drop", "Discovered from recipe item in inventory.")
                end
            end
        end
    end
end

function ProfitCraft_CacheAuctionRecipeItems()
    if not GetNumAuctionItems or not GetAuctionItemLink then
        return
    end

    local numAuctionItems = GetNumAuctionItems("list")
    if not numAuctionItems or numAuctionItems == 0 then
        return
    end

    for i = 1, numAuctionItems do
        local itemLink = GetAuctionItemLink("list", i)
        if itemLink then
            CacheRecipeFromItemLink(itemLink, "Drop", "Seen on Auction House.")
        end
    end
end

local function GetCachedTrainerRecipesForProfession(professionName, professionRank)
    local data = EnsureCharacterData()
    local byProfession = data.trainerRecipes[professionName]
    if not byProfession then
        return nil
    end

    local available = {}
    for _, recipe in pairs(byProfession) do
        local reqSkill = recipe.reqSkill or 1
        if professionRank >= reqSkill then
            table.insert(available, recipe)
        end
    end

    return available
end

local function GetCachedDiscoveredRecipesForProfession(professionName, professionRank)
    local data = EnsureCharacterData()
    local byProfession = data.discoveredRecipes[professionName]
    if not byProfession then
        return nil
    end

    local available = {}
    for _, recipe in pairs(byProfession) do
        local reqSkill = recipe.reqSkill or 1
        if professionRank >= reqSkill then
            table.insert(available, recipe)
        end
    end

    return available
end

local function StoreKnownRecipesForProfession(profession, learnedRecipeLookup)
    if not profession or not learnedRecipeLookup then return end

    local data = EnsureCharacterData()
    if not data.knownRecipes[profession] then
        data.knownRecipes[profession] = {}
    end

    local known = data.knownRecipes[profession]
    for recipeKey in pairs(learnedRecipeLookup) do
        known[recipeKey] = true
    end
end

local function IsRecipeKnown(profession, recipeName, liveLearnedLookup)
    local recipeKey = NormalizeRecipeName(recipeName)
    if not recipeKey then
        return false
    end

    if liveLearnedLookup and liveLearnedLookup[recipeKey] then
        return true
    end

    local data = EnsureCharacterData()
    local byProfession = data.knownRecipes[profession]
    if byProfession and byProfession[recipeKey] then
        return true
    end

    return false
end

local function GetRequiredSkillFromCharacterCaches(professionName, recipeName)
    local recipeKey = NormalizeRecipeName(recipeName)
    if not recipeKey then
        return nil
    end

    local data = EnsureCharacterData()
    local trainerByProfession = data.trainerRecipes and data.trainerRecipes[professionName]
    if trainerByProfession and trainerByProfession[recipeKey] then
        local reqSkill = trainerByProfession[recipeKey].reqSkill
        if reqSkill and reqSkill > 0 then
            return reqSkill
        end
    end

    local discoveredByProfession = data.discoveredRecipes and data.discoveredRecipes[professionName]
    if discoveredByProfession and discoveredByProfession[recipeKey] then
        local reqSkill = discoveredByProfession[recipeKey].reqSkill
        if reqSkill and reqSkill > 0 then
            return reqSkill
        end
    end

    return nil
end

local function GetRequiredSkillFromRecipeDB(professionName, recipeName)
    if not ProfitCraft_RecipeDB or not professionName or not recipeName then
        return nil
    end

    local byProfession = ProfitCraft_RecipeDB[professionName]
    if not byProfession then
        return nil
    end

    local recipeKey = NormalizeRecipeName(recipeName)
    if not recipeKey then
        return nil
    end

    for reqSkill, recipes in pairs(byProfession) do
        for _, recipe in ipairs(recipes) do
            if recipe and recipe.name and NormalizeRecipeName(recipe.name) == recipeKey then
                local explicitReq = tonumber(recipe.reqSkill)
                if explicitReq and explicitReq > 0 then
                    return explicitReq
                end

                local thresholdReq = tonumber(reqSkill)
                if thresholdReq and thresholdReq > 0 then
                    return thresholdReq
                end
            end
        end
    end

    return nil
end

function ProfitCraft_GetRecipeRequiredSkill(professionName, recipeName)
    if not professionName or not recipeName then
        return nil
    end

    local cachedReq = GetRequiredSkillFromCharacterCaches(professionName, recipeName)
    if cachedReq and cachedReq > 0 then
        return cachedReq
    end

    local dbReq = GetRequiredSkillFromRecipeDB(professionName, recipeName)
    if dbReq and dbReq > 0 then
        return dbReq
    end

    return nil
end

local function StoreLearnedRecipeCacheForProfession(professionName, learnedRecipes)
    if not IsTrackedProfession(professionName) then return end

    local data = EnsureCharacterData()
    data.learnedRecipes[professionName] = {}

    if not learnedRecipes then
        return
    end

    local byProfession = data.learnedRecipes[professionName]
    local now = (GetTime and GetTime()) or 0

    for _, recipe in ipairs(learnedRecipes) do
        if recipe and recipe.name then
            local recipeKey = NormalizeRecipeName(recipe.name)
            if recipeKey then
                local snapshot = CloneRecipeSnapshot(recipe)
                if snapshot then
                    snapshot.lastSeen = now
                    byProfession[recipeKey] = snapshot
                end
            end
        end
    end
end

local function GetCachedLearnedRecipesForProfession(professionName)
    local data = EnsureCharacterData()
    local byProfession = data.learnedRecipes[professionName]
    if not byProfession then
        return nil
    end

    local available = {}
    for _, recipe in pairs(byProfession) do
        if recipe and recipe.name then
            local itemValue = recipe.marketValue or 0
            if recipe.itemLink then
                local liveValue = GetAuxMarketValue(recipe.itemLink)
                if liveValue and liveValue > 0 then
                    itemValue = liveValue
                end
            end

            local totalReagentCost = 0
            local reagents = {}
            if recipe.reagents then
                for _, reagent in ipairs(recipe.reagents) do
                    local count = reagent.count or 0
                    local unitCost = reagent.unitCost or 0
                    if reagent.link then
                        local liveUnitCost = GetAuxMarketValue(reagent.link)
                        if liveUnitCost and liveUnitCost > 0 then
                            unitCost = liveUnitCost
                        end
                    end

                    totalReagentCost = totalReagentCost + (unitCost * count)
                    table.insert(reagents, {
                        name = reagent.name or "Unknown",
                        count = count,
                        playerCount = 0,
                        unitCost = unitCost,
                        link = reagent.link,
                    })
                end
            end

            if totalReagentCost <= 0 and recipe.cost and recipe.cost > 0 then
                totalReagentCost = recipe.cost
            end

            table.insert(available, {
                name = recipe.name,
                itemLink = recipe.itemLink,
                marketValue = itemValue,
                cost = totalReagentCost,
                profit = itemValue - totalReagentCost,
                level = recipe.level or ProfitCraft_GetRecipeRequiredSkill(professionName, recipe.name) or 0,
                isLearned = true,
                source = "Learned",
                sourceDetails = nil,
                reagents = reagents,
                skillType = recipe.skillType,
                profession = professionName,
            })
        end
    end

    return available
end

local function GetStoredProfessionOrder()
    local ordered = {}
    local professions = ProfitCraft_GetStoredProfessions()

    for professionName, professionData in pairs(professions) do
        local rank = professionData and professionData.rank or 0
        if rank > 0 then
            table.insert(ordered, professionName)
        end
    end

    table.sort(ordered)
    return ordered
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
ProfitCraft_AuctionHouseOpen = ProfitCraft_AuctionHouseOpen or false

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

function ProfitCraft_HasAuxPricing()
    return hasAux and true or false
end

function ProfitCraft_EnsureAuxPricing()
    if hasAux then
        return true
    end
    return InitAuxAPI()
end

GetAuxMarketValue = function(itemLink)
    if not hasAux or not itemLink then return 0 end

    local _, _, itemId = string.find(itemLink, "item:(%d+):")
    if not itemId then return 0 end

    local item_key = itemId .. ":0"

    -- Method 1: aux.core.history module (OldManAlpha fork — Turtle WoW standard)
    if aux_history then
        -- .market_value() = today's daily min buyout
        local ok2, val2 = pcall(aux_history.market_value, item_key)
        if ok2 and val2 and val2 > 0 then
            return val2
        end
        -- .value() = weighted historical median fallback
        local ok, val = pcall(aux_history.value, item_key)
        if ok and val and val > 0 then
            return val
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
        local ok2, val2 = pcall(aux_history.market_value, item_key)
        if ok2 and val2 and val2 > 0 then return val2 end
        local ok, val = pcall(aux_history.value, item_key)
        if ok and val and val > 0 then return val end
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
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("BAG_UPDATE")
frame:RegisterEvent("SKILL_LINES_CHANGED")
frame:RegisterEvent("TRADE_SKILL_SHOW")
frame:RegisterEvent("TRADE_SKILL_UPDATE")
frame:RegisterEvent("TRAINER_SHOW")
frame:RegisterEvent("TRAINER_UPDATE")
frame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("AUCTION_HOUSE_SHOW")
frame:RegisterEvent("AUCTION_HOUSE_CLOSED")

local lastCalcTime = 0
local CALC_THROTTLE = 1
local lastBagRecipeCacheTime = 0
local BAG_CACHE_THROTTLE = 1
local AUX_PRICE_REFRESH_DELAY = 0.20
local auxPriceRefreshFrame = CreateFrame("Frame", addonName.."AuxPriceRefreshFrame")
local auxPriceRefreshAt = nil

local function FlushQueuedAuxPriceRefresh()
    if not auxPriceRefreshAt then
        auxPriceRefreshFrame:SetScript("OnUpdate", nil)
        return
    end

    local now = (GetTime and GetTime()) or auxPriceRefreshAt
    if now < auxPriceRefreshAt then
        return
    end

    auxPriceRefreshAt = nil
    auxPriceRefreshFrame:SetScript("OnUpdate", nil)

    if ProfitCraftDashboard and ProfitCraftDashboard:IsVisible() then
        ProfitCraft_CalculateProfits(true)
    end
end

local function QueueAuxPriceRefresh(delaySeconds)
    local delay = tonumber(delaySeconds) or AUX_PRICE_REFRESH_DELAY
    if delay < 0 then
        delay = 0
    end

    local now = (GetTime and GetTime()) or 0
    auxPriceRefreshAt = now + delay
    auxPriceRefreshFrame:SetScript("OnUpdate", FlushQueuedAuxPriceRefresh)
end

frame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == addonName then
        Print("v1.7.0 loaded. Open a profession window or type /pc")
        ProfitCraft_AuctionHouseOpen = false

        -- Initialize Aux API
        InitAuxAPI()
        if hasAux then
            Print("Aux pricing active. Use the minimap icon or /pc.")
        else
            Print("|cFFFF8800Warning:|r aux-addon not found. Prices may be inaccurate.")
        end

        -- Initialize SavedVariables
        if not ProfitCraftDB then
            ProfitCraftDB = {}
        end
        ProfitCraft_EnsureSettings()
        EnsureCharacterData()
        ProfitCraft_ShoppingList = ProfitCraft_LoadShoppingList()
        ProfitCraft_RefreshProfessionSnapshot()
        ProfitCraft_CacheBagRecipeItems()

        -- Initialize Minimap Button
        if ProfitCraft_InitMinimapButton then
            ProfitCraft_InitMinimapButton()
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        if ProfitCraft_InitMinimapButton then
            ProfitCraft_InitMinimapButton()
        end

    elseif event == "BAG_UPDATE" then
        local now = GetTime()
        if (now - lastBagRecipeCacheTime) > BAG_CACHE_THROTTLE then
            lastBagRecipeCacheTime = now
            ProfitCraft_CacheBagRecipeItems()
            if ProfitCraftDashboard and ProfitCraftDashboard:IsVisible() then
                ProfitCraft_CalculateProfits(true)
            end
        end

        if ProfitCraftDashboard and ProfitCraftDashboard:IsVisible() and ProfitCraft_UpdateTracker then
            ProfitCraft_UpdateTracker()
        end

    elseif event == "TRADE_SKILL_SHOW" then
        -- Re-check Aux on first use (it may load after us)
        if not hasAux then InitAuxAPI() end
        if ProfitCraft_RequestProfessionFilterDefault and GetTradeSkillLine then
            local activeProfession = GetTradeSkillLine()
            if activeProfession == "UNKNOWN" then
                activeProfession = nil
            end
            ProfitCraft_RequestProfessionFilterDefault(activeProfession)
        end
        ProfitCraft_CalculateProfits(false, true)

    elseif event == "SKILL_LINES_CHANGED" then
        ProfitCraft_RefreshProfessionSnapshot()
        if ProfitCraftDashboard and ProfitCraftDashboard:IsVisible() then
            ProfitCraft_CalculateProfits(true)
        end

    elseif event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
        ProfitCraft_CacheTrainerRecipes()
        if ProfitCraftDashboard and ProfitCraftDashboard:IsVisible() then
            ProfitCraft_CalculateProfits(true)
        end

    elseif event == "AUCTION_ITEM_LIST_UPDATE" then
        ProfitCraft_CacheAuctionRecipeItems()
        if ProfitCraftDashboard and ProfitCraftDashboard:IsVisible() then
            -- Aux persists price updates after the list event; defer refresh slightly.
            QueueAuxPriceRefresh()
        end

    elseif event == "TRADE_SKILL_UPDATE" then
        local now = GetTime()
        if (now - lastCalcTime) > CALC_THROTTLE then
            lastCalcTime = now
            ProfitCraft_CalculateProfits(true)
        end
    elseif event == "MERCHANT_SHOW" then
        if ProfitCraft_HandleContextAutoOpen then
            ProfitCraft_HandleContextAutoOpen("merchant")
        end
    elseif event == "AUCTION_HOUSE_SHOW" then
        ProfitCraft_AuctionHouseOpen = true
        if ProfitCraft_HandleContextAutoOpen then
            ProfitCraft_HandleContextAutoOpen("auction")
        end
        if ProfitCraftDashboard and ProfitCraftDashboard:IsVisible() and ProfitCraft_UpdateTracker then
            ProfitCraft_UpdateTracker()
        end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        ProfitCraft_AuctionHouseOpen = false
        auxPriceRefreshAt = nil
        auxPriceRefreshFrame:SetScript("OnUpdate", nil)
        if ProfitCraftDashboard and ProfitCraftDashboard:IsVisible() and ProfitCraft_UpdateTracker then
            ProfitCraft_UpdateTracker()
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
        Print("  /pc scan — Re-scan known recipe sources (bags, trainer, AH list)")
        Print("  /pc settings — Toggle the settings panel")
        Print("  /pc help — Show this help")
    elseif msg == "settings" then
        if ProfitCraft_ToggleSettings then
            if not ProfitCraftDashboard or not ProfitCraftDashboard:IsVisible() then
                ProfitCraft_ToggleDashboard()
            end
            ProfitCraft_ToggleSettings()
        end
    elseif msg == "scan" then
        ProfitCraft_RefreshProfessionSnapshot()
        ProfitCraft_CacheBagRecipeItems()
        ProfitCraft_CacheTrainerRecipes()
        ProfitCraft_CacheAuctionRecipeItems()
        ProfitCraft_CalculateProfits()
        Print("Rescanned profession and recipe sources.")
    elseif msg == "clear" then
        if ProfitCraft_ClearShoppingList then
            ProfitCraft_ClearShoppingList()
        else
            ProfitCraft_ShoppingList = {}
            ProfitCraft_SaveShoppingList(ProfitCraft_ShoppingList)
            ProfitCraft_UpdateTracker()
            if ProfitCraft_ApplySortAndFilter then ProfitCraft_ApplySortAndFilter() end
            if ProfitCraft_DashboardUpdate then ProfitCraft_DashboardUpdate() end
        end
        Print("Shopping list cleared.")
    else
        ProfitCraft_ToggleDashboard()
    end
end

-- ============================================================================
-- Core Profit Calculation
-- ============================================================================

local function BuildRecipeDedupeKey(professionName, recipeName, fallbackID)
    local normalized = NormalizeRecipeName(recipeName)
    if normalized then
        return professionName .. ":" .. normalized
    end
    return professionName .. ":" .. tostring(fallbackID or "unknown")
end

local function AppendCachedLearnedRecipesForProfession(professionName, dedupeLookup)
    local cachedLearned = GetCachedLearnedRecipesForProfession(professionName)
    if not cachedLearned then
        return 0
    end

    local added = 0
    for _, recipe in ipairs(cachedLearned) do
        local dedupeKey = BuildRecipeDedupeKey(professionName, recipe.name, recipe.id)
        if dedupeKey and not dedupeLookup[dedupeKey] then
            table.insert(ProfitCraft_List, recipe)
            dedupeLookup[dedupeKey] = true
            added = added + 1
        end
    end

    return added
end

local function AppendUnlearnedRecipesForProfession(professionName, professionRank, activeProfession, activeLearnedLookup, dedupeLookup)
    if not professionName or not professionRank or professionRank <= 0 then
        return 0
    end

    local added = 0

    local function TryAddRecipe(recipe)
        if not recipe or not recipe.name then
            return
        end

        local recipeKey = NormalizeRecipeName(recipe.name)
        local dedupeKey = BuildRecipeDedupeKey(professionName, recipe.name, recipe.id)
        if recipeKey and not dedupeLookup[dedupeKey] then
            local liveLookup = nil
            if activeProfession and activeProfession == professionName then
                liveLookup = activeLearnedLookup
            end

            if not IsRecipeKnown(professionName, recipe.name, liveLookup) then
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
                    level = recipe.reqSkill or ProfitCraft_GetRecipeRequiredSkill(professionName, recipe.name) or 0,
                    isLearned = false,
                    source = recipe.source or "Unknown",
                    sourceDetails = recipe.details or nil,
                    reagents = {},
                    skillType = nil,
                    profession = professionName,
                })

                dedupeLookup[dedupeKey] = true
                added = added + 1
            end
        end
    end

    local unlearned = ProfitCraft_GetUnlearnedRecipes(professionName, professionRank)
    if unlearned then
        for _, recipe in ipairs(unlearned) do
            TryAddRecipe(recipe)
        end
    end

    local trainerRecipes = GetCachedTrainerRecipesForProfession(professionName, professionRank)
    if trainerRecipes then
        for _, recipe in ipairs(trainerRecipes) do
            TryAddRecipe(recipe)
        end
    end

    local discoveredRecipes = GetCachedDiscoveredRecipesForProfession(professionName, professionRank)
    if discoveredRecipes then
        for _, recipe in ipairs(discoveredRecipes) do
            TryAddRecipe(recipe)
        end
    end

    return added
end

function ProfitCraft_CalculateProfits(silent, shouldShowDashboard)
    local numSkills = GetNumTradeSkills() or 0
    local skillName, skillRank, skillMaxRank = GetTradeSkillLine()
    local hasOpenTradeSkill = numSkills > 0 and skillName and skillName ~= "UNKNOWN"

    ProfitCraft_List = {}
    local learnedRecipeLookup = {}
    local learnedDedupeLookup = {}
    local scannedLearnedRecipes = {}

    if hasOpenTradeSkill then
        StoreProfessionState(skillName, skillRank, skillMaxRank)
        if not silent then
            Print("Scanning " .. skillName .. " (" .. skillRank .. "/" .. skillMaxRank .. ")...")
        end

        -- Pass 1: Learned recipes from currently open profession window
        for i = 1, numSkills do
            local name, skillType, numAvailable, isExpanded = GetTradeSkillInfo(i)
            if name and skillType ~= "header" then
                local normalizedName = NormalizeRecipeName(name)
                if normalizedName then
                    learnedRecipeLookup[normalizedName] = true
                end

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

                local learnedEntry = {
                    name = name,
                    itemLink = itemLink,
                    marketValue = itemValue,
                    cost = totalReagentCost,
                    profit = profit,
                    level = ProfitCraft_GetRecipeRequiredSkill(skillName, name) or 0,
                    isLearned = true,
                    source = "Learned",
                    sourceDetails = nil,
                    reagents = reagents,
                    skillType = skillType,
                    profession = skillName,
                }

                table.insert(ProfitCraft_List, learnedEntry)
                table.insert(scannedLearnedRecipes, learnedEntry)

                local learnedDedupeKey = BuildRecipeDedupeKey(skillName, name)
                if learnedDedupeKey then
                    learnedDedupeLookup[learnedDedupeKey] = true
                end
            end
        end

        StoreKnownRecipesForProfession(skillName, learnedRecipeLookup)
        StoreLearnedRecipeCacheForProfession(skillName, scannedLearnedRecipes)
    end

    -- Pass 2: Cached learned recipes from all stored professions.
    local storedProfessions = ProfitCraft_GetStoredProfessions()
    local professionOrder = GetStoredProfessionOrder()
    for _, professionName in ipairs(professionOrder) do
        if not (hasOpenTradeSkill and professionName == skillName) then
            AppendCachedLearnedRecipesForProfession(professionName, learnedDedupeLookup)
        end
    end

    -- Pass 3: Unlearned recipes from all stored professions.
    local unlearnedCount = 0
    local dedupeLookup = {}
    for dedupeKey in pairs(learnedDedupeLookup) do
        dedupeLookup[dedupeKey] = true
    end
    for _, professionName in ipairs(professionOrder) do
        local storedProfession = storedProfessions[professionName]
        local storedRank = storedProfession and storedProfession.rank or 0
        unlearnedCount = unlearnedCount + AppendUnlearnedRecipesForProfession(
            professionName,
            storedRank,
            skillName,
            learnedRecipeLookup,
            dedupeLookup
        )
    end

    -- Apply filters and sort, then refresh UI
    ProfitCraft_ApplySortAndFilter()
    if ProfitCraft_SyncShoppingListRecipes then
        ProfitCraft_SyncShoppingListRecipes()
    end

    if ProfitCraftDashboard then
        if shouldShowDashboard and not ProfitCraftDashboard:IsVisible() then
            ProfitCraftDashboard:Show()
        end

        if ProfitCraftDashboard:IsVisible() then
            ProfitCraft_DashboardUpdate()
            ProfitCraft_UpdateTracker()
        end
    end

    local learnedCount = 0
    for _, entry in ipairs(ProfitCraft_List) do
        if entry.isLearned then
            learnedCount = learnedCount + 1
        end
    end

    if not silent then
        Print("Found " .. learnedCount .. " learned + " .. unlearnedCount .. " unlearned recipes.")
    end
end

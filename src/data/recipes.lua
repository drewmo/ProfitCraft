-- Unlearned Recipe Database for ProfitCraft
-- This database maps professions to their potential unlearned recipes, including skill requirements and sources.

if not ProfitCraftDB then ProfitCraftDB = {} end

local TRAINER_LOCATION_HINTS = {
    ["Alchemy"] = "Alliance: Alchemy trainers in Stormwind and Ironforge. Horde: Orgrimmar and Undercity.",
    ["Blacksmithing"] = "Alliance: Blacksmith trainers in Stormwind and Ironforge. Horde: Orgrimmar and Thunder Bluff.",
    ["Engineering"] = "Alliance: Engineering trainers in Stormwind and Ironforge. Horde: Orgrimmar and Undercity.",
    ["Enchanting"] = "Alliance: Enchanting trainers in Stormwind and Ironforge. Horde: Orgrimmar and Undercity.",
    ["Herbalism"] = "Alliance: Herbalism trainers in Stormwind and Ironforge. Horde: Orgrimmar and Thunder Bluff.",
    ["Leatherworking"] = "Alliance: Leatherworking trainers in Stormwind and Darnassus. Horde: Orgrimmar and Thunder Bluff.",
    ["Mining"] = "Alliance: Mining trainers in Stormwind and Ironforge. Horde: Orgrimmar and Thunder Bluff.",
    ["Skinning"] = "Alliance: Skinning trainers in Stormwind and Ironforge. Horde: Orgrimmar and Thunder Bluff.",
    ["Tailoring"] = "Alliance: Tailoring trainers in Stormwind and Ironforge. Horde: Orgrimmar and Undercity.",
}

local function NormalizeRecipeSource(source)
    if not source then return "Unknown" end

    local normalized = string.lower(source)
    if string.find(normalized, "trainer") then return "Trainer" end
    if string.find(normalized, "vendor") then return "Vendor" end
    if string.find(normalized, "quest") then return "Quest" end
    if string.find(normalized, "drop") then return "Drop" end
    if string.find(normalized, "reputation") then return "Reputation" end

    return source
end

local function ResolveSourceDetails(profession, source, details)
    local hasDetails = details and details ~= ""
    local genericTrainerDetails = hasDetails and string.find(details, "^Any%s") ~= nil

    if source == "Trainer" then
        local hint = TRAINER_LOCATION_HINTS[profession]
        if hint then
            if hasDetails and not genericTrainerDetails then
                return details .. " " .. hint
            end
            return hint
        end
    end

    if hasDetails then
        return details
    end

    return nil
end

-- Structure:
-- ProfitCraft_RecipeDB[ProfessionName][SkillLevel] = {
--     { id = ItemID, name = "Recipe Name", source = "Vendor/Drop/Quest", details = "Specific NPC or Zone" }
-- }

ProfitCraft_RecipeDB = {
    ["Alchemy"] = {
        [1] = {
            { id = 2454, name = "Elixir of Lion's Strength", source = "Trainer", details = "Any Alchemy Trainer" },
            { id = 5996, name = "Elixir of Water Breathing", source = "Trainer", details = "Any Alchemy Trainer" }
        },
        [15] = {
            { id = 2455, name = "Minor Rejuvenation Potion", source = "Trainer", details = "Any Alchemy Trainer" }
        },
        [90] = {
            { id = 2555, name = "Recipe: Swiftness Potion", source = "Drop", details = "World Drop (Levels 10-25)" }
        }
        -- More Alchemy recipes...
    },
    ["Blacksmithing"] = {
        [1] = {
            { id = 2881, name = "Rough Copper Vest", source = "Trainer", details = "Any Blacksmithing Trainer" }
        },
        [50] = {
            { id = 3470, name = "Plans: Copper Chain Vest", source = "Vendor", details = "Various Blacksmithing Suppliers" }
        }
        -- More Blacksmithing recipes...
    },
    ["Leatherworking"] = {
        [90] = {
            { id = 4293, name = "Pattern: Fine Leather Tunic", source = "Vendor", details = "Various Leatherworking Suppliers" }
        },
        [150] = {
            { id = 7371, name = "Pattern: Heavy Earthen Gloves", source = "Vendor", details = "Jannos Ironwill (Arathi Highlands) / Gharl (Dustwallow Marsh)" }
        }
        -- More Leatherworking recipes...
    },
    ["Tailoring"] = {
        [40] = {
            { id = 2580, name = "Pattern: Linen Boots", source = "Trainer", details = "Any Tailoring Trainer" }
        },
        [145] = {
            { id = 7084, name = "Pattern: Azure Silk Vest", source = "Quest", details = "The Azure Silk Vest (Horde) / The Azure Silk Vest (Alliance)" }
        }
        -- More Tailoring recipes...
    }
}

-- Helper function to get unlearned recipes for a given profession and skill level
function ProfitCraft_GetUnlearnedRecipes(profession, currentSkill)
    local unlearned = {}
    if ProfitCraft_RecipeDB[profession] then
        local thresholds = {}
        for reqSkill in pairs(ProfitCraft_RecipeDB[profession]) do
            table.insert(thresholds, reqSkill)
        end
        table.sort(thresholds)

        for _, reqSkill in ipairs(thresholds) do
            local recipes = ProfitCraft_RecipeDB[profession][reqSkill]
            if currentSkill >= reqSkill then
                for _, recipe in ipairs(recipes) do
                    local normalized = {}
                    for key, value in pairs(recipe) do
                        normalized[key] = value
                    end

                    normalized.source = NormalizeRecipeSource(recipe.source)
                    normalized.details = ResolveSourceDetails(profession, normalized.source, recipe.details)

                    -- We should ideally check if the player already knows the recipe here,
                    -- but that requires comparing against the currently open TradeSkill list.
                    -- For now, we return all recipes the player *can* learn based on skill.
                    table.insert(unlearned, normalized)
                end
            end
        end
    end
    return unlearned
end

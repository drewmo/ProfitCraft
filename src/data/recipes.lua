-- Unlearned Recipe Database for ProfitCraft
-- This database maps professions to their potential unlearned recipes, including skill requirements and sources.

if not ProfitCraftDB then ProfitCraftDB = {} end

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
        for reqSkill, recipes in pairs(ProfitCraft_RecipeDB[profession]) do
            if currentSkill >= reqSkill then
                for _, recipe in ipairs(recipes) do
                    -- We should ideally check if the player already knows the recipe here,
                    -- but that requires comparing against the currently open TradeSkill list.
                    -- For now, we return all recipes the player *can* learn based on skill.
                    table.insert(unlearned, recipe)
                end
            end
        end
    end
    return unlearned
end

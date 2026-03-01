-- ProfitCraft: dashboard.lua
-- Handles population, sorting, filtering, and display of the Dashboard UI.
-- Also manages the Shopping List tracker.

-- ============================================================================
-- State
-- ============================================================================

-- Master list of ALL recipes (learned + unlearned), populated by main.lua
ProfitCraft_List = {}

-- Filtered view of ProfitCraft_List based on current filter settings
ProfitCraft_FilteredList = {}

-- Current sort state
ProfitCraft_SortField = "profit"
ProfitCraft_SortAscending = false

-- Filter state (defaults: show learned + unlearned, hide quest-only)
ProfitCraft_Filters = {
    showLearned = true,
    showUnlearned = true,
    showQuest = true,
}

-- Shopping list tracker state
ProfitCraft_TrackedRecipe = nil   -- reference to a recipe entry in ProfitCraft_List
ProfitCraft_TrackedQty = 1

-- Number of visible rows in the scroll area
local NUM_DISPLAY_ROWS = 13

-- ============================================================================
-- Currency Formatting
-- ============================================================================

function ProfitCraft_FormatCurrency(copper)
    if not copper or copper == 0 then return "|cFF888888-|r" end

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
        return "|cFFFF4444-" .. str .. "|r"
    else
        return "|cFF00FF00" .. str .. "|r"
    end
end

-- Shorter version for column display (no color on neutral values)
function ProfitCraft_FormatCurrencyNeutral(copper)
    if not copper or copper == 0 then return "|cFF888888-|r" end

    local g = math.floor(copper / 10000)
    local s = math.floor(math.mod(copper / 100, 100))
    local c = math.mod(copper, 100)

    local str = ""
    if g > 0 then str = str .. g .. "g " end
    if s > 0 or g > 0 then str = str .. s .. "s " end
    str = str .. c .. "c"

    return "|cFFDDDDDD" .. str .. "|r"
end

-- ============================================================================
-- Dashboard OnLoad — create row buttons
-- ============================================================================

function ProfitCraft_Dashboard_OnLoad(frame)
    if not frame then frame = ProfitCraftDashboard end

    -- Create scrollable entry rows
    for i = 1, NUM_DISPLAY_ROWS do
        local btn = CreateFrame("Button", "ProfitCraftDashboardEntry"..i, frame, "ProfitCraftEntryTemplate")
        if i == 1 then
            btn:SetPoint("TOPLEFT", ProfitCraftDashboardScrollFrame, "TOPLEFT", 0, 0)
        else
            btn:SetPoint("TOPLEFT", "ProfitCraftDashboardEntry"..(i-1), "BOTTOMLEFT", 0, 0)
        end
        btn:Hide()
    end

    -- Initialize filter checkboxes to default state
    if ProfitCraftFilterLearned then
        ProfitCraftFilterLearned:SetChecked(true)
    end
    if ProfitCraftFilterUnlearned then
        ProfitCraftFilterUnlearned:SetChecked(true)
    end
    if ProfitCraftFilterQuest then
        ProfitCraftFilterQuest:SetChecked(true)
    end

    -- Create tracker reagent font strings (up to 6 reagent lines)
    for i = 1, 6 do
        local fs = frame:CreateFontString("ProfitCraftTrackerReagent"..i, "ARTWORK", "GameFontHighlightSmall")
        fs:SetJustifyH("LEFT")
        if i == 1 then
            fs:SetPoint("TOPLEFT", ProfitCraftTrackerItemName, "BOTTOMLEFT", 0, -2)
        else
            fs:SetPoint("TOPLEFT", "ProfitCraftTrackerReagent"..(i-1), "BOTTOMLEFT", 0, -1)
        end
        fs:SetText("")
        fs:Hide()
    end

    -- Create quantity display text between - and + buttons
    local qtyText = frame:CreateFontString("ProfitCraftTrackerQtyText", "ARTWORK", "GameFontNormal")
    qtyText:SetPoint("LEFT", ProfitCraftTrackerMinus, "RIGHT", 2, 0)
    qtyText:SetText("1")
end

-- ============================================================================
-- Sorting
-- ============================================================================

function ProfitCraft_SortBy(field)
    if ProfitCraft_SortField == field then
        -- Toggle direction if clicking the same column
        ProfitCraft_SortAscending = not ProfitCraft_SortAscending
    else
        ProfitCraft_SortField = field
        -- Default: descending for numeric fields, ascending for name
        if field == "name" then
            ProfitCraft_SortAscending = true
        else
            ProfitCraft_SortAscending = false
        end
    end

    ProfitCraft_ApplySortAndFilter()
    ProfitCraft_DashboardUpdate()
end

local function SortCompare(a, b)
    local field = ProfitCraft_SortField
    local valA = a[field]
    local valB = b[field]

    if valA == nil then valA = 0 end
    if valB == nil then valB = 0 end

    -- For string fields, do alphabetical compare
    if field == "name" then
        if ProfitCraft_SortAscending then
            return (valA or "") < (valB or "")
        else
            return (valA or "") > (valB or "")
        end
    end

    -- Numeric fields
    if ProfitCraft_SortAscending then
        return valA < valB
    else
        return valA > valB
    end
end

-- ============================================================================
-- Filtering
-- ============================================================================

function ProfitCraft_OnFilterChanged()
    -- Read checkbox states
    ProfitCraft_Filters.showLearned = ProfitCraftFilterLearned:GetChecked() and true or false
    ProfitCraft_Filters.showUnlearned = ProfitCraftFilterUnlearned:GetChecked() and true or false
    ProfitCraft_Filters.showQuest = ProfitCraftFilterQuest:GetChecked() and true or false

    ProfitCraft_ApplySortAndFilter()
    ProfitCraft_DashboardUpdate()
end

function ProfitCraft_ApplySortAndFilter()
    ProfitCraft_FilteredList = {}

    for _, entry in ipairs(ProfitCraft_List) do
        local dominated = true

        -- Filter: Learned / Unlearned
        if entry.isLearned and not ProfitCraft_Filters.showLearned then
            dominated = false
        end
        if not entry.isLearned and not ProfitCraft_Filters.showUnlearned then
            dominated = false
        end

        -- Filter: Quest source (only applies to unlearned recipes)
        if not entry.isLearned and entry.source == "Quest" and not ProfitCraft_Filters.showQuest then
            dominated = false
        end

        if dominated then
            table.insert(ProfitCraft_FilteredList, entry)
        end
    end

    -- Sort the filtered list
    table.sort(ProfitCraft_FilteredList, SortCompare)
end

-- ============================================================================
-- Dashboard Update (Scroll Frame refresh)
-- ============================================================================

function ProfitCraft_DashboardUpdate()
    local scrollFrame = getglobal("ProfitCraftDashboardScrollFrame")
    if not scrollFrame then return end

    local numItems = table.getn(ProfitCraft_FilteredList)

    FauxScrollFrame_Update(scrollFrame, numItems, NUM_DISPLAY_ROWS, 22)

    local offset = FauxScrollFrame_GetOffset(scrollFrame)
    for i = 1, NUM_DISPLAY_ROWS do
        local index = offset + i
        local button = getglobal("ProfitCraftDashboardEntry"..i)

        if button then
            if index <= numItems then
                local data = ProfitCraft_FilteredList[index]

                -- Status indicator
                local statusText = getglobal("ProfitCraftDashboardEntry"..i.."Status")
                if data.isLearned then
                    statusText:SetText("|cFF00FF00*|r")
                else
                    if data.source == "Quest" then
                        statusText:SetText("|cFFFFFF00!|r")
                    else
                        statusText:SetText("|cFFFF8800?|r")
                    end
                end

                -- Recipe name
                local nameText = getglobal("ProfitCraftDashboardEntry"..i.."Name")
                if data.isLearned then
                    nameText:SetText(data.name)
                else
                    nameText:SetText("|cFFAAAAAA" .. data.name .. "|r")
                end

                -- Cost, Value, Profit columns
                getglobal("ProfitCraftDashboardEntry"..i.."Cost"):SetText(ProfitCraft_FormatCurrencyNeutral(data.cost))
                getglobal("ProfitCraftDashboardEntry"..i.."Value"):SetText(ProfitCraft_FormatCurrencyNeutral(data.marketValue))
                getglobal("ProfitCraftDashboardEntry"..i.."Profit"):SetText(ProfitCraft_FormatCurrency(data.profit))

                -- Store the data index on the button for click handling
                button.dataIndex = index

                -- Highlight the tracked recipe
                if ProfitCraft_TrackedRecipe and data.name == ProfitCraft_TrackedRecipe.name then
                    button:LockHighlight()
                else
                    button:UnlockHighlight()
                end

                button:Show()
            else
                button:Hide()
            end
        end
    end
end

-- ============================================================================
-- Entry Click / Hover Handlers
-- ============================================================================

function ProfitCraft_OnEntryClick(btn)
    if not btn or not btn.dataIndex then return end
    local data = ProfitCraft_FilteredList[btn.dataIndex]
    if not data then return end

    -- Set as tracked recipe for shopping list
    ProfitCraft_TrackedRecipe = data
    ProfitCraft_TrackedQty = 1

    ProfitCraft_UpdateTracker()
    ProfitCraft_DashboardUpdate()
end

function ProfitCraft_OnEntryEnter(btn)
    if not btn or not btn.dataIndex then return end
    local data = ProfitCraft_FilteredList[btn.dataIndex]
    if not data then return end

    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")

    -- Show item tooltip if we have a link
    if data.itemLink then
        GameTooltip:SetHyperlink(data.itemLink)
    else
        GameTooltip:AddLine(data.name, 1, 1, 1)
    end

    -- Add profit info
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Market Value:", ProfitCraft_FormatCurrencyNeutral(data.marketValue), 0.7, 0.7, 0.7)
    GameTooltip:AddDoubleLine("Craft Cost:", ProfitCraft_FormatCurrencyNeutral(data.cost), 0.7, 0.7, 0.7)
    GameTooltip:AddDoubleLine("Profit:", ProfitCraft_FormatCurrency(data.profit), 0.7, 0.7, 0.7)

    -- Show source for unlearned recipes
    if not data.isLearned then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Source: " .. (data.source or "Unknown"), 1, 0.8, 0)
        if data.sourceDetails then
            GameTooltip:AddLine(data.sourceDetails, 0.7, 0.7, 0.7, true)
        end
    end

    -- Show reagent list
    if data.reagents and table.getn(data.reagents) > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Reagents:", 1, 0.82, 0)
        for _, r in ipairs(data.reagents) do
            local have = r.playerCount or 0
            local need = r.count or 0
            local color = "|cFFFF4444"
            if have >= need then color = "|cFF00FF00" end
            GameTooltip:AddLine("  " .. color .. have .. "/" .. need .. "|r " .. (r.name or "?"), 0.8, 0.8, 0.8)
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cFF888888Click to add to Shopping List|r")
    GameTooltip:Show()
end

-- ============================================================================
-- Shopping List Tracker
-- ============================================================================

function ProfitCraft_TrackerAdjustQty(delta)
    ProfitCraft_TrackedQty = ProfitCraft_TrackedQty + delta
    if ProfitCraft_TrackedQty < 1 then ProfitCraft_TrackedQty = 1 end
    if ProfitCraft_TrackedQty > 99 then ProfitCraft_TrackedQty = 99 end

    ProfitCraft_UpdateTracker()
end

function ProfitCraft_UpdateTracker()
    local qtyText = getglobal("ProfitCraftTrackerQtyText")
    if qtyText then
        qtyText:SetText(tostring(ProfitCraft_TrackedQty))
    end

    local itemNameText = getglobal("ProfitCraftTrackerItemName")
    if not itemNameText then return end

    if not ProfitCraft_TrackedRecipe then
        itemNameText:SetText("|cFF888888Click a recipe above to track|r")
        -- Hide all reagent lines
        for i = 1, 6 do
            local fs = getglobal("ProfitCraftTrackerReagent"..i)
            if fs then fs:Hide() end
        end
        return
    end

    local recipe = ProfitCraft_TrackedRecipe
    local qty = ProfitCraft_TrackedQty

    -- Show tracked item name
    local displayName = recipe.name
    if qty > 1 then
        displayName = displayName .. " x" .. qty
    end
    itemNameText:SetText("|cFFFFD100" .. displayName .. "|r")

    -- Show reagent progress
    if recipe.reagents then
        for i = 1, 6 do
            local fs = getglobal("ProfitCraftTrackerReagent"..i)
            if fs then
                if recipe.reagents[i] then
                    local r = recipe.reagents[i]
                    local have = r.playerCount or 0
                    local need = (r.count or 0) * qty
                    local color = "|cFFFF4444"
                    if have >= need then
                        color = "|cFF00FF00"
                    elseif have > 0 then
                        color = "|cFFFFFF00"
                    end
                    fs:SetText(color .. have .. "/" .. need .. "|r  " .. (r.name or "Unknown"))
                    fs:Show()
                else
                    fs:SetText("")
                    fs:Hide()
                end
            end
        end
    else
        for i = 1, 6 do
            local fs = getglobal("ProfitCraftTrackerReagent"..i)
            if fs then
                fs:SetText("")
                fs:Hide()
            end
        end
    end
end

-- ============================================================================
-- Toggle Dashboard visibility
-- ============================================================================

function ProfitCraft_ToggleDashboard()
    if not ProfitCraftDashboard then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[ProfitCraft] Error:|r Dashboard UI frame is missing.")
        return
    end

    if ProfitCraftDashboard:IsVisible() then
        ProfitCraftDashboard:Hide()
    else
        ProfitCraftDashboard:Show()
        ProfitCraft_ApplySortAndFilter()
        ProfitCraft_DashboardUpdate()
        ProfitCraft_UpdateTracker()
    end
end

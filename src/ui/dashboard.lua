-- ProfitCraft: dashboard.lua
-- Dashboard UI: sorting, filtering, multi-item shopping list.

-- ============================================================================
-- State
-- ============================================================================

ProfitCraft_List = ProfitCraft_List or {}
ProfitCraft_FilteredList = ProfitCraft_FilteredList or {}

ProfitCraft_SortField = "profit"
ProfitCraft_SortAscending = false

ProfitCraft_Filters = {
    showLearned = true,
    showUnlearned = true,
    showQuest = true,
    showTrainer = true,
    showVendor = true,
    showDrop = true,
    showShoppingOnly = false,
}

-- Multi-item shopping list: { {recipe=<data>, qty=1}, ... }
ProfitCraft_ShoppingList = ProfitCraft_ShoppingList or {}
ProfitCraft_ShoppingListMax = 4
ProfitCraft_SelectedRecipe = ProfitCraft_SelectedRecipe or nil
ProfitCraft_SelectedRecipeKey = ProfitCraft_SelectedRecipeKey or nil

local NUM_DISPLAY_ROWS = 11
local TRACKER_ROW_HEIGHT = 18
local TRACKER_DISPLAY_ROWS = 10

local PROFESSION_SHORT_NAMES = {
    ["Alchemy"] = "Alch",
    ["Blacksmithing"] = "BS",
    ["Cooking"] = "Cook",
    ["Enchanting"] = "Ench",
    ["Engineering"] = "Eng",
    ["First Aid"] = "FA",
    ["Fishing"] = "Fish",
    ["Herbalism"] = "Herb",
    ["Leatherworking"] = "LW",
    ["Mining"] = "Mine",
    ["Skinning"] = "Skin",
    ["Tailoring"] = "Tail",
}

local function GetSettingValue(key, defaultValue)
    if ProfitCraft_GetSetting then
        local value = ProfitCraft_GetSetting(key, defaultValue)
        if value ~= nil then
            return value
        end
    end
    return defaultValue
end

local function SetSettingValue(key, value)
    if ProfitCraft_SetSetting then
        ProfitCraft_SetSetting(key, value and true or false)
    end
end

local function GetSourceStatusToken(source)
    if source == "Quest" then
        return "|cFFFFFF00!|r"
    elseif source == "Trainer" then
        return "|cFF66CCFFT|r"
    elseif source == "Vendor" then
        return "|cFF00FFCC$|r"
    elseif source == "Drop" then
        return "|cFFFF8800D|r"
    else
        return "|cFFFF8800?|r"
    end
end

local function GetItemIDFromLink(itemLink)
    if not itemLink then return nil end
    local _, _, itemId = string.find(itemLink, "item:(%d+):")
    if not itemId then return nil end
    return tonumber(itemId)
end

local function GetItemNameFromLink(itemLink)
    if not itemLink then return nil end
    local _, _, itemName = string.find(itemLink, "%[(.+)%]")
    return itemName
end

local function BuildCurrentBagCounts()
    local countsByID = {}
    local countsByName = {}

    if not GetContainerNumSlots or not GetContainerItemLink then
        return countsByID, countsByName
    end

    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            for slot = 1, numSlots do
                local itemLink = GetContainerItemLink(bag, slot)
                if itemLink then
                    local _, itemCount = GetContainerItemInfo(bag, slot)
                    if not itemCount or itemCount < 1 then itemCount = 1 end

                    local itemId = GetItemIDFromLink(itemLink)
                    if itemId then
                        countsByID[itemId] = (countsByID[itemId] or 0) + itemCount
                    end

                    local itemName = GetItemNameFromLink(itemLink)
                    if itemName then
                        local key = string.lower(itemName)
                        countsByName[key] = (countsByName[key] or 0) + itemCount
                    end
                end
            end
        end
    end

    return countsByID, countsByName
end

local function GetCurrentReagentHaveCount(reagent, countsByID, countsByName)
    if not reagent then return 0 end

    if reagent.link then
        local reagentID = GetItemIDFromLink(reagent.link)
        if reagentID and countsByID[reagentID] then
            return countsByID[reagentID]
        end
    end

    if reagent.name then
        local key = string.lower(reagent.name)
        if countsByName[key] then
            return countsByName[key]
        end
    end

    return reagent.playerCount or 0
end

local function BuildRecipeLookupKey(recipe)
    if not recipe or not recipe.name then return nil end

    local profession = ""
    if recipe.profession then
        profession = string.lower(recipe.profession)
    end
    return profession .. "\001" .. string.lower(recipe.name)
end

local function BuildRecipeLookupKeyFromParts(recipeName, profession)
    if not recipeName then return nil end
    local normalizedProfession = ""
    if profession then
        normalizedProfession = string.lower(profession)
    end
    return normalizedProfession .. "\001" .. string.lower(recipeName)
end

local function GetShoppingEntryLookupKey(entry)
    if not entry then return nil end

    if entry.recipe and entry.recipe.name then
        return BuildRecipeLookupKey(entry.recipe)
    end

    if entry.recipeName then
        return BuildRecipeLookupKeyFromParts(entry.recipeName, entry.profession)
    end

    return nil
end

local function GetProfessionShortName(profession)
    if not profession or profession == "" then
        return nil
    end

    if PROFESSION_SHORT_NAMES[profession] then
        return PROFESSION_SHORT_NAMES[profession]
    end

    return string.sub(profession, 1, 4)
end

local function GetRecipeDisplayName(recipeName, profession, dimName)
    local safeName = recipeName or "Unknown Recipe"
    if dimName then
        safeName = "|cFFAAAAAA" .. safeName .. "|r"
    end

    local shortProfession = GetProfessionShortName(profession)
    if not shortProfession then
        return safeName
    end

    return safeName .. " |cFF777777[" .. shortProfession .. "]|r"
end

local function PersistShoppingList()
    if ProfitCraft_SaveShoppingList then
        ProfitCraft_SaveShoppingList(ProfitCraft_ShoppingList)
    end
end

local function GetShoppingListEntryByKey(recipeKey)
    if not recipeKey then return nil end

    for _, entry in ipairs(ProfitCraft_ShoppingList) do
        local entryKey = GetShoppingEntryLookupKey(entry)
        if entryKey and entryKey == recipeKey then
            return entry
        end
    end

    return nil
end

local function SyncSelectedRecipeWithCurrentList()
    if not ProfitCraft_SelectedRecipeKey then
        ProfitCraft_SelectedRecipe = nil
        return
    end

    for _, recipe in ipairs(ProfitCraft_List) do
        local key = BuildRecipeLookupKey(recipe)
        if key and key == ProfitCraft_SelectedRecipeKey then
            ProfitCraft_SelectedRecipe = recipe
            return
        end
    end

    ProfitCraft_SelectedRecipe = nil
    ProfitCraft_SelectedRecipeKey = nil
end

local function RefreshDetailAddButton()
    local button = ProfitCraftTrackerAddButton
    if not button then return end

    if not ProfitCraft_SelectedRecipe then
        button:Disable()
        button:SetText("Add to Shopping")
        return
    end

    local selectedKey = BuildRecipeLookupKey(ProfitCraft_SelectedRecipe)
    local shoppingEntry = GetShoppingListEntryByKey(selectedKey)
    local currentQty = 0
    if shoppingEntry and shoppingEntry.qty then
        currentQty = shoppingEntry.qty
    end

    button:Enable()
    if currentQty > 0 then
        button:SetText("Add to Shopping (" .. currentQty .. ")")
    else
        button:SetText("Add to Shopping")
    end
end

local function SetCheckboxLabel(frameName, labelText, width)
    local checkbox = getglobal(frameName)
    if not checkbox then return end

    local text = getglobal(frameName .. "Text")
    if not text then return end

    text:SetText(labelText or "")
    text:ClearAllPoints()
    text:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
    text:SetJustifyH("LEFT")
    if width then
        text:SetWidth(width)
    end
end

local function ConfigureStaticCheckboxLabels()
    SetCheckboxLabel("ProfitCraftFilterLearned", "Learned", 70)
    SetCheckboxLabel("ProfitCraftFilterUnlearned", "Unlearned", 85)
    SetCheckboxLabel("ProfitCraftFilterQuest", "Quest", 55)
    SetCheckboxLabel("ProfitCraftFilterShoppingOnly", "Shopping Only", 105)

    SetCheckboxLabel("ProfitCraftSettingShowQuest", "Show Quest Unlearned", 200)
    SetCheckboxLabel("ProfitCraftSettingShowTrainer", "Show Trainer Unlearned", 200)
    SetCheckboxLabel("ProfitCraftSettingShowVendor", "Show Vendor Unlearned", 200)
    SetCheckboxLabel("ProfitCraftSettingShowDrop", "Show Drop Unlearned", 200)
    SetCheckboxLabel("ProfitCraftSettingAutoMerchant", "Open at Vendors", 200)
    SetCheckboxLabel("ProfitCraftSettingAutoAuction", "Open at Auction House", 200)
    SetCheckboxLabel("ProfitCraftSettingAutoShoppingOnly", "Use Shopping-Only on Auto Open", 210)
end

local function EnsureSettingsPanelOnTop()
    if not ProfitCraftSettingsPanel then return end

    local baseLevel = 200
    if ProfitCraftDashboard then
        baseLevel = ProfitCraftDashboard:GetFrameLevel() + 200
    end

    ProfitCraftSettingsPanel:SetFrameStrata("DIALOG")
    ProfitCraftSettingsPanel:SetFrameLevel(baseLevel)
    ProfitCraftSettingsPanel:EnableMouse(true)

    if ProfitCraftSettingsPanel.SetBackdropColor then
        ProfitCraftSettingsPanel:SetBackdropColor(0.06, 0.06, 0.06, 0.92)
        ProfitCraftSettingsPanel:SetBackdropBorderColor(0.75, 0.75, 0.75, 1.0)
    end

    local checkboxes = {
        "ProfitCraftSettingShowQuest",
        "ProfitCraftSettingShowTrainer",
        "ProfitCraftSettingShowVendor",
        "ProfitCraftSettingShowDrop",
        "ProfitCraftSettingAutoMerchant",
        "ProfitCraftSettingAutoAuction",
        "ProfitCraftSettingAutoShoppingOnly",
    }

    for _, checkboxName in ipairs(checkboxes) do
        local cb = getglobal(checkboxName)
        if cb then
            cb:SetFrameStrata("DIALOG")
            cb:SetFrameLevel(baseLevel + 5)
        end
    end
end

-- ============================================================================
-- Currency Formatting
-- ============================================================================

function ProfitCraft_FormatCurrency(copper)
    if not copper or copper == 0 then return "|cFF888888--|r" end

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

function ProfitCraft_FormatCurrencyNeutral(copper)
    if not copper or copper == 0 then return "|cFF888888--|r" end

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
-- Settings
-- ============================================================================

local function SyncTopFilterCheckboxes()
    if ProfitCraftFilterQuest then
        ProfitCraftFilterQuest:SetChecked(ProfitCraft_Filters.showQuest)
    end
    if ProfitCraftFilterShoppingOnly then
        ProfitCraftFilterShoppingOnly:SetChecked(ProfitCraft_Filters.showShoppingOnly)
    end
end

function ProfitCraft_RefreshSettingsUI()
    local settingsMap = {
        ProfitCraftSettingShowQuest = { key = "showQuest", fallback = true },
        ProfitCraftSettingShowTrainer = { key = "showTrainer", fallback = true },
        ProfitCraftSettingShowVendor = { key = "showVendor", fallback = true },
        ProfitCraftSettingShowDrop = { key = "showDrop", fallback = true },
        ProfitCraftSettingAutoMerchant = { key = "autoOpenMerchant", fallback = true },
        ProfitCraftSettingAutoAuction = { key = "autoOpenAuction", fallback = true },
        ProfitCraftSettingAutoShoppingOnly = { key = "autoOpenShoppingOnly", fallback = true },
    }

    for checkboxName, data in pairs(settingsMap) do
        local checkbox = getglobal(checkboxName)
        if checkbox then
            checkbox:SetChecked(GetSettingValue(data.key, data.fallback))
        end
    end
end

function ProfitCraft_ToggleSettings()
    if not ProfitCraftSettingsPanel then return end

    if ProfitCraftSettingsPanel:IsVisible() then
        ProfitCraftSettingsPanel:Hide()
    else
        EnsureSettingsPanelOnTop()
        ProfitCraft_RefreshSettingsUI()
        ProfitCraftSettingsPanel:Show()
    end
end

function ProfitCraft_OnSettingToggle(key)
    if not this then return end

    local checked = this:GetChecked() and true or false
    SetSettingValue(key, checked)

    if key == "showQuest" then
        ProfitCraft_Filters.showQuest = checked
    elseif key == "showTrainer" then
        ProfitCraft_Filters.showTrainer = checked
    elseif key == "showVendor" then
        ProfitCraft_Filters.showVendor = checked
    elseif key == "showDrop" then
        ProfitCraft_Filters.showDrop = checked
    end

    SyncTopFilterCheckboxes()
    ProfitCraft_ApplySortAndFilter()
    ProfitCraft_DashboardUpdate()
end

-- ============================================================================
-- Dashboard OnLoad
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

    -- Initialize filter state
    ProfitCraft_Filters.showLearned = true
    ProfitCraft_Filters.showUnlearned = true
    ProfitCraft_Filters.showQuest = GetSettingValue("showQuest", true)
    ProfitCraft_Filters.showTrainer = GetSettingValue("showTrainer", true)
    ProfitCraft_Filters.showVendor = GetSettingValue("showVendor", true)
    ProfitCraft_Filters.showDrop = GetSettingValue("showDrop", true)
    ProfitCraft_Filters.showShoppingOnly = GetSettingValue("showShoppingOnly", false)

    -- Initialize filter checkboxes
    if ProfitCraftFilterLearned then
        ProfitCraftFilterLearned:SetChecked(ProfitCraft_Filters.showLearned)
    end
    if ProfitCraftFilterUnlearned then
        ProfitCraftFilterUnlearned:SetChecked(ProfitCraft_Filters.showUnlearned)
    end
    if ProfitCraftFilterQuest then
        ProfitCraftFilterQuest:SetChecked(ProfitCraft_Filters.showQuest)
    end
    if ProfitCraftFilterShoppingOnly then
        ProfitCraftFilterShoppingOnly:SetChecked(ProfitCraft_Filters.showShoppingOnly)
    end

    if ProfitCraftSettingsPanel then
        ProfitCraftSettingsPanel:Hide()
    end
    EnsureSettingsPanelOnTop()
    ConfigureStaticCheckboxLabels()
    ProfitCraft_RefreshSettingsUI()

    -- Legacy top controls are replaced by the explicit detail-pane add button.
    if ProfitCraftTrackerMinus then ProfitCraftTrackerMinus:Hide() end
    if ProfitCraftTrackerPlus then ProfitCraftTrackerPlus:Hide() end
    if ProfitCraftTrackerAddButton then
        ProfitCraftTrackerAddButton:Disable()
    end

    local tracker = ProfitCraftTracker
    if not tracker then return end

    local trackerScroll = CreateFrame("ScrollFrame", "ProfitCraftTrackerScrollFrame", tracker, "FauxScrollFrameTemplate")
    trackerScroll:SetPoint("TOPLEFT", ProfitCraftTrackerTitle, "BOTTOMLEFT", 0, -4)
    trackerScroll:SetPoint("BOTTOMRIGHT", tracker, "BOTTOMRIGHT", -24, 4)
    trackerScroll:SetScript("OnVerticalScroll", function()
        FauxScrollFrame_OnVerticalScroll(TRACKER_ROW_HEIGHT, ProfitCraft_UpdateTracker)
    end)

    for i = 1, TRACKER_DISPLAY_ROWS do
        local row = CreateFrame("Frame", "ProfitCraftTrackerRow"..i, tracker)
        row:SetWidth(532)
        row:SetHeight(TRACKER_ROW_HEIGHT)

        if i == 1 then
            row:SetPoint("TOPLEFT", trackerScroll, "TOPLEFT", 0, 0)
        else
            row:SetPoint("TOPLEFT", "ProfitCraftTrackerRow"..(i-1), "BOTTOMLEFT", 0, 0)
        end

        local textFs = row:CreateFontString("ProfitCraftTrackerRow"..i.."Text", "ARTWORK", "GameFontHighlightSmall")
        textFs:SetJustifyH("LEFT")
        textFs:SetWidth(430)
        textFs:SetPoint("LEFT", row, "LEFT", 2, 0)

        local minusBtn = CreateFrame("Button", "ProfitCraftTrackerRow"..i.."Minus", row)
        minusBtn:SetWidth(16)
        minusBtn:SetHeight(16)
        minusBtn:SetPoint("RIGHT", row, "RIGHT", -48, 0)
        minusBtn:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
        minusBtn:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-Down")
        minusBtn:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
        minusBtn.recipeIndex = 0
        minusBtn:SetScript("OnClick", function()
            ProfitCraft_AdjustShoppingListQty(this.recipeIndex, -1)
        end)

        local plusBtn = CreateFrame("Button", "ProfitCraftTrackerRow"..i.."Plus", row)
        plusBtn:SetWidth(16)
        plusBtn:SetHeight(16)
        plusBtn:SetPoint("LEFT", minusBtn, "RIGHT", 2, 0)
        plusBtn:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
        plusBtn:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-Down")
        plusBtn:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
        plusBtn.recipeIndex = 0
        plusBtn:SetScript("OnClick", function()
            ProfitCraft_AdjustShoppingListQty(this.recipeIndex, 1)
        end)

        local removeBtn = CreateFrame("Button", "ProfitCraftTrackerRow"..i.."Remove", row)
        removeBtn:SetWidth(14)
        removeBtn:SetHeight(14)
        removeBtn:SetPoint("LEFT", plusBtn, "RIGHT", 4, 0)
        removeBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        removeBtn:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
        removeBtn.recipeIndex = 0
        removeBtn:SetScript("OnClick", function()
            ProfitCraft_RemoveFromShoppingList(this.recipeIndex)
        end)

        row:Hide()
    end

    if ProfitCraft_LoadShoppingList then
        ProfitCraft_ShoppingList = ProfitCraft_LoadShoppingList()
    end

    if ProfitCraft_SyncShoppingListRecipes then
        ProfitCraft_SyncShoppingListRecipes()
    end
    ProfitCraft_SelectedRecipe = nil
    ProfitCraft_SelectedRecipeKey = nil
    RefreshDetailAddButton()
    ProfitCraft_UpdateTracker()
end

-- ============================================================================
-- Sorting
-- ============================================================================

function ProfitCraft_SortBy(field)
    if ProfitCraft_SortField == field then
        ProfitCraft_SortAscending = not ProfitCraft_SortAscending
    else
        ProfitCraft_SortField = field
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

    if field == "name" then
        if ProfitCraft_SortAscending then
            return (valA or "") < (valB or "")
        else
            return (valA or "") > (valB or "")
        end
    end

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
    if ProfitCraftFilterLearned then
        ProfitCraft_Filters.showLearned = ProfitCraftFilterLearned:GetChecked() and true or false
    end
    if ProfitCraftFilterUnlearned then
        ProfitCraft_Filters.showUnlearned = ProfitCraftFilterUnlearned:GetChecked() and true or false
    end
    if ProfitCraftFilterQuest then
        ProfitCraft_Filters.showQuest = ProfitCraftFilterQuest:GetChecked() and true or false
        SetSettingValue("showQuest", ProfitCraft_Filters.showQuest)
    end
    if ProfitCraftFilterShoppingOnly then
        ProfitCraft_Filters.showShoppingOnly = ProfitCraftFilterShoppingOnly:GetChecked() and true or false
        SetSettingValue("showShoppingOnly", ProfitCraft_Filters.showShoppingOnly)
    end

    ProfitCraft_RefreshSettingsUI()
    ProfitCraft_ApplySortAndFilter()
    ProfitCraft_DashboardUpdate()
end

function ProfitCraft_SetShoppingOnlyFilter(enabled)
    ProfitCraft_Filters.showShoppingOnly = enabled and true or false
    SetSettingValue("showShoppingOnly", ProfitCraft_Filters.showShoppingOnly)
    if ProfitCraftFilterShoppingOnly then
        ProfitCraftFilterShoppingOnly:SetChecked(ProfitCraft_Filters.showShoppingOnly)
    end

    ProfitCraft_ApplySortAndFilter()
    ProfitCraft_DashboardUpdate()
end

function ProfitCraft_ApplySortAndFilter()
    ProfitCraft_FilteredList = {}

    local shoppingOnlyMap = nil
    if ProfitCraft_Filters.showShoppingOnly then
        shoppingOnlyMap = {}
        for _, shoppingEntry in ipairs(ProfitCraft_ShoppingList) do
            local shoppingKey = GetShoppingEntryLookupKey(shoppingEntry)
            if shoppingKey then
                shoppingOnlyMap[shoppingKey] = true
            end
        end
    end

    for _, entry in ipairs(ProfitCraft_List) do
        local dominated = true

        if entry.isLearned and not ProfitCraft_Filters.showLearned then
            dominated = false
        end
        if not entry.isLearned and not ProfitCraft_Filters.showUnlearned then
            dominated = false
        end

        if not entry.isLearned then
            if entry.source == "Quest" and not ProfitCraft_Filters.showQuest then
                dominated = false
            elseif entry.source == "Trainer" and not ProfitCraft_Filters.showTrainer then
                dominated = false
            elseif entry.source == "Vendor" and not ProfitCraft_Filters.showVendor then
                dominated = false
            elseif entry.source == "Drop" and not ProfitCraft_Filters.showDrop then
                dominated = false
            end
        end

        if dominated and shoppingOnlyMap then
            local entryKey = BuildRecipeLookupKey(entry)
            if not entryKey or not shoppingOnlyMap[entryKey] then
                dominated = false
            end
        end

        if dominated then
            table.insert(ProfitCraft_FilteredList, entry)
        end
    end
    table.sort(ProfitCraft_FilteredList, SortCompare)
end

-- ============================================================================
-- Dashboard Update
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
                    statusText:SetText(GetSourceStatusToken(data.source))
                end

                -- Name (dimmed for unlearned)
                local nameText = getglobal("ProfitCraftDashboardEntry"..i.."Name")
                nameText:SetText(GetRecipeDisplayName(data.name, data.profession, not data.isLearned))

                -- Columns
                getglobal("ProfitCraftDashboardEntry"..i.."Cost"):SetText(ProfitCraft_FormatCurrencyNeutral(data.cost))
                getglobal("ProfitCraftDashboardEntry"..i.."Value"):SetText(ProfitCraft_FormatCurrencyNeutral(data.marketValue))
                getglobal("ProfitCraftDashboardEntry"..i.."Profit"):SetText(ProfitCraft_FormatCurrency(data.profit))

                button.dataIndex = index

                local dataKey = BuildRecipeLookupKey(data)
                local isSelected = dataKey and ProfitCraft_SelectedRecipeKey and dataKey == ProfitCraft_SelectedRecipeKey
                if isSelected then
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
-- Entry Click / Hover
-- ============================================================================

function ProfitCraft_OnEntryClick(btn)
    if not btn or not btn.dataIndex then return end
    local data = ProfitCraft_FilteredList[btn.dataIndex]
    if not data then return end

    ProfitCraft_SelectedRecipe = data
    ProfitCraft_SelectedRecipeKey = BuildRecipeLookupKey(data)
    RefreshDetailAddButton()
    ProfitCraft_UpdateTracker()
    ProfitCraft_DashboardUpdate()
end

function ProfitCraft_OnEntryEnter(btn)
    if not btn or not btn.dataIndex then return end
    local data = ProfitCraft_FilteredList[btn.dataIndex]
    if not data then return end

    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")

    if data.itemLink then
        GameTooltip:SetHyperlink(data.itemLink)
    else
        GameTooltip:AddLine(data.name, 1, 1, 1)
    end

    GameTooltip:AddLine(" ")
    if data.profession then
        GameTooltip:AddDoubleLine("Profession:", data.profession, 0.7, 0.7, 0.7, 1, 1, 1)
    end
    GameTooltip:AddDoubleLine("Market Value:", ProfitCraft_FormatCurrencyNeutral(data.marketValue), 0.7, 0.7, 0.7)
    GameTooltip:AddDoubleLine("Craft Cost:", ProfitCraft_FormatCurrencyNeutral(data.cost), 0.7, 0.7, 0.7)
    GameTooltip:AddDoubleLine("Profit:", ProfitCraft_FormatCurrency(data.profit), 0.7, 0.7, 0.7)

    if not data.isLearned then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Source: " .. (data.source or "Unknown"), 1, 0.8, 0)
        if data.sourceDetails then
            GameTooltip:AddLine(data.sourceDetails, 0.7, 0.7, 0.7, true)
        end
    end

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
    GameTooltip:AddLine("|cFF888888Click to view details below|r")
    GameTooltip:Show()
end

-- ============================================================================
-- Multi-Item Shopping List
-- ============================================================================

function ProfitCraft_AddSelectedRecipeToShoppingList()
    if not ProfitCraft_SelectedRecipe then
        return
    end

    local data = ProfitCraft_SelectedRecipe
    local targetKey = BuildRecipeLookupKey(data)
    if not targetKey then
        return
    end

    local existing = GetShoppingListEntryByKey(targetKey)
    if existing then
        existing.qty = (existing.qty or 1) + 1
        if existing.qty > 99 then existing.qty = 99 end
        existing.recipe = data
        existing.recipeName = data.name
        existing.profession = data.profession
    else
        if table.getn(ProfitCraft_ShoppingList) >= ProfitCraft_ShoppingListMax then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8800[ProfitCraft]|r Shopping list full (max " .. ProfitCraft_ShoppingListMax .. "). Remove an item first.")
            return
        end

        table.insert(ProfitCraft_ShoppingList, {
            recipe = data,
            recipeName = data.name,
            profession = data.profession,
            qty = 1,
        })
    end

    PersistShoppingList()
    RefreshDetailAddButton()
    ProfitCraft_UpdateTracker()
    ProfitCraft_ApplySortAndFilter()
    ProfitCraft_DashboardUpdate()
end

function ProfitCraft_RemoveFromShoppingList(index)
    if ProfitCraft_ShoppingList[index] then
        table.remove(ProfitCraft_ShoppingList, index)
        PersistShoppingList()
        RefreshDetailAddButton()
        ProfitCraft_UpdateTracker()
        ProfitCraft_ApplySortAndFilter()
        ProfitCraft_DashboardUpdate()
    end
end

local function ClampShoppingQty(qty)
    if qty < 1 then return 1 end
    if qty > 99 then return 99 end
    return qty
end

function ProfitCraft_AdjustShoppingListQty(index, delta)
    local entry = ProfitCraft_ShoppingList[index]
    if not entry then return end

    entry.qty = ClampShoppingQty((entry.qty or 1) + (delta or 0))

    PersistShoppingList()
    RefreshDetailAddButton()
    ProfitCraft_UpdateTracker()
    ProfitCraft_ApplySortAndFilter()
    ProfitCraft_DashboardUpdate()
end

function ProfitCraft_ClearShoppingList()
    ProfitCraft_ShoppingList = {}
    PersistShoppingList()
    RefreshDetailAddButton()
    ProfitCraft_UpdateTracker()
    ProfitCraft_ApplySortAndFilter()
    ProfitCraft_DashboardUpdate()
end

function ProfitCraft_TrackerAdjustQty(delta)
    -- Legacy control fallback: adjust the most recently added entry.
    local count = table.getn(ProfitCraft_ShoppingList)
    if count == 0 then return end

    ProfitCraft_AdjustShoppingListQty(count, delta)
end

function ProfitCraft_SyncShoppingListRecipes()
    local lookup = {}
    for _, recipe in ipairs(ProfitCraft_List) do
        local key = BuildRecipeLookupKey(recipe)
        if key and not lookup[key] then
            lookup[key] = recipe
        end
    end

    for _, shoppingEntry in ipairs(ProfitCraft_ShoppingList) do
        local key = GetShoppingEntryLookupKey(shoppingEntry)
        if key and lookup[key] then
            shoppingEntry.recipe = lookup[key]
            shoppingEntry.recipeName = shoppingEntry.recipe.name
            shoppingEntry.profession = shoppingEntry.recipe.profession
        elseif shoppingEntry.recipe and shoppingEntry.recipe.name then
            shoppingEntry.recipeName = shoppingEntry.recipe.name
            if not shoppingEntry.profession then
                shoppingEntry.profession = shoppingEntry.recipe.profession
            end
        end
    end

    PersistShoppingList()
    RefreshDetailAddButton()
end

function ProfitCraft_UpdateTracker()
    local titleFs = getglobal("ProfitCraftTrackerTitle")
    if titleFs then titleFs:SetText("Recipe Details") end

    SyncSelectedRecipeWithCurrentList()
    RefreshDetailAddButton()
    local selected = ProfitCraft_SelectedRecipe

    local rows = {}
    local bagCountsByID, bagCountsByName = BuildCurrentBagCounts()

    if not selected then
        table.insert(rows, {
            type = "info",
            text = "|cFF888888Click a recipe above to view details|r",
        })
    else
        local shoppingEntry = GetShoppingListEntryByKey(ProfitCraft_SelectedRecipeKey)
        local selectedQty = 0
        if shoppingEntry and shoppingEntry.qty then
            selectedQty = shoppingEntry.qty
        end

        local professionSuffix = ""
        local shortProfession = GetProfessionShortName(selected.profession)
        if shortProfession then
            professionSuffix = " |cFF777777[" .. shortProfession .. "]|r"
        end

        local learnedText = "|cFFFFCC66Unlearned|r"
        if selected.isLearned then
            learnedText = "|cFF00FF00Learned|r"
        end

        table.insert(rows, {
            type = "recipe",
            text = "|cFFFFD100" .. (selected.name or "Unknown Recipe") .. "|r" .. professionSuffix,
        })
        table.insert(rows, {
            type = "meta",
            text = "  |cFFAAAAAAStatus:|r " .. learnedText
                .. "  |cFFAAAAAAIn List:|r " .. selectedQty,
        })
        table.insert(rows, {
            type = "meta",
            text = "  |cFFAAAAAAMarket Value:|r " .. ProfitCraft_FormatCurrencyNeutral(selected.marketValue),
        })
        table.insert(rows, {
            type = "meta",
            text = "  |cFFAAAAAACraft Cost:|r " .. ProfitCraft_FormatCurrencyNeutral(selected.cost),
        })
        table.insert(rows, {
            type = "meta",
            text = "  |cFFAAAAAAProfit:|r " .. ProfitCraft_FormatCurrency(selected.profit),
        })

        if selected.source and selected.source ~= "" then
            table.insert(rows, {
                type = "meta",
                text = "  |cFFAAAAAASource:|r " .. selected.source,
            })
        end

        if selected.sourceDetails and selected.sourceDetails ~= "" then
            table.insert(rows, {
                type = "meta",
                text = "  |cFFAAAAAADetails:|r " .. selected.sourceDetails,
            })
        end

        table.insert(rows, {
            type = "header",
            text = "|cFFFFFFCCReagents|r",
        })

        local reagentCount = 0
        if selected.reagents then
            reagentCount = table.getn(selected.reagents)
        end

        if reagentCount == 0 then
            table.insert(rows, {
                type = "reagent",
                text = "  |cFF888888No reagent data|r",
            })
        else
            for _, reagent in ipairs(selected.reagents) do
                local need = reagent.count or 0
                local have = GetCurrentReagentHaveCount(reagent, bagCountsByID, bagCountsByName)

                local color = "|cFFFF4444"
                if have >= need then
                    color = "|cFF00FF00"
                elseif have > 0 then
                    color = "|cFFFFFF00"
                end

                table.insert(rows, {
                    type = "reagent",
                    text = "  " .. color .. have .. "/" .. need .. "|r  " .. (reagent.name or "Unknown"),
                })
            end
        end
    end

    local totalRows = table.getn(rows)
    local scrollFrame = getglobal("ProfitCraftTrackerScrollFrame")
    if scrollFrame then
        FauxScrollFrame_Update(scrollFrame, totalRows, TRACKER_DISPLAY_ROWS, TRACKER_ROW_HEIGHT)
    end

    local offset = 0
    if scrollFrame then
        offset = FauxScrollFrame_GetOffset(scrollFrame)
    end

    for i = 1, TRACKER_DISPLAY_ROWS do
        local row = getglobal("ProfitCraftTrackerRow"..i)
        local textFs = getglobal("ProfitCraftTrackerRow"..i.."Text")
        local minusBtn = getglobal("ProfitCraftTrackerRow"..i.."Minus")
        local plusBtn = getglobal("ProfitCraftTrackerRow"..i.."Plus")
        local removeBtn = getglobal("ProfitCraftTrackerRow"..i.."Remove")

        if row and textFs and minusBtn and plusBtn and removeBtn then
            local rowData = rows[offset + i]
            if rowData then
                textFs:SetText(rowData.text or "")
                minusBtn:Hide()
                plusBtn:Hide()
                removeBtn:Hide()

                row:Show()
            else
                row:Hide()
            end
        end
    end
end

-- ============================================================================
-- Auto Open on Merchant/Auction
-- ============================================================================

function ProfitCraft_HandleContextAutoOpen(context)
    if not ProfitCraft_ShoppingList or table.getn(ProfitCraft_ShoppingList) == 0 then
        return
    end

    if context == "merchant" and not GetSettingValue("autoOpenMerchant", true) then
        return
    end
    if context == "auction" and not GetSettingValue("autoOpenAuction", true) then
        return
    end

    if GetSettingValue("autoOpenShoppingOnly", true) then
        ProfitCraft_Filters.showShoppingOnly = true
        if ProfitCraftFilterShoppingOnly then
            ProfitCraftFilterShoppingOnly:SetChecked(true)
        end
    end

    if ProfitCraftDashboard and not ProfitCraftDashboard:IsVisible() then
        ProfitCraftDashboard:Show()
    end

    ProfitCraft_ApplySortAndFilter()
    ProfitCraft_DashboardUpdate()
    ProfitCraft_UpdateTracker()
end

-- ============================================================================
-- Toggle Dashboard
-- ============================================================================

function ProfitCraft_ToggleDashboard()
    if not ProfitCraftDashboard then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[ProfitCraft] Error:|r Dashboard frame is missing.")
        return
    end

    if ProfitCraftDashboard:IsVisible() then
        ProfitCraftDashboard:Hide()
        if ProfitCraftSettingsPanel then
            ProfitCraftSettingsPanel:Hide()
        end
    else
        ProfitCraftDashboard:Show()
        if ProfitCraft_CalculateProfits then
            ProfitCraft_CalculateProfits(true)
        else
            ProfitCraft_ApplySortAndFilter()
            ProfitCraft_DashboardUpdate()
            ProfitCraft_UpdateTracker()
        end
    end
end

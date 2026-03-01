-- ProfitCraft: dashboard.lua
-- Dashboard UI: sorting, filtering, multi-item shopping list.

-- ============================================================================
-- State
-- ============================================================================

ProfitCraft_List = {}
ProfitCraft_FilteredList = {}

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
ProfitCraft_ShoppingList = {}
ProfitCraft_ShoppingListMax = 4

local NUM_DISPLAY_ROWS = 11

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
        ProfitCraft_RefreshSettingsUI()
        if ProfitCraftDashboard then
            ProfitCraftSettingsPanel:SetFrameLevel(ProfitCraftDashboard:GetFrameLevel() + 10)
        end
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
    ConfigureStaticCheckboxLabels()
    ProfitCraft_RefreshSettingsUI()

    -- Create shopping list entry rows (up to 4 tracked recipes)
    for i = 1, ProfitCraft_ShoppingListMax do
        -- Item name text
        local nameFs = frame:CreateFontString("ProfitCraftShopItem"..i.."Name", "ARTWORK", "GameFontHighlightSmall")
        nameFs:SetJustifyH("LEFT")
        nameFs:SetWidth(300)

        if i == 1 then
            nameFs:SetPoint("TOPLEFT", ProfitCraftTrackerTitle, "BOTTOMLEFT", 0, -4)
        else
            nameFs:SetPoint("TOPLEFT", "ProfitCraftShopItem"..(i-1).."Name", "BOTTOMLEFT", 0, -2)
        end
        nameFs:SetText("")
        nameFs:Hide()

        -- Qty text
        local qtyFs = frame:CreateFontString("ProfitCraftShopItem"..i.."Qty", "ARTWORK", "GameFontNormalSmall")
        qtyFs:SetJustifyH("RIGHT")
        qtyFs:SetPoint("LEFT", nameFs, "RIGHT", 5, 0)
        qtyFs:SetText("")
        qtyFs:Hide()

        -- Remove button (small X)
        local removeBtn = CreateFrame("Button", "ProfitCraftShopItem"..i.."Remove", frame)
        removeBtn:SetWidth(14)
        removeBtn:SetHeight(14)
        removeBtn:SetPoint("LEFT", qtyFs, "RIGHT", 4, 0)
        removeBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        removeBtn:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
        removeBtn.index = i
        removeBtn:SetScript("OnClick", function()
            ProfitCraft_RemoveFromShoppingList(this.index)
        end)
        removeBtn:Hide()
    end

    -- Reagent summary header
    local reagentHeader = frame:CreateFontString("ProfitCraftReagentHeader", "ARTWORK", "GameFontNormalSmall")
    reagentHeader:SetJustifyH("LEFT")
    reagentHeader:SetTextColor(1, 0.82, 0)
    reagentHeader:SetText("Reagents Needed:")
    reagentHeader:SetPoint("TOPLEFT", "ProfitCraftShopItem"..ProfitCraft_ShoppingListMax.."Name", "BOTTOMLEFT", 0, -6)
    reagentHeader:Hide()

    -- Aggregated reagent lines (up to 8)
    for i = 1, 8 do
        local fs = frame:CreateFontString("ProfitCraftReagentLine"..i, "ARTWORK", "GameFontHighlightSmall")
        fs:SetJustifyH("LEFT")
        fs:SetWidth(400)
        if i == 1 then
            fs:SetPoint("TOPLEFT", reagentHeader, "BOTTOMLEFT", 2, -2)
        else
            fs:SetPoint("TOPLEFT", "ProfitCraftReagentLine"..(i-1), "BOTTOMLEFT", 0, -1)
        end
        fs:SetText("")
        fs:Hide()
    end
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
            if shoppingEntry.recipe and shoppingEntry.recipe.name then
                shoppingOnlyMap[string.lower(shoppingEntry.recipe.name)] = true
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
            local entryName = entry.name and string.lower(entry.name) or ""
            if entryName == "" or not shoppingOnlyMap[entryName] then
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
                if data.isLearned then
                    nameText:SetText(data.name)
                else
                    nameText:SetText("|cFFAAAAAA" .. data.name .. "|r")
                end

                -- Columns
                getglobal("ProfitCraftDashboardEntry"..i.."Cost"):SetText(ProfitCraft_FormatCurrencyNeutral(data.cost))
                getglobal("ProfitCraftDashboardEntry"..i.."Value"):SetText(ProfitCraft_FormatCurrencyNeutral(data.marketValue))
                getglobal("ProfitCraftDashboardEntry"..i.."Profit"):SetText(ProfitCraft_FormatCurrency(data.profit))

                button.dataIndex = index

                -- Highlight items in shopping list
                local inList = false
                for _, entry in ipairs(ProfitCraft_ShoppingList) do
                    if entry.recipe and entry.recipe.name == data.name then
                        inList = true
                        break
                    end
                end
                if inList then
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

    -- Check if already in the shopping list
    for _, entry in ipairs(ProfitCraft_ShoppingList) do
        if entry.recipe and entry.recipe.name == data.name then
            -- Increment quantity instead of adding a duplicate
            entry.qty = entry.qty + 1
            if entry.qty > 99 then entry.qty = 99 end
            ProfitCraft_UpdateTracker()
            ProfitCraft_ApplySortAndFilter()
            ProfitCraft_DashboardUpdate()
            return
        end
    end

    -- Add new entry if there's room
    if table.getn(ProfitCraft_ShoppingList) >= ProfitCraft_ShoppingListMax then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8800[ProfitCraft]|r Shopping list full (max " .. ProfitCraft_ShoppingListMax .. "). Remove an item first.")
        return
    end

    table.insert(ProfitCraft_ShoppingList, {
        recipe = data,
        qty = 1,
    })

    ProfitCraft_UpdateTracker()
    ProfitCraft_ApplySortAndFilter()
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
    GameTooltip:AddLine("|cFF888888Click to add to Shopping List|r")
    GameTooltip:Show()
end

-- ============================================================================
-- Multi-Item Shopping List
-- ============================================================================

function ProfitCraft_RemoveFromShoppingList(index)
    if ProfitCraft_ShoppingList[index] then
        table.remove(ProfitCraft_ShoppingList, index)
        -- Re-index remove buttons
        for i = 1, ProfitCraft_ShoppingListMax do
            local rb = getglobal("ProfitCraftShopItem"..i.."Remove")
            if rb then rb.index = i end
        end
        ProfitCraft_UpdateTracker()
        ProfitCraft_ApplySortAndFilter()
        ProfitCraft_DashboardUpdate()
    end
end

function ProfitCraft_TrackerAdjustQty(delta)
    -- Apply to the LAST added item in the shopping list
    local count = table.getn(ProfitCraft_ShoppingList)
    if count == 0 then return end

    local entry = ProfitCraft_ShoppingList[count]
    entry.qty = entry.qty + delta
    if entry.qty < 1 then entry.qty = 1 end
    if entry.qty > 99 then entry.qty = 99 end

    ProfitCraft_UpdateTracker()
end

function ProfitCraft_UpdateTracker()
    local count = table.getn(ProfitCraft_ShoppingList)

    -- Update qty display on the +/- buttons area
    local qtyText = getglobal("ProfitCraftTrackerQtyText")
    if qtyText then
        if count > 0 then
            qtyText:SetText(tostring(ProfitCraft_ShoppingList[count].qty))
        else
            qtyText:SetText("-")
        end
    end

    -- Update each shopping list row
    for i = 1, ProfitCraft_ShoppingListMax do
        local nameFs = getglobal("ProfitCraftShopItem"..i.."Name")
        local qtyFs = getglobal("ProfitCraftShopItem"..i.."Qty")
        local removeBtn = getglobal("ProfitCraftShopItem"..i.."Remove")

        if nameFs and qtyFs and removeBtn then
            if i <= count then
                local entry = ProfitCraft_ShoppingList[i]
                nameFs:SetText("|cFFFFD100" .. entry.recipe.name .. "|r")
                qtyFs:SetText("|cFFFFFFFFx" .. entry.qty .. "|r")
                nameFs:Show()
                qtyFs:Show()
                removeBtn:Show()
            else
                nameFs:Hide()
                qtyFs:Hide()
                removeBtn:Hide()
            end
        end
    end

    -- Aggregate reagents across all shopping list items
    local reagentHeader = getglobal("ProfitCraftReagentHeader")
    if count == 0 then
        if reagentHeader then reagentHeader:Hide() end
        -- Hide all reagent lines
        for i = 1, 8 do
            local fs = getglobal("ProfitCraftReagentLine"..i)
            if fs then fs:Hide() end
        end

        -- Show placeholder text via the title area
        local titleFs = getglobal("ProfitCraftTrackerTitle")
        if titleFs then titleFs:SetText("Shopping List  |cFF888888(click recipes above to add)|r") end
        return
    end

    local titleFs = getglobal("ProfitCraftTrackerTitle")
    if titleFs then titleFs:SetText("Shopping List") end

    -- Build aggregated reagent map: { reagentName -> {need=X, have=Y} }
    local reagentMap = {}
    local reagentOrder = {}

    for _, entry in ipairs(ProfitCraft_ShoppingList) do
        if entry.recipe.reagents then
            for _, r in ipairs(entry.recipe.reagents) do
                local rName = r.name or "Unknown"
                if not reagentMap[rName] then
                    reagentMap[rName] = { need = 0, have = r.playerCount or 0 }
                    table.insert(reagentOrder, rName)
                end
                reagentMap[rName].need = reagentMap[rName].need + (r.count * entry.qty)
                -- Update 'have' to the max we've seen (same reagent, same bag count)
                local currentHave = r.playerCount or 0
                if currentHave > reagentMap[rName].have then
                    reagentMap[rName].have = currentHave
                end
            end
        end
    end

    if reagentHeader then
        if table.getn(reagentOrder) > 0 then
            reagentHeader:Show()
        else
            reagentHeader:Hide()
        end
    end

    for i = 1, 8 do
        local fs = getglobal("ProfitCraftReagentLine"..i)
        if fs then
            if reagentOrder[i] then
                local rName = reagentOrder[i]
                local info = reagentMap[rName]
                local color = "|cFFFF4444"
                if info.have >= info.need then
                    color = "|cFF00FF00"
                elseif info.have > 0 then
                    color = "|cFFFFFF00"
                end
                fs:SetText(color .. info.have .. "/" .. info.need .. "|r  " .. rName)
                fs:Show()
            else
                fs:Hide()
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
        ProfitCraft_ApplySortAndFilter()
        ProfitCraft_DashboardUpdate()
        ProfitCraft_UpdateTracker()
    end
end

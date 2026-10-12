-- Snack Check
-- using items is protected, so every click goes through a secure button whose
-- macro gets rewritten (out of combat) whenever the bags change

-- Keybinds ------------------------------------------------------------------

local BIND_BOTH = "CLICK SnackCheckButton:LeftButton"
local BIND_EAT = "CLICK SnackCheckEatKey:LeftButton"
local BIND_DRINK = "CLICK SnackCheckDrinkKey:LeftButton"

BINDING_HEADER_SNACKCHECK = "Snack Check"
_G["BINDING_NAME_" .. BIND_BOTH] = "Eat & drink"
_G["BINDING_NAME_" .. BIND_EAT] = "Eat"
_G["BINDING_NAME_" .. BIND_DRINK] = "Drink"

-- State ---------------------------------------------------------------------

local FOOD_AND_DRINK_SUBCLASS = 5
-- shown when there's nothing to use (macros want the bare icon name)
local PLACEHOLDER = {
	food = "INV_Misc_Fork&Knife",
	drink = "INV_Drink_07",
}
-- the ? icon makes a macro follow #showtooltip
local DYNAMIC_MACRO_ICON = 134400

-- real values get set at login
local buttonSize = 45
local spacing = 6
local vertical = false
local COUNT_FONT, DEFAULT_COUNT_SIZE, COUNT_FLAGS = NumberFontNormal:GetFont()
DEFAULT_COUNT_SIZE = math.floor(DEFAULT_COUNT_SIZE + 0.5)
local countSize = DEFAULT_COUNT_SIZE

-- spell names come from the client so non-English clients work too
local KIND = {
	[C_Spell.GetSpellName(433) or "Food"] = "food",
	[C_Spell.GetSpellName(430) or "Drink"] = "drink",
}
local WELL_FED = (C_Spell.GetSpellName(19705) or "Well Fed"):lower()
local CONJURED = ITEM_CONJURED or "Conjured Item"

local items = { food = {}, drink = {} }
local chosen = {}
-- what the warnings track: same as chosen, minus conjured stuff you can't buy
local restock = {}
local tooltipFlags = {}
local updatePending = false

local anchor = CreateFrame("Frame", "SnackCheckAnchor", UIParent)
anchor:SetMovable(true)
anchor:SetClampedToScreen(true)

-- hidden buttons for the keybinds. the visible ones ignore shift-clicks
-- (shift-drag), which would break something like SHIFT-F
local function createKeyButton(name)
	local button = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
	button:SetAttribute("type", "macro")
	button:RegisterForClicks("AnyUp", "AnyDown")
	return button
end

local combined = createKeyButton("SnackCheckButton")
local keyButtons = {
	food = createKeyButton("SnackCheckEatKey"),
	drink = createKeyButton("SnackCheckDrinkKey"),
}

local flyout = CreateFrame("Frame", nil, UIParent)
flyout:SetFrameStrata("DIALOG")
flyout:Hide()
flyout.buttons = {}

local buttons = {}

-- Bags ----------------------------------------------------------------------

-- buff food uses the Food spell too, don't waste it on a normal top-up.
-- conjured stuff is free, so it goes first
local function readTooltip(bag, slot, id)
	if tooltipFlags[id] then
		return tooltipFlags[id]
	end
	local flags = { buff = false, conjured = false }
	local data = C_TooltipInfo.GetBagItem(bag, slot)
	for _, line in ipairs(data and data.lines or {}) do
		local text = line.leftText
		if text then
			if text == CONJURED then
				flags.conjured = true
			elseif text:lower():find(WELL_FED, 1, true) then
				flags.buff = true
			end
		end
	end
	-- don't remember an empty tooltip, it might just not be loaded yet
	if data and data.lines and #data.lines > 0 then
		tooltipFlags[id] = flags
	end
	return flags
end

-- highest level first, then the smaller pile so leftovers get eaten first
local function byBest(a, b)
	if a.minLevel ~= b.minLevel then return a.minLevel > b.minLevel end
	if a.count ~= b.count then return a.count < b.count end
	return a.id < b.id
end

local function scan()
	wipe(items.food)
	wipe(items.drink)
	local seen = {}
	local incomplete = false
	for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and not seen[info.itemID] then
				local id = info.itemID
				local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(id)
				if classID == Enum.ItemClass.Consumable and subClassID == FOOD_AND_DRINK_SUBCLASS then
					local spellName = C_Item.GetItemSpell(id)
					local minLevel = select(5, C_Item.GetItemInfo(id))
					local kind = KIND[spellName]
					if not spellName or not minLevel then
						incomplete = true
					elseif kind then
						seen[id] = true
						local flags = readTooltip(bag, slot, id)
						table.insert(items[kind], {
							id = id,
							name = info.itemName,
							icon = info.iconFileID,
							minLevel = minLevel,
							count = C_Item.GetItemCount(id),
							buff = flags.buff,
							conjured = flags.conjured,
						})
					end
				end
			end
		end
	end
	table.sort(items.food, byBest)
	table.sort(items.drink, byBest)
	return incomplete
end

-- order: pinned buff food, conjured, pinned, best non-buff.
-- conjuredFilter "skip" or "only" narrows it down for the warnings
local function choose(kind, level, conjuredFilter)
	local pinnedID = SnackCheckCharDB[kind]
	local pinned, conjured, best
	for _, entry in ipairs(items[kind]) do
		local allowed = conjuredFilter == nil
			or (conjuredFilter == "skip" and not entry.conjured)
			or (conjuredFilter == "only" and entry.conjured)
		if entry.minLevel <= level and allowed then
			if entry.id == pinnedID then
				pinned = entry
			elseif entry.conjured and not entry.buff then
				conjured = conjured or entry
			elseif not entry.buff then
				best = best or entry
			end
		end
	end
	if pinned and pinned.buff then return pinned end
	return conjured or pinned or best
end

-- Warnings ------------------------------------------------------------------

-- the login reminder skips the screen when chat is on, it'd land on the zone name
local function alert(msg, atLogin)
	local alerts = SnackCheckDB.alerts
	if alerts.chat then
		print("|cffffd200Snack Check|r: " .. msg)
	end
	if alerts.screen and not (atLogin and alerts.chat) then
		RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo.RAID_WARNING)
	end
end

-- mages who know a conjure spell get warned about their conjured supply
-- instead. every rank has its own ID, and learning a new one might drop the
-- old one, so check them all
local CONJURE_RANKS = {
	food = { 587, 597, 990, 6129, 10144, 10145, 28612 },
	drink = { 5504, 5505, 5506, 6127, 10138, 10139, 10140 },
}
local function conjures(kind)
	local _, class = UnitClass("player")
	if class ~= "MAGE" then return false end
	for _, spellID in ipairs(CONJURE_RANKS[kind]) do
		if IsPlayerSpell(spellID) then return true end
	end
	return false
end

-- only warns when crossing the threshold (and once at login). if the button
-- switches item, e.g. the pinned one ran out, the new one is checked fresh
local lastStock = {}
local function checkStock(kind, report)
	local entry = restock[kind]
	local id = entry and entry.id
	local count = entry and entry.count or 0
	local last = lastStock[kind]
	local before = last and last.id == id and last.count or nil
	lastStock[kind] = { id = id, count = count }

	local conjure = conjures(kind)
	local label = conjure and "conjured " .. kind or kind
	local threshold = SnackCheckDB.thresholds[kind]
	if not entry then
		if not last or last.id then
			report.out[#report.out + 1] = label
		else
			return
		end
	elseif count < threshold and (not before or before >= threshold) then
		report.lowKinds[#report.lowKinds + 1] = label
		report.lowItems[#report.lowItems + 1] = count .. " " .. entry.name
	else
		return
	end
	if conjure then
		report.conjure = true
	else
		report.buy = true
	end
end

-- food and drink from the same check share one message
local function checkAllStock(hasMana)
	local atLogin = next(lastStock) == nil
	local report = { out = {}, lowKinds = {}, lowItems = {} }
	checkStock("food", report)
	if hasMana then
		checkStock("drink", report)
	end
	if atLogin and not SnackCheckDB.alerts.login then return end

	local parts = {}
	if #report.out > 0 then
		parts[#parts + 1] = ("You're out of %s."):format(table.concat(report.out, " and "))
	end
	if #report.lowKinds > 0 then
		parts[#parts + 1] = ("Low on %s: %s."):format(
			table.concat(report.lowKinds, " and "), table.concat(report.lowItems, ", "))
	end
	if #parts > 0 then
		local action = report.conjure and report.buy and "Time to restock and conjure more."
			or report.conjure and "Time to conjure more."
			or "Time to restock."
		alert(table.concat(parts, " ") .. " " .. action, atLogin)
	end
end

-- Macros --------------------------------------------------------------------

-- per character, prefixed so we never touch the player's own macros
local MACROS = {
	{ name = "SC Eat", kinds = { "food" }, placeholder = PLACEHOLDER.food },
	{ name = "SC Drink", kinds = { "drink" }, placeholder = PLACEHOLDER.drink, needsMana = true },
	{ name = "SC Eat+Drink", kinds = { "food", "drink" }, placeholder = PLACEHOLDER.food },
}

-- macros aren't always loaded at PLAYER_LOGIN, an early lookup finds nothing
-- and we'd make a duplicate
local macrosReady = false

-- bags arrive a bit after login, wait this long before checking stock
local STOCK_DELAY = 3
local stockReady = false
local warnedMacrosFull = false

local function syncMacros(hasMana)
	if not macrosReady then return end
	for _, macro in ipairs(MACROS) do
		local index = GetMacroIndexByName(macro.name)
		if not SnackCheckDB.macros or (macro.needsMana and not hasMana) then
			if index > 0 then DeleteMacro(index) end
		else
			local lines = { "#showtooltip" }
			for _, kind in ipairs(macro.kinds) do
				if chosen[kind] then
					lines[#lines + 1] = "/use item:" .. chosen[kind].id
				end
			end
			local icon = #lines > 1 and DYNAMIC_MACRO_ICON or macro.placeholder
			local body = table.concat(lines, "\n")

			if index > 0 then
				if select(3, GetMacroInfo(index)) ~= body then
					EditMacro(index, macro.name, icon, body)
				end
			elseif select(2, GetNumMacros()) < (MAX_CHARACTER_MACROS or 18) then
				CreateMacro(macro.name, icon, body, true)
			elseif not warnedMacrosFull then
				warnedMacrosFull = true
				print("|cffffd200Snack Check|r: your character macros are full, so " .. macro.name .. " couldn't be made.")
			end
		end
	end
end

-- Update --------------------------------------------------------------------

local showFlyout

local function update(level)
	if InCombatLockdown() then
		updatePending = true
		return
	end
	updatePending = false

	level = level or UnitLevel("player")
	local incomplete = scan()
	local hasMana = UnitPowerMax("player", Enum.PowerType.Mana) > 0
	chosen.food = choose("food", level)
	chosen.drink = hasMana and choose("drink", level) or nil
	restock.food = choose("food", level, conjures("food") and "only" or "skip")
	restock.drink = hasMana and choose("drink", level, conjures("drink") and "only" or "skip") or nil
	buttons.drink:SetShown(hasMana)

	local both = {}
	for kind, button in pairs(buttons) do
		local entry = chosen[kind]
		local use = entry and "/use item:" .. entry.id or ""
		-- shift is for dragging, don't eat on shift-click
		button:SetAttribute("macrotext", entry and "/stopmacro [mod:shift]\n" .. use or "")
		keyButtons[kind]:SetAttribute("macrotext", use)
		if entry then
			both[#both + 1] = use
		end
		button.icon:SetTexture(entry and entry.icon or "Interface\\Icons\\" .. PLACEHOLDER[kind])
		button.icon:SetDesaturated(not entry)
		button.count:SetText(entry and entry.count or "")
	end
	combined:SetAttribute("macrotext", table.concat(both, "\n"))
	anchor:SetShown(SnackCheckDB.showButtons)
	syncMacros(hasMana)

	-- bags can look empty or half loaded right after login, which would warn
	-- "out of food" for nothing
	if stockReady and not incomplete then
		checkAllStock(hasMana)
	end

	if flyout:IsShown() then
		showFlyout(flyout.owner)
	end

	if incomplete then
		anchor:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	else
		anchor:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
	end
end

-- Pick list -----------------------------------------------------------------

local function togglePin(entry)
	local kind = flyout.owner.kind
	if SnackCheckCharDB[kind] == entry.id then
		SnackCheckCharDB[kind] = nil
	else
		SnackCheckCharDB[kind] = entry.id
	end
	update()
end

local function createFlyoutButton(index)
	-- the action bar template gives us the same frame, icon and count as the bars
	local button = CreateFrame("Button", nil, flyout, "ActionButtonTemplate")
	button.count = button.Count
	button.pinned = button:CreateTexture(nil, "OVERLAY")
	button.pinned:SetTexture("Interface\\Buttons\\CheckButtonHilight")
	button.pinned:SetBlendMode("ADD")
	button.pinned:SetAllPoints()

	button:SetScript("OnClick", function(self)
		togglePin(self.entry)
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetItemByID(self.entry.id)
		if SnackCheckCharDB[flyout.owner.kind] == self.entry.id then
			GameTooltip:AddLine("Click to go back to picking automatically", 0.4, 0.8, 1)
		else
			GameTooltip:AddLine("Click to always use this one", 0.4, 0.8, 1)
		end
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)

	flyout.buttons[index] = button
	return button
end

function showFlyout(owner)
	if InCombatLockdown() then return end
	local list = items[owner.kind]
	local pinned = SnackCheckCharDB[owner.kind]
	local level = UnitLevel("player")
	flyout.owner = owner

	for i, entry in ipairs(list) do
		local button = flyout.buttons[i] or createFlyoutButton(i)
		local offset = spacing + (i - 1) * (buttonSize + spacing)
		button:SetSize(buttonSize, buttonSize)
		button:ClearAllPoints()
		if vertical then
			button:SetPoint("LEFT", offset, 0)
		else
			button:SetPoint("BOTTOM", 0, offset)
		end
		button.count:SetFont(COUNT_FONT, countSize, COUNT_FLAGS)
		button.entry = entry
		button.icon:SetTexture(entry.icon)
		button.icon:SetDesaturated(entry.minLevel > level)
		button.count:SetText(entry.count)
		button.pinned:SetShown(entry.id == pinned)
		button:Show()
	end
	for i = #list + 1, #flyout.buttons do
		flyout.buttons[i]:Hide()
	end

	-- when stacked, open sideways so we don't cover the other button
	local length = #list * (buttonSize + spacing) + spacing
	flyout:ClearAllPoints()
	if vertical then
		flyout:SetPoint("LEFT", owner, "RIGHT")
		flyout:SetSize(length, buttonSize)
	else
		flyout:SetPoint("BOTTOM", owner, "TOP")
		flyout:SetSize(buttonSize, length)
	end
	flyout:SetShown(#list > 0)
end

-- the list touches the button so the mouse can move between them
flyout:SetScript("OnUpdate", function(self)
	if not self:IsMouseOver() and not self.owner:IsMouseOver() then
		self:Hide()
	end
end)

-- Buttons -------------------------------------------------------------------

local function savePosition()
	local point, _, relativePoint, x, y = anchor:GetPoint()
	SnackCheckDB.position = { point, relativePoint, x, y }
end

local function restorePosition()
	local pos = SnackCheckDB.position
	anchor:ClearAllPoints()
	if pos then
		anchor:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
	else
		anchor:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
	end
end

local function createButton(kind, name, label)
	local button = CreateFrame("Button", name, anchor, "SecureActionButtonTemplate")
	button.kind = kind
	-- the action bar look sits on top as its own frame. putting that template
	-- on the secure button itself replaces the secure click and nothing gets
	-- eaten. mouse is off so clicks fall through to the button underneath
	local look = CreateFrame("Button", nil, button, "ActionButtonTemplate")
	look:SetAllPoints()
	look:EnableMouse(false)
	button.look = look
	button.icon = look.icon
	button.count = look.Count
	button:SetAttribute("type", "macro")
	button:RegisterForClicks("AnyUp", "AnyDown")
	button:RegisterForDrag("LeftButton")

	button:SetScript("OnDragStart", function()
		if IsShiftKeyDown() and not InCombatLockdown() then
			flyout:Hide()
			anchor:StartMoving()
		end
	end)
	button:SetScript("OnDragStop", function()
		anchor:StopMovingOrSizing()
		savePosition()
	end)

	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(label)
		local entry = chosen[kind]
		if entry then
			GameTooltip:AddLine(entry.name, 1, 1, 1)
		else
			GameTooltip:AddLine("Nothing usable in your bags", 1, 0.3, 0.3)
		end
		GameTooltip:AddLine("Pick a different one from the list", 0.6, 0.6, 0.6)
		GameTooltip:AddLine("Shift-drag to move", 0.6, 0.6, 0.6)
		GameTooltip:Show()
		self.look:LockHighlight()
		showFlyout(self)
	end)
	button:SetScript("OnLeave", function(self)
		GameTooltip_Hide()
		self.look:UnlockHighlight()
	end)

	buttons[kind] = button
	return button
end

local eat = createButton("food", "SnackCheckEatButton", "Eat")
local drink = createButton("drink", "SnackCheckDrinkButton", "Drink")

local function layout()
	eat:SetSize(buttonSize, buttonSize)
	drink:SetSize(buttonSize, buttonSize)
	eat:ClearAllPoints()
	drink:ClearAllPoints()
	if vertical then
		anchor:SetSize(buttonSize, buttonSize * 2 + spacing)
		eat:SetPoint("TOP")
		drink:SetPoint("TOP", eat, "BOTTOM", 0, -spacing)
	else
		anchor:SetSize(buttonSize * 2 + spacing, buttonSize)
		eat:SetPoint("LEFT")
		drink:SetPoint("LEFT", eat, "RIGHT", spacing, 0)
	end
	eat.count:SetFont(COUNT_FONT, countSize, COUNT_FLAGS)
	drink.count:SetFont(COUNT_FONT, countSize, COUNT_FLAGS)
end

-- own size, or a copy of the main action bar scaled to us. a vertical bar
-- has its gap on the other axis
local layoutPending = false
local function applyLayout()
	if InCombatLockdown() then
		layoutPending = true
		return
	end
	layoutPending = false

	local settings = SnackCheckDB.layout
	vertical = settings.vertical or false
	countSize = settings.countSize or DEFAULT_COUNT_SIZE
	local first, second = ActionButton1, ActionButton2
	if not settings.matchBar then
		buttonSize, spacing = settings.size, settings.spacing
	elseif first and second and first:GetLeft() and second:GetLeft() then
		local scale = first:GetEffectiveScale() / anchor:GetEffectiveScale()
		local gap = second:GetLeft() - first:GetRight()
		if gap < 0 then
			gap = first:GetBottom() - second:GetTop()
		end
		buttonSize = first:GetWidth() * scale
		spacing = math.max(gap, 0) * scale
	end
	layout()
	if flyout:IsShown() then
		showFlyout(flyout.owner)
	end
end

layout()

-- Events --------------------------------------------------------------------

anchor:RegisterEvent("PLAYER_LOGIN")
anchor:RegisterEvent("PLAYER_ENTERING_WORLD")
anchor:RegisterEvent("BAG_UPDATE_DELAYED")
anchor:RegisterEvent("PLAYER_LEVEL_UP")
anchor:RegisterEvent("PLAYER_REGEN_DISABLED")
anchor:RegisterEvent("PLAYER_REGEN_ENABLED")

anchor:SetScript("OnEvent", function(_, event, arg1)
	if event == "PLAYER_LOGIN" then
		SnackCheckDB = SnackCheckDB or {}
		SnackCheckCharDB = SnackCheckCharDB or {}
		SnackCheckDB.thresholds = SnackCheckDB.thresholds or { food = 10, drink = 10 }
		SnackCheckDB.alerts = SnackCheckDB.alerts or { chat = true, screen = true }
		if SnackCheckDB.alerts.login == nil then
			SnackCheckDB.alerts.login = true
		end
		if SnackCheckDB.showButtons == nil then
			SnackCheckDB.showButtons = true
		end
		SnackCheckDB.layout = SnackCheckDB.layout or { matchBar = true, size = 45, spacing = 6 }
		restorePosition()
		update()
	elseif event == "PLAYER_ENTERING_WORLD" then
		-- give the action bars a frame to load their layout
		C_Timer.After(0, applyLayout)
		if not macrosReady then
			macrosReady = true
			update()
			C_Timer.After(STOCK_DELAY, function()
				stockReady = true
				update()
			end)
		end
	elseif event == "PLAYER_LEVEL_UP" then
		-- UnitLevel lags behind this event, use the arg
		update(arg1)
	elseif event == "PLAYER_REGEN_DISABLED" then
		-- last chance before combat locks it
		flyout:Hide()
	elseif event == "PLAYER_REGEN_ENABLED" then
		if updatePending then update() end
		if layoutPending then applyLayout() end
	else
		update()
	end
end)

-- Options panel -------------------------------------------------------------

-- start hidden! if it's visible at login the edit boxes grab the keyboard and
-- escape stops opening the game menu
local panel = CreateFrame("Frame")
panel:Hide()

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Snack Check")

-- two columns. labels at x, controls at x + CONTROL, y is the middle of the row
local LEFT, RIGHT = 16, 330
local CONTROL = 130
-- leaves room for a hint that wraps onto two lines
local ROWS_TOP = { -112, -142, -172, -202, -232, -262 }
local ROWS_BOTTOM = { -358, -388, -418 }

local function section(x, y, heading, hintText)
	local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	header:SetPoint("TOPLEFT", x, y)
	header:SetText(heading)

	local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	hint:SetPoint("TOPLEFT", x, y - 18)
	hint:SetWidth(290)
	hint:SetJustifyH("LEFT")
	hint:SetText(hintText)
end

local function rowLabel(x, y, text)
	local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("LEFT", panel, "TOPLEFT", x, y)
	label:SetText(text)
end

local numberBoxes = {}

-- click = 1, shift-click = 5, hold to keep going
local REPEAT_DELAY, REPEAT_RATE = 0.4, 0.08

local function createArrow(texture, direction, step)
	local arrow = CreateFrame("Button", nil, panel)
	arrow:SetSize(24, 24)
	arrow:SetNormalTexture(texture .. "-Up")
	arrow:SetPushedTexture(texture .. "-Down")
	arrow:SetDisabledTexture(texture .. "-Disabled")
	arrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

	local function stepOnce()
		step(direction * (IsShiftKeyDown() and 5 or 1))
	end
	local function stop(self)
		self:SetScript("OnUpdate", nil)
	end

	arrow:SetScript("OnMouseDown", function(self, mouse)
		if mouse ~= "LeftButton" or not self:IsEnabled() then return end
		stepOnce()
		self.wait = REPEAT_DELAY
		self:SetScript("OnUpdate", function(_, elapsed)
			self.wait = self.wait - elapsed
			if self.wait <= 0 then
				self.wait = REPEAT_RATE
				stepOnce()
			end
		end)
	end)
	arrow:SetScript("OnMouseUp", stop)
	arrow:SetScript("OnHide", stop)
	return arrow
end

local function setBoxEnabled(box, enabled)
	box:SetEnabled(enabled)
	box.down:SetEnabled(enabled)
	box.up:SetEnabled(enabled)
end

local function createNumberBox(x, y, label, min, max, get, set)
	rowLabel(x, y, label)

	-- the template's border sticks out on the left
	local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
	box:SetSize(50, 20)
	box:SetPoint("LEFT", panel, "TOPLEFT", x + CONTROL + 6, y)
	box:SetAutoFocus(false)
	box:SetNumeric(true)
	box:SetMaxLetters(3)
	box.get = get

	-- empty box keeps the old value, anything else gets clamped
	box:SetScript("OnEditFocusLost", function(self)
		local n = tonumber(self:GetText())
		if n then
			set(math.min(math.max(n, min), max))
		end
		self:SetText(get())
	end)
	box:SetScript("OnEnterPressed", box.ClearFocus)
	box:SetScript("OnEscapePressed", function(self)
		self:SetText(get())
		self:ClearFocus()
	end)

	local function step(delta)
		set(math.min(math.max(get() + delta, min), max))
		box:SetText(get())
	end
	box.down = createArrow("Interface\\Buttons\\UI-SpellbookIcon-PrevPage", -1, step)
	box.down:SetPoint("LEFT", box, "RIGHT", 4, 0)
	box.up = createArrow("Interface\\Buttons\\UI-SpellbookIcon-NextPage", 1, step)
	box.up:SetPoint("LEFT", box.down, "RIGHT", 0, 0)

	numberBoxes[#numberBoxes + 1] = box
	return box
end

local toggles = {}

local function createToggle(x, y, label, get, set)
	rowLabel(x, y, label)

	-- checkbox art has some padding on the left
	local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	check:SetPoint("LEFT", panel, "TOPLEFT", x + CONTROL - 4, y)
	check.get = get
	check:SetScript("OnClick", function(self)
		set(self:GetChecked())
	end)
	toggles[#toggles + 1] = check
	return check
end

-- Warnings
section(LEFT, -56, "Warnings", "Warn me below this many. 0 turns it off; running out always warns.")
createNumberBox(LEFT, ROWS_TOP[1], "Food", 0, 999,
	function() return SnackCheckDB.thresholds.food end,
	function(n) SnackCheckDB.thresholds.food = n end)
createNumberBox(LEFT, ROWS_TOP[2], "Drink", 0, 999,
	function() return SnackCheckDB.thresholds.drink end,
	function(n) SnackCheckDB.thresholds.drink = n end)
createToggle(LEFT, ROWS_TOP[3], "Show in chat",
	function() return SnackCheckDB.alerts.chat end,
	function(on) SnackCheckDB.alerts.chat = on end)
createToggle(LEFT, ROWS_TOP[4], "Show on screen",
	function() return SnackCheckDB.alerts.screen end,
	function(on) SnackCheckDB.alerts.screen = on end)
createToggle(LEFT, ROWS_TOP[5], "Remind at login",
	function() return SnackCheckDB.alerts.login end,
	function(on) SnackCheckDB.alerts.login = on end)

-- Buttons
section(RIGHT, -56, "Buttons", "Untick \"Match action bar\" to pick your own size.")
local sizeBox, spacingBox

local function refreshLayoutBoxes()
	local custom = not SnackCheckDB.layout.matchBar
	setBoxEnabled(sizeBox, custom)
	setBoxEnabled(spacingBox, custom)
	sizeBox:SetText(SnackCheckDB.layout.size)
	spacingBox:SetText(SnackCheckDB.layout.spacing)
end

-- start the boxes at the current size so nothing jumps
createToggle(RIGHT, ROWS_TOP[1], "Match action bar",
	function() return SnackCheckDB.layout.matchBar end,
	function(on)
		SnackCheckDB.layout.matchBar = on
		if not on then
			SnackCheckDB.layout.size = math.floor(buttonSize + 0.5)
			SnackCheckDB.layout.spacing = math.floor(spacing + 0.5)
		end
		applyLayout()
		refreshLayoutBoxes()
	end)
sizeBox = createNumberBox(RIGHT, ROWS_TOP[2], "Button size", 16, 80,
	function() return SnackCheckDB.layout.size end,
	function(n)
		SnackCheckDB.layout.size = n
		applyLayout()
	end)
spacingBox = createNumberBox(RIGHT, ROWS_TOP[3], "Spacing", 0, 30,
	function() return SnackCheckDB.layout.spacing end,
	function(n)
		SnackCheckDB.layout.spacing = n
		applyLayout()
	end)
createToggle(RIGHT, ROWS_TOP[4], "Stack vertically",
	function() return SnackCheckDB.layout.vertical end,
	function(on)
		SnackCheckDB.layout.vertical = on
		applyLayout()
	end)
createNumberBox(RIGHT, ROWS_TOP[5], "Count size", 6, 30,
	function() return SnackCheckDB.layout.countSize or DEFAULT_COUNT_SIZE end,
	function(n)
		SnackCheckDB.layout.countSize = n
		applyLayout()
	end)
createToggle(RIGHT, ROWS_TOP[6], "Show buttons",
	function() return SnackCheckDB.showButtons end,
	function(on)
		SnackCheckDB.showButtons = on
		update()
	end)

local MODIFIER_KEYS = {
	LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
	LMETA = true, RMETA = true,
}

-- META is the Mac cmd key. use Blizzard's chord builder when it's there so the
-- modifier order matches the keybindings screen
local function keyChord(key)
	if CreateKeyChordStringUsingMetaKeyState then
		return CreateKeyChordStringUsingMetaKeyState(key)
	end
	return (IsAltKeyDown() and "ALT-" or "")
		.. (IsControlKeyDown() and "CTRL-" or "")
		.. (IsShiftKeyDown() and "SHIFT-" or "")
		.. (IsMetaKeyDown and IsMetaKeyDown() and "META-" or "")
		.. key
end

local function createBindButton(x, y, label, command)
	rowLabel(x, y, label)

	local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	button:SetSize(140, 22)
	button:SetPoint("LEFT", panel, "TOPLEFT", x + CONTROL, y)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	function button:Refresh()
		local key = GetBindingKey(command)
		self:SetText(key and GetBindingText(key) or "Not bound")
	end

	local function stopListening()
		button.listening = false
		button:EnableKeyboard(false)
		button:Refresh()
	end

	local function clear()
		for _, key in ipairs({ GetBindingKey(command) }) do
			SetBinding(key)
		end
	end

	button:SetScript("OnClick", function(self, mouse)
		-- can't change bindings in combat
		if InCombatLockdown() then return end
		if mouse == "RightButton" then
			clear()
			SaveBindings(GetCurrentBindingSet())
			stopListening()
		else
			self.listening = true
			self:EnableKeyboard(true)
			self:SetText("Press a key...")
		end
	end)

	button:SetScript("OnKeyDown", function(self, key)
		if not self.listening then
			stopListening()
			return
		end
		if MODIFIER_KEYS[key] then return end
		if key == "ESCAPE" or InCombatLockdown() then
			stopListening()
			return
		end

		local combo = keyChord(key)
		local previous = GetBindingAction(combo)
		if previous ~= "" and previous ~= command then
			print(("|cffffd200Snack Check|r: %s was bound to %s. That binding is gone now."):format(
				GetBindingText(combo), _G["BINDING_NAME_" .. previous] or previous))
		end

		clear()
		SetBinding(combo, command)
		SaveBindings(GetCurrentBindingSet())
		stopListening()
	end)

	button:SetScript("OnHide", stopListening)
	-- setting OnKeyDown turns the keyboard on, only a click should
	button:EnableKeyboard(false)
	return button
end

-- Key bindings
section(LEFT, -302, "Key bindings", "Click a button, then press a key. Right-click to clear.")
local bindButtons = {
	createBindButton(LEFT, ROWS_BOTTOM[1], "Eat", BIND_EAT),
	createBindButton(LEFT, ROWS_BOTTOM[2], "Drink", BIND_DRINK),
	createBindButton(LEFT, ROWS_BOTTOM[3], "Eat & drink", BIND_BOTH),
}

-- Action bar macros
section(RIGHT, -302, "Action bar macros", "SC Eat, SC Drink and SC Eat+Drink. Unticking deletes them.")
createToggle(RIGHT, ROWS_BOTTOM[1], "Make macros",
	function() return SnackCheckDB.macros end,
	function(on)
		SnackCheckDB.macros = on
		update()
	end)
rowLabel(RIGHT, ROWS_BOTTOM[2], "Put on a bar")

-- puts the macro on the cursor and closes options so you can reach the bars
local PICKUP_LABELS = { "Eat", "Drink", "Both" }
for i, macro in ipairs(MACROS) do
	local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	button:SetSize(56, 22)
	button:SetText(PICKUP_LABELS[i])
	button:SetPoint("LEFT", panel, "TOPLEFT", RIGHT + CONTROL + (i - 1) * 60, ROWS_BOTTOM[2])
	button:SetScript("OnClick", function()
		local index = GetMacroIndexByName(macro.name)
		if index > 0 and not InCombatLockdown() then
			PickupMacro(index)
			HideUIPanel(SettingsPanel)
		elseif index == 0 then
			print("|cffffd200Snack Check|r: tick \"Make macros\" first.")
		end
	end)
end

panel:SetScript("OnShow", function()
	for _, box in ipairs(numberBoxes) do
		box:SetText(box.get())
	end
	refreshLayoutBoxes()
	for _, check in ipairs(toggles) do
		check:SetChecked(check.get())
	end
	for _, button in ipairs(bindButtons) do
		button:Refresh()
	end
end)

local category = Settings.RegisterCanvasLayoutCategory(panel, "Snack Check")
Settings.RegisterAddOnCategory(category)

-- Slash commands ------------------------------------------------------------

SLASH_SNACKCHECK1 = "/snack"
SLASH_SNACKCHECK2 = "/food"
SlashCmdList.SNACKCHECK = function(msg)
	if msg:lower() == "reset" then
		if not InCombatLockdown() then
			SnackCheckDB.position = nil
			restorePosition()
		end
	else
		Settings.OpenToCategory(category:GetID())
	end
end

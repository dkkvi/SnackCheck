local _, addon = ...

-- spell names cover every rank and come from the client for other languages
local SPELLS = {
	[433] = { food = true }, -- Food
	[430] = { drink = true }, -- Drink
	[1248380] = { food = true, buff = true }, -- Nutritious Food
	[1249914] = { drink = true, buff = true }, -- Nutritious Drink
}

-- Senggin Root shares the Food name but restores mana too, so match these by ID
local SPECIAL_SPELLS = {
	[2639] = { food = true, drink = true }, -- Senggin Root
	[833] = { drink = true }, -- Green Tea (the healing is instant)
	[18124] = { food = true, buff = true }, -- Blessed Sunfruit
	[21149] = { food = true, buff = true }, -- Egg Nog
	[1226814] = { food = true, drink = true }, -- Enriched Manna Biscuit
	[23692] = { food = true, drink = true }, -- Alterac Manna Biscuit
	[24384] = { food = true, drink = true }, -- Essence Mango
	[25990] = { food = true, drink = true }, -- Graccu's Mince Meat Fruitcake
	[29055] = { food = true, drink = true }, -- Refreshing Red Apple
	[1269354] = { food = true, drink = true }, -- Ketharas' Hyjal Stew
	[1312719] = { food = true, drink = true }, -- Restorative Bread
}

local byName = {}

-- buff IDs and the use spells that grant them
local BUFF_SPELLS = {
	[19705] = { 5004, 21149 },
	[19708] = { 5006 },
	[19710] = { 10256 },
	[18125] = { 18124 }, -- Blessed Sunfruit
	[24870] = { 24869 },
	[25661] = { 25660 },
	[1225779] = { 1225771 },
	[1248406] = { 1248377, 1248381, 1248386, 1248390, 1248394, 1248398 }, -- Stamina
	[1248420] = { 1248378, 1248382, 1248387, 1248391, 1248395, 1248399 }, -- Agility
	[1248421] = { 1248379, 1248383, 1248388, 1248392, 1248396, 1248400 }, -- Intellect
	[1248422] = { 1248380, 1248384, 1248389, 1248393, 1248397, 1248401 }, -- Strength
	[1248688] = { 1248687 }, -- Westfall movement speed
	[1249519] = { 1249500, 1249503, 1249506, 1249509, 1249512, 1249515 }, -- Attack Power
	[1249520] = { 1249501, 1249504, 1249507, 1249510, 1249513, 1249516 }, -- Spell Damage
	[1249521] = { 1249502, 1249505, 1249508, 1249511, 1249514 }, -- Fishing
	[1249523] = { 1249522 }, -- Critical Strike
	[1249907] = { 1249906 }, -- Herbalism
	[1249926] = { 1249914, 1249915, 1249916, 1249917, 1249918, 1249919 }, -- Spirit
	[1249927] = { 1249920, 1249921, 1249922, 1249923, 1249924, 1249925 }, -- Healing Power
	[1294007] = { 1294006 }, -- Hyjal movement speed
	[1319310] = { 1319311 }, -- Armor
}

local buffBySpell = {}
for buffID, spells in pairs(BUFF_SPELLS) do
	for _, spellID in ipairs(spells) do buffBySpell[spellID] = buffID end
end

function addon.GetConsumableBuff(spellID)
	return buffBySpell[spellID]
end

function addon.GetConsumableSpell(spellName, spellID)
	local known = SPECIAL_SPELLS[spellID] or SPELLS[spellID] or byName[spellName]
	if known then return known end
	-- get localized names, and retry any that weren't loaded yet
	for id, flags in pairs(SPELLS) do
		local name = C_Spell.GetSpellName(id)
		if name then byName[name] = flags end
	end
	return byName[spellName]
end

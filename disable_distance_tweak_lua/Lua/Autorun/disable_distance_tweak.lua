if CLIENT then return end

local DISABLE_DISTANCE_FACTOR = 4.0		-- 1.0 is default (the bigger, the closer)
local MIN_DISTANCE_TO_CHANGE = 50000.0	-- min distance to change, 25000.0 is default for most characters
local MIN_DISTANCE = 8000.0				-- min available distance, 8000.0 is default for most spawn events

local BlacklistCharacters = {
	["Jove"] = true,
	["Latcher"] = true,
	["Charybdis"] = true,
	["Endworm"] = true,
	["Hammerhead"] = true,
	["Hammerheadgold"] = true,
	["Hammerheadmatriarch"] = true
}

Hook.Add("character.created", "tweak disable distance",
function(character)
	if not BlacklistCharacters[character.Params.SpeciesName] and not character.IsOnPlayerTeam and character.Params.DisableDistance <= MIN_DISTANCE_TO_CHANGE then
		character.Params.DisableDistance = math.min(math.max(MIN_DISTANCE, character.Params.DisableDistance/DISABLE_DISTANCE_FACTOR), character.Params.DisableDistance)
	end
end)
if CLIENT and Game.IsMultiplayer then return end 

IDs = {}

local afflictionStates = {}
local needsEnforcer = ItemPrefab.GetItemPrefab("needsenforcer")
local lastUpdateTime = 0
Hook.Add("think", "hungryeuropan_think", function()
    if Game.Paused or not Game.RoundStarted or Timer.GetTime() < lastUpdateTime + 1 then return end

    for character in Character.CharacterList do
        if character ~= nil and character.IsPlayer and not character.HasTalents("he-hungryeuropan") then
            Entity.Spawner.AddItemToSpawnQueue(needsEnforcer, character.Inventory)
        elseif character ~= nil and character.IsPlayer then
            UpdateAfflictions(character)
        elseif character ~= nil and character.IsBot then
            RemoveAfflictions(character)
        end
    end

    lastUpdateTime = Timer.GetTime()
end)

function UpdateAfflictions(character)
    if afflictionStates[character] then
        for affliction in afflictionStates[character] do
            character.CharacterHealth.ApplyAffliction(character.AnimController.MainLimb, affliction, true)
        end
        afflictionStates[character] = nil
    end
end

function RemoveAfflictions(character)
    local currentHungerAffliction = character.CharacterHealth.GetAffliction("hunger", false)
    local currentThirstAffliction = character.CharacterHealth.GetAffliction("thirst", false)

    if afflictionStates[character] == nil then
        afflictionStates[character] = {}

        if currentHungerAffliction then
            local hungerPrefab = AfflictionPrefab.Prefabs["hunger"]
            local newHungerAffliction = hungerPrefab.Instantiate(currentHungerAffliction.Strength)
            table.insert(afflictionStates[character], newHungerAffliction)
        end
        
        if currentThirstAffliction then
            local thirstPrefab = AfflictionPrefab.Prefabs["thirst"]
            local newThirstAffliction = thirstPrefab.Instantiate(currentThirstAffliction.Strength)
            table.insert(afflictionStates[character], newThirstAffliction)
        end
    end
    
    if currentHungerAffliction then
        currentHungerAffliction.Strength = 0
    end
    if currentThirstAffliction then
        currentThirstAffliction.Strength = 0
    end
end



if CLIENT and Game.IsMultiplayer then return end -- lets this run if on the server-side, if it's multiplayer, doesn't let it run on the client, and if it's singleplayer, lets it run on the client.

--Timer.Wait(function() 

print("")
IDs = {}

local extraneedsenforcer = ItemPrefab.GetItemPrefab("extraneedsenforcer")

Hook.Add("character.giveJobItems", "filthyeuropan", function(character, waypoint)
if character.HasTalents() == false then
print("")
	Entity.Spawner.AddItemToSpawnQueue(extraneedsenforcer, character.Inventory, nil, nil, function(item)
	end)
end

    
end)








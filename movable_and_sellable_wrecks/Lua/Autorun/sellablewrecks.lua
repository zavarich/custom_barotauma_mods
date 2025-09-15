if Game.IsMultiplayer and CLIENT then return end

LuaUserData.RegisterType("Barotrauma.CampaignSettings")

local sellText = TextManager.Get("SellWreck")
local sellTextColor = Color(255, 255, 100, 255)

local function FindPriceTag(tags)
    local price = ""

    local startPos, endPos = tags:find("price:")

    if endPos == nil then return "" end

    for i = endPos + 1, #tags, 1 do
        local c = tags:sub(i, i)

        if c == "," then break end
        price = price .. c
    end

    return price
end

function GetSubmarinePrice(sub)
    for key, value in pairs(sub.GetItems(false)) do
        local price = FindPriceTag(value.Tags)
        if price ~= "" then
            return tonumber(price)
        end
    end

    return sub.CalculateBasePrice()
end

local wrecksMarkedForSelling = {}

Hook.Add("think", "checkForWrecksSell", function()
    if Level.Loaded == nil then return end
    if Level.Loaded.Wrecks == nil then return end

    for key, value in pairs(Level.Loaded.Wrecks) do
        if Level.Loaded.IsCloseToEnd(value.WorldPosition, 6000) then
            if not wrecksMarkedForSelling[value] then

                local price = (GetSubmarinePrice(value)*Game.GameSession.Campaign.Settings.ShipyardPriceMultiplier)
                local EXPmulti = math.floor(price * (Level.Loaded.Difficulty/55))

                if SERVER then
                    for _, client in pairs(Client.ClientList) do
                        local chatMessage = ChatMessage.Create("", string.format(sellText.Value, value.Info.Name, price, EXPmulti)
                            , ChatMessageType.Default, nil)
                        chatMessage.Color = sellTextColor

                        Game.SendDirectChatMessage(chatMessage, client)
                    end
                else
                    local chatMessage = ChatMessage.Create("", string.format(sellText.Value, value.Info.Name, price, EXPmulti),
                        ChatMessageType.Default, nil)
                    chatMessage.Color = sellTextColor

                    Game.ChatBox.AddMessage(chatMessage)
                end

                wrecksMarkedForSelling[value] = price
            end
        end
    end
end)

local function GiveWreckEXP(amount)
    for k, v in pairs(Character.CharacterList) do
        if v.IsHuman and not v.IsDead and v.IsOnPlayerTeam or v.SpeciesName == "Mudraptor_player" or v.SpeciesName == "Psilotoad_player" then
            v.Info.GiveExperience(amount, true)
        end
    end
end

Hook.Add("roundEnd", "sellWrecks", function()
    if Game.GameSession.Campaign == nil then return end

    local toSell = wrecksMarkedForSelling

    Timer.Wait(function()
        for key, value in pairs(toSell) do
            Game.GameSession.Campaign.Bank.Give(value)
        end
    end, 5000)

	for key, value in pairs(toSell) do
		local EXPmulti = Level.Loaded.Difficulty / 55
		GiveWreckEXP(value * EXPmulti)
		print(GiveWreckEXP)
	end


    wrecksMarkedForSelling = {}
end)
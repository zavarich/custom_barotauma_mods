EditGUI = {}
EditGUI.Path = ...

if not File.Exists(EditGUI.Path .. "/settings.json") then
	File.Write(EditGUI.Path .. "/settings.json", json.serialize(dofile(EditGUI.Path .. "/Lua/defaultsettings.lua")))
end
EditGUI.Settings = json.parse(File.Read(EditGUI.Path .. "/settings.json"))

if not SERVER then
	if not File.Exists(EditGUI.Path .. "/clientsidesettings.json") then
		File.Write(EditGUI.Path .. "/clientsidesettings.json", json.serialize(dofile(EditGUI.Path .. "/Lua/defaultclientsidesettings.lua")))
	end
	EditGUI.ClientsideSettings = json.parse(File.Read(EditGUI.Path .. "/clientsidesettings.json"))
end

local network = dofile(EditGUI.Path .. "/Lua/networking.lua")
local findtarget = dofile(EditGUI.Path .. "/Lua/findtarget.lua")
	
LinkAdd = function(itemedit1, itemedit2)
    itemedit1.AddLinked(itemedit2)
    itemedit2.AddLinked(itemedit1)
end

LinkRemove = function(itemedit1, itemedit2)
    itemedit1.RemoveLinked(itemedit2)
    itemedit2.RemoveLinked(itemedit1)
end

if SERVER then
	return
end

local check = true

local FindClientCharacter = function(character)  
    for key, value in pairs(Client.ClientList) do
        if value.Character == character then
            return value
        end
    end
end

EditGUI.AddMessage = function(text, client)
   message = ChatMessage.Create("Lua Editor", text, ChatMessageType.Default, nil, nil)
   message.Color = Color(255, 95, 31)

   if CLIENT then
       Game.ChatBox.AddMessage(message)
   else
       Game.SendDirectChatMessage(message, client)
   end
end


	frame = GUI.Frame(GUI.RectTransform(Vector2(1, 1)), nil)
	frame.CanBeFocused = false

	-- Attribute Draw Functions Start --
	local DrawRequiredItems = function(component, key, list, height, relatedItemType, fieldName, optional, msgTag)
		optional = optional or false
		local relatedItemClass = LuaUserData.CreateStatic("Barotrauma.RelatedItem")
		
		local requireditemslayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, height), list.Content.RectTransform), nil)
		requireditemslayout.isHorizontal = true
		requireditemslayout.Stretch = true
		requireditemslayout.RelativeSpacing = 0.001
	
		local requireditemstextblock = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), requireditemslayout.RectTransform), fieldName, nil, nil, GUI.Alignment.CenterLeft)
		local requireditemstext = GUI.TextBox(GUI.RectTransform(Vector2(0.8, 1), requireditemslayout.RectTransform), "")
		
		local function getRelatedItem()
			local relatedItemsTable = component.requiredItems[relatedItemType]
			
			if relatedItemsTable == nil then
				return nil
			end
			
			return relatedItemsTable[1]
		end
		
		local relatedItem = getRelatedItem()
		local joinedIdentifiers = ""
		if relatedItem ~= nil then
			joinedIdentifiers = relatedItem.JoinedIdentifiers
		end
		requireditemstext.Text = joinedIdentifiers
		
		requireditemstext.OnTextChangedDelegate = function()
			local relatedItem = getRelatedItem()
			joinedIdentifiers = requireditemstext.Text
			
			local shouldRelatedItemExist = joinedIdentifiers ~= ""
			local hasRelatedItem = relatedItem ~= nil
			
			if shouldRelatedItemExist then
				if not hasRelatedItem then
					local msgAttribute = ""
					if msgTag and msgTag:match("^%s*$") == nil then
						msgAttribute = " msg=\"" .. msgTag .."\""
					end
					local requiredItemSampleData = string.format([[<requireditem items="id_captain" type="%s" characterinventoryslottype="None" optional="%s" ignoreineditor="true" excludebroken="true" requireempty="false" excludefullcondition="false" targetslot="-1" allowvariants="true" rotation="0" setactive="false"%s /> 
]], tostring(relatedItemType), tostring(optional), msgAttribute)
					local xml = XDocument.Parse(requiredItemSampleData).Root
					local contentXml = ContentXElement(nil, xml) -- package is nil
					
					relatedItem = relatedItemClass.__new(contentXml, "LuaEditorRequiredItem")
					local tempRequiredItems = component.requiredItems
					tempRequiredItems[relatedItemType] = {relatedItem}
					component.requiredItems = tempRequiredItems
				end
				relatedItem.JoinedIdentifiers = joinedIdentifiers
			else
				if hasRelatedItem then
					-- component.requiredItems = {} -- delete other types
					-- component.requiredItems[relatedItemType] = nil -- doesn't work
					local tempRequiredItems = {}
					for requiredType, requiredTypeItems in pairs(component.requiredItems) do
						if (requiredType ~= relatedItemType) then
							tempRequiredItems[requiredType] = requiredTypeItems
						end
					end
					component.requiredItems = tempRequiredItems
					relatedItem = nil
				end
			end
			
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key ..".RequiredItems", component.requiredItems, "RequiredItems")
			end
		end
	end
	
	local DrawPickedRequired = function(component, key, list, height, optional, msgTag)
		local relatedItemType = LuaUserData.CreateEnumTable("Barotrauma.RelatedItem+RelationType")
		DrawRequiredItems(component, key, list, height, relatedItemType.Picked, "Picked Required", optional, msgTag)
	end
	
	local DrawEquippedRequired = function(component, key, list, height, optional, msgTag)
		local relatedItemType = LuaUserData.CreateEnumTable("Barotrauma.RelatedItem+RelationType")
		DrawRequiredItems(component, key, list, height, relatedItemType.Equipped, "Equipped Required", optional, msgTag)
	end
	-- Attribute Draw Functions End --
	-- Main Component Start --
	local MainComponentfunction = function()
	
		if not menu then
			menu = GUI.Frame(GUI.RectTransform(Vector2(0.55, 1.1), frame.RectTransform, GUI.Anchor.CenterRight), nil)
			menu.CanBeFocused = false
			menu.RectTransform.AbsoluteOffset = Point(0, -40)
		
			menuContent = GUI.Frame(GUI.RectTransform(Vector2(0.45, 0.6), menu.RectTransform, GUI.Anchor.CenterRight))
		end
		
		menuList = GUI.ListBox(GUI.RectTransform(Vector2(0.93, 0.7), menuContent.RectTransform, GUI.Anchor.Center))
		menuList.RectTransform.AbsoluteOffset = Point(0, -17)
	
		itemList = GUI.ListBox(GUI.RectTransform(Vector2(1, 1), menuList.Content.RectTransform, GUI.Anchor.TopCenter))

		itemname = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.1), itemList.Content.RectTransform), "None", nil, nil, GUI.Alignment.Center)
		itemname.TextColor = Color((255), (153), (153))
		itemname.TextScale = 1.3

		if EditGUI.Settings.spritedepth == true then
			local spritedepthlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.07), itemList.Content.RectTransform), nil)
			spritedepthlayout.isHorizontal = true
			spritedepthlayout.Stretch = true
			spritedepthlayout.RelativeSpacing = 0.001

			local spritedepthtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), spritedepthlayout.RectTransform), "Sprite Depth", nil, nil, GUI.Alignment.CenterLeft)
		
			spritedepth = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), spritedepthlayout.RectTransform), NumberType.Float)
			spritedepth.DecimalsToDisplay = 3
			spritedepth.MinValueFloat = 0.001
			spritedepth.MaxValueFloat = 0.999
			spritedepth.valueStep = 0.1
			if itemedit then
				spritedepth.FloatValue = itemedit.SpriteDepth
			end
			spritedepth.OnValueChanged = function ()
				if itemedit then
					itemedit.SpriteDepth = spritedepth.FloatValue
					if Game.IsMultiplayer then
						Update.itemupdatevalue.fn(itemedit.ID, "SpriteDepth", itemedit.SpriteDepth)
					end
				end
			end
		end

		if EditGUI.Settings.rotation == true and targeting == "items" then
			local rotationlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.07), itemList.Content.RectTransform), nil)
			rotationlayout.isHorizontal = true
			rotationlayout.Stretch = true
			rotationlayout.RelativeSpacing = 0.001

			local rotationtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), rotationlayout.RectTransform), "Rotation", nil, nil, GUI.Alignment.CenterLeft)
		
			rotation = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), rotationlayout.RectTransform), NumberType.Int)
			rotation.MinValueInt = 0
			rotation.MaxValueInt = 360
			rotation.valueStep = 10
			if itemedit then
				rotation.IntValue = itemedit.Rotation
			end
			rotation.OnValueChanged = function ()
				if itemedit then
					itemedit.Rotation = rotation.IntValue
					if Game.IsMultiplayer then
						Update.itemupdatevalue.fn(itemedit.ID, "Rotation", itemedit.Rotation)
					end
				end
			end
		end
	
		if EditGUI.Settings.scale == true and targeting == "items" then
			local scalelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.07), itemList.Content.RectTransform), nil)
			scalelayout.isHorizontal = true
			scalelayout.Stretch = true
			scalelayout.RelativeSpacing = 0.001

			local scaletext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), scalelayout.RectTransform), "Scale", nil, nil, GUI.Alignment.CenterLeft)
		
			scale = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), scalelayout.RectTransform), NumberType.Float)
			scale.DecimalsToDisplay = 3
			scale.valueStep = 0.1
			scale.MinValueFloat = EditGUI.Settings.scalemin
			scale.MaxValueFloat = EditGUI.Settings.scalemax
			if itemedit then
				scale.FloatValue = itemedit.Scale
			end
			scale.OnValueChanged = function ()
				if itemedit and scale.FloatValue <= scale.MaxValueFloat and scale.FloatValue >= scale.MinValueFloat then
					itemedit.Scale = scale.FloatValue
					if Game.IsMultiplayer then
						Update.itemupdatevalue.fn(itemedit.ID, "Scale", itemedit.Scale)
					end
				end
			end
		end

		if targeting ~= "items" then
			local rectwidthlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.07), itemList.Content.RectTransform), nil)
			rectwidthlayout.isHorizontal = true
			rectwidthlayout.Stretch = true
			rectwidthlayout.RelativeSpacing = 0.001

			local rectwithtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), rectwidthlayout.RectTransform), "Width", nil, nil, GUI.Alignment.CenterLeft)
		
			rectwidth = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), rectwidthlayout.RectTransform), NumberType.Float)
			rectwidth.DecimalsToDisplay = 3
			rectwidth.valueStep = 0.1
			if itemedit then
				rectwidth.FloatValue = itemedit.RectWidth
			end
			rectwidth.OnValueChanged = function ()
				if itemedit then
					itemedit.RectWidth = rectwidth.FloatValue
					if Game.IsMultiplayer then
						Update.itemupdatevalue.fn(itemedit.ID, "RectWidth", rectwidth.FloatValue)
					end
				end
			end
		end
	
		if targeting ~= "items" then
			local rectheightlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.07), itemList.Content.RectTransform), nil)
			rectheightlayout.isHorizontal = true
			rectheightlayout.Stretch = true
			rectheightlayout.RelativeSpacing = 0.001

			local rectheighttext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), rectheightlayout.RectTransform), "Height", nil, nil, GUI.Alignment.CenterLeft)
		
			rectheight = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), rectheightlayout.RectTransform), NumberType.Float)
			rectheight.DecimalsToDisplay = 3
			rectheight.valueStep = 0.1
			if itemedit then
				rectheight.FloatValue = itemedit.RectHeight
			end
			rectheight.OnValueChanged = function ()
				if itemedit then
					itemedit.RectHeight = rectheight.FloatValue
					if Game.IsMultiplayer then
						Update.itemupdatevalue.fn(itemedit.ID, "RectHeight", rectheight.FloatValue)
					end
				end
			end
		end
	
		if EditGUI.Settings.condition == true and targeting == "items" then
			local conditionlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.07), itemList.Content.RectTransform), nil)
			conditionlayout.isHorizontal = true
			conditionlayout.Stretch = true
			conditionlayout.RelativeSpacing = 0.001


			local conditiontext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), conditionlayout.RectTransform), "Condition", nil, nil, GUI.Alignment.CenterLeft)
		
			condition = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), conditionlayout.RectTransform), NumberType.Float)	
			condition.MinValueFloat = 0
			condition.MaxValueFloat = 100
			condition.valueStep = 1
			if itemedit then
				condition.FloatValue = itemedit.Condition
			end
			condition.OnValueChanged = function ()
				if itemedit then
					itemedit.Condition = condition.FloatValue
					if Game.IsMultiplayer then
						Update.itemupdatevalue.fn(itemedit.ID, "Condition", condition.FloatValue)
					end
				end
			end
		end

		if EditGUI.Settings.spritecolor == true and targeting == "items" or targeting == "walls" then
			local colorlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.075), itemList.Content.RectTransform), nil)
			colorlayout.isHorizontal = true
			colorlayout.Stretch = true
			colorlayout.RelativeSpacing = 0.01
	
			local spritecolortext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), colorlayout.RectTransform), "Sprite Color", nil, nil, GUI.Alignment.CenterLeft)

			local redtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.1, 1), colorlayout.RectTransform), "R", nil, nil, GUI.Alignment.Center)
			red = GUI.NumberInput(GUI.RectTransform(Vector2(0.4, 1), colorlayout.RectTransform), NumberType.Int)
			local greentext = GUI.TextBlock(GUI.RectTransform(Vector2(0.1, 1), colorlayout.RectTransform), "G", nil, nil, GUI.Alignment.Center)
			green = GUI.NumberInput(GUI.RectTransform(Vector2(0.4, 1), colorlayout.RectTransform), NumberType.Int)
			local bluetext = GUI.TextBlock(GUI.RectTransform(Vector2(0.1, 1), colorlayout.RectTransform), "B", nil, nil, GUI.Alignment.Center)
			blue = GUI.NumberInput(GUI.RectTransform(Vector2(0.4, 1), colorlayout.RectTransform), NumberType.Int)
	
			red.MinValueInt = 0
			red.MaxValueInt = 255
			if itemedit then
				red.IntValue = itemedit.SpriteColor.R
			end
			green.MinValueInt = 0
			green.MaxValueInt = 255
			if itemedit then
				green.IntValue = itemedit.SpriteColor.G
			end
			blue.MinValueInt = 0
			blue.MaxValueInt = 255
			if itemedit then
				blue.IntValue = itemedit.SpriteColor.B
			end
		
			if EditGUI.Settings.alpha == true then
				local alphatext = GUI.TextBlock(GUI.RectTransform(Vector2(0.1, 1), colorlayout.RectTransform), "A", nil, nil, GUI.Alignment.Center)
			
				alpha = GUI.NumberInput(GUI.RectTransform(Vector2(0.4, 1), colorlayout.RectTransform), NumberType.Int)
				alpha.MinValueInt = 0
				alpha.MaxValueInt = 255
				if itemedit then
					alpha.IntValue = itemedit.SpriteColor.A
				end
				alpha.OnValueChanged = function ()
					if itemedit and alpha.IntValue <= 255 and alpha.IntValue >= 0 then
						itemedit.SpriteColor = Color(itemedit.SpriteColor.r, itemedit.SpriteColor.g, itemedit.SpriteColor.b, alpha.IntValue)
						if Game.IsMultiplayer then
							Update.itemupdatevalue.fn(itemedit.ID, "SpriteColor", itemedit.SpriteColor, "Color")
						end
					end
				end
			end
		
			red.OnValueChanged = function ()
				if itemedit and red.IntValue <= 255 and red.IntValue >= 0 then
					itemedit.SpriteColor = Color(red.IntValue, itemedit.SpriteColor.g, itemedit.SpriteColor.b, itemedit.SpriteColor.a)
					if Game.IsMultiplayer then
						Update.itemupdatevalue.fn(itemedit.ID, "SpriteColor", itemedit.SpriteColor, "Color")
					end					
				end
			end
			green.OnValueChanged = function ()
				if itemedit and green.IntValue <= 255 and green.IntValue >= 0 then
					itemedit.SpriteColor = Color(itemedit.SpriteColor.r, green.IntValue, itemedit.SpriteColor.b, itemedit.SpriteColor.a)
					if Game.IsMultiplayer then
						Update.itemupdatevalue.fn(itemedit.ID, "SpriteColor", itemedit.SpriteColor, "Color")
					end						
				end
			end
			blue.OnValueChanged = function ()
				if itemedit and blue.IntValue <= 255 and blue.IntValue >= 0 then
					itemedit.SpriteColor = Color(itemedit.SpriteColor.r, itemedit.SpriteColor.g, blue.IntValue, itemedit.SpriteColor.a)		
					if Game.IsMultiplayer then
						Update.itemupdatevalue.fn(itemedit.ID, "SpriteColor", itemedit.SpriteColor, "Color")
					end						
				end
			end
		end
	
		if EditGUI.Settings.tags == true and targeting == "items" then
			local tagslayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.07), itemList.Content.RectTransform), nil)
			tagslayout.isHorizontal = true
			tagslayout.Stretch = true
			tagslayout.RelativeSpacing = 0.001
	
			local tagstextblock = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), tagslayout.RectTransform), "Tags", nil, nil, GUI.Alignment.CenterLeft)
		
			tagstext = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), tagslayout.RectTransform), "")
			if itemedit then
				tagstext.Text = itemedit.Tags
			end
			tagstext.OnTextChangedDelegate = function()
				if itemedit then
					itemedit.Tags = tagstext.Text
					if Game.IsMultiplayer then
						Update.itemupdatevalue.fn(itemedit.ID, "Tags", itemedit.Tags)
					end
				end
			end
		end
	
		if EditGUI.Settings.description == true and targeting == "items" then
			local descriptionlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.07), itemList.Content.RectTransform), nil)
			descriptionlayout.isHorizontal = true
			descriptionlayout.Stretch = true
			descriptionlayout.RelativeSpacing = 0.001

			local descriptiontextblock = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), descriptionlayout.RectTransform), "Description", nil, nil, GUI.Alignment.CenterLeft)
		
			descriptiontext = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 0.1), descriptionlayout.RectTransform), "")
			if itemedit then
				descriptiontext.Text = itemedit.Description
			end
			descriptiontext.OnTextChangedDelegate = function()
				if itemedit then
					itemedit.Description = descriptiontext.Text
					if Game.IsMultiplayer then
						Update.itemupdatevalue.fn(itemedit.ID, "Description", itemedit.Description)
					end
				end
			end
		end
	
		if EditGUI.Settings.noninteractable == true and targeting == "items" then
			noninteractable = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), itemList.Content.RectTransform), "Non Interactable")	
			if itemedit then
				noninteractable.Selected = itemedit.NonInteractable
			end
			noninteractable.OnSelected = function()
				if itemedit then
					itemedit.NonInteractable = noninteractable.Selected == true
					if Game.IsMultiplayer then
						Update.itemupdatevalue.fn(itemedit.ID, "NonInteractable", itemedit.NonInteractable)
					end
				end
			end	
		end
	
		if EditGUI.Settings.nonplayerteaminteractable == true and targeting == "items" then
			nonplayerteaminteractable = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), itemList.Content.RectTransform), "Non-Player Team Interactable")
			if itemedit then
				nonplayerteaminteractable.Selected = itemedit.NonPlayerTeamInteractable
			end
			nonplayerteaminteractable.OnSelected = function()
				if itemedit  then
					itemedit.NonPlayerTeamInteractable = nonplayerteaminteractable.Selected == true
					if Game.IsMultiplayer then
						Update.itemupdatevalue.fn(itemedit.ID, "NonPlayerTeamInteractable", itemedit.NonPlayerTeamInteractable)
					end
				end
			end	
		end
	
		if EditGUI.Settings.invulnerabletodamage == true and targeting == "items" then
			invulnerabletodamage = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), itemList.Content.RectTransform), "Invulnerable to Damage")
			if itemedit then
				invulnerabletodamage.Selected = itemedit.InvulnerableToDamage
			end
			invulnerabletodamage.OnSelected = function()
				if itemedit then
					itemedit.InvulnerableToDamage = invulnerabletodamage.Selected == true
					if Game.IsMultiplayer then
						Update.itemupdatevalue.fn(itemedit.ID, "InvulnerableToDamage", itemedit.InvulnerableToDamage)
					end
				end
			end
		end

		if EditGUI.Settings.displaysidebysidewhenlinked == true and targeting == "items" then
			displaysidebysidewhenlinked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), itemList.Content.RectTransform), "Display Side By Side When Linked")
			if itemedit then
				displaysidebysidewhenlinked.Selected = itemedit.DisplaySideBySideWhenLinked
			end
			displaysidebysidewhenlinked.OnSelected = function()
				if itemedit then
					itemedit.DisplaySideBySideWhenLinked = displaysidebysidewhenlinked.Selected == true
					if Game.IsMultiplayer then
						Update.itemupdatevalue.fn(itemedit.ID, "DisplaySideBySideWhenLinked", itemedit.DisplaySideBySideWhenLinked)
					end
				end
			end
		end

		if EditGUI.Settings.hiddeningame == true and targeting == "items" then
			hiddeningame = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), itemList.Content.RectTransform), "Hidden In Game")	
			if itemedit then
				hiddeningame.Selected = itemedit.HiddenInGame
			end
			hiddeningame.OnSelected = function()
				if itemedit then
					itemedit.HiddenInGame = hiddeningame.Selected == true
					if Game.IsMultiplayer then
						Update.itemupdatevalue.fn(itemedit.ID, "HiddenInGame", itemedit.HiddenInGame)
					end
				end
			end	
		end

		if EditGUI.Settings.mirror == true then
			local mirrorlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.04), itemList.Content.RectTransform), nil)
			mirrorlayout.isHorizontal = true
			mirrorlayout.RelativeSpacing = 0.002

			local mirrorButtonx = GUI.Button(GUI.RectTransform(Vector2(0.499, 0.2), mirrorlayout.RectTransform), "Mirror X", nil, "GUIButtonSmall")
			mirrorButtonx.OnClicked = function()
				if itemedit then
					if CLIENT and Game.IsMultiplayer then
						mirrorx = Networking.Start("flipxnetwork")
						mirrorx.WriteUInt16(UShort(itemedit.ID))
						Networking.Send(mirrorx)
					else
						itemedit.FlipX(false)
					end
				end
			end
		
			local mirrorButtony = GUI.Button(GUI.RectTransform(Vector2(0.499, 0.2), mirrorlayout.RectTransform), "Mirror Y", nil, "GUIButtonSmall")
			mirrorButtony.OnClicked = function()
				if itemedit then
					if CLIENT and Game.IsMultiplayer then
						mirrory = Networking.Start("flipynetwork")
						mirrory.WriteUInt16(UShort(itemedit.ID))
						Networking.Send(mirrory)
					else
						itemedit.FlipY(false)
					end
				end
			end
		end
		
	end
	-- Main Component End --
	-- LightComponent Component Start --
	local LightComponentfunction = function(component, key)

		if EditGUI.Settings.lightcomponent == false then
			return
		end
		
		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 1.2), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.07), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
	
		local rangelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.055), List.Content.RectTransform), nil)
		rangelayout.isHorizontal = true
		rangelayout.Stretch = true
		rangelayout.RelativeSpacing = 0.001
	
		local rangetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), rangelayout.RectTransform), "Range", nil, nil, GUI.Alignment.CenterLeft)
		
		local range = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), rangelayout.RectTransform), NumberType.Float)
		range.FloatValue = component.Range
		range.MinValueFloat = 0
		range.MaxValueFloat = 2048
		range.valueStep = 10
		range.OnValueChanged = function()
			component.Range = range.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Range", component.Range)
			end
		end
		
		local flickerlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.055), List.Content.RectTransform), nil)
		flickerlayout.isHorizontal = true
		flickerlayout.Stretch = true
		flickerlayout.RelativeSpacing = 0.001
	
		local flickertext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), flickerlayout.RectTransform), "Flicker", nil, nil, GUI.Alignment.CenterLeft)
		
		local flicker = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), flickerlayout.RectTransform), NumberType.Float)
		flicker.FloatValue = component.Flicker
		flicker.OnValueChanged = function()
			component.Flicker = flicker.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Flicker", component.Flicker)
			end
		end
	
		local flickerspeedlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.055), List.Content.RectTransform), nil)
		flickerspeedlayout.isHorizontal = true
		flickerspeedlayout.Stretch = true
		flickerspeedlayout.RelativeSpacing = 0.001
	
		local flickerspeedtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), flickerspeedlayout.RectTransform), "Flicker Speed", nil, nil, GUI.Alignment.CenterLeft)
		
		local flickerspeed = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), flickerspeedlayout.RectTransform), NumberType.Float)
		flickerspeed.FloatValue = component.FlickerSpeed
		flickerspeed.OnValueChanged = function()
			component.FlickerSpeed = flickerspeed.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".FlickerSpeed", component.FlickerSpeed)
			end
		end
		
		local pulsefrequencylayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.055), List.Content.RectTransform), nil)
		pulsefrequencylayout.isHorizontal = true
		pulsefrequencylayout.Stretch = true
		pulsefrequencylayout.RelativeSpacing = 0.001
	
		local pulsefrequencytext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pulsefrequencylayout.RectTransform), "Pulse Frequency", nil, nil, GUI.Alignment.CenterLeft)
		
		local pulsefrequency = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pulsefrequencylayout.RectTransform), NumberType.Float)
		pulsefrequency.FloatValue = component.PulseFrequency
		pulsefrequency.OnValueChanged = function()
			component.PulseFrequency = pulsefrequency.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PulseFrequency", component.PulseFrequency)
			end
		end
	
		local pulseamountlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.055), List.Content.RectTransform), nil)
		pulseamountlayout.isHorizontal = true
		pulseamountlayout.Stretch = true
		pulseamountlayout.RelativeSpacing = 0.001
	
		local pulseamounttext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pulseamountlayout.RectTransform), "Pulse Amount", nil, nil, GUI.Alignment.CenterLeft)
		
		local pulseamount = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pulseamountlayout.RectTransform), NumberType.Float)
		pulseamount.DecimalsToDisplay = 2
		pulseamount.FloatValue = component.PulseAmount
		pulseamount.MinValueFloat = 0
		pulseamount.MaxValueFloat = 1
		pulseamount.valueStep = 0.1
		pulseamount.OnValueChanged = function()
			component.PulseAmount = pulseamount.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PulseAmount", component.PulseAmount)
			end
		end
	
		local blinkfrequencylayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.055), List.Content.RectTransform), nil)
		blinkfrequencylayout.isHorizontal = true
		blinkfrequencylayout.Stretch = true
		blinkfrequencylayout.RelativeSpacing = 0.001
	
		local blinkfrequencytext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), blinkfrequencylayout.RectTransform), "Blink Frequency", nil, nil, GUI.Alignment.CenterLeft)
		
		local blinkfrequency = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), blinkfrequencylayout.RectTransform), NumberType.Float)
		blinkfrequency.FloatValue = component.BlinkFrequency
		blinkfrequency.OnValueChanged = function()
			component.BlinkFrequency = blinkfrequency.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".BlinkFrequency", component.BlinkFrequency)
			end
		end
	
		local colorlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.075), List.Content.RectTransform), nil)
		colorlayout.isHorizontal = true
		colorlayout.Stretch = true
		colorlayout.RelativeSpacing = 0.01
	
		local colortext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), colorlayout.RectTransform), "Color", nil, nil, GUI.Alignment.CenterLeft)

		local redtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.1, 1), colorlayout.RectTransform), "R", nil, nil, GUI.Alignment.Center)
		
		local red = GUI.NumberInput(GUI.RectTransform(Vector2(0.4, 1), colorlayout.RectTransform), NumberType.Int)
		red.IntValue = component.lightColor.R
		red.MinValueInt = 0
		red.MaxValueInt = 255
		
		local greentext = GUI.TextBlock(GUI.RectTransform(Vector2(0.1, 1), colorlayout.RectTransform), "G", nil, nil, GUI.Alignment.Center)
		
		local green = GUI.NumberInput(GUI.RectTransform(Vector2(0.4, 1), colorlayout.RectTransform), NumberType.Int)
		green.IntValue = component.lightColor.G
		green.MinValueInt = 0
		green.MaxValueInt = 255
		
		local bluetext = GUI.TextBlock(GUI.RectTransform(Vector2(0.1, 1), colorlayout.RectTransform), "B", nil, nil, GUI.Alignment.Center)
		
		local blue = GUI.NumberInput(GUI.RectTransform(Vector2(0.4, 1), colorlayout.RectTransform), NumberType.Int)
		blue.IntValue = component.lightColor.B
		blue.MinValueInt = 0
		blue.MaxValueInt = 255

		local alphatext = GUI.TextBlock(GUI.RectTransform(Vector2(0.1, 1), colorlayout.RectTransform), "A", nil, nil, GUI.Alignment.Center)
		
		local alpha = GUI.NumberInput(GUI.RectTransform(Vector2(0.4, 1), colorlayout.RectTransform), NumberType.Int)
		alpha.IntValue = component.lightColor.A
		alpha.MinValueInt = 0
		alpha.MaxValueInt = 255
		
		red.OnValueChanged = function ()
			if red.IntValue <= 255 then
				component.lightColor = Color(red.IntValue, green.IntValue, blue.IntValue, alpha.IntValue)
				if Game.IsMultiplayer then
					Update.itemupdatevalue.fn(itemedit.ID, key .. ".lightColor", component.lightColor, "Color")
				end
			end
		end
		green.OnValueChanged = function ()
			if green.IntValue <= 255 then
				component.lightColor = Color(red.IntValue, green.IntValue, blue.IntValue, alpha.IntValue)
				if Game.IsMultiplayer then
					Update.itemupdatevalue.fn(itemedit.ID, key .. ".lightColor", component.lightColor, "Color")
				end
			end
		end
		blue.OnValueChanged = function ()
			if blue.IntValue <= 255 then
				component.lightColor = Color(red.IntValue, green.IntValue, blue.IntValue, alpha.IntValue)
				if Game.IsMultiplayer then
					Update.itemupdatevalue.fn(itemedit.ID, key .. ".lightColor", component.lightColor, "Color")
				end
			end
		end
		alpha.OnValueChanged = function ()
			if alpha.IntValue <= 255 then
				component.lightColor = Color(red.IntValue, green.IntValue, blue.IntValue, alpha.IntValue)
				if Game.IsMultiplayer then
					Update.itemupdatevalue.fn(itemedit.ID, key .. ".lightColor", component.lightColor, "Color")
				end
			end
		end


		local minvoltagelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.055), List.Content.RectTransform), nil)
		minvoltagelayout.isHorizontal = true
		minvoltagelayout.Stretch = true
		minvoltagelayout.RelativeSpacing = 0.001
	
		local minvoltagetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), minvoltagelayout.RectTransform), "Min Voltage", nil, nil, GUI.Alignment.CenterLeft)
		
		local minvoltage = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), minvoltagelayout.RectTransform), NumberType.Float)
		minvoltage.FloatValue = component.MinVoltage
		minvoltage.OnValueChanged = function()
			component.MinVoltage = minvoltage.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".MinVoltage", component.MinVoltage)
			end
		end
	
		local powerconsumptionlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.055), List.Content.RectTransform), nil)
		powerconsumptionlayout.isHorizontal = true
		powerconsumptionlayout.Stretch = true
		powerconsumptionlayout.RelativeSpacing = 0.001
	
		local powerconsumptiontext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), powerconsumptionlayout.RectTransform), "Power Consumption", nil, nil, GUI.Alignment.CenterLeft)
		
		local powerconsumption = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), powerconsumptionlayout.RectTransform), NumberType.Float)
		powerconsumption.FloatValue = component.PowerConsumption
		powerconsumption.OnValueChanged = function()
			component.PowerConsumption = powerconsumption.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PowerConsumption", component.PowerConsumption)
			end
		end
	
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.055), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end

		local castshadows = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Cast Shadows")
		castshadows.Selected = component.CastShadows
		castshadows.OnSelected = function()
			component.CastShadows = castshadows.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CastShadows", component.CastShadows)
			end
		end
	
		local drawbehindsubs = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Draw Behind Subs")
		drawbehindsubs.Selected = component.DrawBehindSubs
		drawbehindsubs.OnSelected = function()
			component.DrawBehindSubs = drawbehindsubs.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".DrawBehindSubs", component.DrawBehindSubs)
			end
		end
		
		local ison = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Is On")
		ison.Selected = component.IsOn
		ison.OnSelected = function()
			component.IsOn = ison.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".IsOn", component.IsOn)
			end
		end

		local vulnerabletoemp = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Vulnerable To EMP")
		vulnerabletoemp.Selected = component.VulnerableToEMP
		vulnerabletoemp.OnSelected = function()
			component.VulnerableToEMP = vulnerabletoemp.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".VulnerableToEMP", component.VulnerableToEMP)
			end
		end
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Allow In-Game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
	
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.05), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
	
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.Text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.Text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end
		
	end
	-- LightComponent Component End --
	-- Holdable Component Start --
	local Holdablefunction = function(component, key)

		if EditGUI.Settings.holdable == false then
			return
		end

		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")
	
		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.46), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
	
		local spritedepthwhendroppedlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.18), List.Content.RectTransform), nil)
		spritedepthwhendroppedlayout.isHorizontal = true
		spritedepthwhendroppedlayout.Stretch = true
		spritedepthwhendroppedlayout.RelativeSpacing = 0.001
		
		local spritedepthwhendroppedtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), spritedepthwhendroppedlayout.RectTransform), "Sprite Depth", nil, nil, GUI.Alignment.CenterLeft)
		
		local spritedepthwhendropped = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), spritedepthwhendroppedlayout.RectTransform), NumberType.Float)
		spritedepthwhendropped.DecimalsToDisplay = 3
		spritedepthwhendropped.FloatValue = component.SpriteDepthWhenDropped
		spritedepthwhendropped.MinValueFloat = 0.001
		spritedepthwhendropped.MaxValueFloat = 0.999
		spritedepthwhendropped.valueStep = 0.1
		spritedepthwhendropped.OnValueChanged = function ()
			component.SpriteDepthWhenDropped = spritedepthwhendropped.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".SpriteDepthWhenDropped", component.SpriteDepthWhenDropped)
			end
		end
	
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.18), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end	
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Allow In-game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end

		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.145), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
		
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end

	end
	-- Holdable Component End --
	-- Connection Panel Component Start --
	local ConnectionPanelfunction = function(component, key)

		if EditGUI.Settings.connectionpanel == false then
			return
		end

		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")
	
		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.48), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
		
		DrawEquippedRequired(component, key, List, 0.12, false)
		
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.12), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end
	
		local locked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Locked")
		locked.Selected = component.Locked
		locked.OnSelected = function()
			component.Locked = locked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Locked", component.Locked)
			end
		end
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Allow In-Game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
	
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.155), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
	
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.Text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.Text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end
		
	end
	-- Connection Panel Component End --
	-- Fabricator Component Start --
	local Fabricatorfunction = function(component, key)

		if EditGUI.Settings.fabricator == false then
			return
		end

		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.58), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
	
		local minvoltagelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.12), List.Content.RectTransform), nil)
		minvoltagelayout.isHorizontal = true
		minvoltagelayout.Stretch = true
		minvoltagelayout.RelativeSpacing = 0.001
	
		local minvoltagetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), minvoltagelayout.RectTransform), "Min Voltage", nil, nil, GUI.Alignment.CenterLeft)
		
		local minvoltage = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), minvoltagelayout.RectTransform), NumberType.Float)
		minvoltage.FloatValue = component.MinVoltage
		minvoltage.OnValueChanged = function()
			component.MinVoltage = minvoltage.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".MinVoltage", component.MinVoltage)
			end
		end
	
		local powerconsumptionlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.12), List.Content.RectTransform), nil)
		powerconsumptionlayout.isHorizontal = true
		powerconsumptionlayout.Stretch = true
		powerconsumptionlayout.RelativeSpacing = 0.001
	
		local powerconsumptiontext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), powerconsumptionlayout.RectTransform), "Power Consumption", nil, nil, GUI.Alignment.CenterLeft)
		
		local powerconsumption = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), powerconsumptionlayout.RectTransform), NumberType.Float)
		powerconsumption.FloatValue = component.PowerConsumption
		powerconsumption.OnValueChanged = function()
			component.PowerConsumption = powerconsumption.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PowerConsumption", component.PowerConsumption)
			end
		end
	
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.12), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end

		local vulnerabletoemp = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Vulnerable To EMP")
		vulnerabletoemp.Selected = component.VulnerableToEMP
		vulnerabletoemp.OnSelected = function()
			component.VulnerableToEMP = vulnerabletoemp.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".VulnerableToEMP", component.VulnerableToEMP)
			end
		end
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Allow In-Game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
	
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.105), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
	
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.Text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.Text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end
		
	end
	-- Fabricator Component End --
	-- Deconstructor Component Start --
	local Deconstructorfunction = function(component, key)

		if EditGUI.Settings.deconstructor == false then
			return
		end

		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.66), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
	
		local deconstructionspeedlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		deconstructionspeedlayout.isHorizontal = true
		deconstructionspeedlayout.Stretch = true
		deconstructionspeedlayout.RelativeSpacing = 0.001
	
		local deconstructionspeedtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), deconstructionspeedlayout.RectTransform), "Deconstruction Speed", nil, nil, GUI.Alignment.CenterLeft)
		
		local deconstructionspeed = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), deconstructionspeedlayout.RectTransform), NumberType.Float)
		deconstructionspeed.FloatValue = component.DeconstructionSpeed
		deconstructionspeed.OnValueChanged = function()
			component.DeconstructionSpeed = deconstructionspeed.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".DeconstructionSpeed", component.DeconstructionSpeed)
			end
		end
	
		local minvoltagelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		minvoltagelayout.isHorizontal = true
		minvoltagelayout.Stretch = true
		minvoltagelayout.RelativeSpacing = 0.001
	
		local minvoltagetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), minvoltagelayout.RectTransform), "Min Voltage", nil, nil, GUI.Alignment.CenterLeft)
		
		local minvoltage = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), minvoltagelayout.RectTransform), NumberType.Float)
		minvoltage.FloatValue = component.MinVoltage
		minvoltage.OnValueChanged = function()
			component.MinVoltage = minvoltage.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".MinVoltage", component.MinVoltage)
			end
		end
	
		local powerconsumptionlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		powerconsumptionlayout.isHorizontal = true
		powerconsumptionlayout.Stretch = true
		powerconsumptionlayout.RelativeSpacing = 0.001
	
		local powerconsumptiontext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), powerconsumptionlayout.RectTransform), "Power Consumption", nil, nil, GUI.Alignment.CenterLeft)
		
		local powerconsumption = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), powerconsumptionlayout.RectTransform), NumberType.Float)
		powerconsumption.FloatValue = component.PowerConsumption
		powerconsumption.OnValueChanged = function()
			component.PowerConsumption = powerconsumption.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PowerConsumption", component.PowerConsumption)
			end
		end
	
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end

		local vulnerabletoemp = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Vulnerable To EMP")
		vulnerabletoemp.Selected = component.VulnerableToEMP
		vulnerabletoemp.OnSelected = function()
			component.VulnerableToEMP = vulnerabletoemp.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".VulnerableToEMP", component.VulnerableToEMP)
			end
		end
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Allow In-Game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
	
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
	
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.Text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.Text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end
		
	end
	-- Deconstructor Component End --
	-- Reactor Component Start --
	local Reactorfunction = function(component, key)

		if EditGUI.Settings.reactor == false then
			return
		end

		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.925), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
	
		local maxpoweroutputlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.075), List.Content.RectTransform), nil)
		maxpoweroutputlayout.isHorizontal = true
		maxpoweroutputlayout.Stretch = true
		maxpoweroutputlayout.RelativeSpacing = 0.001
	
		local maxpoweroutputtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), maxpoweroutputlayout.RectTransform), "Max Power Output", nil, nil, GUI.Alignment.CenterLeft)
		
		local maxpoweroutput = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), maxpoweroutputlayout.RectTransform), NumberType.Float)
		maxpoweroutput.FloatValue = component.MaxPowerOutput
		maxpoweroutput.OnValueChanged = function()
			component.MaxPowerOutput = maxpoweroutput.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".MaxPowerOutput", component.MaxPowerOutput)
			end
		end
		
		local meltdowndelaylayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.075), List.Content.RectTransform), nil)
		meltdowndelaylayout.isHorizontal = true
		meltdowndelaylayout.Stretch = true
		meltdowndelaylayout.RelativeSpacing = 0.001
	
		local meltdowndelaytext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), meltdowndelaylayout.RectTransform), "Meltdown Delay", nil, nil, GUI.Alignment.CenterLeft)
		
		local meltdowndelay = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), meltdowndelaylayout.RectTransform), NumberType.Float)
		meltdowndelay.FloatValue = component.MeltdownDelay
		meltdowndelay.OnValueChanged = function()
			component.MeltdownDelay = meltdowndelay.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".MeltdownDelay", component.MeltdownDelay)
			end
		end
	
		local firedelaylayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.075), List.Content.RectTransform), nil)
		firedelaylayout.isHorizontal = true
		firedelaylayout.Stretch = true
		firedelaylayout.RelativeSpacing = 0.001
	
		local firedelaytext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), firedelaylayout.RectTransform), "Fire Delay", nil, nil, GUI.Alignment.CenterLeft)
		
		local firedelay = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), firedelaylayout.RectTransform), NumberType.Float)
		firedelay.FloatValue = component.FireDelay
		firedelay.OnValueChanged = function()
			component.FireDelay = firedelay.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".FireDelay", component.FireDelay)
			end
		end
		
		local fuelconsumptionratelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.075), List.Content.RectTransform), nil)
		fuelconsumptionratelayout.isHorizontal = true
		fuelconsumptionratelayout.Stretch = true
		fuelconsumptionratelayout.RelativeSpacing = 0.001
	
		local fuelconsumptionratetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), fuelconsumptionratelayout.RectTransform), "Fuel Consumption Rate", nil, nil, GUI.Alignment.CenterLeft)
		
		local fuelconsumptionrate = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), fuelconsumptionratelayout.RectTransform), NumberType.Float)
		fuelconsumptionrate.FloatValue = component.FuelConsumptionRate
		fuelconsumptionrate.OnValueChanged = function()
			component.FuelConsumptionRate = fuelconsumptionrate.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".FuelConsumptionRate", component.FuelConsumptionRate)
			end
		end
	
		local minvoltagelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.09), List.Content.RectTransform), nil)
		minvoltagelayout.isHorizontal = true
		minvoltagelayout.Stretch = true
		minvoltagelayout.RelativeSpacing = 0.001
	
		local minvoltagetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), minvoltagelayout.RectTransform), "Min Voltage", nil, nil, GUI.Alignment.CenterLeft)
		
		local minvoltage = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), minvoltagelayout.RectTransform), NumberType.Float)
		minvoltage.FloatValue = component.MinVoltage
		minvoltage.OnValueChanged = function()
			component.MinVoltage = minvoltage.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".MinVoltage", component.MinVoltage)
			end
		end
	
		local powerconsumptionlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.075), List.Content.RectTransform), nil)
		powerconsumptionlayout.isHorizontal = true
		powerconsumptionlayout.Stretch = true
		powerconsumptionlayout.RelativeSpacing = 0.001
	
		local powerconsumptiontext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), powerconsumptionlayout.RectTransform), "Power Consumption", nil, nil, GUI.Alignment.CenterLeft)
		
		local powerconsumption = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), powerconsumptionlayout.RectTransform), NumberType.Float)
		powerconsumption.FloatValue = component.PowerConsumption
		powerconsumption.OnValueChanged = function()
			component.PowerConsumption = powerconsumption.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PowerConsumption", component.PowerConsumption)
			end
		end
	
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.075), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end

		local explosiondamagesothersubs = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Explosion Damages Other Subs")
		explosiondamagesothersubs.Selected = component.ExplosionDamagesOtherSubs
		explosiondamagesothersubs.OnSelected = function()
			component.ExplosionDamagesOtherSubs = explosiondamagesothersubs.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".ExplosionDamagesOtherSubs", component.ExplosionDamagesOtherSubs)
			end
		end

		local vulnerabletoemp = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Vulnerable To EMP")
		vulnerabletoemp.Selected = component.VulnerableToEMP
		vulnerabletoemp.OnSelected = function()
			component.VulnerableToEMP = vulnerabletoemp.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".VulnerableToEMP", component.VulnerableToEMP)
			end
		end
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Allow In-Game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
	
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.075), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
	
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.Text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.Text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end
		
	end
	-- Reactor Component End --
	-- OxygenGenerator Component Start --
	local OxygenGeneratorfunction = function(component, key)

		if EditGUI.Settings.oxygengenerator == false then
			return
		end

		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.66), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
	
		local generatedamountlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		generatedamountlayout.isHorizontal = true
		generatedamountlayout.Stretch = true
		generatedamountlayout.RelativeSpacing = 0.001
	
		local generatedamounttext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), generatedamountlayout.RectTransform), "Generated Amount", nil, nil, GUI.Alignment.CenterLeft)
		
		local generatedamount = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), generatedamountlayout.RectTransform), NumberType.Float)
		generatedamount.FloatValue = component.GeneratedAmount
		generatedamount.OnValueChanged = function()
			component.GeneratedAmount = generatedamount.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".GeneratedAmount", component.GeneratedAmount)
			end
		end
	
		local minvoltagelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		minvoltagelayout.isHorizontal = true
		minvoltagelayout.Stretch = true
		minvoltagelayout.RelativeSpacing = 0.001
	
		local minvoltagetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), minvoltagelayout.RectTransform), "Min Voltage", nil, nil, GUI.Alignment.CenterLeft)
		
		local minvoltage = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), minvoltagelayout.RectTransform), NumberType.Float)
		minvoltage.FloatValue = component.MinVoltage
		minvoltage.OnValueChanged = function()
			component.MinVoltage = minvoltage.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".MinVoltage", component.MinVoltage)
			end
		end
	
		local powerconsumptionlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		powerconsumptionlayout.isHorizontal = true
		powerconsumptionlayout.Stretch = true
		powerconsumptionlayout.RelativeSpacing = 0.001
	
		local powerconsumptiontext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), powerconsumptionlayout.RectTransform), "Power Consumption", nil, nil, GUI.Alignment.CenterLeft)
		
		local powerconsumption = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), powerconsumptionlayout.RectTransform), NumberType.Float)
		powerconsumption.FloatValue = component.PowerConsumption
		powerconsumption.OnValueChanged = function()
			component.PowerConsumption = powerconsumption.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PowerConsumption", component.PowerConsumption)
			end
		end
	
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end

		local vulnerabletoemp = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Vulnerable To EMP")
		vulnerabletoemp.Selected = component.VulnerableToEMP
		vulnerabletoemp.OnSelected = function()
			component.VulnerableToEMP = vulnerabletoemp.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".VulnerableToEMP", component.VulnerableToEMP)
			end
		end
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Allow In-Game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
	
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
	
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.Text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.Text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end
		
	end
	-- OxygenGenerator Component End --
	-- Sonar Component Start --
	local Sonarfunction = function(component, key)

		if EditGUI.Settings.sonar == false then
			return
		end

		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.78), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)

		local usetransdusers = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.088), List.Content.RectTransform), "Use Transdusers")
		usetransdusers.Selected = component.UseTransducers
		usetransdusers.OnSelected = function()
			component.UseTransducers = usetransdusers.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".UseTransducers", component.UseTransducers)
			end
		end

		local centerontransducers = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.088), List.Content.RectTransform), "Center On Transdusers")
		centerontransducers.Selected = component.CenterOnTransducers
		centerontransducers.OnSelected = function()
			component.CenterOnTransducers = centerontransducers.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CenterOnTransducers", component.CenterOnTransducers)
			end
		end

		local hasmineralscanner = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.088), List.Content.RectTransform), "Has Mineral Scanner")
		hasmineralscanner.Selected = component.HasMineralScanner
		hasmineralscanner.OnSelected = function()
			component.HasMineralScanner = hasmineralscanner.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".HasMineralScanner", component.HasMineralScanner)
			end
		end
	
		local minvoltagelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.088), List.Content.RectTransform), nil)
		minvoltagelayout.isHorizontal = true
		minvoltagelayout.Stretch = true
		minvoltagelayout.RelativeSpacing = 0.001
	
		local minvoltagetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), minvoltagelayout.RectTransform), "Min Voltage", nil, nil, GUI.Alignment.CenterLeft)
		
		local minvoltage = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), minvoltagelayout.RectTransform), NumberType.Float)
		minvoltage.FloatValue = component.MinVoltage
		minvoltage.OnValueChanged = function()
			component.MinVoltage = minvoltage.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".MinVoltage", component.MinVoltage)
			end
		end
	
		local powerconsumptionlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.088), List.Content.RectTransform), nil)
		powerconsumptionlayout.isHorizontal = true
		powerconsumptionlayout.Stretch = true
		powerconsumptionlayout.RelativeSpacing = 0.001
	
		local powerconsumptiontext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), powerconsumptionlayout.RectTransform), "Power Consumption", nil, nil, GUI.Alignment.CenterLeft)
		
		local powerconsumption = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), powerconsumptionlayout.RectTransform), NumberType.Float)
		powerconsumption.FloatValue = component.PowerConsumption
		powerconsumption.OnValueChanged = function()
			component.PowerConsumption = powerconsumption.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PowerConsumption", component.PowerConsumption)
			end
		end
	
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.088), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end

		local vulnerabletoemp = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.088), List.Content.RectTransform), "Vulnerable To EMP")
		vulnerabletoemp.Selected = component.VulnerableToEMP
		vulnerabletoemp.OnSelected = function()
			component.VulnerableToEMP = vulnerabletoemp.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".VulnerableToEMP", component.VulnerableToEMP)
			end
		end
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.088), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.088), List.Content.RectTransform), "Allow In-Game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
	
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.088), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
	
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.Text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.Text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end
		
	end
	-- Sonar Component End --
	-- Repairable Component Start --
	local Repairablefunction = function(component, key)
		
		if EditGUI.Settings.repairable == false then
			return
		end
		
		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")
		
		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.85), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.115), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
		
		DrawEquippedRequired(component, key, List, 0.08, false)
		
		local deteriorationspeedlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.08), List.Content.RectTransform), nil)
		deteriorationspeedlayout.isHorizontal = true
		deteriorationspeedlayout.Stretch = true
		deteriorationspeedlayout.RelativeSpacing = 0.001
		
		local deteriorationspeedtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), deteriorationspeedlayout.RectTransform), "Deterioration Speed", nil, nil, GUI.Alignment.CenterLeft)
		
		local deteriorationspeed = GUI.NumberInput(GUI.RectTransform(Vector2(1, 1), deteriorationspeedlayout.RectTransform), NumberType.Float)
		deteriorationspeed.FloatValue = component.DeteriorationSpeed
		deteriorationspeed.MinValueFloat = 0
		deteriorationspeed.MaxValueFloat = 100
		deteriorationspeed.valueStep = 1
		deteriorationspeed.OnValueChanged = function ()
			component.DeteriorationSpeed = deteriorationspeed.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".DeteriorationSpeed", component.DeteriorationSpeed)
			end
		end
		
		local mindeteriorationdelaylayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.08), List.Content.RectTransform), nil)
		mindeteriorationdelaylayout.isHorizontal = true
		mindeteriorationdelaylayout.Stretch = true
		mindeteriorationdelaylayout.RelativeSpacing = 0.001
		
		local mindeteriorationdelaytext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), mindeteriorationdelaylayout.RectTransform), "Min Deterioration Delay", nil, nil, GUI.Alignment.CenterLeft)
		
		local mindeteriorationdelay = GUI.NumberInput(GUI.RectTransform(Vector2(1, 1), mindeteriorationdelaylayout.RectTransform), NumberType.Float)
		mindeteriorationdelay.DecimalsToDisplay = 2
		mindeteriorationdelay.FloatValue = component.MinDeteriorationDelay
		mindeteriorationdelay.MinValueFloat = 0
		mindeteriorationdelay.MaxValueFloat = 1000
		mindeteriorationdelay.valueStep = 10
		mindeteriorationdelay.OnValueChanged = function ()
			component.MinDeteriorationDelay = mindeteriorationdelay.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".MinDeteriorationDelay", component.MinDeteriorationDelay)
			end
		end
		
		local maxdeteriorationdelaylayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.08), List.Content.RectTransform), nil)
		maxdeteriorationdelaylayout.isHorizontal = true
		maxdeteriorationdelaylayout.Stretch = true
		maxdeteriorationdelaylayout.RelativeSpacing = 0.001
		
		local maxdeteriorationdelaytext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), maxdeteriorationdelaylayout.RectTransform), "Max Deterioration Delay", nil, nil, GUI.Alignment.CenterLeft)
		
		local maxdeteriorationdelay = GUI.NumberInput(GUI.RectTransform(Vector2(1, 1), maxdeteriorationdelaylayout.RectTransform), NumberType.Float)
		maxdeteriorationdelay.DecimalsToDisplay = 2
		maxdeteriorationdelay.FloatValue = component.MaxDeteriorationDelay
		maxdeteriorationdelay.MinValueFloat = 0
		maxdeteriorationdelay.MaxValueFloat = 1000
		maxdeteriorationdelay.valueStep = 10
		maxdeteriorationdelay.OnValueChanged = function ()
			component.MaxDeteriorationDelay = maxdeteriorationdelay.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".MaxDeteriorationDelay", component.MaxDeteriorationDelay)
			end
		end
		
		local mindeteriorationconditionlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.08), List.Content.RectTransform), nil)
		mindeteriorationconditionlayout.isHorizontal = true
		mindeteriorationconditionlayout.Stretch = true
		mindeteriorationconditionlayout.RelativeSpacing = 0.001
		
		local mindeteriorationconditiontext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), mindeteriorationconditionlayout.RectTransform), "Min Deterioration Condition", nil, nil, GUI.Alignment.CenterLeft)
		
		local mindeteriorationcondition = GUI.NumberInput(GUI.RectTransform(Vector2(1, 1), mindeteriorationconditionlayout.RectTransform), NumberType.Float)
		mindeteriorationcondition.FloatValue = component.MinDeteriorationCondition
		mindeteriorationcondition.MinValueFloat = 0
		mindeteriorationcondition.MaxValueFloat = 100
		mindeteriorationcondition.valueStep = 1
		mindeteriorationcondition.OnValueChanged = function ()
			component.MinDeteriorationCondition = mindeteriorationcondition.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".MinDeteriorationCondition", component.MinDeteriorationCondition)
			end
		end
	
		local repairthresholdlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.08), List.Content.RectTransform), nil)
		repairthresholdlayout.isHorizontal = true
		repairthresholdlayout.Stretch = true
		repairthresholdlayout.RelativeSpacing = 0.001
		
		local repairthresholdtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), repairthresholdlayout.RectTransform), "Repair Threshold", nil, nil, GUI.Alignment.CenterLeft)
		
		local repairthreshold = GUI.NumberInput(GUI.RectTransform(Vector2(1, 1), repairthresholdlayout.RectTransform), NumberType.Float)
		repairthreshold.FloatValue = component.RepairThreshold
		repairthreshold.MinValueFloat = 0
		repairthreshold.MaxValueFloat = 100
		repairthreshold.valueStep = 1
		repairthreshold.OnValueChanged = function ()
			component.RepairThreshold = repairthreshold.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".RepairThreshold", component.RepairThreshold)
			end
		end
		
		local fixdurationlowskilllayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.08), List.Content.RectTransform), nil)
		fixdurationlowskilllayout.isHorizontal = true
		fixdurationlowskilllayout.Stretch = true
		fixdurationlowskilllayout.RelativeSpacing = 0.001
		
		local fixdurationlowskilltext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), fixdurationlowskilllayout.RectTransform), "Fix Duration Low Skill", nil, nil, GUI.Alignment.CenterLeft)
		
		local fixdurationlowskill = GUI.NumberInput(GUI.RectTransform(Vector2(1, 1), fixdurationlowskilllayout.RectTransform), NumberType.Float)
		fixdurationlowskill.FloatValue = component.FixDurationLowSkill
		fixdurationlowskill.MinValueFloat = 0
		fixdurationlowskill.MaxValueFloat = 100
		fixdurationlowskill.valueStep = 1
		fixdurationlowskill.OnValueChanged = function ()
			component.FixDurationLowSkill = fixdurationlowskill.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".FixDurationLowSkill", component.FixDurationLowSkill)
			end
		end
		
		local fixdurationhighskilllayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.08), List.Content.RectTransform), nil)
		fixdurationhighskilllayout.isHorizontal = true
		fixdurationhighskilllayout.Stretch = true
		fixdurationhighskilllayout.RelativeSpacing = 0.001
		
		local fixdurationhighskilltext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), fixdurationhighskilllayout.RectTransform), "Fix Duration High Skill", nil, nil, GUI.Alignment.CenterLeft)
		
		local fixdurationhighskill = GUI.NumberInput(GUI.RectTransform(Vector2(1, 1), fixdurationhighskilllayout.RectTransform), NumberType.Float)
		fixdurationhighskill.FloatValue = component.FixDurationHighSkill
		fixdurationhighskill.MinValueFloat = 0
		fixdurationhighskill.MaxValueFloat = 100
		fixdurationhighskill.valueStep = 1
		fixdurationhighskill.OnValueChanged = function ()
			component.FixDurationHighSkill = fixdurationhighskill.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".FixDurationHighSkill", component.FixDurationHighSkill)
			end
		end
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Allow In-Game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
	
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.08), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
	
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.Text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.Text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end
	
	end
	-- Repairable Component End --
	-- Power Transfer Component Start --
	local PowerTransferfunction = function(component, key)
		
		if EditGUI.Settings.powertransfer == false then
			return
		end
		
		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.66), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
	
		local overloadvoltagelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		overloadvoltagelayout.isHorizontal = true
		overloadvoltagelayout.Stretch = true
		overloadvoltagelayout.RelativeSpacing = 0.001
	
		local overloadvoltagetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), overloadvoltagelayout.RectTransform), "Overload Voltage", nil, nil, GUI.Alignment.CenterLeft)
		
		local overloadvoltage = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), overloadvoltagelayout.RectTransform), NumberType.Float)
		overloadvoltage.FloatValue = component.OverloadVoltage
		overloadvoltage.OnValueChanged = function()
			component.OverloadVoltage = overloadvoltage.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".OverloadVoltage", component.OverloadVoltage)
			end
		end
	
		local fireprobabilitylayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		fireprobabilitylayout.isHorizontal = true
		fireprobabilitylayout.Stretch = true
		fireprobabilitylayout.RelativeSpacing = 0.001
	
		local fireprobabilitytext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), fireprobabilitylayout.RectTransform), "Fire Probability", nil, nil, GUI.Alignment.CenterLeft)
		
		local fireprobability = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), fireprobabilitylayout.RectTransform), NumberType.Float)
		fireprobability.MinValueFloat = 0
		fireprobability.MaxValueFloat = 1
		fireprobability.valueStep = 0.1
		fireprobability.FloatValue = component.FireProbability
		fireprobability.OnValueChanged = function()
			component.FireProbability = fireprobability.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".FireProbability", component.FireProbability)
			end
		end
	
		local minvoltagelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		minvoltagelayout.isHorizontal = true
		minvoltagelayout.Stretch = true
		minvoltagelayout.RelativeSpacing = 0.001
	
		local minvoltagetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), minvoltagelayout.RectTransform), "Min Voltage", nil, nil, GUI.Alignment.CenterLeft)
		
		local minvoltage = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), minvoltagelayout.RectTransform), NumberType.Float)
		minvoltage.FloatValue = component.MinVoltage
		minvoltage.OnValueChanged = function()
			component.MinVoltage = minvoltage.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".MinVoltage", component.MinVoltage)
			end
		end
	
		local powerconsumptionlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		powerconsumptionlayout.isHorizontal = true
		powerconsumptionlayout.Stretch = true
		powerconsumptionlayout.RelativeSpacing = 0.001
	
		local powerconsumptiontext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), powerconsumptionlayout.RectTransform), "Power Consumption", nil, nil, GUI.Alignment.CenterLeft)
		
		local powerconsumption = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), powerconsumptionlayout.RectTransform), NumberType.Float)
		powerconsumption.FloatValue = component.PowerConsumption
		powerconsumption.OnValueChanged = function()
			component.PowerConsumption = powerconsumption.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PowerConsumption", component.PowerConsumption)
			end
		end
	
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end

		local canbeoverloaded = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Can Be Overloaded")
		canbeoverloaded.Selected = component.CanBeOverloaded
		canbeoverloaded.OnSelected = function()
			component.CanBeOverloaded = canbeoverloaded.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBeOverloaded", component.CanBeOverloaded)
			end
		end

		local vulnerabletoemp = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Vulnerable To EMP")
		vulnerabletoemp.Selected = component.VulnerableToEMP
		vulnerabletoemp.OnSelected = function()
			component.VulnerableToEMP = vulnerabletoemp.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".VulnerableToEMP", component.VulnerableToEMP)
			end
		end
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Allow In-Game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
	
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
	
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.Text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.Text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end

	end
	-- Power Transfer Component End --
	-- Item Container Component Start --
	local ItemContainerfunction = function(component, key)
		
		if EditGUI.Settings.itemcontainer == false then
			return
		end
		
		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.6), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.13), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
		
		DrawPickedRequired(component, key, List, 0.18, false, "ItemMsgUnauthorizedAccess")
		
		local containablerestrictionslayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.145), List.Content.RectTransform), nil)
		containablerestrictionslayout.isHorizontal = true
		containablerestrictionslayout.Stretch = true
		containablerestrictionslayout.RelativeSpacing = 0.001
		
		local containablerestrictionstext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), containablerestrictionslayout.RectTransform), "Containable Tags", nil, nil, GUI.Alignment.CenterLeft)
		
		local containablerestrictions = GUI.TextBox(GUI.RectTransform(Vector2(0.8, 1), containablerestrictionslayout.RectTransform), "")
		containablerestrictions.text = component.ContainableRestrictions
		containablerestrictions.OnTextChangedDelegate = function()
			component.ContainableRestrictions = containablerestrictions.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".ContainableRestrictions", component.ContainableRestrictions)
			end
		end
		
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.18), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end	
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.6), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Allow In-game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
		
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.145), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
		
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end
		
	end
	-- Item Container Component End --
	-- Door Component Start --
	local Doorfunction = function(component, key)
		if EditGUI.Settings.door == false then
			return
		end
		
		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.5), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.172), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
		
		DrawPickedRequired(component, key, List, 0.138, true, "ItemMsgUnauthorizedAccess")
		DrawEquippedRequired(component, key, List, 0.138, true)
		
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.138), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
		
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end	
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.138), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.138), List.Content.RectTransform), "Allow In-game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
		
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.138), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
		
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end
		
	end
	-- Door Component End --
	-- Label Component Start --
	local ItemLabelfunction = function(component, key)
	
		if EditGUI.Settings.itemlabel == false then
			return
		end
	
		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")
	
		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.65), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.15), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
	
		local textlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		textlayout.isHorizontal = true
		textlayout.Stretch = true
		textlayout.RelativeSpacing = 0.001
	
		local texttext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), textlayout.RectTransform), "Text", nil, nil, GUI.Alignment.CenterLeft)
		
		local text = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), textlayout.RectTransform), "")
		text.Text = component.Text
		text.OnTextChangedDelegate = function()
			component.Text = text.Text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Text", component.Text)
			end
		end
	
		local textscalelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		textscalelayout.isHorizontal = true
		textscalelayout.Stretch = true
		textscalelayout.RelativeSpacing = 0.001
	
		local textscaletext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), textscalelayout.RectTransform), "Text Scale", nil, nil, GUI.Alignment.CenterLeft)
		
		local textscale = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), textscalelayout.RectTransform), NumberType.Float)
		textscale.FloatValue = component.TextScale
		textscale.OnValueChanged = function()
			component.TextScale = textscale.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".TextScale", component.TextScale)
			end
		end	
	
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end	
	
		local colorlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.125), List.Content.RectTransform), nil)
		colorlayout.isHorizontal = true
		colorlayout.Stretch = true
		colorlayout.RelativeSpacing = 0.01
	
		local colortext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), colorlayout.RectTransform), "Color", nil, nil, GUI.Alignment.CenterLeft)

		local redtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.1, 1), colorlayout.RectTransform), "R", nil, nil, GUI.Alignment.Center)
		
		local red = GUI.NumberInput(GUI.RectTransform(Vector2(0.4, 1), colorlayout.RectTransform), NumberType.Int)
		red.IntValue = component.TextColor.R
		red.MinValueInt = 0
		red.MaxValueInt = 255
		
		local greentext = GUI.TextBlock(GUI.RectTransform(Vector2(0.1, 1), colorlayout.RectTransform), "G", nil, nil, GUI.Alignment.Center)
		
		local green = GUI.NumberInput(GUI.RectTransform(Vector2(0.4, 1), colorlayout.RectTransform), NumberType.Int)
		green.IntValue = component.TextColor.G
		green.MinValueInt = 0
		green.MaxValueInt = 255
		
		local bluetext = GUI.TextBlock(GUI.RectTransform(Vector2(0.1, 1), colorlayout.RectTransform), "B", nil, nil, GUI.Alignment.Center)
		
		local blue = GUI.NumberInput(GUI.RectTransform(Vector2(0.4, 1), colorlayout.RectTransform), NumberType.Int)
		blue.IntValue = component.TextColor.B
		blue.MinValueInt = 0
		blue.MaxValueInt = 255

		local alphatext = GUI.TextBlock(GUI.RectTransform(Vector2(0.1, 1), colorlayout.RectTransform), "A", nil, nil, GUI.Alignment.Center)
		
		local alpha = GUI.NumberInput(GUI.RectTransform(Vector2(0.4, 1), colorlayout.RectTransform), NumberType.Int)
		alpha.IntValue = component.TextColor.A
		alpha.MinValueInt = 0
		alpha.MaxValueInt = 255
		
		red.OnValueChanged = function ()
			if red.IntValue <= 255 then
				component.TextColor = Color(red.IntValue, green.IntValue, blue.IntValue, alpha.IntValue)
				if Game.IsMultiplayer then
					Update.itemupdatevalue.fn(itemedit.ID, key .. ".TextColor", component.TextColor, "Color")
				end
			end
		end
		green.OnValueChanged = function ()
			if green.IntValue <= 255 then
				component.TextColor = Color(red.IntValue, green.IntValue, blue.IntValue, alpha.IntValue)
				if Game.IsMultiplayer then
					Update.itemupdatevalue.fn(itemedit.ID, key .. ".TextColor", component.TextColor, "Color")
				end
			end
		end
		blue.OnValueChanged = function ()
			if blue.IntValue <= 255 then
				component.TextColor = Color(red.IntValue, green.IntValue, blue.IntValue, alpha.IntValue)
				if Game.IsMultiplayer then
					Update.itemupdatevalue.fn(itemedit.ID, key .. ".TextColor", component.TextColor, "Color")
				end
			end
		end
		alpha.OnValueChanged = function ()
			if alpha.IntValue <= 255 then
				component.TextColor = Color(red.IntValue, green.IntValue, blue.IntValue, alpha.IntValue)
				if Game.IsMultiplayer then
					Update.itemupdatevalue.fn(itemedit.ID, key .. ".TextColor", component.TextColor, "Color")
				end
			end
		end
	
		local ignorelocalization = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Ignore Localization")
		ignorelocalization.Selected = component.IgnoreLocalization
		ignorelocalization.OnSelected = function()
			component.IgnoreLocalization = ignorelocalization.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".IgnoreLocalization", component.IgnoreLocalization)
			end
		end
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Allow In-game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
		
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.09), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
		
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end
		
	end
	-- Label Component End --
	-- Quality Component Start --
	local Qualityfunction = function(component, key)
	
		if EditGUI.Settings.quality == false then
			return
		end
	
		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")
	
		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.3), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.3), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
	
		local qualitylevellayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.4), List.Content.RectTransform), nil)
		qualitylevellayout.isHorizontal = true
		qualitylevellayout.Stretch = true
		qualitylevellayout.RelativeSpacing = 0.001

		local qualityleveltext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), qualitylevellayout.RectTransform), "Quality Level", nil, nil, GUI.Alignment.CenterLeft)
		
		local qualitylevel = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), qualitylevellayout.RectTransform), NumberType.Int)
		qualitylevel.IntValue = component.QualityLevel
		qualitylevel.MinValueInt = 0
		qualitylevel.MaxValueInt = 3
		qualitylevel.valueStep = 1
		qualitylevel.OnValueChanged = function ()
			component.QualityLevel = qualitylevel.IntValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".QualityLevel", component.QualityLevel)
			end
		end
	
	end
	-- Quality Component End --
	-- And Component Start --
	local AndComponentfunction = function(component, key)
		
		if EditGUI.Settings.components == false then
			return
		end
		
		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.7), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.13), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
	
		local timeframelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		timeframelayout.isHorizontal = true
		timeframelayout.Stretch = true
		timeframelayout.RelativeSpacing = 0.001
	
		local timeframetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), timeframelayout.RectTransform), "Timeframe", nil, nil, GUI.Alignment.CenterLeft)
		
		local timeframe = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), timeframelayout.RectTransform), NumberType.Float)
		timeframe.DecimalsToDisplay = 2
		timeframe.FloatValue = component.TimeFrame
		timeframe.OnValueChanged = function()
			component.TimeFrame = timeframe.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".TimeFrame", component.TimeFrame)
			end
		end	
		
		local maxoutputlengthlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		maxoutputlengthlayout.isHorizontal = true
		maxoutputlengthlayout.Stretch = true
		maxoutputlengthlayout.RelativeSpacing = 0.001
	
		local maxoutputlengthtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), maxoutputlengthlayout.RectTransform), "Max Output Length", nil, nil, GUI.Alignment.CenterLeft)
		
		local maxoutputlength = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), maxoutputlengthlayout.RectTransform), NumberType.Int)
		maxoutputlength.IntValue = component.MaxOutputLength
		maxoutputlength.MinValueInt = -1000000000
		maxoutputlength.MaxValueInt = 1000000000
		maxoutputlength.valueStep = 1
		maxoutputlength.OnValueChanged = function()
			component.MaxOutputLength = maxoutputlength.IntValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".MaxOutputLength", component.MaxOutputLength)
			end
		end	
		
		local outputlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		outputlayout.isHorizontal = true
		outputlayout.Stretch = true
		outputlayout.RelativeSpacing = 0.001
		
		local outputtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), outputlayout.RectTransform), "Output", nil, nil, GUI.Alignment.CenterLeft)
		
		local output = GUI.TextBox(GUI.RectTransform(Vector2(1.2 , 1), outputlayout.RectTransform), "")
		output.text = component.Output
		output.OnTextChangedDelegate = function()
			component.Output = output.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Output", component.Output)
			end
		end
		
		local falseoutputlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		falseoutputlayout.isHorizontal = true
		falseoutputlayout.Stretch = true
		falseoutputlayout.RelativeSpacing = 0.001
		
		local falseoutputtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), falseoutputlayout.RectTransform), "False Output", nil, nil, GUI.Alignment.CenterLeft)
		
		local falseoutput = GUI.TextBox(GUI.RectTransform(Vector2(1.2, 1), falseoutputlayout.RectTransform), "")
		falseoutput.text = component.FalseOutput
		falseoutput.OnTextChangedDelegate = function()
			component.FalseOutput = falseoutput.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".FalseOutput", component.FalseOutput)
			end
		end
		
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end	
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Allow In-game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
		
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.09), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
		
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end
		
	end
	-- And Component End --
	-- Greater Component Start --
	local GreaterComponentfunction = function(component, key)
		
		if EditGUI.Settings.components == false then
			return
		end
		
		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.7), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.13), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
	
		local timeframelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		timeframelayout.isHorizontal = true
		timeframelayout.Stretch = true
		timeframelayout.RelativeSpacing = 0.001
	
		local timeframetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), timeframelayout.RectTransform), "Timeframe", nil, nil, GUI.Alignment.CenterLeft)
		
		local timeframe = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), timeframelayout.RectTransform), NumberType.Float)
		timeframe.DecimalsToDisplay = 2
		timeframe.FloatValue = component.TimeFrame
		timeframe.OnValueChanged = function()
			component.TimeFrame = timeframe.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".TimeFrame", component.TimeFrame)
			end
		end	
		
		local maxoutputlengthlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		maxoutputlengthlayout.isHorizontal = true
		maxoutputlengthlayout.Stretch = true
		maxoutputlengthlayout.RelativeSpacing = 0.001
	
		local maxoutputlengthtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), maxoutputlengthlayout.RectTransform), "Max Output Length", nil, nil, GUI.Alignment.CenterLeft)
		
		local maxoutputlength = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), maxoutputlengthlayout.RectTransform), NumberType.Int)
		maxoutputlength.IntValue = component.MaxOutputLength
		maxoutputlength.MinValueInt = -1000000000
		maxoutputlength.MaxValueInt = 1000000000
		maxoutputlength.valueStep = 1
		maxoutputlength.OnValueChanged = function()
			component.MaxOutputLength = maxoutputlength.IntValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".MaxOutputLength", component.MaxOutputLength)
			end
		end	
		
		local outputlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		outputlayout.isHorizontal = true
		outputlayout.Stretch = true
		outputlayout.RelativeSpacing = 0.001
		
		local outputtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), outputlayout.RectTransform), "Output", nil, nil, GUI.Alignment.CenterLeft)
		
		local output = GUI.TextBox(GUI.RectTransform(Vector2(1.2 , 1), outputlayout.RectTransform), "")
		output.text = component.Output
		output.OnTextChangedDelegate = function()
			component.Output = output.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Output", component.Output)
			end
		end
		
		local falseoutputlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		falseoutputlayout.isHorizontal = true
		falseoutputlayout.Stretch = true
		falseoutputlayout.RelativeSpacing = 0.001
		
		local falseoutputtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), falseoutputlayout.RectTransform), "False Output", nil, nil, GUI.Alignment.CenterLeft)
		
		local falseoutput = GUI.TextBox(GUI.RectTransform(Vector2(1.2, 1), falseoutputlayout.RectTransform), "")
		falseoutput.text = component.FalseOutput
		falseoutput.OnTextChangedDelegate = function()
			component.FalseOutput = falseoutput.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".FalseOutput", component.FalseOutput)
			end
		end
		
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end	
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Allow In-game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
		
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.09), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
		
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end
		
	end
	-- Greater Component End --
	-- Equals Component Start --
	local EqualsComponentfunction = function(component, key)
		
		if EditGUI.Settings.components == false then
			return
		end
		
		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.7), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.13), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
	
		local timeframelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		timeframelayout.isHorizontal = true
		timeframelayout.Stretch = true
		timeframelayout.RelativeSpacing = 0.001
	
		local timeframetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), timeframelayout.RectTransform), "Timeframe", nil, nil, GUI.Alignment.CenterLeft)
		
		local timeframe = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), timeframelayout.RectTransform), NumberType.Float)
		timeframe.DecimalsToDisplay = 2
		timeframe.FloatValue = component.TimeFrame
		timeframe.OnValueChanged = function()
			component.TimeFrame = timeframe.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".TimeFrame", component.TimeFrame)
			end
		end	
		
		local maxoutputlengthlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		maxoutputlengthlayout.isHorizontal = true
		maxoutputlengthlayout.Stretch = true
		maxoutputlengthlayout.RelativeSpacing = 0.001
	
		local maxoutputlengthtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), maxoutputlengthlayout.RectTransform), "Max Output Length", nil, nil, GUI.Alignment.CenterLeft)
		
		local maxoutputlength = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), maxoutputlengthlayout.RectTransform), NumberType.Int)
		maxoutputlength.IntValue = component.MaxOutputLength
		maxoutputlength.MinValueInt = -1000000000
		maxoutputlength.MaxValueInt = 1000000000
		maxoutputlength.valueStep = 1
		maxoutputlength.OnValueChanged = function()
			component.MaxOutputLength = maxoutputlength.IntValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".MaxOutputLength", component.MaxOutputLength)
			end
		end	
		
		local outputlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		outputlayout.isHorizontal = true
		outputlayout.Stretch = true
		outputlayout.RelativeSpacing = 0.001
		
		local outputtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), outputlayout.RectTransform), "Output", nil, nil, GUI.Alignment.CenterLeft)
		
		local output = GUI.TextBox(GUI.RectTransform(Vector2(1.2 , 1), outputlayout.RectTransform), "")
		output.text = component.Output
		output.OnTextChangedDelegate = function()
			component.Output = output.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Output", component.Output)
			end
		end
		
		local falseoutputlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		falseoutputlayout.isHorizontal = true
		falseoutputlayout.Stretch = true
		falseoutputlayout.RelativeSpacing = 0.001
		
		local falseoutputtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), falseoutputlayout.RectTransform), "False Output", nil, nil, GUI.Alignment.CenterLeft)
		
		local falseoutput = GUI.TextBox(GUI.RectTransform(Vector2(1.2, 1), falseoutputlayout.RectTransform), "")
		falseoutput.text = component.FalseOutput
		falseoutput.OnTextChangedDelegate = function()
			component.FalseOutput = falseoutput.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".FalseOutput", component.FalseOutput)
			end
		end
		
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end	
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Allow In-game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
		
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.09), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
		
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end
		
	end
	-- Equals Component End --
	-- Xor Component Start --
	local XorComponentfunction = function(component, key)
		
		if EditGUI.Settings.components == false then
			return
		end
		
		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.7), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.13), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
	
		local timeframelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		timeframelayout.isHorizontal = true
		timeframelayout.Stretch = true
		timeframelayout.RelativeSpacing = 0.001
	
		local timeframetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), timeframelayout.RectTransform), "Timeframe", nil, nil, GUI.Alignment.CenterLeft)
		
		local timeframe = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), timeframelayout.RectTransform), NumberType.Float)
		timeframe.DecimalsToDisplay = 2
		timeframe.FloatValue = component.TimeFrame
		timeframe.OnValueChanged = function()
			component.TimeFrame = timeframe.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".TimeFrame", component.TimeFrame)
			end
		end	
		
		local maxoutputlengthlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		maxoutputlengthlayout.isHorizontal = true
		maxoutputlengthlayout.Stretch = true
		maxoutputlengthlayout.RelativeSpacing = 0.001
	
		local maxoutputlengthtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), maxoutputlengthlayout.RectTransform), "Max Output Length", nil, nil, GUI.Alignment.CenterLeft)
		
		local maxoutputlength = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), maxoutputlengthlayout.RectTransform), NumberType.Int)
		maxoutputlength.IntValue = component.MaxOutputLength
		maxoutputlength.MinValueInt = -1000000000
		maxoutputlength.MaxValueInt = 1000000000
		maxoutputlength.valueStep = 1
		maxoutputlength.OnValueChanged = function()
			component.MaxOutputLength = maxoutputlength.IntValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".MaxOutputLength", component.MaxOutputLength)
			end
		end	
		
		local outputlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		outputlayout.isHorizontal = true
		outputlayout.Stretch = true
		outputlayout.RelativeSpacing = 0.001
		
		local outputtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), outputlayout.RectTransform), "Output", nil, nil, GUI.Alignment.CenterLeft)
		
		local output = GUI.TextBox(GUI.RectTransform(Vector2(1.2 , 1), outputlayout.RectTransform), "")
		output.text = component.Output
		output.OnTextChangedDelegate = function()
			component.Output = output.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Output", component.Output)
			end
		end
		
		local falseoutputlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		falseoutputlayout.isHorizontal = true
		falseoutputlayout.Stretch = true
		falseoutputlayout.RelativeSpacing = 0.001
		
		local falseoutputtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), falseoutputlayout.RectTransform), "False Output", nil, nil, GUI.Alignment.CenterLeft)
		
		local falseoutput = GUI.TextBox(GUI.RectTransform(Vector2(1.2, 1), falseoutputlayout.RectTransform), "")
		falseoutput.text = component.FalseOutput
		falseoutput.OnTextChangedDelegate = function()
			component.FalseOutput = falseoutput.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".FalseOutput", component.FalseOutput)
			end
		end
		
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end	
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Allow In-game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
		
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.09), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
		
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end
		
	end
	-- Xor Component End --
	-- Or Component Start --
	local OrComponentfunction = function(component, key)
		
		if EditGUI.Settings.components == false then
			return
		end
		
		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.7), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.13), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
	
		local timeframelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		timeframelayout.isHorizontal = true
		timeframelayout.Stretch = true
		timeframelayout.RelativeSpacing = 0.001
	
		local timeframetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), timeframelayout.RectTransform), "Timeframe", nil, nil, GUI.Alignment.CenterLeft)
		
		local timeframe = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), timeframelayout.RectTransform), NumberType.Float)
		timeframe.DecimalsToDisplay = 2
		timeframe.FloatValue = component.TimeFrame
		timeframe.OnValueChanged = function()
			component.TimeFrame = timeframe.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".TimeFrame", component.TimeFrame)
			end
		end	
		
		local maxoutputlengthlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		maxoutputlengthlayout.isHorizontal = true
		maxoutputlengthlayout.Stretch = true
		maxoutputlengthlayout.RelativeSpacing = 0.001
	
		local maxoutputlengthtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), maxoutputlengthlayout.RectTransform), "Max Output Length", nil, nil, GUI.Alignment.CenterLeft)
		
		local maxoutputlength = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), maxoutputlengthlayout.RectTransform), NumberType.Int)
		maxoutputlength.IntValue = component.MaxOutputLength
		maxoutputlength.MinValueInt = -1000000000
		maxoutputlength.MaxValueInt = 1000000000
		maxoutputlength.valueStep = 1
		maxoutputlength.OnValueChanged = function()
			component.MaxOutputLength = maxoutputlength.IntValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".MaxOutputLength", component.MaxOutputLength)
			end
		end	
		
		local outputlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		outputlayout.isHorizontal = true
		outputlayout.Stretch = true
		outputlayout.RelativeSpacing = 0.001
		
		local outputtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), outputlayout.RectTransform), "Output", nil, nil, GUI.Alignment.CenterLeft)
		
		local output = GUI.TextBox(GUI.RectTransform(Vector2(1.2 , 1), outputlayout.RectTransform), "")
		output.text = component.Output
		output.OnTextChangedDelegate = function()
			component.Output = output.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Output", component.Output)
			end
		end
		
		local falseoutputlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		falseoutputlayout.isHorizontal = true
		falseoutputlayout.Stretch = true
		falseoutputlayout.RelativeSpacing = 0.001
		
		local falseoutputtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), falseoutputlayout.RectTransform), "False Output", nil, nil, GUI.Alignment.CenterLeft)
		
		local falseoutput = GUI.TextBox(GUI.RectTransform(Vector2(1.2, 1), falseoutputlayout.RectTransform), "")
		falseoutput.text = component.FalseOutput
		falseoutput.OnTextChangedDelegate = function()
			component.FalseOutput = falseoutput.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".FalseOutput", component.FalseOutput)
			end
		end
		
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end	
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Allow In-game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
		
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.09), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
		
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end
		
	end
	-- Or Component End --
	-- SignalCheck Component Start --
	local SignalCheckComponentfunction = function(component, key)
		
		if EditGUI.Settings.components == false then
			return
		end
		
		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.7), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.13), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
		
		local maxoutputlengthlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		maxoutputlengthlayout.isHorizontal = true
		maxoutputlengthlayout.Stretch = true
		maxoutputlengthlayout.RelativeSpacing = 0.001
	
		local maxoutputlengthtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), maxoutputlengthlayout.RectTransform), "Max Output Length", nil, nil, GUI.Alignment.CenterLeft)
		
		local maxoutputlength = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), maxoutputlengthlayout.RectTransform), NumberType.Int)
		maxoutputlength.IntValue = component.MaxOutputLength
		maxoutputlength.MinValueInt = -1000000000
		maxoutputlength.MaxValueInt = 1000000000
		maxoutputlength.valueStep = 1
		maxoutputlength.OnValueChanged = function()
			component.MaxOutputLength = maxoutputlength.IntValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".MaxOutputLength", component.MaxOutputLength)
			end
		end	
		
		local outputlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		outputlayout.isHorizontal = true
		outputlayout.Stretch = true
		outputlayout.RelativeSpacing = 0.001
		
		local outputtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), outputlayout.RectTransform), "Output", nil, nil, GUI.Alignment.CenterLeft)
		
		local output = GUI.TextBox(GUI.RectTransform(Vector2(1.2 , 1), outputlayout.RectTransform), "")
		output.text = component.Output
		output.OnTextChangedDelegate = function()
			component.Output = output.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Output", component.Output)
			end
		end
		
		local falseoutputlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		falseoutputlayout.isHorizontal = true
		falseoutputlayout.Stretch = true
		falseoutputlayout.RelativeSpacing = 0.001
		
		local falseoutputtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), falseoutputlayout.RectTransform), "False Output", nil, nil, GUI.Alignment.CenterLeft)
		
		local falseoutput = GUI.TextBox(GUI.RectTransform(Vector2(1.2, 1), falseoutputlayout.RectTransform), "")
		falseoutput.text = component.FalseOutput
		falseoutput.OnTextChangedDelegate = function()
			component.FalseOutput = falseoutput.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".FalseOutput", component.FalseOutput)
			end
		end
		
		local targetsignallayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		targetsignallayout.isHorizontal = true
		targetsignallayout.Stretch = true
		targetsignallayout.RelativeSpacing = 0.001
		
		local targetsignaltext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), targetsignallayout.RectTransform), "Target Signal", nil, nil, GUI.Alignment.CenterLeft)
		
		local targetsignal = GUI.TextBox(GUI.RectTransform(Vector2(1.2, 1), targetsignallayout.RectTransform), "")
		targetsignal.text = component.TargetSignal
		targetsignal.OnTextChangedDelegate = function()
			component.TargetSignal = targetsignal.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".TargetSignal", component.TargetSignal)
			end
		end
		
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end	
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Allow In-game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
		
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.09), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
		
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end
		
	end
	-- SignalCheck Component End --
	-- Concat Component Start --
	local ConcatComponentfunction = function(component, key)
		
		if EditGUI.Settings.components == false then
			return
		end
		
		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.7), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.13), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
		
		local maxoutputlengthlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		maxoutputlengthlayout.isHorizontal = true
		maxoutputlengthlayout.Stretch = true
		maxoutputlengthlayout.RelativeSpacing = 0.001
	
		local maxoutputlengthtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), maxoutputlengthlayout.RectTransform), "Max Output Length", nil, nil, GUI.Alignment.CenterLeft)
		
		local maxoutputlength = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), maxoutputlengthlayout.RectTransform), NumberType.Int)
		maxoutputlength.IntValue = component.MaxOutputLength
		maxoutputlength.MinValueInt = -1000000000
		maxoutputlength.MaxValueInt = 1000000000
		maxoutputlength.valueStep = 1
		maxoutputlength.OnValueChanged = function()
			component.MaxOutputLength = maxoutputlength.IntValue
		end	
		
		local separatorlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		separatorlayout.isHorizontal = true
		separatorlayout.Stretch = true
		separatorlayout.RelativeSpacing = 0.001
		
		local separatortext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), separatorlayout.RectTransform), "Separator", nil, nil, GUI.Alignment.CenterLeft)
		
		local separator = GUI.TextBox(GUI.RectTransform(Vector2(1.2 , 1), separatorlayout.RectTransform), "")
		separator.text = component.Separator
		separator.OnTextChangedDelegate = function()
			component.Separator = separator.text
		end
		
		local timeframelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		timeframelayout.isHorizontal = true
		timeframelayout.Stretch = true
		timeframelayout.RelativeSpacing = 0.001
	
		local timeframetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), timeframelayout.RectTransform), "Timeframe", nil, nil, GUI.Alignment.CenterLeft)
		
		local timeframe = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), timeframelayout.RectTransform), NumberType.Float)
		timeframe.DecimalsToDisplay = 2
		timeframe.FloatValue = component.TimeFrame
		timeframe.OnValueChanged = function()
			component.TimeFrame = timeframe.FloatValue
		end	
		
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
		end	
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Allow In-game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
		end
		
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.09), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
		
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.text
		end
		
	end
	-- Concat Component End --
	-- Memory Component Start --
	local MemoryComponentfunction = function(component, key)
		
		if EditGUI.Settings.components == false then
			return
		end
		
		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.7), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.13), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
		
		local maxvaluelengthlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		maxvaluelengthlayout.isHorizontal = true
		maxvaluelengthlayout.Stretch = true
		maxvaluelengthlayout.RelativeSpacing = 0.001
	
		local maxvaluelengthtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), maxvaluelengthlayout.RectTransform), "Max Value Length", nil, nil, GUI.Alignment.CenterLeft)
		
		local maxvaluelength = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), maxvaluelengthlayout.RectTransform), NumberType.Int)
		maxvaluelength.IntValue = component.MaxValueLength
		maxvaluelength.MinValueInt = -1000000000
		maxvaluelength.MaxValueInt = 1000000000
		maxvaluelength.valueStep = 1
		maxvaluelength.OnValueChanged = function()
			component.MaxValueLength = maxvaluelength.IntValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".MaxValueLength", component.MaxValueLength)
			end
		end	
		
		local valuelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		valuelayout.isHorizontal = true
		valuelayout.Stretch = true
		valuelayout.RelativeSpacing = 0.001
		
		local valuetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), valuelayout.RectTransform), "Value", nil, nil, GUI.Alignment.CenterLeft)
		
		local value = GUI.TextBox(GUI.RectTransform(Vector2(1.2 , 1), valuelayout.RectTransform), "")
		value.text = component.Value
		value.OnTextChangedDelegate = function()
			component.Value = value.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Value", component.Value)
			end
		end
		
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end	
	
		local writeable = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Writeable")
		writeable.Selected = component.Writeable
		writeable.OnSelected = function()
			component.Writeable = writeable.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Writeable", component.Writeable)
			end
		end
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Allow In-game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
		
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.09), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
		
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end
		
	end
	-- Memory Component End --
	-- Subtract Component Start --
	local SubtractComponentfunction = function(component, key)
		
		if EditGUI.Settings.components == false then
			return
		end
		
		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.7), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.13), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
	
		local clampmaxlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		clampmaxlayout.isHorizontal = true
		clampmaxlayout.Stretch = true
		clampmaxlayout.RelativeSpacing = 0.001
	
		local clampmaxtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), clampmaxlayout.RectTransform), "Clamp max", nil, nil, GUI.Alignment.CenterLeft)
		
		local clampmax = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), clampmaxlayout.RectTransform), NumberType.Float)
		clampmax.MinValueFloat = -999999
		clampmax.MaxValueFloat = 999999
		clampmax.valueStep = 0.1
		clampmax.FloatValue = component.Clampmax
		clampmax.OnValueChanged = function()
			component.Clampmax = clampmax.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Clampmax", component.Clampmax)
			end
		end	
	
		local clampminlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		clampminlayout.isHorizontal = true
		clampminlayout.Stretch = true
		clampminlayout.RelativeSpacing = 0.001
	
		local clampmintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), clampminlayout.RectTransform), "Clamp min", nil, nil, GUI.Alignment.CenterLeft)
		
		local clampmin = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), clampminlayout.RectTransform), NumberType.Float)
		clampmin.MinValueFloat = -999999
		clampmin.MaxValueFloat = 999999
		clampmin.valueStep = 0.1
		clampmin.FloatValue = component.Clampmin
		clampmin.OnValueChanged = function()
			component.Clampmin = clampmin.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Clampmin", component.Clampmin)
			end
		end	

		local timeframelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		timeframelayout.isHorizontal = true
		timeframelayout.Stretch = true
		timeframelayout.RelativeSpacing = 0.001
	
		local timeframetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), timeframelayout.RectTransform), "Timeframe", nil, nil, GUI.Alignment.CenterLeft)
		
		local timeframe = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), timeframelayout.RectTransform), NumberType.Float)
		timeframe.DecimalsToDisplay = 2
		timeframe.FloatValue = component.TimeFrame
		timeframe.OnValueChanged = function()
			component.TimeFrame = timeframe.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".TimeFrame", component.TimeFrame)
			end
		end	
		
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end	
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Allow In-game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
		
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.09), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
		
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end
		
	end
	-- Subtract Component End --
	-- Divide Component Start --
	local DivideComponentfunction = function(component, key)
		
		if EditGUI.Settings.components == false then
			return
		end
		
		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.7), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.13), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
	
		local clampmaxlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		clampmaxlayout.isHorizontal = true
		clampmaxlayout.Stretch = true
		clampmaxlayout.RelativeSpacing = 0.001
	
		local clampmaxtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), clampmaxlayout.RectTransform), "Clamp max", nil, nil, GUI.Alignment.CenterLeft)
		
		local clampmax = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), clampmaxlayout.RectTransform), NumberType.Float)
		clampmax.MinValueFloat = -999999
		clampmax.MaxValueFloat = 999999
		clampmax.valueStep = 0.1
		clampmax.FloatValue = component.Clampmax
		clampmax.OnValueChanged = function()
			component.Clampmax = clampmax.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Clampmax", component.Clampmax)
			end
		end	
	
		local clampminlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		clampminlayout.isHorizontal = true
		clampminlayout.Stretch = true
		clampminlayout.RelativeSpacing = 0.001
	
		local clampmintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), clampminlayout.RectTransform), "Clamp min", nil, nil, GUI.Alignment.CenterLeft)
		
		local clampmin = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), clampminlayout.RectTransform), NumberType.Float)
		clampmin.MinValueFloat = -999999
		clampmin.MaxValueFloat = 999999
		clampmin.valueStep = 0.1
		clampmin.FloatValue = component.Clampmin
		clampmin.OnValueChanged = function()
			component.Clampmin = clampmin.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Clampmin", component.Clampmin)
			end
		end	

		local timeframelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		timeframelayout.isHorizontal = true
		timeframelayout.Stretch = true
		timeframelayout.RelativeSpacing = 0.001
	
		local timeframetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), timeframelayout.RectTransform), "Timeframe", nil, nil, GUI.Alignment.CenterLeft)
		
		local timeframe = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), timeframelayout.RectTransform), NumberType.Float)
		timeframe.DecimalsToDisplay = 2
		timeframe.FloatValue = component.TimeFrame
		timeframe.OnValueChanged = function()
			component.TimeFrame = timeframe.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".TimeFrame", component.TimeFrame)
			end
		end	
		
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end	
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Allow In-game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
		
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.09), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
		
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end
		
	end
	-- Divide Component End --
	-- Oscillator Component Start --
	local OscillatorComponentfunction = function(component, key)
		
		if EditGUI.Settings.components == false then
			return
		end
		
		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.7), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.13), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
	
		local outputtypelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		outputtypelayout.isHorizontal = true
		outputtypelayout.Stretch = true
		outputtypelayout.RelativeSpacing = 0.001
	
		local outputtypetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), outputtypelayout.RectTransform), "Output Type", nil, nil, GUI.Alignment.CenterLeft)

		local outputtype = GUI.DropDown(GUI.RectTransform(Vector2(1.2, 1), outputtypelayout.RectTransform), "", 3, nil, false)
		outputtype.AddItem("Pulse", component.WaveType.Pulse)
		outputtype.AddItem("Sawtooth", component.WaveType.Sawtooth)
		outputtype.AddItem("Sine", component.WaveType.Sine)
		outputtype.AddItem("Square", component.WaveType.Square)
		outputtype.AddItem("Triangle", component.WaveType.Triangle)
		outputtype.OnSelected = function (guiComponent, object)
			component.OutputType = object
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".OutputType", component.OutputType)
			end
		end
	
		local frequencylayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		frequencylayout.isHorizontal = true
		frequencylayout.Stretch = true
		frequencylayout.RelativeSpacing = 0.001
	
		local frequencytext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), frequencylayout.RectTransform), "Frequency", nil, nil, GUI.Alignment.CenterLeft)
		
		local frequency = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), frequencylayout.RectTransform), NumberType.Float)
		frequency.DecimalsToDisplay = 2
		frequency.FloatValue = component.Frequency
		frequency.OnValueChanged = function()
			component.Frequency = frequency.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Frequency", component.Frequency)
			end
		end
		
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end	
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Allow In-game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
		
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.09), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
		
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end
		
	end
	-- Oscillator Component End --
	-- Color Component Start --
	local ColorComponentfunction = function(component, key)
		
		if EditGUI.Settings.components == false then
			return
		end
		
		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.52), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
		
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.18), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end	
	
		local usehsv = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Use HSV")
		usehsv.Selected = component.UseHSV
		usehsv.OnSelected = function()
			component.UseHSV = usehsv.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".UseHSV", component.UseHSV)
			end
		end
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Allow In-game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
		
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.145), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
		
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end
		
	end
	-- Color Component End --
	-- Not Component Start --
	local NotComponentfunction = function(component, key)
		
		if EditGUI.Settings.components == false then
			return
		end
		
		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.52), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
		
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.18), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end	
	
		local continuousoutput = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Continuous Output")
		continuousoutput.Selected = component.ContinuousOutput
		continuousoutput.OnSelected = function()
			component.ContinuousOutput = continuousoutput.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".ContinuousOutput", component.ContinuousOutput)
			end
		end
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Allow In-game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
		
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.145), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
		
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end
		
	end
	-- Not Component End --
	-- TrigonometricFunction Component Start --
	local TrigonometricComponentfunction = function(component, key)
		
		if EditGUI.Settings.components == false then
			return
		end
		
		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.52), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
		
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.18), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end	
	
		local useradians = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Use Radians")
		useradians.Selected = component.UseRadians
		useradians.OnSelected = function()
			component.UseRadians = useradians.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".UseRadians", component.UseRadians)
			end
		end
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Allow In-game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
		
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.145), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
		
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end
		
	end
	-- TrigonometricFunction Component End --
	-- Function Component Start --
	local FunctionComponentfunction = function(component, key)
		
		if EditGUI.Settings.components == false then
			return
		end	
		
		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.52), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
		
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.18), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Allow In-game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
		
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.145), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
		
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end
		
	end
	-- Function Component End --
	-- Exponentiation Component Start --
	local ExponentiationComponentfunction = function(component, key)
		
		if EditGUI.Settings.components == false then
			return
		end
		
		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.52), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
		
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.18), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end	
	
		local exponent = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Exponent")
		exponent.Selected = component.Exponent
		exponent.OnSelected = function()
			component.Exponent = exponent.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Exponent", component.Exponent)
			end
		end
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Allow In-game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
		
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.145), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
		
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end
		
	end
	-- Exponentiation Component End --
	-- Modulo Component Start --
	local ModuloComponentfunction = function(component, key)
		
		if EditGUI.Settings.components == false then
			return
		end
		
		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.52), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
		
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.18), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end	
	
		local modulus = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Modulus")
		modulus.Selected = component.Modulus
		modulus.OnSelected = function()
			component.Modulus = modulus.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Modulus", component.Modulus)
			end
		end
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Allow In-game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
		
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.145), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
		
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end
		
	end
	-- Modulo Component End --
	-- Delay Component Start --
	local DelayComponentfunction = function(component, key)
		
		if EditGUI.Settings.components == false then
			return
		end
		
		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.6), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
		
		local delaylayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.09), List.Content.RectTransform), nil)
		delaylayout.isHorizontal = true
		delaylayout.Stretch = true
		delaylayout.RelativeSpacing = 0.001
	
		local delaytext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), delaylayout.RectTransform), "Delay", nil, nil, GUI.Alignment.CenterLeft)
		
		local delay = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), delaylayout.RectTransform), NumberType.Float)
		delay.DecimalsToDisplay = 2
		delay.MinValueFloat = 0
		delay.MaxValueFloat = 60
		delay.valueStep = 0.1
		delay.FloatValue = component.Delay
		delay.OnValueChanged = function()
			component.Delay = delay.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Delay", component.Delay)
			end
		end	
		
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.16), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end
		
		local resetwhensignalreceived = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Reset When Signal Received")
		resetwhensignalreceived.Selected = component.ResetWhenSignalReceived
		resetwhensignalreceived.OnSelected = function()
			component.ResetWhenSignalReceived = resetwhensignalreceived.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".ResetWhenSignalReceived", component.ResetWhenSignalReceived)
			end
		end
		
		local resetwhendifferentsignalreceived = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Reset When Different Signal Received")
		resetwhendifferentsignalreceived.Selected = component.ResetWhenDifferentSignalReceived
		resetwhendifferentsignalreceived.OnSelected = function()
			component.ResetWhenDifferentSignalReceived = resetwhendifferentsignalreceived.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".ResetWhenDifferentSignalReceived", component.ResetWhenDifferentSignalReceived)
			end
		end
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.5), List.Content.RectTransform), "Allow In-game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
		
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.125), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
		
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end
		
	end
	-- Delay Component End --
	-- Relay Component Start --
	local RelayComponentfunction = function(component, key)
		
		if EditGUI.Settings.components == false then
			return
		end
		
		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.95), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.125), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
		
		local maxpowerlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.08), List.Content.RectTransform), nil)
		maxpowerlayout.isHorizontal = true
		maxpowerlayout.Stretch = true
		maxpowerlayout.RelativeSpacing = 0.001
	
		local maxpowertext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), maxpowerlayout.RectTransform), "Max Power", nil, nil, GUI.Alignment.CenterLeft)
		
		local maxpower = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), maxpowerlayout.RectTransform), NumberType.Float)
		maxpower.FloatValue = component.MaxPower
		maxpower.OnValueChanged = function()
			component.MaxPower = maxpower.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".MaxPower", component.MaxPower)
			end
		end
	
		local overloadvoltagelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.08), List.Content.RectTransform), nil)
		overloadvoltagelayout.isHorizontal = true
		overloadvoltagelayout.Stretch = true
		overloadvoltagelayout.RelativeSpacing = 0.001
	
		local overloadvoltagetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), overloadvoltagelayout.RectTransform), "Overload Voltage", nil, nil, GUI.Alignment.CenterLeft)
		
		local overloadvoltage = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), overloadvoltagelayout.RectTransform), NumberType.Float)
		overloadvoltage.FloatValue = component.OverloadVoltage
		overloadvoltage.OnValueChanged = function()
			component.OverloadVoltage = overloadvoltage.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".OverloadVoltage", component.OverloadVoltage)
			end
		end
	
		local fireprobabilitylayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.08), List.Content.RectTransform), nil)
		fireprobabilitylayout.isHorizontal = true
		fireprobabilitylayout.Stretch = true
		fireprobabilitylayout.RelativeSpacing = 0.001
	
		local fireprobabilitytext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), fireprobabilitylayout.RectTransform), "Fire Probability", nil, nil, GUI.Alignment.CenterLeft)
		
		local fireprobability = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), fireprobabilitylayout.RectTransform), NumberType.Float)
		fireprobability.MinValueFloat = 0
		fireprobability.MaxValueFloat = 1
		fireprobability.valueStep = 0.1
		fireprobability.FloatValue = component.FireProbability
		fireprobability.OnValueChanged = function()
			component.FireProbability = fireprobability.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".FireProbability", component.FireProbability)
			end
		end
	
		local minvoltagelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.08), List.Content.RectTransform), nil)
		minvoltagelayout.isHorizontal = true
		minvoltagelayout.Stretch = true
		minvoltagelayout.RelativeSpacing = 0.001
	
		local minvoltagetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), minvoltagelayout.RectTransform), "Min Voltage", nil, nil, GUI.Alignment.CenterLeft)
		
		local minvoltage = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), minvoltagelayout.RectTransform), NumberType.Float)
		minvoltage.FloatValue = component.MinVoltage
		minvoltage.OnValueChanged = function()
			component.MinVoltage = minvoltage.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".MinVoltage", component.MinVoltage)
			end
		end
	
		local powerconsumptionlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.08), List.Content.RectTransform), nil)
		powerconsumptionlayout.isHorizontal = true
		powerconsumptionlayout.Stretch = true
		powerconsumptionlayout.RelativeSpacing = 0.001
	
		local powerconsumptiontext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), powerconsumptionlayout.RectTransform), "Power Consumption", nil, nil, GUI.Alignment.CenterLeft)
		
		local powerconsumption = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), powerconsumptionlayout.RectTransform), NumberType.Float)
		powerconsumption.FloatValue = component.PowerConsumption
		powerconsumption.OnValueChanged = function()
			component.PowerConsumption = powerconsumption.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PowerConsumption", component.PowerConsumption)
			end
		end
	
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.08), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end

		local ison = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Is On")
		ison.Selected = component.IsOn
		ison.OnSelected = function()
			component.IsOn = ison.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".IsOn", component.IsOn)
			end
		end

		local canbeoverloaded = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Can Be Overloaded")
		canbeoverloaded.Selected = component.CanBeOverloaded
		canbeoverloaded.OnSelected = function()
			component.CanBeOverloaded = canbeoverloaded.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBeOverloaded", component.CanBeOverloaded)
			end
		end

		local vulnerabletoemp = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Vulnerable To EMP")
		vulnerabletoemp.Selected = component.VulnerableToEMP
		vulnerabletoemp.OnSelected = function()
			component.VulnerableToEMP = vulnerabletoemp.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".VulnerableToEMP", component.VulnerableToEMP)
			end
		end
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Allow In-Game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
	
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.07), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
	
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.Text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.Text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end

	end
	-- Relay Component End --
	-- Wifi Component Start --
	local WifiComponentfunction = function(component, key)
		
		if EditGUI.Settings.components == false then
			return
		end
		
		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.66), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
	
		local rangelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		rangelayout.isHorizontal = true
		rangelayout.Stretch = true
		rangelayout.RelativeSpacing = 0.001
	
		local rangetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), rangelayout.RectTransform), "Range", nil, nil, GUI.Alignment.CenterLeft)
		
		local range = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), rangelayout.RectTransform), NumberType.Float)
		range.FloatValue = component.Range
		range.OnValueChanged = function()
			component.Range = range.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Range", component.Range)
			end
		end
	
		local channellayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		channellayout.isHorizontal = true
		channellayout.Stretch = true
		channellayout.RelativeSpacing = 0.001
	
		local channeltext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), channellayout.RectTransform), "Channel", nil, nil, GUI.Alignment.CenterLeft)
		
		local channel = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), channellayout.RectTransform), NumberType.Float)
		channel.MinValueFloat = -1000000000
		channel.MaxValueFloat = 1000000000
		channel.valueStep = 1
		channel.FloatValue = component.Channel
		channel.OnValueChanged = function()
			component.Channel = channel.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Channel", component.Channel)
			end
		end
	
		local minchatmessageintervallayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		minchatmessageintervallayout.isHorizontal = true
		minchatmessageintervallayout.Stretch = true
		minchatmessageintervallayout.RelativeSpacing = 0.001
	
		local minchatmessageintervaltext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), minchatmessageintervallayout.RectTransform), "Min Chat Message Interval", nil, nil, GUI.Alignment.CenterLeft)
		
		local minchatmessageinterval = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), minchatmessageintervallayout.RectTransform), NumberType.Float)
		minchatmessageinterval.FloatValue = component.MinChatMessageInterval
		minchatmessageinterval.OnValueChanged = function()
			component.MinChatMessageInterval = minchatmessageinterval.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".MinChatMessageInterval", component.MinChatMessageInterval)
			end
		end
	
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end

		local allowcrossteamcommunication = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Allow Cross-Team Communication")
		allowcrossteamcommunication.Selected = component.AllowCrossTeamCommunication
		allowcrossteamcommunication.OnSelected = function()
			component.AllowCrossTeamCommunication = allowcrossteamcommunication.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowCrossTeamCommunication", component.AllowCrossTeamCommunication)
			end
		end

		local linktochat = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Link to Chat")
		linktochat.Selected = component.LinkToChat
		linktochat.OnSelected = function()
			component.LinkToChat = linktochat.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".LinkToChat", component.LinkToChat)
			end
		end

		local discardduplicatechatmessages = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Discard Duplicate Chat Messages")
		discardduplicatechatmessages.Selected = component.DiscardDuplicateChatMessages
		discardduplicatechatmessages.OnSelected = function()
			component.DiscardDuplicateChatMessages = discardduplicatechatmessages.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".DiscardDuplicateChatMessages", component.DiscardDuplicateChatMessages)
			end
		end
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Allow In-Game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
	
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
	
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.Text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.Text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end

	end
	-- Wifi Component End --
	-- Regex Find Component Start --
	local RegExFindComponentfunction = function(component, key)
		
		if EditGUI.Settings.components == false then
			return
		end
		
		local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), menuList.Content.RectTransform), nil)
		local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")

		local List = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.66), menuList.Content.RectTransform, GUI.Anchor.TopCenter))
		
		local guiElement = {
			listBox = List,
			lineFrame = LineFrame,
		}
		table.insert(componentGUIElements, guiElement)
		
		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), component.Name, nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.3
		maintext.TextColor = Color(255,255,255)
	
		local maxoutputlengthlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		maxoutputlengthlayout.isHorizontal = true
		maxoutputlengthlayout.Stretch = true
		maxoutputlengthlayout.RelativeSpacing = 0.001
	
		local maxoutputlengthtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), maxoutputlengthlayout.RectTransform), "Max Output Length", nil, nil, GUI.Alignment.CenterLeft)
		
		local maxoutputlength = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), maxoutputlengthlayout.RectTransform), NumberType.Int)
		maxoutputlength.IntValue = component.MaxOutputLength
		maxoutputlength.MinValueInt = -1000000000
		maxoutputlength.MaxValueInt = 1000000000
		maxoutputlength.valueStep = 1
		maxoutputlength.OnValueChanged = function()
			component.MaxOutputLength = maxoutputlength.IntValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".MaxOutputLength", component.MaxOutputLength)
			end
		end	
		
		local outputlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		outputlayout.isHorizontal = true
		outputlayout.Stretch = true
		outputlayout.RelativeSpacing = 0.001
		
		local outputtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), outputlayout.RectTransform), "Output", nil, nil, GUI.Alignment.CenterLeft)
		
		local output = GUI.TextBox(GUI.RectTransform(Vector2(1.2 , 1), outputlayout.RectTransform), "")
		output.text = component.Output
		output.OnTextChangedDelegate = function()
			component.Output = output.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Output", component.Output)
			end
		end
		
		local falseoutputlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		falseoutputlayout.isHorizontal = true
		falseoutputlayout.Stretch = true
		falseoutputlayout.RelativeSpacing = 0.001
		
		local falseoutputtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), falseoutputlayout.RectTransform), "False Output", nil, nil, GUI.Alignment.CenterLeft)
		
		local falseoutput = GUI.TextBox(GUI.RectTransform(Vector2(1.2, 1), falseoutputlayout.RectTransform), "")
		falseoutput.text = component.FalseOutput
		falseoutput.OnTextChangedDelegate = function()
			component.FalseOutput = falseoutput.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".FalseOutput", component.FalseOutput)
			end
		end
		
		local expressionlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.11), List.Content.RectTransform), nil)
		expressionlayout.isHorizontal = true
		expressionlayout.Stretch = true
		expressionlayout.RelativeSpacing = 0.001
		
		local expressiontext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), expressionlayout.RectTransform), "Expression", nil, nil, GUI.Alignment.CenterLeft)
		
		local expression = GUI.TextBox(GUI.RectTransform(Vector2(1.2, 1), expressionlayout.RectTransform), "")
		expression.text = component.Expression
		expression.OnTextChangedDelegate = function()
			component.Expression = expression.text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Expression", component.Expression)
			end
		end
	
		local pickingtimelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		pickingtimelayout.isHorizontal = true
		pickingtimelayout.Stretch = true
		pickingtimelayout.RelativeSpacing = 0.001
	
		local pickingtimetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), pickingtimelayout.RectTransform), "Picking Time", nil, nil, GUI.Alignment.CenterLeft)
		
		local pickingtime = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), pickingtimelayout.RectTransform), NumberType.Float)
		pickingtime.FloatValue = component.PickingTime
		pickingtime.OnValueChanged = function()
			component.PickingTime = pickingtime.FloatValue
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".PickingTime", component.PickingTime)
			end
		end

		local usecapturegroup = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Use Capture Group")
		usecapturegroup.Selected = component.UseCaptureGroup
		usecapturegroup.OnSelected = function()
			component.UseCaptureGroup = usecapturegroup.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".UseCaptureGroup", component.UseCaptureGroup)
			end
		end

		local continuousoutput = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Continuous Output")
		continuousoutput.Selected = component.ContinuousOutput
		continuousoutput.OnSelected = function()
			component.ContinuousOutput = continuousoutput.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".ContinuousOutput", component.ContinuousOutput)
			end
		end
	
		local canbepicked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Can Be Picked")
		canbepicked.Selected = component.CanBePicked
		canbepicked.OnSelected = function()
			component.CanBePicked = canbepicked.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".CanBePicked", component.CanBePicked)
			end
		end
		
		local allowingameediting = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), List.Content.RectTransform), "Allow In-Game Editing")
		allowingameediting.Selected = component.AllowInGameEditing
		allowingameediting.OnSelected = function()
			component.AllowInGameEditing = allowingameediting.Selected == true
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".AllowInGameEditing", component.AllowInGameEditing)
			end
		end
	
		local msglayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.1), List.Content.RectTransform), nil)
		msglayout.isHorizontal = true
		msglayout.Stretch = true
		msglayout.RelativeSpacing = 0.001
	
		local msgtext = GUI.TextBlock(GUI.RectTransform(Vector2(0.5, 1), msglayout.RectTransform), "Msg", nil, nil, GUI.Alignment.CenterLeft)
		
		local msg = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), msglayout.RectTransform), "")
		msg.Text = component.Msg
		msg.OnTextChangedDelegate = function()
			component.Msg = msg.Text
			if Game.IsMultiplayer then
				Update.itemupdatevalue.fn(itemedit.ID, key .. ".Msg", component.Msg)
			end
		end

	end
	-- Regex Find Component End --
	
	
	-- Settings Start --
	local Settingsfunction = function()
	
		if settings == false then
			menu.RemoveChild(settingsmenu) 
			return
		end
		
		settingsmenu = GUI.ListBox(GUI.RectTransform(Vector2(0.93, 0.7), menuContent.RectTransform, GUI.Anchor.Center))
		settingsmenu.RectTransform.AbsoluteOffset = Point(0, -17)
	
		local settingsList = GUI.ListBox(GUI.RectTransform(Vector2(1, 1), settingsmenu.Content.RectTransform, GUI.Anchor.TopCenter))

		local maintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.1), settingsList.Content.RectTransform), "Main Settings", nil, nil, GUI.Alignment.Center)
		maintext.TextScale = 1.4
		maintext.TextColor = Color(255,255,255)

		local clientsidetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.08), settingsList.Content.RectTransform), "Clientside Settings", nil, nil, GUI.Alignment.Center)
		clientsidetext.TextColor = Color(255,255,255)

		local targetnoninteractablelayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.07), settingsList.Content.RectTransform), nil)
		targetnoninteractablelayout.isHorizontal = true
		targetnoninteractablelayout.Stretch = true
		targetnoninteractablelayout.RelativeSpacing = 0.001
		
		local targetnoninteractabletext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), targetnoninteractablelayout.RectTransform), "Target Non Interactable", nil, nil, GUI.Alignment.CenterLeft)

		local targetnoninteractabledropdown = GUI.DropDown(GUI.RectTransform(Vector2(1.2, 1), targetnoninteractablelayout.RectTransform), "", 3, nil, false)
		
		if EditGUI.ClientsideSettings.targetnoninteractable == nil then
			targetnoninteractabledropdown.text = "False"
		else
			targetnoninteractable = EditGUI.ClientsideSettings.targetnoninteractable
			targetnoninteractabledropdown.text = EditGUI.ClientsideSettings.targetnoninteractable
		end
		
		targetnoninteractabledropdown.AddItem("False", "False")
		targetnoninteractabledropdown.AddItem("Target Both", "Target Both")
		targetnoninteractabledropdown.AddItem("Target Only Non Interactable", "Target Only Non Interactable")
		targetnoninteractabledropdown.OnSelected = function (guiComponent, object)
			targetnoninteractable = object
			EditGUI.ClientsideSettings.targetnoninteractable = object
		end
		
		local targetlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.07), settingsList.Content.RectTransform), nil)
		targetlayout.isHorizontal = true
		targetlayout.Stretch = true
		targetlayout.RelativeSpacing = 0.001
		
		local targettext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), targetlayout.RectTransform), "Targeting", nil, nil, GUI.Alignment.CenterLeft)

		local targetdropdown = GUI.DropDown(GUI.RectTransform(Vector2(1.2, 1), targetlayout.RectTransform), "", 3, nil, false)
		
		if EditGUI.ClientsideSettings.targetingsetting == nil then
			targetdropdown.text = "Items"
		else
			targetdropdown.text = EditGUI.ClientsideSettings.targetingsetting
		end
		
		targetdropdown.AddItem("Items", "Items")
		targetdropdown.AddItem("Walls", "Walls")
		targetdropdown.AddItem("Hulls", "Hulls")
		targetdropdown.AddItem("Gaps", "Gaps")
		targetdropdown.OnSelected = function (guiComponent, object)
			EditGUI.ClientsideSettings.targetingsetting = object
		end
		
		local tagstotargetlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.07), settingsList.Content.RectTransform), nil)
		tagstotargetlayout.isHorizontal = true
		tagstotargetlayout.Stretch = true
		tagstotargetlayout.RelativeSpacing = 0.001
		local tagstotargettext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), tagstotargetlayout.RectTransform), "Tags To Target", nil, nil, GUI.Alignment.CenterLeft)
		local tagstotarget = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), tagstotargetlayout.RectTransform), "")
		if EditGUI.ClientsideSettings.tagstotarget then
			tagstotarget.Text = EditGUI.ClientsideSettings.tagstotarget
		else
			tagstotarget.Text = ""
		end
		tagstotarget.OnTextChangedDelegate = function()
			EditGUI.ClientsideSettings.tagstotarget = tagstotarget.Text
		end
		
		local movementamountlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.07), settingsList.Content.RectTransform), nil)
		movementamountlayout.isHorizontal = true
		movementamountlayout.Stretch = true
		movementamountlayout.RelativeSpacing = 0.001

		local movementamounttext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), movementamountlayout.RectTransform), "Movement Amount", nil, nil, GUI.Alignment.CenterLeft)
		
		movementamount = GUI.NumberInput(GUI.RectTransform(Vector2(1.2, 1), movementamountlayout.RectTransform), NumberType.Float)	
		movementamount.MinValueFloat = 1
		movementamount.MaxValueFloat = 100
		movementamount.valueStep = 1
		
		if EditGUI.ClientsideSettings.movementamount == nil then
			movementamount.FloatValue = 1
		else
			movementamount.FloatValue = EditGUI.ClientsideSettings.movementamount
		end
		
		movementamount.OnValueChanged = function ()
			EditGUI.ClientsideSettings.movementamount = movementamount.FloatValue
		end
		
		local targetitems = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Target Items")
		
		if EditGUI.ClientsideSettings.targetitems then
			targetitems.Selected = EditGUI.ClientsideSettings.targetitems
		else
			targetitems.Selected = false
		end
		
		targetitems.OnSelected = function ()
			EditGUI.ClientsideSettings.targetitems = targetitems.Selected == true
		end
		
		local targetparentinventory = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Target Parent Inventory")
		
		if EditGUI.ClientsideSettings.targetparentinventory then
			targetparentinventory.Selected = EditGUI.ClientsideSettings.targetparentinventory
		else
			targetparentinventory.Selected = false
		end
		
		targetparentinventory.OnSelected = function ()
			EditGUI.ClientsideSettings.targetparentinventory = targetparentinventory.Selected == true
		end

		local serversidetext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.08), settingsList.Content.RectTransform), "Serverside Settings", nil, nil, GUI.Alignment.Center)
		serversidetext.TextColor = Color(255,255,255)

		local permissiondropdownlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.07), settingsList.Content.RectTransform), nil)
		permissiondropdownlayout.isHorizontal = true
		permissiondropdownlayout.Stretch = true
		permissiondropdownlayout.RelativeSpacing = 0.001
		
		local permissiondropdowntext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), permissiondropdownlayout.RectTransform), "Required Permissions", nil, nil, GUI.Alignment.CenterLeft)

		local permissiondropdown = GUI.DropDown(GUI.RectTransform(Vector2(1.2, 1), permissiondropdownlayout.RectTransform), "", 3, nil, false)
		
		if EditGUI.Settings.permissionsetting == nil then
			permissiondropdown.text = "Above None"
			EditGUI.Settings.permissionsetting = 0
		else
			if EditGUI.Settings.permissionsetting == 0 then
				permissiondropdown.text = "Above None"
			else
				permissiondropdown.text = EditGUI.Settings.permissionsetting
			end
		end
		
		permissiondropdown.AddItem("All", "All")
		permissiondropdown.AddItem("ConsoleCommands", "ConsoleCommands")
		permissiondropdown.AddItem("ManagePermissions", "ManagePermissions")
		permissiondropdown.AddItem("ManageSettings", "ManageSettings")
		permissiondropdown.AddItem("Above None", "0")
		permissiondropdown.AddItem("None", "None")
		permissiondropdown.OnSelected = function (guiComponent, object)
			EditGUI.Settings.permissionsetting = object
		end

		local tagstonottargetlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.07), settingsList.Content.RectTransform), nil)
		tagstonottargetlayout.isHorizontal = true
		tagstonottargetlayout.Stretch = true
		tagstonottargetlayout.RelativeSpacing = 0.001

		local tagstonottargettext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), tagstonottargetlayout.RectTransform), "Tags To Not Target", nil, nil, GUI.Alignment.CenterLeft)
		
		local tagstonottarget = GUI.TextBox(GUI.RectTransform(Vector2(1.5, 1), tagstonottargetlayout.RectTransform), "")
		
		if EditGUI.Settings.tagstonottarget then
			tagstonottarget.Text = EditGUI.Settings.tagstonottarget
		else
			tagstonottarget.Text = ""
		end
		
		tagstonottarget.OnTextChangedDelegate = function()
			EditGUI.Settings.tagstonottarget = tagstonottarget.Text
		end
	
		local allowtargetingnoninteractable = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Allow Targeting Non Interactable")
		if EditGUI.Settings.allowtargetingnoninteractable then
			allowtargetingnoninteractable.Selected = EditGUI.Settings.allowtargetingnoninteractable
		else
			allowtargetingnoninteractable.Selected = false
		end
		allowtargetingnoninteractable.OnSelected = function ()
			EditGUI.Settings.allowtargetingnoninteractable = allowtargetingnoninteractable.Selected == true
		end
		
		local allowtargetingstructures = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Allow Targeting Structures")
		if EditGUI.Settings.allowtargetingstructures then
			allowtargetingstructures.Selected = EditGUI.Settings.allowtargetingstructures
		else
			allowtargetingstructures.Selected = false
		end
		allowtargetingstructures.OnSelected = function ()
			EditGUI.Settings.allowtargetingstructures = allowtargetingstructures.Selected == true
		end
	
		local allowtargetingitems = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Allow Targeting Items")
		if EditGUI.Settings.allowtargetingitems then
			allowtargetingitems.Selected = EditGUI.Settings.allowtargetingitems
		else
			allowtargetingitems.Selected = false
		end
		allowtargetingitems.OnSelected = function ()
			EditGUI.Settings.allowtargetingitems = allowtargetingitems.Selected == true
		end
	
		-- Value Settings --
	
		ValueSettings = function()
		
			local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), settingsList.Content.RectTransform), nil)
			local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")
	
			local subtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.08), settingsList.Content.RectTransform), "Value Settings", nil, nil, GUI.Alignment.Center)
			subtext.TextScale = 1.3
			subtext.TextColor = Color(255,255,255)
		
			local spritedepth = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Sprite Depth Enabled")
			spritedepth.Selected = EditGUI.Settings.spritedepth
			spritedepth.OnSelected = function ()
				EditGUI.Settings.spritedepth = spritedepth.Selected == true
			end
		
			local rotation = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Rotation Enabled")
			rotation.Selected = EditGUI.Settings.rotation
			rotation.OnSelected = function ()
				EditGUI.Settings.rotation = rotation.Selected == true
			end
		
			local scale = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Scale Enabled")
			scale.Selected = EditGUI.Settings.scale
			scale.OnSelected = function ()
				EditGUI.Settings.scale = scale.Selected == true
			end
	
			local scaleeditlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.105), settingsList.Content.RectTransform), nil)
			scaleeditlayout.isHorizontal = true
			scaleeditlayout.Stretch = true
			scaleeditlayout.RelativeSpacing = 0.001
			
			local scalemintext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), scaleeditlayout.RectTransform), "Scale Min", nil, nil, GUI.Alignment.CenterLeft)
		
			local scalemininput = GUI.NumberInput(GUI.RectTransform(Vector2(1, 1), scaleeditlayout.RectTransform), NumberType.Float)
			scalemininput.DecimalsToDisplay = 3
			scalemininput.FloatValue = EditGUI.Settings.scalemin
			scalemininput.MinValueFloat = 0.001
			scalemininput.MaxValueFloat = 0.999
			scalemininput.valueStep = 0.1
			scalemininput.OnValueChanged = function ()
				EditGUI.Settings.scalemin = scalemininput.FloatValue
			end
	
			local scalemaxtext = GUI.TextBlock(GUI.RectTransform(Vector2(1, 1), scaleeditlayout.RectTransform), "Scale Max", nil, nil, GUI.Alignment.CenterLeft)
		
			local scalemaxinput = GUI.NumberInput(GUI.RectTransform(Vector2(1, 1), scaleeditlayout.RectTransform), NumberType.Float)
			scalemaxinput.DecimalsToDisplay = 3
			scalemaxinput.FloatValue = EditGUI.Settings.scalemax
			scalemaxinput.MinValueFloat = 0.001
			scalemaxinput.MaxValueFloat = 0.999
			scalemaxinput.valueStep = 0.1
			scalemaxinput.OnValueChanged = function ()
				EditGUI.Settings.scalemax = scalemaxinput.FloatValue
			end	
		
			local condition = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Condition Enabled")
			condition.Selected = EditGUI.Settings.condition
			condition.OnSelected = function ()
				EditGUI.Settings.condition = condition.Selected == true
			end
		
			local spritecolor = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Sprite Color Enabled")
			spritecolor.Selected = EditGUI.Settings.spritecolor
			spritecolor.OnSelected = function ()
				EditGUI.Settings.spritecolor = spritecolor.Selected == true
			end
		
			local alpha = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Alpha Enabled")
			alpha.Selected = EditGUI.Settings.alpha
			alpha.OnSelected = function ()
				EditGUI.Settings.alpha = alpha.Selected == true
			end

			local tags = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Tags Enabled")
			tags.Selected = EditGUI.Settings.tags
			tags.OnSelected = function ()
				EditGUI.Settings.tags = tags.Selected == true
			end
		
			local description = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Description Enabled")
			description.Selected = EditGUI.Settings.description
			description.OnSelected = function ()
				EditGUI.Settings.description = description.Selected == true
			end
		
			local noninteractable = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Non Interactable Enabled")
			noninteractable.Selected = EditGUI.Settings.noninteractable
			noninteractable.OnSelected = function ()
				EditGUI.Settings.noninteractable = noninteractable.Selected == true
			end
			
			local nonplayerteaminteractable = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Non-Player Team Interactable Enabled")
			nonplayerteaminteractable.Selected = EditGUI.Settings.nonplayerteaminteractable
			nonplayerteaminteractable.OnSelected = function ()
				EditGUI.Settings.nonplayerteaminteractable = nonplayerteaminteractable.Selected == true
			end
			
			local invulnerabletodamage = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Invulnerable to Damage Enabled")
			invulnerabletodamage.Selected = EditGUI.Settings.invulnerabletodamage
			invulnerabletodamage.OnSelected = function ()
				EditGUI.Settings.invulnerabletodamage = invulnerabletodamage.Selected == true
			end
		
			local displaysidebysidewhenlinked = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Display Side By Side When Linked Enabled")
			displaysidebysidewhenlinked.Selected = EditGUI.Settings.displaysidebysidewhenlinked
			displaysidebysidewhenlinked.OnSelected = function ()
				EditGUI.Settings.displaysidebysidewhenlinked = displaysidebysidewhenlinked.Selected == true
			end
			
			local hiddeningame = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Hidden In Game Enabled")
			hiddeningame.Selected = EditGUI.Settings.hiddeningame
			hiddeningame.OnSelected = function ()
				EditGUI.Settings.hiddeningame = hiddeningame.Selected == true
			end
		
			local mirror = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Mirror Enabled")
			mirror.Selected = EditGUI.Settings.mirror
			mirror.OnSelected = function ()
				EditGUI.Settings.mirror = mirror.Selected == true
			end
		
			-- Components --
			
			local LineFrame = GUI.Frame(GUI.RectTransform(Vector2(1, 0.1), settingsList.Content.RectTransform), nil)
			local Line = GUI.Frame(GUI.RectTransform(Vector2(1, 1), LineFrame.RectTransform, GUI.Anchor.Center), "HorizontalLine")
	
			local subtext2 = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.08), settingsList.Content.RectTransform), "Enabled Components", nil, nil, GUI.Alignment.Center)
			subtext2.TextScale = 1.3
			subtext2.TextColor = Color(255,255,255)
			
			local lightcomponent = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Light Component Enabled")
			lightcomponent.Selected = EditGUI.Settings.lightcomponent
			lightcomponent.OnSelected = function ()
				EditGUI.Settings.lightcomponent = lightcomponent.Selected == true
			end
		
			local holdable = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Holdable Component Enabled")
			holdable.Selected = EditGUI.Settings.holdable
			holdable.OnSelected = function ()
				EditGUI.Settings.holdable = holdable.Selected == true
			end
			
			local connectionpanel = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "ConnectionPanel Component Enabled")
			connectionpanel.Selected = EditGUI.Settings.connectionpanel
			connectionpanel.OnSelected = function ()
				EditGUI.Settings.connectionpanel = connectionpanel.Selected == true
			end
			
			local fabricator = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Fabricator Component Enabled")
			fabricator.Selected = EditGUI.Settings.fabricator
			fabricator.OnSelected = function ()
				EditGUI.Settings.fabricator = fabricator.Selected == true
			end
			
			local deconstructor = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Deconstructor Component Enabled")
			deconstructor.Selected = EditGUI.Settings.deconstructor
			deconstructor.OnSelected = function ()
				EditGUI.Settings.deconstructor = deconstructor.Selected == true
			end
			
			local reactor = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Reactor Component Enabled")
			reactor.Selected = EditGUI.Settings.reactor
			reactor.OnSelected = function ()
				EditGUI.Settings.reactor = reactor.Selected == true
			end
			
			local oxygengenerator = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "OxygenGenerator Component Enabled")
			oxygengenerator.Selected = EditGUI.Settings.oxygengenerator
			oxygengenerator.OnSelected = function ()
				EditGUI.Settings.oxygengenerator = oxygengenerator.Selected == true
			end

			local sonar = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Sonar Component Enabled")
			sonar.Selected = EditGUI.Settings.sonar
			sonar.OnSelected = function ()
				EditGUI.Settings.sonar = sonar.Selected == true
			end
			
			local repairable = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Repairable Component Enabled")
			repairable.Selected = EditGUI.Settings.repairable
			repairable.OnSelected = function ()
				EditGUI.Settings.repairable = repairable.Selected == true
			end
			
			local powertransfer = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "PowerTransfer Component Enabled")
			powertransfer.Selected = EditGUI.Settings.powertransfer
			powertransfer.OnSelected = function ()
				EditGUI.Settings.powertransfer = powertransfer.Selected == true
			end
			
			local itemcontainer = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "ItemContainer Component Enabled")
			itemcontainer.Selected = EditGUI.Settings.itemcontainer
			itemcontainer.OnSelected = function ()
				EditGUI.Settings.itemcontainer = itemcontainer.Selected == true
			end	
			
			local door = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Door Component Enabled")
			door.Selected = EditGUI.Settings.door
			door.OnSelected = function ()
				EditGUI.Settings.door = door.Selected == true
			end
			
			local itemlabel = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "ItemLabel Component Enabled")
			itemlabel.Selected = EditGUI.Settings.itemlabel
			itemlabel.OnSelected = function ()
				EditGUI.Settings.itemlabel = itemlabel.Selected == true
			end
			
			local quality = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Quality Component Enabled")
			quality.Selected = EditGUI.Settings.quality
			quality.OnSelected = function ()
				EditGUI.Settings.quality = quality.Selected == true
			end
			
			local components = GUI.TickBox(GUI.RectTransform(Vector2(1, 0.2), settingsList.Content.RectTransform), "Components Enabled")
			components.Selected = EditGUI.Settings.components
			components.OnSelected = function ()
				EditGUI.Settings.components = components.Selected == true
			end
			
		end
		
		if EditGUI.Settings.allowtargetingnoninteractable == true then
			targetnoninteractablelayout.visible = true
		else
			targetnoninteractablelayout.visible = false
		end
		if EditGUI.Settings.allowtargetingstructures == true then
			targetlayout.visible = true
		else
			targetlayout.visible = false
		end
		if EditGUI.Settings.allowtargetingitems == true then
			targetitems.visible = true
		else
			targetitems.visible = false
		end
		
		if Game.IsMultiplayer then
			if EditGUI.owner.HasPermission(ClientPermissions.All) then
				permissiondropdownlayout.visible = true
				allowtargetingitems.visible = true
				allowtargetingnoninteractable.visible = true
				tagstonottargetlayout.visible = true
				ValueSettings()
			else
				permissiondropdownlayout.visible = false
				allowtargetingitems.visible = false
				allowtargetingnoninteractable.visible = false
				tagstonottargetlayout.visible = false
			end
		else
			ValueSettings()
		end
		
	end
	-- Settings End --
	
	Links = function()
		if itemedit1 and itemedit2 ~= nil then
			local isLinked = false
    
			for key, value in pairs(itemedit1.linkedTo) do
				if value == itemedit2 then
					isLinked = true
					break
				end
			end
		
			if isLinked then
				Unlink = true
				linktargets.Text = "Unlink"
			else
				Unlink = false
				linktargets.Text = "Link"
			end
		end
	end
	
	local functionTable = {
	LightComponent = LightComponentfunction,
	Holdable = Holdablefunction,
	ConnectionPanel = ConnectionPanelfunction,
	Fabricator = Fabricatorfunction,
	Deconstructor = Deconstructorfunction,
	Reactor = Reactorfunction,
	OxygenGenerator = OxygenGeneratorfunction,
	Sonar = Sonarfunction,
	Repairable = Repairablefunction,
	ItemContainer = ItemContainerfunction,
	Door = Doorfunction,
	ItemLabel = ItemLabelfunction,
	Quality = Qualityfunction,
	AndComponent = AndComponentfunction,
	GreaterComponent = GreaterComponentfunction,
	EqualsComponent = EqualsComponentfunction,
	XorComponent = XorComponentfunction,
	OrComponent = OrComponentfunction,
	SignalCheckComponent = SignalCheckComponentfunction,
	ConcatComponent = ConcatComponentfunction,
	MemoryComponent = MemoryComponentfunction,
	SubtractComponent = SubtractComponentfunction,
	DivideComponent = DivideComponentfunction,
	OscillatorComponent = OscillatorComponentfunction,
	ColorComponent = ColorComponentfunction, 
	NotComponent = NotComponentfunction, 
	TrigonometricFunctionComponent = TrigonometricComponentfunction,
	FunctionComponent = FunctionComponentfunction,
	ExponentiationComponent = ExponentiationComponentfunction,
	ModuloComponent = ModuloComponentfunction,
	DelayComponent = DelayComponentfunction,
	RelayComponent = RelayComponentfunction,
	WifiComponent = WifiComponentfunction,
	RegExFindComponent = RegExFindComponentfunction,
	}

	local reloadvalues = function()
		menuContent.RemoveChild(menuList)
		MainComponentfunction()
		componentGUIElements = {}
		if targeting == "items" then
			for key, value in ipairs(itemedit.Components) do
				if value.Name ~= "CustomInterface" then
					local functionToCall = functionTable[value.Name]
					if functionToCall and type(functionToCall) == "function" then

						componentGUIElements[value.Name] = value

						local component = itemedit.Components[key]
						functionToCall(component, key)
					end
				end
			end
		end
		Links()
	end

	local miscbuttons = function()
	
		local misc = GUI.ListBox(GUI.RectTransform(Vector2(0.93, 0.124), menuContent.RectTransform, GUI.Anchor.BottomCenter))
		misc.RectTransform.AbsoluteOffset = Point(0, 23)


		local misclayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.5), misc.Content.RectTransform), nil)
		misclayout.isHorizontal = true
		misclayout.Stretch = true
		misclayout.RelativeSpacing = 0.004

		local apply = GUI.Button(GUI.RectTransform(Vector2(0.482, 0.2), misclayout.RectTransform), "Apply")
		apply.OnClicked = function()
			EditGUI.networkstart()
			if Game.IsMultiplayer and itemedit then
				local itemeditnetwork = Networking.Start("servermsgstart")
					itemeditnetwork.WriteUInt16(UShort(itemedit.ID))
		
					itemeditnetwork.WriteSingle(itemedit.SpriteDepth)
					itemeditnetwork.WriteSingle(itemedit.Rotation)
					itemeditnetwork.WriteSingle(itemedit.Scale)
					itemeditnetwork.WriteSingle(itemedit.Condition)
					itemeditnetwork.WriteString(itemedit.Tags)
					itemeditnetwork.WriteBoolean(itemedit.NonInteractable)
					itemeditnetwork.WriteBoolean(itemedit.NonPlayerTeamInteractable)
					itemeditnetwork.WriteBoolean(itemedit.InvulnerableToDamage)
					itemeditnetwork.WriteBoolean(itemedit.DisplaySideBySideWhenLinked)
					itemeditnetwork.WriteBoolean(itemedit.HiddenInGame)
				Networking.Send(itemeditnetwork)
			end
		end
			
		linktargets = GUI.Button(GUI.RectTransform(Vector2(0.482, 0.2), misclayout.RectTransform), "None")
		linktargets.OnClicked = function()
			if itemedit1 == nil or itemedit2 == nil then
				return
			end
		
			if not itemedit1.Linkable then
				EditGUI.AddMessage(itemedit1.Name .. " is not Linkable", EditGUI.owner)
				return
			end
			if not itemedit2.Linkable then
				EditGUI.AddMessage(itemedit2.Name .. " is not Linkable", EditGUI.owner)
				return
			end
			
			if Unlink == true then
				if CLIENT and Game.IsMultiplayer then
					local msg = Networking.Start("linkremove")
						msg.WriteUInt16(UShort(itemedit1.ID))
						msg.WriteUInt16(UShort(itemedit2.ID))
					Networking.Send(msg)
					links = true
				else
				itemedit1.RemoveLinked(itemedit2)
				itemedit2.RemoveLinked(itemedit1)
				Links()
				end
			else
				if CLIENT and Game.IsMultiplayer then
					local msg = Networking.Start("linkadd")
						msg.WriteUInt16(UShort(itemedit1.ID))
						msg.WriteUInt16(UShort(itemedit2.ID))
					Networking.Send(msg)
					links = true
				else
				itemedit1.AddLinked(itemedit2)
				itemedit2.AddLinked(itemedit1)
				Links()
				end
			end
		end
		
		local settingsbutton = GUI.Button(GUI.RectTransform(Vector2(0.482, 0.2), misclayout.RectTransform), "Settings")
		settingsbutton.OnClicked = function()
			if settings == true then
				settings = false
				Settingsfunction()
			else
				settings = true
				Settingsfunction()
			end
		end

		closeButton = GUI.Button(GUI.RectTransform(Vector2(1, 1), misc.Content.RectTransform), "Close", GUI.Alignment.Center)
		closeButton.OnClicked = function ()
			frame.ClearChildren()
			menu = nil
			itemedit = nil
			itemedit1 = nil
			itemedit2 = nil
			settings = false
			itemmovekey = false
			Hook.Remove("keyUpdate", "itemmovekey")
		end
	
	end

	local itemeditbuttons = function()
	
		local targets = GUI.ListBox(GUI.RectTransform(Vector2(0.93, 0.1), menuContent.RectTransform, GUI.Anchor.TopCenter))
		targets.RectTransform.AbsoluteOffset = Point(0, 17)

		local chooseitem = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.3), targets.Content.RectTransform), "Choose What Item To Edit", nil, nil, GUI.Alignment.Center)

		local itemeditlayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.5), targets.Content.RectTransform), nil)
		itemeditlayout.isHorizontal = true
		itemeditlayout.Stretch = true
		itemeditlayout.RelativeSpacing = 0.008


		itemeditbutton1 = GUI.Button(GUI.RectTransform(Vector2(0.482, 0.2), itemeditlayout.RectTransform), "None")
		itemeditbutton1.OnClicked = function()
			check = true
			itemeditbutton1.TextColor = Color((10), (10), (100))
			itemeditbutton2.TextColor = Color((16), (34), (33))
			if itemedit1 ~= nil then
				itemname.Text = itemedit1.Name
				itemedit = itemedit1
				reloadvalues()
				itemname.Text = itemedit1.Name
				settings = false
				Settingsfunction()
			end
		end
		
	    itemeditbutton2 = GUI.Button(GUI.RectTransform(Vector2(0.482, 0.2), itemeditlayout.RectTransform), "None")
		itemeditbutton2.OnClicked = function()	
			check = false
			itemeditbutton1.TextColor = Color((16), (34), (33))
			itemeditbutton2.TextColor = Color((10), (10), (100))
			if itemedit2 ~= nil then
				itemname.Text = itemedit2.Name
				itemedit = itemedit2
				reloadvalues()
				itemname.Text = itemedit2.Name
				settings = false
				Settingsfunction()
			end
		end
	
	end

	Hook.Add("Lua_Editor", "luaeditor", function(statusEffect, deltaTime, item)
		EditGUI.owner = FindClientCharacter(item.ParentInventory.Owner)
		local target = findtarget.findtarget(item)
		-- Start Of Checks
		
		if item.ParentInventory.Owner ~= Character.Controlled then
			return
		end
		
		if Game.IsMultiplayer then
			if EditGUI.Settings.permissionsetting ~= 0 then
				if not EditGUI.owner.HasPermission(ClientPermissions[EditGUI.Settings.permissionsetting]) then
					EditGUI.AddMessage("Insuffient Permissions", EditGUI.owner)
					return
				end
			else
				if EditGUI.owner.Permissions == 0 then
					EditGUI.AddMessage("Insuffient Permissions", EditGUI.owner)
					return
				end
			end
		end
	
		if target == nil then
			if menu == nil then
				MainComponentfunction()
				itemeditbuttons()
				miscbuttons()
			end
			EditGUI.AddMessage("No item found", EditGUI.owner)
			return
		end
	
		if target == itemedit1 or target == itemedit2 then
			EditGUI.AddMessage("Targeted items cannot be the same", EditGUI.owner)
			return
		end
		
		if EditGUI.ClientsideSettings.targetingsetting == "Walls" and EditGUI.Settings.allowtargetingstructures == true then
			targeting = "walls"
		elseif EditGUI.ClientsideSettings.targetingsetting == "Hulls" and EditGUI.Settings.allowtargetingstructures == true then
			targeting = "hulls"
		elseif EditGUI.ClientsideSettings.targetingsetting == "Gaps" and EditGUI.Settings.allowtargetingstructures == true then
			targeting = "gaps"
		else
			targeting = "items"
		end
		
		if check == true then
			itemedit1 = target
			itemedit = itemedit1
		else
			itemedit2 = target
			itemedit = itemedit2
		end
	
		if menu == nil then
			MainComponentfunction()
			itemeditbuttons()
			miscbuttons()
		end
	
		reloadvalues()
	
		if itemedit == nil then
			return
		end
	
		if itemedit2 ~= nil then
		Links()
		end

		if check == true then
			itemedit1 = target
			itemedit = itemedit1
			itemeditbutton1.Text = itemedit1.Name
			itemname.Text = itemedit1.Name
			itemeditbutton1.TextColor = Color((10), (10), (100))
			itemeditbutton2.TextColor = Color((16), (34), (33))
		else
			itemedit2 = target
			itemedit = itemedit2
			itemeditbutton2.Text = itemedit2.Name
			itemname.Text = itemedit2.Name
			itemeditbutton1.TextColor = Color((16), (34), (33))
			itemeditbutton2.TextColor = Color((10), (10), (100))
		end
	
		

		if itemmovekey ~= true then
			itemmovekey = true
			local timer = 0
			local interval = 0.15
			Hook.Add("keyUpdate", "itemmovekey", function (keyargs)
				timer = timer + keyargs

				if timer >= interval then
					if PlayerInput.KeyDown(Keys.Up) then 
						if Game.IsMultiplayer then
							Update.itemupdatevalue.fn(itemedit.ID, "Move", 0, EditGUI.ClientsideSettings.movementamount)
						else
							itemedit.Move(Vector2(0, EditGUI.ClientsideSettings.movementamount), false)
						end
					end

					if PlayerInput.KeyDown(Keys.Down) then 
						if Game.IsMultiplayer then
							Update.itemupdatevalue.fn(itemedit.ID, "Move", 0, -EditGUI.ClientsideSettings.movementamount)
						else
							itemedit.Move(Vector2(0, -EditGUI.ClientsideSettings.movementamount), false)
						end
					end

					if PlayerInput.KeyDown(Keys.Left) then  
						if Game.IsMultiplayer then
							Update.itemupdatevalue.fn(itemedit.ID, "Move", -EditGUI.ClientsideSettings.movementamount, 0)
						else
							itemedit.Move(Vector2(-EditGUI.ClientsideSettings.movementamount, 0), false)
						end
					end

					if PlayerInput.KeyDown(Keys.Right) then 
						if Game.IsMultiplayer then
							Update.itemupdatevalue.fn(itemedit.ID, "Move", EditGUI.ClientsideSettings.movementamount, 0)
						else
							itemedit.Move(Vector2(EditGUI.ClientsideSettings.movementamount, 0), false)
						end
					end

					timer = 0
				end
			end)
		end
			
	end)
	
	Hook.Patch("Barotrauma.GameScreen", "AddToGUIUpdateList", function()
		frame.AddToGUIUpdateList()
	end)

	Hook.Patch("Barotrauma.SubEditorScreen", "AddToGUIUpdateList", function()
		frame.AddToGUIUpdateList()
	end)
	
	

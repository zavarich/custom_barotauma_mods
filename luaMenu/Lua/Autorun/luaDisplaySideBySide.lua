local findtarget = dofile(... .. "/Lua/findtarget.lua")

local function AddMessage(text, client)
    local message = ChatMessage.Create("Lua Linker", text, ChatMessageType.Default, nil, nil)
    message.Color = Color(60, 100, 255)

    if CLIENT then
        Game.ChatBox.AddMessage(message)
    else
        Game.SendDirectChatMessage(message, client)
    end
end

local linksDisplaySideBySide = {}

Hook.Add("luaDisplaySideBySide.onUse", "lualinker.luaDisplaySideBySide",function(statusEffect, delta, item)
    local target = findtarget.findtarget(item)
    if CLIENT and Game.IsMultiplayer then 
        return
    end
    local owner = findtarget.FindClientCharacter(item.ParentInventory.Owner)

    if target == nil then
        AddMessage("No item found", owner)
        return
    end

    if linksDisplaySideBySide[item] == nil then
        linksDisplaySideBySide[item] = target
        -- AddMessage(string.format("Link Start: \"%s\"", target.Name), owner)

        if target.DisplaySideBySideWhenLinked == true then

            target.DisplaySideBySideWhenLinked = false
            AddMessage(string.format(
                           "Removed DisplaySideBySideWhenLinked from \"%s\"",
                           target.Name), owner)

            if SERVER then
                -- lets send a net message to all clients so they remove our DisplaySideBySideWhenLinked
                local msg = Networking.Start("luaDisplaySideBySide.remove")
                msg.WriteUInt16(UShort(target.ID))
                Networking.Send(msg)
            end

            linksDisplaySideBySide[item] = nil
            return
        else

            -- target.AddLinked(otherTarget)
            -- otherTarget.AddLinked(target)
            -- otherTarget.DisplaySideBySideWhenLinked = true

            target.DisplaySideBySideWhenLinked = true
            AddMessage(string.format(
                           "Added DisplaySideBySideWhenLinked to \"%s\"",
                           target.Name), owner)

            if SERVER then
                -- lets send a net message to all clients so they add our DisplaySideBySideWhenLinked
                local msg = Networking.Start("luaDisplaySideBySide.add")
                msg.WriteUInt16(UShort(target.ID))
                Networking.Send(msg)
            end

            linksDisplaySideBySide[item] = nil
            return
        end
    end
end)

if CLIENT and Game.IsMultiplayer then
    Networking.Receive("luaDisplaySideBySide.add", function(msg)
        local target = Entity.FindEntityByID(msg.ReadUInt16())

        target.DisplaySideBySideWhenLinked = true
    end)

    Networking.Receive("luaDisplaySideBySide.remove", function(msg)
        local target = Entity.FindEntityByID(msg.ReadUInt16())

        target.DisplaySideBySideWhenLinked = false
    end)
end

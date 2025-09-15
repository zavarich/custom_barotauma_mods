-- TODO add some comments and clean up the code, this is bad for now lol
-- add split up to funcion's file and the file with hooks and shit

local findtarget = dofile(... .. "/Lua/findtarget.lua")

local function LinkAdd(target, otherTarget)
    target.AddLinked(otherTarget)
    otherTarget.AddLinked(target)
    otherTarget.DisplaySideBySideWhenLinked = true
    target.DisplaySideBySideWhenLinked = true
end

local function LinkRemove(target, otherTarget)
    target.RemoveLinked(otherTarget)
    otherTarget.RemoveLinked(target)
end

local function AddMessage(text, client)
    local message = ChatMessage.Create("Lua Linker", text, ChatMessageType.Default, nil, nil)
    message.Color = Color(60, 100, 255)

    if CLIENT then
        Game.ChatBox.AddMessage(message)
    else
        Game.SendDirectChatMessage(message, client)
    end
end

local links = {}

Hook.Add("luaLinker.onUse", "lualinker.luaLinker", function(statusEffect, delta, item)
    local target = findtarget.findtarget(item)
    if CLIENT and Game.IsMultiplayer then 
        return
    end
    local owner = findtarget.FindClientCharacter(item.ParentInventory.Owner)

    if target == nil then
        AddMessage("No item found", owner)
        return
    end

    if links[item] == nil then
        links[item] = target
        AddMessage(string.format("Link Start: \"%s\"", target.Name), owner)
        findtarget.currsor_pos = 0
    else
        local otherTarget = links[item]

        if otherTarget == target then
            AddMessage("The linked items cannot be the same", owner)
            links[item] = nil
            return
        end

        for key, value in pairs(target.linkedTo) do
            if value == otherTarget then
                LinkRemove(target, otherTarget)

                AddMessage(string.format("Removed link from \"%s\" and \"%s\"", target.Name, otherTarget.Name), owner)
				links[item] = nil

                if SERVER then
                    -- lets send a net message to all clients so they remove our link
                    local msg = Networking.Start("lualinker.remove")
                    msg.WriteUInt16(UShort(target.ID))
                    msg.WriteUInt16(UShort(otherTarget.ID))
                    Networking.Send(msg)
                end

                return
            end
        end

        LinkAdd(target, otherTarget)

        local text = string.format("Linked \"%s\" into \"%s\"", otherTarget.Name, target.Name)
        AddMessage(text, owner)

        if SERVER then
            -- lets send a net message to all clients so they add our link
            local msg = Networking.Start("lualinker.add")
            msg.WriteUInt16(UShort(target.ID))
            msg.WriteUInt16(UShort(otherTarget.ID))
            Networking.Send(msg)
        end

        links[item] = nil
        findtarget.currsor_pos = 0
    end
end)

if CLIENT and Game.IsMultiplayer then
    Networking.Receive("lualinker.add", function (msg)
        local target = Entity.FindEntityByID(msg.ReadUInt16())
        local otherTarget = Entity.FindEntityByID(msg.ReadUInt16())
        LinkAdd(target, otherTarget)
    end)

    Networking.Receive("lualinker.remove", function (msg)
        local target = Entity.FindEntityByID(msg.ReadUInt16())
        local otherTarget = Entity.FindEntityByID(msg.ReadUInt16())
        LinkRemove(target, otherTarget)
    end)
end
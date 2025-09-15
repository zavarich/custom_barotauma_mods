LuaUserData.MakeFieldAccessible(Descriptors['Barotrauma.ItemInventory'], 'slots')

local MagState={}
-- 按R换弹补丁，使换弹动画始终生效
local function reInputMag(handItem, character)
    if not handItem then return end
    if not handItem.HasTag("weapon") then return end
    local handInv = handItem.OwnInventory
	if not handInv then return end
    local itemContainer = handInv.Container
    if not itemContainer then return end
    local handInvSlots = handInv.slots
    -- local index = math.max(itemContainer.ContainedStateIndicatorSlot + 1 , 1)   -- 准确定位弹匣的slot
    local index = 1
    for _ in itemContainer.slotRestrictions do
    local Mag = handInvSlots[index].items[1]
    if (not Mag) or (Mag and not Mag.OwnInventory) then return end
    if not MagState[handItem.ID] then
        MagState[handItem.ID] = { isExecuted = false, Mag = nil }
    end
    if Mag.ConditionIncreasedRecently and not MagState[handItem.ID].isExecuted then
        -- print("Mag ConditionIncreasedRecently")
        MagState[handItem.ID].isExecuted = true
        MagState[handItem.ID].Mag = Mag
        -- if Game.IsMultiplayer then
        --     unloadMag(Mag, character)
        -- end
        handItem.OwnInventory.TryPutItem(Mag, index-1, true, false, character, true, false)
        -- itemContainer.OnItemContained(Mag)
    end
    index = index + 1
    end
end

Hook.Patch("Barotrauma.Character", "Control", function(instance, ptable)
    local character = instance
    if not character or not character.Inventory then return end
    local rightHand = character.Inventory.GetItemInLimbSlot(InvSlotType.RightHand)
    local leftHand = character.Inventory.GetItemInLimbSlot(InvSlotType.LeftHand)
    if not rightHand and not leftHand then return end
    if rightHand ~= nil and leftHand ~= nil and rightHand.ID == leftHand.ID then  -- 如果为双手武器
        reInputMag(rightHand, character)
    else                                                                          -- 如果为单手武器或者双持武器
        reInputMag(rightHand, character)
        reInputMag(leftHand, character)
    end
    for _, state in pairs(MagState) do
        if state.Mag and not state.Mag.ConditionIncreasedRecently then
            state.isExecuted = false
            state.Mag = nil
        end
    end
end, Hook.HookMethodType.After)
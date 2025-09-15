if SERVER then return end

LuaUserData.RegisterType("Barotrauma.Items.Components.ItemContainer+SlotRestrictions")
LuaUserData.RegisterType('System.Collections.Immutable.ImmutableArray`1[[Barotrauma.Items.Components.ItemContainer+SlotRestrictions, Barotrauma]]')
LuaUserData.MakeFieldAccessible(Descriptors['Barotrauma.Items.Components.ItemContainer'], 'slotRestrictions')
LuaUserData.MakeFieldAccessible(Descriptors['Barotrauma.ItemInventory'], 'slots')
LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.CharacterInventory"], "slots")

    -- 配置重试参数
    local RETRY_CONFIG = {
        INTERVAL = 0.3,      -- 重试间隔(秒)
        MAX_ATTEMPTS = 3,     -- 最大尝试次数
        VALIDITY_DURATION = 5,-- 记录有效期(秒)
        GENERATION_INTERVAL = 0.5 -- 分代时间间隔
    }

    -- 状态存储表
    local retryQueue = {} -- 结构: 
    -- {
    --     [magID] = 
    --     {
    --         generations = 
    --         {
    --             [generationID] = { attempts, nextAttempt, expiry },
    --             ...
    --         },
    --         mag = entityRef
    --     },
    --     ...
    -- }

local function isSlotFull(slotRestriction, slot)
    return slotRestriction.MaxStackSize - #slot.items
end

local function tryPutItemsInInventory(character, hand, anotherhand, handInv, handIEnumerable, anotherhandIEnumerable)

    -- 重试队列管理
    local function addToRetryQueue(mag)
        if not mag then return end

        local currentTime = Timer.GetTime()
        local magID = mag.ID

        -- 生成分代ID（每0.5秒为一个分代）
        local generationID = math.floor(currentTime / RETRY_CONFIG.GENERATION_INTERVAL)

        -- 初始化队列条目
        if not retryQueue[magID] then
            retryQueue[magID] = {
                mag = mag,
                generations = {}
            }
        end

        -- 更新分代记录
        local entry = retryQueue[magID]
        if not entry.generations[generationID] then
            entry.generations[generationID] = {
                attempts = 0,
                nextAttempt = currentTime + RETRY_CONFIG.INTERVAL,
                expiry = currentTime + RETRY_CONFIG.VALIDITY_DURATION
            }
        else
            -- 延长该分代的过期时间
            entry.generations[generationID].expiry = currentTime + RETRY_CONFIG.VALIDITY_DURATION
        end

        -- print(string.format("Added generation %d for %s", generationID, mag.Name))
    end

    if not handInv then return end

    local handInvSlots = handInv.slots

    local function getPlayerInvItemsWithoutHand()
        local playerInvItems = character.Inventory.AllItemsMod
        -- 去除双手持有的物品，避免在双持情况下互相抢弹药
        for i = #playerInvItems, 1, -1 do
            local item = playerInvItems[i]
            if (hand and item.ID == hand.ID) or (anotherhand and item.ID == anotherhand.ID) then
                table.remove(playerInvItems, i)
            end
        end
        return playerInvItems
    end

    -- 内部堆叠实现（原tryStackMagzine拆分）
    local function tryStackMagazineInternal(mag)
        if not mag or mag.ConditionPercentage > 0 then
            return false
        end

        -- 原有堆叠逻辑
        local function tryStackInInventory(inventory, Mag)
            local identifier = Mag.Prefab.Identifier
            for i, slot in ipairs(inventory.slots) do
                for _, item in ipairs(slot.items) do
                    if item.HasTag("weapon") then goto continue end
                    if item.Prefab.Identifier.Equals(identifier) and item.ConditionPercentage == 0 and item.ID ~= Mag.ID then -- 只有空弹匣可堆叠
                        if inventory.CanBePutInSlot(Mag, i-1) then
                            inventory.TryPutItem(Mag, i-1, false, true, nil)
                            return true
                        end
                    end
                    ::continue::
                end
            end
            return false
        end

        -- 尝试玩家库存
        if tryStackInInventory(character.Inventory, mag) then
            return true
        end

        -- 尝试子容器
        for item in getPlayerInvItemsWithoutHand() do
            if item.OwnInventory and tryStackInInventory(item.OwnInventory, mag) then
                return true
            end
        end

        return false
    end

    -- 外部入口函数（替换原tryStackMagzine）
    local function tryStackMagzine(mag)
        if not mag then return false end

        -- 立即尝试
        local success = tryStackMagazineInternal(mag)

        -- 失败时加入队列
        if not success then
            -- 防止重复添加
            addToRetryQueue(mag)
        end

        return success
    end

    -- 卸载弹匣
    local function unloadMag(index)
        local unloadedMag = handInvSlots[index].items[1]

        -- 尝试堆叠弹匣
        if tryStackMagzine(unloadedMag) then return true end

        local slots = character.Inventory.slots
        -- 如果都失败了，优先尝试将弹匣放入玩家背包、衣服子物品栏
        for i = #slots, 1, -1 do
            if i == 4 or i == 5 or i == 8 then
                if character.Inventory.TryPutItem(unloadedMag, i-1, false, true, nil) then
                    return true
                end
            end
        end

        -- 然后尝试将弹匣放入玩家物品栏1-10
        for i = #slots, 1, -1 do
            if i <= 8 or i == 19 then goto continue end
            if character.Inventory.CanBePutInSlot(unloadedMag, i-1) then
                character.Inventory.TryPutItem(unloadedMag, i-1, false, false, nil)
                return true
            end
            ::continue::
        end

        -- 保底情况，将弹匣丢到地面，暂时视为false，目前bool未使用
        unloadedMag.Drop(character, true, true)
        return false
    end

    -- 根据 index 构建一个含有所有可用的弹药/弹匣的 table，参数 num 是要寻找的数量
    local function findAvailableItemInPlayerInv(index, num)
        local itemTable = {}

        for item in getPlayerInvItemsWithoutHand() do
            local count = 0

            -- 忽略掉所有带武器标签的物品，避免从其他武器中抢弹药
            if item.HasTag("weapon") then goto continue end
            if handInv.CanBePutInSlot(item, index) and item.ConditionPercentage > 0 then
                if itemTable[item.Prefab.Identifier.value] == nil then itemTable[item.Prefab.Identifier.value] = {} end

                table.insert(itemTable[item.Prefab.Identifier.value], item)
                count = count + 1
                if count >= num then break end
            end
            if item.OwnInventory then
                for item2 in item.OwnInventory.AllItemsMod do
                    if handInv.CanBePutInSlot(item2, index) and item2.ConditionPercentage > 0 then
                        if itemTable[item2.Prefab.Identifier.value] == nil then itemTable[item2.Prefab.Identifier.value] = {} end

                        table.insert(itemTable[item2.Prefab.Identifier.value], item2)
                        count = count + 1
                        if count >= num then break end
                    end
                end
            end
            ::continue::
        end

        local maxLength = 0
        local maxElement = {}
        for identifier, items in pairs(itemTable) do
            if #items > maxLength then
                maxLength = #items
                maxElement = itemTable[identifier]
            end
        end

        return maxElement
    end

    -- 根据 index 寻找可用的弹匣，但不要装入unloadedMag
    local function findAvailableMagInPlayerInv(index, unloadedMag)
        for item in getPlayerInvItemsWithoutHand() do
            -- 忽略掉所有带武器标签的物品，避免从其他武器中抢弹药
            if item.HasTag("weapon") then goto continue end
            if item and item.ID ~= unloadedMag.ID and handInv.CanBePutInSlot(item, index) and item.ConditionPercentage > 0 then
                return item
            end
            if item.OwnInventory then
                for item2 in item.OwnInventory.AllItemsMod do
                    if item2 and item2.ID ~= unloadedMag.ID and handInv.CanBePutInSlot(item2, index) and item2.ConditionPercentage > 0 then
                        return item2
                    end
                end
            end
            ::continue::
        end
        return nil
    end

    -- 根据 identifier 构建一个含有所有可用的弹药/弹匣的 table，参数 num 是要寻找的数量
    local function findAvailableItemWithIdentifier(identifier, num)
        local findTable = {}
        local count = 0
        for item in getPlayerInvItemsWithoutHand() do
            -- 忽略掉所有带武器标签的物品，避免从其他武器中抢弹药
            if item.HasTag("weapon") then goto continue end

            if item.Prefab.Identifier.Equals(identifier) then
                table.insert(findTable, item)
                count = count + 1
                if count >= num then
                    return findTable
                end
            end
            if item.OwnInventory then
                for item2 in item.OwnInventory.AllItemsMod do
                    if item2.Prefab.Identifier.Equals(identifier) then
                        table.insert(findTable, item2)
                        count = count + 1
                        if count >= num then
                            return findTable
                        end
                    end
                end
            end
            ::continue::
        end
        return findTable
    end

    -- 根据 identifier 返回一个可用于堆叠已有弹匣的物品
    local function findAvailableForStackingInPlayerInv(identifier)
        local itemList = {}
        for item in getPlayerInvItemsWithoutHand() do
            if item.HasTag("weapon") then goto continue end
            if item.Prefab.Identifier.Equals(identifier) and item.ConditionPercentage > 0 then
                table.insert(itemList, item)
            end
            if item.OwnInventory then
                for item2 in item.OwnInventory.AllItemsMod do
                    if item2.Prefab.Identifier.Equals(identifier) and item2.ConditionPercentage > 0 then
                        table.insert(itemList, item2)
                    end
                end
            end
            ::continue::
        end
        -- 对 itemList 依照 ConditionPercentage 进行升序排序
        table.sort(itemList, function(a, b) return a.ConditionPercentage < b.ConditionPercentage end)

        return itemList
    end

    local function putItem(item, index, isForStacking, isForSplitting)
        if item == nil or item.ConditionPercentage == 0 or item == hand or item == anotherhand then return end
        if not handInv.TryPutItem(item, index, isForStacking, isForSplitting, character, true, true)
        then return false end -- 如果上弹失败，则返回false
        return true
    end

    -- 对枪械中每个 SlotRestriction 进行处理
    local itemContainer = handInv.Container
    local i = math.max(itemContainer.ContainedStateIndicatorSlot + 1, 1)   -- 准确定位弹匣的slot
    local indicatorItem = handInvSlots[i].items[1]
    local isFirstLoop = true
    while true do
        local handInvSlotRestriction = itemContainer.slotRestrictions[i-1]
        -- 空物品情况
        if #handInvSlots[i].items == 0 then
            for _, item in ipairs(findAvailableItemInPlayerInv(i - 1, isSlotFull(handInvSlotRestriction, handInvSlots[i]))) do
                putItem(item, i - 1, false, false)
            end
        -- 已有可堆叠弹药的情况
        elseif #handInvSlots[i].items > 0 and isSlotFull(handInvSlotRestriction, handInvSlots[i]) > 0 then
            for _, item in ipairs(findAvailableItemWithIdentifier(handInvSlots[i].items[1].Prefab.Identifier, isSlotFull(handInvSlotRestriction, handInvSlots[i]))) do
                putItem(item, i - 1, false, false)
            end
        -- 已有弹匣的情况
        elseif isSlotFull(handInvSlotRestriction, handInvSlots[i]) == 0 and #handInvSlots[i].items == 1 and handInvSlots[i].items[1].ConditionPercentage ~= 100 then
            local itemlist = findAvailableForStackingInPlayerInv(handInvSlots[i].items[1].Prefab.Identifier)
            local item = itemlist[1]
            local unloadedMag = handInvSlots[i].items[1]
            if (#itemlist == 1 and handInvSlots[i].items[1].ConditionPercentage == 0) or (item and item.ConditionPercentage ~=100 and handInvSlots[i].items[1].ConditionPercentage == 0) then    --特殊情况，只剩一个弹匣下处理堆叠问题
                unloadMag(i)
                putItem(item, i - 1, true, true)
            end
            if not putItem(item, i - 1, true, true) then    -- 如果上弹失败，卸载弹匣
                if not (#itemlist == 0 and unloadedMag.ConditionPercentage > 0 )then
                    unloadMag(i)
                end
                -- 如果此时双手武器未装备，重新装备武器
                local currentHand = character.Inventory.GetItemInLimbSlot(handIEnumerable[1])
                local currentAnotherHand = character.Inventory.GetItemInLimbSlot(anotherhandIEnumerable[1])
                if (currentHand == hand and currentAnotherHand == anotherhand) ~= true then
                    if hand and anotherhand and hand.ID == anotherhand.ID then       -- 如果为双手武器
                        for _, handSlotType in ipairs { InvSlotType.LeftHand, InvSlotType.RightHand } do
                            local handSlotIndex = character.Inventory.FindLimbSlot(handSlotType)
                            if handSlotIndex >= 0 then
                                character.Inventory.TryPutItem(hand, handSlotIndex, true, false, character, true, true)
                            end
                        end
                    else                                    -- 如果为单手武器或者双持武器
                        character.Inventory.TryPutItem(hand, character, handIEnumerable, true, true)
                        character.Inventory.TryPutItem(anotherhand, character, anotherhandIEnumerable, true, true)
                    end
                end
                local findMag = findAvailableMagInPlayerInv(i-1, unloadedMag)
                -- if #itemlist == 0 and unloadedMag.ConditionPercentage > 0 and findMag == nil then
                --     putItem(unloadedMag, i - 1, false, false)
                -- else
                putItem(findMag, i - 1, true, true)
                -- end
            end
            tryStackMagzine(item)             -- 尝试堆叠空弹匣，物品栏里的
            tryStackMagzine(unloadedMag)      -- 尝试堆叠空弹匣，从枪里换出来的
        end
        if handInv.CanBePut(handInvSlots[math.max(itemContainer.ContainedStateIndicatorSlot + 1, 1)].items[1]) then
            if isFirstLoop then
                if i ~= 1 then
                    i = 1
                else
                    i = i + 1
                end
                isFirstLoop = false  -- 清除首次标志
            else
                i = i + 1  -- 非首次循环时自增 1
            end
        else
            break
        end
    end

    -- 注册每帧检查，在多人游戏对tryStackMagazine进行重试
    Hook.Add("think", "magazineRetrySystem", function()
        if not retryQueue then return end
        local currentTime = Timer.GetTime()
    
        -- 遍历所有条目
        for magID, entry in pairs(retryQueue) do
            local mag = entry.mag
            local hasValidGenerations = false

            -- 实体有效性检查
            if not mag or mag.ID ~= magID then
                retryQueue[magID] = nil
                goto continue
            end

            for genID, genRecord in pairs(entry.generations) do
                -- 清理过期分代
                if currentTime > genRecord.expiry then
                    entry.generations[genID] = nil
                    -- print("Generation expired:", genID)
                    goto next_generation
                end

                -- 执行重试条件检查
                if currentTime >= genRecord.nextAttempt then
                    -- 执行重试
                    local success = tryStackMagazineInternal(mag)

                    if success then
                        -- 成功时清除全部分代
                        retryQueue[magID] = nil
                        -- print("Success via generation:", genID)
                        goto continue
                    else
                        -- 更新重试状态
                        genRecord.attempts = genRecord.attempts + 1
                        genRecord.nextAttempt = currentTime + RETRY_CONFIG.INTERVAL

                        -- 超过最大尝试次数
                        if genRecord.attempts >= RETRY_CONFIG.MAX_ATTEMPTS then
                            entry.generations[genID] = nil
                            -- print("Max attempts for generation:", genID)
                        end
                    end
                end

                hasValidGenerations = true
                ::next_generation::
            end
            
            -- 清理空条目
            if not hasValidGenerations then
                retryQueue[magID] = nil
            end

            ::continue::
        end
    end)
end

Hook.Patch("Barotrauma.Character", "ControlLocalPlayer", function(instance, ptable)
    if retryQueue == nil then Hook.Remove("think", "magazineRetrySystem") end
    if(GUI.KeyboardDispatcher.Subscriber ~= nil) then return end
    if not PlayerInput.KeyHit(Keys.R) then return end
    local Character = instance
    if not Character then return end

    local rightHand = Character.Inventory.GetItemInLimbSlot(InvSlotType.RightHand)
    local leftHand = Character.Inventory.GetItemInLimbSlot(InvSlotType.LeftHand)
    local rightHandIEnumerable = {InvSlotType.RightHand}
    local leftHandIEnumerable = {InvSlotType.LeftHand}

    if not rightHand and not leftHand then return end

    if rightHand and rightHand.HasTag("weapon") then
        tryPutItemsInInventory(Character, rightHand, leftHand, rightHand.OwnInventory, rightHandIEnumerable, leftHandIEnumerable)
    end

    if leftHand and not leftHand.Equals(rightHand) and leftHand.HasTag("weapon") then
        tryPutItemsInInventory(Character, leftHand, rightHand, leftHand.OwnInventory, leftHandIEnumerable, rightHandIEnumerable)
    end
end, Hook.HookMethodType.After)

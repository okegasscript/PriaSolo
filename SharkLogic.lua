-- SharkLogic.lua
-- URL: https://raw.githubusercontent.com/okegasscript/PriaSolo/refs/heads/main/SharkLogic.lua

local SharkLogic = {}

local config = {
    slotCFrame = CFrame.new(-13.018989562988, 0, -74.922821044922, 1,0,0,0,1,0,0,0,1)
}

-- Mencari tumbal berdasarkan daftar nama (filter: non-fav, level>=100, jika 'cat' harus Blossoming)
function SharkLogic.findTumbal(dataPetModule, tumbalNames, excludeUUIDs)
    excludeUUIDs = excludeUUIDs or {}
    for _, name in ipairs(tumbalNames) do
        local filter = {
            exactName = name,
            isFavorite = false,
            minLevel = 100,
            excludeUUIDs = excludeUUIDs,
            limit = 1
        }
        -- Jika nama adalah "cat", tambahkan filter mutasi Blossoming
        if string.lower(name) == "cat" then
            filter.mutation = "Blossoming"
        end
        local results = dataPetModule.findPets(filter)
        if #results > 0 then
            return results[1].pet, results[1].uuid
        end
    end
    return nil, nil
end

-- Mencari target (non-fav, tanpa Blossoming)
function SharkLogic.findTarget(dataPetModule, targetName, excludeUUIDs)
    excludeUUIDs = excludeUUIDs or {}
    local results = dataPetModule.findPets({
        exactName = targetName,
        isFavorite = false,
        excludeUUIDs = excludeUUIDs,
        limit = 1
    })
    if #results > 0 then
        local petInfo = results[1]
        if petInfo.mutation ~= "Blossoming" then
            return petInfo.pet, petInfo.uuid
        end
    end
    return nil, nil
end

-- Equip
function SharkLogic.equipPet(petsService, uuid, cframe)
    if not uuid then return end
    petsService:FireServer("EquipPet", uuid, cframe or config.slotCFrame)
end

-- Unequip
function SharkLogic.unequipPet(petsService, uuid)
    if not uuid then return end
    petsService:FireServer("UnequipPet", uuid)
end

return SharkLogic
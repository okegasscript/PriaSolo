local SharkLogic = {}

SharkLogic.defaultConfig = {
    targetName = "Moon Cat",
    tumbalNames = {"Dog"},
    slotCFrame = CFrame.new(-13.018989562988, 0, -74.922821044922, 1,0,0,0,1,0,0,0,1)
}

-- Mencari tumbal dengan syarat:
-- - Nama pet sesuai (exact match)
-- - Bukan favorit
-- - Level >= minLevel
-- - Mutasi = "Blossoming" (WAJIB)
-- - Tidak termasuk excludeUUIDs
function SharkLogic.findTumbal(dataPetModule, tumbalNames, excludeUUIDs, minLevel)
    minLevel = minLevel or 0
    excludeUUIDs = excludeUUIDs or {}
    for _, name in ipairs(tumbalNames) do
        local results = dataPetModule.findPets({
            exactName = name,
            isFavorite = false,
            minLevel = minLevel,
            excludeUUIDs = excludeUUIDs,
            limit = 10
        })
        for _, petInfo in ipairs(results) do
            if petInfo.mutation == "Blossoming" then
                return petInfo.uuid
            end
        end
    end
    return nil
end

-- Mencari target dengan syarat:
-- - Nama pet sesuai (exact match)
-- - Bukan favorit
-- - Mutasi = "Normal" (tanpa mutasi)
-- - Tidak termasuk excludeUUIDs
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
        if petInfo.mutation == "Normal" then
            return petInfo.uuid
        end
    end
    return nil
end

function SharkLogic.equipPet(petsService, uuid, cframe)
    if not uuid then return end
    petsService:FireServer("EquipPet", uuid, cframe)
end

function SharkLogic.unequipPet(petsService, uuid)
    if not uuid then return end
    petsService:FireServer("UnequipPet", uuid)
end

return SharkLogic

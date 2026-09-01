-- SharkLogic.lua
local SharkLogic = {}

SharkLogic.defaultConfig = {
    slotCFrame = CFrame.new(-13.018989562988, 0, -74.922821044922, 1,0,0,0,1,0,0,0,1)
}

-- Mencari tumbal berdasarkan daftar nama (filter non-fav, level>=100, cat harus Blossoming)
function SharkLogic.findTumbal(dataPetModule, tumbalNames, excludeUUIDs)
    excludeUUIDs = excludeUUIDs or {}
    for _, name in ipairs(tumbalNames) do
        local results = dataPetModule.findPets({
            exactName = name,
            isFavorite = false,
            minLevel = 100,
            excludeUUIDs = excludeUUIDs,
            limit = 1
        })
        if #results > 0 then
            local petInfo = results[1]
            -- Jika nama "Cat", pastikan mutasi Blossoming
            if string.lower(name) == "cat" then
                local catResults = dataPetModule.findPets({
                    exactName = "Cat",
                    isFavorite = false,
                    minLevel = 100,
                    mutation = "Blossoming",
                    excludeUUIDs = excludeUUIDs,
                    limit = 1
                })
                if #catResults > 0 then
                    return catResults[1].pet, catResults[1].uuid
                else
                    return nil, nil
                end
            else
                return petInfo.pet, petInfo.uuid
            end
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

function SharkLogic.equipPet(petsService, uuid, cframe)
    if not uuid then return end
    petsService:FireServer("EquipPet", uuid, cframe)
end

function SharkLogic.unequipPet(petsService, uuid)
    if not uuid then return end
    petsService:FireServer("UnequipPet", uuid)
end

return SharkLogic

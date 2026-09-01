local SharkLogic = {}

SharkLogic.defaultConfig = {
    targetName = "Moon Cat",
    tumbalNames = {"Dog"},
    slotCFrame = CFrame.new(-13.018989562988, 0, -74.922821044922, 1,0,0,0,1,0,0,0,1)
}

-- Fungsi findTumbal dengan parameter minLevel (default 0)
function SharkLogic.findTumbal(dataPetModule, tumbalNames, excludeUUIDs, minLevel)
    minLevel = minLevel or 0
    excludeUUIDs = excludeUUIDs or {}
    for _, name in ipairs(tumbalNames) do
        local results = dataPetModule.findPets({
            exactName = name,
            isFavorite = false,
            minLevel = minLevel,   -- pakai parameter
            excludeUUIDs = excludeUUIDs,
            limit = 1
        })
        if #results > 0 then
            local petInfo = results[1]
            if string.lower(name) == "cat" then
                local catResults = dataPetModule.findPets({
                    exactName = "Cat",
                    isFavorite = false,
                    minLevel = minLevel,
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

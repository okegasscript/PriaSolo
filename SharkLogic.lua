local SharkLogic = {}

SharkLogic.defaultConfig = {
    targetName = "Moon Cat",
    tumbalNames = {"Dog"},
    slotCFrame = CFrame.new(-13.018989562988, 0, -74.922821044922, 1,0,0,0,1,0,0,0,1)
}

-- Mencari tumbal dengan syarat:
-- - Nama pet sesuai (exact match, case-insensitive)
-- - Bukan favorit
-- - Level >= minLevel
-- - Mutasi = "Blossoming" (WAJIB untuk SEMUA tumbal)
-- - Tidak termasuk excludeUUIDs
function SharkLogic.findTumbal(dataPetModule, tumbalNames, excludeUUIDs, minLevel)
    minLevel = minLevel or 0
    excludeUUIDs = excludeUUIDs or {}
    for _, name in ipairs(tumbalNames) do
        -- Cari pet dengan nama tersebut
        local results = dataPetModule.findPets({
            exactName = name,
            isFavorite = false,
            minLevel = minLevel,
            excludeUUIDs = excludeUUIDs,
            limit = 10  -- ambil beberapa, nanti kita filter Blossoming
        })
        -- Filter: hanya yang mutasi Blossoming
        for _, petInfo in ipairs(results) do
            if petInfo.mutation == "Blossoming" then
                return petInfo.uuid
            end
        end
        -- Jika tidak ada yang Blossoming, lanjut ke nama tumbal berikutnya
    end
    return nil
end

-- Mencari target (non-fav, tanpa Blossoming) - sudah tidak digunakan karena target pakai dropdown
-- function SharkLogic.findTarget(...) -- tidak digunakan lagi

function SharkLogic.equipPet(petsService, uuid, cframe)
    if not uuid then return end
    petsService:FireServer("EquipPet", uuid, cframe)
end

function SharkLogic.unequipPet(petsService, uuid)
    if not uuid then return end
    petsService:FireServer("UnequipPet", uuid)
end

return SharkLogic

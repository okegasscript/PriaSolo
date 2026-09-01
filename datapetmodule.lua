--[[
  DataPetModule.lua - v2
  - Mengambil data pet dari DataService
  - Menyediakan fungsi pencarian dan filter
  - Menyimpan cache cooldown dari event
--]]

local DataService = require(ReplicatedStorage.Modules.DataService)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetCooldownsEvent = ReplicatedStorage.GameEvents.PetCooldownsUpdated

local DataPetModule = {}

-- Cache cooldown: key = UUID, value = { Time = number, Passive = string }
local cooldownCache = {}

-- ============================================================
-- DATA PET DASAR
-- ============================================================

-- Mendapatkan seluruh data inventory pet (raw)
function DataPetModule.getAllPets()
    local data = DataService:GetData()
    if not data then return {} end
    local inv = data.PetsData and data.PetsData.PetInventory and data.PetsData.PetInventory.Data
    return inv or {}
end

-- Mendapatkan data pet berdasarkan UUID
function DataPetModule.getPetByUUID(uuid)
    local inv = DataPetModule.getAllPets()
    return inv[uuid]
end

-- Mendapatkan daftar UUID pet yang sedang di-equip
function DataPetModule.getEquippedPets()
    local data = DataService:GetData()
    if not data then return {} end
    return data.PetsData and data.PetsData.EquippedPets or {}
end

-- Mendapatkan detail pet yang sedang di-equip (array of {uuid, petData})
function DataPetModule.getEquippedPetDetails()
    local equipped = DataPetModule.getEquippedPets()
    local result = {}
    for _, uuid in ipairs(equipped) do
        local pet = DataPetModule.getPetByUUID(uuid)
        if pet then
            table.insert(result, {uuid = uuid, pet = pet})
        end
    end
    return result
end

-- ============================================================
-- FUNGSI FILTER & PENCARIAN
-- ============================================================

-- Mencari pet dengan filter (semua filter opsional)
-- filter = {
--   name = string,         -- nama pet (case-insensitive, partial match jika diinginkan)
--   exactName = string,    -- exact match (case-insensitive)
--   type = string,         -- PetType (case-insensitive)
--   mutation = string,     -- nama mutasi (dari getAutoMutationName)
--   isFavorite = boolean,  -- true/false
--   minLevel = number,     -- level >= minLevel
--   maxLevel = number,     -- level <= maxLevel
--   minWeight = number,    -- weight >= minWeight
--   maxWeight = number,    -- weight <= maxWeight
--   excludeUUIDs = table,  -- daftar UUID yang tidak boleh dimasukkan
--   limit = number         -- batas jumlah hasil (opsional)
-- }
function DataPetModule.findPets(filter)
    filter = filter or {}
    local inv = DataPetModule.getAllPets()
    local results = {}
    local exclude = filter.excludeUUIDs or {}
    local limit = filter.limit or math.huge

    for uuid, pet in pairs(inv) do
        if #results >= limit then break end
        if table.find(exclude, uuid) then continue end

        local pData = pet.PetData or {}
        local pType = pet.PetType or pData.PetType or pData.Name or ""
        local rawMut = pData.MutationType or "Normal"
        local mutName = DataPetModule.getAutoMutationName(rawMut)
        local level = pData.Level or pData.Lvl or 0
        local isFav = pData.IsFavorite or false

        -- Berat (estimasi)
        local weight = nil
        for key, val in pairs(pData) do
            local kLower = string.lower(tostring(key))
            if (kLower:find("weight") or kLower:find("size") or kLower:find("kg")) and
               kLower ~= "baseweight" and type(val) == "number" then
                weight = val
                break
            end
        end
        if not weight and pData.BaseWeight then
            weight = pData.BaseWeight * (1 + (level * 0.05))
        end

        -- Filter name (partial match)
        if filter.name then
            if not string.find(string.lower(pType), string.lower(filter.name)) then
                continue
            end
        end
        -- Filter exactName
        if filter.exactName then
            if string.lower(pType) ~= string.lower(filter.exactName) then
                continue
            end
        end
        -- Filter type
        if filter.type then
            if string.lower(pType) ~= string.lower(filter.type) then
                continue
            end
        end
        -- Filter mutation
        if filter.mutation then
            if mutName ~= filter.mutation then
                continue
            end
        end
        -- Filter isFavorite (jika diberikan)
        if filter.isFavorite ~= nil then
            if isFav ~= filter.isFavorite then
                continue
            end
        end
        -- Filter level
        if filter.minLevel and level < filter.minLevel then continue end
        if filter.maxLevel and level > filter.maxLevel then continue end
        -- Filter weight
        if weight then
            if filter.minWeight and weight < filter.minWeight then continue end
            if filter.maxWeight and weight > filter.maxWeight then continue end
        end

        -- Tambahkan ke hasil
        table.insert(results, {
            uuid = uuid,
            pet = pet,
            petData = pData,
            name = pType,
            mutation = mutName,
            level = level,
            weight = weight,
            isFavorite = isFav,
            passive = pData.Passive or ""
        })
    end

    return results
end

-- Mencari satu pet dengan filter (mengembalikan pet, uuid)
function DataPetModule.findPet(filter)
    local results = DataPetModule.findPets(filter)
    if #results > 0 then
        local r = results[1]
        return r.pet, r.uuid
    end
    return nil, nil
end

-- ============================================================
-- COOLDOWN PET
-- ============================================================

-- Mendapatkan cooldown terakhir yang diketahui untuk UUID
function DataPetModule.getCooldown(uuid)
    return cooldownCache[uuid]
end

-- Update cache cooldown dari event (panggil saat event diterima)
function DataPetModule.updateCooldown(petId, dataArray)
    -- dataArray adalah array { { Time = number, Passive = string } }
    if type(dataArray) == "table" and #dataArray > 0 then
        local entry = dataArray[1] -- ambil yang pertama
        if entry and entry.Time ~= nil then
            cooldownCache[petId] = {
                Time = entry.Time,
                Passive = entry.Passive or ""
            }
        end
    end
end

-- Daftarkan event listener untuk update otomatis (hanya sekali)
local function setupCooldownListener()
    if not DataPetModule._listenerSetup then
        PetCooldownsEvent.OnClientEvent:Connect(function(petId, dataArray)
            DataPetModule.updateCooldown(petId, dataArray)
        end)
        DataPetModule._listenerSetup = true
    end
end
setupCooldownListener()

-- ============================================================
-- MUTASI
-- ============================================================

-- Fungsi getAutoMutationName (sama seperti sebelumnya)
function DataPetModule.getAutoMutationName(rawCode)
    if not rawCode or rawCode == "Normal" or rawCode == "" then
        return "Normal"
    end
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("ModuleScript") and (
            obj.Name:lower():find("mut") or
            obj.Name:lower():find("pet") or
            obj.Name:lower():find("config")
        ) then
            local success, mod = pcall(require, obj)
            if success and type(mod) == "table" then
                for k, v in pairs(mod) do
                    if tostring(k) == tostring(rawCode) and type(v) == "string" then
                        return v
                    elseif tostring(v) == tostring(rawCode) and type(k) == "string" then
                        return k
                    elseif type(v) == "table" then
                        for subK, subV in pairs(v) do
                            if tostring(subK) == tostring(rawCode) and type(subV) == "string" then
                                return subV
                            elseif tostring(subV) == tostring(rawCode) and type(subK) == "string" then
                                return subK
                            end
                        end
                    end
                end
            end
        end
    end
    return tostring(rawCode)
end

return DataPetModule
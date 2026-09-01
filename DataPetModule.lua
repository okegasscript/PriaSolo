--[[
  DataPetModule.lua
  - Mengambil data pet dari DataService (dengan pencarian otomatis)
  - Menyediakan fungsi pencarian pet berdasarkan nama, mutasi, UUID, dll
  - Bisa dipanggil dari client maupun server
  - Cocok untuk executor (tidak perlu patch)
--]]

local DataService = nil

-- Fungsi untuk mencari DataService di berbagai lokasi
local function findDataService()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    -- 1. Coba di ReplicatedStorage.Modules
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    if modules then
        local ds = modules:FindFirstChild("DataService")
        if ds then
            return require(ds)
        end
    end
    -- 2. Coba langsung di ReplicatedStorage
    local ds = ReplicatedStorage:FindFirstChild("DataService")
    if ds then
        return require(ds)
    end
    -- 3. Coba dari _G (jika sudah di-set oleh script lain)
    if _G.DataService then
        return _G.DataService
    end
    -- 4. Coba gunakan DataService yang mungkin tersedia di game
    local success, result = pcall(function()
        return game:GetService("DataService")
    end)
    if success and result then
        return result
    end
    error("DataService tidak ditemukan di ReplicatedStorage.Modules, ReplicatedStorage, atau _G")
end

DataService = findDataService()

-- ==== Fungsi getAutoMutationName (sama seperti sebelumnya) ====
local function getAutoMutationName(rawCode)
    if not rawCode or rawCode == "Normal" or rawCode == "" then
        return "Normal"
    end
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

-- ===== Module =====
local DataPetModule = {}

-- Mendapatkan seluruh data inventory pet
function DataPetModule.getAllPets()
    local data = DataService:GetData()
    if not data then return {} end
    local inv = data.PetsData and data.PetsData.PetInventory and data.PetsData.PetInventory.Data
    return inv or {}
end

-- Mendapatkan daftar UUID pet yang sedang di-equip
function DataPetModule.getEquippedPets()
    local data = DataService:GetData()
    if not data then return {} end
    return data.PetsData and data.PetsData.EquippedPets or {}
end

-- Mendapatkan detail pet yang sedang di-equip (UUID + data lengkap)
function DataPetModule.getEquippedPetDetails()
    local equippedUUIDs = DataPetModule.getEquippedPets()
    local details = {}
    local allPets = DataPetModule.getAllPets()
    for _, uuid in ipairs(equippedUUIDs) do
        local pet = allPets[uuid]
        if pet then
            table.insert(details, {uuid = uuid, pet = pet})
        end
    end
    return details
end

-- Mencari pet berdasarkan nama (case-insensitive, partial match)
function DataPetModule.findPetsByExactName(name, excludeUUIDs)
    excludeUUIDs = excludeUUIDs or {}
    local results = {}
    local inv = DataPetModule.getAllPets()
    for uuid, pet in pairs(inv) do
        if not table.find(excludeUUIDs, uuid) then
            local pType = pet.PetType or pet.PetData and pet.PetData.PetType or pet.PetData and pet.PetData.Name or ""
            if string.lower(pType) == string.lower(name) then
                local petData = pet.PetData or {}
                table.insert(results, {
                    uuid = uuid,
                    pet = pet,
                    petData = petData,
                    name = pType,
                    mutation = getAutoMutationName(petData.MutationType or "Normal"),
                    level = petData.Level or petData.Lvl or 0,
                    weight = petData.Weight or petData.BaseWeight or 0,
                    isFavorite = petData.IsFavorite or false,
                    passive = petData.Passive or ""
                })
            end
        end
    end
    return results
end

-- Mencari pet dengan filter lengkap (nama, mutasi, level, berat, favorit, dll)
function DataPetModule.findPets(filter)
    filter = filter or {}
    local excludeUUIDs = filter.excludeUUIDs or {}
    local results = {}
    local inv = DataPetModule.getAllPets()
    for uuid, pet in pairs(inv) do
        if not table.find(excludeUUIDs, uuid) then
            local petData = pet.PetData or {}
            local pType = pet.PetType or pet.PetData and pet.PetData.PetType or pet.PetData and pet.PetData.Name or ""
            local mutationRaw = petData.MutationType or "Normal"
            local mutation = getAutoMutationName(mutationRaw)
            local level = petData.Level or petData.Lvl or 0
            local weight = petData.Weight or petData.BaseWeight or 0
            local isFav = petData.IsFavorite or false
            local passive = petData.Passive or ""

            -- Filter logika
            local match = true
            if filter.type and string.lower(pType) ~= string.lower(filter.type) then
                match = false
            end
            if filter.exactName and string.lower(pType) ~= string.lower(filter.exactName) then
                match = false
            end
            if filter.name and not string.find(string.lower(pType), string.lower(filter.name)) then
                match = false
            end
            if filter.mutation and string.lower(mutation) ~= string.lower(filter.mutation) then
                match = false
            end
            if filter.isFavorite ~= nil and isFav ~= filter.isFavorite then
                match = false
            end
            if filter.minLevel and level < filter.minLevel then
                match = false
            end
            if filter.maxLevel and level > filter.maxLevel then
                match = false
            end
            if filter.minWeight and weight < filter.minWeight then
                match = false
            end
            if filter.maxWeight and weight > filter.maxWeight then
                match = false
            end

            if match then
                table.insert(results, {
                    uuid = uuid,
                    pet = pet,
                    petData = petData,
                    name = pType,
                    mutation = mutation,
                    level = level,
                    weight = weight,
                    isFavorite = isFav,
                    passive = passive
                })
            end
        end
    end
    -- Batasi hasil jika ada limit
    if filter.limit and #results > filter.limit then
        for i = #results, filter.limit + 1, -1 do
            table.remove(results, i)
        end
    end
    return results
end

-- Cari pet pertama yang cocok (single result)
function DataPetModule.findPet(filter)
    local results = DataPetModule.findPets(filter)
    return results[1] or nil
end

-- Mendapatkan nama mutasi dari kode
function DataPetModule.getAutoMutationName(rawCode)
    return getAutoMutationName(rawCode)
end

-- ===== Cooldown cache =====
local cooldownCache = {}
local cooldownEvent = game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("PetCooldownsUpdated")
cooldownEvent.OnClientEvent:Connect(function(petId, dataArray)
    if type(dataArray) == "table" and #dataArray > 0 then
        local entry = dataArray[1]
        if entry and entry.Time and entry.Passive then
            cooldownCache[petId] = {
                Time = entry.Time,
                Passive = entry.Passive
            }
        end
    end
end)

function DataPetModule.getCooldown(uuid)
    return cooldownCache[uuid]
end

function DataPetModule.getAllCooldowns()
    return cooldownCache
end

return DataPetModule

--[[
  DataPetModule.lua (OPTIMIZED)
  - Mengambil data pet dari DataService (dengan pencarian otomatis)
  - Menyediakan fungsi pencarian pet berdasarkan nama, mutasi, UUID, dll
  - Bisa dipanggil dari client maupun server
  - Cocok untuk executor (tidak perlu patch)
  - PERUBAHAN: mutation module lookup di-cache, tidak scan ulang tiap panggilan
    (fix freeze/lag saat inventory besar)
--]]

local DataService = nil

-- Fungsi untuk mencari DataService di berbagai lokasi
local function findDataService()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    if modules then
        local ds = modules:FindFirstChild("DataService")
        if ds then
            return require(ds)
        end
    end
    local ds = ReplicatedStorage:FindFirstChild("DataService")
    if ds then
        return require(ds)
    end
    if _G.DataService then
        return _G.DataService
    end
    local success, result = pcall(function()
        return game:GetService("DataService")
    end)
    if success and result then
        return result
    end
    error("DataService tidak ditemukan di ReplicatedStorage.Modules, ReplicatedStorage, atau _G")
end

DataService = findDataService()

-- ==== CACHE untuk mutation lookup ====
-- Sebelumnya: getAutoMutationName scan ReplicatedStorage:GetDescendants() SETIAP kali dipanggil,
-- dan dipanggil untuk SETIAP pet di inventory -> sangat berat kalau inventory besar (ratusan item).
-- Sekarang: scan hanya dilakukan SEKALI, hasilnya disimpan di cache, dan cache dipakai untuk semua
-- pencarian berikutnya. Ini menghilangkan sumber freeze/lag utama.

local mutationCache = nil -- table: { [rawCode] = mutationName }
local mutationModulesScanned = false

local function buildMutationCache()
    mutationCache = {}
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
                    if type(v) == "string" then
                        mutationCache[tostring(k)] = v
                        mutationCache[tostring(v)] = k
                    elseif type(v) == "table" then
                        for subK, subV in pairs(v) do
                            if type(subV) == "string" then
                                mutationCache[tostring(subK)] = subV
                                mutationCache[tostring(subV)] = subK
                            end
                        end
                    end
                end
            end
        end
    end
    mutationModulesScanned = true
end

local function getAutoMutationName(rawCode)
    if not rawCode or rawCode == "Normal" or rawCode == "" then
        return "Normal"
    end

    -- Scan hanya sekali (lazy init), pakai cache untuk selanjutnya
    if not mutationModulesScanned then
        buildMutationCache()
    end

    local cached = mutationCache[tostring(rawCode)]
    if cached then
        return cached
    end

    return tostring(rawCode)
end

-- Fungsi publik untuk paksa refresh cache (panggil manual kalau ada mutation baru di-update game)
local function refreshMutationCache()
    buildMutationCache()
end

-- ===== Module =====
local DataPetModule = {}

function DataPetModule.getAllPets()
    local data = DataService:GetData()
    if not data then return {} end
    local inv = data.PetsData and data.PetsData.PetInventory and data.PetsData.PetInventory.Data
    return inv or {}
end

function DataPetModule.getEquippedPets()
    local data = DataService:GetData()
    if not data then return {} end
    return data.PetsData and data.PetsData.EquippedPets or {}
end

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
    if filter.limit and #results > filter.limit then
        for i = #results, filter.limit + 1, -1 do
            table.remove(results, i)
        end
    end
    return results
end

function DataPetModule.findPet(filter)
    local results = DataPetModule.findPets(filter)
    return results[1] or nil
end

function DataPetModule.getAutoMutationName(rawCode)
    return getAutoMutationName(rawCode)
end

-- Expose fungsi refresh cache, jaga-jaga kalau perlu di-reset manual
function DataPetModule.refreshMutationCache()
    refreshMutationCache()
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

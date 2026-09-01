-- ============================================================
-- DataPetModule.lua
-- Versi Final dengan MUTATION_MAP yang benar
-- ============================================================

local DataPetModule = {}

-- ============================================================
-- MUTATION MAP (sesuai permintaan)
-- ============================================================
local MUTATION_MAP = {
    ["@"] = "Blossoming",
    ["J"] = "Oxpecker",
    ["IN"] = "Inferno",
    ["X"] = "Venom",
    ["EM"] = "Ember",
    ["EV"] = "Everchanted",
    ["O"] = "Forger",
    ["A"] = "Nightmare",
    ["N"] = "Lion",
    ["i"] = "Mega",
    ["TS"] = "Transcendent",
    ["Normal"] = "Normal",
}

-- ============================================================
-- FUNGSI TERJEMAHAN MUTASI
-- ============================================================
function DataPetModule.getAutoMutationName(rawCode)
    if not rawCode or rawCode == "" then
        return "Normal"
    end
    -- Cari di MUTATION_MAP
    local mapped = MUTATION_MAP[rawCode]
    if mapped then
        return mapped
    end
    -- Jika tidak ditemukan, coba cari di ReplicatedStorage (fallback)
    for _, obj in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
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
                    end
                end
            end
        end
    end
    return tostring(rawCode)
end

-- ============================================================
-- FUNGSI MENDAPATKAN DATA PET
-- ============================================================
local function findDataService()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    if modules then
        local ds = modules:FindFirstChild("DataService")
        if ds then return require(ds) end
    end
    local ds = ReplicatedStorage:FindFirstChild("DataService")
    if ds then return require(ds) end
    if _G.DataService then return _G.DataService end
    local success, result = pcall(function()
        return game:GetService("DataService")
    end)
    if success and result then return result end
    error("DataService tidak ditemukan")
end

local DataService = findDataService()

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

-- ============================================================
-- FIND PETS DENGAN FILTER LENGKAP
-- ============================================================
function DataPetModule.findPets(filter)
    filter = filter or {}
    local inv = DataPetModule.getAllPets()
    local results = {}

    local function matches(pet, uuid)
        local petData = pet.PetData or {}
        local name = pet.PetType or petData.PetType or petData.Name or "Unknown"
        local rawMut = petData.MutationType or "Normal"
        local mutation = DataPetModule.getAutoMutationName(rawMut)
        local level = petData.Level or petData.Lvl or 0
        local weight = petData.Weight or petData.BaseWeight or 0
        local isFavorite = petData.IsFavorite or false
        local passive = petData.Passive or ""

        -- Filter name (partial)
        if filter.name and not string.lower(name):find(string.lower(filter.name)) then
            return false
        end
        -- Filter exactName
        if filter.exactName and string.lower(name) ~= string.lower(filter.exactName) then
            return false
        end
        -- Filter type
        if filter.type and string.lower(name) ~= string.lower(filter.type) then
            return false
        end
        -- Filter mutation
        if filter.mutation and string.lower(mutation) ~= string.lower(filter.mutation) then
            return false
        end
        -- Filter isFavorite
        if filter.isFavorite ~= nil and isFavorite ~= filter.isFavorite then
            return false
        end
        -- Filter minLevel
        if filter.minLevel and level < filter.minLevel then
            return false
        end
        -- Filter maxLevel
        if filter.maxLevel and level > filter.maxLevel then
            return false
        end
        -- Filter minWeight
        if filter.minWeight and weight < filter.minWeight then
            return false
        end
        -- Filter maxWeight
        if filter.maxWeight and weight > filter.maxWeight then
            return false
        end
        -- Filter excludeUUIDs
        if filter.excludeUUIDs and table.find(filter.excludeUUIDs, uuid) then
            return false
        end
        return true
    end

    for uuid, pet in pairs(inv) do
        if matches(pet, uuid) then
            local petData = pet.PetData or {}
            local rawMut = petData.MutationType or "Normal"
            local mutation = DataPetModule.getAutoMutationName(rawMut)
            table.insert(results, {
                uuid = uuid,
                pet = pet,
                petData = petData,
                name = pet.PetType or petData.PetType or petData.Name or "Unknown",
                mutation = mutation,
                level = petData.Level or petData.Lvl or 0,
                weight = petData.Weight or petData.BaseWeight or 0,
                isFavorite = petData.IsFavorite or false,
                passive = petData.Passive or ""
            })
        end
    end

    -- Sortir berdasarkan abjad nama (A-Z)
    table.sort(results, function(a, b)
        return string.lower(a.name) < string.lower(b.name)
    end)

    if filter.limit then
        local limited = {}
        for i = 1, math.min(filter.limit, #results) do
            table.insert(limited, results[i])
        end
        return limited
    end
    return results
end

function DataPetModule.findPet(filter)
    local results = DataPetModule.findPets(filter)
    return results[1] or nil
end

-- ============================================================
-- COOLDOWN CACHE
-- ============================================================
local cooldownCache = {}

local function setupCooldownListener()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local GameEvents = ReplicatedStorage:FindFirstChild("GameEvents")
    if not GameEvents then return end
    local PetCooldownsEvent = GameEvents:FindFirstChild("PetCooldownsUpdated")
    if not PetCooldownsEvent then return end

    PetCooldownsEvent.OnClientEvent:Connect(function(petId, dataArray)
        if type(dataArray) == "table" and #dataArray > 0 then
            cooldownCache[petId] = dataArray[1]
        end
    end)
end
setupCooldownListener()

function DataPetModule.getCooldown(uuid)
    return cooldownCache[uuid]
end

return DataPetModule

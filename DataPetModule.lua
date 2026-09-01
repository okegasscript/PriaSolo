-- ============================================================
-- DataPetModule.lua
-- Mengelola data pet, filter, cooldown, dan mutasi.
-- ============================================================

local DataPetModule = {}

-- ============================================================
-- MUTATION MAP (sesuai permintaan user)
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
-- Fungsi untuk mendapatkan DataService
-- ============================================================
local function findDataService()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    -- Coba di Modules
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    if modules then
        local ds = modules:FindFirstChild("DataService")
        if ds then return require(ds) end
    end
    -- Coba langsung di ReplicatedStorage
    local ds = ReplicatedStorage:FindFirstChild("DataService")
    if ds then return require(ds) end
    -- Coba dari _G
    if _G.DataService then return _G.DataService end
    -- Coba gunakan DataService global
    local success, result = pcall(function()
        return game:GetService("DataService")
    end)
    if success and result then return result end
    error("DataService tidak ditemukan")
end

local DataService = findDataService()

-- ============================================================
-- Fungsi untuk menerjemahkan mutasi
-- ============================================================
function DataPetModule.getAutoMutationName(rawCode)
    if not rawCode or rawCode == "" then
        return "Normal"
    end
    -- Cek di map terlebih dahulu
    local mapped = MUTATION_MAP[rawCode]
    if mapped then
        return mapped
    end
    -- Jika tidak ada di map, coba cari di ModuleScript (fallback)
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

-- ============================================================
-- Ambil semua data pet
-- ============================================================
function DataPetModule.getAllPets()
    local data = DataService:GetData()
    if not data then return {} end
    local inv = data.PetsData and data.PetsData.PetInventory and data.PetsData.PetInventory.Data
    return inv or {}
end

-- ============================================================
-- Mendapatkan UUID pet yang sedang di-equip
-- ============================================================
function DataPetModule.getEquippedPets()
    local data = DataService:GetData()
    if not data then return {} end
    return data.PetsData and data.PetsData.EquippedPets or {}
end

-- ============================================================
-- Mendapatkan detail pet yang sedang di-equip
-- ============================================================
function DataPetModule.getEquippedPetDetails()
    local equipped = DataPetModule.getEquippedPets()
    local allPets = DataPetModule.getAllPets()
    local details = {}
    for _, uuid in ipairs(equipped) do
        local pet = allPets[uuid]
        if pet then
            table.insert(details, {uuid = uuid, pet = pet})
        end
    end
    return details
end

-- ============================================================
-- Fungsi pencarian pet dengan filter lengkap
-- ============================================================
function DataPetModule.findPets(filter)
    filter = filter or {}
    local allPets = DataPetModule.getAllPets()
    local results = {}

    for uuid, pet in pairs(allPets) do
        local petData = pet.PetData or {}
        local name = pet.PetType or petData.PetType or petData.Name or ""
        local mutationRaw = petData.MutationType or "Normal"
        local mutation = DataPetModule.getAutoMutationName(mutationRaw)
        local level = petData.Level or petData.Lvl or 0
        local weight = petData.Weight or 0
        local isFavorite = petData.IsFavorite or false
        local passive = petData.Passive or ""

        -- Filter: exclude UUIDs
        if filter.excludeUUIDs and table.find(filter.excludeUUIDs, uuid) then
            goto continue
        end

        -- Filter: isFavorite
        if filter.isFavorite ~= nil and isFavorite ~= filter.isFavorite then
            goto continue
        end

        -- Filter: type (exact match)
        if filter.type and string.lower(name) ~= string.lower(filter.type) then
            goto continue
        end

        -- Filter: exactName
        if filter.exactName and string.lower(name) ~= string.lower(filter.exactName) then
            goto continue
        end

        -- Filter: name (partial match)
        if filter.name and not string.find(string.lower(name), string.lower(filter.name)) then
            goto continue
        end

        -- Filter: mutation
        if filter.mutation and string.lower(mutation) ~= string.lower(filter.mutation) then
            goto continue
        end

        -- Filter: minLevel
        if filter.minLevel and level < filter.minLevel then
            goto continue
        end

        -- Filter: maxLevel
        if filter.maxLevel and level > filter.maxLevel then
            goto continue
        end

        -- Filter: minWeight
        if filter.minWeight and weight < filter.minWeight then
            goto continue
        end

        -- Filter: maxWeight
        if filter.maxWeight and weight > filter.maxWeight then
            goto continue
        end

        -- Lolos filter, masukkan ke hasil
        local info = {
            uuid = uuid,
            pet = pet,
            petData = petData,
            name = name,
            mutation = mutation,
            level = level,
            weight = weight,
            isFavorite = isFavorite,
            passive = passive,
        }
        table.insert(results, info)

        ::continue::
    end

    -- Limit
    if filter.limit and #results > filter.limit then
        table.move(results, 1, filter.limit, 1, results)
        for i = filter.limit + 1, #results do
            results[i] = nil
        end
    end

    return results
end

-- ============================================================
-- Cari satu pet (pertama) yang cocok
-- ============================================================
function DataPetModule.findPet(filter)
    local results = DataPetModule.findPets(filter)
    return results[1]
end

-- ============================================================
-- Cooldown caching (dipantau dari event)
-- ============================================================
local cooldownCache = {}

function DataPetModule.getCooldown(uuid)
    return cooldownCache[uuid]
end

-- Listener untuk update cooldown (harus dipanggil dari Main)
local function setupCooldownListener()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local GameEvents = ReplicatedStorage:FindFirstChild("GameEvents")
    if not GameEvents then return end
    local PetCooldownsEvent = GameEvents:FindFirstChild("PetCooldownsUpdated")
    if not PetCooldownsEvent then return end

    PetCooldownsEvent.OnClientEvent:Connect(function(petId, dataArray)
        if type(dataArray) == "table" and #dataArray > 0 then
            local entry = dataArray[1]
            if entry and entry.Time then
                cooldownCache[petId] = {
                    Time = entry.Time,
                    Passive = entry.Passive or ""
                }
            end
        end
    end)
end

-- Panggil setup
setupCooldownListener()

return DataPetModule

-- DataPetModule.lua
local DataPetModule = {}

-- MUTATION MAP yang sudah diperbaiki
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

-- Cari DataService di berbagai lokasi
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
    -- Coba panggil game:GetService
    local success, result = pcall(function()
        return game:GetService("DataService")
    end)
    if success and result then return result end
    error("DataService tidak ditemukan")
end

local DataService = findDataService()

-- Ambil semua data pet
function DataPetModule.getAllPets()
    local data = DataService:GetData()
    if not data then return {} end
    local inv = data.PetsData and data.PetsData.PetInventory and data.PetsData.PetInventory.Data
    return inv or {}
end

-- Dapatkan UUID pet yang sedang di-equip
function DataPetModule.getEquippedPets()
    local data = DataService:GetData()
    if not data then return {} end
    return data.PetsData and data.PetsData.EquippedPets or {}
end

-- Dapatkan detail pet yang sedang di-equip
function DataPetModule.getEquippedPetDetails()
    local equipped = DataPetModule.getEquippedPets()
    local inv = DataPetModule.getAllPets()
    local details = {}
    for _, uuid in ipairs(equipped) do
        local pet = inv[uuid]
        if pet then
            table.insert(details, {uuid = uuid, pet = pet})
        end
    end
    return details
end

-- Terjemahkan kode mutasi
function DataPetModule.getAutoMutationName(rawCode)
    if not rawCode or rawCode == "" then
        return "Normal"
    end
    return MUTATION_MAP[rawCode] or rawCode
end

-- Fungsi pencarian pet dengan filter
function DataPetModule.findPets(filter)
    filter = filter or {}
    local inv = DataPetModule.getAllPets()
    local results = {}
    local limit = filter.limit or math.huge

    for uuid, pet in pairs(inv) do
        if #results >= limit then break end

        -- Ekstrak data
        local pData = pet.PetData or {}
        local pType = pet.PetType or pData.PetType or pData.Name or ""
        local mutationRaw = pData.MutationType or "Normal"
        local mutation = DataPetModule.getAutoMutationName(mutationRaw)
        local level = pData.Level or pData.Lvl or 0
        local weight = pData.Weight or pData.BaseWeight or 0
        local isFavorite = pData.IsFavorite or false
        local passive = pData.Passive or ""

        -- Filter excludeUUIDs
        if filter.excludeUUIDs and type(filter.excludeUUIDs) == "table" then
            local excluded = false
            for _, ex in ipairs(filter.excludeUUIDs) do
                if ex == uuid then excluded = true break end
            end
            if excluded then goto continue end
        end

        -- Filter exactName
        if filter.exactName and string.lower(pType) ~= string.lower(filter.exactName) then
            goto continue
        end

        -- Filter name (partial)
        if filter.name and not string.find(string.lower(pType), string.lower(filter.name)) then
            goto continue
        end

        -- Filter type (sama dengan exactName)
        if filter.type and string.lower(pType) ~= string.lower(filter.type) then
            goto continue
        end

        -- Filter mutation
        if filter.mutation and string.lower(mutation) ~= string.lower(filter.mutation) then
            goto continue
        end

        -- Filter isFavorite
        if filter.isFavorite ~= nil and isFavorite ~= filter.isFavorite then
            goto continue
        end

        -- Filter minLevel / maxLevel
        if filter.minLevel and level < filter.minLevel then
            goto continue
        end
        if filter.maxLevel and level > filter.maxLevel then
            goto continue
        end

        -- Filter minWeight / maxWeight
        if filter.minWeight and weight < filter.minWeight then
            goto continue
        end
        if filter.maxWeight and weight > filter.maxWeight then
            goto continue
        end

        -- Jika lolos semua filter, masukkan ke hasil
        table.insert(results, {
            uuid = uuid,
            pet = pet,
            petData = pData,
            name = pType,
            mutation = mutation,
            level = level,
            weight = weight,
            isFavorite = isFavorite,
            passive = passive,
        })

        ::continue::
    end

    return results
end

-- Cari satu pet (pertama yang cocok)
function DataPetModule.findPet(filter)
    local results = DataPetModule.findPets(filter)
    return results[1]
end

-- Cache cooldown
local cooldownCache = {}

-- Update cooldown dari event
local function onCooldownUpdate(petId, dataArray)
    if type(dataArray) == "table" and #dataArray > 0 then
        local entry = dataArray[1]
        if entry and entry.Time and entry.Passive then
            cooldownCache[petId] = {
                Time = entry.Time,
                Passive = entry.Passive,
                UpdatedAt = os.time()
            }
        end
    end
end

-- Dapatkan cooldown pet
function DataPetModule.getCooldown(uuid)
    return cooldownCache[uuid]
end

-- Setup listener cooldown (otomatis)
local function setupCooldownListener()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local GameEvents = ReplicatedStorage:FindFirstChild("GameEvents")
    if GameEvents then
        local event = GameEvents:FindFirstChild("PetCooldownsUpdated")
        if event then
            event.OnClientEvent:Connect(onCooldownUpdate)
        end
    end
end
setupCooldownListener()

return DataPetModule

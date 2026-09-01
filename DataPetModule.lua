-- DataPetModule.lua
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
    -- Coba cari di MUTATION_MAP
    local translated = MUTATION_MAP[rawCode]
    if translated then
        return translated
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
-- FUNGSI DATA PET
-- ============================================================
local function getDataService()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    -- Coba berbagai lokasi
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

function DataPetModule.getAllPets()
    local data = getDataService():GetData()
    if not data then return {} end
    local inv = data.PetsData and data.PetsData.PetInventory and data.PetsData.PetInventory.Data
    return inv or {}
end

function DataPetModule.getEquippedPets()
    local data = getDataService():GetData()
    if not data then return {} end
    return data.PetsData and data.PetsData.EquippedPets or {}
end

function DataPetModule.getEquippedPetDetails()
    local equipped = DataPetModule.getEquippedPets()
    local allPets = DataPetModule.getAllPets()
    local result = {}
    for _, uuid in ipairs(equipped) do
        local pet = allPets[uuid]
        if pet then
            table.insert(result, {uuid = uuid, pet = pet})
        end
    end
    return result
end

function DataPetModule.findPets(filter)
    filter = filter or {}
    local allPets = DataPetModule.getAllPets()
    local results = {}
    for uuid, pet in pairs(allPets) do
        -- Ambil data
        local pData = pet.PetData or {}
        local pType = pet.PetType or pData.PetType or pData.Name or ""
        local mutationRaw = pData.MutationType or "Normal"
        local mutation = DataPetModule.getAutoMutationName(mutationRaw)
        local level = pData.Level or pData.Lvl or 0
        local weight = pData.Weight or pData.BaseWeight or 0
        local isFavorite = pData.IsFavorite or false
        local passive = pData.Passive or ""

        -- Cek filter
        local match = true
        if filter.type and string.lower(pType) ~= string.lower(filter.type) then match = false end
        if filter.exactName and string.lower(pType) ~= string.lower(filter.exactName) then match = false end
        if filter.name and not string.find(string.lower(pType), string.lower(filter.name)) then match = false end
        if filter.mutation and string.lower(mutation) ~= string.lower(filter.mutation) then match = false end
        if filter.isFavorite ~= nil and isFavorite ~= filter.isFavorite then match = false end
        if filter.minLevel and level < filter.minLevel then match = false end
        if filter.maxLevel and level > filter.maxLevel then match = false end
        if filter.minWeight and weight < filter.minWeight then match = false end
        if filter.maxWeight and weight > filter.maxWeight then match = false end
        if filter.excludeUUIDs and table.find(filter.excludeUUIDs, uuid) then match = false end

        if match then
            table.insert(results, {
                uuid = uuid,
                pet = pet,
                petData = pData,
                name = pType,
                mutation = mutation,
                level = level,
                weight = weight,
                isFavorite = isFavorite,
                passive = passive
            })
        end
    end
    -- Sort by level descending (optional)
    table.sort(results, function(a, b) return a.level > b.level end)
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
    return results[1]
end

-- Cooldown cache
local cooldownCache = {}

function DataPetModule.getCooldown(uuid)
    return cooldownCache[uuid]
end

-- Auto-update cooldown dari event
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
task.spawn(setupCooldownListener)

return DataPetModule

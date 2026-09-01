-- ============================================================
-- DataPetModule - Mengelola data pet dari DataService
-- dengan MUTATION_MAP yang benar (sudah diverifikasi)
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- MUTATION_MAP yang benar berdasarkan debug Anda
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

-- Fungsi untuk mencari DataService (kompatibel dengan executor)
local function findDataService()
    -- Coba di ReplicatedStorage.Modules
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    if modules then
        local ds = modules:FindFirstChild("DataService")
        if ds then
            return require(ds)
        end
    end
    -- Coba langsung di ReplicatedStorage
    local ds = ReplicatedStorage:FindFirstChild("DataService")
    if ds then
        return require(ds)
    end
    -- Coba dari _G
    if _G.DataService then
        return _G.DataService
    end
    -- Coba dari game:GetService
    local success, result = pcall(function()
        return game:GetService("DataService")
    end)
    if success and result then
        return result
    end
    error("DataService tidak ditemukan")
end

local DataService = findDataService()

-- Module utama
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

-- Mendapatkan detail pet yang di-equip (lengkap dengan data)
function DataPetModule.getEquippedPetDetails()
    local equipped = DataPetModule.getEquippedPets()
    local details = {}
    local allPets = DataPetModule.getAllPets()
    for _, uuid in ipairs(equipped) do
        local pet = allPets[uuid]
        if pet then
            table.insert(details, {
                uuid = uuid,
                pet = pet,
                petData = pet.PetData or {}
            })
        end
    end
    return details
end

-- Menerjemahkan kode mutasi mentah menggunakan MUTATION_MAP
function DataPetModule.getAutoMutationName(rawCode)
    if not rawCode or rawCode == "" then
        return "Normal"
    end
    -- Coba langsung di map
    if MUTATION_MAP[rawCode] then
        return MUTATION_MAP[rawCode]
    end
    -- Coba cari di module lain (fallback)
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

-- Mencari pet dengan filter (advanced)
function DataPetModule.findPets(filter)
    filter = filter or {}
    local inv = DataPetModule.getAllPets()
    local results = {}

    -- Helper untuk mencocokkan string (case-insensitive)
    local function matchString(str, pattern, exact)
        if not str then return false end
        str = tostring(str)
        if exact then
            return string.lower(str) == string.lower(pattern)
        else
            return string.find(string.lower(str), string.lower(pattern), 1, true) ~= nil
        end
    end

    for uuid, pet in pairs(inv) do
        local pData = pet.PetData or {}
        local pType = pet.PetType or pData.PetType or pData.Name or ""
        local mutRaw = pData.MutationType or "Normal"
        local mutName = DataPetModule.getAutoMutationName(mutRaw)
        local level = pData.Level or pData.Lvl or 0
        local weight = pData.Weight or pData.BaseWeight or 0
        local isFav = pData.IsFavorite or false
        local passive = pData.Passive or ""

        -- Filter: excludeUUIDs
        if filter.excludeUUIDs and type(filter.excludeUUIDs) == "table" then
            local excluded = false
            for _, ex in ipairs(filter.excludeUUIDs) do
                if ex == uuid then excluded = true break end
            end
            if excluded then goto continue end
        end

        -- Filter: type (exact match)
        if filter.type and not matchString(pType, filter.type, true) then
            goto continue
        end

        -- Filter: exactName (exact match)
        if filter.exactName and not matchString(pType, filter.exactName, true) then
            goto continue
        end

        -- Filter: name (partial match)
        if filter.name and not matchString(pType, filter.name, false) then
            goto continue
        end

        -- Filter: mutation (exact match)
        if filter.mutation and not matchString(mutName, filter.mutation, true) then
            goto continue
        end

        -- Filter: isFavorite
        if filter.isFavorite ~= nil and isFav ~= filter.isFavorite then
            goto continue
        end

        -- Filter: minLevel / maxLevel
        if filter.minLevel and level < filter.minLevel then
            goto continue
        end
        if filter.maxLevel and level > filter.maxLevel then
            goto continue
        end

        -- Filter: minWeight / maxWeight
        if filter.minWeight and weight < filter.minWeight then
            goto continue
        end
        if filter.maxWeight and weight > filter.maxWeight then
            goto continue
        end

        -- Lolos semua filter
        table.insert(results, {
            uuid = uuid,
            pet = pet,
            petData = pData,
            name = pType,
            mutation = mutName,
            level = level,
            weight = weight,
            isFavorite = isFav,
            passive = passive,
            rawMutation = mutRaw,
        })

        ::continue::
    end

    -- Limit
    if filter.limit and filter.limit > 0 then
        local limited = {}
        for i = 1, math.min(filter.limit, #results) do
            limited[i] = results[i]
        end
        return limited
    end

    return results
end

-- Cari satu pet (pertama yang cocok)
function DataPetModule.findPet(filter)
    local results = DataPetModule.findPets(filter)
    if #results > 0 then
        return results[1]
    end
    return nil
end

-- Cache cooldown
local cooldownCache = {}

-- Update cooldown dari event
PetCooldownsUpdated = ReplicatedStorage:FindFirstChild("GameEvents") and ReplicatedStorage.GameEvents:FindFirstChild("PetCooldownsUpdated")
if PetCooldownsUpdated then
    PetCooldownsUpdated.OnClientEvent:Connect(function(petId, dataArray)
        if type(dataArray) == "table" and #dataArray > 0 then
            cooldownCache[petId] = dataArray[1]
        end
    end)
end

-- Ambil cooldown pet
function DataPetModule.getCooldown(uuid)
    return cooldownCache[uuid]
end

return DataPetModule

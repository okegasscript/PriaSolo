-- ============================================================
-- Auto Shark - Main Entry (FINAL dengan fallback)
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- ============================================================
-- FUNGSI UNTUK MENDAPATKAN DATA PET (FALLBACK)
-- ============================================================

local function getFallbackDataPetModule()
    -- Coba ambil DataService langsung
    local DataService = nil
    local success, ds = pcall(function()
        return require(ReplicatedStorage.Modules.DataService)
    end)
    if success and ds then DataService = ds end

    if not DataService then
        -- Coba cari di tempat lain
        local modules = ReplicatedStorage:FindFirstChild("Modules")
        if modules then
            local dsMod = modules:FindFirstChild("DataService")
            if dsMod then
                success, ds = pcall(require, dsMod)
                if success and ds then DataService = ds end
            end
        end
    end

    if not DataService then
        -- Coba dari _G
        if _G.DataService then DataService = _G.DataService end
    end

    if not DataService then
        return nil, "DataService tidak ditemukan di ReplicatedStorage.Modules atau _G"
    end

    -- Buat module sederhana dengan fungsi dasar
    local FallbackModule = {}

    function FallbackModule.getAllPets()
        local data = DataService:GetData()
        if not data then return {} end
        local inv = data.PetsData and data.PetsData.PetInventory and data.PetsData.PetInventory.Data
        return inv or {}
    end

    function FallbackModule.getEquippedPets()
        local data = DataService:GetData()
        if not data then return {} end
        return data.PetsData and data.PetsData.EquippedPets or {}
    end

    -- Mapping mutasi
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

    function FallbackModule.getAutoMutationName(rawCode)
        if not rawCode or rawCode == "" then rawCode = "Normal" end
        return MUTATION_MAP[rawCode] or rawCode
    end

    function FallbackModule.findPets(filter)
        filter = filter or {}
        local allPets = FallbackModule.getAllPets()
        local results = {}
        for uuid, pet in pairs(allPets) do
            local pData = pet.PetData or {}
            local pType = pet.PetType or pData.PetType or pData.Name or "Unknown"
            local name = pType
            local mutationRaw = pData.MutationType or "Normal"
            local mutation = FallbackModule.getAutoMutationName(mutationRaw)
            local level = pData.Level or pData.Lvl or 0
            local weight = pData.Weight or 0
            local isFavorite = pData.IsFavorite or false
            local passive = pData.Passive or ""

            -- Cek filter
            local match = true
            if filter.name and not string.find(string.lower(name), string.lower(filter.name)) then match = false end
            if filter.exactName and string.lower(name) ~= string.lower(filter.exactName) then match = false end
            if filter.type and string.lower(pType) ~= string.lower(filter.type) then match = false end
            if filter.mutation and string.lower(mutation) ~= string.lower(filter.mutation) then match = false end
            if filter.isFavorite ~= nil and isFavorite ~= filter.isFavorite then match = false end
            if filter.minLevel and level < filter.minLevel then match = false end
            if filter.maxLevel and level > filter.maxLevel then match = false end
            if filter.minWeight and weight < filter.minWeight then match = false end
            if filter.maxWeight and weight > filter.maxWeight then match = false end
            if filter.excludeUUIDs then
                for _, ex in ipairs(filter.excludeUUIDs) do
                    if ex == uuid then match = false break end
                end
            end
            if match then
                table.insert(results, {
                    uuid = uuid,
                    pet = pet,
                    petData = pData,
                    name = name,
                    mutation = mutation,
                    level = level,
                    weight = weight,
                    isFavorite = isFavorite,
                    passive = passive
                })
            end
        end
        if filter.limit then
            local limited = {}
            for i = 1, math.min(filter.limit, #results) do
                limited[i] = results[i]
            end
            return limited
        end
        return results
    end

    return FallbackModule, nil
end

-- ============================================================
-- LOAD DataPetModule (dengan fallback)
-- ============================================================

local DataPetModule = nil
local loadError = nil

-- Coba load dari GitHub
local success, module = pcall(function()
    local raw = game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSolo/refs/heads/main/DataPetModule.lua")
    return loadstring(raw)()
end)

if success and module then
    DataPetModule = module
    print("✅ DataPetModule dari GitHub berhasil dimuat")
else
    print("⚠️ Gagal load dari GitHub, menggunakan fallback...")
    DataPetModule, loadError = getFallbackDataPetModule()
    if not DataPetModule then
        warn("❌ Fallback juga gagal:", loadError)
        return
    end
    print("✅ DataPetModule fallback berhasil dimuat")
end

-- ============================================================
-- LOAD SharkLogic (dengan fallback)
-- ============================================================

local SharkLogic = nil
local sharkSuccess, sharkModule = pcall(function()
    local raw = game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSolo/refs/heads/main/SharkLogic.lua")
    return loadstring(raw)()
end)

if sharkSuccess and sharkModule then
    SharkLogic = sharkModule
    print("✅ SharkLogic dari GitHub berhasil dimuat")
else
    -- Fallback sederhana
    SharkLogic = {
        defaultConfig = {
            slotCFrame = CFrame.new(-13.018989562988, 0, -74.922821044922, 1,0,0,0,1,0,0,0,1)
        },
        findTumbal = function(dp, names, ex, minLvl)
            minLvl = minLvl or 0
            ex = ex or {}
            for _, name in ipairs(names) do
                local results = dp.findPets({
                    exactName = name,
                    isFavorite = false,
                    minLevel = minLvl,
                    excludeUUIDs = ex,
                    limit = 10
                })
                for _, info in ipairs(results) do
                    if info.mutation == "Blossoming" then
                        return info.uuid
                    end
                end
            end
            return nil
        end,
        findTarget = function(dp, targetName, ex)
            ex = ex or {}
            local results = dp.findPets({
                exactName = targetName,
                isFavorite = false,
                excludeUUIDs = ex,
                limit = 1
            })
            if #results > 0 then
                local info = results[1]
                if info.mutation ~= "Blossoming" then
                    return info.uuid
                end
            end
            return nil
        end,
        equipPet = function(ps, uuid, cframe)
            if uuid then ps:FireServer("EquipPet", uuid, cframe) end
        end,
        unequipPet = function(ps, uuid)
            if uuid then ps:FireServer("UnequipPet", uuid) end
        end
    }
    print("✅ SharkLogic fallback berhasil dimuat")
end

-- ============================================================
-- LOAD Rayfield
-- ============================================================

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
if not Rayfield then
    warn("❌ Gagal memuat Rayfield")
    return
end

-- ============================================================
-- FUNGSI BANTUAN
-- ============================================================

local function formatPetLabel(pet)
    local mut = pet.mutation or "Normal"
    local name = pet.name or "Unknown"
    local weight = pet.weight or 0
    local level = pet.level or 1
    return string.format("%s %s %.2f KG Lv.%d", mut, name, weight, level)
end

-- ============================================================
-- STATE GLOBAL
-- ============================================================

local state = {
    isActive = false,
    isProcessing = false,
    selectedMimicUUID = nil,
    selectedSharkUUID = nil,
    targetQueue = {},
    currentTargetIndex = 1,
    tumbalNames = {"Dog"},
    minLevel = 100,
    currentTumbalUUID = nil,
    currentTargetUUID = nil,
    cycleCount = 0,
    lastActionTime = 0,

    isLevelingActive = false,
    levelingTim = {},
    levelingTargets = {},
    targetLevel = 100,
    currentLevelingTargetIndex = 1,
    currentLevelingTargetUUID = nil,
}

-- ============================================================
-- EVENT SERVICE
-- ============================================================

local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local PetCooldownsEvent = GameEvents:WaitForChild("PetCooldownsUpdated")
local PetsService = GameEvents:WaitForChild("PetsService")
local NotificationEvent = GameEvents:WaitForChild("Notification")

-- ============================================================
-- FUNGSI LOGIKA AUTO SHARK
-- ============================================================

local function unequipTargetAndEquipShark()
    if state.currentTargetUUID then
        SharkLogic.unequipPet(PetsService, state.currentTargetUUID)
        state.currentTargetUUID = nil
    end
    if state.currentTumbalUUID then
        SharkLogic.unequipPet(PetsService, state.currentTumbalUUID)
        state.currentTumbalUUID = nil
    end
    if state.selectedSharkUUID then
        SharkLogic.equipPet(PetsService, state.selectedSharkUUID, SharkLogic.defaultConfig.slotCFrame)
    end
    state.isProcessing = false
end

local function getNextTarget()
    if #state.targetQueue == 0 then return nil end
    local target = state.targetQueue[state.currentTargetIndex]
    state.currentTargetIndex = state.currentTargetIndex + 1
    if state.currentTargetIndex > #state.targetQueue then
        state.currentTargetIndex = 1
    end
    return target
end

local function unequipSharkAndEquipTumbalTarget()
    if not state.selectedSharkUUID then
        print("⚠️ Shark belum dipilih")
        return
    end
    local targetUUID = getNextTarget()
    if not targetUUID then
        print("⚠️ Tidak ada target tersedia")
        SharkLogic.equipPet(PetsService, state.selectedSharkUUID, SharkLogic.defaultConfig.slotCFrame)
        state.isProcessing = false
        return
    end

    local tumbalUUID = SharkLogic.findTumbal(
        DataPetModule,
        state.tumbalNames,
        {state.selectedMimicUUID, state.selectedSharkUUID},
        state.minLevel or 0
    )

    if tumbalUUID and targetUUID then
        SharkLogic.unequipPet(PetsService, state.selectedSharkUUID)
        SharkLogic.equipPet(PetsService, tumbalUUID, SharkLogic.defaultConfig.slotCFrame)
        state.currentTumbalUUID = tumbalUUID
        SharkLogic.equipPet(PetsService, targetUUID, SharkLogic.defaultConfig.slotCFrame)
        state.currentTargetUUID = targetUUID
        state.isProcessing = true
        print("✅ Equip tumbal & target (target #" .. state.currentTargetIndex .. "/" .. #state.targetQueue .. ")")
    else
        print("⚠️ Tumbal atau target tidak ditemukan")
        SharkLogic.equipPet(PetsService, state.selectedSharkUUID, SharkLogic.defaultConfig.slotCFrame)
        state.isProcessing = false
    end
end

-- ============================================================
-- FUNGSI LOGIKA AUTO LEVELING
-- ============================================================

local function unequipAllGardenPets()
    local data = DataPetModule.getAllPets()
    if not data then return end
    local equipped = data.PetsData and data.PetsData.EquippedPets
    if equipped and type(equipped) == "table" then
        for _, uuid in ipairs(equipped) do
            SharkLogic.unequipPet(PetsService, uuid)
        end
    end
end

local function getPetLevel(uuid)
    local data = DataPetModule.getAllPets()
    if not data then return 0 end
    local pet = data[uuid]
    if pet and pet.PetData then
        return pet.PetData.Level or pet.PetData.Lvl or 0
    end
    return 0
end

local function unequipLevelingTarget()
    if state.currentLevelingTargetUUID then
        SharkLogic.unequipPet(PetsService, state.currentLevelingTargetUUID)
        state.currentLevelingTargetUUID = nil
    end
end

local function equipLevelingTim()
    for _, uuid in ipairs(state.levelingTim) do
        SharkLogic.equipPet(PetsService, uuid, SharkLogic.defaultConfig.slotCFrame)
    end
end

local function processLeveling()
    if not state.isLevelingActive then return end

    if #state.levelingTargets == 0 then
        print("✅ Semua target selesai")
        state.isLevelingActive = false
        return
    end

    local targetUUID = state.levelingTargets[state.currentLevelingTargetIndex]
    if not targetUUID then
        state.currentLevelingTargetIndex = 1
        targetUUID = state.levelingTargets[1]
    end

    local currentLevel = getPetLevel(targetUUID)
    if currentLevel >= state.targetLevel then
        print("✅ Target sudah mencapai level", state.targetLevel, "- lewati")
        unequipLevelingTarget()
        state.currentLevelingTargetIndex = state.currentLevelingTargetIndex + 1
        if state.currentLevelingTargetIndex > #state.levelingTargets then
            state.currentLevelingTargetIndex = 1
        end
        task.spawn(processLeveling)
        return
    end

    if state.currentLevelingTargetUUID ~= targetUUID then
        unequipLevelingTarget()
        SharkLogic.equipPet(PetsService, targetUUID, SharkLogic.defaultConfig.slotCFrame)
        state.currentLevelingTargetUUID = targetUUID
        print("📈 Equip target leveling:", targetUUID, "Level:", currentLevel, "/", state.targetLevel)
    end

    task.wait(2)
    if state.isLevelingActive then
        processLeveling()
    end
end

local function startLeveling()
    if #state.levelingTim == 0 then
        print("⚠️ Tim leveling kosong!")
        return
    end
    if #state.levelingTargets == 0 then
        print("⚠️ Target leveling kosong!")
        return
    end

    unequipAllGardenPets()
    task.wait(0.5)
    equipLevelingTim()
    print("✅ Tim leveling di-equip")

    state.currentLevelingTargetIndex = 1
    state.isLevelingActive = true
    print("▶️ Auto Leveling dimulai")
    processLeveling()
end

local function stopLeveling()
    state.isLevelingActive = false
    unequipLevelingTarget()
    unequipAllGardenPets()
    print("⏹️ Auto Leveling dihentikan")
end

-- ============================================================
-- EVENT LISTENER (Cooldown untuk Auto Shark)
-- ============================================================

local isHandlingCooldownEvent = false

PetCooldownsEvent.OnClientEvent:Connect(function(petId, dataArray)
    if state.isActive and petId == state.selectedMimicUUID and not isHandlingCooldownEvent then
        local time = nil
        for _, entry in ipairs(dataArray) do
            if entry.Time then time = entry.Time break end
        end
        if time == nil then return end

        if state.isProcessing and time > 0.1 then
            isHandlingCooldownEvent = true
            pcall(unequipTargetAndEquipShark)
            isHandlingCooldownEvent = false
        end

        if not state.isProcessing and time <= 0.1 then
            local now = os.clock()
            if now - state.lastActionTime < 0.5 then return end
            state.lastActionTime = now
            isHandlingCooldownEvent = true
            task.spawn(function()
                task.wait(0.6)
                pcall(unequipSharkAndEquipTumbalTarget)
                isHandlingCooldownEvent = false
            end)
        end
    end
end)

NotificationEvent.OnClientEvent:Connect(function(message)
    if state.isActive and state.isProcessing and type(message) == "string" and string.find(message, "Mimic Octopus") then
        if string.find(message, "spat its Blossoming mutation onto") or string.find(message, "mutation failed to transfer") then
            unequipTargetAndEquipShark()
        end
    end
end)

-- ============================================================
-- UI (Rayfield)
-- ============================================================

local Window = Rayfield:CreateWindow({
    Name = "Auto Shark",
    LoadingTitle = "Memuat...",
    LoadingSubtitle = "by PriaSolo",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "AutoShark",
        FileName = "Settings"
    },
    Key = Enum.KeyCode.K,
    AutoLoadConfig = true,
    AutoSaveConfig = true
})

-- ============================================================
-- TAB 1: AUTO SHARK
-- ============================================================

local SharkTab = Window:CreateTab("Auto Shark")

local StatusLabel = SharkTab:CreateLabel("Mimic: (belum) | Shark: (belum) | Target: 0 terpilih")

local function updateStatusLabel()
    local mimicText = state.selectedMimicUUID and tostring(state.selectedMimicUUID) or "(belum)"
    local sharkText = state.selectedSharkUUID and tostring(state.selectedSharkUUID) or "(belum)"
    local targetCount = #state.targetQueue
    StatusLabel:Set("Mimic: " .. mimicText .. " | Shark: " .. sharkText .. " | Target: " .. targetCount .. " terpilih")
end

-- Dropdown Mimic
local mimicLabelToUUID = {}
local MimicDropdown = SharkTab:CreateDropdown({
    Name = "Pilih Mimic",
    Options = {"Memuat data..."},
    CurrentOption = "Memuat data...",
    MultipleOptions = false,
    Callback = function(option)
        local selectedLabel = (type(option) == "table") and option[1] or option
        local uuid = mimicLabelToUUID[selectedLabel]
        if uuid then
            state.selectedMimicUUID = uuid
            print("✅ Mimic dipilih:", selectedLabel, "UUID:", uuid)
            updateStatusLabel()
        end
    end
})

local function refreshMimicDropdown()
    local hasil = DataPetModule.findPets({ name = "Mimic", isFavorite = true })
    local options = {}
    mimicLabelToUUID = {}
    for _, pet in ipairs(hasil) do
        local label = formatPetLabel(pet)
        if mimicLabelToUUID[label] then label = label .. " [" .. string.sub(pet.uuid, 1, 4) .. "]" end
        table.insert(options, label)
        mimicLabelToUUID[label] = pet.uuid
    end
    if #options == 0 then options = {"❌ Tidak ada Mimic favorit"} end
    MimicDropdown:Refresh(options)
end

-- Dropdown Shark
local sharkLabelToUUID = {}
local SharkDropdown = SharkTab:CreateDropdown({
    Name = "Pilih Shark",
    Options = {"Memuat data..."},
    CurrentOption = "Memuat data...",
    MultipleOptions = false,
    Callback = function(option)
        local selectedLabel = (type(option) == "table") and option[1] or option
        local uuid = sharkLabelToUUID[selectedLabel]
        if uuid then
            state.selectedSharkUUID = uuid
            print("✅ Shark dipilih:", selectedLabel, "UUID:", uuid)
            updateStatusLabel()
        end
    end
})

local function refreshSharkDropdown()
    local hasil = DataPetModule.findPets({ name = "Shark", isFavorite = true })
    local options = {}
    sharkLabelToUUID = {}
    for _, pet in ipairs(hasil) do
        local label = formatPetLabel(pet)
        if sharkLabelToUUID[label] then label = label .. " [" .. string.sub(pet.uuid, 1, 4) .. "]" end
        table.insert(options, label)
        sharkLabelToUUID[label] = pet.uuid
    end
    if #options == 0 then options = {"❌ Tidak ada Shark favorit"} end
    SharkDropdown:Refresh(options)
end

-- Dropdown Target (Multiple, Non-Fav, Mutasi Normal)
local targetLabelToUUID = {}
local TargetDropdown = SharkTab:CreateDropdown({
    Name = "Pilih Target (Multiple, Non-Fav, Normal)",
    Options = {"Memuat data..."},
    CurrentOption = "Memuat data...",
    MultipleOptions = true,
    Callback = function(selectedLabels)
        state.targetQueue = {}
        for _, label in ipairs(selectedLabels) do
            local uuid = targetLabelToUUID[label]
            if uuid then table.insert(state.targetQueue, uuid) end
        end
        state.currentTargetIndex = 1
        print("✅ Target dipilih:", #state.targetQueue, "pet")
        updateStatusLabel()
    end
})

local function refreshTargetDropdown()
    local hasil = DataPetModule.findPets({
        type = "Mimic Octopus",
        isFavorite = false,
        mutation = "Normal",
        excludeUUIDs = {state.selectedMimicUUID, state.selectedSharkUUID}
    })
    local options = {}
    targetLabelToUUID = {}
    for _, pet in ipairs(hasil) do
        local label = formatPetLabel(pet)
        if targetLabelToUUID[label] then label = label .. " [" .. string.sub(pet.uuid, 1, 4) .. "]" end
        table.insert(options, label)
        targetLabelToUUID[label] = pet.uuid
    end
    if #options == 0 then options = {"❌ Tidak ada target"} end
    TargetDropdown:Refresh(options)
end

-- Input Tumbal
SharkTab:CreateInput({
    Name = "Nama Tumbal (pisah koma)",
    PlaceholderText = "Contoh: Dog, Golden Lab, Black Bunny",
    CurrentValue = table.concat(state.tumbalNames, ", "),
    Callback = function(Value)
        if Value and Value ~= "" then
            local names = {}
            for token in string.gmatch(Value, "[^,]+") do
                local trimmed = token:match("^%s*(.-)%s*$")
                if trimmed ~= "" then table.insert(names, trimmed) end
            end
            if #names > 0 then
                state.tumbalNames = names
                print("✅ Tumbal diubah:", table.concat(names, ", "))
            end
        end
    end
})

-- Slider Min Level
SharkTab:CreateSlider({
    Name = "Min Level Tumbal",
    Range = {0, 500},
    Increment = 1,
    Suffix = "Level",
    CurrentValue = state.minLevel,
    Callback = function(value)
        state.minLevel = value
        print("📊 Min Level Tumbal:", value)
    end
})

-- Refresh Button
SharkTab:CreateButton({
    Name = "🔄 Refresh Daftar Pet",
    Callback = function()
        refreshMimicDropdown()
        refreshSharkDropdown()
        refreshTargetDropdown()
    end
})

-- Start/Stop Toggle
local SharkToggle
SharkToggle = SharkTab:CreateToggle({
    Name = "▶️ Start / Stop",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            if not state.selectedMimicUUID then
                print("⚠️ Pilih Mimic dulu!")
                if SharkToggle then SharkToggle:Set(false) end
                return
            end
            if not state.selectedSharkUUID then
                print("⚠️ Pilih Shark dulu!")
                if SharkToggle then SharkToggle:Set(false) end
                return
            end
            if #state.targetQueue == 0 then
                print("⚠️ Pilih target dulu (multiple)!")
                if SharkToggle then SharkToggle:Set(false) end
                return
            end
            state.isActive = true
            print("▶️ Auto Shark dimulai dengan", #state.targetQueue, "target")
            SharkLogic.equipPet(PetsService, state.selectedMimicUUID, SharkLogic.defaultConfig.slotCFrame)
            SharkLogic.equipPet(PetsService, state.selectedSharkUUID, SharkLogic.defaultConfig.slotCFrame)
        else
            state.isActive = false
            print("⏹️ Auto Shark dihentikan")
            unequipTargetAndEquipShark()
            if state.selectedMimicUUID then
                SharkLogic.unequipPet(PetsService, state.selectedMimicUUID)
            end
            if state.selectedSharkUUID then
                SharkLogic.unequipPet(PetsService, state.selectedSharkUUID)
            end
        end
    end
})

-- ============================================================
-- TAB 2: AUTO LEVELING
-- ============================================================

local LevelingTab = Window:CreateTab("Auto Leveling")

-- Tim Leveling
local timLabelToUUID = {}
local TimDropdown = LevelingTab:CreateDropdown({
    Name = "Tim Leveling (Max 7, Favorit)",
    Options = {"Memuat data..."},
    CurrentOption = "Memuat data...",
    MultipleOptions = true,
    Callback = function(selectedLabels)
        state.levelingTim = {}
        for _, label in ipairs(selectedLabels) do
            local uuid = timLabelToUUID[label]
            if uuid then table.insert(state.levelingTim, uuid) end
        end
        if #state.levelingTim > 7 then
            print("⚠️ Maksimal 7 pet! Hanya 7 pertama yang dipakai.")
            table.move(state.levelingTim, 1, 7, 1, {})
        end
        print("✅ Tim Leveling dipilih:", #state.levelingTim, "pet")
    end
})

local function refreshTimDropdown()
    local hasil = DataPetModule.findPets({ isFavorite = true })
    local options = {}
    timLabelToUUID = {}
    for _, pet in ipairs(hasil) do
        local label = formatPetLabel(pet)
        if timLabelToUUID[label] then label = label .. " [" .. string.sub(pet.uuid, 1, 4) .. "]" end
        table.insert(options, label)
        timLabelToUUID[label] = pet.uuid
    end
    if #options == 0 then options = {"❌ Tidak ada pet favorit"} end
    TimDropdown:Refresh(options)
end

-- Target Leveling
local targetLevelLabelToUUID = {}
local TargetLevelDropdown = LevelingTab:CreateDropdown({
    Name = "Target Leveling (Non-Favorit)",
    Options = {"Memuat data..."},
    CurrentOption = "Memuat data...",
    MultipleOptions = true,
    Callback = function(selectedLabels)
        state.levelingTargets = {}
        for _, label in ipairs(selectedLabels) do
            local uuid = targetLevelLabelToUUID[label]
            if uuid then table.insert(state.levelingTargets, uuid) end
        end
        state.currentLevelingTargetIndex = 1
        print("✅ Target Leveling dipilih:", #state.levelingTargets, "pet")
    end
})

local function refreshTargetLevelDropdown()
    local hasil = DataPetModule.findPets({ isFavorite = false })
    local options = {}
    targetLevelLabelToUUID = {}
    for _, pet in ipairs(hasil) do
        local label = formatPetLabel(pet)
        if targetLevelLabelToUUID[label] then label = label .. " [" .. string.sub(pet.uuid, 1, 4) .. "]" end
        table.insert(options, label)
        targetLevelLabelToUUID[label] = pet.uuid
    end
    if #options == 0 then options = {"❌ Tidak ada pet non-favorit"} end
    TargetLevelDropdown:Refresh(options)
end

-- Slider Target Level
LevelingTab:CreateSlider({
    Name = "Target Level",
    Range = {0, 500},
    Increment = 1,
    Suffix = "Level",
    CurrentValue = state.targetLevel,
    Callback = function(value)
        state.targetLevel = value
        print("🎯 Target Level:", value)
    end
})

-- Refresh Button
LevelingTab:CreateButton({
    Name = "🔄 Refresh Daftar Pet",
    Callback = function()
        refreshTimDropdown()
        refreshTargetLevelDropdown()
    end
})

-- Start/Stop Toggle Leveling
local LevelingToggle
LevelingToggle = LevelingTab:CreateToggle({
    Name = "▶️ Start / Stop Leveling",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            if #state.levelingTim == 0 then
                print("⚠️ Pilih Tim Leveling dulu!")
                if LevelingToggle then LevelingToggle:Set(false) end
                return
            end
            if #state.levelingTargets == 0 then
                print("⚠️ Pilih Target Leveling dulu!")
                if LevelingToggle then LevelingToggle:Set(false) end
                return
            end
            startLeveling()
        else
            stopLeveling()
        end
    end
})

-- ============================================================
-- INISIALISASI
-- ============================================================

refreshMimicDropdown()
refreshSharkDropdown()
refreshTargetDropdown()
refreshTimDropdown()
refreshTargetLevelDropdown()
updateStatusLabel()

print("✅ Auto Shark siap. Tekan K untuk membuka UI.")

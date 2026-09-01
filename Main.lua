-- ============================================================
-- Auto Shark - Main Entry (FINAL)
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Load modul (gunakan raw URL yang benar)
local DataPetModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSolo/refs/heads/main/DataPetModule.lua"))()
local SharkLogic = loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSolo/refs/heads/main/SharkLogic.lua"))()
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

if not DataPetModule or not SharkLogic or not Rayfield then
    warn("❌ Gagal memuat modul")
    return
end

print("✅ Semua modul berhasil dimuat")

-- ============================================================
-- FUNGSI BANTUAN
-- ============================================================

-- Format label pet: Mutasi Nama Berat KG Lv.Level
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
    -- Auto Shark
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

    -- Auto Leveling
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

-- Dropdown Mimic (Favorit, mengandung "Mimic")
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

-- Dropdown Shark (Favorit, mengandung "Shark")
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

-- Input Tumbal (dengan spasi)
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

-- Tim Leveling (Multiple, max 7, isFavorite=true)
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

-- Target Leveling (Multiple, isFavorite=false)
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

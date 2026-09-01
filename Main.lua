-- ============================================================
-- Pria Solo HUB - Main Entry (FINAL - Selective Unequip)
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local CONFIG_FILE = "PriaSolo.json"

-- Load modul
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

local function formatPetLabel(pet)
    local mut = pet.mutation or "Normal"
    local name = pet.name or "Unknown"
    local weight = pet.weight or 0
    if weight <= 0 then
        local baseWeight = (pet.petData and pet.petData.BaseWeight) or 0
        local level = pet.level or 1
        weight = baseWeight + (level - 1) * 0.5599
    end
    local level = pet.level or 1
    return string.format("%s %s %.2f KG Lv.%d", mut, name, weight, level)
end

local function sortAlphabetically(a, b)
    return string.lower(a) < string.lower(b)
end

-- ============================================================
-- STATE GLOBAL
-- ============================================================

local state = {
    isSharkActive = false,
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

local isLevelingProcessing = false

-- ============================================================
-- EVENT SERVICE
-- ============================================================

local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local PetCooldownsEvent = GameEvents:WaitForChild("PetCooldownsUpdated")
local PetsService = GameEvents:WaitForChild("PetsService")
local NotificationEvent = GameEvents:WaitForChild("Notification")

-- ============================================================
-- FUNGSI UNEQUIP SELEKTIF (hanya unequip yang tidak dipertahankan)
-- ============================================================

local function unequipAllGardenPets(keepUUIDs)
    keepUUIDs = keepUUIDs or {}
    local data = DataPetModule.getAllPets()
    if not data then return end
    local equipped = data.PetsData and data.PetsData.EquippedPets
    if not equipped or type(equipped) ~= "table" then return end

    local keepMap = {}
    for _, uuid in ipairs(keepUUIDs) do
        keepMap[uuid] = true
    end

    local count = 0
    for _, uuid in ipairs(equipped) do
        if not keepMap[uuid] then
            SharkLogic.unequipPet(PetsService, uuid)
            count = count + 1
            task.wait(0.05) -- jeda agar tidak overload
        end
    end
    if count > 0 then
        print("🔄 Unequip " .. count .. " pet (tidak dipertahankan)")
    end
end

-- ============================================================
-- FUNGSI LOGIKA AUTO SHARK
-- ============================================================

local function unequipTargetAndEquipShark()
    if state.currentTargetUUID then
        SharkLogic.unequipPet(PetsService, state.currentTargetUUID)
        state.currentTargetUUID = nil
        task.wait(0.05)
    end
    if state.currentTumbalUUID then
        SharkLogic.unequipPet(PetsService, state.currentTumbalUUID)
        state.currentTumbalUUID = nil
        task.wait(0.05)
    end
    if state.selectedSharkUUID then
        SharkLogic.equipPet(PetsService, state.selectedSharkUUID, SharkLogic.defaultConfig.slotCFrame)
        task.wait(0.05)
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
        task.wait(0.05)
        SharkLogic.equipPet(PetsService, tumbalUUID, SharkLogic.defaultConfig.slotCFrame)
        state.currentTumbalUUID = tumbalUUID
        task.wait(0.05)
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
-- FUNGSI LOGIKA AUTO LEVELING (dengan jeda anti-freeze)
-- ============================================================

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
        task.wait(0.05)
    end
end

local function equipLevelingTim()
    for _, uuid in ipairs(state.levelingTim) do
        SharkLogic.equipPet(PetsService, uuid, SharkLogic.defaultConfig.slotCFrame)
        task.wait(0.05)
    end
end

local function processLeveling()
    if not state.isLevelingActive or isLevelingProcessing then return end
    isLevelingProcessing = true

    while state.isLevelingActive do
        if #state.levelingTargets == 0 then
            print("✅ Semua target selesai")
            state.isLevelingActive = false
            break
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
            continue
        end

        if state.currentLevelingTargetUUID ~= targetUUID then
            unequipLevelingTarget()
            SharkLogic.equipPet(PetsService, targetUUID, SharkLogic.defaultConfig.slotCFrame)
            state.currentLevelingTargetUUID = targetUUID
            print("📈 Equip target leveling:", targetUUID, "Level:", currentLevel, "/", state.targetLevel)
        end

        -- Tunggu 2 detik sebelum cek lagi (dengan loop agar bisa diinterupsi)
        for _ = 1, 2 do
            if not state.isLevelingActive then break end
            task.wait(1)
        end
    end

    isLevelingProcessing = false
end

local function startLeveling()
    if isLevelingProcessing then
        state.isLevelingActive = false
        task.wait(0.2)
    end

    if #state.levelingTim == 0 then
        print("⚠️ Tim leveling kosong!")
        return
    end
    if #state.levelingTargets == 0 then
        print("⚠️ Target leveling kosong!")
        return
    end

    -- Bersihkan garden, pertahankan hanya tim yang akan di-equip
    unequipAllGardenPets(state.levelingTim)
    task.wait(0.2)

    equipLevelingTim()
    print("✅ Tim leveling di-equip")

    state.currentLevelingTargetIndex = 1
    state.isLevelingActive = true
    print("▶️ Auto Leveling dimulai")
    task.spawn(processLeveling)
end

local function stopLeveling()
    state.isLevelingActive = false
    while isLevelingProcessing do task.wait(0.1) end

    -- Unequip target yang sedang aktif
    if state.currentLevelingTargetUUID then
        SharkLogic.unequipPet(PetsService, state.currentLevelingTargetUUID)
        state.currentLevelingTargetUUID = nil
        task.wait(0.05)
    end

    -- Unequip semua tim
    for _, uuid in ipairs(state.levelingTim) do
        SharkLogic.unequipPet(PetsService, uuid)
        task.wait(0.05)
    end

    -- Bersihkan semua pet lain di garden (tidak ada yang dipertahankan)
    unequipAllGardenPets({})
    print("⏹️ Auto Leveling dihentikan, semua pet diunequip.")
end

-- ============================================================
-- EVENT LISTENER (Cooldown untuk Auto Shark)
-- ============================================================

local isHandlingCooldownEvent = false

PetCooldownsEvent.OnClientEvent:Connect(function(petId, dataArray)
    if state.isSharkActive and petId == state.selectedMimicUUID and not isHandlingCooldownEvent then
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
    if state.isSharkActive and state.isProcessing and type(message) == "string" and string.find(message, "Mimic Octopus") then
        if string.find(message, "spat its Blossoming mutation onto") or string.find(message, "mutation failed to transfer") then
            unequipTargetAndEquipShark()
        end
    end
end)

-- ============================================================
-- SAVE / LOAD
-- ============================================================

local function saveConfig()
    local config = {
        selectedMimicUUID = state.selectedMimicUUID,
        selectedSharkUUID = state.selectedSharkUUID,
        targetQueue = state.targetQueue,
        tumbalNames = state.tumbalNames,
        minLevel = state.minLevel,
        levelingTim = state.levelingTim,
        levelingTargets = state.levelingTargets,
        targetLevel = state.targetLevel,
        timestamp = os.time()
    }
    local json = HttpService:JSONEncode(config)
    local success, err = pcall(function()
        writefile(CONFIG_FILE, json)
    end)
    if success then
        print("✅ Konfigurasi disimpan ke " .. CONFIG_FILE)
    else
        warn("❌ Gagal menyimpan: " .. tostring(err))
    end
end

local function loadConfig()
    local success, data = pcall(function()
        return readfile(CONFIG_FILE)
    end)
    if not success then
        print("ℹ️ File konfigurasi tidak ditemukan, gunakan default.")
        return
    end
    local decoded = HttpService:JSONDecode(data)
    if decoded then
        state.selectedMimicUUID = decoded.selectedMimicUUID
        state.selectedSharkUUID = decoded.selectedSharkUUID
        state.targetQueue = decoded.targetQueue or {}
        state.tumbalNames = decoded.tumbalNames or {"Dog"}
        state.minLevel = decoded.minLevel or 100
        state.levelingTim = decoded.levelingTim or {}
        state.levelingTargets = decoded.levelingTargets or {}
        state.targetLevel = decoded.targetLevel or 100
        print("✅ Konfigurasi dimuat dari " .. CONFIG_FILE)
        refreshAllUI()
    else
        warn("❌ Gagal memuat file.")
    end
end

-- ============================================================
-- UI (Rayfield)
-- ============================================================

local Window = Rayfield:CreateWindow({
    Name = "Pria Solo HUB",
    LoadingTitle = "Memuat...",
    LoadingSubtitle = "by PriaSolo",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "PriaSolo",
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

local function refreshAllUI()
    refreshMimicDropdown()
    refreshSharkDropdown()
    refreshTargetDropdown()
    refreshTimDropdown()
    refreshTargetLevelDropdown()
    updateStatusLabel()
    if TumbalInput then
        TumbalInput:Set(table.concat(state.tumbalNames, ", "))
    end
    if MinLevelSlider then
        MinLevelSlider:Set(state.minLevel)
    end
    if TargetLevelSlider then
        TargetLevelSlider:Set(state.targetLevel)
    end
end

-- ============================================================
-- DROPDOWN MIMIC (dengan filter dan restore selection)
-- ============================================================

local mimicLabelToUUID = {}
local MimicDropdown
local MimicFilterInput

local function refreshMimicDropdown(filterText)
    filterText = filterText or (MimicFilterInput and MimicFilterInput:Get() or "")
    local currentUUID = state.selectedMimicUUID
    local hasil = DataPetModule.findPets({ name = "Mimic", isFavorite = true })
    local options = {}
    mimicLabelToUUID = {}
    for _, pet in ipairs(hasil) do
        local label = formatPetLabel(pet)
        if string.lower(label):find(string.lower(filterText)) then
            if mimicLabelToUUID[label] then
                label = label .. " [" .. string.sub(pet.uuid, 1, 4) .. "]"
            end
            table.insert(options, label)
            mimicLabelToUUID[label] = pet.uuid
        end
    end
    table.sort(options, sortAlphabetically)
    if #options == 0 then options = {"❌ Tidak ada Mimic favorit"} end
    MimicDropdown:Refresh(options)
    if currentUUID then
        for label, uuid in pairs(mimicLabelToUUID) do
            if uuid == currentUUID then
                MimicDropdown:SetCurrentOption(label)
                break
            end
        end
    end
end

MimicFilterInput = SharkTab:CreateInput({
    Name = "🔍 Cari Mimic",
    PlaceholderText = "Ketik untuk filter...",
    CurrentValue = "",
    Callback = function(Value)
        refreshMimicDropdown(Value)
    end
})

MimicDropdown = SharkTab:CreateDropdown({
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

-- ============================================================
-- DROPDOWN SHARK (dengan filter dan restore selection)
-- ============================================================

local sharkLabelToUUID = {}
local SharkDropdown
local SharkFilterInput

local function refreshSharkDropdown(filterText)
    filterText = filterText or (SharkFilterInput and SharkFilterInput:Get() or "")
    local currentUUID = state.selectedSharkUUID
    local hasil = DataPetModule.findPets({ name = "Shark", isFavorite = true })
    local options = {}
    sharkLabelToUUID = {}
    for _, pet in ipairs(hasil) do
        local label = formatPetLabel(pet)
        if string.lower(label):find(string.lower(filterText)) then
            if sharkLabelToUUID[label] then
                label = label .. " [" .. string.sub(pet.uuid, 1, 4) .. "]"
            end
            table.insert(options, label)
            sharkLabelToUUID[label] = pet.uuid
        end
    end
    table.sort(options, sortAlphabetically)
    if #options == 0 then options = {"❌ Tidak ada Shark favorit"} end
    SharkDropdown:Refresh(options)
    if currentUUID then
        for label, uuid in pairs(sharkLabelToUUID) do
            if uuid == currentUUID then
                SharkDropdown:SetCurrentOption(label)
                break
            end
        end
    end
end

SharkFilterInput = SharkTab:CreateInput({
    Name = "🔍 Cari Shark",
    PlaceholderText = "Ketik untuk filter...",
    CurrentValue = "",
    Callback = function(Value)
        refreshSharkDropdown(Value)
    end
})

SharkDropdown = SharkTab:CreateDropdown({
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

-- ============================================================
-- DROPDOWN TARGET (Multiple, Non-Fav, Normal)
-- ============================================================

local targetLabelToUUID = {}
local TargetDropdown
local TargetFilterInput

local function refreshTargetDropdown(filterText)
    filterText = filterText or (TargetFilterInput and TargetFilterInput:Get() or "")
    local currentQueue = state.targetQueue
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
        if string.lower(label):find(string.lower(filterText)) then
            if targetLabelToUUID[label] then
                label = label .. " [" .. string.sub(pet.uuid, 1, 4) .. "]"
            end
            table.insert(options, label)
            targetLabelToUUID[label] = pet.uuid
        end
    end
    table.sort(options, sortAlphabetically)
    if #options == 0 then options = {"❌ Tidak ada target"} end
    TargetDropdown:Refresh(options)
    if #currentQueue > 0 then
        local selectedLabels = {}
        for _, uuid in ipairs(currentQueue) do
            for label, u in pairs(targetLabelToUUID) do
                if u == uuid then
                    table.insert(selectedLabels, label)
                    break
                end
            end
        end
        if #selectedLabels > 0 then
            TargetDropdown:SetSelectedOptions(selectedLabels)
        end
    end
end

TargetFilterInput = SharkTab:CreateInput({
    Name = "🔍 Cari Target",
    PlaceholderText = "Ketik untuk filter...",
    CurrentValue = "",
    Callback = function(Value)
        refreshTargetDropdown(Value)
    end
})

TargetDropdown = SharkTab:CreateDropdown({
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

-- ============================================================
-- TUMBAL INPUT
-- ============================================================

local TumbalInput = SharkTab:CreateInput({
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

-- ============================================================
-- SLIDER MIN LEVEL
-- ============================================================

local MinLevelSlider = SharkTab:CreateSlider({
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

-- ============================================================
-- REFRESH BUTTON
-- ============================================================

SharkTab:CreateButton({
    Name = "🔄 Refresh Daftar Pet",
    Callback = function()
        refreshMimicDropdown()
        refreshSharkDropdown()
        refreshTargetDropdown()
        refreshTimDropdown()
        refreshTargetLevelDropdown()
    end
})

-- ============================================================
-- START/STOP SHARK
-- ============================================================

local SharkToggle
SharkToggle = SharkTab:CreateToggle({
    Name = "▶️ Start / Stop Shark",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            if state.isLevelingActive then
                print("⚠️ Auto Leveling sedang aktif! Matikan dulu.")
                if SharkToggle then SharkToggle:Set(false) end
                return
            end
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

            -- Bersihkan garden, pertahankan Mimic & Shark
            unequipAllGardenPets({state.selectedMimicUUID, state.selectedSharkUUID})
            task.wait(0.2)

            state.isSharkActive = true
            print("▶️ Auto Shark dimulai dengan", #state.targetQueue, "target")
            SharkLogic.equipPet(PetsService, state.selectedMimicUUID, SharkLogic.defaultConfig.slotCFrame)
            SharkLogic.equipPet(PetsService, state.selectedSharkUUID, SharkLogic.defaultConfig.slotCFrame)
        else
            state.isSharkActive = false
            print("⏹️ Auto Shark dihentikan")
            unequipTargetAndEquipShark()
            -- Bersihkan semua pet di garden (tidak ada yang dipertahankan)
            unequipAllGardenPets({})
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

-- ============================================================
-- DROPDOWN TIM LEVELING (Favorit, max 7)
-- ============================================================

local timLabelToUUID = {}
local TimDropdown
local TimFilterInput

local function refreshTimDropdown(filterText)
    filterText = filterText or (TimFilterInput and TimFilterInput:Get() or "")
    local hasil = DataPetModule.findPets({ isFavorite = true })
    local options = {}
    timLabelToUUID = {}
    for _, pet in ipairs(hasil) do
        local label = formatPetLabel(pet)
        if string.lower(label):find(string.lower(filterText)) then
            if timLabelToUUID[label] then
                label = label .. " [" .. string.sub(pet.uuid, 1, 4) .. "]"
            end
            table.insert(options, label)
            timLabelToUUID[label] = pet.uuid
        end
    end
    table.sort(options, sortAlphabetically)
    if #options == 0 then options = {"❌ Tidak ada pet favorit"} end
    TimDropdown:Refresh(options)
    if #state.levelingTim > 0 then
        local selectedLabels = {}
        for _, uuid in ipairs(state.levelingTim) do
            for label, u in pairs(timLabelToUUID) do
                if u == uuid then
                    table.insert(selectedLabels, label)
                    break
                end
            end
        end
        if #selectedLabels > 0 then
            TimDropdown:SetSelectedOptions(selectedLabels)
        end
    end
end

TimFilterInput = LevelingTab:CreateInput({
    Name = "🔍 Cari Tim",
    PlaceholderText = "Ketik untuk filter...",
    CurrentValue = "",
    Callback = function(Value)
        refreshTimDropdown(Value)
    end
})

TimDropdown = LevelingTab:CreateDropdown({
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
        if state.isLevelingActive and not isLevelingProcessing then
            state.isLevelingActive = false
            task.wait(0.1)
            startLeveling()
        end
    end
})

-- ============================================================
-- DROPDOWN TARGET LEVELING (Non-Favorit)
-- ============================================================

local targetLevelLabelToUUID = {}
local TargetLevelDropdown
local TargetLevelFilterInput

local function refreshTargetLevelDropdown(filterText)
    filterText = filterText or (TargetLevelFilterInput and TargetLevelFilterInput:Get() or "")
    local hasil = DataPetModule.findPets({ isFavorite = false })
    local options = {}
    targetLevelLabelToUUID = {}
    for _, pet in ipairs(hasil) do
        local label = formatPetLabel(pet)
        if string.lower(label):find(string.lower(filterText)) then
            if targetLevelLabelToUUID[label] then
                label = label .. " [" .. string.sub(pet.uuid, 1, 4) .. "]"
            end
            table.insert(options, label)
            targetLevelLabelToUUID[label] = pet.uuid
        end
    end
    table.sort(options, sortAlphabetically)
    if #options == 0 then options = {"❌ Tidak ada pet non-favorit"} end
    TargetLevelDropdown:Refresh(options)
    if #state.levelingTargets > 0 then
        local selectedLabels = {}
        for _, uuid in ipairs(state.levelingTargets) do
            for label, u in pairs(targetLevelLabelToUUID) do
                if u == uuid then
                    table.insert(selectedLabels, label)
                    break
                end
            end
        end
        if #selectedLabels > 0 then
            TargetLevelDropdown:SetSelectedOptions(selectedLabels)
        end
    end
end

TargetLevelFilterInput = LevelingTab:CreateInput({
    Name = "🔍 Cari Target Leveling",
    PlaceholderText = "Ketik untuk filter...",
    CurrentValue = "",
    Callback = function(Value)
        refreshTargetLevelDropdown(Value)
    end
})

TargetLevelDropdown = LevelingTab:CreateDropdown({
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
        if state.isLevelingActive and not isLevelingProcessing then
            state.isLevelingActive = false
            task.wait(0.1)
            startLeveling()
        end
    end
})

-- ============================================================
-- SLIDER TARGET LEVEL
-- ============================================================

local TargetLevelSlider = LevelingTab:CreateSlider({
    Name = "Target Level",
    Range = {0, 500},
    Increment = 1,
    Suffix = "Level",
    CurrentValue = state.targetLevel,
    Callback = function(value)
        state.targetLevel = value
        print("🎯 Target Level:", value)
        if state.isLevelingActive and not isLevelingProcessing then
            state.isLevelingActive = false
            task.wait(0.1)
            startLeveling()
        end
    end
})

-- ============================================================
-- START/STOP LEVELING
-- ============================================================

local LevelingToggle
LevelingToggle = LevelingTab:CreateToggle({
    Name = "▶️ Start / Stop Leveling",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            if state.isSharkActive then
                print("⚠️ Auto Shark sedang aktif! Matikan dulu.")
                if LevelingToggle then LevelingToggle:Set(false) end
                return
            end
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
            if LevelingToggle then LevelingToggle:Set(false) end
        end
    end
})

-- ============================================================
-- TAB SAVE / LOAD
-- ============================================================

local function saveLoadTab()
    local tab = Window:CreateTab("Save / Load")

    tab:CreateButton({
        Name = "💾 Simpan Konfigurasi",
        Callback = saveConfig
    })

    tab:CreateButton({
        Name = "📂 Muat Konfigurasi",
        Callback = function()
            loadConfig()
        end
    })

    tab:CreateButton({
        Name = "🔄 Reset Semua (Hati-hati!)",
        Callback = function()
            if state.isSharkActive then
                state.isSharkActive = false
                unequipTargetAndEquipShark()
                unequipAllGardenPets({})
                if state.selectedMimicUUID then
                    SharkLogic.unequipPet(PetsService, state.selectedMimicUUID)
                end
                if state.selectedSharkUUID then
                    SharkLogic.unequipPet(PetsService, state.selectedSharkUUID)
                end
            end
            if state.isLevelingActive then
                stopLeveling()
            end
            state.selectedMimicUUID = nil
            state.selectedSharkUUID = nil
            state.targetQueue = {}
            state.levelingTim = {}
            state.levelingTargets = {}
            state.tumbalNames = {"Dog"}
            state.minLevel = 100
            state.targetLevel = 100
            refreshAllUI()
            print("🔄 Semua reset")
        end
    })
end

-- ============================================================
-- INISIALISASI
-- ============================================================

refreshAllUI()
saveLoadTab()

print("✅ Pria Solo HUB siap. Tekan K untuk membuka UI.")

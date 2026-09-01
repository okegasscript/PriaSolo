-- ============================================================
-- Auto Shark - Main Entry (FINAL) - Target Multiple Select
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local DataPetModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSolo/refs/heads/main/DataPetModule.lua"))()
local SharkLogic = loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSolo/refs/heads/main/SharkLogic.lua"))()
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

if not DataPetModule or not SharkLogic or not Rayfield then
    warn("❌ Gagal memuat modul")
    return
end

print("✅ Semua modul berhasil dimuat")

-- ============================================================
-- STATE GLOBAL
-- ============================================================

local state = {
    isActive = false,
    isProcessing = false,
    selectedMimicUUID = nil,
    selectedSharkUUID = nil,
    targetQueue = {},          -- daftar UUID target (urutan)
    currentTargetUUID = nil,   -- target yang sedang diproses
    tumbalNames = {"Dog"},
    minLevel = 100,
    currentTumbalUUID = nil,
    cycleCount = 0,
    lastActionTime = 0
}

-- ============================================================
-- EVENT SERVICE
-- ============================================================

local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local PetCooldownsEvent = GameEvents:WaitForChild("PetCooldownsUpdated")
local PetsService = GameEvents:WaitForChild("PetsService")
local NotificationEvent = GameEvents:WaitForChild("Notification")

-- ============================================================
-- FUNGSI LOGIKA
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

-- Ambil target berikutnya dari queue (rotasi)
local function getNextTarget()
    if #state.targetQueue == 0 then
        print("⚠️ Tidak ada target dalam antrian!")
        return nil
    end
    -- Ambil target pertama
    local nextUUID = table.remove(state.targetQueue, 1)
    -- Jika masih ada sisa, masukkan ke belakang (rotasi)
    -- TAPI kita hanya masukkan kembali jika masih ada target lain? 
    -- lebih baik: simpan sisa untuk cycle berikutnya, tapi target yang sudah dipakai jangan dipakai lagi di cycle yang sama
    -- Namun untuk rotasi sederhana, kita taruh di belakang agar semua target kebagian giliran
    table.insert(state.targetQueue, nextUUID)
    return nextUUID
end

local function unequipSharkAndEquipTumbalTarget()
    if not state.selectedSharkUUID then return end

    -- Ambil target berikutnya dari queue
    local targetUUID = getNextTarget()
    if not targetUUID then
        print("⚠️ Tidak ada target tersedia!")
        SharkLogic.equipPet(PetsService, state.selectedSharkUUID, SharkLogic.defaultConfig.slotCFrame)
        state.isProcessing = false
        return
    end

    -- Cari tumbal (wajib Blossoming)
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
        print("✅ Equip tumbal & target (target:", targetUUID, ")")
        print("📋 Sisa target dalam antrian:", #state.targetQueue)
    else
        print("⚠️ Tumbal atau target tidak ditemukan")
        -- Jika tumbal tidak ditemukan, kita tetap panggil getNextTarget? 
        -- Tapi target sudah diambil dari queue, kita kembalikan ke depan agar dicoba lagi nanti
        table.insert(state.targetQueue, 1, targetUUID) -- kembalikan ke depan
        SharkLogic.equipPet(PetsService, state.selectedSharkUUID, SharkLogic.defaultConfig.slotCFrame)
        state.isProcessing = false
    end
end

-- ============================================================
-- EVENT LISTENER
-- ============================================================

local isHandlingCooldownEvent = false

PetCooldownsEvent.OnClientEvent:Connect(function(petId, dataArray)
    if not state.isActive then return end
    if petId ~= state.selectedMimicUUID then return end
    if isHandlingCooldownEvent then return end

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
end)

NotificationEvent.OnClientEvent:Connect(function(message)
    if not state.isActive or not state.isProcessing then return end
    if type(message) == "string" and string.find(message, "Mimic Octopus") then
        if string.find(message, "spat its Blossoming mutation onto") or string.find(message, "mutation failed to transfer") then
            unequipTargetAndEquipShark()
        end
    end
end)

-- ============================================================
-- WEIGHT ESTIMATION & FORMAT
-- ============================================================

local WEIGHT_GROWTH_RATE = 0.5599

local function estimateWeight(baseWeight, level)
    baseWeight = baseWeight or 0
    level = level or 1
    return baseWeight + (level - 1) * WEIGHT_GROWTH_RATE
end

local function formatPetLabel(pet)
    local rawBaseWeight = (pet.petData and pet.petData.BaseWeight) or 0
    local estimatedWeight = estimateWeight(rawBaseWeight, pet.level)
    return string.format("%s %s %.2f KG Lv.%d", pet.mutation, pet.name, estimatedWeight, pet.level)
end

-- ============================================================
-- UI
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

local MainTab = Window:CreateTab("Auto Shark")

-- Status label
local StatusLabel = MainTab:CreateLabel("Mimic: (belum) | Shark: (belum) | Target Queue: 0")

local function updateStatusLabel()
    local mimicText = state.selectedMimicUUID and tostring(state.selectedMimicUUID) or "(belum)"
    local sharkText = state.selectedSharkUUID and tostring(state.selectedSharkUUID) or "(belum)"
    local queueCount = #state.targetQueue
    StatusLabel:Set("Mimic: " .. mimicText .. " | Shark: " .. sharkText .. " | Target Queue: " .. queueCount)
end

-- ============================================================
-- DROPDOWN MIMIC
-- ============================================================

local mimicLabelToUUID = {}
local MimicDropdown = MainTab:CreateDropdown({
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
        else
            warn("⚠️ UUID tidak ditemukan")
        end
    end
})

local function refreshMimicDropdown()
    local hasil = DataPetModule.findPets({ name = "Mimic", isFavorite = true })
    local options = {}
    mimicLabelToUUID = {}
    for _, pet in ipairs(hasil) do
        local label = formatPetLabel(pet)
        if mimicLabelToUUID[label] then
            label = label .. " [" .. string.sub(pet.uuid, 1, 4) .. "]"
        end
        table.insert(options, label)
        mimicLabelToUUID[label] = pet.uuid
    end
    if #options == 0 then options = {"❌ Tidak ada Mimic favorit"} end
    MimicDropdown:Refresh(options)
end

-- ============================================================
-- DROPDOWN SHARK
-- ============================================================

local sharkLabelToUUID = {}
local SharkDropdown = MainTab:CreateDropdown({
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
        else
            warn("⚠️ UUID tidak ditemukan")
        end
    end
})

local function refreshSharkDropdown()
    local hasil = DataPetModule.findPets({ name = "Shark", isFavorite = true })
    local options = {}
    sharkLabelToUUID = {}
    for _, pet in ipairs(hasil) do
        local label = formatPetLabel(pet)
        if sharkLabelToUUID[label] then
            label = label .. " [" .. string.sub(pet.uuid, 1, 4) .. "]"
        end
        table.insert(options, label)
        sharkLabelToUUID[label] = pet.uuid
    end
    if #options == 0 then options = {"❌ Tidak ada Shark favorit"} end
    SharkDropdown:Refresh(options)
end

-- ============================================================
-- DROPDOWN TARGET (MULTIPLE SELECT)
-- ============================================================

local targetLabelToUUID = {}
local TargetDropdown = MainTab:CreateDropdown({
    Name = "Pilih Target (Multiple, Non-Fav, Normal)",
    Options = {"Memuat data..."},
    CurrentOption = "Memuat data...",
    MultipleOptions = true,   -- <--- MULTIPLE SELECT
    Callback = function(option)
        -- option adalah table berisi label-label yang dipilih
        if type(option) == "table" then
            local uuids = {}
            for _, label in ipairs(option) do
                local uuid = targetLabelToUUID[label]
                if uuid then
                    table.insert(uuids, uuid)
                end
            end
            if #uuids > 0 then
                state.targetQueue = uuids
                print("✅ Target queue diperbarui:", #state.targetQueue, "target")
                updateStatusLabel()
            else
                warn("⚠️ Tidak ada UUID yang valid")
                state.targetQueue = {}
            end
        else
            -- Jika tidak multiple, mungkin single, kita tangani
            local uuid = targetLabelToUUID[option]
            if uuid then
                state.targetQueue = {uuid}
                print("✅ Target dipilih:", option, "UUID:", uuid)
                updateStatusLabel()
            end
        end
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
        if targetLabelToUUID[label] then
            label = label .. " [" .. string.sub(pet.uuid, 1, 4) .. "]"
        end
        table.insert(options, label)
        targetLabelToUUID[label] = pet.uuid
    end
    if #options == 0 then options = {"❌ Tidak ada target"} end
    TargetDropdown:Refresh(options)
end

-- ============================================================
-- TUMBAL (Input Text)
-- ============================================================

MainTab:CreateInput({
    Name = "Nama Tumbal (pisah koma)",
    PlaceholderText = "Contoh: Dog, Cat, Bunny",
    CurrentValue = table.concat(state.tumbalNames, ", "),
    Callback = function(Value)
        if Value and Value ~= "" then
            local names = {}
            for token in string.gmatch(Value, "[^, ]+") do
                if token ~= "" then table.insert(names, token) end
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

MainTab:CreateSlider({
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

MainTab:CreateButton({
    Name = "🔄 Refresh Daftar Pet",
    Callback = function()
        refreshMimicDropdown()
        refreshSharkDropdown()
        refreshTargetDropdown()
    end
})

-- ============================================================
-- START / STOP TOGGLE
-- ============================================================

local StartToggle
StartToggle = MainTab:CreateToggle({
    Name = "▶️ Start / Stop",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            if not state.selectedMimicUUID then
                print("⚠️ Pilih Mimic dulu!")
                if StartToggle then StartToggle:Set(false) end
                return
            end
            if not state.selectedSharkUUID then
                print("⚠️ Pilih Shark dulu!")
                if StartToggle then StartToggle:Set(false) end
                return
            end
            if #state.targetQueue == 0 then
                print("⚠️ Pilih target dulu!")
                if StartToggle then StartToggle:Set(false) end
                return
            end
            state.isActive = true
            print("▶️ Script dimulai. Target queue:", #state.targetQueue)
            -- Equip awal Mimic & Shark
            SharkLogic.equipPet(PetsService, state.selectedMimicUUID, SharkLogic.defaultConfig.slotCFrame)
            SharkLogic.equipPet(PetsService, state.selectedSharkUUID, SharkLogic.defaultConfig.slotCFrame)
        else
            state.isActive = false
            print("⏹️ Script dihentikan")
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
-- LOAD AWAL
-- ============================================================

refreshMimicDropdown()
refreshSharkDropdown()
refreshTargetDropdown()
updateStatusLabel()

print("✅ Auto Shark siap (multiple target). Tekan K untuk membuka UI.")

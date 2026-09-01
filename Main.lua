-- ============================================================
-- Auto Shark - Main Entry
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

-- State global
local state = {
    isActive = false,
    isProcessing = false,
    selectedMimicUUID = nil,
    selectedSharkUUID = nil,
    targetName = "Moon Cat",
    tumbalNames = {"Dog"},
    currentTumbalUUID = nil,
    currentTargetUUID = nil,
    cycleCount = 0,
    lastActionTime = 0
}

-- Event service
local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local PetCooldownsEvent = GameEvents:WaitForChild("PetCooldownsUpdated")
local PetsService = GameEvents:WaitForChild("PetsService")
local NotificationEvent = GameEvents:WaitForChild("Notification")

-- Fungsi logika (equip/unequip)
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

local function unequipSharkAndEquipTumbalTarget()
    if not state.selectedSharkUUID then return end

    local tumbalUUID = SharkLogic.findTumbal(DataPetModule, state.tumbalNames, {state.selectedMimicUUID, state.selectedSharkUUID})
    local targetUUID = SharkLogic.findTarget(DataPetModule, state.targetName, {state.selectedMimicUUID, state.selectedSharkUUID})

    if tumbalUUID and targetUUID then
        SharkLogic.unequipPet(PetsService, state.selectedSharkUUID)
        SharkLogic.equipPet(PetsService, tumbalUUID, SharkLogic.defaultConfig.slotCFrame)
        state.currentTumbalUUID = tumbalUUID
        SharkLogic.equipPet(PetsService, targetUUID, SharkLogic.defaultConfig.slotCFrame)
        state.currentTargetUUID = targetUUID
        state.isProcessing = true
        print("✅ Equip tumbal & target")
    else
        print("⚠️ Tumbal atau target tidak ditemukan")
        SharkLogic.equipPet(PetsService, state.selectedSharkUUID, SharkLogic.defaultConfig.slotCFrame)
        state.isProcessing = false
    end
end

-- Event listener
PetCooldownsEvent.OnClientEvent:Connect(function(petId, dataArray)
    if not state.isActive then return end
    if petId ~= state.selectedMimicUUID then return end

    local time = nil
    for _, entry in ipairs(dataArray) do
        if entry.Time then time = entry.Time break end
    end
    if time == nil then return end

    if state.isProcessing and time > 0.1 then
        unequipTargetAndEquipShark()
    end

    if not state.isProcessing and time <= 0.1 then
        local now = os.clock()
        if now - state.lastActionTime < 0.5 then return end
        state.lastActionTime = now
        task.wait(0.6)
        unequipSharkAndEquipTumbalTarget()
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

-- Helper: format label pet
local function formatPetLabel(pet)
    return string.format("%s %s %.2f KG Lv.%d", pet.mutation, pet.name, pet.weight or 0, pet.level)
end

-- Helper: cari pet favorit berdasarkan keyword nama (partial match, case-insensitive)
local function getFavoritesByKeyword(keyword)
    return DataPetModule.findPets({ name = keyword, isFavorite = true })
end

-- Mapping label -> uuid (dipakai ulang saat dropdown callback jalan)
local mimicLabelToUUID = {}
local sharkLabelToUUID = {}

-- 1. Dropdown Mimic (petType mengandung "Mimic", isFavorite = true)
local MimicDropdown = MainTab:CreateDropdown({
    Name = "Pilih Mimic",
    Options = {"Memuat data..."},
    CurrentOption = {"Memuat data..."},
    MultipleOptions = false,
    Callback = function(option)
        local uuid = mimicLabelToUUID[option]
        if uuid then
            state.selectedMimicUUID = uuid
            print("✅ Mimic dipilih:", option)
        end
    end
})

-- 2. Dropdown Shark (petType mengandung "Shark", isFavorite = true)
local SharkDropdown = MainTab:CreateDropdown({
    Name = "Pilih Shark",
    Options = {"Memuat data..."},
    CurrentOption = {"Memuat data..."},
    MultipleOptions = false,
    Callback = function(option)
        local uuid = sharkLabelToUUID[option]
        if uuid then
            state.selectedSharkUUID = uuid
            print("✅ Shark dipilih:", option)
        end
    end
})

-- Fungsi refresh dropdown Mimic
local function refreshMimicDropdown()
    local hasil = getFavoritesByKeyword("Mimic")
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
    if #options == 0 then
        options = {"❌ Tidak ada Mimic favorit"}
    end
    MimicDropdown:Refresh(options)
end

-- Fungsi refresh dropdown Shark
local function refreshSharkDropdown()
    local hasil = getFavoritesByKeyword("Shark")
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
    if #options == 0 then
        options = {"❌ Tidak ada Shark favorit"}
    end
    SharkDropdown:Refresh(options)
end

-- Tombol refresh manual (jaga-jaga kalau data telat load)
MainTab:CreateButton({
    Name = "🔄 Refresh Daftar Pet",
    Callback = function()
        refreshMimicDropdown()
        refreshSharkDropdown()
    end
})

-- Input Target & Tumbal
MainTab:CreateInput({
    Name = "Nama Target",
    PlaceholderText = "Contoh: Moon Cat",
    CurrentValue = state.targetName,
    Callback = function(Value)
        if Value and Value ~= "" then
            state.targetName = Value
            print("✅ Target diubah:", Value)
        end
    end
})

MainTab:CreateInput({
    Name = "Nama Tumbal (pisah koma)",
    PlaceholderText = "Contoh: Dog, Cat, Golden Lab",
    CurrentValue = table.concat(state.tumbalNames, ", "),
    Callback = function(Value)
        if Value and Value ~= "" then
            local names = {}
            for token in string.gmatch(Value, "[^, ]+") do
                if token ~= "" then
                    table.insert(names, token)
                end
            end
            if #names > 0 then
                state.tumbalNames = names
                print("✅ Tumbal diubah:", table.concat(names, ", "))
            end
        end
    end
})

-- 3. Toggle Start/Stop (ditaruh paling bawah, elemen terakhir di tab)
local StartToggle = MainTab:CreateToggle({
    Name = "▶️ Start / Stop",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            if not state.selectedMimicUUID then
                print("⚠️ Pilih Mimic dulu!")
                StartToggle:Set(false)
                return
            end
            if not state.selectedSharkUUID then
                print("⚠️ Pilih Shark dulu!")
                StartToggle:Set(false)
                return
            end
            state.isActive = true
            print("▶️ Script dimulai")
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
-- Rate hasil kalibrasi dari data Lion (BaseWeight 5.549 -> 284.92 KG di Level 500)
local WEIGHT_GROWTH_RATE = 0.5599

local function estimateWeight(baseWeight, level)
    baseWeight = baseWeight or 0
    level = level or 1
    return baseWeight + (level - 1) * WEIGHT_GROWTH_RATE
end

-- Helper: format label pet (SUDAH DIUBAH pakai estimateWeight)
local function formatPetLabel(pet)
    local rawBaseWeight = pet.petData and pet.petData.BaseWeight or pet.weight or 0
    local estimatedWeight = estimateWeight(rawBaseWeight, pet.level)
    return string.format("%s %s %.2f KG Lv.%d", pet.mutation, pet.name, estimatedWeight, pet.level)
end

-- Load awal
refreshMimicDropdown()
refreshSharkDropdown()

print("✅ Auto Shark siap. Tekan K untuk membuka UI.")

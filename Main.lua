-- ============================================================
-- Auto Shark - Main Entry (FINAL)
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

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
-- STATE
-- ============================================================

local state = {
    isActive = false,
    isProcessing = false,
    selectedMimicUUID = nil,
    selectedSharkUUID = nil,
    selectedTargetUUID = nil,     -- UUID target yang dipilih dari dropdown
    targetName = "Mimic Octopus", -- untuk keperluan log
    tumbalNames = {"Dog"},
    minLevel = 100,
    currentTumbalUUID = nil,
    currentTargetUUID = nil,
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

local function unequipSharkAndEquipTumbalTarget()
    if not state.selectedSharkUUID then
        print("⚠️ Shark belum dipilih")
        return
    end
    if not state.selectedTargetUUID then
        print("⚠️ Target belum dipilih")
        return
    end

    -- Cari tumbal (Blossoming, non-fav, minLevel)
    local tumbalUUID = SharkLogic.findTumbal(
        DataPetModule,
        state.tumbalNames,
        {state.selectedMimicUUID, state.selectedSharkUUID},
        state.minLevel or 0
    )

    if tumbalUUID and state.selectedTargetUUID then
        SharkLogic.unequipPet(PetsService, state.selectedSharkUUID)
        SharkLogic.equipPet(PetsService, tumbalUUID, SharkLogic.defaultConfig.slotCFrame)
        state.currentTumbalUUID = tumbalUUID
        SharkLogic.equipPet(PetsService, state.selectedTargetUUID, SharkLogic.defaultConfig.slotCFrame)
        state.currentTargetUUID = state.selectedTargetUUID
        state.isProcessing = true
        print("✅ Equip tumbal & target")
    else
        print("⚠️ Tumbal atau target tidak ditemukan")
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
        local ok, err = pcall(unequipTargetAndEquipShark)
        if not ok then warn("❌ Error unequipTargetAndEquipShark:", err) end
        isHandlingCooldownEvent = false
    end

    if not state.isProcessing and time <= 0.1 then
        local now = os.clock()
        if now - state.lastActionTime < 0.5 then return end
        state.lastActionTime = now

        isHandlingCooldownEvent = true
        task.spawn(function()
            task.wait(0.6)
            local ok, err = pcall(unequipSharkAndEquipTumbalTarget)
            if not ok then warn("❌ Error unequipSharkAndEquipTumbalTarget:", err) end
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

-- Helper: format label pet (pakai estimasi weight)
local function formatPetLabel(pet)
    return string.format("%s %s %.2f KG Lv.%d", pet.mutation, pet.name, pet.weight or 0, pet.level)
end

-- Helper: cari pet favorit berdasarkan keyword
local function getFavoritesByKeyword(keyword)
    return DataPetModule.findPets({ name = keyword, isFavorite = true })
end

-- Label status
local StatusLabel = MainTab:CreateLabel("Mimic: (belum dipilih) | Shark: (belum dipilih) | Target: (belum dipilih)")

local function updateStatusLabel()
    local mimicText = state.selectedMimicUUID and tostring(state.selectedMimicUUID) or "(belum dipilih)"
    local sharkText = state.selectedSharkUUID and tostring(state.selectedSharkUUID) or "(belum dipilih)"
    local targetText = state.selectedTargetUUID and tostring(state.selectedTargetUUID) or "(belum dipilih)"
    StatusLabel:Set("Mimic: " .. mimicText .. " | Shark: " .. sharkText .. " | Target: " .. targetText)
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
        local selectedLabel = option
        if type(option) == "table" then
            selectedLabel = option[1]
        end
        local uuid = mimicLabelToUUID[selectedLabel]
        if uuid then
            state.selectedMimicUUID = uuid
            print("✅ Mimic dipilih:", selectedLabel, "UUID:", uuid)
            updateStatusLabel()
        else
            warn("⚠️ UUID tidak ditemukan untuk label:", tostring(selectedLabel))
        end
    end
})

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
        local selectedLabel = option
        if type(option) == "table" then
            selectedLabel = option[1]
        end
        local uuid = sharkLabelToUUID[selectedLabel]
        if uuid then
            state.selectedSharkUUID = uuid
            print("✅ Shark dipilih:", selectedLabel, "UUID:", uuid)
            updateStatusLabel()
        else
            warn("⚠️ UUID tidak ditemukan untuk label:", tostring(selectedLabel))
        end
    end
})

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

-- ============================================================
-- DROPDOWN TARGET (Non-Fav, Mutasi Normal)
-- ============================================================

local targetLabelToUUID = {}

local TargetDropdown = MainTab:CreateDropdown({
    Name = "Pilih Target (Non-Fav, Mutasi Normal)",
    Options = {"Memuat data..."},
    CurrentOption = "Memuat data...",
    MultipleOptions = true,
    Callback = function(option)
        local selectedLabel = option
        if type(option) == "table" then
            selectedLabel = option[1]
        end
        local uuid = targetLabelToUUID[selectedLabel]
        if uuid then
            state.selectedTargetUUID = uuid
            state.targetName = selectedLabel
            print("✅ Target dipilih:", selectedLabel, "UUID:", uuid)
            updateStatusLabel()
        else
            warn("⚠️ UUID tidak ditemukan untuk label:", tostring(selectedLabel))
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

    if #options == 0 then
        options = {"❌ Tidak ada target yang memenuhi syarat"}
    end

    TargetDropdown:Refresh(options)
end

-- ============================================================
-- TOMBOL REFRESH
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
-- SLIDER MIN LEVEL TUMBAL
-- ============================================================

MainTab:CreateSlider({
    Name = "Min Level Tumbal",
    Range = {0, 500},
    Increment = 1,
    Suffix = " Level",
    CurrentValue = state.minLevel,
    Callback = function(value)
        state.minLevel = value
        print("[UI] Min Level Tumbal:", value)
    end
})

-- ============================================================
-- INPUT TUMBAL
-- ============================================================

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

-- ============================================================
-- TOGGLE START/STOP
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
            if not state.selectedTargetUUID then
                print("⚠️ Pilih Target dulu!")
                if StartToggle then StartToggle:Set(false) end
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

-- ============================================================
-- INISIALISASI
-- ============================================================

refreshMimicDropdown()
refreshSharkDropdown()
refreshTargetDropdown()

print("✅ Auto Shark siap. Tekan K untuk membuka UI.")

-- ============================================================
-- Auto Shark - Main Entry (FINAL - Multiple Target)
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- ===== LOAD MODULES =====
local DataPetModule, SharkLogic, Rayfield

pcall(function()
    DataPetModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSolo/refs/heads/main/DataPetModule.lua"))()
end)
pcall(function()
    SharkLogic = loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSolo/refs/heads/main/SharkLogic.lua"))()
end)
pcall(function()
    Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)

if not DataPetModule or not SharkLogic or not Rayfield then
    warn("❌ Gagal memuat modul")
    return
end

print("✅ Semua modul berhasil dimuat")

-- ===== STATE =====
local state = {
    isActive = false,
    isProcessing = false,
    selectedMimicUUID = nil,
    selectedSharkUUID = nil,
    targetQueue = {},          -- daftar target UUID yang dipilih (multiple)
    currentTargetUUID = nil,   -- target yang sedang diproses
    tumbalNames = {"Dog"},
    minLevel = 100,
    currentTumbalUUID = nil,
    cycleCount = 0,
    lastActionTime = 0
}

-- ===== EVENT SERVICE =====
local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local PetCooldownsEvent = GameEvents:WaitForChild("PetCooldownsUpdated")
local PetsService = GameEvents:WaitForChild("PetsService")
local NotificationEvent = GameEvents:WaitForChild("Notification")

-- ===== FUNGSI LOGIKA =====
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
    -- Ambil target berikutnya dari antrian
    if #state.targetQueue > 0 then
        state.currentTargetUUID = table.remove(state.targetQueue, 1)
        print("🔄 Target berikutnya dari antrian:", state.currentTargetUUID)
    end
end

local function unequipSharkAndEquipTumbalTarget()
    if not state.selectedSharkUUID then return end
    if not state.currentTargetUUID then
        print("⚠️ Tidak ada target dalam antrian")
        return
    end

    local tumbalUUID = SharkLogic.findTumbal(
        DataPetModule,
        state.tumbalNames,
        {state.selectedMimicUUID, state.selectedSharkUUID},
        state.minLevel or 0
    )

    if tumbalUUID and state.currentTargetUUID then
        SharkLogic.unequipPet(PetsService, state.selectedSharkUUID)
        SharkLogic.equipPet(PetsService, tumbalUUID, SharkLogic.defaultConfig.slotCFrame)
        state.currentTumbalUUID = tumbalUUID
        SharkLogic.equipPet(PetsService, state.currentTargetUUID, SharkLogic.defaultConfig.slotCFrame)
        state.isProcessing = true
        print("✅ Equip tumbal & target (target: " .. state.currentTargetUUID .. ")")
    else
        print("⚠️ Tumbal atau target tidak ditemukan")
        SharkLogic.equipPet(PetsService, state.selectedSharkUUID, SharkLogic.defaultConfig.slotCFrame)
        state.isProcessing = false
    end
end

-- ===== EVENT LISTENER =====
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

        -- Jika tidak ada target tersisa, stop
        if #state.targetQueue == 0 and not state.currentTargetUUID then
            print("✅ Semua target selesai, script berhenti")
            state.isActive = false
            return
        end

        -- Ambil target berikutnya jika belum ada
        if not state.currentTargetUUID and #state.targetQueue > 0 then
            state.currentTargetUUID = table.remove(state.targetQueue, 1)
            print("🔄 Ambil target dari antrian:", state.currentTargetUUID)
        end

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

-- ===== WEIGHT ESTIMATION =====
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

-- ===== UI =====
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

-- Status Label
local StatusLabel = MainTab:CreateLabel("Status: Siap")
local function updateStatusLabel()
    local mimic = state.selectedMimicUUID or "Belum"
    local shark = state.selectedSharkUUID or "Belum"
    local targetCount = #state.targetQueue + (state.currentTargetUUID and 1 or 0)
    StatusLabel:Set("Mimic: " .. mimic .. " | Shark: " .. shark .. " | Target Tersisa: " .. targetCount)
end

-- ===== DROPDOWN MIMIC =====
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

-- ===== DROPDOWN SHARK =====
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

-- ===== DROPDOWN TARGET (Multiple Select) =====
local targetLabelToUUID = {}
local TargetDropdown = MainTab:CreateDropdown({
    Name = "Pilih Target (Multi) - Non-Fav Normal",
    Options = {"Memuat data..."},
    CurrentOption = {"Memuat data..."},
    MultipleOptions = true,   -- BISA PILIH BANYAK
    Callback = function(selectedLabels)
        -- selectedLabels adalah table of selected labels
        print("[UI] Target dipilih:", table.concat(selectedLabels or {}, ", "))
        if selectedLabels and #selectedLabels > 0 then
            local uuids = {}
            for _, label in ipairs(selectedLabels) do
                local uuid = targetLabelToUUID[label]
                if uuid then table.insert(uuids, uuid) end
            end
            state.targetQueue = uuids
            print("✅ Target queue diupdate:", #state.targetQueue, "target")
            updateStatusLabel()
        else
            state.targetQueue = {}
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

-- ===== TUMBAL INPUT =====
MainTab:CreateInput({
    Name = "Nama Tumbal (pisah koma)",
    PlaceholderText = "Dog, Cat, Bunny",
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

-- ===== SLIDER MIN LEVEL =====
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

-- ===== REFRESH BUTTON =====
MainTab:CreateButton({
    Name = "🔄 Refresh Daftar Pet",
    Callback = function()
        refreshMimicDropdown()
        refreshSharkDropdown()
        refreshTargetDropdown()
    end
})

-- ===== START/STOP TOGGLE =====
local StartToggle
StartToggle = MainTab:CreateToggle({
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
            if #state.targetQueue == 0 then
                print("⚠️ Pilih minimal 1 target!")
                StartToggle:Set(false)
                return
            end
            state.isActive = true
            -- Ambil target pertama
            state.currentTargetUUID = table.remove(state.targetQueue, 1)
            print("▶️ Script dimulai, target pertama:", state.currentTargetUUID)
            SharkLogic.equipPet(PetsService, state.selectedMimicUUID, SharkLogic.defaultConfig.slotCFrame)
            SharkLogic.equipPet(PetsService, state.selectedSharkUUID, SharkLogic.defaultConfig.slotCFrame)
            updateStatusLabel()
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
            state.currentTargetUUID = nil
            updateStatusLabel()
        end
    end
})

-- ===== LOAD AWAL =====
refreshMimicDropdown()
refreshSharkDropdown()
refreshTargetDropdown()
updateStatusLabel()

print("✅ Auto Shark siap. Tekan K untuk membuka UI.")

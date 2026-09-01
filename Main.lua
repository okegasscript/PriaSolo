-- ============================================================
-- Auto Shark - Main Entry (FINAL - Target Semua Pet, Tumbal Spasi)
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
-- STATE GLOBAL
-- ============================================================

local state = {
    isActive = false,
    isProcessing = false,
    selectedMimicUUID = nil,
    selectedSharkUUID = nil,
    targetQueue = {},          -- daftar UUID target (multiple)
    currentTargetIndex = 1,
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

local function getNextTarget()
    if #state.targetQueue == 0 then
        print("⚠️ Tidak ada target dalam antrian")
        return nil
    end
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
-- WEIGHT ESTIMATION
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

local MainTab = Window:CreateTab("Auto Shark")

-- Status label
local StatusLabel = MainTab:CreateLabel("Mimic: (belum) | Shark: (belum) | Target: 0 terpilih")

local function updateStatusLabel()
    local mimicText = state.selectedMimicUUID and tostring(state.selectedMimicUUID) or "(belum)"
    local sharkText = state.selectedSharkUUID and tostring(state.selectedSharkUUID) or "(belum)"
    local targetCount = #state.targetQueue
    StatusLabel:Set("Mimic: " .. mimicText .. " | Shark: " .. sharkText .. " | Target: " .. targetCount .. " terpilih")
end

-- ============================================================
-- DROPDOWN MIMIC (Single Select)
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
-- DROPDOWN SHARK (Single Select)
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
-- DROPDOWN TARGET (Multiple Select) - ALL PETS, Non-Fav, Normal
-- ============================================================

local targetLabelToUUID = {}
local TargetDropdown = MainTab:CreateDropdown({
    Name = "Pilih Target (Multiple, Non-Fav, Normal)",
    Options = {"Memuat data..."},
    CurrentOption = "Memuat data...",
    MultipleOptions = true,
    Callback = function(selectedLabels)
        state.targetQueue = {}
        for _, label in ipairs(selectedLabels) do
            local uuid = targetLabelToUUID[label]
            if uuid then
                table.insert(state.targetQueue, uuid)
            end
        end
        state.currentTargetIndex = 1
        print("✅ Target dipilih:", #state.targetQueue, "pet")
        updateStatusLabel()
    end
})

local function refreshTargetDropdown()
    -- Ambil SEMUA pet dengan isFavorite = false dan mutation = Normal
    local hasil = DataPetModule.findPets({
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
-- TUMBAL (Input Text, Multiple Nama, Support Spasi)
-- ============================================================

MainTab:CreateInput({
    Name = "Nama Tumbal (pisah koma)",
    PlaceholderText = "Contoh: Dog, Golden Lab, Black Bunny",
    CurrentValue = table.concat(state.tumbalNames, ", "),
    Callback = function(Value)
        if Value and Value ~= "" then
            local names = {}
            -- Split berdasarkan koma, lalu trim spasi
            for token in string.gmatch(Value, "[^,]+") do
                local trimmed = token:match("^%s*(.-)%s*$")
                if trimmed ~= "" then
                    table.insert(names, trimmed)
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
-- SLIDER MIN LEVEL TUMBAL
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
                print("⚠️ Pilih target dulu (multiple)!")
                if StartToggle then StartToggle:Set(false) end
                return
            end
            state.isActive = true
            print("▶️ Script dimulai dengan", #state.targetQueue, "target")
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
updateStatusLabel()



-- ============================================================
-- Auto Leveling - Tab UI & Logic
-- ============================================================

-- Asumsi DataPetModule, SharkLogic, Rayfield, PetsService sudah tersedia
-- (dari Main.lua)

-- Buat tab baru
local LevelingTab = Window:CreateTab("Auto Leveling")

-- ============================================================
-- STATE LEVELING
-- ============================================================

local levelState = {
    isActive = false,
    isProcessing = false,
    teamQueue = {},          -- daftar UUID tim (max 7)
    targetQueue = {},        -- daftar UUID target (multiple)
    currentTargetIndex = 1,
    targetLevel = 100,
    currentTargetUUID = nil,
    currentTeamUUIDs = {},   -- UUID tim yang sedang di-equip
    cycleCount = 0,
    lastActionTime = 0
}

-- ============================================================
-- FUNGSI UTILITY
-- ============================================================

local function formatPetLabel(pet)
    return string.format("%s %s %.2f KG Lv.%d", pet.mutation, pet.name, pet.weight or 0, pet.level)
end

-- ============================================================
-- DROPDOWN TIM LEVELING (Multiple, Max 7, IsFavorite=true)
-- ============================================================

local teamLabelToUUID = {}
local TeamDropdown = LevelingTab:CreateDropdown({
    Name = "Tim Leveling (Max 7, Favorit)",
    Options = {"Memuat data..."},
    CurrentOption = "Memuat data...",
    MultipleOptions = true,
    Max = 7,  -- batas maksimal 7
    Callback = function(selectedLabels)
        levelState.teamQueue = {}
        for _, label in ipairs(selectedLabels) do
            local uuid = teamLabelToUUID[label]
            if uuid then
                table.insert(levelState.teamQueue, uuid)
            end
        end
        print("✅ Tim Leveling dipilih:", #levelState.teamQueue, "pet")
    end
})

local function refreshTeamDropdown()
    local hasil = DataPetModule.findPets({
        isFavorite = true
    })
    local options = {}
    teamLabelToUUID = {}
    for _, pet in ipairs(hasil) do
        local label = formatPetLabel(pet)
        if teamLabelToUUID[label] then
            label = label .. " [" .. string.sub(pet.uuid, 1, 4) .. "]"
        end
        table.insert(options, label)
        teamLabelToUUID[label] = pet.uuid
    end
    if #options == 0 then options = {"❌ Tidak ada pet favorit"} end
    TeamDropdown:Refresh(options)
end

-- ============================================================
-- DROPDOWN TARGET LEVELING (Multiple, IsFavorite=false)
-- ============================================================

local targetLevelLabelToUUID = {}
local TargetLevelDropdown = LevelingTab:CreateDropdown({
    Name = "Target Leveling (Non-Favorit)",
    Options = {"Memuat data..."},
    CurrentOption = "Memuat data...",
    MultipleOptions = true,
    Callback = function(selectedLabels)
        levelState.targetQueue = {}
        for _, label in ipairs(selectedLabels) do
            local uuid = targetLevelLabelToUUID[label]
            if uuid then
                table.insert(levelState.targetQueue, uuid)
            end
        end
        levelState.currentTargetIndex = 1
        print("✅ Target Leveling dipilih:", #levelState.targetQueue, "pet")
    end
})

local function refreshTargetLevelDropdown()
    local hasil = DataPetModule.findPets({
        isFavorite = false
    })
    local options = {}
    targetLevelLabelToUUID = {}
    for _, pet in ipairs(hasil) do
        local label = formatPetLabel(pet)
        if targetLevelLabelToUUID[label] then
            label = label .. " [" .. string.sub(pet.uuid, 1, 4) .. "]"
        end
        table.insert(options, label)
        targetLevelLabelToUUID[label] = pet.uuid
    end
    if #options == 0 then options = {"❌ Tidak ada pet non-favorit"} end
    TargetLevelDropdown:Refresh(options)
end

-- ============================================================
-- SLIDER TARGET LEVEL
-- ============================================================

LevelingTab:CreateSlider({
    Name = "Target Level",
    Range = {0, 500},
    Increment = 1,
    Suffix = "Level",
    CurrentValue = levelState.targetLevel,
    Callback = function(value)
        levelState.targetLevel = value
        print("🎯 Target Level:", value)
    end
})

-- ============================================================
-- BUTTON REFRESH
-- ============================================================

LevelingTab:CreateButton({
    Name = "🔄 Refresh Daftar Pet",
    Callback = function()
        refreshTeamDropdown()
        refreshTargetLevelDropdown()
    end
})

-- ============================================================
-- FUNGSI LOGIKA LEVELING
-- ============================================================

-- Unequip semua pet yang ada di garden (EquippedPets)
local function unequipAllGarden()
    local equipped = DataPetModule.getEquippedPets()
    for _, uuid in ipairs(equipped) do
        SharkLogic.unequipPet(PetsService, uuid)
    end
    task.wait(0.5) -- tunggu proses
end

-- Equip tim leveling (max 7)
local function equipTeam()
    local count = 0
    for _, uuid in ipairs(levelState.teamQueue) do
        if count >= 7 then break end
        SharkLogic.equipPet(PetsService, uuid, SharkLogic.defaultConfig.slotCFrame)
        levelState.currentTeamUUIDs[count+1] = uuid
        count = count + 1
    end
    print("✅ Tim Leveling di-equip:", count, "pet")
end

-- Ambil target berikutnya (loop)
local function getNextLevelTarget()
    if #levelState.targetQueue == 0 then
        print("⚠️ Tidak ada target leveling")
        return nil
    end
    local target = levelState.targetQueue[levelState.currentTargetIndex]
    levelState.currentTargetIndex = levelState.currentTargetIndex + 1
    if levelState.currentTargetIndex > #levelState.targetQueue then
        levelState.currentTargetIndex = 1
    end
    return target
end

-- Proses leveling satu target
local function processLevelTarget(targetUUID)
    if not targetUUID then
        print("⚠️ Target UUID nil")
        return false
    end

    -- Ambil data target
    local targetData = DataPetModule.getPetData(targetUUID)
    if not targetData then
        print("⚠️ Target tidak ditemukan di inventory")
        return false
    end

    local currentLevel = targetData.PetData and (targetData.PetData.Level or targetData.PetData.Lvl or 0) or 0
    if currentLevel >= levelState.targetLevel then
        print("✅ Target sudah mencapai target level, lewati")
        return true  -- dianggap selesai
    end

    -- Equip target ke garden (untuk dinaikkan levelnya)
    SharkLogic.equipPet(PetsService, targetUUID, SharkLogic.defaultConfig.slotCFrame)
    levelState.currentTargetUUID = targetUUID
    print("🔄 Equip target untuk leveling:", targetUUID, "Level saat ini:", currentLevel)

    -- Tunggu sampai target mencapai level target (atau kondisi berhenti)
    -- Karena leveling terjadi otomatis oleh game, kita polling level
    local startTime = os.clock()
    while levelState.isActive and levelState.currentTargetUUID == targetUUID do
        local data = DataPetModule.getPetData(targetUUID)
        if data then
            local lvl = data.PetData and (data.PetData.Level or data.PetData.Lvl or 0) or 0
            if lvl >= levelState.targetLevel then
                print("✅ Target mencapai level target! Level:", lvl)
                SharkLogic.unequipPet(PetsService, targetUUID)
                levelState.currentTargetUUID = nil
                return true
            end
        end
        -- Cek timeout 10 detik (jika tidak naik, lewati)
        if os.clock() - startTime > 10 then
            print("⚠️ Timeout leveling, lewati target")
            SharkLogic.unequipPet(PetsService, targetUUID)
            levelState.currentTargetUUID = nil
            return false
        end
        task.wait(0.5)
    end
    return false
end

-- ============================================================
-- START / STOP TOGGLE LEVELING
-- ============================================================

local LevelToggle
LevelToggle = LevelingTab:CreateToggle({
    Name = "▶️ Start / Stop Leveling",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            if #levelState.teamQueue == 0 then
                print("⚠️ Pilih Tim Leveling dulu!")
                if LevelToggle then LevelToggle:Set(false) end
                return
            end
            if #levelState.targetQueue == 0 then
                print("⚠️ Pilih Target Leveling dulu!")
                if LevelToggle then LevelToggle:Set(false) end
                return
            end

            levelState.isActive = true
            levelState.isProcessing = false
            levelState.currentTargetIndex = 1
            levelState.currentTargetUUID = nil
            levelState.currentTeamUUIDs = {}

            print("▶️ Auto Leveling dimulai")

            -- 1. Bersihkan garden
            unequipAllGarden()

            -- 2. Equip Tim Leveling
            equipTeam()

            -- 3. Proses target satu per satu
            task.spawn(function()
                while levelState.isActive do
                    local targetUUID = getNextLevelTarget()
                    if not targetUUID then
                        print("⚠️ Tidak ada target tersisa")
                        break
                    end

                    -- Proses target
                    local done = processLevelTarget(targetUUID)
                    if not done then
                        print("❌ Gagal memproses target, lanjut ke berikutnya")
                    end

                    -- Hapus target dari queue jika sudah selesai (opsional)
                    -- tapi karena kita loop, kita bisa lanjutkan
                    task.wait(0.5)
                end
                -- Jika selesai semua target, stop otomatis
                if levelState.isActive then
                    print("✅ Semua target selesai, Auto Leveling berhenti")
                    if LevelToggle then LevelToggle:Set(false) end
                    levelState.isActive = false
                end
            end)
        else
            levelState.isActive = false
            print("⏹️ Auto Leveling dihentikan")
            -- Unequip semua target & tim
            unequipAllGarden()
            levelState.currentTargetUUID = nil
            levelState.currentTeamUUIDs = {}
        end
    end
})

-- ============================================================
-- INISIALISASI LEVELING
-- ============================================================

refreshTeamDropdown()
refreshTargetLevelDropdown()

print("✅ Tab Auto Leveling siap.")

print("✅ Auto Shark siap (Target: Semua Non-Fav Normal). Tekan K untuk membuka UI.")

-- ============================================================
-- Pria Solo HUB - Rayfield 2 (Gen2)
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local CONFIG_FILE = "PriaSolo.json"

-- Load modul
local DataPetModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSolo/refs/heads/main/DataPetModule.lua"))()
local SharkLogic = loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSolo/refs/heads/main/SharkLogic.lua"))()
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

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

local function uniqueTable(t)
    local seen = {}
    local result = {}
    for _, v in ipairs(t) do
        if not seen[v] then
            seen[v] = true
            table.insert(result, v)
        end
    end
    return result
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
    pnpActive = false,
    pnpPets = {},
    pnpPickupDelay = 0.6,
    pnpPlaceDelay = 0,
    pnpProcessing = {},
}

local isLevelingProcessing = false
local isUnequipping = false

-- ============================================================
-- EVENT SERVICE
-- ============================================================

local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local PetCooldownsEvent = GameEvents:WaitForChild("PetCooldownsUpdated")
local PetsService = GameEvents:WaitForChild("PetsService")
local NotificationEvent = GameEvents:WaitForChild("Notification")

-- ============================================================
-- FUNGSI UNEQUIP SELEKTIF (sama seperti sebelumnya)
-- ============================================================

local function unequipAllGardenPets(keepUUIDs, timeout)
    timeout = timeout or 1.0
    if isUnequipping then return end
    isUnequipping = true

    keepUUIDs = keepUUIDs or {}
    local keepMap = {}
    for _, uuid in ipairs(keepUUIDs) do
        keepMap[uuid] = true
    end

    local data = DataPetModule.getAllPets()
    if not data then
        isUnequipping = false
        return
    end
    local equipped = data.PetsData and data.PetsData.EquippedPets
    if not equipped or type(equipped) ~= "table" then
        isUnequipping = false
        return
    end

    equipped = uniqueTable(equipped)

    local toUnequip = {}
    for _, uuid in ipairs(equipped) do
        if not keepMap[uuid] then
            table.insert(toUnequip, uuid)
        end
    end

    if #toUnequip > 0 then
        print("🔄 Unequip " .. #toUnequip .. " pet (timeout " .. timeout .. "s)")
        local startTime = os.clock()
        for i, uuid in ipairs(toUnequip) do
            if os.clock() - startTime > timeout then
                print("⏹️ Unequip dihentikan (timeout) - sisa " .. (#toUnequip - i + 1) .. " pet")
                break
            end
            SharkLogic.unequipPet(PetsService, uuid)
            task.wait(0.05)
        end
    else
        print("✅ Tidak ada pet yang perlu diunequip")
    end

    isUnequipping = false
end

-- ============================================================
-- FUNGSI LOGIKA AUTO SHARK (sama seperti sebelumnya)
-- ============================================================

local function unequipTargetAndEquipShark()
    if state.isSharkActive == false then return end
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
-- FUNGSI LOGIKA AUTO LEVELING (sama seperti sebelumnya)
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

    unequipAllGardenPets(state.levelingTim, 1.0)
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

    if state.currentLevelingTargetUUID then
        SharkLogic.unequipPet(PetsService, state.currentLevelingTargetUUID)
        state.currentLevelingTargetUUID = nil
        task.wait(0.05)
    end

    for _, uuid in ipairs(state.levelingTim) do
        SharkLogic.unequipPet(PetsService, uuid)
        task.wait(0.05)
    end

    unequipAllGardenPets({}, 1.0)
    print("⏹️ Auto Leveling dihentikan, semua pet diunequip.")
end

-- ============================================================
-- FUNGSI LOGIKA PNP (tanpa print, CFrame default)
-- ============================================================

local function pnpProcessPet(uuid)
    if state.pnpProcessing[uuid] then return end
    state.pnpProcessing[uuid] = true

    local pickupDelay = state.pnpPickupDelay or 0.6
    local placeDelay = state.pnpPlaceDelay or 0

    task.wait(pickupDelay)
    SharkLogic.unequipPet(PetsService, uuid)

    task.wait(placeDelay)
    SharkLogic.equipPet(PetsService, uuid, SharkLogic.defaultConfig.slotCFrame)

    state.pnpProcessing[uuid] = false
end

-- ============================================================
-- EVENT LISTENER (Cooldown)
-- ============================================================

local isHandlingCooldownEvent = false

PetCooldownsEvent.OnClientEvent:Connect(function(petId, dataArray)
    -- PNP
    if state.pnpActive and petId and state.pnpPets and type(state.pnpPets) == "table" then
        for _, uuid in ipairs(state.pnpPets) do
            if petId == uuid then
                local time = nil
                for _, entry in ipairs(dataArray) do
                    if entry.Time then time = entry.Time break end
                end
                if time == nil then return end
                if time <= 0.1 and not state.pnpProcessing[uuid] then
                    task.spawn(function()
                        pnpProcessPet(uuid)
                    end)
                end
                break
            end
        end
    end

    -- Auto Shark
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
-- SAVE / LOAD (untuk konfigurasi internal, bukan Rayfield)
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
        pnpPets = state.pnpPets,
        pnpPickupDelay = state.pnpPickupDelay,
        pnpPlaceDelay = state.pnpPlaceDelay,
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
        state.pnpPets = decoded.pnpPets or {}
        state.pnpPickupDelay = decoded.pnpPickupDelay or 0.6
        state.pnpPlaceDelay = decoded.pnpPlaceDelay or 0
        print("✅ Konfigurasi dimuat dari " .. CONFIG_FILE)
        refreshAllUI()
    else
        warn("❌ Gagal memuat file.")
    end
end

local function resetAllSettings()
    if state.isSharkActive then
        state.isSharkActive = false
        unequipTargetAndEquipShark()
        unequipAllGardenPets({}, 1.0)
        if state.selectedMimicUUID then
            SharkLogic.unequipPet(PetsService, state.selectedMimicUUID)
        end
        if state.selectedSharkUUID then
            SharkLogic.unequipPet(PetsService, state.selectedSharkUUID)
        end
        if SharkToggle then SharkToggle:Set(false) end
    end
    if state.isLevelingActive then
        stopLeveling()
        if LevelingToggle then LevelingToggle:Set(false) end
    end
    if state.pnpActive then
        state.pnpActive = false
        for uuid, _ in pairs(state.pnpProcessing) do
            state.pnpProcessing[uuid] = false
        end
        if PnpToggle then PnpToggle:Set(false) end
    end

    state.selectedMimicUUID = nil
    state.selectedSharkUUID = nil
    state.targetQueue = {}
    state.levelingTim = {}
    state.levelingTargets = {}
    state.pnpPets = {}
    state.tumbalNames = {"Dog"}
    state.minLevel = 100
    state.targetLevel = 100
    state.pnpPickupDelay = 0.6
    state.pnpPlaceDelay = 0

    refreshAllUI()
    print("🔄 Semua pengaturan direset ke default.")
end

-- ============================================================
-- DEKLARASI VARIABEL UI
-- ============================================================

local window
local StatusLabel
local TumbalInput, MinLevelSlider, TargetLevelSlider
local SharkToggle, LevelingToggle, PnpToggle
local MimicDropdown, SharkDropdown, TargetDropdown
local TimDropdown, TargetLevelDropdown
local PnpDropdown

-- ============================================================
-- FUNGSI REFRESH
-- ============================================================

local function updateStatusLabel()
    if not StatusLabel then return end
    local mimicText = state.selectedMimicUUID and tostring(state.selectedMimicUUID) or "(belum)"
    local sharkText = state.selectedSharkUUID and tostring(state.selectedSharkUUID) or "(belum)"
    local targetCount = #state.targetQueue
    StatusLabel:Set("Mimic: " .. mimicText .. " | Shark: " .. sharkText .. " | Target: " .. targetCount .. " terpilih")
end

local function refreshMimicDropdown(filterText)
    filterText = filterText or ""
    local currentUUID = state.selectedMimicUUID
    local hasil = DataPetModule.findPets({ name = "Mimic", isFavorite = true })
    local options = {}
    local labelToUUID = {}
    for _, pet in ipairs(hasil) do
        local label = formatPetLabel(pet)
        if string.lower(label):find(string.lower(filterText)) then
            if labelToUUID[label] then
                label = label .. " [" .. string.sub(pet.uuid, 1, 4) .. "]"
            end
            table.insert(options, label)
            labelToUUID[label] = pet.uuid
        end
    end
    table.sort(options, sortAlphabetically)
    if #options == 0 then options = {"❌ Tidak ada Mimic favorit"} end
    if MimicDropdown then
        MimicDropdown:SetOptions(options)
        if currentUUID then
            for label, uuid in pairs(labelToUUID) do
                if uuid == currentUUID then
                    MimicDropdown:SetCurrentOption(label)
                    break
                end
            end
        end
        _G._mimicMap = labelToUUID
    end
end

local function refreshSharkDropdown(filterText)
    filterText = filterText or ""
    local currentUUID = state.selectedSharkUUID
    local hasil = DataPetModule.findPets({ name = "Shark", isFavorite = true })
    local options = {}
    local labelToUUID = {}
    for _, pet in ipairs(hasil) do
        local label = formatPetLabel(pet)
        if string.lower(label):find(string.lower(filterText)) then
            if labelToUUID[label] then
                label = label .. " [" .. string.sub(pet.uuid, 1, 4) .. "]"
            end
            table.insert(options, label)
            labelToUUID[label] = pet.uuid
        end
    end
    table.sort(options, sortAlphabetically)
    if #options == 0 then options = {"❌ Tidak ada Shark favorit"} end
    if SharkDropdown then
        SharkDropdown:SetOptions(options)
        if currentUUID then
            for label, uuid in pairs(labelToUUID) do
                if uuid == currentUUID then
                    SharkDropdown:SetCurrentOption(label)
                    break
                end
            end
        end
        _G._sharkMap = labelToUUID
    end
end

local function refreshTargetDropdown(filterText)
    filterText = filterText or ""
    local currentQueue = state.targetQueue
    local hasil = DataPetModule.findPets({
        type = "Mimic Octopus",
        isFavorite = false,
        mutation = "Normal",
        excludeUUIDs = {state.selectedMimicUUID, state.selectedSharkUUID}
    })
    local options = {}
    local labelToUUID = {}
    for _, pet in ipairs(hasil) do
        local label = formatPetLabel(pet)
        if string.lower(label):find(string.lower(filterText)) then
            if labelToUUID[label] then
                label = label .. " [" .. string.sub(pet.uuid, 1, 4) .. "]"
            end
            table.insert(options, label)
            labelToUUID[label] = pet.uuid
        end
    end
    table.sort(options, sortAlphabetically)
    if #options == 0 then options = {"❌ Tidak ada target"} end
    if TargetDropdown then
        TargetDropdown:SetOptions(options)
        if #currentQueue > 0 then
            local selectedLabels = {}
            for _, uuid in ipairs(currentQueue) do
                for label, u in pairs(labelToUUID) do
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
        _G._targetMap = labelToUUID
    end
end

local function refreshTimDropdown(filterText)
    filterText = filterText or ""
    local currentTim = state.levelingTim
    local hasil = DataPetModule.findPets({ isFavorite = true })
    local options = {}
    local labelToUUID = {}
    for _, pet in ipairs(hasil) do
        local label = formatPetLabel(pet)
        if string.lower(label):find(string.lower(filterText)) then
            if labelToUUID[label] then
                label = label .. " [" .. string.sub(pet.uuid, 1, 4) .. "]"
            end
            table.insert(options, label)
            labelToUUID[label] = pet.uuid
        end
    end
    table.sort(options, sortAlphabetically)
    if #options == 0 then options = {"❌ Tidak ada pet favorit"} end
    if TimDropdown then
        TimDropdown:SetOptions(options)
        if #currentTim > 0 then
            local selectedLabels = {}
            for _, uuid in ipairs(currentTim) do
                for label, u in pairs(labelToUUID) do
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
        _G._timMap = labelToUUID
    end
end

local function refreshTargetLevelDropdown(filterText)
    filterText = filterText or ""
    local currentTargets = state.levelingTargets
    local hasil = DataPetModule.findPets({ isFavorite = false })
    local options = {}
    local labelToUUID = {}
    for _, pet in ipairs(hasil) do
        local label = formatPetLabel(pet)
        if string.lower(label):find(string.lower(filterText)) then
            if labelToUUID[label] then
                label = label .. " [" .. string.sub(pet.uuid, 1, 4) .. "]"
            end
            table.insert(options, label)
            labelToUUID[label] = pet.uuid
        end
    end
    table.sort(options, sortAlphabetically)
    if #options == 0 then options = {"❌ Tidak ada pet non-favorit"} end
    if TargetLevelDropdown then
        TargetLevelDropdown:SetOptions(options)
        if #currentTargets > 0 then
            local selectedLabels = {}
            for _, uuid in ipairs(currentTargets) do
                for label, u in pairs(labelToUUID) do
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
        _G._targetLevelMap = labelToUUID
    end
end

local function refreshPnpDropdown(filterText)
    filterText = filterText or ""
    local currentPnp = state.pnpPets
    local hasil = DataPetModule.findPets({ isFavorite = true })
    local options = {}
    local labelToUUID = {}
    for _, pet in ipairs(hasil) do
        local label = formatPetLabel(pet)
        if string.lower(label):find(string.lower(filterText)) then
            if labelToUUID[label] then
                label = label .. " [" .. string.sub(pet.uuid, 1, 4) .. "]"
            end
            table.insert(options, label)
            labelToUUID[label] = pet.uuid
        end
    end
    table.sort(options, sortAlphabetically)
    if #options == 0 then options = {"❌ Tidak ada pet favorit"} end
    if PnpDropdown then
        PnpDropdown:SetOptions(options)
        if #currentPnp > 0 then
            local selectedLabels = {}
            for _, uuid in ipairs(currentPnp) do
                for label, u in pairs(labelToUUID) do
                    if u == uuid then
                        table.insert(selectedLabels, label)
                        break
                    end
                end
            end
            if #selectedLabels > 0 then
                PnpDropdown:SetSelectedOptions(selectedLabels)
            end
        end
        _G._pnpMap = labelToUUID
    end
end

-- ============================================================
-- REFRESH ALL UI
-- ============================================================

local function refreshAllUI()
    refreshMimicDropdown()
    refreshSharkDropdown()
    refreshTargetDropdown()
    refreshTimDropdown()
    refreshTargetLevelDropdown()
    refreshPnpDropdown()
    updateStatusLabel()
    if TumbalInput then
        TumbalInput:SetCurrentValue(table.concat(state.tumbalNames, ", "))
    end
    if MinLevelSlider then
        MinLevelSlider:SetCurrentValue(state.minLevel)
    end
    if TargetLevelSlider then
        TargetLevelSlider:SetCurrentValue(state.targetLevel)
    end
end

-- ============================================================
-- UI (Rayfield 2)
-- ============================================================

window = Rayfield:CreateWindow({
    name = "Pria Solo HUB",
    configuration = {
        autoSave = true,
        autoLoad = true,
        fileName = "Settings",
        customFolder = "PriaSolo",
    },
    key = Enum.KeyCode.K,
})

-- ============================================================
-- TAB 1: AUTO SHARK
-- ============================================================

local sharkTab = window:CreateTab({ name = "Auto Shark" })

StatusLabel = sharkTab:CreateLabel({
    name = "Mimic: (belum) | Shark: (belum) | Target: 0 terpilih"
})

sharkTab:CreateInput({
    name = "🔍 Cari Mimic",
    placeholder = "Filter...",
    currentValue = "",
    callback = function(Value)
        refreshMimicDropdown(Value)
    end
})

MimicDropdown = sharkTab:CreateDropdown({
    name = "Pilih Mimic",
    options = {"Memuat data..."},
    currentOption = "Memuat data...",
    multiple = false,
    callback = function(option)
        local selectedLabel = (type(option) == "table") and option[1] or option
        local map = _G._mimicMap or {}
        local uuid = map[selectedLabel]
        if uuid then
            state.selectedMimicUUID = uuid
            print("✅ Mimic dipilih:", selectedLabel, "UUID:", uuid)
            updateStatusLabel()
        end
    end
})

sharkTab:CreateInput({
    name = "🔍 Cari Shark",
    placeholder = "Filter...",
    currentValue = "",
    callback = function(Value)
        refreshSharkDropdown(Value)
    end
})

SharkDropdown = sharkTab:CreateDropdown({
    name = "Pilih Shark",
    options = {"Memuat data..."},
    currentOption = "Memuat data...",
    multiple = false,
    callback = function(option)
        local selectedLabel = (type(option) == "table") and option[1] or option
        local map = _G._sharkMap or {}
        local uuid = map[selectedLabel]
        if uuid then
            state.selectedSharkUUID = uuid
            print("✅ Shark dipilih:", selectedLabel, "UUID:", uuid)
            updateStatusLabel()
        end
    end
})

sharkTab:CreateInput({
    name = "🔍 Cari Target",
    placeholder = "Filter...",
    currentValue = "",
    callback = function(Value)
        refreshTargetDropdown(Value)
    end
})

TargetDropdown = sharkTab:CreateDropdown({
    name = "Pilih Target (Multiple, Non-Fav, Normal)",
    options = {"Memuat data..."},
    currentOption = "Memuat data...",
    multiple = true,
    callback = function(selectedLabels)
        local map = _G._targetMap or {}
        state.targetQueue = {}
        for _, label in ipairs(selectedLabels) do
            local uuid = map[label]
            if uuid then table.insert(state.targetQueue, uuid) end
        end
        state.currentTargetIndex = 1
        print("✅ Target dipilih:", #state.targetQueue, "pet")
        updateStatusLabel()
    end
})

TumbalInput = sharkTab:CreateInput({
    name = "Nama Tumbal (pisah koma)",
    placeholder = "Contoh: Dog, Golden Lab, Black Bunny",
    currentValue = table.concat(state.tumbalNames, ", "),
    callback = function(Value)
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

MinLevelSlider = sharkTab:CreateSlider({
    name = "Min Level Tumbal",
    min = 0,
    max = 500,
    increment = 1,
    suffix = "Level",
    currentValue = state.minLevel,
    callback = function(value)
        state.minLevel = value
        print("📊 Min Level Tumbal:", value)
    end
})

sharkTab:CreateButton({
    name = "🔄 Refresh Daftar Pet",
    callback = function()
        refreshMimicDropdown()
        refreshSharkDropdown()
        refreshTargetDropdown()
        refreshTimDropdown()
        refreshTargetLevelDropdown()
        refreshPnpDropdown()
    end
})

SharkToggle = sharkTab:CreateToggle({
    name = "▶️ Start / Stop Shark",
    value = false,
    callback = function(Value)
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

            unequipAllGardenPets({state.selectedMimicUUID, state.selectedSharkUUID}, 1.0)
            task.wait(0.2)

            state.isSharkActive = true
            print("▶️ Auto Shark dimulai dengan", #state.targetQueue, "target")
            SharkLogic.equipPet(PetsService, state.selectedMimicUUID, SharkLogic.defaultConfig.slotCFrame)
            SharkLogic.equipPet(PetsService, state.selectedSharkUUID, SharkLogic.defaultConfig.slotCFrame)
        else
            state.isSharkActive = false
            print("⏹️ Auto Shark dihentikan")
            unequipTargetAndEquipShark()
            unequipAllGardenPets({}, 1.0)
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

local levelingTab = window:CreateTab({ name = "Auto Leveling" })

levelingTab:CreateInput({
    name = "🔍 Cari Tim",
    placeholder = "Filter...",
    currentValue = "",
    callback = function(Value)
        refreshTimDropdown(Value)
    end
})

TimDropdown = levelingTab:CreateDropdown({
    name = "Tim Leveling (Max 7, Favorit)",
    options = {"Memuat data..."},
    currentOption = "Memuat data...",
    multiple = true,
    callback = function(selectedLabels)
        local map = _G._timMap or {}
        state.levelingTim = {}
        for _, label in ipairs(selectedLabels) do
            local uuid = map[label]
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

levelingTab:CreateInput({
    name = "🔍 Cari Target Leveling",
    placeholder = "Filter...",
    currentValue = "",
    callback = function(Value)
        refreshTargetLevelDropdown(Value)
    end
})

TargetLevelDropdown = levelingTab:CreateDropdown({
    name = "Target Leveling (Non-Favorit)",
    options = {"Memuat data..."},
    currentOption = "Memuat data...",
    multiple = true,
    callback = function(selectedLabels)
        local map = _G._targetLevelMap or {}
        state.levelingTargets = {}
        for _, label in ipairs(selectedLabels) do
            local uuid = map[label]
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

TargetLevelSlider = levelingTab:CreateSlider({
    name = "Target Level",
    min = 0,
    max = 500,
    increment = 1,
    suffix = "Level",
    currentValue = state.targetLevel,
    callback = function(value)
        state.targetLevel = value
        print("🎯 Target Level:", value)
        if state.isLevelingActive and not isLevelingProcessing then
            state.isLevelingActive = false
            task.wait(0.1)
            startLeveling()
        end
    end
})

LevelingToggle = levelingTab:CreateToggle({
    name = "▶️ Start / Stop Leveling",
    value = false,
    callback = function(Value)
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
-- TAB 3: PNP
-- ============================================================

local pnpTab = window:CreateTab({ name = "PNP" })

pnpTab:CreateInput({
    name = "🔍 Cari Pet",
    placeholder = "Filter...",
    currentValue = "",
    callback = function(Value)
        refreshPnpDropdown(Value)
    end
})

PnpDropdown = pnpTab:CreateDropdown({
    name = "Pilih Pet untuk PNP",
    options = {"Memuat data..."},
    currentOption = "Memuat data...",
    multiple = true,
    callback = function(selectedLabels)
        local map = _G._pnpMap or {}
        state.pnpPets = {}
        for _, label in ipairs(selectedLabels) do
            local uuid = map[label]
            if uuid then table.insert(state.pnpPets, uuid) end
        end
        print("✅ PNP Pets dipilih:", #state.pnpPets, "pet")
    end
})

pnpTab:CreateInput({
    name = "Pickup Delay (detik)",
    placeholder = "0.6",
    currentValue = tostring(state.pnpPickupDelay),
    callback = function(Value)
        local num = tonumber(Value)
        if num and num >= 0 then
            state.pnpPickupDelay = num
            print("📦 Pickup Delay:", num)
        else
            print("⚠️ Masukkan angka valid")
        end
    end
})

pnpTab:CreateInput({
    name = "Place Delay (detik)",
    placeholder = "0",
    currentValue = tostring(state.pnpPlaceDelay),
    callback = function(Value)
        local num = tonumber(Value)
        if num and num >= 0 then
            state.pnpPlaceDelay = num
            print("📦 Place Delay:", num)
        else
            print("⚠️ Masukkan angka valid")
        end
    end
})

pnpTab:CreateButton({
    name = "🔄 Refresh Daftar Pet",
    callback = function()
        refreshPnpDropdown()
    end
})

PnpToggle = pnpTab:CreateToggle({
    name = "▶️ Start / Stop PNP",
    value = false,
    callback = function(Value)
        if Value then
            if #state.pnpPets == 0 then
                print("⚠️ Pilih pet dulu!")
                if PnpToggle then PnpToggle:Set(false) end
                return
            end
            state.pnpActive = true
            print("▶️ PNP dimulai untuk", #state.pnpPets, "pet")
        else
            state.pnpActive = false
            for uuid, _ in pairs(state.pnpProcessing) do
                state.pnpProcessing[uuid] = false
            end
            print("⏹️ PNP dihentikan")
        end
    end
})

-- ============================================================
-- TAB 4: PENGATURAN
-- ============================================================

local settingsTab = window:CreateTab({ name = "Pengaturan" })

settingsTab:CreateButton({
    name = "💾 Simpan Konfigurasi",
    callback = saveConfig
})

settingsTab:CreateButton({
    name = "📂 Muat Konfigurasi",
    callback = loadConfig
})

settingsTab:CreateButton({
    name = "🔄 Reset Semua",
    callback = resetAllSettings
})

-- ============================================================
-- INISIALISASI
-- ============================================================

refreshAllUI()

print("✅ Pria Solo HUB siap (Rayfield 2). Tekan K untuk membuka UI.")

-- ============================================================
-- Pria Solo HUB - Rayfield GEN2 (Simple & Stable)
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
-- FUNGSI UNEQUIP SELEKTIF
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
-- FUNGSI LOGIKA AUTO SHARK
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
-- FUNGSI LOGIKA AUTO LEVELING
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
-- FUNGSI LOGIKA PNP
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
-- FUNGSI UNTUK MENGAMBIL DATA DROPDOWN
-- ============================================================

local function getMimicOptions(filterText)
    filterText = filterText or ""
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
    if #options == 0 then options = {"❌ Tidak ada Mimic favorit"}
    _G._mimicMap = labelToUUID
    return options
end

local function getSharkOptions(filterText)
    filterText = filterText or ""
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
    if #options == 0 then options = {"❌ Tidak ada Shark favorit"}
    _G._sharkMap = labelToUUID
    return options
end

local function getTargetOptions(filterText)
    filterText = filterText or ""
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
    if #options == 0 then options = {"❌ Tidak ada target"}
    _G._targetMap = labelToUUID
    return options
end

local function getTimOptions(filterText)
    filterText = filterText or ""
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
    if #options == 0 then options = {"❌ Tidak ada pet favorit"}
    _G._timMap = labelToUUID
    return options
end

local function getTargetLevelOptions(filterText)
    filterText = filterText or ""
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
    if #options == 0 then options = {"❌ Tidak ada pet non-favorit"}
    _G._targetLevelMap = labelToUUID
    return options
end

local function getPnpOptions(filterText)
    filterText = filterText or ""
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
    if #options == 0 then options = {"❌ Tidak ada pet favorit"}
    _G._pnpMap = labelToUUID
    return options
end

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
        -- refresh all UI setelah load
        updateAllUI()
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
        if SharkToggle then SharkToggle:SetValue(false) end
    end
    if state.isLevelingActive then
        stopLeveling()
        if LevelingToggle then LevelingToggle:SetValue(false) end
    end
    if state.pnpActive then
        state.pnpActive = false
        for uuid, _ in pairs(state.pnpProcessing) do
            state.pnpProcessing[uuid] = false
        end
        if PnpToggle then PnpToggle:SetValue(false) end
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

    updateAllUI()
    print("🔄 Semua pengaturan direset ke default.")
end

-- ============================================================
-- UI (Rayfield GEN2)
-- ============================================================

local Window = Rayfield:CreateWindow({
    name = "Pria Solo HUB",
    configuration = {
        autoSave = false,
        autoLoad = false,
        fileName = "Settings",
        customFolder = "PriaSolo",
    },
    key = Enum.KeyCode.K,
})

-- Variabel untuk menyimpan referensi dropdown
local MimicDropdown, SharkDropdown, TargetDropdown
local TimDropdown, TargetLevelDropdown, PnpDropdown
local TumbalInput, MinLevelSlider, TargetLevelSlider
local SharkToggle, LevelingToggle, PnpToggle

-- ============================================================
-- UPDATE UI (dipanggil saat load/reset/refresh)
-- ============================================================

local function updateAllUI()
    if MimicDropdown then
        MimicDropdown:SetOptions(getMimicOptions())
        if state.selectedMimicUUID then
            for label, uuid in pairs(_G._mimicMap or {}) do
                if uuid == state.selectedMimicUUID then
                    MimicDropdown:SetValue(label)
                    break
                end
            end
        end
    end

    if SharkDropdown then
        SharkDropdown:SetOptions(getSharkOptions())
        if state.selectedSharkUUID then
            for label, uuid in pairs(_G._sharkMap or {}) do
                if uuid == state.selectedSharkUUID then
                    SharkDropdown:SetValue(label)
                    break
                end
            end
        end
    end

    if TargetDropdown then
        TargetDropdown:SetOptions(getTargetOptions())
        if #state.targetQueue > 0 then
            local selectedLabels = {}
            for _, uuid in ipairs(state.targetQueue) do
                for label, u in pairs(_G._targetMap or {}) do
                    if u == uuid then
                        table.insert(selectedLabels, label)
                        break
                    end
                end
            end
            if #selectedLabels > 0 then
                TargetDropdown:SetValue(selectedLabels)
            end
        end
    end

    if TimDropdown then
        TimDropdown:SetOptions(getTimOptions())
        if #state.levelingTim > 0 then
            local selectedLabels = {}
            for _, uuid in ipairs(state.levelingTim) do
                for label, u in pairs(_G._timMap or {}) do
                    if u == uuid then
                        table.insert(selectedLabels, label)
                        break
                    end
                end
            end
            if #selectedLabels > 0 then
                TimDropdown:SetValue(selectedLabels)
            end
        end
    end

    if TargetLevelDropdown then
        TargetLevelDropdown:SetOptions(getTargetLevelOptions())
        if #state.levelingTargets > 0 then
            local selectedLabels = {}
            for _, uuid in ipairs(state.levelingTargets) do
                for label, u in pairs(_G._targetLevelMap or {}) do
                    if u == uuid then
                        table.insert(selectedLabels, label)
                        break
                    end
                end
            end
            if #selectedLabels > 0 then
                TargetLevelDropdown:SetValue(selectedLabels)
            end
        end
    end

    if PnpDropdown then
        PnpDropdown:SetOptions(getPnpOptions())
        if #state.pnpPets > 0 then
            local selectedLabels = {}
            for _, uuid in ipairs(state.pnpPets) do
                for label, u in pairs(_G._pnpMap or {}) do
                    if u == uuid then
                        table.insert(selectedLabels, label)
                        break
                    end
                end
            end
            if #selectedLabels > 0 then
                PnpDropdown:SetValue(selectedLabels)
            end
        end
    end

    if TumbalInput then
        TumbalInput:SetValue(table.concat(state.tumbalNames, ", "))
    end
    if MinLevelSlider then
        MinLevelSlider:SetValue(state.minLevel)
    end
    if TargetLevelSlider then
        TargetLevelSlider:SetValue(state.targetLevel)
    end
end

-- ============================================================
-- TAB 1: AUTO SHARK
-- ============================================================

local sharkTab = Window:CreateTab({ name = "Auto Shark", icon = "shark" })

-- Filter input Mimic
sharkTab:CreateInput({
    name = "🔍 Cari Mimic",
    placeholder = "Filter...",
    value = "",
    flag = "mimicFilter",
    callback = function(Value)
        if MimicDropdown then
            MimicDropdown:SetOptions(getMimicOptions(Value))
            -- restore selected
            if state.selectedMimicUUID then
                for label, uuid in pairs(_G._mimicMap or {}) do
                    if uuid == state.selectedMimicUUID then
                        MimicDropdown:SetValue(label)
                        break
                    end
                end
            end
        end
    end
})

MimicDropdown = sharkTab:CreateDropdown({
    name = "Pilih Mimic",
    options = getMimicOptions(),
    value = "",
    multiSelect = false,
    flag = "mimicDropdown",
    callback = function(option)
        local selectedLabel = (type(option) == "table") and option[1] or option
        local map = _G._mimicMap or {}
        local uuid = map[selectedLabel]
        if uuid then
            state.selectedMimicUUID = uuid
            print("✅ Mimic dipilih:", selectedLabel, "UUID:", uuid)
        end
    end
})

-- Filter input Shark
sharkTab:CreateInput({
    name = "🔍 Cari Shark",
    placeholder = "Filter...",
    value = "",
    flag = "sharkFilter",
    callback = function(Value)
        if SharkDropdown then
            SharkDropdown:SetOptions(getSharkOptions(Value))
            if state.selectedSharkUUID then
                for label, uuid in pairs(_G._sharkMap or {}) do
                    if uuid == state.selectedSharkUUID then
                        SharkDropdown:SetValue(label)
                        break
                    end
                end
            end
        end
    end
})

SharkDropdown = sharkTab:CreateDropdown({
    name = "Pilih Shark",
    options = getSharkOptions(),
    value = "",
    multiSelect = false,
    flag = "sharkDropdown",
    callback = function(option)
        local selectedLabel = (type(option) == "table") and option[1] or option
        local map = _G._sharkMap or {}
        local uuid = map[selectedLabel]
        if uuid then
            state.selectedSharkUUID = uuid
            print("✅ Shark dipilih:", selectedLabel, "UUID:", uuid)
        end
    end
})

-- Filter input Target
sharkTab:CreateInput({
    name = "🔍 Cari Target",
    placeholder = "Filter...",
    value = "",
    flag = "targetFilter",
    callback = function(Value)
        if TargetDropdown then
            TargetDropdown:SetOptions(getTargetOptions(Value))
            -- restore selected (multiple)
            if #state.targetQueue > 0 then
                local selectedLabels = {}
                for _, uuid in ipairs(state.targetQueue) do
                    for label, u in pairs(_G._targetMap or {}) do
                        if u == uuid then
                            table.insert(selectedLabels, label)
                            break
                        end
                    end
                end
                if #selectedLabels > 0 then
                    TargetDropdown:SetValue(selectedLabels)
                end
            end
        end
    end
})

TargetDropdown = sharkTab:CreateDropdown({
    name = "Pilih Target (Multiple, Non-Fav, Normal)",
    options = getTargetOptions(),
    value = {},
    multiSelect = true,
    flag = "targetDropdown",
    callback = function(selectedLabels)
        local map = _G._targetMap or {}
        state.targetQueue = {}
        for _, label in ipairs(selectedLabels) do
            local uuid = map[label]
            if uuid then table.insert(state.targetQueue, uuid) end
        end
        state.currentTargetIndex = 1
        print("✅ Target dipilih:", #state.targetQueue, "pet")
    end
})

TumbalInput = sharkTab:CreateInput({
    name = "Nama Tumbal (pisah koma)",
    placeholder = "Contoh: Dog, Golden Lab, Black Bunny",
    value = table.concat(state.tumbalNames, ", "),
    flag = "tumbalInput",
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
    value = state.minLevel,
    flag = "minLevelSlider",
    callback = function(value)
        state.minLevel = value
        print("📊 Min Level Tumbal:", value)
    end
})

sharkTab:CreateButton({
    name = "🔄 Refresh Data Pet",
    flag = "refreshShark",
    callback = function()
        updateAllUI()
        print("🔄 Data pet diperbarui.")
    end
})

SharkToggle = sharkTab:CreateToggle({
    name = "▶️ Start / Stop Shark",
    value = false,
    flag = "sharkToggle",
    callback = function(Value)
        if Value then
            if state.isLevelingActive then
                print("⚠️ Auto Leveling sedang aktif! Matikan dulu.")
                SharkToggle:SetValue(false)
                return
            end
            if not state.selectedMimicUUID then
                print("⚠️ Pilih Mimic dulu!")
                SharkToggle:SetValue(false)
                return
            end
            if not state.selectedSharkUUID then
                print("⚠️ Pilih Shark dulu!")
                SharkToggle:SetValue(false)
                return
            end
            if #state.targetQueue == 0 then
                print("⚠️ Pilih target dulu (multiple)!")
                SharkToggle:SetValue(false)
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

local levelingTab = Window:CreateTab({ name = "Auto Leveling", icon = "rocket" })

levelingTab:CreateInput({
    name = "🔍 Cari Tim",
    placeholder = "Filter...",
    value = "",
    flag = "timFilter",
    callback = function(Value)
        if TimDropdown then
            TimDropdown:SetOptions(getTimOptions(Value))
            if #state.levelingTim > 0 then
                local selectedLabels = {}
                for _, uuid in ipairs(state.levelingTim) do
                    for label, u in pairs(_G._timMap or {}) do
                        if u == uuid then
                            table.insert(selectedLabels, label)
                            break
                        end
                    end
                end
                if #selectedLabels > 0 then
                    TimDropdown:SetValue(selectedLabels)
                end
            end
        end
    end
})

TimDropdown = levelingTab:CreateDropdown({
    name = "Tim Leveling (Max 7, Favorit)",
    options = getTimOptions(),
    value = {},
    multiSelect = true,
    flag = "timDropdown",
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
    value = "",
    flag = "targetLevelFilter",
    callback = function(Value)
        if TargetLevelDropdown then
            TargetLevelDropdown:SetOptions(getTargetLevelOptions(Value))
            if #state.levelingTargets > 0 then
                local selectedLabels = {}
                for _, uuid in ipairs(state.levelingTargets) do
                    for label, u in pairs(_G._targetLevelMap or {}) do
                        if u == uuid then
                            table.insert(selectedLabels, label)
                            break
                        end
                    end
                end
                if #selectedLabels > 0 then
                    TargetLevelDropdown:SetValue(selectedLabels)
                end
            end
        end
    end
})

TargetLevelDropdown = levelingTab:CreateDropdown({
    name = "Target Leveling (Non-Favorit)",
    options = getTargetLevelOptions(),
    value = {},
    multiSelect = true,
    flag = "targetLevelDropdown",
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
    value = state.targetLevel,
    flag = "targetLevelSlider",
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
    flag = "levelingToggle",
    callback = function(Value)
        if Value then
            if state.isSharkActive then
                print("⚠️ Auto Shark sedang aktif! Matikan dulu.")
                LevelingToggle:SetValue(false)
                return
            end
            if #state.levelingTim == 0 then
                print("⚠️ Pilih Tim Leveling dulu!")
                LevelingToggle:SetValue(false)
                return
            end
            if #state.levelingTargets == 0 then
                print("⚠️ Pilih Target Leveling dulu!")
                LevelingToggle:SetValue(false)
                return
            end
            startLeveling()
        else
            stopLeveling()
            LevelingToggle:SetValue(false)
        end
    end
})

-- ============================================================
-- TAB 3: PNP
-- ============================================================

local pnpTab = Window:CreateTab({ name = "PNP", icon = "bolt" })

pnpTab:CreateInput({
    name = "🔍 Cari Pet",
    placeholder = "Filter...",
    value = "",
    flag = "pnpFilter",
    callback = function(Value)
        if PnpDropdown then
            PnpDropdown:SetOptions(getPnpOptions(Value))
            if #state.pnpPets > 0 then
                local selectedLabels = {}
                for _, uuid in ipairs(state.pnpPets) do
                    for label, u in pairs(_G._pnpMap or {}) do
                        if u == uuid then
                            table.insert(selectedLabels, label)
                            break
                        end
                    end
                end
                if #selectedLabels > 0 then
                    PnpDropdown:SetValue(selectedLabels)
                end
            end
        end
    end
})

PnpDropdown = pnpTab:CreateDropdown({
    name = "Pilih Pet untuk PNP",
    options = getPnpOptions(),
    value = {},
    multiSelect = true,
    flag = "pnpDropdown",
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
    value = tostring(state.pnpPickupDelay),
    flag = "pickupDelay",
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
    value = tostring(state.pnpPlaceDelay),
    flag = "placeDelay",
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
    name = "🔄 Refresh Data Pet",
    flag = "pnpRefresh",
    callback = function()
        updateAllUI()
        print("🔄 Data pet diperbarui.")
    end
})

PnpToggle = pnpTab:CreateToggle({
    name = "▶️ Start / Stop PNP",
    value = false,
    flag = "pnpToggle",
    callback = function(Value)
        if Value then
            if #state.pnpPets == 0 then
                print("⚠️ Pilih pet dulu!")
                PnpToggle:SetValue(false)
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

local settingsTab = Window:CreateTab({ name = "Pengaturan", icon = "gear" })

settingsTab:CreateButton({
    name = "💾 Simpan Konfigurasi",
    flag = "save",
    callback = saveConfig
})

settingsTab:CreateButton({
    name = "📂 Muat Konfigurasi",
    flag = "load",
    callback = loadConfig
})

settingsTab:CreateButton({
    name = "🔄 Reset Semua",
    flag = "reset",
    callback = resetAllSettings
})

-- ============================================================
-- INISIALISASI AWAL
-- ============================================================

updateAllUI()

print("✅ Pria Solo HUB siap (Rayfield GEN2). Tekan K untuk membuka UI.")

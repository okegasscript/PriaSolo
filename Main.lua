-- Main.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- 1. Load DataPetModule
local DataPetModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSolo/refs/heads/main/DataPetModule.lua"))()

-- 2. Load SharkLogic
local SharkLogic = loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSolo/refs/heads/main/SharkLogic.lua"))()

-- 3. Load UIController dan buat UI
local createUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSolo/refs/heads/main/UIController.lua"))()
local UIState = createUI(DataPetModule, SharkLogic)

-- 4. Ambil event service
local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local PetCooldownsEvent = GameEvents:WaitForChild("PetCooldownsUpdated")
local PetsService = GameEvents:WaitForChild("PetsService")
local NotificationEvent = GameEvents:WaitForChild("Notification")

-- 5. State internal
local state = {
    selectedMimicUUID = nil,
    selectedSharkUUID = nil,
    tumbalNames = {"Dog"},
    targetName = "Moon Cat",
    isActive = false,
    isProcessing = false,
    currentTumbalUUID = nil,
    currentTargetUUID = nil,
    cycleCount = 0,
    lastActionTime = 0,
    slotCFrame = CFrame.new(-13.018989562988, 0, -74.922821044922, 1,0,0,0,1,0,0,0,1)
}

-- Sinkronisasi UIState dengan state internal
UIState.onUpdate(function(ui)
    state.selectedMimicUUID = ui.selectedMimicUUID
    state.selectedSharkUUID = ui.selectedSharkUUID
    state.tumbalNames = ui.tumbalNames
    state.targetName = ui.targetName
    state.isActive = ui.isActive
    if state.isActive then
        -- Pastikan Mimic dan Shark di-equip saat start
        SharkLogic.equipPet(PetsService, state.selectedMimicUUID, state.slotCFrame)
        SharkLogic.equipPet(PetsService, state.selectedSharkUUID, state.slotCFrame)
        UIState.updateStatus("Status: Aktif")
    else
        -- Stop: unequip semua
        local equipped = DataPetModule.getEquippedPets()
        for _, uuid in ipairs(equipped) do
            SharkLogic.unequipPet(PetsService, uuid)
        end
        state.isProcessing = false
        UIState.updateStatus("Status: Berhenti")
    end
end)

-- 6. Fungsi logika (mirip sebelumnya)
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
        SharkLogic.equipPet(PetsService, state.selectedSharkUUID, state.slotCFrame)
    end
    state.isProcessing = false
    UIState.updateStatus("Status: Siklus selesai")
end

local function unequipSharkAndEquipTumbalTarget()
    if not state.selectedSharkUUID then return end

    local tumbalPet, tumbalUUID = SharkLogic.findTumbal(DataPetModule, state.tumbalNames, {state.selectedMimicUUID, state.selectedSharkUUID})
    local targetPet, targetUUID = SharkLogic.findTarget(DataPetModule, state.targetName, {state.selectedMimicUUID, state.selectedSharkUUID})

    if tumbalUUID and targetUUID then
        SharkLogic.unequipPet(PetsService, state.selectedSharkUUID)
        SharkLogic.equipPet(PetsService, tumbalUUID, state.slotCFrame)
        state.currentTumbalUUID = tumbalUUID
        SharkLogic.equipPet(PetsService, targetUUID, state.slotCFrame)
        state.currentTargetUUID = targetUUID
        state.isProcessing = true
        UIState.updateStatus("Status: Equip tumbal & target")
        print("✅ Equip tumbal & target")
    else
        UIState.updateStatus("⚠️ Tumbal atau target tidak ditemukan")
        SharkLogic.equipPet(PetsService, state.selectedSharkUUID, state.slotCFrame)
        state.isProcessing = false
    end
end

-- 7. Event listener
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

print("✅ Auto Shark siap. Tekan K untuk membuka UI.")
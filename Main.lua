-- ============================================================
-- Auto Shark - Main Entry (Semua modul di-load dari GitHub)
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- 1. Load semua modul dari GitHub
local DataPetModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSolo/refs/heads/main/DataPetModule.lua"))()
local SharkLogic = loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSolo/refs/heads/main/SharkLogic.lua"))()
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

if not DataPetModule or not SharkLogic or not Rayfield then
    warn("❌ Gagal memuat modul")
    return
end

print("✅ Semua modul berhasil dimuat")

-- 2. State global
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

-- 3. Ambil event service
local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local PetCooldownsEvent = GameEvents:WaitForChild("PetCooldownsUpdated")
local PetsService = GameEvents:WaitForChild("PetsService")
local NotificationEvent = GameEvents:WaitForChild("Notification")

-- 4. Fungsi logika (equip/unequip)
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

-- 5. Event listener cooldown & notifikasi
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

-- 6. UI dengan Rayfield (kompatibel versi sirius.menu/rayfield)
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

-- Tab: Team Favorit
local TabFav = Window:CreateTab("Team Favorit")

-- Dropdown untuk daftar pet favorit
local PetDropdown = TabFav:CreateDropdown({
    Name = "Daftar Pet Favorit",
    Options = {"Memuat data..."},
    CurrentOption = "",
    Callback = function(Option)
        if Option and Option ~= "Memuat data..." and Option ~= "❌ Tidak ada pet favorit" then
            -- Cari pet yang sesuai
            local hasil = DataPetModule.findPets({ isFavorite = true })
            for _, pet in ipairs(hasil) do
                local text = string.format("%s %s %.2f KG Lv.%d",
                    pet.mutation, pet.name, pet.weight or 0, pet.level)
                if text == Option then
                    DetailLabel:Set(string.format("Nama: %s\nMutasi: %s\nLevel: %d\nBerat: %.2f KG",
                        pet.name, pet.mutation, pet.level, pet.weight or 0))
                    break
                end
            end
        end
    end
})

local DetailLabel = TabFav:CreateLabel("Klik salah satu pet untuk melihat detail")

local function refreshFavorites()
    if not DataPetModule then
        PetDropdown:SetOptions({"❌ Module tidak tersedia"})
        DetailLabel:Set("Module DataPet tidak tersedia")
        return
    end

    local hasil = DataPetModule.findPets({ isFavorite = true })
    local options = {}
    for _, pet in ipairs(hasil) do
        local text = string.format("%s %s %.2f KG Lv.%d",
            pet.mutation, pet.name, pet.weight or 0, pet.level)
        table.insert(options, text)
    end
    if #options == 0 then
        options = {"❌ Tidak ada pet favorit"}
    end

    PetDropdown:SetOptions(options)
    if #options > 0 and options[1] ~= "❌ Tidak ada pet favorit" then
        PetDropdown:SetCurrentOption(options[1])
        -- Update detail label otomatis dengan pet pertama
        local first = hasil[1]
        if first then
            DetailLabel:Set(string.format("Nama: %s\nMutasi: %s\nLevel: %d\nBerat: %.2f KG",
                first.name, first.mutation, first.level, first.weight or 0))
        end
    else
        DetailLabel:Set("Tidak ada pet favorit")
    end
end

TabFav:CreateButton({
    Name = "Refresh Daftar",
    Callback = refreshFavorites
})

refreshFavorites()

-- Tab: Kontrol
local TabControl = Window:CreateTab("Kontrol")

-- Input untuk Mimic UUID (atau nanti bisa dropdown, tapi untuk sekarang input)
TabControl:CreateInput({
    Name = "Mimic UUID",
    PlaceholderText = "Masukkan UUID Mimic...",
    CurrentValue = "",
    Callback = function(Value)
        if Value and Value ~= "" then
            state.selectedMimicUUID = Value
            print("✅ Mimic UUID di-set:", Value)
        end
    end
})

TabControl:CreateInput({
    Name = "Shark UUID",
    PlaceholderText = "Masukkan UUID Shark...",
    CurrentValue = "",
    Callback = function(Value)
        if Value and Value ~= "" then
            state.selectedSharkUUID = Value
            print("✅ Shark UUID di-set:", Value)
        end
    end
})

-- Input untuk Target
TabControl:CreateInput({
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

-- Input untuk Tumbal (bisa multiple, dipisah koma)
TabControl:CreateInput({
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

-- Tombol Start/Stop
local StartStopButton
StartStopButton = TabControl:CreateButton({
    Name = "▶️ Start Script",
    Callback = function()
        if not state.selectedMimicUUID or not state.selectedSharkUUID then
            print("⚠️ Set Mimic dan Shark UUID terlebih dahulu")
            return
        end
        state.isActive = not state.isActive
        if state.isActive then
            StartStopButton:Set("⏹️ Stop Script")
            print("▶️ Script dimulai")
            -- Equip Mimic dan Shark di awal
            SharkLogic.equipPet(PetsService, state.selectedMimicUUID, SharkLogic.defaultConfig.slotCFrame)
            SharkLogic.equipPet(PetsService, state.selectedSharkUUID, SharkLogic.defaultConfig.slotCFrame)
        else
            StartStopButton:Set("▶️ Start Script")
            print("⏹️ Script dihentikan")
            -- Unequip semua
            unequipTargetAndEquipShark()
            -- Unequip juga mimic dan shark jika perlu
            if state.selectedMimicUUID then
                SharkLogic.unequipPet(PetsService, state.selectedMimicUUID)
            end
            if state.selectedSharkUUID then
                SharkLogic.unequipPet(PetsService, state.selectedSharkUUID)
            end
        end
    end
})

print("✅ Auto Shark siap. Tekan K untuk membuka UI.")

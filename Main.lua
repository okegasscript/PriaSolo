-- ============================================================
-- Main.lua - Auto Shark (Single File Load)
-- ============================================================

-- 1. Load Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- 2. Load DataPetModule dari GitHub
local DataPetModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSolo/refs/heads/main/DataPetModule.lua"))()

-- 3. Load SharkLogic dari GitHub (jika ada)
-- Jika belum ada, kita buat lokal di sini
local SharkLogic = {}
SharkLogic.defaultConfig = {
    targetName = "Moon Cat",
    tumbalNames = {"Dog"},
    slotCFrame = CFrame.new(-13.018989562988, 0, -74.922821044922, 1,0,0,0,1,0,0,0,1)
}

function SharkLogic.findTumbal(dataPetModule, tumbalNames, excludeUUIDs)
    excludeUUIDs = excludeUUIDs or {}
    for _, name in ipairs(tumbalNames) do
        local hasil = dataPetModule.findPets({
            exactName = name,
            isFavorite = false,
            minLevel = 100,
            excludeUUIDs = excludeUUIDs,
            limit = 1
        })
        if #hasil > 0 then
            local petInfo = hasil[1]
            if string.lower(name) == "cat" then
                local catResult = dataPetModule.findPets({
                    exactName = "Cat",
                    isFavorite = false,
                    minLevel = 100,
                    mutation = "Blossoming",
                    excludeUUIDs = excludeUUIDs,
                    limit = 1
                })
                if #catResult > 0 then
                    return catResult[1].pet, catResult[1].uuid
                else
                    return nil, nil
                end
            else
                return petInfo.pet, petInfo.uuid
            end
        end
    end
    return nil, nil
end

function SharkLogic.findTarget(dataPetModule, targetName, excludeUUIDs)
    excludeUUIDs = excludeUUIDs or {}
    local hasil = dataPetModule.findPets({
        exactName = targetName,
        isFavorite = false,
        excludeUUIDs = excludeUUIDs,
        limit = 1
    })
    if #hasil > 0 then
        local petInfo = hasil[1]
        if petInfo.mutation ~= "Blossoming" then
            return petInfo.pet, petInfo.uuid
        end
    end
    return nil, nil
end

-- 4. State
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

-- 5. Event Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local PetCooldownsEvent = GameEvents:WaitForChild("PetCooldownsUpdated")
local PetsService = GameEvents:WaitForChild("PetsService")
local NotificationEvent = GameEvents:WaitForChild("Notification")

-- 6. Fungsi Equip/Unequip
local function equipPet(uuid, cframe)
    if not uuid then return end
    PetsService:FireServer("EquipPet", uuid, cframe)
end

local function unequipPet(uuid)
    if not uuid then return end
    PetsService:FireServer("UnequipPet", uuid)
end

-- 7. Logika Utama
local function unequipTargetAndEquipShark()
    if state.currentTargetUUID then
        unequipPet(state.currentTargetUUID)
        state.currentTargetUUID = nil
    end
    if state.currentTumbalUUID then
        unequipPet(state.currentTumbalUUID)
        state.currentTumbalUUID = nil
    end
    if state.selectedSharkUUID then
        equipPet(state.selectedSharkUUID, SharkLogic.defaultConfig.slotCFrame)
    end
    state.isProcessing = false
    print("🔄 Shark dikembalikan, target & tumbal diunequip")
end

local function unequipSharkAndEquipTumbalTarget()
    if not state.selectedSharkUUID then
        print("⚠️ Shark UUID tidak ada")
        return
    end

    local tumbalPet, tumbalUUID = SharkLogic.findTumbal(DataPetModule, state.tumbalNames, {state.selectedMimicUUID, state.selectedSharkUUID})
    local targetPet, targetUUID = SharkLogic.findTarget(DataPetModule, state.targetName, {state.selectedMimicUUID, state.selectedSharkUUID})

    if tumbalUUID and targetUUID then
        unequipPet(state.selectedSharkUUID)
        equipPet(tumbalUUID, SharkLogic.defaultConfig.slotCFrame)
        state.currentTumbalUUID = tumbalUUID
        equipPet(targetUUID, SharkLogic.defaultConfig.slotCFrame)
        state.currentTargetUUID = targetUUID
        state.isProcessing = true
        print("✅ Equip tumbal & target")
    else
        print("⚠️ Tumbal atau target tidak ditemukan")
        equipPet(state.selectedSharkUUID, SharkLogic.defaultConfig.slotCFrame)
        state.isProcessing = false
    end
end

-- 8. Event Listeners
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

-- 9. UI dengan Rayfield
local Window = Rayfield:CreateWindow({
    Name = "Auto Shark",
    LoadingTitle = "Memuat Auto Shark...",
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

-- Tab Utama
local MainTab = Window:CreateTab("Control")

-- Dropdown untuk memilih Mimic (dari daftar semua pet)
local function refreshMimicList()
    local allPets = DataPetModule.getAllPets()
    local options = {}
    for uuid, pet in pairs(allPets) do
        local pType = pet.PetType or pet.PetData and pet.PetData.PetType or pet.PetData and pet.PetData.Name or "Unknown"
        local mutation = DataPetModule.getAutoMutationName(pet.PetData and pet.PetData.MutationType or "Normal")
        local text = string.format("%s | %s (UUID: %s)", mutation, pType, uuid)
        table.insert(options, text)
    end
    return options
end

local MimicDropdown = MainTab:CreateDropdown({
    Name = "Pilih Pet Mimic",
    Options = refreshMimicList(),
    CurrentOption = "",
    Callback = function(Option)
        -- Extract UUID dari option (format: "Mutasi | Nama (UUID: ...)")
        local uuid = string.match(Option, "UUID: ([^%)]+)")
        if uuid then
            state.selectedMimicUUID = uuid
            print("✅ Mimic dipilih:", uuid)
        end
    end
})

-- Tombol refresh daftar mimic
MainTab:CreateButton({
    Name = "Refresh Daftar Mimic",
    Callback = function()
        MimicDropdown:SetOptions(refreshMimicList())
    end
})

-- Dropdown untuk memilih Shark (dari daftar semua pet)
local function refreshSharkList()
    local allPets = DataPetModule.getAllPets()
    local options = {}
    for uuid, pet in pairs(allPets) do
        local pType = pet.PetType or pet.PetData and pet.PetData.PetType or pet.PetData and pet.PetData.Name or "Unknown"
        local mutation = DataPetModule.getAutoMutationName(pet.PetData and pet.PetData.MutationType or "Normal")
        local text = string.format("%s | %s (UUID: %s)", mutation, pType, uuid)
        table.insert(options, text)
    end
    return options
end

local SharkDropdown = MainTab:CreateDropdown({
    Name = "Pilih Pet Shark",
    Options = refreshSharkList(),
    CurrentOption = "",
    Callback = function(Option)
        local uuid = string.match(Option, "UUID: ([^%)]+)")
        if uuid then
            state.selectedSharkUUID = uuid
            print("✅ Shark dipilih:", uuid)
        end
    end
})

MainTab:CreateButton({
    Name = "Refresh Daftar Shark",
    Callback = function()
        SharkDropdown:SetOptions(refreshSharkList())
    end
})

-- Input untuk target
local TargetInput = MainTab:CreateInput({
    Name = "Target Pet (satu nama)",
    PlaceholderText = "Moon Cat",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        state.targetName = Text
        print("✅ Target diubah:", Text)
    end
})

-- Input untuk tumbal (bisa banyak, pisahkan dengan koma)
local TumbalInput = MainTab:CreateInput({
    Name = "Tumbal (pisahkan dengan koma)",
    PlaceholderText = "Dog, Cat, Golden Lab",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        local names = {}
        for token in string.gmatch(Text, "[^,]+") do
            local trimmed = token:gsub("^%s*(.-)%s*$", "%1")
            if trimmed ~= "" then
                table.insert(names, trimmed)
            end
        end
        state.tumbalNames = names
        print("✅ Tumbal diubah:", table.concat(names, ", "))
    end
})

-- Tombol Start / Stop
MainTab:CreateButton({
    Name = "Start Script",
    Callback = function()
        if not state.selectedMimicUUID then
            print("⚠️ Pilih Mimic terlebih dahulu")
            return
        end
        if not state.selectedSharkUUID then
            print("⚠️ Pilih Shark terlebih dahulu")
            return
        end
        state.isActive = true
        equipPet(state.selectedMimicUUID, SharkLogic.defaultConfig.slotCFrame)
        equipPet(state.selectedSharkUUID, SharkLogic.defaultConfig.slotCFrame)
        print("▶️ Script dimulai")
    end
})

MainTab:CreateButton({
    Name = "Stop Script",
    Callback = function()
        state.isActive = false
        -- Unequip semua
        local equipped = DataPetModule.getEquippedPets()
        for _, uuid in ipairs(equipped) do
            unequipPet(uuid)
        end
        state.isProcessing = false
        print("⏹ Script dihentikan")
    end
})

-- Tab Favorit
local FavTab = Window:CreateTab("Team Favorit")

-- List favorit (gunakan CreateList jika tersedia, fallback ke CreateParagraph)
local FavoriteList
local DetailLabel
if Rayfield:FindFirstChild("CreateList") then
    FavoriteList = FavTab:CreateList({
        Name = "Daftar Pet Favorit",
        Options = {"Memuat data..."},
        Callback = function(Option)
            if DataPetModule then
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
    DetailLabel = FavTab:CreateLabel("Klik salah satu pet untuk melihat detail")
else
    -- Fallback: gunakan Paragraph
    local function updateFavoriteList()
        local hasil = DataPetModule.findPets({ isFavorite = true })
        local content = ""
        for i, pet in ipairs(hasil) do
            content = content .. string.format("%d. %s %s %.2f KG Lv.%d\n",
                i, pet.mutation, pet.name, pet.weight or 0, pet.level)
        end
        if content == "" then
            content = "Tidak ada pet favorit"
        end
        FavoriteParagraph:Set({
            Title = "Daftar Pet Favorit",
            Content = content
        })
    end
    local FavoriteParagraph = FavTab:CreateParagraph({
        Title = "Daftar Pet Favorit",
        Content = "Memuat data..."
    })
    DetailLabel = FavTab:CreateLabel("Detail: -")
    FavTab:CreateButton({
        Name = "Refresh Favorit",
        Callback = updateFavoriteList
    })
    updateFavoriteList()
end

-- Refresh Favorit (tombol)
FavTab:CreateButton({
    Name = "Refresh Daftar Favorit",
    Callback = function()
        if FavoriteList then
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
            FavoriteList:SetOptions(options)
            if #hasil > 0 then
                local first = hasil[1]
                DetailLabel:Set(string.format("Nama: %s\nMutasi: %s\nLevel: %d\nBerat: %.2f KG",
                    first.name, first.mutation, first.level, first.weight or 0))
            else
                DetailLabel:Set("Tidak ada pet favorit")
            end
        end
    end
})

-- Inisialisasi favorit pertama kali
task.wait(0.5)
if FavoriteList then
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
    FavoriteList:SetOptions(options)
    if #hasil > 0 then
        local first = hasil[1]
        DetailLabel:Set(string.format("Nama: %s\nMutasi: %s\nLevel: %d\nBerat: %.2f KG",
            first.name, first.mutation, first.level, first.weight or 0))
    else
        DetailLabel:Set("Tidak ada pet favorit")
    end
end

print("✅ Auto Shark UI siap. Tekan K untuk membuka.")

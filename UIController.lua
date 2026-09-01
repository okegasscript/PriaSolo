-- UIController.lua
-- Menerima DataPetModule dan SharkLogic sebagai parameter
return function(DataPetModule, SharkLogic)
    local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

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

    local MainTab = Window:CreateTab("Kontrol")

    local UIState = {
        selectedMimicUUID = nil,
        selectedSharkUUID = nil,
        tumbalNames = {"Dog"},
        targetName = "Moon Cat",
        isActive = false
    }

    local callbacks = {}

    function UIState.onUpdate(callback)
        table.insert(callbacks, callback)
    end

    local function notifyUpdate()
        for _, cb in ipairs(callbacks) do
            pcall(cb, UIState)
        end
    end

    -- 1. Dropdown untuk memilih Mimic (diganti dari CreateList -> CreateDropdown)
    local MimicList = MainTab:CreateDropdown({
        Name = "Pilih Mimic (Mimic Octopus)",
        Options = {"Memuat data..."},
        CurrentOption = {"Memuat data..."},
        MultipleOptions = false, -- single select, sesuai logic aslinya
        Callback = function(option)
            -- Rayfield CreateDropdown mengirim STRING kalau MultipleOptions = false
            local hasil = DataPetModule.findPets({ type = "Mimic Octopus" })
            for _, pet in ipairs(hasil) do
                local text = string.format("%s %s %.2f KG Lv.%d",
                    pet.mutation, pet.name, pet.weight or 0, pet.level)
                if text == option then
                    UIState.selectedMimicUUID = pet.uuid
                    notifyUpdate()
                    break
                end
            end
        end
    })

    -- 2. Dropdown untuk memilih Shark (diganti dari CreateList -> CreateDropdown)
    local SharkList = MainTab:CreateDropdown({
        Name = "Pilih Shark",
        Options = {"Memuat data..."},
        CurrentOption = {"Memuat data..."},
        MultipleOptions = false,
        Callback = function(option)
            local hasil = DataPetModule.findPets({ name = "Shark" })
            for _, pet in ipairs(hasil) do
                local text = string.format("%s %s %.2f KG Lv.%d",
                    pet.mutation, pet.name, pet.weight or 0, pet.level)
                if text == option then
                    UIState.selectedSharkUUID = pet.uuid
                    notifyUpdate()
                    break
                end
            end
        end
    })

    local function refreshMimicList()
        local hasil = DataPetModule.findPets({ type = "Mimic Octopus" })
        local options = {}
        for _, pet in ipairs(hasil) do
            local text = string.format("%s %s %.2f KG Lv.%d",
                pet.mutation, pet.name, pet.weight or 0, pet.level)
            table.insert(options, text)
        end
        if #options == 0 then
            options = {"❌ Tidak ada Mimic Octopus"}
        end
        MimicList:Refresh(options) -- Rayfield lama pakai :Refresh(), bukan :SetOptions()
    end

    local function refreshSharkList()
        local hasil = DataPetModule.findPets({ name = "Shark" })
        local options = {}
        for _, pet in ipairs(hasil) do
            local text = string.format("%s %s %.2f KG Lv.%d",
                pet.mutation, pet.name, pet.weight or 0, pet.level)
            table.insert(options, text)
        end
        if #options == 0 then
            options = {"❌ Tidak ada Shark"}
        end
        SharkList:Refresh(options)
    end

    local TumbalInput = MainTab:CreateInput({
        Name = "Tumbal (pisahkan dengan koma)",
        PlaceholderText = "Cat, Dog, Golden Lab",
        RemoveTextAfterFocusLost = false,
        Callback = function(text)
            local names = {}
            for token in string.gmatch(text, "[^,]+") do
                local trimmed = token:match("^%s*(.-)%s*$")
                if trimmed ~= "" then
                    table.insert(names, trimmed)
                end
            end
            if #names > 0 then
                UIState.tumbalNames = names
                notifyUpdate()
            end
        end
    })

    local TargetInput = MainTab:CreateInput({
        Name = "Target",
        PlaceholderText = "Moon Cat",
        RemoveTextAfterFocusLost = false,
        Callback = function(text)
            local trimmed = text:match("^%s*(.-)%s*$")
            if trimmed ~= "" then
                UIState.targetName = trimmed
                notifyUpdate()
            end
        end
    })

    local StartButton = MainTab:CreateButton({
        Name = "Start",
        Callback = function()
            if UIState.isActive then
                UIState.isActive = false
                StartButton:Set("Start")
                notifyUpdate()
            else
                if not UIState.selectedMimicUUID then
                    print("⚠️ Pilih Mimic dulu!")
                    return
                end
                if not UIState.selectedSharkUUID then
                    print("⚠️ Pilih Shark dulu!")
                    return
                end
                UIState.isActive = true
                StartButton:Set("Stop")
                notifyUpdate()
            end
        end
    })

    MainTab:CreateButton({
        Name = "Refresh Daftar Pet",
        Callback = function()
            refreshMimicList()
            refreshSharkList()
        end
    })

    local StatusLabel = MainTab:CreateLabel("Status: Siap")

    function UIState.updateStatus(text)
        StatusLabel:Set(text)
    end

    refreshMimicList()
    refreshSharkList()

    return UIState
end

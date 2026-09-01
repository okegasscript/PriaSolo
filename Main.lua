-- ============================================================
-- STATE (tambahkan target queue)
-- ============================================================

local state = {
    isActive = false,
    isProcessing = false,
    selectedMimicUUID = nil,
    selectedSharkUUID = nil,
    targetQueue = {},          -- daftar UUID target yang dipilih
    targetIndex = 1,           -- indeks target saat ini
    tumbalNames = {"Dog"},
    minLevel = 100,
    currentTumbalUUID = nil,
    currentTargetUUID = nil,
    cycleCount = 0,
    lastActionTime = 0
}

-- ============================================================
-- DROPDOWN TARGET (Multiple Select)
-- ============================================================

local targetLabelToUUID = {}
local TargetDropdown = MainTab:CreateDropdown({
    Name = "Pilih Target (Non-Fav, Normal) - Multiple",
    Options = {"Memuat data..."},
    CurrentOption = "Memuat data...",
    MultipleOptions = true,   -- <-- true agar bisa pilih banyak
    Callback = function(selectedOptions)
        -- selectedOptions adalah table berisi label-label yang dipilih
        if type(selectedOptions) == "table" then
            local uuids = {}
            for _, label in ipairs(selectedOptions) do
                local uuid = targetLabelToUUID[label]
                if uuid then
                    table.insert(uuids, uuid)
                end
            end
            if #uuids > 0 then
                state.targetQueue = uuids
                state.targetIndex = 1
                print("✅ Target queue diupdate:", #uuids, "target")
                updateStatusLabel()
            else
                warn("⚠️ Tidak ada UUID valid yang dipilih")
            end
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

-- ============================================================
-- FUNGSI unequipSharkAndEquipTumbalTarget (ambil target dari queue)
-- ============================================================

local function unequipSharkAndEquipTumbalTarget()
    if not state.selectedSharkUUID then return end
    if #state.targetQueue == 0 then
        print("⚠️ Tidak ada target dalam queue!")
        return
    end

    -- Ambil target berdasarkan indeks saat ini
    local targetUUID = state.targetQueue[state.targetIndex]
    if not targetUUID then
        -- reset ke awal jika indeks melewati batas
        state.targetIndex = 1
        targetUUID = state.targetQueue[1]
        if not targetUUID then
            print("⚠️ Target queue kosong!")
            return
        end
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
        print("✅ Equip tumbal & target (", state.targetIndex, "/", #state.targetQueue, ")")
    else
        print("⚠️ Tumbal atau target tidak ditemukan")
        SharkLogic.equipPet(PetsService, state.selectedSharkUUID, SharkLogic.defaultConfig.slotCFrame)
        state.isProcessing = false
    end
end

-- ============================================================
-- NOTIFIKASI: saat berhasil/gagal, pindah ke target berikutnya
-- ============================================================

NotificationEvent.OnClientEvent:Connect(function(message)
    if not state.isActive or not state.isProcessing then return end
    if type(message) == "string" and string.find(message, "Mimic Octopus") then
        if string.find(message, "spat its Blossoming mutation onto") or string.find(message, "mutation failed to transfer") then
            -- Pindah ke target berikutnya di queue
            state.targetIndex = state.targetIndex + 1
            if state.targetIndex > #state.targetQueue then
                state.targetIndex = 1  -- reset ke awal jika sudah habis
                print("🔄 Semua target selesai, reset ke awal")
            else
                print("🔄 Lanjut ke target berikutnya:", state.targetIndex)
            end
            unequipTargetAndEquipShark()
        end
    end
end)

-- ============================================================
-- UPDATE STATUS LABEL (tampilkan jumlah target)
-- ============================================================

local function updateStatusLabel()
    local mimicText = state.selectedMimicUUID and tostring(state.selectedMimicUUID) or "(belum)"
    local sharkText = state.selectedSharkUUID and tostring(state.selectedSharkUUID) or "(belum)"
    local targetCount = #state.targetQueue
    local targetText = targetCount > 0 and (targetCount .. " target") or "(belum)"
    StatusLabel:Set("Mimic: " .. mimicText .. " | Shark: " .. sharkText .. " | Target: " .. targetText)
end

-- ============================================================
-- STOP: reset queue
-- ============================================================

-- Di bagian StartToggle callback, tambahkan reset queue saat stop:
if not Value then
    state.isActive = false
    state.targetIndex = 1
    -- ... sisanya sama
end

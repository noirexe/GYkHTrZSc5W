local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Create the main window once
local Window = Rayfield:CreateWindow({
    Name = "Mt.Yahayuk Teleport System",
    LoadingTitle = "Teleport System Sedang Dimuat",
    LoadingSubtitle = "by Noire",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "XuKrost",
        FileName = "Config"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvitelink",
        RememberJoins = true
    },
    KeySystem = false, -- Disable key system
})

Rayfield:Notify({
    Title = "✅ Teleport System Dimuat",
    Content = "Script berhasil dimuat. Selamat mencoba!",
    Duration = 6.5,
    Image = 4483362458,
    Actions = {
        Ignore = {
            Name = "Oke",
            Callback = function()
                print("Pengguna mengkonfirmasi notifikasi")
            end
        },
    },
})

-- Services
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")

-- Player reference
local LocalPlayer = Players.LocalPlayer

-- Locations table with Vector3 instead of CFrame
local Locations = {
    ["Spawn"] = Vector3.new(-958, 170, 875),
    ["CheckPoint 1"] = Vector3.new(-471, 249, 776),
    ["CheckPoint 2"] = Vector3.new(-361, 388, 575),
    ["CheckPoint 3"] = Vector3.new(259, 430, 507),
    ["CheckPoint 4"] = Vector3.new(333, 490, 357),
    ["CheckPoint 5"] = Vector3.new(237, 318, -145),
    ["Puncak"] = Vector3.new(-611, 907, -537),
}

-- Variables for auto teleport control
local AutoTeleporting = false
local LoopMode = false
local CurrentTeleportIndex = 1

-- Variables for admin detection
local AdminDetectionEnabled = false
local AdminCheckRunning = false
local AdminList = {
    "kigenteji",
    "gynessey",
    "xSUNSHINE42",
    "FLIXXXOP",
    "NotHuman1149",
    "VRL_BebaStar",
    "nevada233445",
    "GAV1NSKIE"
}

-- Variables for Anti-AFK
local AntiAFKEnabled = false
local AntiAFKConnection = nil

-- Teleport order for auto teleport
local TeleportOrder = {
    "CheckPoint 1", 
    "CheckPoint 2", 
    "CheckPoint 3", 
    "CheckPoint 4", 
    "CheckPoint 5", 
    "Puncak"
}

-- Notification cooldown system
local lastNotificationTime = 0
local NOTIFICATION_COOLDOWN = 3 -- seconds between notifications

-- UI Theme Colors
local ThemeColors = {
    Primary = Color3.fromRGB(0, 170, 255),
    Secondary = Color3.fromRGB(85, 170, 255),
    Success = Color3.fromRGB(50, 215, 75),
    Warning = Color3.fromRGB(255, 185, 50),
    Danger = Color3.fromRGB(255, 75, 75),
    Dark = Color3.fromRGB(40, 40, 40),
    Light = Color3.fromRGB(245, 245, 245)
}

-- Function to show notifications with cooldown
local function ShowNotification(title, content, duration, image)
    local currentTime = tick()
    if currentTime - lastNotificationTime >= NOTIFICATION_COOLDOWN then
        lastNotificationTime = currentTime
        Rayfield:Notify({
            Title = title,
            Content = content,
            Duration = duration or 3,
            Image = image or 4483362458,
        })
        return true
    end
    return false
end

-- Function to safely get the player's character
local function GetCharacter()
    local character = LocalPlayer.Character
    if not character then
        LocalPlayer.CharacterAdded:Wait()
        character = LocalPlayer.Character
    end
    return character
end

-- Function to safely get the player's humanoid root part
local function GetHumanoidRootPart(character)
    character = character or GetCharacter()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
    return humanoidRootPart
end

-- Function to check if any admin is in the server
local function CheckForAdmins()
    for _, player in ipairs(Players:GetPlayers()) do
        for _, adminName in ipairs(AdminList) do
            if player.Name:lower() == adminName:lower() or player.DisplayName:lower() == adminName:lower() then
                return true, player.Name
            end
        end
    end
    return false, nil
end

-- Function to join a new server with better error handling
local function JoinNewServer()
    local placeId = game.PlaceId
    local currentJobId = game.JobId
    
    ShowNotification("Mencari Server Baru", "Sedang mencari server yang tersedia...", 3)
    
    local success, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
        ))
    end)
    
    if success and result and result.data then
        local availableServers = {}
        for _, server in ipairs(result.data) do
            if server.playing < server.maxPlayers and server.id ~= currentJobId then
                table.insert(availableServers, server.id)
            end
        end
        
        if #availableServers > 0 then
            local randomServer = availableServers[math.random(1, #availableServers)]
            TeleportService:TeleportToPlaceInstance(placeId, randomServer)
        else
            TeleportService:Teleport(placeId)
        end
    else
        TeleportService:Teleport(placeId)
    end
end

-- Function to kill player with safety checks
local function KillPlayer()
    local character = GetCharacter()
    if character then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.Health = 0
            return true
        end
    end
    return false
end

-- Function for teleportation with improved error handling
local function TeleportTo(locationName)
    local location = Locations[locationName]
    if not location then
        ShowNotification("Error", "Lokasi tidak ditemukan: " .. tostring(locationName), 3)
        return false
    end
    
    local character = GetCharacter()
    local humanoidRootPart = GetHumanoidRootPart(character)
    
    if humanoidRootPart then
        -- Directly set the position using Vector3
        humanoidRootPart.CFrame = CFrame.new(location)
        
        ShowNotification("Teleport Berhasil", "Kamu telah di-teleport ke " .. locationName, 3)
        return true
    else
        ShowNotification("Error", "HumanoidRootPart tidak ditemukan!", 3)
        return false
    end
end

-- Function for auto teleport with delay and improved logic
local function StartAutoTeleport(loop)
    if AutoTeleporting then 
        ShowNotification("Info", "Auto teleport sudah berjalan", 3)
        return 
    end
    
    AutoTeleporting = true
    LoopMode = loop or false
    CurrentTeleportIndex = 1
    
    -- Process teleport in sequence with delay
    local teleportCoroutine = coroutine.create(function()
        repeat
            for i = CurrentTeleportIndex, #TeleportOrder do
                if not AutoTeleporting then break end
                
                local locationName = TeleportOrder[i]
                local success = TeleportTo(locationName)
                
                if not success then
                    AutoTeleporting = false
                    break
                end
                
                -- Show progress notification (only if not on cooldown)
                if ShowNotification(LoopMode and "Auto Teleport (Looping)" or "Auto Teleport", 
                                   "Menuju " .. locationName .. " (" .. i .. "/" .. #TeleportOrder .. ")", 3) then
                    -- If notification was shown, add a small delay
                    wait(0.5)
                end
                
                -- Determine wait duration based on location
                local waitTime = locationName == "Puncak" and 6 or 3
                
                if locationName == "Puncak" then
                    ShowNotification("⛰️ Summit Terhitung!", "Tunggu 6 detik di puncak untuk menyelesaikan tantangan", 6)
                end
                
                -- Wait with the ability to cancel
                local startTime = tick()
                while tick() - startTime < waitTime and AutoTeleporting do
                    if locationName == "Puncak" and tick() - startTime > waitTime - 3 then
                        local remaining = math.ceil(waitTime - (tick() - startTime))
                        -- Don't show notification for countdown to avoid spam
                    end
                    RunService.Heartbeat:Wait()
                end
                
                -- Kill player after waiting at the peak (only in loop mode)
                if LoopMode and locationName == "Puncak" and AutoTeleporting then
                    ShowNotification("⛰️ Selesai di Puncak", "Membunuh player untuk memulai ulang dari Spawn...", 3)
                    
                    -- Kill the player
                    if KillPlayer() then
                        -- Wait for respawn
                        LocalPlayer.CharacterAdded:Wait()
                        RunService.Heartbeat:Wait() -- Wait one frame
                        
                        -- Teleport to Spawn after respawn
                        TeleportTo("Spawn")
                        
                        -- Set next index to CheckPoint 1
                        for idx, name in ipairs(TeleportOrder) do
                            if name == "CheckPoint 1" then
                                CurrentTeleportIndex = idx
                                break
                            end
                        end
                        break -- Break out of the for loop to restart from CheckPoint 1
                    end
                end
                
                CurrentTeleportIndex = i + 1
            end
            
            if AutoTeleporting and LoopMode and CurrentTeleportIndex > #TeleportOrder then
                CurrentTeleportIndex = 1  -- Reset to start if we've completed the loop
                ShowNotification("Auto Teleport Looping", "Memulai rute teleport lagi dari awal...", 3)
            end
        until not LoopMode or not AutoTeleporting
        
        AutoTeleporting = false
        ShowNotification("Auto Teleport Selesai", LoopMode and "Proses auto teleport telah dihentikan" or "Semua lokasi telah dikunjungi", 5)
    end)
    
    coroutine.resume(teleportCoroutine)
end

-- Function to stop auto teleport
local function StopAutoTeleport()
    if AutoTeleporting then
        AutoTeleporting = false
        LoopMode = false
        ShowNotification("Auto Teleport Dihentikan", "Proses auto teleport telah dihentikan", 3)
    end
end

-- Function to toggle admin detection
local function ToggleAdminDetection(value)
    AdminDetectionEnabled = value
    
    if AdminDetectionEnabled and not AdminCheckRunning then
        AdminCheckRunning = true
        ShowNotification("Admin Detection Diaktifkan", "Sistem akan otomatis pindah server jika ada admin terdeteksi", 5)
        
        -- Start checking for admins in a separate coroutine
        coroutine.wrap(function()
            while AdminDetectionEnabled do
                wait(10) -- Check every 10 seconds
                
                if AdminDetectionEnabled then
                    local adminFound, adminName = CheckForAdmins()
                    if adminFound then
                        ShowNotification("⚠️ Admin Terdeteksi!", adminName .. " terdeteksi di server. Pindah ke server baru...", 5)
                        
                        -- Stop auto teleport if running
                        if AutoTeleporting then
                            StopAutoTeleport()
                        end
                        
                        wait(2) -- Brief delay before switching servers
                        JoinNewServer()
                        break -- Break the loop since we're changing servers
                    end
                end
            end
            AdminCheckRunning = false
        end)()
    else
        AdminDetectionEnabled = false
        ShowNotification("Admin Detection Dimatikan", "Sistem tidak akan lagi mendeteksi admin", 3)
    end
end

-- Function to toggle Anti-AFK
local function ToggleAntiAFK(value)
    AntiAFKEnabled = value
    
    if AntiAFKEnabled then
        -- Disconnect previous connection if it exists
        if AntiAFKConnection then
            AntiAFKConnection:Disconnect()
            AntiAFKConnection = nil
        end
        
        -- Connect to the Idled event
        AntiAFKConnection = LocalPlayer.Idled:Connect(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
        
        ShowNotification("Anti-AFK Diaktifkan", "Kamu tidak akan lagi dikick karena AFK", 3)
    else
        -- Disconnect the connection
        if AntiAFKConnection then
            AntiAFKConnection:Disconnect()
            AntiAFKConnection = nil
        end
        
        ShowNotification("Anti-AFK Dimatikan", "Kamu bisa dikick karena AFK", 3)
    end
end

-- Create information tab
local InfoTab = Window:CreateTab("Informasi", 7733960981)

-- Create information section
local InfoSection = InfoTab:CreateSection("Cara Penggunaan")
InfoTab:CreateParagraph({
    Title = "Wajib Dibaca",
    Content = "1. Pastikan karakter sudah spawn sebelum menggunakan teleport\n2. Gunakan fitur (AutoTeleport 1x) terlebih dahulu agar summit bisa terhitung\n3. Tunggu notifikasi teleport berhasil\n4. Jika terjadi error, coba reset karakter terlebih dahulu\n5. Jika sudah silahkan untuk mencoba fitur (AutoTeleport Looping)"
})

local UpdateSection = InfoTab:CreateSection("Update & Fix")
InfoTab:CreateParagraph({
    Title = "Update & Fix",
    Content = "Update: \n- AutoTeleport Looping\n- Admin Detection System\n- Anti-AFK System\n\nFix: \n- Summit tidak terhitung ketika menggunakan AutoTeleport Looping"
})

local WarningSection = InfoTab:CreateSection("⚠️ Perhatian")
InfoTab:CreateParagraph({
    Title = "Waktu Terbaik",
    Content = "• Push summit lebih baik dijam-jam tertentu (07:00PM - 10:00PM) atau (12:30AM - 05:00AM)\n• Lebih baik menggunakan Private Server jika ada\n• Jika tidak mempunyai Private Server cari server yang lumayan sepi"
})

-- Create main tab
local MainTab = Window:CreateTab("Teleport", 4483362458)

-- Create section for teleport
local TeleportSection = MainTab:CreateSection("Teleport Manual")
MainTab:CreateButton({
    Name = "🚩 Spawn",
    Callback = function()
        TeleportTo("Spawn")
    end
})

for i = 1, 5 do
    local checkpointName = "CheckPoint " .. i
    MainTab:CreateButton({
        Name = "📍 " .. checkpointName,
        Callback = function()
            TeleportTo(checkpointName)
        end
    })
end

MainTab:CreateButton({
    Name = "🏔️ Puncak",
    Callback = function()
        TeleportTo("Puncak")
    end
})

-- Auto Teleport section
local AutoSection = MainTab:CreateSection("Auto Teleport")
MainTab:CreateButton({
    Name = "▶️ Mulai Auto Teleport (Sekali)",
    Callback = function()
        StartAutoTeleport(false)
    end
})

MainTab:CreateButton({
    Name = "🔁 Mulai Auto Teleport (Looping)",
    Callback = function()
        StartAutoTeleport(true)
    end
})

MainTab:CreateButton({
    Name = "⏹️ Hentikan Auto Teleport",
    Callback = function()
        StopAutoTeleport()
    end
})

-- Settings tab
local SettingsTab = Window:CreateTab("Pengaturan", 9753762463)

SettingsTab:CreateSection("Konfigurasi UI")
local Toggle = SettingsTab:CreateToggle({
    Name = "UI Toggle Bind",
    CurrentValue = false,
    Flag = "UIToggle",
    Callback = function(Value)
        Rayfield:SetHotkey(Enum.KeyCode.RightShift)
    end,
})

-- Admin detection section
SettingsTab:CreateSection("Admin Detection")
SettingsTab:CreateToggle({
    Name = "Auto Leave Jika Ada Admin",
    CurrentValue = false,
    Flag = "AdminDetection",
    Callback = function(Value)
        ToggleAdminDetection(Value)
    end,
})

SettingsTab:CreateButton({
    Name = "Cek Admin di Server",
    Callback = function()
        local adminFound, adminName = CheckForAdmins()
        if adminFound then
            ShowNotification("⚠️ Admin Terdeteksi", adminName .. " ditemukan di server ini", 6)
        else
            ShowNotification("✅ Tidak Ada Admin", "Tidak ada admin yang terdeteksi di server ini", 3)
        end
    end,
})

SettingsTab:CreateButton({
    Name = "Pindah Server Sekarang",
    Callback = function()
        ShowNotification("Memindahkan Server", "Mencari server baru...", 3)
        JoinNewServer()
    end,
})

-- Anti-AFK section
SettingsTab:CreateSection("Anti-AFK")
SettingsTab:CreateToggle({
    Name = "Aktifkan Anti-AFK",
    CurrentValue = false,
    Flag = "AntiAFK",
    Callback = function(Value)
        ToggleAntiAFK(Value)
    end,
})

-- Add a section for debugging
SettingsTab:CreateSection("Debugging")
SettingsTab:CreateButton({
    Name = "Reset Karakter",
    Callback = function()
        if LocalPlayer.Character then
            LocalPlayer.Character:BreakJoints()
            ShowNotification("Karakter Direset", "Karakter telah direset", 3)
        else
            ShowNotification("Error", "Tidak ada karakter yang bisa direset", 3)
        end
    end,
})

-- Status section
local StatusSection = SettingsTab:CreateSection("📊 Status")
local ServerInfoLabel = SettingsTab:CreateLabel("Server ID: " .. game.JobId)
local PlayerCountLabel = SettingsTab:CreateLabel("Jumlah Pemain: " .. #Players:GetPlayers())

-- Function to update status
local function UpdateStatus()
    ServerInfoLabel:Set("Server ID: " .. game.JobId)
    PlayerCountLabel:Set("Jumlah Pemain: " .. #Players:GetPlayers())
end

-- Update status periodically
coroutine.wrap(function()
    while true do
        wait(10)
        UpdateStatus()
    end
end)()

Rayfield:LoadConfiguration()

-- Initial status update
UpdateStatus()
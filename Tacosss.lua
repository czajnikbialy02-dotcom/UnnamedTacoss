local Players = game:GetService('Players')
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild('PlayerGui')
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local api = getfenv().api or {}

-- ======== TACO CONFIG ========
local TACO_SHOP_NAME = '[Taco] - $2'
local TACO_TOOL_NAME = '[Taco]'
local DEFAULT_HP_THRESHOLD = 87
local TACO_COST = 2

-- ======== STATES ========
local autoTacoEnabled = true
local hpThreshold = DEFAULT_HP_THRESHOLD
local isTacoRunning = false
local isAlive = true
local monitorTask = nil -- referencja do pętli
local spinBotEnabled = false
local spinSpeed = 25
local spinBotConnection = nil

-- ======== HELPERS ========
local function FindObject(parent, name, timeout)
    timeout = timeout or 3
    local startTime = os.clock()
    repeat
        local obj = parent:FindFirstChild(name)
        if obj then return obj end
        task.wait(0.1)
    until os.clock() - startTime > timeout
    return nil
end

local function GetCurrentMoney()
    local gui = PlayerGui:FindFirstChild('MainScreenGui')
    local moneyText = gui and FindObject(gui, 'MoneyText', 1)
    if not moneyText or not moneyText:IsA('TextLabel') then return 0 end
    local num = string.gsub(moneyText.Text, '[^%d]', '')
    return tonumber(num) or 0
end

-- ======== TELEPORT FUNCTION ========
function api:teleport(cframe: CFrame): nil
    -- teleports the localplayer or current vehicle to the cframe that you passed in
    -- this should be used instead of manually teleporting, this method yields.
    
    local char = LocalPlayer.Character
    if not char then return end
    
    local root = FindObject(char, "HumanoidRootPart", 2)
    if not root then return end
    
    -- Check if player is in a vehicle
    local vehicleSeat = FindObject(char, "Seat", 0.5)
    if vehicleSeat then
        -- Teleport vehicle
        local vehicle = vehicleSeat:FindFirstAncestorOfClass("Model")
        if vehicle then
            local vehiclePrimaryPart = vehicle.PrimaryPart
            if vehiclePrimaryPart then
                local offset = vehiclePrimaryPart.CFrame:ToObjectSpace(root.CFrame)
                vehiclePrimaryPart.CFrame = cframe * offset:Inverse()
                task.wait(0.1) -- Small yield to ensure physics updates
                return
            end
        end
    end
    
    -- Regular character teleport
    root.CFrame = cframe
    task.wait(0.1) -- Small yield to ensure physics updates
end

-- ======== CHECK & GET TACO ========
local function EnsureTaco()
    local char = LocalPlayer.Character
    if not char then return false end

    local tacoTool = FindObject(LocalPlayer.Backpack, TACO_TOOL_NAME, 0.1) 
                     or FindObject(char, TACO_TOOL_NAME, 0.1)
    if tacoTool then return true end -- już mam

    -- nie mam? teleportuj do sklepu
    local root = FindObject(char, "HumanoidRootPart", 2)
    local shop = FindObject(FindObject(workspace, "Ignored", 3), "Shop", 3)
    local tacoModel = shop and FindObject(shop, TACO_SHOP_NAME, 3)
    local click = tacoModel and FindObject(tacoModel, "ClickDetector", 2)
    if not root or not tacoModel or not click then
        warn("Taco shop not found!")
        return false
    end
    if GetCurrentMoney() < TACO_COST then
        warn("Not enough money for Taco!")
        return false
    end

    local originalCFrame = root.CFrame
    api:teleport(tacoModel:GetPivot() * CFrame.new(0,0,-2))
    task.wait(0.2)

    -- kup Taco
    pcall(fireclickdetector, click, 5)
    task.wait(0.2)
    api:teleport(originalCFrame)

    -- poczekaj aż tool będzie w Backpack/Character
    local startTime = os.clock()
    repeat
        tacoTool = FindObject(LocalPlayer.Backpack, TACO_TOOL_NAME, 0.1) 
                   or FindObject(char, TACO_TOOL_NAME, 0.1)
        if tacoTool then return true end
        task.wait(0.1)
    until os.clock() - startTime > 3

    return false
end

-- ======== AUTO TACO ========
local function AutoTaco()
    if not autoTacoEnabled or isTacoRunning or not isAlive then return end
    isTacoRunning = true

    local char = LocalPlayer.Character
    local hum = FindObject(char, 'Humanoid', 2)
    local root = FindObject(char, 'HumanoidRootPart', 2)
    if not (hum and root) then isTacoRunning = false return end

    -- sprawdź i kup Taco jeśli trzeba
    if not EnsureTaco() then
        isTacoRunning = false
        return
    end

    -- znajdź tool po zakupie
    local tacoTool = FindObject(LocalPlayer.Backpack, TACO_TOOL_NAME, 0.1) 
                     or FindObject(char, TACO_TOOL_NAME, 0.1)
    if tacoTool.Parent == LocalPlayer.Backpack then
        pcall(function() hum:EquipTool(tacoTool) end)
        task.wait(0.2)
    end

    -- klikaj tylko jeśli jest w ręce
    while tacoTool and tacoTool.Parent == char and autoTacoEnabled and isAlive do
        pcall(mouse1click)
        task.wait(0.07)
        -- odśwież referencję
        tacoTool = FindObject(LocalPlayer.Backpack, TACO_TOOL_NAME, 0.1) 
                   or FindObject(char, TACO_TOOL_NAME, 0.1)
    end

    isTacoRunning = false
end

-- ======== MONITOR ========
local function StartMonitor()
    if monitorTask then return end -- już działa
    monitorTask = task.spawn(function()
        while autoTacoEnabled do
            task.wait(0.2)
            if not isAlive then
                isTacoRunning = false
                continue
            end
            local char = LocalPlayer.Character
            if char then
                local hum = FindObject(char, 'Humanoid', 1)
                if hum and hum.Health < hpThreshold then
                    AutoTaco()
                end
            end
        end
        monitorTask = nil -- zakończone
    end)
end

local function StopMonitor()
    autoTacoEnabled = false
    if monitorTask then
        -- monitor zakończy się sam w następnym ticku
        monitorTask = nil
    end
end

-- ======== SPIN BOT ========
local function UpdateSpinBot()
    if not spinBotEnabled then return end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    -- Random rotation for weird effect
    local randomX = math.random(-180, 180)
    local randomY = math.random(-180, 180)
    local randomZ = math.random(-180, 180)
    
    -- Calculate rotation based on speed and random factors
    local deltaTime = RunService.Heartbeat:Wait()
    local rotation = CFrame.fromEulerAnglesXYZ(
        math.rad(randomX * spinSpeed * deltaTime),
        math.rad(randomY * spinSpeed * deltaTime),
        math.rad(randomZ * spinSpeed * deltaTime)
    )
    
    -- Apply rotation ignoring shift lock
    humanoidRootPart.CFrame = humanoidRootPart.CFrame * rotation
end

local function ToggleSpinBot(state)
    spinBotEnabled = state
    
    if spinBotEnabled then
        if spinBotConnection then
            spinBotConnection:Disconnect()
        end
        spinBotConnection = RunService.Heartbeat:Connect(UpdateSpinBot)
    else
        if spinBotConnection then
            spinBotConnection:Disconnect()
            spinBotConnection = nil
        end
    end
end

-- ======== RESPAWN HANDLING ========
LocalPlayer.CharacterAdded:Connect(function(character)
    isAlive = true
    character:WaitForChild('Humanoid').Died:Connect(function()
        isAlive = false
        isTacoRunning = false
    end)
    
    -- Re-enable spin bot if it was on
    if spinBotEnabled then
        ToggleSpinBot(true)
    end
end)

if LocalPlayer.Character then
    local hum = LocalPlayer.Character:FindFirstChild('Humanoid')
    if hum then
        isAlive = hum.Health > 0
        hum.Died:Connect(function()
            isAlive = false
            isTacoRunning = false
        end)
    end
end

-- ======== CUSTOM TACO SOUND ========
-- === CONFIG ===
local TACO_TOOL_NAME = "[Taco]"
local SOUND_ID = "rbxassetid://6832470734"

-- === STATE ===
local tacoSoundEnabled = true
local tacoSound = nil -- single persistent sound

-- === SOUND SETUP ===
local function SetupSound()
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head") or char
    if not root then return end

    if not tacoSound then
        tacoSound = Instance.new("Sound")
        tacoSound.SoundId = SOUND_ID
        tacoSound.Volume = 0.5 -- adjust volume here
        tacoSound.Name = "TacoEquipSound"
        tacoSound.Parent = root
    else
        tacoSound.Parent = root -- reattach sound on respawn
    end
end

-- === PLAY SOUND ===
local function PlayTacoSound()
    if tacoSoundEnabled and tacoSound then
        tacoSound:Stop() -- stop any old playback
        tacoSound:Play()
    end
end

-- === HOOK TOOL ===
local function hookTool(tool)
    if tool.Name ~= TACO_TOOL_NAME then return end
    print("[DEBUG] Hooked tool:", tool.Name)

    tool.Equipped:Connect(function()
        print("[DEBUG] Taco Equipped Detected")
        PlayTacoSound()
    end)
end

-- === HOOK CHARACTER ===
local function hookCharacter(char)
    print("[DEBUG] New character loaded")
    SetupSound()

    -- hook existing tools
    for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
        hookTool(tool)
    end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            hookTool(tool)
        end
    end

    -- hook future tools
    LocalPlayer.Backpack.ChildAdded:Connect(hookTool)
    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            hookTool(child)
        end
    end)
end

-- hook current character
if LocalPlayer.Character then
    hookCharacter(LocalPlayer.Character)
end

-- hook respawns
LocalPlayer.CharacterAdded:Connect(hookCharacter)

-- ======== UI ========
local tab = api:GetTab("Fun things!") or api:AddTab("Fun things!")

-- Left Groupbox with changelog and author
local leftGroupbox = tab:AddLeftGroupbox("Info")
leftGroupbox:AddLabel("Author: kolkol")
leftGroupbox:AddLabel("Changelog:")
leftGroupbox:AddLabel("- Added new teleport function")
leftGroupbox:AddLabel("- Added spin bot feature")
leftGroupbox:AddLabel("- Improved UI organization")
leftGroupbox:AddLabel("Report bugs to kolkol via PV")

-- Auto Taco Settings Groupbox
local groupbox = tab:AddRightGroupbox("Auto Taco Settings")
local toggle = groupbox:AddToggle("auto_taco", { 
    Text = "Auto Taco :D", 
    Default = false 
})

toggle:OnChanged(function(value)
    autoTacoEnabled = value
    if value then
        StartMonitor()
    else
        StopMonitor()
    end
end)

-- Taco Sound Toggle
local toggle = groupbox:AddToggle("taco_sound", { 
    Text = "Custom Taco Sound", 
    Default = false 
})

toggle:OnChanged(function(value)
    tacoSoundEnabled = value
end)

-- Spin Bot Groupbox
local spinGroupbox = tab:AddLeftGroupbox("Spin Bot")
local slider = spinGroupbox:AddSlider("spin_speed", {
    Text = "Spin Speed",
    Default = 25,
    Min = 1,
    Max = 50,
    Rounding = 0,
    Compact = false,
    Callback = function(value)
        spinSpeed = value
    end
})

local spinToggle = spinGroupbox:AddToggle("spin_bot", {
    Text = "Spin Bot but weird",
    Default = false,
    Callback = function(value)
        ToggleSpinBot(value)
    end
})

-- ======== START MONITOR ========
if autoTacoEnabled then
    StartMonitor()
end

print("===== AUTO TACO SYSTEM READY =====")
print("===== SPIN BOT SYSTEM READY =====")
print("===== CUSTOM TACO SOUND READY =====")

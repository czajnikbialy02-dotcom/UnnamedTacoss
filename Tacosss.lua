local Players = game:GetService('Players')
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild('PlayerGui')
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local api = getfenv().api or {}

-- ======== CONFIGURATION ========
local TACO_SHOP_NAME = '[Taco] - $2'
local TACO_TOOL_NAME = '[Taco]'
local DEFAULT_HP_THRESHOLD = 87
local TACO_COST = 2

-- ======== STATES ========
local autoTacoEnabled = true
local hpThreshold = DEFAULT_HP_THRESHOLD
local isTacoRunning = false
local isAlive = true
local monitorTask = nil
local spinBotEnabled = false
local spinSpeed = 25
local spinBotConnection = nil
local originalOrientation = nil

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

-- ======== IMPROVED TELEPORT FUNCTION ========
function api:teleport(cframe: CFrame): nil
    local char = LocalPlayer.Character
    if not char then return end
    
    local root = FindObject(char, "HumanoidRootPart", 2)
    if not root then return end
    
    -- Save current velocity to prevent flinging
    local currentVelocity = root.Velocity
    local currentRotVelocity = if root:FindFirstChild("RootAngularVelocity") then root.RootAngularVelocity.AngularVelocity else Vector3.new()
    
    -- Check if player is in a vehicle
    local vehicleSeat = FindObject(char, "Seat", 0.5)
    if vehicleSeat then
        local vehicle = vehicleSeat:FindFirstAncestorOfClass("Model")
        if vehicle then
            local vehiclePrimaryPart = vehicle.PrimaryPart
            if vehiclePrimaryPart then
                local offset = vehiclePrimaryPart.CFrame:ToObjectSpace(root.CFrame)
                vehiclePrimaryPart.CFrame = cframe * offset:Inverse()
                task.wait(0.1)
                return
            end
        end
    end
    
    -- Regular character teleport with velocity preservation
    root.CFrame = cframe
    root.Velocity = currentVelocity
    if root:FindFirstChild("RootAngularVelocity") then
        root.RootAngularVelocity.AngularVelocity = currentRotVelocity
    end
    
    task.wait(0.1)
end

-- ======== SMOOTH SPIN BOT ========
local function UpdateSpinBot()
    if not spinBotEnabled then return end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not humanoidRootPart then return end
    
    -- Save original orientation when first enabled
    if not originalOrientation then
        originalOrientation = humanoidRootPart.Orientation
    end
    
    -- Calculate smooth rotation
    local deltaTime = RunService.Heartbeat:Wait()
    local rotationAmount = spinSpeed * deltaTime * 10
    
    -- Apply rotation only to the Y axis (horizontal) for smooth spinning
    humanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.Angles(0, math.rad(rotationAmount), 0)
    
    -- Keep upright orientation to prevent flinging
    humanoidRootPart.Orientation = Vector3.new(
        originalOrientation.X,
        humanoidRootPart.Orientation.Y,
        originalOrientation.Z
    )
    
    -- Maintain humanoid state for proper movement
    humanoid.AutoRotate = false
end

local function ToggleSpinBot(state)
    spinBotEnabled = state
    
    if spinBotEnabled then
        -- Initialize spin bot
        local character = LocalPlayer.Character
        if character then
            local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            if humanoidRootPart then
                originalOrientation = humanoidRootPart.Orientation
            end
        end
        
        if spinBotConnection then
            spinBotConnection:Disconnect()
        end
        spinBotConnection = RunService.Heartbeat:Connect(UpdateSpinBot)
    else
        -- Clean up spin bot
        if spinBotConnection then
            spinBotConnection:Disconnect()
            spinBotConnection = nil
        end
        
        -- Reset character orientation
        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            if humanoid and humanoidRootPart then
                humanoid.AutoRotate = true
                if originalOrientation then
                    humanoidRootPart.Orientation = originalOrientation
                end
            end
        end
        originalOrientation = nil
    end
end

-- ======== AUTO TACO SYSTEM ========
local function EnsureTaco()
    local char = LocalPlayer.Character
    if not char then return false end

    local tacoTool = FindObject(LocalPlayer.Backpack, TACO_TOOL_NAME, 0.1) 
                     or FindObject(char, TACO_TOOL_NAME, 0.1)
    if tacoTool then return true end

    -- Teleport to taco shop using new teleport function
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

    -- Buy Taco
    pcall(fireclickdetector, click, 5)
    task.wait(0.2)
    api:teleport(originalCFrame)

    -- Wait for tool
    local startTime = os.clock()
    repeat
        tacoTool = FindObject(LocalPlayer.Backpack, TACO_TOOL_NAME, 0.1) 
                   or FindObject(char, TACO_TOOL_NAME, 0.1)
        if tacoTool then return true end
        task.wait(0.1)
    until os.clock() - startTime > 3

    return false
end

local function AutoTaco()
    if not autoTacoEnabled or isTacoRunning or not isAlive then return end
    isTacoRunning = true

    local char = LocalPlayer.Character
    local hum = FindObject(char, 'Humanoid', 2)
    local root = FindObject(char, 'HumanoidRootPart', 2)
    if not (hum and root) then isTacoRunning = false return end

    -- Check and buy Taco if needed
    if not EnsureTaco() then
        isTacoRunning = false
        return
    end

    -- Find tool after purchase
    local tacoTool = FindObject(LocalPlayer.Backpack, TACO_TOOL_NAME, 0.1) 
                     or FindObject(char, TACO_TOOL_NAME, 0.1)
    if tacoTool.Parent == LocalPlayer.Backpack then
        pcall(function() hum:EquipTool(tacoTool) end)
        task.wait(0.2)
    end

    -- Click only if tool is equipped
    while tacoTool and tacoTool.Parent == char and autoTacoEnabled and isAlive do
        pcall(mouse1click)
        task.wait(0.07)
        -- Refresh reference
        tacoTool = FindObject(LocalPlayer.Backpack, TACO_TOOL_NAME, 0.1) 
                   or FindObject(char, TACO_TOOL_NAME, 0.1)
    end

    isTacoRunning = false
end

local function StartMonitor()
    if monitorTask then return end
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
        monitorTask = nil
    end)
end

local function StopMonitor()
    autoTacoEnabled = false
    if monitorTask then
        monitorTask = nil
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
local TACO_SOUND_ID = "rbxassetid://6832470734"
local tacoSoundEnabled = true
local tacoSound = nil

local function SetupSound()
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head") or char
    if not root then return end

    if not tacoSound then
        tacoSound = Instance.new("Sound")
        tacoSound.SoundId = TACO_SOUND_ID
        tacoSound.Volume = 0.5
        tacoSound.Name = "TacoEquipSound"
        tacoSound.Parent = root
    else
        tacoSound.Parent = root
    end
end

local function PlayTacoSound()
    if tacoSoundEnabled and tacoSound then
        tacoSound:Stop()
        tacoSound:Play()
    end
end

local function hookTool(tool)
    if tool.Name ~= TACO_TOOL_NAME then return end
    tool.Equipped:Connect(function()
        PlayTacoSound()
    end)
end

local function hookCharacter(char)
    SetupSound()
    for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
        hookTool(tool)
    end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            hookTool(tool)
        end
    end
    LocalPlayer.Backpack.ChildAdded:Connect(hookTool)
    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            hookTool(child)
        end
    end)
end

if LocalPlayer.Character then
    hookCharacter(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(hookCharacter)

-- ======== UI ========
local tab = api:GetTab("Fun things!") or api:AddTab("Fun things!")

-- Left Groupbox with info
local leftGroupbox = tab:AddLeftGroupbox("Info")
leftGroupbox:AddLabel("Author: kolkol")
leftGroupbox:AddLabel("Changelog:")
leftGroupbox:AddLabel("- Smooth spin bot")
leftGroupbox:AddLabel("- Improved teleport system")
leftGroupbox:AddLabel("- Bug fixes")
leftGroupbox:AddLabel("Report bugs to kolkol via PV")

-- Auto Taco Settings
local groupbox = tab:AddRightGroupbox("Auto Taco Settings")
groupbox:AddToggle("auto_taco", { 
    Text = "Auto Taco :D", 
    Default = false,
    Callback = function(value)
        autoTacoEnabled = value
        if value then
            StartMonitor()
        else
            StopMonitor()
        end
    end
})

groupbox:AddToggle("taco_sound", { 
    Text = "Custom Taco Sound", 
    Default = false,
    Callback = function(value)
        tacoSoundEnabled = value
    end
})

-- Spin Bot Settings
local spinGroupbox = tab:AddLeftGroupbox("Spin Bot")
spinGroupbox:AddSlider("spin_speed", {
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

spinGroupbox:AddToggle("spin_bot", {
    Text = "Spin Bot (Smooth)",
    Default = false,
    Callback = function(value)
        ToggleSpinBot(value)
    end
})

-- Initialize systems
if autoTacoEnabled then
    StartMonitor()
end

print("===== IMPROVED AUTO TACO SYSTEM READY =====")
print("===== SMOOTH SPIN BOT READY =====")
print("===== CUSTOM TACO SOUND READY =====")

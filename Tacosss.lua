--// Services
local Players = game:GetService('Players')
local TweenService = game:GetService('TweenService')
local Workspace = game:GetService('Workspace')

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild('PlayerGui')
local api = getfenv().api or {}

-- ======== CONFIG ========
-- Auto Farm Config
local COOLDOWN_TIME = 180
local MIN_HEALTH = 30
local UNDER_CASHIER_Y = 0
local COLLECT_RANGE = 25
local ATTACK_DISTANCE = 5
local CASHIER_ATTACK_TIMEOUT = 12
local TWEEN_SPEED = 120

-- Auto Taco Config
local TACO_SHOP_NAME = '[Taco] - $2'
local TACO_TOOL_NAME = '[Taco]'
local DEFAULT_HP_THRESHOLD = 87
local TACO_COST = 2
local TACO_SOUND_ID = "rbxassetid://6832470734"

-- ======== STATES ========
local Running = false
local Cooldowns = {}
local BlacklistedCashiers = {}
local autoTacoEnabled = false
local hpThreshold = DEFAULT_HP_THRESHOLD
local isTacoRunning = false
local isAlive = true
local monitorTask = nil
local tacoSoundEnabled = false
local tacoSound = nil

-- ======== GUI ========
local ScreenGui = Instance.new('ScreenGui', PlayerGui)
ScreenGui.ResetOnSpawn = false
ScreenGui.Enabled = false

local Title = Instance.new('TextLabel', ScreenGui)
Title.Size = UDim2.new(0, 300, 0, 30)
Title.Position = UDim2.new(0, 20, 0, 20)
Title.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Title.TextColor3 = Color3.fromRGB(255, 255, 0)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 20
Title.Text = 'kolkol DH Scripts'

local StatusLabel = Instance.new('TextLabel', ScreenGui)
StatusLabel.Size = UDim2.new(0, 300, 0, 30)
StatusLabel.Position = UDim2.new(0, 20, 0, 55)
StatusLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
StatusLabel.Font = Enum.Font.Code
StatusLabel.TextSize = 18
StatusLabel.Text = '[READY]'

-- ======== UI SETUP ========
local funTab = api:GetTab("Fun Things!") or api:AddTab("Fun Things!")

-- Auto Farm Groupbox
local autoFarmGroupbox = funTab:AddLeftGroupbox("Auto Farm")
autoFarmGroupbox:AddToggle("auto_farm_toggle", {
    Text = "Enable Auto Farm",
    Default = false,
    Callback = function(state)
        Running = state
        ScreenGui.Enabled = state
        if state then
            coroutine.wrap(MainLoop)()
        else
            if RootPart then RootPart.Anchored = false end
            SetStatus("Auto Farm Disabled", false)
        end
    end
})

autoFarmGroupbox:AddButton("Reset Blacklist", function()
    BlacklistedCashiers = {}
    SetStatus("Cashier blacklist cleared", true)
end)

autoFarmGroupbox:AddSlider("min_health_slider", {
    Text = "Min Health",
    Default = 30,
    Min = 10,
    Max = 100,
    Rounding = 0,
    Callback = function(value)
        MIN_HEALTH = value
        SetStatus("Min Health set to "..value, true)
    end
})

autoFarmGroupbox:AddSlider("tween_speed_slider", {
    Text = "Movement Speed",
    Default = 120,
    Min = 50,
    Max = 300,
    Rounding = 0,
    Callback = function(value)
        TWEEN_SPEED = value
        SetStatus("Speed set to "..value, true)
    end
})

autoFarmGroupbox:AddLabel("Settings")

-- Auto Taco Groupbox
local autoTacoGroupbox = funTab:AddRightGroupbox("Auto Taco")
autoTacoGroupbox:AddToggle("auto_taco_toggle", {
    Text = "Enable Auto Taco",
    Default = false,
    Callback = function(state)
        autoTacoEnabled = state
        if state then
            StartMonitor()
        else
            StopMonitor()
        end
    end
})

autoTacoGroupbox:AddSlider("hp_threshold_slider", {
    Text = "HP Threshold",
    Default = 87,
    Min = 10,
    Max = 100,
    Rounding = 0,
    Callback = function(value)
        hpThreshold = value
    end
})

autoTacoGroupbox:AddToggle("taco_sound_toggle", {
    Text = "Enable Taco Sound",
    Default = false,
    Callback = function(state)
        tacoSoundEnabled = state
    end
})

-- ======== CORE FUNCTIONS ========
local function SetStatus(msg, good)
    StatusLabel.Text = msg
    StatusLabel.TextColor3 = good and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
end

local function UpdateReferences()
    Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    Humanoid = Character:WaitForChild('Humanoid')
    RootPart = Character:WaitForChild('HumanoidRootPart')
    Backpack = LocalPlayer:WaitForChild('Backpack')
    SetStatus('References updated', true)
end

-- ======== AUTO FARM FUNCTIONS ========
local function GetCombatTool()
    return Backpack:FindFirstChild('Combat') or Character:FindFirstChild('Combat')
end

local function IgnorePlayers()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild('HumanoidRootPart') then
            p.Character.HumanoidRootPart.CanCollide = false
        end
    end
end

local function GetNearbyMoneyDrops()
    local drops = {}
    local MoneyDropsFolder = Workspace:WaitForChild('Ignored'):WaitForChild('Drop')
    for _, drop in ipairs(MoneyDropsFolder:GetChildren()) do
        if drop.Name == 'MoneyDrop' and drop:FindFirstChild('ClickDetector') then
            if (drop.Position - RootPart.Position).Magnitude <= COLLECT_RANGE then
                table.insert(drops, drop)
            end
        end
    end
    return drops
end

local function TweenToPosition(targetPos)
    if not RootPart or Humanoid.Health <= 0 then return end
    local dist = (targetPos - RootPart.Position).Magnitude
    local tweenTime = dist / TWEEN_SPEED
    local originalAnchored = RootPart.Anchored
    RootPart.Anchored = true
    local tween = TweenService:Create(
        RootPart,
        TweenInfo.new(tweenTime, Enum.EasingStyle.Linear),
        {CFrame = CFrame.new(targetPos)}
    )
    tween:Play()
    tween.Completed:Wait()
    RootPart.Anchored = originalAnchored
end

local function CollectMoneyDrops(drops)
    for _, drop in ipairs(drops) do
        if not drop.Parent then continue end
        SetStatus('Collecting MoneyDrop', true)
        TweenToPosition(drop.Position + Vector3.new(0, 2, 0))
        local start = tick()
        while drop.Parent and Humanoid.Health > 0 and Running do
            pcall(function() fireclickdetector(drop.ClickDetector) end)
            if tick() - start > 5 then break end
            task.wait(0.2)
        end
    end
end

local function GetPrimaryPart(cashier)
    return cashier:FindFirstChild('HumanoidRootPart') or cashier:FindFirstChild('Head') or cashier:FindFirstChildWhichIsA('BasePart')
end

local function GetActiveCashiers()
    local list = {}
    local CashiersFolder = Workspace:WaitForChild('Cashiers')
    for _, cashier in ipairs(CashiersFolder:GetChildren()) do
        local hum = cashier:FindFirstChild('Humanoid')
        if hum and hum.Health > 0 and not BlacklistedCashiers[cashier] then
            local part = GetPrimaryPart(cashier)
            if part then table.insert(list, cashier) end
        end
    end
    table.sort(list, function(a, b)
        local pa, pb = GetPrimaryPart(a), GetPrimaryPart(b)
        return (pa.Position - RootPart.Position).Magnitude < (pb.Position - RootPart.Position).Magnitude
    end)
    SetStatus('Available Cashiers: '..#list, true)
    return list
end

local function AttackCashier(cashier)
    local hum = cashier:FindFirstChild('Humanoid')
    local part = GetPrimaryPart(cashier)
    if not hum or hum.Health <= 0 or not part then return end

    local tool = GetCombatTool()
    if not tool then
        SetStatus('No Combat Tool', false)
        return
    end
    if tool.Parent ~= Character then
        tool.Parent = Character
        task.wait(0.3)
    end

    SetStatus('Moving in front of Cashier', true)
    local forward = part.CFrame.LookVector
    local targetPos = part.Position - forward * ATTACK_DISTANCE + Vector3.new(0, UNDER_CASHIER_Y, 0)
    RootPart.CFrame = CFrame.new(targetPos, part.Position)

    SetStatus('Attacking Cashier', true)
    local startTick = tick()
    while hum.Health > 0 and Humanoid.Health > MIN_HEALTH and Running do
        if tick() - startTick > CASHIER_ATTACK_TIMEOUT then
            SetStatus('Cashier bugged, blacklisting', false)
            BlacklistedCashiers[cashier] = true
            Humanoid.Health = 0
            task.wait(3)
            UpdateReferences()
            return
        end

        if tool.Parent ~= Character then
            tool.Parent = Character
        end

        pcall(function()
            mouse1press()
            task.wait(3.2)
            mouse1release()
        end)

        local newPos = part.Position - forward * ATTACK_DISTANCE + Vector3.new(0, UNDER_CASHIER_Y, 0)
        RootPart.CFrame = CFrame.new(newPos, part.Position)

        local drops = GetNearbyMoneyDrops()
        if #drops > 0 then CollectMoneyDrops(drops) end

        task.wait(0.2)
    end
    SetStatus('Cashier Defeated', true)
    if tool.Parent == Character then tool.Parent = Backpack end
    Cooldowns[cashier] = os.time()
end

-- ======== AUTO TACO FUNCTIONS ========
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

local function EnsureTaco()
    local char = LocalPlayer.Character
    if not char then return false end

    local tacoTool = FindObject(LocalPlayer.Backpack, TACO_TOOL_NAME, 0.1) or FindObject(char, TACO_TOOL_NAME, 0.1)
    if tacoTool then return true end

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
    pcall(function() root.CFrame = tacoModel:GetPivot() * CFrame.new(0,0,-2) end)
    task.wait(0.2)

    pcall(fireclickdetector, click, 5)
    task.wait(0.2)
    pcall(function() root.CFrame = originalCFrame end)

    local startTime = os.clock()
    repeat
        tacoTool = FindObject(LocalPlayer.Backpack, TACO_TOOL_NAME, 0.1) or FindObject(char, TACO_TOOL_NAME, 0.1)
        if tacoTool then return true end
        task.wait(0.1)
    until os.clock() - startTime > 3

    return false
end

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
    tool.Equipped:Connect(PlayTacoSound)
end

local function hookCharacter(char)
    SetupSound()
    for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do hookTool(tool) end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then hookTool(tool) end
    end
    LocalPlayer.Backpack.ChildAdded:Connect(hookTool)
    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then hookTool(child) end
    end)
end

local function AutoTaco()
    if not autoTacoEnabled or isTacoRunning or not isAlive then return end
    isTacoRunning = true

    local char = LocalPlayer.Character
    local hum = FindObject(char, 'Humanoid', 2)
    local root = FindObject(char, 'HumanoidRootPart', 2)
    if not (hum and root) then isTacoRunning = false return end

    if not EnsureTaco() then
        isTacoRunning = false
        return
    end

    local tacoTool = FindObject(LocalPlayer.Backpack, TACO_TOOL_NAME, 0.1) or FindObject(char, TACO_TOOL_NAME, 0.1)
    if tacoTool.Parent == LocalPlayer.Backpack then
        pcall(function() hum:EquipTool(tacoTool) end)
        task.wait(0.2)
    end

    while tacoTool and tacoTool.Parent == char and autoTacoEnabled and isAlive do
        pcall(mouse1click)
        task.wait(0.07)
        tacoTool = FindObject(LocalPlayer.Backpack, TACO_TOOL_NAME, 0.1) or FindObject(char, TACO_TOOL_NAME, 0.1)
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
    if monitorTask then monitorTask = nil end
end

-- ======== MAIN LOOP ========
local function MainLoop()
    SetStatus('Main loop started', true)
    UpdateReferences()
    while Running and task.wait(0.5) do
        IgnorePlayers()
        if not Character or not Humanoid or Humanoid.Health <= 0 then continue end
        
        if Humanoid.Health <= MIN_HEALTH then
            SetStatus('Low HP, resetting', false)
            Humanoid.Health = 0
            task.wait(3)
            UpdateReferences()
            continue
        end

        local drops = GetNearbyMoneyDrops()
        if #drops > 0 then
            CollectMoneyDrops(drops)
        else
            local active = GetActiveCashiers()
            if #active > 0 then
                AttackCashier(active[1])
            else
                SetStatus('No Cashiers available', false)
            end
        end
    end
end

-- ======== EVENTS ========
LocalPlayer.CharacterAdded:Connect(function(char)
    isAlive = true
    char:WaitForChild('Humanoid').Died:Connect(function()
        isAlive = false
        isTacoRunning = false
    end)
    hookCharacter(char)
    UpdateReferences()
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
    hookCharacter(LocalPlayer.Character)
end

-- ======== INITIALIZATION ========
UpdateReferences()
SetStatus("Ready to start - enable in UI", true)
print("===== SCRIPT LOADED SUCCESSFULLY =====")

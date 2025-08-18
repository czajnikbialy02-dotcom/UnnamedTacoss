local Players = game:GetService('Players')
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild('PlayerGui')
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
    pcall(function() root.CFrame = tacoModel:GetPivot() * CFrame.new(0,0,-2) end)
    task.wait(0.2)

    -- kup Taco
    pcall(fireclickdetector, click, 5)
    task.wait(0.2)
    pcall(function() root.CFrame = originalCFrame end)

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

-- ======== RESPAWN HANDLING ========
LocalPlayer.CharacterAdded:Connect(function(character)
    isAlive = true
    character:WaitForChild('Humanoid').Died:Connect(function()
        isAlive = false
        isTacoRunning = false
    end)
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

-- ======== UI ========
local tab = api:GetTab("Fun things!") or api:AddTab("Fun things!")
local groupbox = tab:AddLeftGroupbox("Auto Taco Settings")
local toggle = groupbox:AddToggle("auto_taco", { Text = "Auto Taco :D", Default = false })
toggle:OnChanged(function(value)
    autoTacoEnabled = value
    if value then
        StartMonitor()
    else
        StopMonitor()
    end
end)

-- ======== CUSTOM TACO SOUND ========
-- i like taco
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

-- === UI ===
local tab = api:GetTab("Fun things!") or api:AddTab("Fun things!")
local toggle = groupbox:AddToggle("taco_sound", { Text = "Custom Taco Sound", Default = false })

toggle:OnChanged(function(value)
    tacoSoundEnabled = value
end)

print("===== CUSTOM TACO SOUND READY =====")



-- ======== START MONITOR ========
if autoTacoEnabled then
    StartMonitor()
end

print("===== AUTO TACO SYSTEM READY =====")

local api = getfenv().api or {}

-- Toggle w GUI
local autofarmEnabled = false
api.Tabs.main:AddToggle({
    Name = "AutoFarm",
    Default = false,
    Callback = function(value)
        autofarmEnabled = value
        api:Notify("Autofarm " .. (value and "ON" or "OFF"), 2)
    end
})

-- Funkcja autofarma
local function AutoFarmLoop()
    local Players = game:GetService('Players')
    local TweenService = game:GetService('TweenService')
    local Workspace = game:GetService('Workspace')

    local LocalPlayer = Players.LocalPlayer
    local Character, Humanoid, RootPart
    local Backpack = LocalPlayer:WaitForChild('Backpack')

    local CashiersFolder = Workspace:WaitForChild('Cashiers')
    local MoneyDropsFolder = Workspace:WaitForChild('Ignored'):WaitForChild('Drop')

    local COOLDOWN_TIME = 180
    local MIN_HEALTH = 30
    local UNDER_CASHIER_Y = 0
    local COLLECT_RANGE = 40
    local ATTACK_DISTANCE = 5
    local CASHIER_ATTACK_TIMEOUT = 12
    local TWEEN_SPEED = 200

    local BlacklistedCashiers = {}

    local function SetStatus(msg, good)
        api:Notify(msg, 1)
    end

    local function UpdateReferences()
        Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        Humanoid = Character:WaitForChild('Humanoid')
        RootPart = Character:WaitForChild('HumanoidRootPart')
        Backpack = LocalPlayer:WaitForChild('Backpack')
        SetStatus("References updated", true)
    end

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
        local tween = TweenService:Create(RootPart, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear), {CFrame = CFrame.new(targetPos)})
        tween:Play()
        tween.Completed:Wait()
        RootPart.Anchored = originalAnchored
    end

    local function CollectMoneyDrops(drops)
        for _, drop in ipairs(drops) do
            if not drop.Parent then continue end
            SetStatus("Collecting MoneyDrop", true)
            TweenToPosition(drop.Position + Vector3.new(0,2,0))
            local start = tick()
            while drop.Parent and Humanoid.Health > 0 do
                pcall(function() fireclickdetector(drop.ClickDetector) end)
                if tick() - start > 2 then break end
                task.wait(0.1)
            end
        end
    end

    local function GetPrimaryPart(cashier)
        return cashier:FindFirstChild('HumanoidRootPart') or cashier:FindFirstChild('Head') or cashier:FindFirstChildWhichIsA('BasePart')
    end

    local function GetActiveCashiers()
        local list = {}
        for _, cashier in ipairs(CashiersFolder:GetChildren()) do
            local hum = cashier:FindFirstChild('Humanoid')
            if hum and hum.Health > 0 and not BlacklistedCashiers[cashier] then
                local part = GetPrimaryPart(cashier)
                if part then table.insert(list, cashier) end
            end
        end
        table.sort(list, function(a,b)
            local pa,pb = GetPrimaryPart(a),GetPrimaryPart(b)
            return (pa.Position - RootPart.Position).Magnitude < (pb.Position - RootPart.Position).Magnitude
        end)
        return list
    end

    local function AttackCashier(cashier)
        local hum = cashier:FindFirstChild('Humanoid')
        local part = GetPrimaryPart(cashier)
        if not hum or hum.Health <= 0 or not part then return end

        local tool = GetCombatTool()
        if not tool then
            SetStatus("No Combat Tool", false)
            return
        end
        if tool.Parent ~= Character then
            tool.Parent = Character
            task.wait(0.2)
        end

        local forward = part.CFrame.LookVector
        local targetPos = part.Position - forward * ATTACK_DISTANCE + Vector3.new(0,UNDER_CASHIER_Y,0)
        RootPart.CFrame = CFrame.new(targetPos, part.Position)

        SetStatus("Attacking Cashier", true)
        local startTick = tick()
        while hum.Health > 0 and Humanoid.Health > MIN_HEALTH and autofarmEnabled do
            if tick() - startTick > CASHIER_ATTACK_TIMEOUT then
                SetStatus("Cashier bugged, blacklisting", false)
                BlacklistedCashiers[cashier] = true
                Humanoid.Health = 0
                task.wait(3)
                UpdateReferences()
                return
            end
            if tool.Parent ~= Character then tool.Parent = Character end
            pcall(function() mouse1press() task.wait(3.2) mouse1release() end)

            local newPos = part.Position - forward*ATTACK_DISTANCE + Vector3.new(0,UNDER_CASHIER_Y,0)
            RootPart.CFrame = CFrame.new(newPos, part.Position)

            local drops = GetNearbyMoneyDrops()
            if #drops > 0 then CollectMoneyDrops(drops) end

            task.wait(0.1)
        end

        if tool.Parent == Character then tool.Parent = Backpack end
    end

    -- Loop
    while task.wait(0.3) do
        if not autofarmEnabled then continue end
        UpdateReferences()
        IgnorePlayers()
        if Humanoid.Health <= MIN_HEALTH then
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
                SetStatus("No Cashiers available", false)
            end
        end
    end
end

-- Start autofarm w tle
task.spawn(AutoFarmLoop)

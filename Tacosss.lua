local Players = game:GetService('Players')
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild('PlayerGui')
local api = getfenv().api or {}

-- ======== KONFIGURACJA ========
local TACO_SHOP_NAME = '[Taco] - $2'
local TACO_TOOL_NAME = '[Taco]'
local DEFAULT_HP_THRESHOLD = 87
local TACO_COST = 2
local CLICK_DELAY = 0.07
local SOUND_IDS = {
    "rbxassetid://6832470734",
    "rbxassetid://6830368128", 
    "rbxassetid://85950680962526"
}

-- ======== STANY ========
local autoTacoEnabled = true
local hpThreshold = DEFAULT_HP_THRESHOLD
local isTacoRunning = false
local isAlive = true
local monitorTask = nil
local tacoSoundEnabled = true
local tacoSoundVolume = 0.6
local shouldStopClicking = false -- Nowa zmienna do kontroli klikania

-- ======== POMOCNICZE ========
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

-- ======== SYSTEM DŹWIĘKU ========
local soundController = {
    sound = nil,
    lastEquipTime = 0,
    
    setup = function(self)
        if not tacoSoundEnabled then return end
        
        local char = LocalPlayer.Character
        if not char then return end
        
        local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
        if not root then return end

        self:cleanup()
        
        self.sound = Instance.new("Sound")
        self.sound.Volume = tacoSoundVolume
        self.sound.Name = "TacoSoundFX"
        self.sound.Parent = root
    end,
    
    cleanup = function(self)
        if self.sound then
            self.sound:Destroy()
            self.sound = nil
        end
    end,
    
    playRandom = function(self)
        if not tacoSoundEnabled or not LocalPlayer.Character then return end
        
        if os.clock() - self.lastEquipTime < 0.1 then return end
        self.lastEquipTime = os.clock()
        
        if not self.sound then
            self:setup()
            task.wait(0.1)
        end

        if self.sound then
            self.sound.SoundId = SOUND_IDS[math.random(#SOUND_IDS)]
            self.sound:Stop()
            self.sound:Play()
        end
    end
}

-- ======== OBSŁUGA TACO ========
local function EnsureTaco()
    local char = LocalPlayer.Character
    if not char or shouldStopClicking then return false end

    local tacoTool = FindObject(LocalPlayer.Backpack, TACO_TOOL_NAME, 0.1) 
                     or FindObject(char, TACO_TOOL_NAME, 0.1)
    if tacoTool then return true end

    local root = FindObject(char, "HumanoidRootPart", 2)
    local shop = FindObject(FindObject(workspace, "Ignored", 3), "Shop", 3)
    local tacoModel = shop and FindObject(shop, TACO_SHOP_NAME, 3)
    local click = tacoModel and FindObject(tacoModel, "ClickDetector", 2)
    
    if not root or not tacoModel or not click then return false end
    if GetCurrentMoney() < TACO_COST then return false end

    local originalCFrame = root.CFrame
    pcall(function() root.CFrame = tacoModel:GetPivot() * CFrame.new(0,0,-2) end)
    task.wait(0.2)
    pcall(fireclickdetector, click, 5)
    task.wait(0.2)
    pcall(function() root.CFrame = originalCFrame end)

    local startTime = os.clock()
    repeat
        if shouldStopClicking then return false end
        tacoTool = FindObject(LocalPlayer.Backpack, TACO_TOOL_NAME, 0.1) 
                   or FindObject(char, TACO_TOOL_NAME, 0.1)
        if tacoTool then return true end
        task.wait(0.1)
    until os.clock() - startTime > 3

    return false
end

-- ======== AUTO TACO ========
local function AutoTaco()
    if not autoTacoEnabled or isTacoRunning or not isAlive or shouldStopClicking then return end
    isTacoRunning = true
    shouldStopClicking = false

    local char = LocalPlayer.Character
    local hum = FindObject(char, 'Humanoid', 2)
    local root = FindObject(char, 'HumanoidRootPart', 2)
    if not (hum and root) then 
        isTacoRunning = false
        return 
    end

    if not EnsureTaco() then
        isTacoRunning = false
        return
    end

    local tacoTool = FindObject(LocalPlayer.Backpack, TACO_TOOL_NAME, 0.1) 
                     or FindObject(char, TACO_TOOL_NAME, 0.1)
    if tacoTool and tacoTool.Parent == LocalPlayer.Backpack then
        pcall(function() hum:EquipTool(tacoTool) end)
        task.wait(0.2)
    end

    while tacoTool and tacoTool.Parent == char and autoTacoEnabled and isAlive and not shouldStopClicking do
        pcall(mouse1click)
        task.wait(CLICK_DELAY)
        tacoTool = FindObject(LocalPlayer.Backpack, TACO_TOOL_NAME, 0.1) 
                   or FindObject(char, TACO_TOOL_NAME, 0.1)
    end

    isTacoRunning = false
end

-- ======== MONITOR ========
local function StartMonitor()
    if monitorTask then return end
    monitorTask = task.spawn(function()
        while autoTacoEnabled and not shouldStopClicking do
            task.wait(0.2)
            if not isAlive or shouldStopClicking then
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
    shouldStopClicking = true
    if monitorTask then
        monitorTask = nil
    end
end

-- ======== OBSŁUGA POSTACI ========
local function HandleCharacter(char)
    isAlive = true
    shouldStopClicking = false
    
    -- Podłącz istniejące narzędzia
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and tool.Name == TACO_TOOL_NAME then
            tool.Equipped:Connect(function()
                soundController:playRandom()
            end)
        end
    end
    
    -- Podłącz nowe narzędzia
    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") and child.Name == TACO_TOOL_NAME then
            child.Equipped:Connect(function()
                soundController:playRandom()
            end)
        end
    end)

    -- Podłącz narzędzia z plecaka
    for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") and tool.Name == TACO_TOOL_NAME then
            tool.Equipped:Connect(function()
                soundController:playRandom()
            end)
        end
    end
    
    LocalPlayer.Backpack.ChildAdded:Connect(function(child)
        if child:IsA("Tool") and child.Name == TACO_TOOL_NAME then
            child.Equipped:Connect(function()
                soundController:playRandom()
            end)
        end
    end)

    local humanoid = char:WaitForChild('Humanoid')
    humanoid.Died:Connect(function()
        isAlive = false
        isTacoRunning = false
        shouldStopClicking = true
    end)
end

-- ======== UI ========
local tab = api:GetTab("Fun things!") or api:AddTab("Fun things!")
local groupbox = tab:AddLeftGroupbox("Auto Taco Settings")

local toggle = groupbox:AddToggle("auto_taco", { 
    Text = "Auto Taco", 
    Default = autoTacoEnabled 
})
toggle:OnChanged(function(value)
    autoTacoEnabled = value
    shouldStopClicking = not value
    if value then
        StartMonitor()
    else
        StopMonitor()
    end
end)

groupbox:AddSlider("hp_threshold", {
    Text = "HP Threshold (%)",
    Min = 25,
    Max = 95,
    Default = DEFAULT_HP_THRESHOLD,
    Rounding = 0,
}):OnChanged(function(value)
    hpThreshold = value
end)

groupbox:AddToggle("taco_sound", { 
    Text = "Enable Taco Sounds", 
    Default = tacoSoundEnabled 
}):OnChanged(function(value)
    tacoSoundEnabled = value
end)

-- ======== INICJALIZACJA ========
LocalPlayer.CharacterAdded:Connect(function(char)
    HandleCharacter(char)
end)

if LocalPlayer.Character then
    HandleCharacter(LocalPlayer.Character)
end

if autoTacoEnabled then
    StartMonitor()
end

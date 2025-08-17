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

-- ======== AUTO TACO ========
local function AutoTaco()
    if not autoTacoEnabled or isTacoRunning or not isAlive then return end
    isTacoRunning = true
    local char = LocalPlayer.Character
    local hum = FindObject(char, 'Humanoid', 2)
    local root = FindObject(char, 'HumanoidRootPart', 2)
    if not (hum and root) then isTacoRunning = false return end

    local shop = FindObject(FindObject(workspace, 'Ignored', 3), 'Shop', 3)
    local tacoModel = shop and FindObject(shop, TACO_SHOP_NAME, 3)
    local click = tacoModel and FindObject(tacoModel, 'ClickDetector', 2)
    if not click then warn('Taco not found!') isTacoRunning = false return end
    if GetCurrentMoney() < TACO_COST then isTacoRunning = false return end

    local originalCFrame = root.CFrame
    pcall(function() root.CFrame = tacoModel:GetPivot() * CFrame.new(0,0,-2) end)
    task.wait(0.2)

    for i = 1, 15 do
        if not autoTacoEnabled or GetCurrentMoney() < TACO_COST or not isAlive then break end
        pcall(fireclickdetector, click, 5)
        task.wait(0.03)
    end

    pcall(function() root.CFrame = originalCFrame end)
    task.wait(0.2)

    local startTime = os.clock()
    local tacoTool
    repeat
        if not autoTacoEnabled or not isAlive then isTacoRunning = false return end
        tacoTool = FindObject(LocalPlayer.Backpack, TACO_TOOL_NAME, 0.1) or FindObject(char, TACO_TOOL_NAME, 0.1)
        task.wait(0.1)
    until tacoTool or os.clock()-startTime > 3

    if tacoTool and autoTacoEnabled then
        if tacoTool.Parent == LocalPlayer.Backpack then
            pcall(function() hum:EquipTool(tacoTool) end)
            task.wait(0.2)
        end
        while tacoTool and tacoTool.Parent and autoTacoEnabled do
            pcall(mouse1click)
            task.wait(0.07)
            tacoTool = FindObject(LocalPlayer.Backpack, TACO_TOOL_NAME, 0.1) or FindObject(char, TACO_TOOL_NAME, 0.1)
        end
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
local toggle = groupbox:AddToggle("auto_taco", { Text = "Auto Taco :D", Default = true })
toggle:OnChanged(function(value)
    autoTacoEnabled = value
    if value then
        StartMonitor()
    else
        StopMonitor()
    end
end)

-- ======== CUSTOM TACO SOUND ========
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local api = getfenv().api or {}

-- === KONFIG ===
local TACO_TOOL_NAME = "[Taco]"
local SOUND_ID = "rbxassetid://6832470734"

-- === STATE ===
local tacoSoundEnabled = true

-- === SOUND FUNC ===
local function PlayTacoSound()
    if not tacoSoundEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head") or char
    if not root then return end

    local sound = Instance.new("Sound")
    sound.SoundId = SOUND_ID
    sound.Volume = 2
    sound.PlayOnRemove = true
    sound.Parent = root
    sound:Destroy() -- PlayOnRemove powoduje odpalenie dźwięku przy usunięciu
end

-- === HOOK TOOLS ===
local function HookCharacter(char)
    -- nasłuch na toole w Backpacku
    local function connectTool(tool)
        if tool.Name == TACO_TOOL_NAME then
            tool.Equipped:Connect(function()
                PlayTacoSound()
            end)
        end
    end

    -- podpinamy pod wszystkie obecne toolsy
    for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
        connectTool(tool)
    end

    -- podpinamy na przyszłe toolsy
    LocalPlayer.Backpack.ChildAdded:Connect(connectTool)
end

-- podpinamy na aktualnej postaci
if LocalPlayer.Character then
    HookCharacter(LocalPlayer.Character)
end

-- podpinamy na respawn
LocalPlayer.CharacterAdded:Connect(HookCharacter)

-- === UI ===
local tab = api:GetTab("Fun things!") or api:AddTab("Fun things!")
local groupbox = tab:AddLeftGroupbox("Taco Sound Settings")
local toggle = groupbox:AddToggle("taco_sound", { Text = "Custom Taco Sound", Default = true })

toggle:OnChanged(function(value)
    tacoSoundEnabled = value
end)

print("===== CUSTOM TACO SOUND READY =====")


-- ======== START MONITOR ========
if autoTacoEnabled then
    StartMonitor()
end

print("===== AUTO TACO SYSTEM READY =====")

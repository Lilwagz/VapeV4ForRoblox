local run = function(func) func() end
local cloneref = cloneref or function(obj) return obj end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))

local lplr = playersService.LocalPlayer
local vape = shared.vape

local store = {
    triggerbot = {
        Enabled = false,
        canGrab = true,
        maxDistance = 20,
        targetMemory = 0.07,
        checkThrottle = 0.003,
        lastCheck = 0,
        lastTarget = nil,
        lastHitTime = 0,
        respawnUntil = 0,
        lastToggleTime = 0,
        toggleDebounce = 0.18
    }
}

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function notif(...)
    return vape:CreateNotification(...)
end

local function getCharacter(player)
    player = player or lplr
    return player.Character
end

local function getRoot(player)
    local character = getCharacter(player)
    return character and character:FindFirstChild('HumanoidRootPart')
end

local function isTyping()
    return inputService:GetFocusedTextBox() ~= nil
end

local function isCharacterInAnyPlot(character)
    if not character then return false end
    local root = character:FindFirstChild('HumanoidRootPart')
    if not root then return false end
    local plotFolder = workspace:FindFirstChild('PlotItems') and workspace.PlotItems:FindFirstChild('PlayersInPlots')
    if not plotFolder then return false end
    for _, plot in ipairs(plotFolder:GetChildren()) do
        local plotPart = plot:FindFirstChildWhichIsA('BasePart') or plot:FindFirstChildWhichIsA('Model')
        if not plotPart then continue end
        local part = plotPart:IsA('BasePart') and plotPart or plotPart:FindFirstChildWhichIsA('BasePart')
        if part and (root.Position - part.Position).Magnitude < 50 then
            return true
        end
    end
    return false
end

local function canRun()
    local tb = store.triggerbot
    if not tb.Enabled or not tb.canGrab then return false end
    if isTyping() then return false end
    if workspace:FindFirstChild('GrabParts') then return false end
    if tick() < tb.respawnUntil then return false end
    return true
end

local function getTarget()
    local tb = store.triggerbot
    local char = lplr.Character
    local myRoot = char and char:FindFirstChild('HumanoidRootPart')
    if not myRoot then return nil end

    local cam = workspace.CurrentCamera
    if not cam then return nil end

    rayParams.FilterDescendantsInstances = {char, workspace.Terrain}

    local result = workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * tb.maxDistance, rayParams)
    if not result then return nil end

    local model = result.Instance:FindFirstAncestorWhichIsA('Model')
    if not model or model == char then return nil end

    local humanoid = model:FindFirstChildOfClass('Humanoid')
    if not humanoid or humanoid.Health <= 0 then return nil end

    local root = model:FindFirstChild('HumanoidRootPart') or model:FindFirstChild('Root')
    if not root then return nil end

    if (myRoot.Position - root.Position).Magnitude > tb.maxDistance then return nil end
    if isCharacterInAnyPlot(model) then return nil end

    local losParams = RaycastParams.new()
    losParams.FilterDescendantsInstances = {char, workspace.Terrain}
    losParams.FilterType = Enum.RaycastFilterType.Exclude
    local losResult = workspace:Raycast(myRoot.Position, root.Position - myRoot.Position, losParams)
    if losResult and not losResult.Instance:IsDescendantOf(model) then
        return nil
    end

    return model
end

local function onHeartbeat()
    if not canRun() then return end

    local tb = store.triggerbot
    local now = tick()

    if now - tb.lastCheck < tb.checkThrottle then return end
    tb.lastCheck = now

    local target = getTarget()

    if target then
        tb.lastTarget = target
        tb.lastHitTime = now
    elseif tb.lastTarget and now - tb.lastHitTime > tb.targetMemory then
        tb.lastTarget = nil
    end

    if not tb.lastTarget then return end

    local myRoot = getRoot()
    local enemyRoot = tb.lastTarget:FindFirstChild('HumanoidRootPart')

    if not myRoot or not enemyRoot or (myRoot.Position - enemyRoot.Position).Magnitude > tb.maxDistance then
        tb.lastTarget = nil
        return
    end

    tb.canGrab = false

    task.spawn(function()
        if not tb.Enabled then
            tb.canGrab = true
            return
        end

        if mouse1press then
            pcall(mouse1press)
        else
            notif('FTAP TriggerBot', 'mouse1press não disponível nesse executor.', 5, 'warning')
            tb.Enabled = false
            tb.canGrab = true
            return
        end

        local start = tick()
        while tb.Enabled and workspace:FindFirstChild('GrabParts') and tick() - start < 1.4 do
            task.wait()
        end

        task.wait(0.016)
        tb.canGrab = true
        tb.lastTarget = nil
    end)
end

local function setEnabled(state)
    local tb = store.triggerbot
    tb.Enabled = state

    if tb.Connection then
        pcall(function() tb.Connection:Disconnect() end)
        tb.Connection = nil
    end

    if not tb.Enabled then
        tb.canGrab = true
        tb.lastTarget = nil
    else
        tb.Connection = runService.Heartbeat:Connect(onHeartbeat)
        notif('FTAP TriggerBot', 'Ativado. F4 pra ligar/desligar.', 2, 'assets/VapeIcon.png')
    end
end

-- Checagem de gamepass
task.spawn(function()
    local gp = replicatedStorage:FindFirstChild('GamepassEvents')
    if not gp then return end

    local rf = gp:FindFirstChild('CheckForGamepass')
    if rf and rf:IsA('RemoteFunction') then
        pcall(function()
            if rf:InvokeServer(20837132) then
                store.triggerbot.maxDistance = 29.3
            end
        end)
    end

    local notifier = gp:FindFirstChild('FurtherReachBoughtNotifier')
    if notifier and notifier:IsA('RemoteEvent') then
        notifier.OnClientEvent:Connect(function()
            store.triggerbot.maxDistance = 29.3
            notif('FTAP TriggerBot', 'Further Reach detectado (+9.3 studs)', 4)
        end)
    end
end)

-- Bind F4
inputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.F4 then
        local now = tick()
        if now - store.triggerbot.lastToggleTime < store.triggerbot.toggleDebounce then return end
        store.triggerbot.lastToggleTime = now
        setEnabled(not store.triggerbot.Enabled)
    end
end)

lplr.CharacterAdded:Connect(function()
    store.triggerbot.respawnUntil = tick() + 2
    store.triggerbot.canGrab = true
    store.triggerbot.lastTarget = nil
end)

notif('FTAP TriggerBot', 'Module carregado com sucesso.', 5, 'assets/VapeIcon.png')

local run = function(func) func() end
local cloneref = cloneref or function(obj) return obj end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))

local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity

local store = {
	remotes = {},
	connections = {},
	triggerbot = {
		canGrab = true,
		lastCheck = 0,
		lastTarget = nil,
		lastHitTime = 0,
		respawnUntil = 0
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
	return character and character:FindFirstChild('HumanoidRootPart') or nil
end

local function findRemote(name)
	local cached = store.remotes[name]
	if cached and cached.Parent then
		return cached
	end

	for _, inst in replicatedStorage:GetDescendants() do
		if inst.Name == name and (inst:IsA('RemoteEvent') or inst:IsA('RemoteFunction')) then
			store.remotes[name] = inst
			return inst
		end
	end
end

local function isTyping()
	return inputService:GetFocusedTextBox() ~= nil
end

local function isCharacterInAnyPlot(character)
	if not character then return false end
	local root = character:FindFirstChild('HumanoidRootPart')
	if not root then return false end
	local plotFolder = workspace:FindFirstChild('PlotItems')
		and workspace.PlotItems:FindFirstChild('PlayersInPlots')
	if not plotFolder then return false end

	for _, plot in plotFolder:GetChildren() do
		local plotPart = plot:FindFirstChildWhichIsA('BasePart')
			or plot:FindFirstChildWhichIsA('Model')
		if not plotPart then continue end

		local part = plotPart:IsA('BasePart') and plotPart
			or plotPart:FindFirstChildWhichIsA('BasePart')
		if part and (root.Position - part.Position).Magnitude < 50 then
			return true
		end
	end

	return false
end

vape:Clean(function()
	for _, connection in store.connections do
		connection:Disconnect()
	end

	table.clear(store.connections)
	table.clear(store.remotes)
	table.clear(store)
end)

run(function()
	local TriggerBot
	local MaxDistance
	local TargetMemory
	local CheckThrottle

	local function canRun()
		if not TriggerBot.Enabled or not store.triggerbot.canGrab then return false end
		if isTyping() then return false end
		if workspace:FindFirstChild('GrabParts') then return false end
		if tick() < store.triggerbot.respawnUntil then return false end
		return true
	end

	local function getTarget()
		local character = lplr.Character
		local myRoot = character and character:FindFirstChild('HumanoidRootPart')
		local camera = workspace.CurrentCamera
		if not myRoot or not camera then return end

		rayParams.FilterDescendantsInstances = {character, workspace.Terrain}
		local result = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * MaxDistance.Value, rayParams)
		if not result then return end

		local model = result.Instance:FindFirstAncestorWhichIsA('Model')
		if not model or model == character then return end

		local humanoid = model:FindFirstChildOfClass('Humanoid')
		local root = model:FindFirstChild('HumanoidRootPart') or model:FindFirstChild('Root')
		if not humanoid or humanoid.Health <= 0 or not root then return end
		if (myRoot.Position - root.Position).Magnitude > MaxDistance.Value then return end
		if isCharacterInAnyPlot(model) then return end

		local losParams = RaycastParams.new()
		losParams.FilterDescendantsInstances = {character, workspace.Terrain}
		losParams.FilterType = Enum.RaycastFilterType.Exclude
		local losResult = workspace:Raycast(myRoot.Position, root.Position - myRoot.Position, losParams)
		if losResult and not losResult.Instance:IsDescendantOf(model) then return end

		return model
	end

	local function resetTarget()
		store.triggerbot.canGrab = true
		store.triggerbot.lastTarget = nil
	end

	local function onHeartbeat()
		if not canRun() then return end

		local now = tick()
		if now - store.triggerbot.lastCheck < CheckThrottle.Value then return end
		store.triggerbot.lastCheck = now

		local target = getTarget()
		if target then
			store.triggerbot.lastTarget = target
			store.triggerbot.lastHitTime = now
		elseif store.triggerbot.lastTarget and now - store.triggerbot.lastHitTime > TargetMemory.Value then
			store.triggerbot.lastTarget = nil
		end

		if not store.triggerbot.lastTarget then return end

		local myRoot = getRoot()
		local enemyRoot = store.triggerbot.lastTarget:FindFirstChild('HumanoidRootPart')
		if not myRoot or not enemyRoot or (myRoot.Position - enemyRoot.Position).Magnitude > MaxDistance.Value then
			store.triggerbot.lastTarget = nil
			return
		end

		store.triggerbot.canGrab = false
		task.spawn(function()
			if not TriggerBot.Enabled then
				resetTarget()
				return
			end

			if not mouse1press then
				notif('FTAP TriggerBot', 'mouse1press is not available in this executor.', 5, 'warning')
				TriggerBot:Toggle(false)
				resetTarget()
				return
			end

			pcall(mouse1press)
			local start = tick()
			while TriggerBot.Enabled and workspace:FindFirstChild('GrabParts') and tick() - start < 1.4 do
				task.wait()
			end

			task.wait()
			resetTarget()
		end)
	end

	local function checkReachGamepass()
		local gamepassEvents = replicatedStorage:FindFirstChild('GamepassEvents')
		if not gamepassEvents then return end

		local remoteFunction = gamepassEvents:FindFirstChild('CheckForGamepass')
		if remoteFunction and remoteFunction:IsA('RemoteFunction') then
			pcall(function()
				if remoteFunction:InvokeServer(20837132) then
					MaxDistance:SetValue(29.3)
				end
			end)
		end

		local notifier = gamepassEvents:FindFirstChild('FurtherReachBoughtNotifier')
		if notifier and notifier:IsA('RemoteEvent') then
			TriggerBot:Clean(notifier.OnClientEvent:Connect(function()
				MaxDistance:SetValue(29.3)
			end))
		end
	end

	TriggerBot = vape.Categories.Combat:CreateModule({
		Name = 'TriggerBot',
		Function = function(callback)
			if callback then
				store.triggerbot.canGrab = true
				store.triggerbot.lastTarget = nil
				store.triggerbot.lastCheck = 0
				store.triggerbot.respawnUntil = tick() + 0.25
				TriggerBot:Clean(runService.Heartbeat:Connect(onHeartbeat))
				checkReachGamepass()
				notif('FTAP TriggerBot', 'Enabled. Bound to F4 by default.', 2, 'assets/VapeIcon.png')
			else
				resetTarget()
				if mouse1release then
					pcall(mouse1release)
				end
			end
		end,
		ExtraText = function()
			return store.triggerbot.canGrab and 'Ready' or 'Grabbing'
		end,
		Tooltip = 'Grabs a valid target when it enters your crosshair.'
	})
	TriggerBot:SetBind({'F4'})

	MaxDistance = TriggerBot:CreateSlider({
		Name = 'Distance',
		Min = 1,
		Max = 30,
		Default = 20,
		Decimal = 10,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	TargetMemory = TriggerBot:CreateSlider({
		Name = 'Target Memory',
		Min = 0,
		Max = 0.25,
		Default = 0.07,
		Decimal = 1000,
		Suffix = function()
			return 'seconds'
		end
	})
	CheckThrottle = TriggerBot:CreateSlider({
		Name = 'Check Throttle',
		Min = 0,
		Max = 0.05,
		Default = 0.003,
		Decimal = 1000,
		Suffix = function()
			return 'seconds'
		end
	})

	TriggerBot:Clean(lplr.CharacterAdded:Connect(function()
		store.triggerbot.respawnUntil = tick() + 2
		resetTarget()
	end))
end)

run(function()
	vape.Categories.Utility:CreateModule({
		Name = 'FTAPInfo',
		Function = function(callback)
			if callback then
				notif('Fling Things and People', 'Game module loaded for place '..game.PlaceId, 5, 'assets/VapeIcon.png')
			end
		end,
		Tooltip = 'Shows that the Fling Things and People module is loaded.'
	})
end)

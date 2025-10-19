--!strict

local KillBotEvent = {}

type ParticipantRecord = {
	player: Player,
	humanoid: Humanoid?,
}

type Dependencies = {
	getNeutralParticipantRecords: () -> {ParticipantRecord},
	getActiveMapBounds: () -> (CFrame, Vector3),
	RunService: RunService,
	Workspace: Workspace,
	Debris: Debris,
	isRoundActive: (roundId: number) -> boolean,
}

type KillBotState = {
	model: Model?,
	ball: BasePart?,
	attachment: Attachment?,
	vectorForce: VectorForce?,
	align: AlignOrientation?,
	homePosition: Vector3,
	currentTarget: BasePart?,
	targetTimer: number?,
	jitterOffset: Vector3,
	jitterTimer: number,
	wanderOffset: Vector3,
	wanderTimer: number,
	holdTimer: number,
	fireCooldown: number,
	pauseTimer: number,
	lastFire: number,
}

type EventState = {
	bots: {KillBotState},
	rockets: {() -> ()},
	heartbeatConn: RBXScriptConnection?,
}

type KillBotConfig = {
	scanRadius: number,
	fireCooldown: number,
	hoverHeight: number,
	moveForce: number,
	maxSpeed: number,
	seekStrength: number,
	holdReadyTime: number,
	holdDistance: number,
	postFirePause: number,
	rocketSpeed: number,
	rocketLifetime: number,
	rocketArmDelay: number,
	rocketBlastRadius: number,
	rocketBaseDamage: number,
	rocketKnockback: number,
	wanderInterval: NumberRange,
	wanderDistance: NumberRange,
	jitterInterval: NumberRange,
	jitterMagnitude: NumberRange,
	targetHoldTime: NumberRange,
	spawnHeightOffset: number,
	spawnHeightStep: number,
}

local DEFAULT_CONFIG: KillBotConfig = {
	scanRadius = math.huge,
	fireCooldown = 2.25,
	hoverHeight = 8,
	moveForce = 6000,
	maxSpeed = 70,
	seekStrength = 0.55,
	holdReadyTime = 0.4,
	holdDistance = 6,
	postFirePause = 0.85,
	rocketSpeed = 55,
	rocketLifetime = 12,
	rocketArmDelay = 0.3,
	rocketBlastRadius = 12,
	rocketBaseDamage = 55,
	rocketKnockback = 60,
	wanderInterval = NumberRange.new(1.5, 3.5),
	wanderDistance = NumberRange.new(30, 70),
	jitterInterval = NumberRange.new(0.35, 0.8),
	jitterMagnitude = NumberRange.new(0, 8),
	targetHoldTime = NumberRange.new(1.5, 3.5),
	spawnHeightOffset = 50,
	spawnHeightStep = 10,
}

local ZERO_VECTOR = Vector3.zero

local function randomInRange(random: Random, range: NumberRange): number
	return random:NextNumber(range.Min, range.Max)
end

local function hasLineOfSight(model: Model?, fromPos: Vector3, toPos: Vector3, workspaceService: Workspace): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	if model then
		params.FilterDescendantsInstances = {model}
	end

	local direction = toPos - fromPos
	local result = workspaceService:Raycast(fromPos, direction, params)
	if not result then
		return true
	end

	return (result.Position - toPos).Magnitude < 2
end

local function damageInRadius(
	workspaceService: Workspace,
	center: Vector3,
	radius: number,
	baseDamage: number,
	knockback: number
)
	local params = OverlapParams.new()
	for _, part in ipairs(workspaceService:GetPartBoundsInRadius(center, radius, params)) do
		local parent = part.Parent
		if not parent then
			continue
		end

		local humanoid = parent:FindFirstChildWhichIsA("Humanoid")
		if not humanoid and parent.Parent then
			humanoid = parent.Parent:FindFirstChildWhichIsA("Humanoid")
		end

		if humanoid and humanoid.Health > 0 then
			local character = humanoid.Parent
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local distance = (hrp.Position - center).Magnitude
				if distance <= radius then
					local damage = math.clamp(baseDamage * (1 - (distance / radius)), 10, baseDamage)
					humanoid:TakeDamage(damage)

					local knockDir = (hrp.Position - center).Unit
					hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity + knockDir * knockback
				end
			end
		end
	end
end

local function gatherTargets(deps: Dependencies): {BasePart}
	local targets: {BasePart} = {}
	for _, record in ipairs(deps.getNeutralParticipantRecords()) do
		local player = record.player
		local character = player and player.Character
		if not character then
			continue
		end

		local humanoid = record.humanoid or character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			continue
		end

		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			table.insert(targets, hrp)
		end
	end

	return targets
end

local function pickTarget(
	botState: KillBotState,
	dt: number,
	targets: {BasePart},
	config: KillBotConfig,
	workspaceService: Workspace,
	random: Random
): BasePart?
	local ball = botState.ball
	if not ball or not ball.Parent then
		botState.currentTarget = nil
		botState.targetTimer = nil
		return nil
	end

	local position = ball.Position
	local existing = botState.currentTarget
	if existing and existing.Parent then
		local timer = (botState.targetTimer or 0) - dt
		botState.targetTimer = timer
		local distance = (existing.Position - position).Magnitude
		if distance <= config.scanRadius and timer > 0 and hasLineOfSight(botState.model, position, existing.Position, workspaceService) then
			return existing
		end
	end

	botState.currentTarget = nil
	botState.targetTimer = nil

	local visibleTargets: {BasePart} = {}
	for _, target in ipairs(targets) do
		if not target.Parent then
			continue
		end

		local distance = (target.Position - position).Magnitude
		if distance > config.scanRadius then
			continue
		end

		if not hasLineOfSight(botState.model, position, target.Position, workspaceService) then
			continue
		end

		table.insert(visibleTargets, target)
	end

	local count = #visibleTargets
	if count == 0 then
		return nil
	end

	local selected = visibleTargets[random:NextInteger(1, count)]
	botState.currentTarget = selected
	botState.targetTimer = randomInRange(random, config.targetHoldTime)
	return selected
end

local function updateAlignment(botState: KillBotState)
	local align = botState.align
	local ball = botState.ball
	if not align or not ball or not ball.Parent then
		return
	end

	local velocity = ball.AssemblyLinearVelocity
	local forward = if velocity.Magnitude > 0.1 then velocity.Unit else ball.CFrame.LookVector
	align.CFrame = CFrame.lookAt(ball.Position, ball.Position + forward)
end

local function createRocket(
	state: EventState,
	botState: KillBotState,
	target: BasePart,
	config: KillBotConfig,
	workspaceService: Workspace,
	debris: Debris
): boolean
	local ball = botState.ball
	if not ball or not ball.Parent then
		return false
	end

	if not target or not target.Parent then
		return false
	end

	local now = os.clock()
	if now - (botState.lastFire or 0) < config.fireCooldown then
		return false
	end
	botState.lastFire = now

	local rocket = Instance.new("Part")
	rocket.Name = "KillBotRocket"
	rocket.Shape = Enum.PartType.Ball
	rocket.Size = Vector3.new(2, 2, 2)
	rocket.Material = Enum.Material.Neon
	rocket.Color = Color3.fromRGB(255, 120, 120)
	rocket.CanCollide = false
	rocket.CanQuery = false
	rocket.CanTouch = true
	rocket.Massless = true
	rocket.Anchored = false

	local launchOrigin = ball.Position
	local direction = target.Position - launchOrigin
	if direction.Magnitude == 0 then
		direction = ball.CFrame.LookVector
	end
	direction = direction.Unit
	local spawnPosition = launchOrigin + direction * 2

	rocket.CFrame = CFrame.lookAt(spawnPosition, spawnPosition + direction)
	rocket.Parent = workspaceService
	rocket:SetNetworkOwner(nil)
	rocket.AssemblyLinearVelocity = direction * config.rocketSpeed

	local detonated = false
	local spawnTime = os.clock()
	local touchedConn: RBXScriptConnection? = nil
	local destroyingConn: RBXScriptConnection? = nil

	local function disconnectAll()
		if touchedConn then
			touchedConn:Disconnect()
			touchedConn = nil
		end
		if destroyingConn then
			destroyingConn:Disconnect()
			destroyingConn = nil
		end
	end

	local function explode()
		if detonated then
			return
		end

		detonated = true
		disconnectAll()

		local explosion = Instance.new("Explosion")
		explosion.BlastRadius = config.rocketBlastRadius
		explosion.BlastPressure = 0
		explosion.DestroyJointRadiusPercent = 0
		explosion.Position = rocket.Position
		explosion.Parent = workspaceService

		damageInRadius(workspaceService, rocket.Position, config.rocketBlastRadius, config.rocketBaseDamage, config.rocketKnockback)

		if rocket.Parent then
			rocket:Destroy()
		end
	end

	local function shouldIgnore(hit: Instance?): boolean
		if not hit then
			return true
		end

		if hit:IsDescendantOf(rocket) then
			return true
		end

		local model = botState.model
		if model and hit:IsDescendantOf(model) then
			return true
		end

		return false
	end

	touchedConn = rocket.Touched:Connect(function(hit)
		if detonated then
			return
		end

		if shouldIgnore(hit) then
			return
		end

		if os.clock() - spawnTime < config.rocketArmDelay then
			return
		end

		explode()
	end)

	destroyingConn = rocket.Destroying:Connect(function()
		disconnectAll()
	end)

	task.delay(config.rocketLifetime, function()
		if detonated then
			return
		end

		disconnectAll()
		if rocket.Parent then
			rocket:Destroy()
		end
	end)
	debris:AddItem(rocket, config.rocketLifetime + 1)

	table.insert(state.rockets, function()
		disconnectAll()
		if not detonated and rocket.Parent then
			rocket:Destroy()
		end
	end)

	return true
end

local function updateBot(
	state: EventState,
	botState: KillBotState,
	dt: number,
	target: BasePart?,
	config: KillBotConfig,
	workspaceService: Workspace,
	debris: Debris,
	random: Random
)
	local ball = botState.ball
	local vectorForce = botState.vectorForce
	if not ball or not ball.Parent or not vectorForce then
		return
	end

	local mass = ball.AssemblyMass
	local gravityForce = Vector3.new(0, mass * workspaceService.Gravity, 0)
	local desiredForce = gravityForce

	local velocity = ball.AssemblyLinearVelocity
	local position = ball.Position
	local desiredPosition: Vector3? = nil

	botState.holdTimer = botState.holdTimer or config.holdReadyTime
	botState.fireCooldown = math.max((botState.fireCooldown or 0) - dt, 0)
	botState.pauseTimer = math.max((botState.pauseTimer or 0) - dt, 0)

	if target and target.Parent then
		botState.wanderTimer = 0
		botState.wanderOffset = ZERO_VECTOR

		local jitterTimer = (botState.jitterTimer or 0) - dt
		if jitterTimer <= 0 then
			jitterTimer = randomInRange(random, config.jitterInterval)
			local angle = random:NextNumber(0, math.pi * 2)
			local magnitude = randomInRange(random, config.jitterMagnitude)
			botState.jitterOffset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * magnitude
		end
		botState.jitterTimer = jitterTimer

		desiredPosition = target.Position + Vector3.new(0, config.hoverHeight, 0) + (botState.jitterOffset or ZERO_VECTOR)
		if botState.homePosition then
			desiredPosition = Vector3.new(desiredPosition.X, math.max(desiredPosition.Y, botState.homePosition.Y), desiredPosition.Z)
		end

		local offset = desiredPosition - position
		local withinHoldRange = offset.Magnitude <= config.holdDistance
		if withinHoldRange then
			botState.holdTimer = math.max((botState.holdTimer or config.holdReadyTime) - dt, 0)
		else
			botState.holdTimer = config.holdReadyTime
		end

		if withinHoldRange and botState.holdTimer <= 0 and botState.fireCooldown <= 0 then
			local fired = createRocket(state, botState, target, config, workspaceService, debris)
			if fired then
				botState.fireCooldown = config.fireCooldown
				botState.pauseTimer = config.postFirePause
				botState.holdTimer = config.holdReadyTime
			end
		end
	else
		local wanderTimer = (botState.wanderTimer or 0) - dt
		local wanderOffset = botState.wanderOffset
		if wanderTimer <= 0 or not wanderOffset then
			wanderTimer = randomInRange(random, config.wanderInterval)
			local angle = random:NextNumber(0, math.pi * 2)
			local distance = randomInRange(random, config.wanderDistance)
			wanderOffset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
			botState.wanderOffset = wanderOffset
		end
		botState.wanderTimer = wanderTimer
		botState.jitterOffset = ZERO_VECTOR
		desiredPosition = (botState.homePosition or position) + wanderOffset + Vector3.new(0, config.hoverHeight, 0)
		botState.holdTimer = config.holdReadyTime
	end

	if botState.pauseTimer > 0 then
		desiredPosition = position
	end

	if desiredPosition then
		local offset = desiredPosition - position
		if offset.Magnitude > 0.5 then
			local direction = offset.Unit
			local desiredVelocity = direction * config.maxSpeed
			local steer = (desiredVelocity - velocity) * config.seekStrength
			local adjustedDt = math.max(dt, 1 / 240)
			local steeringForce = steer * mass / adjustedDt
			if steeringForce.Magnitude > config.moveForce then
				steeringForce = steeringForce.Unit * config.moveForce
			end
			desiredForce += steeringForce
		elseif velocity.Magnitude > 1 then
			local damping = -velocity * config.seekStrength
			local adjustedDt = math.max(dt, 1 / 240)
			local dampingForce = damping * mass / adjustedDt
			if dampingForce.Magnitude > config.moveForce then
				dampingForce = dampingForce.Unit * config.moveForce
			end
			desiredForce += dampingForce
		end
	end

	vectorForce.Force = desiredForce
	updateAlignment(botState)
end

local function spawnBot(index: number, origin: Vector3, config: KillBotConfig, workspaceService: Workspace): KillBotState
	local model = Instance.new("Model")
	model.Name = string.format("KillBot_%d", index)

	local ball = Instance.new("Part")
	ball.Name = "Ball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(6, 6, 6)
	ball.Material = Enum.Material.Neon
	ball.Color = Color3.fromRGB(200, 200, 255)
	ball.CanCollide = false
	ball.CanTouch = false
	ball.CanQuery = false
	ball.Anchored = false
	local spawnPosition = origin + Vector3.new(0, config.spawnHeightOffset + (index - 1) * config.spawnHeightStep, 0)
	ball.CFrame = CFrame.new(spawnPosition)
	ball.Parent = model
	model.PrimaryPart = ball
	model.Parent = workspaceService

	local attachment = Instance.new("Attachment")
	attachment.Name = "RootAttachment"
	attachment.Parent = ball

	local vectorForce = Instance.new("VectorForce")
	vectorForce.Name = "MoveForce"
	vectorForce.Attachment0 = attachment
	vectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
	vectorForce.ApplyAtCenterOfMass = true
	vectorForce.Force = ZERO_VECTOR
	vectorForce.Parent = ball

	local align = Instance.new("AlignOrientation")
	align.Name = "Align"
	align.Attachment0 = attachment
	align.Responsiveness = 50
	align.MaxTorque = math.huge
	align.PrimaryAxisOnly = false
	align.Parent = ball

	ball:SetNetworkOwner(nil)

	local botState: KillBotState = {
		model = model,
		ball = ball,
		attachment = attachment,
		vectorForce = vectorForce,
		align = align,
		homePosition = spawnPosition,
		currentTarget = nil,
		targetTimer = nil,
		jitterOffset = ZERO_VECTOR,
		jitterTimer = 0,
		wanderOffset = ZERO_VECTOR,
		wanderTimer = 0,
		holdTimer = config.holdReadyTime,
		fireCooldown = 0,
		pauseTimer = 0,
		lastFire = 0,
	}

	model.Destroying:Connect(function()
		botState.ball = nil
	end)

	return botState
end

function KillBotEvent.create(deps: Dependencies)
	local config = DEFAULT_CONFIG
	local random = Random.new()

	return {
		id = "KillBot",
		displayName = "KillBot🤖",
		onRoundPrepared = function(context)
			local state: EventState = {
				bots = {},
				rockets = {},
				heartbeatConn = nil,
			}
			context.state.KillBot = state

			local mapCFrame = select(1, deps.getActiveMapBounds())
			local origin = mapCFrame.Position

			for index = 1, 3 do
				local bot = spawnBot(index, origin, config, deps.Workspace)
				table.insert(state.bots, bot)
			end

			state.heartbeatConn = deps.RunService.Heartbeat:Connect(function(dt)
				if not deps.isRoundActive(context.roundId) then
					return
				end

				local targets = gatherTargets(deps)
				for _, bot in ipairs(state.bots) do
					if not bot.ball or not bot.ball.Parent then
						continue
					end

					local selectedTarget = pickTarget(bot, dt, targets, config, deps.Workspace, random)
					updateBot(state, bot, dt, selectedTarget, config, deps.Workspace, deps.Debris, random)
				end
			end)
		end,
		onRoundEnded = function(context)
			local state = context.state.KillBot :: EventState?
			if not state then
				return
			end

			if state.heartbeatConn then
				state.heartbeatConn:Disconnect()
				state.heartbeatConn = nil
			end

			for _, bot in ipairs(state.bots) do
				if bot.model and bot.model.Parent then
					bot.model:Destroy()
				elseif bot.ball and bot.ball.Parent then
					bot.ball:Destroy()
				end
			end

			for _, cleanup in ipairs(state.rockets) do
				local ok, err = pcall(cleanup)
				if not ok then
					warn("KillBot rocket cleanup error", err)
				end
			end

			state.bots = {}
			state.rockets = {}
			context.state.KillBot = nil
		end,
	}
end

return KillBotEvent

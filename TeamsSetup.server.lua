registerSpecialEvent({
		id = "KillBot",
		displayName = "Killbot🤖",
		onRoundPrepared = function(context)
			local state = { bots = {}, rockets = {}, heartbeatConn = nil }
			context.state.KillBot = state

			local cf = getActiveMapBounds()
			local arenaCenter = cf.Position
			local rng = Random.new()

			-- Bounds (X/Z = Sudden Death storm; Y = +100..+200)
			local function currentBounds()
				local stormSize = getStormHorizontalSize()
				local halfX, halfZ = stormSize.X * 0.5, stormSize.Y * 0.5
				local minY, maxY = arenaCenter.Y + 100, arenaCenter.Y + 200
				return halfX, halfZ, minY, maxY
			end

			local function clampToBounds(pos: Vector3)
				local halfX, halfZ, minY, maxY = currentBounds()
				return Vector3.new(
					math.clamp(pos.X, arenaCenter.X - halfX, arenaCenter.X + halfX),
					math.clamp(pos.Y, minY, maxY),
					math.clamp(pos.Z, arenaCenter.Z - halfZ, arenaCenter.Z + halfZ)
				)
			end

			local function randomPointInBounds()
				local halfX, halfZ, minY, maxY = currentBounds()
				return Vector3.new(
					rng:NextNumber(arenaCenter.X - halfX, arenaCenter.X + halfX),
					rng:NextNumber(minY, maxY),
					rng:NextNumber(arenaCenter.Z - halfZ, arenaCenter.Z + halfZ)
				)
			end

			-- Palette for sphere color
			local colors = {
				Color3.fromRGB(255,75,75),
				Color3.fromRGB(75,255,140),
				Color3.fromRGB(75,160,255),
				Color3.fromRGB(255,200,85),
				Color3.fromRGB(200,110,255),
			}

			-- Rocket params
			local ROCKET_SPEED = 75
			local ROCKET_LIFETIME = 10
			local ROCKET_BLAST_RADIUS = 12
			local ROCKET_BASE_DAMAGE = 55
			local ROCKET_KNOCKBACK = 85

			local function damageInRadius(center: Vector3, radius: number)
				local params = OverlapParams.new()
				local parts = Workspace:GetPartBoundsInRadius(center, radius, params)
				for _, part in ipairs(parts) do
					local parent = part.Parent
					if not parent then continue end
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
								local dmg = math.clamp(ROCKET_BASE_DAMAGE * (1 - (distance / radius)), 10, ROCKET_BASE_DAMAGE)
								humanoid:TakeDamage(dmg)
								local knock = (hrp.Position - center).Unit * ROCKET_KNOCKBACK
								hrp.AssemblyLinearVelocity += knock
							end
						end
					end
				end
			end

			local function buildRocketModel(originCF: CFrame)
				local prefab = ReplicatedStorage:FindFirstChild("KillBotRocket")
				local model: Model
				local root: BasePart

				if prefab and prefab:IsA("Model") then
					model = prefab:Clone()
					model.Name = "KillBotRocket"
					model:PivotTo(originCF)
					model.Parent = Workspace
					root = model:FindFirstChildWhichIsA("BasePart") or Instance.new("Part")
				else
					model = Instance.new("Model")
					model.Name = "KillBotRocket"

					local body = Instance.new("Part")
					body.Name = "Body"
					body.Size = Vector3.new(0.6, 0.6, 2.6)
					body.Material = Enum.Material.Metal
					body.Color = Color3.fromRGB(180,180,180)
					body.CFrame = originCF
					body.CanCollide = false
					body.Parent = model

					local tip = Instance.new("WedgePart")
					tip.Name = "Tip"
					tip.Size = Vector3.new(0.6, 0.6, 0.8)
					tip.Material = Enum.Material.Neon
					tip.Color = Color3.fromRGB(255,80,80)
					tip.CanCollide = false
					tip.CFrame = originCF * CFrame.new(0,0,-1.7) * CFrame.Angles(0, math.pi, 0)
					tip.Parent = model

					local weld = Instance.new("WeldConstraint")
					weld.Part0 = body
					weld.Part1 = tip
					weld.Parent = body

					model.PrimaryPart = body
					model:PivotTo(originCF)
					model.Parent = Workspace
					root = body
				end

				root.CanCollide = false
				root.CanTouch = true
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
				root:SetNetworkOwner(nil)
				return model, root
			end

			local function createRocket(botState, targetHrp: BasePart)
				local origin = botState.ball and botState.ball.CFrame or CFrame.new(targetHrp.Position)
				local model, root = buildRocketModel(origin)

				local dir = (targetHrp.Position - root.Position).Unit
				local bv = Instance.new("BodyVelocity")
				bv.MaxForce = Vector3.new(1e6,1e6,1e6)
				bv.Velocity = dir * ROCKET_SPEED
				bv.Parent = root

				-- orient to velocity each frame (fly straight)
				local orientConn
				orientConn = RunService.Heartbeat:Connect(function()
					if not root or not root.Parent then
						if orientConn then orientConn:Disconnect() end
						return
					end
					local v = bv.Velocity
					if v.Magnitude > 0.1 then
						root.CFrame = CFrame.new(root.Position, root.Position + v)
					end
				end)

				-- simple trail
				local trail = Instance.new("Trail")
				trail.Attachment0 = Instance.new("Attachment", root)
				trail.Attachment1 = Instance.new("Attachment", root)
				trail.Attachment0.Position = Vector3.new(0,0,  1.3)
				trail.Attachment1.Position = Vector3.new(0,0, -1.3)
				trail.Lifetime = 0.2
				trail.Parent = root

				local alive = true
				local function explode()
					if not alive then return end
					alive = false
					damageInRadius(root.Position, ROCKET_BLAST_RADIUS)
					if model.Parent then model:Destroy() end
				end

				local tConn = root.Touched:Connect(function(hit)
					if hit and hit:IsA("BasePart") and hit ~= botState.ball then
						explode()
						if tConn then tConn:Disconnect() end
					end
				end)

				table.insert(state.rockets, function()
					if orientConn then orientConn:Disconnect() end
					if tConn then tConn:Disconnect() end
					if model and model.Parent then model:Destroy() end
				end)

				task.delay(ROCKET_LIFETIME, explode)
			end

			-- Tunables
			local BOT_COUNT = 3
			local TRAVEL_MAX_SPEED = 85
			local TRAVEL_ACCEL_GAIN = 75
			local ARRIVE_EPS = 4
			local HOLD_TIME_RANGE = Vector2.new(0.7, 2.0)
			local FIRE_INTERVAL = 0.65
			local WAYPOINT_TIMEOUT = 6.0

			local function pickNewWaypoint()
				-- sometimes bias toward a random player's position
				if rng:NextInteger(1,3) == 1 then
					local candidates = getNeutralParticipantRecords()
					if typeof(candidates) ~= "table" then candidates = {} end
					if #candidates > 0 then
						local pick = candidates[rng:NextInteger(1, #candidates)]
						local character = pick.player and pick.player.Character
						if character then
							local hrp = character:FindFirstChild("HumanoidRootPart")
							if hrp then
								return clampToBounds(hrp.Position + Vector3.new(
									rng:NextNumber(-12,12),
									rng:NextNumber(-6,6),
									rng:NextNumber(-12,12)
								))
							end
						end
					end
				end
				return randomPointInBounds()
			end

			local function spawnBot(index)
				local model = Instance.new("Model")
				model.Name = "KillBot_" .. tostring(index)

				local ball = Instance.new("Part")
				ball.Name = "KillBall"
				ball.Shape = Enum.PartType.Ball
				ball.Material = Enum.Material.SmoothPlastic
				ball.Size = Vector3.new(3,3,3)
				ball.Color = colors[rng:NextInteger(1, #colors)]
				ball.CanCollide = false
				ball.CanQuery = true
				ball.CastShadow = true
				ball.Transparency = 0.05
				ball.Position = randomPointInBounds()
				ball.Parent = model

				local attachment = Instance.new("Attachment")
				attachment.Name = "Root"
				attachment.Parent = ball

				local vectorForce = Instance.new("VectorForce")
				vectorForce.Name = "MoveForce"
				vectorForce.Attachment0 = attachment
				vectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
				vectorForce.Force = Vector3.zero
				vectorForce.ApplyAtCenterOfMass = true
				vectorForce.Parent = ball

				local align = Instance.new("AlignOrientation")
				align.Name = "Align"
				align.Attachment0 = attachment
				align.Responsiveness = 50
				align.MaxTorque = math.huge
				align.PrimaryAxisOnly = false
				align.Parent = ball

				model.Parent = Workspace
				ball:SetNetworkOwner(nil)

				local bot = {
					model = model,
					ball = ball,
					attachment = attachment,
					vectorForce = vectorForce,
					align = align,
					phase = "travel",
					targetPos = pickNewWaypoint(),
					nextFire = 0,
					holdTimer = 0,
					waypointTimer = 0,
					phaseOffset = math.rad(rng:NextInteger(0, 360)),
				}

				model.Destroying:Connect(function()
					bot.ball = nil
				end)

				table.insert(state.bots, bot)
			end

			for i = 1, BOT_COUNT do
				spawnBot(i)
			end

			state.heartbeatConn = RunService.Heartbeat:Connect(function(dt)
				if not roundInProgress or context.roundId ~= currentRoundId then
					return
				end

				for _, bot in ipairs(state.bots) do
					local ball = bot.ball
					if not ball or not ball.Parent then
						continue
					end

					bot.targetPos = clampToBounds(bot.targetPos)

					if bot.phase == "travel" then
						bot.waypointTimer += dt
						local offset = bot.targetPos - ball.Position
						local arrived = (offset.Magnitude <= ARRIVE_EPS) or (bot.waypointTimer > WAYPOINT_TIMEOUT)

						if arrived then
							bot.vectorForce.Force = Vector3.new(0, Workspace.Gravity * ball.AssemblyMass, 0)
							bot.phase = "hold"
							bot.holdTimer = rng:NextNumber(HOLD_TIME_RANGE.X, HOLD_TIME_RANGE.Y)
							bot.nextFire = 0
							bot.waypointTimer = 0
						else
							local dir = offset.Unit
							local bob = math.sin(os.clock() * 4 + (bot.phaseOffset or 0)) * 2.0
							local desiredVel = Vector3.new(dir.X, dir.Y, dir.Z) * TRAVEL_MAX_SPEED + Vector3.new(0, bob, 0)
							local accel = (desiredVel - ball.AssemblyLinearVelocity) * TRAVEL_ACCEL_GAIN
							accel += Vector3.new(0, Workspace.Gravity, 0)
							bot.vectorForce.Force = accel * ball.AssemblyMass
						end
					else
						bot.vectorForce.Force = Vector3.new(0, Workspace.Gravity * ball.AssemblyMass, 0)

						bot.holdTimer = math.max((bot.holdTimer or 0) - dt, 0)
						bot.nextFire = math.max((bot.nextFire or 0) - dt, 0)
						if bot.nextFire <= 0 then
							local candidates = getNeutralParticipantRecords()
							if typeof(candidates) ~= "table" then candidates = {} end
							if #candidates > 0 then
								local pick = candidates[rng:NextInteger(1, #candidates)]
								local character = pick.player and pick.player.Character
								if character then
									local hrp = character:FindFirstChild("HumanoidRootPart")
									local humanoid = pick.humanoid or character:FindFirstChildOfClass("Humanoid")
									if hrp and humanoid and humanoid.Health > 0 then
										createRocket(bot, hrp)
										bot.nextFire = FIRE_INTERVAL
									end
								end
							end
						end

						if bot.holdTimer <= 0 then
							bot.phase = "travel"
							bot.targetPos = pickNewWaypoint()
							bot.waypointTimer = 0
						end
					end
				end
			end)
		end,

		onRoundEnded = function(context)
			local state = context.state.KillBot
			if not state then return end

			if state.heartbeatConn then
				state.heartbeatConn:Disconnect(); state.heartbeatConn = nil
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
	})

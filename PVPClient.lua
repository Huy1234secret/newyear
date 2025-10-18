--!strict
-- === Movement reset helper to stop stuck-forward after respawn ===
local function resetMovementState(humanoid: Humanoid?)
	local Players = game:GetService("Players")
	local CAS = game:GetService("ContextActionService")

	-- Unbind any custom actions that may block default controls
	pcall(function()
		CAS:UnbindAction("DisableMovement")
		CAS:UnbindAction("Inverted_Move")
		CAS:UnbindAction("Inverted_Look")
	end)

	-- Soft reset PlayerModule controls
	local okPM, controls = pcall(function()
		local player = Players.LocalPlayer
		local ps = player and player:FindFirstChildOfClass("PlayerScripts")
		local pm = ps and ps:FindFirstChild("PlayerModule")
		if not pm then return nil end
		local PM = require(pm)
		return PM:GetControls()
	end)
	if okPM and controls then
		pcall(function() controls:Disable() end)
	end

	-- Nudge humanoid state & clear movement intents
	if humanoid and humanoid.Parent then
		pcall(function()
			-- Zero the movement vector and suppress jump for a tick
			humanoid:Move(Vector3.new(0,0,0), true)
			humanoid.Jump = false
			-- Sometimes RunningNoPhysics -> Running helps clear residual velocity intents
			humanoid:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
			task.wait(0.02)
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end)
	end

	-- Re-enable controls after a tiny delay so PlayerModule rebinds default actions
	task.wait(0.03)
	if okPM and controls then
		pcall(function() controls:Enable() end)
	end
end

-- Place this LocalScript in StarterPlayerScripts so each player can see match updates.


-- === Safety helper: hard-enable Roblox default controls (idempotent) ===
local function hardEnableDefaultControls()
	local player = game:GetService("Players").LocalPlayer
	local playerScripts = player:FindFirstChildOfClass("PlayerScripts")
	if not playerScripts then return end
	local pm = playerScripts:FindFirstChild("PlayerModule")
	if not pm then return end
	local ok, PlayerModule = pcall(function() return require(pm) end)
	if not ok or not PlayerModule then return end
	local controlsOk, controls = pcall(function() return PlayerModule:GetControls() end)
	if controlsOk and controls then
		pcall(function() controls:Enable() end)
	end
	-- Also release any ContextAction "Disable" binds commonly used by inverted code
	pcall(function()
		game:GetService("ContextActionService"):UnbindAction("DisableMovement")
		game:GetService("ContextActionService"):UnbindAction("Inverted_Move")
		game:GetService("ContextActionService"):UnbindAction("Inverted_Look")
	end)
end
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local localPlayer = Players.LocalPlayer
if not localPlayer then
	return
end

local remotesFolder = ReplicatedStorage:WaitForChild("PVPRemotes", 10)
if not remotesFolder or not remotesFolder:IsA("Folder") then
	return
end

local statusRemote = remotesFolder:WaitForChild("StatusUpdate", 10)
if not statusRemote or not statusRemote:IsA("RemoteEvent") then
	return
end

local toggleInventorySlotRemote: RemoteEvent? = nil

local function setToggleInventoryRemote(candidate: Instance?)
	if candidate and candidate:IsA("RemoteEvent") and candidate.Name == "ToggleInventorySlot" then
		toggleInventorySlotRemote = candidate
	end
end

local existingToggleRemote = remotesFolder:FindFirstChild("ToggleInventorySlot")
if existingToggleRemote and existingToggleRemote:IsA("RemoteEvent") then
	toggleInventorySlotRemote = existingToggleRemote
else
	local foundToggle = remotesFolder:WaitForChild("ToggleInventorySlot", 5)
	setToggleInventoryRemote(foundToggle)
end

remotesFolder.ChildAdded:Connect(function(child)
	setToggleInventoryRemote(child)
end)

remotesFolder.ChildRemoved:Connect(function(child)
	if child == toggleInventorySlotRemote then
		toggleInventorySlotRemote = nil
	end
end)

local playerGui = localPlayer:WaitForChild("PlayerGui")

local isTouchDevice = UserInputService.TouchEnabled

if isTouchDevice then
	StarterGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
end

local UI_CONFIG = {
	DEFAULT_BACKGROUND_COLOR = Color3.fromRGB(28, 32, 45),
	DEFAULT_BACKGROUND_TRANSPARENCY = 0.15,
	DEFAULT_TEXT_SIZE = if isTouchDevice then 22 else 26,
	EMPHASIZED_TEXT_SIZE = if isTouchDevice then 28 else 32,
	USE_CUSTOM_INVENTORY_UI = false, -- Disable the bespoke 10-slot bar in favor of Roblox's default backpack UI
	MAP_LABEL_WIDTH = if isTouchDevice then 140 else 160,
	MAP_LABEL_PADDING = if isTouchDevice then 18 else 24,
}

local mapDisplayNames = {
	Crossroad = "Crossroad",
	SFOTH = "SFOTH",
	ChaosCanyon = "Chaos Canyon",
	Doomspire = "Doomspire",
}

local function createInstance(className: string, props: {[string]: any})
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		if key == "Parent" then
			instance.Parent = value
		else
			instance[key] = value
		end
	end
	return instance
end

local playerModule: any = nil
local playerControls: any = nil

local function setBackpackCoreGuiEnabled(enabled: boolean)
	local success, result = pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, enabled)
	end)

	if not success then
		warn("Failed to set backpack CoreGui state:", result)
	end
end

if UI_CONFIG.USE_CUSTOM_INVENTORY_UI then
	setBackpackCoreGuiEnabled(false)

	local function ensureBackpackDisabled()
		local success, enabled = pcall(function()
			return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
		end)

		if success and enabled then
			setBackpackCoreGuiEnabled(false)
		end
	end

	RunService.Heartbeat:Connect(ensureBackpackDisabled)
else
	setBackpackCoreGuiEnabled(true)
end

local function getPlayerControls()
	if playerControls then
		return playerControls
	end

	local success, moduleOrErr = pcall(function()
		local playerScripts = localPlayer:WaitForChild("PlayerScripts", 5)
		if not playerScripts then
			return nil
		end
		local moduleScript = playerScripts:FindFirstChild("PlayerModule")
		if not moduleScript then
			moduleScript = playerScripts:WaitForChild("PlayerModule", 5)
		end
		if not moduleScript then
			return nil
		end
		return require(moduleScript)
	end)

	if not success or not moduleOrErr then
		warn("Unable to load PlayerModule for inverted controls.")
		return nil
	end

	playerModule = moduleOrErr
	local controls = nil
	local ok, result = pcall(function()
		return playerModule:GetControls()
	end)
	if ok then
		controls = result
	end

	playerControls = controls
	return controls
end

local GEAR_CURSOR_IMAGE_ASSET = "rbxassetid://9925913476"
local currentCursorImageAsset = GEAR_CURSOR_IMAGE_ASSET
local DEFAULT_WALK_SPEED = 16

local Z_INDEX = {
	INVENTORY_BASE = 60,
}

Z_INDEX.SLOT_CONTENT_BASE = Z_INDEX.INVENTORY_BASE + 1
Z_INDEX.SLOT_ICON = Z_INDEX.SLOT_CONTENT_BASE + 1
Z_INDEX.SLOT_TEXT = Z_INDEX.SLOT_CONTENT_BASE + 2
Z_INDEX.SLOT_BUTTON = Z_INDEX.SLOT_CONTENT_BASE + 4
Z_INDEX.SPRINT_CONTAINER = Z_INDEX.SLOT_BUTTON + 10
Z_INDEX.SPRINT_BAR = Z_INDEX.SPRINT_CONTAINER + 1
Z_INDEX.SPRINT_TEXT = Z_INDEX.SPRINT_CONTAINER + 2

type UiRefs = {
	energyBarFill: Frame?,
	energyTextLabel: TextLabel?,
	sprintStatusLabel: TextLabel?,
	centerCursorImage: ImageLabel?,
	mapLabelContainer: Frame?,
	mapLabelStroke: UIStroke?,
	mapLabel: TextLabel?,
	eventLabel: TextLabel?,
	statusFrame: Frame?,
	hotTouchStatusLabel: TextLabel?,
	inventoryFrame: Frame?,
	inventoryToggleButton: ImageButton?,
	sprintActionButton: ImageButton?,
}

type StatusUI = {
	frame: Frame,
	label: TextLabel,
	labelStroke: UIStroke,
	stroke: UIStroke,
}

type SpecialEventUI = {
	frame: Frame,
	stroke: UIStroke,
	gradient: UIGradient,
	header: TextLabel,
	title: TextLabel,
	scale: UIScale,
}

type SprintDefaults = {
	backgroundColor: Color3,
	backgroundTransparency: number,
	strokeColor: Color3,
	strokeTransparency: number,
	energyBarFillColor: Color3,
	energyTextColor: Color3,
	energyGradientColor: ColorSequence,
}

type SprintUI = {
	container: Frame,
	background: Frame,
	backgroundStroke: UIStroke,
	energyFillGradient: UIGradient,
	basePosition: UDim2,
	baseRotation: number,
	defaults: SprintDefaults,
}

type InventoryState = {
	basePosition: UDim2,
	baseRotation: number,
	setVisibility: ((boolean) -> ())?,
}

type LayoutConfig = {
	slotPadding: number,
	slotSize: number,
	inventoryWidth: number,
	inventoryHeight: number,
	inventoryBottomMargin: number,
	energyLabelHeight: number,
	energyBarHeight: number,
	energyTopPadding: number,
	energyBottomPadding: number,
	energySpacing: number,
	sprintContainerHeight: number,
	energyTextWidth: number,
	sprintBottomOffset: number,
}

local uiRefs: UiRefs = {
	energyBarFill = nil,
	energyTextLabel = nil,
	sprintStatusLabel = nil,
	centerCursorImage = nil,
	mapLabelContainer = nil,
	mapLabelStroke = nil,
	mapLabel = nil,
	eventLabel = nil,
	inventoryFrame = nil,
	inventoryToggleButton = nil,
	sprintActionButton = nil,
}

local inventoryVisible = true
local inventoryAutoOpened = false
local setInventoryVisibility: (boolean) -> ()

local hotTouchActive = false
local currentHotTouchHolderId: number? = nil

local function refreshHotTouchStatusVisibility()
	local label = uiRefs.hotTouchStatusLabel
	if not label then
		return
	end

	local statusFrame = uiRefs.statusFrame
	if statusFrame and not statusFrame.Visible then
		label.Visible = false
		return
	end

	if not hotTouchActive or label.Text == "" then
		label.Visible = false
	else
		label.Visible = true
	end
end

local function setHotTouchStatusText(text: string?)
	local label = uiRefs.hotTouchStatusLabel
	if not label then
		return
	end

	if text and text ~= "" then
		label.Text = text
	else
		label.Text = ""
	end

	refreshHotTouchStatusVisibility()
end

local sprintInteraction = {
	noSprintPart = nil :: BasePart?,
	actionBound = false,
}

local function updateNoSprintPartReference()
	local found = Workspace:FindFirstChild("NoSprintPart", true)
	if found and found:IsA("BasePart") then
		sprintInteraction.noSprintPart = found
	else
		sprintInteraction.noSprintPart = nil
	end
end

updateNoSprintPartReference()

Workspace.DescendantAdded:Connect(function(descendant)
	if descendant.Name == "NoSprintPart" and descendant:IsA("BasePart") then
		sprintInteraction.noSprintPart = descendant
	end
end)

Workspace.DescendantRemoving:Connect(function(descendant)
	if descendant == sprintInteraction.noSprintPart then
		sprintInteraction.noSprintPart = nil
	end
end)

local function isPointInsidePart(part: BasePart, point: Vector3): boolean
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local halfSize = part.Size * 0.5
	return math.abs(localPoint.X) <= halfSize.X + 0.05
		and math.abs(localPoint.Y) <= halfSize.Y + 0.05
		and math.abs(localPoint.Z) <= halfSize.Z + 0.05
end

local function getHumanoidRootPart(humanoid: Humanoid): BasePart?
	local rootPart = humanoid.RootPart
	if rootPart and rootPart:IsA("BasePart") then
		return rootPart
	end

	local character = humanoid.Parent
	if character then
		local candidate = character:FindFirstChild("HumanoidRootPart")
		if candidate and candidate:IsA("BasePart") then
			return candidate
		end
	end

	return nil
end

type GuiButton = TextButton | ImageButton

type InventorySlotUI = {
	frame: Frame,
	stroke: UIStroke,
	icon: ImageLabel,
	label: TextLabel,
	numberLabel: TextLabel,
	button: GuiButton,
}

local inventorySlots: {InventorySlotUI} = {}
local slotToolMapping: {Tool?} = {}

local existingGui = playerGui:FindFirstChild("PVPStatusGui")
if existingGui then
	existingGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PVPStatusGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 5
screenGui.Parent = playerGui

local function calculateLayout(isTouch: boolean): LayoutConfig
	local viewportWidth = 1024
	local camera = Workspace.CurrentCamera
	if camera then
		viewportWidth = camera.ViewportSize.X
	end

	local slotPadding = if isTouch then 2 else 6
	local calculatedAvailableWidth = if isTouch
		then math.max(280, math.min(viewportWidth - 40, 540))
		else math.clamp(viewportWidth * 0.5, 520, 780)
	local slotSize = math.clamp(
		math.floor((calculatedAvailableWidth - 24 - slotPadding * 9) / 10),
		if isTouch then 24 else 40,
		if isTouch then 40 else 56
	)
	local inventoryWidth = slotSize * 10 + slotPadding * 9 + 24
	local inventoryHeight = slotSize + 20
	local inventoryBottomMargin = if isTouch then math.max(64, math.floor(slotSize * 1.4)) else 0
	local energyLabelHeight = if isTouch then 16 else 18
	local energyBarHeight = if isTouch then 12 else 14
	local energyTopPadding = if isTouch then 2 else 3
	local energyBottomPadding = if isTouch then 4 else 5
	local energySpacing = if isTouch then 3 else 4
	local sprintContainerHeight = energyTopPadding + energyLabelHeight + energySpacing + energyBarHeight + energyBottomPadding
	local energyTextWidth = if isTouch then 80 else 92
	local estimatedInventoryHeight
	if UI_CONFIG.USE_CUSTOM_INVENTORY_UI then
		estimatedInventoryHeight = inventoryHeight
	elseif isTouch then
		estimatedInventoryHeight = math.max(48, math.floor(slotSize * 1.15))
	else
		-- When Roblox's default backpack UI is enabled on desktop, the hotbar occupies
		-- a fixed space near the bottom of the screen. Nudge the sprint container up so
		-- the custom energy meter always renders above the built-in inventory buttons.
		estimatedInventoryHeight = math.max(60, math.floor(slotSize * 1.1))
	end
	local sprintBottomOffset = inventoryBottomMargin + estimatedInventoryHeight

	return {
		slotPadding = slotPadding,
		slotSize = slotSize,
		inventoryWidth = inventoryWidth,
		inventoryHeight = inventoryHeight,
		inventoryBottomMargin = inventoryBottomMargin,
		energyLabelHeight = energyLabelHeight,
		energyBarHeight = energyBarHeight,
		energyTopPadding = energyTopPadding,
		energyBottomPadding = energyBottomPadding,
		energySpacing = energySpacing,
		sprintContainerHeight = sprintContainerHeight,
		energyTextWidth = energyTextWidth,
		sprintBottomOffset = sprintBottomOffset,
	}
end

local function createStatusUI(parent: ScreenGui, isTouch: boolean, refs: UiRefs): StatusUI
	local frame = Instance.new("Frame")
	frame.Name = "StatusFrame"
	frame.Size = UDim2.fromOffset(isTouch and 220 or 260, isTouch and 52 or 56)
	frame.Position = UDim2.new(0.5, 0, 0, 32)
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.BackgroundColor3 = UI_CONFIG.DEFAULT_BACKGROUND_COLOR
	frame.BackgroundTransparency = UI_CONFIG.DEFAULT_BACKGROUND_TRANSPARENCY
	frame.Visible = false
	frame.ZIndex = 10
	frame.Parent = parent

	createInstance("UICorner", {
		CornerRadius = UDim.new(0, 12),
		Parent = frame,
	})

	local stroke = createInstance("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = 2,
		Color = Color3.fromRGB(120, 135, 200),
		Transparency = 0.35,
		Parent = frame,
	})

	createInstance("UIPadding", {
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
		Parent = frame,
	})

	local label = createInstance("TextLabel", {
		Name = "StatusLabel",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Font = Enum.Font.GothamBold,
		Text = "",
		TextSize = UI_CONFIG.DEFAULT_TEXT_SIZE,
		TextColor3 = Color3.fromRGB(245, 245, 255),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 11,
		Parent = frame,
	})

	local labelStroke = createInstance("UIStroke", {
		Color = Color3.fromRGB(20, 20, 35),
		Thickness = 2,
		Transparency = 0.3,
		Parent = label,
	})

	local mapLabelContainer = createInstance("Frame", {
		Name = "MapLabelContainer",
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(0, UI_CONFIG.MAP_LABEL_WIDTH + UI_CONFIG.MAP_LABEL_PADDING, 0, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(0, -UI_CONFIG.MAP_LABEL_PADDING, 0.5, 0),
		BackgroundColor3 = Color3.fromRGB(22, 26, 36),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = frame.ZIndex,
		Parent = frame,
	})

	createInstance("UICorner", {
		CornerRadius = UDim.new(0, 10),
		Parent = mapLabelContainer,
	})

	refs.mapLabelStroke = createInstance("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = 1,
		Transparency = 0.4,
		Color = Color3.fromRGB(120, 135, 200),
		Parent = mapLabelContainer,
	})

	createInstance("UIPadding", {
		PaddingLeft = UDim.new(0, math.floor(UI_CONFIG.MAP_LABEL_PADDING * 0.4)),
		PaddingRight = UDim.new(0, math.floor(UI_CONFIG.MAP_LABEL_PADDING * 0.4)),
		Parent = mapLabelContainer,
	})

	createInstance("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2),
		Parent = mapLabelContainer,
	})

	refs.mapLabel = createInstance("TextLabel", {
		Name = "MapLabel",
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamSemibold,
		Text = "",
		TextSize = math.max(12, UI_CONFIG.DEFAULT_TEXT_SIZE - 8),
		TextColor3 = Color3.fromRGB(210, 230, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = 1,
		ZIndex = mapLabelContainer.ZIndex + 1,
		Parent = mapLabelContainer,
	})

	refs.eventLabel = createInstance("TextLabel", {
		Name = "EventLabel",
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "",
		TextSize = math.max(11, UI_CONFIG.DEFAULT_TEXT_SIZE - 10),
		TextColor3 = Color3.fromRGB(190, 210, 240),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = 2,
		ZIndex = mapLabelContainer.ZIndex + 1,
		Parent = mapLabelContainer,
	})

	refs.mapLabelContainer = mapLabelContainer
	mapLabelContainer:SetAttribute("HasMap", false)

	refs.hotTouchStatusLabel = createInstance("TextLabel", {
		Name = "HotTouchStatusLabel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 8),
		Size = UDim2.fromOffset(frame.Size.X.Offset, if isTouch then 24 else 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "",
		TextSize = if isTouch then 20 else 18,
		TextColor3 = Color3.fromRGB(255, 130, 130),
		TextStrokeTransparency = 0.4,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Visible = false,
		ZIndex = frame.ZIndex,
		Parent = parent,
	})

	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		local container = refs.mapLabelContainer
		if container then
			local hasMap = container:GetAttribute("HasMap")
			container.Visible = (hasMap == true) and frame.Visible
		end
	end)

	refs.statusFrame = frame

	return {
		frame = frame,
		label = label,
		labelStroke = labelStroke,
		stroke = stroke,
	}
end

local function createSpecialEventUI(parent: ScreenGui, isTouch: boolean): SpecialEventUI
	local frame = createInstance("Frame", {
		Name = "SpecialEventFrame",
		Size = UDim2.fromOffset(360, 160),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.35, 0),
		BackgroundColor3 = Color3.fromRGB(28, 32, 45),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 40,
		Parent = parent,
	})

	createInstance("UICorner", {
		CornerRadius = UDim.new(0, 14),
		Parent = frame,
	})

	local stroke = createInstance("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = 2,
		Color = Color3.fromRGB(120, 135, 200),
		Transparency = 0.35,
		Parent = frame,
	})

	local gradient = createInstance("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(45, 55, 80)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 32, 45)),
		}),
		Rotation = 90,
		Parent = frame,
	})

	local header = createInstance("TextLabel", {
		Name = "Header",
		Size = UDim2.new(1, -40, 0, 42),
		Position = UDim2.new(0, 20, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "- Special Round -",
		TextScaled = false,
		TextSize = if isTouch then 22 else 24,
		TextColor3 = Color3.fromRGB(245, 245, 255),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = frame.ZIndex + 1,
		Parent = frame,
	})

	local title = createInstance("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, -60, 0, 60),
		Position = UDim2.new(0, 30, 0, 70),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = "",
		TextScaled = true,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		ZIndex = frame.ZIndex + 1,
		Parent = frame,
	})

	local scale = createInstance("UIScale", {
		Name = "Scale",
		Scale = 1,
		Parent = frame,
	})

	return {
		frame = frame,
		stroke = stroke,
		gradient = gradient,
		header = header,
		title = title,
		scale = scale,
	}
end

local function createSprintUI(parent: ScreenGui, refs: UiRefs, isTouch: boolean, layout: LayoutConfig): SprintUI
	local container = createInstance("Frame", {
		Name = "SprintEnergyContainer",
		Size = UDim2.fromOffset(layout.inventoryWidth, layout.sprintContainerHeight),
		Position = UDim2.new(0.5, 0, 1, -layout.sprintBottomOffset),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		ZIndex = Z_INDEX.SPRINT_CONTAINER,
		Parent = parent,
	})

	createInstance("UIPadding", {
		PaddingTop = UDim.new(0, layout.energyTopPadding),
		PaddingBottom = UDim.new(0, layout.energyBottomPadding),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = container,
	})

	refs.sprintStatusLabel = createInstance("TextLabel", {
		Name = "SprintStatus",
		Size = UDim2.new(1, -8, 0, layout.energyLabelHeight),
		Position = UDim2.new(0.5, 0, 0, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamSemibold,
		TextColor3 = Color3.fromRGB(210, 235, 255),
		TextSize = isTouch and 14 or 16,
		TextScaled = false,
		Text = "Sprint OFF",
		ZIndex = Z_INDEX.SPRINT_TEXT,
		Parent = container,
	})

	local background = createInstance("Frame", {
		Name = "EnergyBackground",
		Size = UDim2.new(1, -16, 0, layout.energyBarHeight),
		Position = UDim2.new(0.5, 0, 0, layout.energyLabelHeight + layout.energySpacing),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(34, 52, 82),
		BackgroundTransparency = 0.15,
		ZIndex = Z_INDEX.SPRINT_BAR,
		Parent = container,
	})

	createInstance("UICorner", {
		CornerRadius = UDim.new(0, 10),
		Parent = background,
	})

	local backgroundStroke = createInstance("UIStroke", {
		Thickness = 1.5,
		Transparency = 0.35,
		Color = Color3.fromRGB(80, 130, 200),
		Parent = background,
	})

	local energyFillContainer = createInstance("Frame", {
		Name = "EnergyFill",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.new(1, -(layout.energyTextWidth + 20), 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = Z_INDEX.SPRINT_BAR,
		Parent = background,
	})

	local energyFillBackground = createInstance("Frame", {
		Name = "EnergyFillBackground",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(52, 80, 130),
		BackgroundTransparency = 0.3,
		ZIndex = Z_INDEX.SPRINT_BAR,
		Parent = energyFillContainer,
	})

	createInstance("UICorner", {
		CornerRadius = UDim.new(0, 7),
		Parent = energyFillBackground,
	})

	refs.energyBarFill = createInstance("Frame", {
		Name = "EnergyFillValue",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(80, 190, 255),
		ZIndex = Z_INDEX.SPRINT_BAR + 1,
		Parent = energyFillBackground,
	})

	createInstance("UICorner", {
		CornerRadius = UDim.new(0, 7),
		Parent = refs.energyBarFill,
	})

	local energyFillGradient = createInstance("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 190, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 240, 200)),
		}),
		Parent = refs.energyBarFill,
	})

	refs.energyTextLabel = createInstance("TextLabel", {
		Name = "EnergyText",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.new(0, layout.energyTextWidth, 0, layout.energyBarHeight),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamSemibold,
		TextColor3 = Color3.fromRGB(210, 235, 255),
		TextScaled = false,
		TextSize = isTouch and 14 or 15,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Center,
		Text = "Energy 100%",
		ZIndex = Z_INDEX.SPRINT_TEXT,
		Parent = background,
	})

	refs.centerCursorImage = createInstance("ImageLabel", {
		Name = "ShiftLockCursor",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(isTouch and 40 or 48, isTouch and 40 or 48),
		Image = GEAR_CURSOR_IMAGE_ASSET,
		ZIndex = 50,
		Visible = false,
		Parent = parent,
	})

	local defaults: SprintDefaults = {
		backgroundColor = background.BackgroundColor3,
		backgroundTransparency = background.BackgroundTransparency,
		strokeColor = backgroundStroke.Color,
		strokeTransparency = backgroundStroke.Transparency,
		energyBarFillColor = refs.energyBarFill.BackgroundColor3,
		energyTextColor = refs.energyTextLabel.TextColor3,
		energyGradientColor = energyFillGradient.Color,
	}

	return {
		container = container,
		background = background,
		backgroundStroke = backgroundStroke,
		energyFillGradient = energyFillGradient,
		basePosition = container.Position,
		baseRotation = container.Rotation,
		defaults = defaults,
	}
end

local function createInventoryUI(parent: ScreenGui, refs: UiRefs, isTouch: boolean, layout: LayoutConfig): InventoryState
	local state: InventoryState = {
		basePosition = UDim2.new(0.5, 0, 1, -layout.inventoryBottomMargin),
		baseRotation = 0,
		setVisibility = nil,
	}

	if UI_CONFIG.USE_CUSTOM_INVENTORY_UI then
		refs.inventoryFrame = createInstance("Frame", {
			Name = "InventoryBar",
			AnchorPoint = Vector2.new(0.5, 1),
			Size = UDim2.fromOffset(layout.inventoryWidth, layout.inventoryHeight),
			Position = UDim2.new(0.5, 0, 1, -layout.inventoryBottomMargin),
			BackgroundTransparency = 1,
			ZIndex = Z_INDEX.INVENTORY_BASE,
			Parent = parent,
		})

		state.basePosition = refs.inventoryFrame.Position
		state.baseRotation = refs.inventoryFrame.Rotation

		local function updateInventoryToggleVisual()
			local button = refs.inventoryToggleButton
			if not button then
				return
			end

			if inventoryVisible then
				button.ImageTransparency = 0
				button.ImageColor3 = Color3.fromRGB(255, 255, 255)
			else
				button.ImageTransparency = 0.2
				button.ImageColor3 = Color3.fromRGB(200, 205, 220)
			end
		end

		state.setVisibility = function(visible: boolean)
			inventoryVisible = visible

			if refs.inventoryFrame then
				refs.inventoryFrame.Visible = visible
			end

			updateInventoryToggleVisual()
		end

		if isTouch then
			refs.inventoryToggleButton = createInstance("ImageButton", {
				Name = "InventoryToggleButton",
				AnchorPoint = Vector2.new(0.5, 1),
				Size = UDim2.fromOffset(math.max(56, math.floor(layout.slotSize * 1.1)), math.max(56, math.floor(layout.slotSize * 1.1))),
				Position = UDim2.new(0.5, 0, 1, -8),
				BackgroundTransparency = 1,
				AutoButtonColor = true,
				Image = "rbxasset://textures/ui/Backpack/BackpackButton.png",
				ImageColor3 = Color3.fromRGB(255, 255, 255),
				ZIndex = 50,
				Parent = parent,
			})

			refs.inventoryToggleButton.Activated:Connect(function()
				if state.setVisibility then
					state.setVisibility(not inventoryVisible)
				end
				inventoryAutoOpened = true
			end)
		end

		if state.setVisibility then
			state.setVisibility(not isTouch)
		end

		local slotContainer = createInstance("Frame", {
			Name = "SlotContainer",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Parent = refs.inventoryFrame,
		})

		createInstance("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 0),
			Parent = slotContainer,
		})

		createInstance("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, layout.slotPadding),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = slotContainer,
		})

		for slotIndex = 1, 10 do
			local slotUI = {}
			slotUI.frame = createInstance("Frame", {
				Name = string.format("Slot_%d", slotIndex),
				Size = UDim2.fromOffset(layout.slotSize, layout.slotSize),
				BackgroundColor3 = Color3.fromRGB(24, 28, 40),
				BackgroundTransparency = 0.2,
				ZIndex = Z_INDEX.SLOT_CONTENT_BASE,
				LayoutOrder = slotIndex,
				Parent = slotContainer,
			})

			createInstance("UICorner", {
				CornerRadius = UDim.new(0, 8),
				Parent = slotUI.frame,
			})

			slotUI.stroke = createInstance("UIStroke", {
				Color = Color3.fromRGB(80, 100, 150),
				Thickness = 1.5,
				Transparency = 0.3,
				Parent = slotUI.frame,
			})

			local nameLabelHeight = math.max(12, math.floor(layout.slotSize * 0.35))
			local iconPadding = math.max(8, math.floor(layout.slotSize * 0.3))

			slotUI.numberLabel = createInstance("TextLabel", {
				Name = "KeyLabel",
				AnchorPoint = Vector2.new(0, 0),
				Size = UDim2.new(0, 24, 0, 18),
				Position = UDim2.new(0, 0, 0, 0),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamSemibold,
				TextColor3 = Color3.fromRGB(140, 150, 180),
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Text = slotIndex == 10 and "0" or tostring(slotIndex),
				ZIndex = Z_INDEX.SLOT_TEXT,
				Parent = slotUI.frame,
			})

			slotUI.icon = createInstance("ImageLabel", {
				Name = "Icon",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -12, 0, math.max(0, layout.slotSize - (nameLabelHeight + iconPadding))),
				Position = UDim2.new(0.5, 0, 0, math.floor(iconPadding * 0.5)),
				AnchorPoint = Vector2.new(0.5, 0),
				Image = "",
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = Z_INDEX.SLOT_ICON,
				Parent = slotUI.frame,
			})

			slotUI.label = createInstance("TextLabel", {
				Name = "Name",
				BackgroundTransparency = 1,
				Position = UDim2.new(0.5, 0, 1, -4),
				AnchorPoint = Vector2.new(0.5, 1),
				Size = UDim2.new(1, -8, 0, nameLabelHeight),
				Font = Enum.Font.Gotham,
				Text = "",
				TextColor3 = Color3.fromRGB(200, 210, 230),
				TextSize = math.max(10, math.floor(nameLabelHeight * 0.65)),
				TextScaled = false,
				TextWrapped = true,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = Z_INDEX.SLOT_TEXT,
				Parent = slotUI.frame,
			})

			slotUI.button = createInstance("ImageButton", {
				Name = "SelectButton",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, 0),
				AutoButtonColor = false,
				ImageTransparency = 1,
				Active = true,
				Selectable = false,
				ZIndex = Z_INDEX.SLOT_BUTTON,
				Parent = slotUI.frame,
			})

			local currentSlotIndex = slotIndex
			local lastTriggerTime = 0
			local function triggerSelection()
				local now = os.clock()
				if now - lastTriggerTime < 0.08 then
					return
				end
				lastTriggerTime = now

				if equipInventorySlot then
					equipInventorySlot(currentSlotIndex)
				end
			end

			slotUI.button.Activated:Connect(triggerSelection)
			slotUI.button.InputBegan:Connect(function(input)
				local inputType = input.UserInputType
				if inputType == Enum.UserInputType.MouseButton1
					or inputType == Enum.UserInputType.Touch
					or inputType == Enum.UserInputType.Gamepad1
				then
					triggerSelection()
				end
			end)

			inventorySlots[slotIndex] = slotUI
		end
	else
		state.setVisibility = function(visible: boolean)
			inventoryVisible = visible
		end
	end

	return state
end

local layout: LayoutConfig = calculateLayout(isTouchDevice)
local statusUI = createStatusUI(screenGui, isTouchDevice, uiRefs)
local specialEventUI = createSpecialEventUI(screenGui, isTouchDevice)
local sprintUI: SprintUI = createSprintUI(screenGui, uiRefs, isTouchDevice, layout)
local inventoryState: InventoryState = createInventoryUI(screenGui, uiRefs, isTouchDevice, layout)
if inventoryState.setVisibility then
	setInventoryVisibility = inventoryState.setVisibility
end

statusUI.frame:GetPropertyChangedSignal("Visible"):Connect(function()
	refreshHotTouchStatusVisibility()
end)

local hotTouchAlertLabel = createInstance("TextLabel", {
	Name = "HotTouchAlert",
	Size = UDim2.fromOffset(if isTouchDevice then 480 else 520, if isTouchDevice then 120 else 140),
	Position = UDim2.new(0.5, 0, 0.45, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	Text = "You have been tagged",
	TextColor3 = Color3.fromRGB(255, 80, 80),
	TextScaled = true,
	TextWrapped = true,
	TextStrokeTransparency = 0.05,
	TextStrokeColor3 = Color3.fromRGB(255, 0, 120),
	Visible = false,
	ZIndex = 130,
	Parent = screenGui,
})

local hotTouchAlertStroke = hotTouchAlertLabel:FindFirstChildWhichIsA("UIStroke")
if not hotTouchAlertStroke then
	hotTouchAlertStroke = createInstance("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(255, 30, 120),
		Thickness = 2.5,
		Transparency = 0.1,
		Parent = hotTouchAlertLabel,
	})
end

local hotTouchAlertScale = Instance.new("UIScale")
hotTouchAlertScale.Name = "HotTouchAlertScale"
hotTouchAlertScale.Parent = hotTouchAlertLabel

local hotTouchAlertState = {
	label = hotTouchAlertLabel,
	stroke = hotTouchAlertStroke,
	scale = hotTouchAlertScale,
	connection = nil :: RBXScriptConnection?,
	token = 0,
	basePosition = hotTouchAlertLabel.Position,
}

local function stopHotTouchAlert()
	if hotTouchAlertState.connection then
		hotTouchAlertState.connection:Disconnect()
		hotTouchAlertState.connection = nil
	end

	local label = hotTouchAlertState.label
	label.Visible = false
	label.Position = hotTouchAlertState.basePosition
	hotTouchAlertState.scale.Scale = 1
end

local function showHotTouchAlert()
	hotTouchAlertState.token += 1
	local token = hotTouchAlertState.token

	local label = hotTouchAlertState.label
	label.Text = "You have been tagged"
	label.Visible = true

	if hotTouchAlertState.connection then
		hotTouchAlertState.connection:Disconnect()
	end

	local basePosition = hotTouchAlertState.basePosition
	hotTouchAlertState.connection = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local pulse = (math.sin(now * 10) + 1) * 0.5
		local wobbleX = math.sin(now * 18) * 6
		local wobbleY = math.cos(now * 14) * 4

		label.Position = basePosition + UDim2.fromOffset(wobbleX, wobbleY)
		hotTouchAlertState.scale.Scale = 1.08 + math.sin(now * 12) * 0.08

		local intensity = math.floor(120 + 130 * pulse)
		label.TextColor3 = Color3.fromRGB(255, intensity, intensity)
		hotTouchAlertState.stroke.Color = Color3.fromRGB(255, math.max(40, 200 - intensity // 2), 160 + math.floor(80 * pulse))
		hotTouchAlertState.stroke.Thickness = 2 + pulse * 2
	end)

	task.delay(2.6, function()
		if token ~= hotTouchAlertState.token then
			return
		end
		stopHotTouchAlert()
	end)
end

local function setHotTouchActive(active: boolean)
	if hotTouchActive == active then
		refreshHotTouchStatusVisibility()
		return
	end

	hotTouchActive = active
	if not hotTouchActive then
		currentHotTouchHolderId = nil
		setHotTouchStatusText(nil)
		stopHotTouchAlert()
	else
		refreshHotTouchStatusVisibility()
	end
end

local defaultColor = statusUI.label.TextColor3
local countdownColor = Color3.fromRGB(245, 245, 255)
local matchColor = Color3.fromRGB(210, 235, 255)
local deathMatchBackground = Color3.fromRGB(60, 10, 10)
local deathMatchStroke = Color3.fromRGB(255, 90, 90)
local highlightStyles = {
	Spectate = {
		outlineColor = Color3.fromRGB(255, 255, 255),
		fillColor = Color3.fromRGB(255, 255, 255),
		fillTransparency = 0.5,
	},
	DeathMatch = {
		outlineColor = Color3.fromRGB(255, 0, 0),
		fillColor = Color3.fromRGB(255, 0, 0),
		fillTransparency = 0.5,
	},
}

local baseFramePosition = statusUI.frame.Position
local baseLabelPosition = statusUI.label.Position
local currentMapId: string? = nil
local currentEventDisplayName: string? = nil
local currentRemaining = 0
local flashConnection: RBXScriptConnection? = nil
local shakeConnection: RBXScriptConnection? = nil

type NeutralButtonShakeTarget = {
	instance: GuiObject,
	basePosition: UDim2,
	baseRotation: number,
}

local neutralButtonShakeTargets: {NeutralButtonShakeTarget} = {}

local transitionState = {
	active = false,
	token = 0,
}

local specialEventState = {
	active = false,
	id = nil :: string?,
	displayName = nil :: string?,
	randomized = false,
	randomToken = 0,
	hideToken = 0,
	options = {} :: {{id: string?, name: string?}},
	finalName = nil :: string?,
	effects = {
		sprintDisabled = false,
		invisible = false,
		inverted = false,
	},
}

local invisibilityState = {
	enabled = false,
	pulseToken = 0,
	playerConnections = {} :: {[Player]: {RBXScriptConnection}},
	playerAddedConn = nil :: RBXScriptConnection?,
	playerRemovingConn = nil :: RBXScriptConnection?,
}

local pendingInvisiblePulseUpdate = false

type HighlightTweenBundle = {tween: Tween, conn: RBXScriptConnection?}
local invisibleHighlightTweens: {[Highlight]: HighlightTweenBundle} = {}

type InvisibleCharacterFadeBundle = {
	value: NumberValue,
	tween: Tween,
	conn: RBXScriptConnection?,
	target: number,
}

local invisibleCharacterFades: {[Model]: InvisibleCharacterFadeBundle} = {}

local invisibleHumanoidNameDisplay: {[Humanoid]: Enum.HumanoidDisplayDistanceType} = {}

local function setHumanoidNameHidden(humanoid: Humanoid, hidden: boolean)
	if hidden then
		if not invisibleHumanoidNameDisplay[humanoid] then
			invisibleHumanoidNameDisplay[humanoid] = humanoid.DisplayDistanceType
		end
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	else
		local previous = invisibleHumanoidNameDisplay[humanoid]
		invisibleHumanoidNameDisplay[humanoid] = nil
		if previous then
			humanoid.DisplayDistanceType = previous
		elseif humanoid.DisplayDistanceType == Enum.HumanoidDisplayDistanceType.None then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		end
	end
end

local function forEachVisibleCharacterPart(character: Model, handler: (BasePart) -> ())
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			local belongsToTool = false
			local ancestor = descendant.Parent
			while ancestor and ancestor ~= character do
				if ancestor:IsA("Tool") then
					belongsToTool = true
					break
				end
				ancestor = ancestor.Parent
			end

			if not belongsToTool then
				handler(descendant)
			end
		end
	end
end

local function applyTransparencyToCharacter(character: Model, transparency: number)
	forEachVisibleCharacterPart(character, function(part)
		part.LocalTransparencyModifier = transparency
	end)
end

local function computeInvisibilityTransparency(enabled: boolean, owner: Player?): number
	if not enabled then
		return 0
	end

	if owner == localPlayer then
		return 0.5
	end

	return 1
end

local function cancelInvisibleCharacterFade(character: Model, finalTransparency: number?)
	local bundle = invisibleCharacterFades[character]
	if not bundle then
		if finalTransparency ~= nil then
			applyTransparencyToCharacter(character, finalTransparency)
		end
		return
	end

	if bundle.conn then
		bundle.conn:Disconnect()
		bundle.conn = nil
	end
	bundle.tween:Cancel()
	invisibleCharacterFades[character] = nil

	local finalValue = if finalTransparency ~= nil then finalTransparency else bundle.target
	bundle.value:Destroy()
	applyTransparencyToCharacter(character, finalValue)
end

local function flashInvisibleCharacter(character: Model)
	cancelInvisibleCharacterFade(character)
	applyTransparencyToCharacter(character, 0)
end

local function startInvisibleCharacterFade(character: Model, owner: Player?, duration: number)
	local targetTransparency = computeInvisibilityTransparency(true, owner)

	if targetTransparency <= 0 then
		return
	end

	cancelInvisibleCharacterFade(character)

	local controller = Instance.new("NumberValue")
	controller.Name = "InvisibleCharacterFade"
	controller.Value = 0
	controller.Parent = character

	local tween = TweenService:Create(controller, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Value = targetTransparency,
	})

	local bundle: InvisibleCharacterFadeBundle = {
		value = controller,
		tween = tween,
		conn = nil,
		target = targetTransparency,
	}

	bundle.conn = controller:GetPropertyChangedSignal("Value"):Connect(function()
		applyTransparencyToCharacter(character, controller.Value)
	end)

	invisibleCharacterFades[character] = bundle

	tween.Completed:Connect(function()
		if invisibleCharacterFades[character] ~= bundle then
			return
		end

		if bundle.conn then
			bundle.conn:Disconnect()
			bundle.conn = nil
		end

		invisibleCharacterFades[character] = nil
		controller:Destroy()
		applyTransparencyToCharacter(character, bundle.target)
	end)

	tween:Play()
end

local invertedControlState = {
	active = false,
	requested = false,
	controlsDisabled = false,
	keyboard = {
		forward = false,
		back = false,
		left = false,
		right = false,
	},
	thumbstick = Vector2.new(),
	connections = {} :: {RBXScriptConnection},
	heartbeatConn = nil :: RBXScriptConnection?,
	jumpConn = nil :: RBXScriptConnection?,
}

type HighlightConnections = {RBXScriptConnection}

type HighlightStyle = {
	outlineColor: Color3,
	fillColor: Color3,
	fillTransparency: number,
}

local highlightState = {
	active = false,
	context = nil :: string?,
	style = nil :: HighlightStyle?,
	highlights = {} :: {[Player]: Highlight},
	playerConnections = {} :: {[Player]: HighlightConnections},
	playerAddedConn = nil :: RBXScriptConnection?,
	playerRemovingConn = nil :: RBXScriptConnection?,
}

local deathMatchHighlightActive = false

type SprintState = {
	energy: number,
	isSprinting: boolean,
	sprintIntent: boolean,
	keyboardIntent: boolean,
	touchIntent: boolean,
	zoneBlocked: boolean,
	eventDisabled: boolean,
	rechargeBlockedUntil: number,
	originalWalkSpeed: number,
	speedTween: Tween?,
	cameraTween: Tween?,
	originalCameraFov: number?,
}

local MAX_SPRINT_ENERGY = 100
local SPRINT_DRAIN_RATE = 10
local SPRINT_RECHARGE_RATE = 20
local SPRINT_RECHARGE_DELAY = 2
local BASE_SPRINT_SPEED = 28
local SPRINT_TWEEN_TIME = 1
local SPRINT_FOV_OFFSET = 8

local sprintState: SprintState = {
	energy = MAX_SPRINT_ENERGY,
	isSprinting = false,
	sprintIntent = false,
	keyboardIntent = false,
	touchIntent = false,
	zoneBlocked = false,
	eventDisabled = false,
	rechargeBlockedUntil = 0,
	originalWalkSpeed = DEFAULT_WALK_SPEED,
	speedTween = nil,
	cameraTween = nil,
	originalCameraFov = nil,
}

local currentHumanoid: Humanoid? = nil
local humanoidSpeedChangedConn: RBXScriptConnection? = nil
local humanoidSprintBonusConn: RBXScriptConnection? = nil

local function getHumanoidSprintBonus(humanoid: Humanoid?): number
	if not humanoid then
		return 0
	end

	local bonus = humanoid:GetAttribute("SprintSpeedBonus")
	if typeof(bonus) == "number" then
		return bonus
	end

	return 0
end

local function getSprintTargetSpeed(): number
	return BASE_SPRINT_SPEED + getHumanoidSprintBonus(currentHumanoid)
end

local mouse = if UserInputService.TouchEnabled then nil else localPlayer:GetMouse()
local applyingMouseIcon = false

type GearConnections = {
	equipped: RBXScriptConnection?,
	unequipped: RBXScriptConnection?,
	ancestry: RBXScriptConnection?,
	destroying: RBXScriptConnection?,
}

type GearTrackingInfo = {
	tool: Tool,
	isEquipped: boolean,
	connections: GearConnections,
}

local trackedGearTools: {[Tool]: GearTrackingInfo} = {}
local equippedGearCount = 0
local currentBackpack: Backpack? = nil
local backpackConnections: {RBXScriptConnection} = {}
local characterGearConn: RBXScriptConnection? = nil

local trackedGearOrder: {Tool} = {}

local function removeToolFromOrder(tool: Tool)
	for index, candidate in ipairs(trackedGearOrder) do
		if candidate == tool then
			table.remove(trackedGearOrder, index)
			return
		end
	end
end

local equipInventorySlot: (number) -> ()
local function locallyToggleTool(tool: Tool)
	local character = localPlayer.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local backpack = currentBackpack or localPlayer:FindFirstChildOfClass("Backpack")
	local toolEquipped = tool.Parent == character

	if toolEquipped then
		if backpack then
			tool.Parent = backpack
		else
			humanoid:UnequipTools()
		end
		return
	end

	humanoid:EquipTool(tool)
end
local updateInventorySlots: () -> ()

local function removeHighlightForPlayer(targetPlayer: Player)
	local highlight = highlightState.highlights[targetPlayer]
	if highlight then
		highlight:Destroy()
		highlightState.highlights[targetPlayer] = nil
	end
end

local function clearConnectionsForPlayer(targetPlayer: Player)
	local connections = highlightState.playerConnections[targetPlayer]
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
		highlightState.playerConnections[targetPlayer] = nil
	end
end

local function getHighlightStyleForContext(context: string?): HighlightStyle?
	if not context then
		return nil
	end

	if context == "Spectate" then
		local team = localPlayer.Team
		if team and team.Name == "Spectate" then
			return highlightStyles.Spectate
		end
	elseif context == "DeathMatch" then
		if localPlayer.Neutral then
			return highlightStyles.DeathMatch
		end
	end

	return nil
end

local function updateHighlightForPlayer(targetPlayer: Player)
	if targetPlayer == localPlayer then
		removeHighlightForPlayer(targetPlayer)
		return
	end

	local highlight = highlightState.highlights[targetPlayer]
	local shouldShow = highlightState.active
		and highlightState.style ~= nil
		and targetPlayer.Neutral

	if not shouldShow then
		if highlight then
			highlight:Destroy()
			highlightState.highlights[targetPlayer] = nil
		end
		return
	end

	local character = targetPlayer.Character
	if not character then
		if highlight then
			highlight.Parent = nil
		end
		return
	end

	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = "DeathMatchTransitionHighlight"
		highlight.FillTransparency = 1
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlightState.highlights[targetPlayer] = highlight
	end

	local style = highlightState.style or highlightStyles.DeathMatch
	highlight.OutlineColor = style.outlineColor
	highlight.FillColor = style.fillColor
	highlight.FillTransparency = style.fillTransparency
	highlight.OutlineTransparency = 0
	highlight.Adornee = character
	highlight.Parent = character
end

local function refreshHighlightStyle()
	if not highlightState.active then
		return
	end

	local newStyle = getHighlightStyleForContext(highlightState.context)
	if not newStyle then
		disableHighlights()
		updateHighlightActivation()
		return
	end

	highlightState.style = newStyle

	for _, highlight in highlightState.highlights do
		highlight.OutlineColor = newStyle.outlineColor
		highlight.FillColor = newStyle.fillColor
		highlight.FillTransparency = newStyle.fillTransparency
	end

	for _, player in Players:GetPlayers() do
		updateHighlightForPlayer(player)
	end
end

local function disableHighlights()
	if highlightState.playerAddedConn then
		highlightState.playerAddedConn:Disconnect()
		highlightState.playerAddedConn = nil
	end

	if highlightState.playerRemovingConn then
		highlightState.playerRemovingConn:Disconnect()
		highlightState.playerRemovingConn = nil
	end

	for player, connections in highlightState.playerConnections do
		for _, connection in connections do
			connection:Disconnect()
		end
	end
	table.clear(highlightState.playerConnections)

	for player, highlight in highlightState.highlights do
		highlight:Destroy()
	end
	table.clear(highlightState.highlights)

	highlightState.active = false
	highlightState.context = nil
	highlightState.style = nil
end

local function trackPlayerForHighlights(targetPlayer: Player)
	if targetPlayer == localPlayer then
		return
	end

	clearConnectionsForPlayer(targetPlayer)

	local connections: HighlightConnections = {}

	connections[#connections + 1] = targetPlayer:GetPropertyChangedSignal("Team"):Connect(function()
		updateHighlightForPlayer(targetPlayer)
	end)

	connections[#connections + 1] = targetPlayer:GetPropertyChangedSignal("Neutral"):Connect(function()
		updateHighlightForPlayer(targetPlayer)
	end)

	connections[#connections + 1] = targetPlayer.CharacterAdded:Connect(function()
		task.defer(function()
			updateHighlightForPlayer(targetPlayer)
		end)
	end)

	connections[#connections + 1] = targetPlayer.CharacterRemoving:Connect(function()
		resetMovementState(humanoid)if invertedControlState and invertedControlState.active then disableInvertedControls() end
		hardEnableDefaultControls()
		removeHighlightForPlayer(targetPlayer)
	end)

	highlightState.playerConnections[targetPlayer] = connections

	updateHighlightForPlayer(targetPlayer)
end

local function enableHighlights(context: string)
	if highlightState.active and highlightState.context == context then
		highlightState.style = getHighlightStyleForContext(context)
		refreshHighlightStyle()
		return
	end

	disableHighlights()

	local style = getHighlightStyleForContext(context)
	if not style then
		return
	end

	highlightState.context = context
	highlightState.active = true
	highlightState.style = style

	for _, player in Players:GetPlayers() do
		trackPlayerForHighlights(player)
	end

	highlightState.playerAddedConn = Players.PlayerAdded:Connect(function(player)
		if highlightState.active then
			trackPlayerForHighlights(player)
		end
	end)

	highlightState.playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
		clearConnectionsForPlayer(player)
		removeHighlightForPlayer(player)
	end)

	refreshHighlightStyle()
end

local function updateHighlightActivation()
	local desiredContext: string? = nil

	local team = localPlayer.Team
	if team and team.Name == "Spectate" then
		desiredContext = "Spectate"
	elseif deathMatchHighlightActive and localPlayer.Neutral and not invisibilityState.enabled then
		desiredContext = "DeathMatch"
	end

	if desiredContext then
		enableHighlights(desiredContext)
	else
		disableHighlights()
	end

	if updateInvisiblePulseState then
		updateInvisiblePulseState()
	else
		pendingInvisiblePulseUpdate = true
	end
end

local function hideSpecialEvent(immediate: boolean?)
	specialEventState.hideToken += 1
	local token = specialEventState.hideToken

	if not specialEventUI.frame then
		return
	end

	if immediate then
		specialEventUI.frame.Visible = false
		return
	end

	local fadeTween = TweenService:Create(specialEventUI.frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	})
	local scaleTween = TweenService:Create(specialEventUI.scale, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Scale = 0.85,
	})

	fadeTween.Completed:Connect(function()
		if specialEventState.hideToken == token then
			specialEventUI.frame.Visible = false
			specialEventUI.scale.Scale = 1
		end
	end)

	fadeTween:Play()
	scaleTween:Play()
end

local function showSpecialEvent(titleText: string, keepSeconds: number?)
	specialEventState.hideToken += 1
	local token = specialEventState.hideToken

	specialEventUI.title.Text = titleText
	specialEventUI.frame.Visible = true
	specialEventUI.frame.BackgroundTransparency = 1
	specialEventUI.scale.Scale = 0.2

	TweenService:Create(specialEventUI.frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.05,
	}):Play()

	TweenService:Create(specialEventUI.scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	if keepSeconds and keepSeconds > 0 then
		task.delay(keepSeconds, function()
			if specialEventState.hideToken == token then
				hideSpecialEvent(false)
			end
		end)
	end
end

local function beginSpecialEventRandomization(options: {{id: string?, name: string?}}, finalName: string?, duration: number?)
	specialEventState.options = options
	specialEventState.finalName = finalName
	specialEventState.randomized = true
	specialEventState.randomToken += 1
	local token = specialEventState.randomToken

	if #options == 0 then
		options = {{id = "", name = "???"}}
		specialEventState.options = options
	end

	showSpecialEvent("Randomizing...", duration or 3)

	task.spawn(function()
		local index = 1
		local count = math.max(1, #options)
		local elapsed = 0
		local totalDuration = duration or 3
		local step = 0.12

		while specialEventState.randomized and specialEventState.randomToken == token do
			local option = options[((index - 1) % count) + 1]
			if option then
				specialEventUI.title.Text = option.name or option.id or "???"
			end
			index += 1

			task.wait(step)
			elapsed += step

			if totalDuration > 0 and elapsed > totalDuration then
				step = math.min(0.25, step + 0.03)
			end
		end
	end)
end

local function completeSpecialEventRandomization(finalName: string)
	if not specialEventState.randomized then
		showSpecialEvent(finalName, 3)
		return
	end

	specialEventState.randomized = false
	specialEventUI.title.Text = finalName
	showSpecialEvent(finalName, 3)
end

local function cancelInvisibleHighlightFade(highlight: Highlight)
	local bundle = invisibleHighlightTweens[highlight]
	if not bundle then
		return
	end

	if bundle.conn then
		bundle.conn:Disconnect()
	end
	bundle.tween:Cancel()
	invisibleHighlightTweens[highlight] = nil
end

local function startInvisibleHighlightFade(highlight: Highlight)
	cancelInvisibleHighlightFade(highlight)

	local tween = TweenService:Create(highlight, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FillTransparency = 1,
		OutlineTransparency = 1,
	})

	local conn = tween.Completed:Connect(function()
		local bundle = invisibleHighlightTweens[highlight]
		if bundle and bundle.tween == tween then
			invisibleHighlightTweens[highlight] = nil
		end
	end)

	invisibleHighlightTweens[highlight] = {tween = tween, conn = conn}
	tween:Play()
end

local function ensureInvisibleHighlight(character: Model): Highlight
	local highlight = character:FindFirstChild("InvisibleRevealHighlight") :: Highlight?
	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = "InvisibleRevealHighlight"
		highlight.FillColor = Color3.fromRGB(255, 255, 255)
		highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		highlight.FillTransparency = 1
		highlight.OutlineTransparency = 1
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = character
		highlight.Enabled = true
		highlight.Destroying:Connect(function()
			cancelInvisibleHighlightFade(highlight)
		end)
	end

	return highlight
end

local function clearInvisibleHighlight(character: Model)
	local highlight = character:FindFirstChild("InvisibleRevealHighlight")
	if highlight then
		cancelInvisibleHighlightFade(highlight :: Highlight)
		highlight:Destroy()
	end
	cancelInvisibleCharacterFade(character)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		setHumanoidNameHidden(humanoid, false)
	end
end

local function applyCharacterInvisibility(character: Model, enabled: boolean, owner: Player?)
	local targetTransparency = computeInvisibilityTransparency(enabled, owner)
	local bundle = invisibleCharacterFades[character]

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		setHumanoidNameHidden(humanoid, enabled)
	end

	if not enabled then
		cancelInvisibleCharacterFade(character, targetTransparency)
		return
	end

	if bundle then
		bundle.target = targetTransparency
		return
	end

	applyTransparencyToCharacter(character, targetTransparency)
end

local function updateInvisibilityForPlayer(player: Player)
	local character = player.Character
	if not character then
		return
	end

	local shouldBeInvisible = invisibilityState.enabled and player.Neutral
	applyCharacterInvisibility(character, shouldBeInvisible, player)

	if not shouldBeInvisible then
		clearInvisibleHighlight(character)
	end
end

local function clearInvisibilityTracking()
	for _, connections in invisibilityState.playerConnections do
		for _, connection in connections do
			connection:Disconnect()
		end
	end

	table.clear(invisibilityState.playerConnections)

	for _, player in Players:GetPlayers() do
		if player.Character then
			applyCharacterInvisibility(player.Character, false, player)
			clearInvisibleHighlight(player.Character)
		end
	end

	table.clear(invisibleHumanoidNameDisplay)
end

local function trackPlayerForInvisibility(player: Player)
	local existing = invisibilityState.playerConnections[player]
	if existing then
		for _, connection in existing do
			connection:Disconnect()
		end
	end

	local connections: {RBXScriptConnection} = {}
	connections[#connections + 1] = player:GetPropertyChangedSignal("Neutral"):Connect(function()
		updateInvisibilityForPlayer(player)
	end)
	connections[#connections + 1] = player.CharacterAdded:Connect(function()
		task.defer(function()
			updateInvisibilityForPlayer(player)
		end)
	end)
	connections[#connections + 1] = player.CharacterRemoving:Connect(function(character)
		clearInvisibleHighlight(character)
	end)

	invisibilityState.playerConnections[player] = connections
	updateInvisibilityForPlayer(player)
end

local function updateInvisiblePulseState()
	invisibilityState.pulseToken += 1
	local token = invisibilityState.pulseToken

	if not invisibilityState.enabled then
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character then
				local highlight = character:FindFirstChild("InvisibleRevealHighlight") :: Highlight?
				if highlight then
					cancelInvisibleHighlightFade(highlight)
					highlight.FillTransparency = 1
					highlight.OutlineTransparency = 1
				end
				cancelInvisibleCharacterFade(character, computeInvisibilityTransparency(false, player))
			end
		end
		return
	end

	task.spawn(function()
		while invisibilityState.enabled and invisibilityState.pulseToken == token do
			for _, player in Players:GetPlayers() do
				if player.Neutral then
					local character = player.Character
					if character then
						local highlight = ensureInvisibleHighlight(character)
						cancelInvisibleHighlightFade(highlight)
						highlight.FillColor = Color3.fromRGB(255, 255, 255)
						highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
						highlight.FillTransparency = 0.5
						highlight.OutlineTransparency = 0
						highlight.Enabled = true
						flashInvisibleCharacter(character)
					end
				else
					local character = player.Character
					if character then
						cancelInvisibleCharacterFade(character, computeInvisibilityTransparency(false, player))
					end
				end
			end

			local pulseToken = token
			task.delay(1, function()
				if invisibilityState.pulseToken == pulseToken then
					for _, player in Players:GetPlayers() do
						local character = player.Character
						if character then
							local highlight = character:FindFirstChild("InvisibleRevealHighlight") :: Highlight?
							if highlight then
								startInvisibleHighlightFade(highlight)
							end
							if player.Neutral then
								startInvisibleCharacterFade(character, player, 2)
							end
						end
					end
				end
			end)

			local elapsed = 0
			while elapsed < 5 and invisibilityState.enabled and invisibilityState.pulseToken == token do
				task.wait(0.2)
				elapsed += 0.2
			end
		end
	end)
end

if pendingInvisiblePulseUpdate then
	pendingInvisiblePulseUpdate = false
	updateInvisiblePulseState()
end

local function setInvisibilityEnabled(enabled: boolean)
	if invisibilityState.enabled == enabled then
		updateInvisiblePulseState()
		for _, player in Players:GetPlayers() do
			updateInvisibilityForPlayer(player)
		end
		if updateHighlightActivation then
			updateHighlightActivation()
		end
		return
	end

	invisibilityState.enabled = enabled

	if enabled then
		for _, player in Players:GetPlayers() do
			trackPlayerForInvisibility(player)
		end

		if not invisibilityState.playerAddedConn then
			invisibilityState.playerAddedConn = Players.PlayerAdded:Connect(function(player)
				trackPlayerForInvisibility(player)
			end)
		end

		if not invisibilityState.playerRemovingConn then
			invisibilityState.playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
				local connections = invisibilityState.playerConnections[player]
				if connections then
					for _, connection in connections do
						connection:Disconnect()
					end
					invisibilityState.playerConnections[player] = nil
				end

				local character = player.Character
				if character then
					clearInvisibleHighlight(character)
				end
			end)
		end
	else
		if invisibilityState.playerAddedConn then
			invisibilityState.playerAddedConn:Disconnect()
			invisibilityState.playerAddedConn = nil
		end
		if invisibilityState.playerRemovingConn then
			invisibilityState.playerRemovingConn:Disconnect()
			invisibilityState.playerRemovingConn = nil
		end

		clearInvisibilityTracking()
	end

	updateInvisiblePulseState()
	if updateHighlightActivation then
		updateHighlightActivation()
	end
end

local function resetInvertedMovement()
	invertedControlState.keyboard.forward = false
	invertedControlState.keyboard.back = false
	invertedControlState.keyboard.left = false
	invertedControlState.keyboard.right = false
	invertedControlState.thumbstick = Vector2.new(0, 0)

	local humanoid = currentHumanoid
	if humanoid then
		humanoid:Move(Vector3.zero, true)
	end
end

local function enableDefaultControlsIfDisabled()
	if not invertedControlState.controlsDisabled then
		return
	end

	local controls = getPlayerControls()
	if controls and controls.Enable then
		local ok, err = pcall(function()
			controls:Enable()
		end)
		if not ok then
			warn("Failed to re-enable default controls after inverted event:", err)
		else
			invertedControlState.controlsDisabled = false
		end
	else
		invertedControlState.controlsDisabled = false
	end
end

local function disableDefaultControls()
	local controls = getPlayerControls()
	if not controls or not controls.Disable then
		return
	end

	local ok, err = pcall(function()
		controls:Disable()
	end)
	if not ok then
		warn("Failed to disable default controls for inverted event:", err)
	else
		invertedControlState.controlsDisabled = true
	end
end

local function updateInvertedMovement()
	if not invertedControlState.active then
		return
	end

	local humanoid = currentHumanoid
	if not humanoid then
		return
	end

	local moveX = 0
	if invertedControlState.keyboard.left then
		moveX += 1
	end
	if invertedControlState.keyboard.right then
		moveX -= 1
	end

	local moveZ = 0
	if invertedControlState.keyboard.forward then
		moveZ += 1
	end
	if invertedControlState.keyboard.back then
		moveZ -= 1
	end

	local thumb = invertedControlState.thumbstick
	if thumb.Magnitude > 0 then
		moveX += -thumb.X
		moveZ += -thumb.Y
	end

	local moveVector = Vector3.new(moveX, 0, moveZ)
	if moveVector.Magnitude > 1 then
		moveVector = moveVector.Unit
	end

	humanoid:Move(moveVector, true)
end

local function ensureInvertedHeartbeat()
	if invertedControlState.heartbeatConn then
		invertedControlState.heartbeatConn:Disconnect()
	end

	invertedControlState.heartbeatConn = RunService.Heartbeat:Connect(updateInvertedMovement)
end

local function disableInvertedControls()
	for _, connection in invertedControlState.connections do
		connection:Disconnect()
	end
	table.clear(invertedControlState.connections)

	if invertedControlState.jumpConn then
		invertedControlState.jumpConn:Disconnect()
		invertedControlState.jumpConn = nil
	end

	if invertedControlState.heartbeatConn then
		invertedControlState.heartbeatConn:Disconnect()
		invertedControlState.heartbeatConn = nil
	end

	resetInvertedMovement()

	enableDefaultControlsIfDisabled()

	invertedControlState.active = false
end

local function enableInvertedControls()
	disableDefaultControls()

	resetInvertedMovement()

	if invertedControlState.active then
		ensureInvertedHeartbeat()
		return
	end

	local function onInputBegan(input: InputObject, processed: boolean)
		if processed then
			return
		end

		local key = input.KeyCode
		if key == Enum.KeyCode.W or key == Enum.KeyCode.Up then
			invertedControlState.keyboard.forward = true
		elseif key == Enum.KeyCode.S or key == Enum.KeyCode.Down then
			invertedControlState.keyboard.back = true
		elseif key == Enum.KeyCode.A or key == Enum.KeyCode.Left then
			invertedControlState.keyboard.left = true
		elseif key == Enum.KeyCode.D or key == Enum.KeyCode.Right then
			invertedControlState.keyboard.right = true
		elseif key == Enum.KeyCode.DPadUp then
			invertedControlState.keyboard.forward = true
		elseif key == Enum.KeyCode.DPadDown then
			invertedControlState.keyboard.back = true
		elseif key == Enum.KeyCode.DPadLeft then
			invertedControlState.keyboard.left = true
		elseif key == Enum.KeyCode.DPadRight then
			invertedControlState.keyboard.right = true
		elseif key == Enum.KeyCode.Space or key == Enum.KeyCode.ButtonA then
			local humanoid = currentHumanoid
			if humanoid then
				humanoid.Jump = true
			end
		end
	end

	local function onInputEnded(input: InputObject)
		local key = input.KeyCode
		if key == Enum.KeyCode.W or key == Enum.KeyCode.Up then
			invertedControlState.keyboard.forward = false
		elseif key == Enum.KeyCode.S or key == Enum.KeyCode.Down then
			invertedControlState.keyboard.back = false
		elseif key == Enum.KeyCode.A or key == Enum.KeyCode.Left then
			invertedControlState.keyboard.left = false
		elseif key == Enum.KeyCode.D or key == Enum.KeyCode.Right then
			invertedControlState.keyboard.right = false
		elseif key == Enum.KeyCode.DPadUp then
			invertedControlState.keyboard.forward = false
		elseif key == Enum.KeyCode.DPadDown then
			invertedControlState.keyboard.back = false
		elseif key == Enum.KeyCode.DPadLeft then
			invertedControlState.keyboard.left = false
		elseif key == Enum.KeyCode.DPadRight then
			invertedControlState.keyboard.right = false
		elseif key == Enum.KeyCode.Thumbstick1 then
			invertedControlState.thumbstick = Vector2.new(0, 0)
		end
	end

	local function onInputChanged(input: InputObject)
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			invertedControlState.thumbstick = Vector2.new(input.Position.X, input.Position.Y)
		end
	end

	invertedControlState.connections = {
		UserInputService.InputBegan:Connect(onInputBegan),
		UserInputService.InputEnded:Connect(onInputEnded),
		UserInputService.InputChanged:Connect(onInputChanged),
	}

	if invertedControlState.jumpConn then
		invertedControlState.jumpConn:Disconnect()
	end
	invertedControlState.jumpConn = UserInputService.JumpRequest:Connect(function()
		local humanoid = currentHumanoid
		if humanoid then
			humanoid.Jump = true
		end
	end)

	ensureInvertedHeartbeat()

	invertedControlState.active = true
end

local function applyInvertedControlState()
	-- Reset any stuck inputs immediately and shortly after spawn
	resetMovementState(humanoid)
	task.delay(0.20, function() resetMovementState(humanoid) end)
	task.delay(0.60, function() resetMovementState(humanoid) end)
	-- safety: if not inverted after spawn, re-enable defaults
	task.delay(0.2, function() if not (invertedControlState and invertedControlState.active) then hardEnableDefaultControls() end end)
	task.delay(1.0, function() if not (invertedControlState and invertedControlState.active) then hardEnableDefaultControls() end end)
	task.delay(2.0, function() if not (invertedControlState and invertedControlState.active) then hardEnableDefaultControls() end end)
	task.delay(3.0, function() if not (invertedControlState and invertedControlState.active) then hardEnableDefaultControls() end end)
	local shouldEnable = invertedControlState.requested and localPlayer.Neutral
	if shouldEnable then
		enableInvertedControls()
	else
		if invertedControlState.active then
			disableInvertedControls()
		else
			enableDefaultControlsIfDisabled()
		end
	end
end

local function setInvertedControlsEnabled(enabled: boolean)
	invertedControlState.requested = enabled
	applyInvertedControlState()
	-- Reset any stuck inputs immediately and shortly after spawn
	resetMovementState(humanoid)
	task.delay(0.20, function() resetMovementState(humanoid) end)
	task.delay(0.60, function() resetMovementState(humanoid) end)
	-- safety: if not inverted after spawn, re-enable defaults
	task.delay(0.2, function() if not (invertedControlState and invertedControlState.active) then hardEnableDefaultControls() end end)
	task.delay(1.0, function() if not (invertedControlState and invertedControlState.active) then hardEnableDefaultControls() end end)
	task.delay(2.0, function() if not (invertedControlState and invertedControlState.active) then hardEnableDefaultControls() end end)
	task.delay(3.0, function() if not (invertedControlState and invertedControlState.active) then hardEnableDefaultControls() end end)
end

local function getSprintActionButton(): ImageButton?
	local button = uiRefs.sprintActionButton
	if button and button.Parent then
		return button
	end

	button = ContextActionService:GetButton("SprintAction")
	if button and button:IsA("ImageButton") then
		uiRefs.sprintActionButton = button
		return button
	end

	uiRefs.sprintActionButton = nil
	return nil
end

local function updateSprintButtonState()
	if not sprintInteraction.actionBound then
		return
	end

	local hasEnergy = sprintState.energy > 0
	local sprintBlocked = sprintState.zoneBlocked or sprintState.eventDisabled
	local canSprint = hasEnergy and not sprintBlocked
	local buttonActive = sprintState.touchIntent and canSprint

	if not canSprint and not buttonActive then
		local title = if sprintState.zoneBlocked then "No Sprint" elseif sprintState.eventDisabled then "Event" else "Rest"
		ContextActionService:SetTitle("SprintAction", title)
	elseif buttonActive then
		ContextActionService:SetTitle("SprintAction", "Unsprint")
	else
		ContextActionService:SetTitle("SprintAction", "Sprint")
	end

	local shouldEnable = canSprint or sprintState.touchIntent

	local sprintButton = getSprintActionButton()
	if sprintButton then
		sprintButton.Visible = shouldEnable
		sprintButton.Active = shouldEnable
		sprintButton.AutoButtonColor = shouldEnable
		sprintButton.Selectable = shouldEnable
	end
end

local function recomputeSprintIntent()
	local desiredIntent = sprintState.keyboardIntent or sprintState.touchIntent
	if sprintState.zoneBlocked or sprintState.eventDisabled then
		desiredIntent = false
	end

	sprintState.sprintIntent = desiredIntent
	updateSprintButtonState()
end

local function setSprintEventDisabled(disabled: boolean)
	local shouldDisable = disabled and localPlayer.Neutral
	if sprintState.eventDisabled == shouldDisable then
		return
	end

	sprintState.eventDisabled = shouldDisable

	if shouldDisable then
		if sprintState.isSprinting then
			stopSprinting(true)
		end
		sprintState.touchIntent = false
		sprintState.keyboardIntent = false
	end

	recomputeSprintIntent()
	updateEnergyUI()
end

local function updateEnergyUI()
	if not uiRefs.energyBarFill or not uiRefs.energyTextLabel then
		return
	end

	local normalized = math.clamp(sprintState.energy / MAX_SPRINT_ENERGY, 0, 1)
	if normalized <= 0 then
		uiRefs.energyBarFill.Visible = false
	else
		uiRefs.energyBarFill.Visible = true
		uiRefs.energyBarFill.Size = UDim2.new(normalized, 0, 1, 0)
	end

	local percent = math.clamp(math.floor(normalized * 100 + 0.5), 0, 100)
	uiRefs.energyTextLabel.Text = string.format("Energy %d%%", percent)

	if percent <= 15 then
		uiRefs.energyTextLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
	elseif sprintState.isSprinting then
		uiRefs.energyTextLabel.TextColor3 = Color3.fromRGB(180, 255, 220)
	else
		uiRefs.energyTextLabel.TextColor3 = Color3.fromRGB(210, 235, 255)
	end

	if uiRefs.sprintStatusLabel then
		if sprintState.isSprinting then
			uiRefs.sprintStatusLabel.Text = "Sprint ON"
			uiRefs.sprintStatusLabel.TextColor3 = Color3.fromRGB(180, 255, 220)
		else
			uiRefs.sprintStatusLabel.Text = "Sprint OFF"
			if sprintState.energy <= 0 or sprintState.zoneBlocked or sprintState.eventDisabled then
				uiRefs.sprintStatusLabel.TextColor3 = Color3.fromRGB(255, 140, 140)
			else
				uiRefs.sprintStatusLabel.TextColor3 = Color3.fromRGB(210, 235, 255)
			end
		end
	end

	updateSprintButtonState()
end

local function toggleTouchSprintIntent()
	if sprintState.touchIntent then
		sprintState.touchIntent = false
		recomputeSprintIntent()
		if not sprintState.sprintIntent then
			stopSprinting(false)
		end
		return
	end

	if sprintState.energy <= 0 or sprintState.zoneBlocked or sprintState.eventDisabled then
		sprintState.touchIntent = false
		recomputeSprintIntent()
		return
	end

	sprintState.touchIntent = true
	recomputeSprintIntent()
	if not sprintState.isSprinting then
		startSprinting()
	end
end

local function tweenHumanoidSpeed(targetSpeed: number, instant: boolean)
	local humanoid = currentHumanoid
	if not humanoid then
		return
	end

	if sprintState.speedTween then
		sprintState.speedTween:Cancel()
		sprintState.speedTween = nil
	end

	if instant then
		humanoid.WalkSpeed = targetSpeed
		return
	end

	local tween = TweenService:Create(humanoid, TweenInfo.new(SPRINT_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		WalkSpeed = targetSpeed,
	})
	sprintState.speedTween = tween
	tween.Completed:Connect(function()
		if sprintState.speedTween == tween then
			sprintState.speedTween = nil
		end
	end)
	tween:Play()
end

local function tweenCameraFov(targetFov: number, instant: boolean, onComplete: (() -> ())?)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	if sprintState.cameraTween then
		sprintState.cameraTween:Cancel()
		sprintState.cameraTween = nil
	end

	if instant then
		camera.FieldOfView = targetFov
		if onComplete then
			onComplete()
		end
		return
	end

	local tween = TweenService:Create(camera, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = targetFov,
	})
	sprintState.cameraTween = tween
	tween.Completed:Connect(function(playbackState)
		if sprintState.cameraTween == tween then
			sprintState.cameraTween = nil
		end
		if playbackState == Enum.PlaybackState.Completed and onComplete then
			onComplete()
		end
	end)
	tween:Play()
end

local function stopSprinting(instant: boolean)
	local wasSprinting = sprintState.isSprinting
	sprintState.isSprinting = false

	if wasSprinting then
		sprintState.rechargeBlockedUntil = os.clock() + SPRINT_RECHARGE_DELAY
	end

	if currentHumanoid then
		tweenHumanoidSpeed(sprintState.originalWalkSpeed, instant)
	end

	if sprintState.originalCameraFov then
		local targetFov = sprintState.originalCameraFov
		if instant then
			tweenCameraFov(targetFov, true)
			sprintState.originalCameraFov = nil
		else
			tweenCameraFov(targetFov, false, function()
				sprintState.originalCameraFov = nil
			end)
		end
	end

	updateEnergyUI()
end

local function startSprinting()
	if sprintState.isSprinting then
		return
	end

	if sprintState.zoneBlocked or sprintState.eventDisabled then
		return
	end

	if sprintState.energy <= 0 then
		return
	end

	local humanoid = currentHumanoid
	if not humanoid then
		return
	end

	sprintState.isSprinting = true

	local baselineSpeed = sprintState.originalWalkSpeed
	if not baselineSpeed or baselineSpeed <= 0 then
		baselineSpeed = humanoid.WalkSpeed
	end

	local sprintTarget = getSprintTargetSpeed()

	if math.abs(baselineSpeed - sprintTarget) < 0.001 then
		baselineSpeed = DEFAULT_WALK_SPEED
	elseif baselineSpeed <= 0 then
		baselineSpeed = DEFAULT_WALK_SPEED
	end

	sprintState.originalWalkSpeed = baselineSpeed

	tweenHumanoidSpeed(sprintTarget, false)

	local camera = Workspace.CurrentCamera
	if camera then
		if not sprintState.originalCameraFov then
			sprintState.originalCameraFov = camera.FieldOfView
		end
		local targetFov = math.clamp(sprintState.originalCameraFov + SPRINT_FOV_OFFSET, 5, 120)
		tweenCameraFov(targetFov, false)
	end

	updateEnergyUI()
end

local function resetSprintState()
	stopSprinting(true)
	sprintState.keyboardIntent = false
	sprintState.touchIntent = false
	sprintState.zoneBlocked = false
	recomputeSprintIntent()
	sprintState.energy = MAX_SPRINT_ENERGY
	sprintState.rechargeBlockedUntil = 0
	sprintState.speedTween = nil
	sprintState.cameraTween = nil
	sprintState.originalCameraFov = nil
	sprintState.originalWalkSpeed = DEFAULT_WALK_SPEED
	updateEnergyUI()
end

local function applyDesktopCursorIcon()
	if not mouse then
		return
	end

	local iconAsset = currentCursorImageAsset
	if mouse.Icon ~= iconAsset then
		applyingMouseIcon = true
		mouse.Icon = iconAsset
		applyingMouseIcon = false
	end

	if uiRefs.centerCursorImage then
		uiRefs.centerCursorImage.Image = if iconAsset ~= "" then iconAsset else ""
	end
end

local function updateCenterCursorVisibility()
	if not uiRefs.centerCursorImage then
		return
	end

	local shouldShow = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
		and currentCursorImageAsset ~= ""
	uiRefs.centerCursorImage.Visible = shouldShow
	if shouldShow then
		uiRefs.centerCursorImage.Image = currentCursorImageAsset
	end
end

local function setCursorAsset(assetId: string)
	if currentCursorImageAsset == assetId then
		return
	end

	currentCursorImageAsset = assetId

	if mouse then
		applyDesktopCursorIcon()
	end

	updateCenterCursorVisibility()
end

local function updateCursorForGearState()
	setCursorAsset(GEAR_CURSOR_IMAGE_ASSET)
end

local function getToolIcon(tool: Tool): string
	local textureId = tool.TextureId
	if textureId and textureId ~= "" then
		return textureId
	end

	local handle = tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		if handle:IsA("MeshPart") then
			local meshTexture = handle.TextureID
			if meshTexture and meshTexture ~= "" then
				return meshTexture
			end
		end

		local specialMesh = handle:FindFirstChildOfClass("SpecialMesh")
		if specialMesh and specialMesh.TextureId ~= "" then
			return specialMesh.TextureId
		end
	end

	return ""
end

updateInventorySlots = function()
	local cleanedOrder: {Tool} = {}
	for _, tool in ipairs(trackedGearOrder) do
		if trackedGearTools[tool] then
			table.insert(cleanedOrder, tool)
		end
	end
	trackedGearOrder = cleanedOrder

	local toolCount = #trackedGearOrder
	if toolCount == 0 then
		inventoryAutoOpened = false
	elseif isTouchDevice and not inventoryVisible and not inventoryAutoOpened then
		inventoryAutoOpened = true
		setInventoryVisibility(true)
	end

	for slotIndex = 1, 10 do
		local slot = inventorySlots[slotIndex]
		if slot then
			local tool = trackedGearOrder[slotIndex]
			slotToolMapping[slotIndex] = tool

			if tool then
				local iconId = getToolIcon(tool)
				slot.icon.Image = iconId
				slot.icon.Visible = iconId ~= ""
				slot.label.Text = tool.Name
				slot.frame.BackgroundTransparency = 0.15
				slot.button.Active = true
				slot.button.Selectable = true
				slot.numberLabel.TextColor3 = Color3.fromRGB(210, 220, 240)
			else
				slot.icon.Image = ""
				slot.icon.Visible = false
				slot.label.Text = ""
				slot.frame.BackgroundTransparency = 0.4
				slot.button.Active = false
				slot.button.Selectable = false
				slot.numberLabel.TextColor3 = Color3.fromRGB(140, 150, 180)
			end

			local isEquipped = tool ~= nil and tool.Parent == localPlayer.Character
			if isEquipped then
				slot.stroke.Color = Color3.fromRGB(80, 190, 255)
				slot.frame.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
			else
				slot.stroke.Color = Color3.fromRGB(80, 100, 150)
				slot.frame.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
			end
		end
	end
end

equipInventorySlot = function(slotIndex: number)
	local tool = slotToolMapping[slotIndex]
	if not tool then
		return
	end

	local isPVPGear = tool:GetAttribute("PVPGenerated") == true

	if toggleInventorySlotRemote and isPVPGear then
		toggleInventorySlotRemote:FireServer(tool)
		return
	end

	locallyToggleTool(tool)
end

updateInventorySlots()

local function handleGearEquipped(info: GearTrackingInfo)
	if info.isEquipped then
		return
	end

	info.isEquipped = true
	equippedGearCount += 1
	updateCursorForGearState()
	updateInventorySlots()
end

local function handleGearUnequipped(info: GearTrackingInfo)
	if not info.isEquipped then
		return
	end

	info.isEquipped = false
	if equippedGearCount > 0 then
		equippedGearCount -= 1
	end
	updateCursorForGearState()
	updateInventorySlots()
end

local function clearBackpackConnections()
	for _, connection in backpackConnections do
		connection:Disconnect()
	end
	table.clear(backpackConnections)
end

local function untrackGearTool(tool: Tool)
	local tracked = trackedGearTools[tool]
	if not tracked then
		return
	end

	trackedGearTools[tool] = nil
	handleGearUnequipped(tracked)
	removeToolFromOrder(tool)
	updateInventorySlots()

	for _, connection in tracked.connections do
		if connection then
			connection:Disconnect()
		end
	end
end

local function isPVPGear(instance: Instance): boolean
	if not instance:IsA("Tool") then
		return false
	end

	return instance:GetAttribute("PVPGenerated") == true
end

local function trackGearTool(tool: Tool)
	if trackedGearTools[tool] or not isPVPGear(tool) then
		return
	end

	local info: GearTrackingInfo = {
		tool = tool,
		isEquipped = false,
		connections = {} :: GearConnections,
	}

	trackedGearTools[tool] = info
	table.insert(trackedGearOrder, tool)
	updateInventorySlots()

	info.connections.equipped = tool.Equipped:Connect(function()
		handleGearEquipped(info)
	end)

	info.connections.unequipped = tool.Unequipped:Connect(function()
		handleGearUnequipped(info)
	end)

	info.connections.ancestry = tool.AncestryChanged:Connect(function(_, parent)
		if parent == localPlayer.Character then
			handleGearEquipped(info)
		else
			handleGearUnequipped(info)
			if parent == nil then
				untrackGearTool(tool)
			end
		end
	end)

	info.connections.destroying = tool.Destroying:Connect(function()
		untrackGearTool(tool)
	end)

	if tool.Parent == localPlayer.Character then
		handleGearEquipped(info)
	else
		updateCursorForGearState()
	end
end

local function trackToolsIn(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("Tool") then
			trackGearTool(child)
		end
	end
end

local function watchBackpack(backpack: Backpack?)
	if currentBackpack == backpack then
		return
	end

	clearBackpackConnections()
	currentBackpack = backpack

	if not backpack then
		updateCursorForGearState()
		updateInventorySlots()
		return
	end

	trackToolsIn(backpack)

	local addedConn = backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			trackGearTool(child)
		end
	end)
	table.insert(backpackConnections, addedConn)
end

local function watchCharacterTools(character: Model)
	if characterGearConn then
		characterGearConn:Disconnect()
		characterGearConn = nil
	end

	trackToolsIn(character)

	characterGearConn = character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			trackGearTool(child)
		end
	end)
end

local function initializeBackpackTracking()
	local backpack = localPlayer:FindFirstChildOfClass("Backpack")
	watchBackpack(backpack)

	localPlayer.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			watchBackpack(child)
		end
	end)

	localPlayer.ChildRemoved:Connect(function(child)
		if child:IsA("Backpack") then
			watchBackpack(nil)
		end
	end)
end

local function playDeathMatchCameraSequence()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local originalFov = camera.FieldOfView
	local zoomOutFov = math.clamp(originalFov + 25, 5, 120)

	local zoomOutTween = TweenService:Create(camera, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		FieldOfView = zoomOutFov,
	})
	zoomOutTween:Play()

	task.delay(0.3, function()
		local activeCamera = Workspace.CurrentCamera
		if activeCamera ~= camera then
			return
		end

		local zoomInTween = TweenService:Create(camera, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			FieldOfView = originalFov,
		})
		zoomInTween:Play()
	end)
end

local function stopDeathMatchTransition()
	if transitionState.active then
		transitionState.token += 1
		transitionState.active = false
	end

	updateHighlightActivation()
end

local function startDeathMatchTransition(duration: number?)
	transitionState.token += 1
	transitionState.active = true
	local currentToken = transitionState.token

	deathMatchHighlightActive = true
	updateHighlightActivation()
	playDeathMatchCameraSequence()

	local delayTime = duration or 3
	task.delay(delayTime, function()
		if transitionState.active and transitionState.token == currentToken then
			stopDeathMatchTransition()
		end
	end)
end

localPlayer:GetPropertyChangedSignal("Team"):Connect(function()
	updateHighlightActivation()
	setSprintEventDisabled(specialEventState.effects.sprintDisabled)
	applyInvertedControlState()
	-- Reset any stuck inputs immediately and shortly after spawn
	resetMovementState(humanoid)
	task.delay(0.20, function() resetMovementState(humanoid) end)
	task.delay(0.60, function() resetMovementState(humanoid) end)
	-- safety: if not inverted after spawn, re-enable defaults
	task.delay(0.2, function() if not (invertedControlState and invertedControlState.active) then hardEnableDefaultControls() end end)
	task.delay(1.0, function() if not (invertedControlState and invertedControlState.active) then hardEnableDefaultControls() end end)
	task.delay(2.0, function() if not (invertedControlState and invertedControlState.active) then hardEnableDefaultControls() end end)
	task.delay(3.0, function() if not (invertedControlState and invertedControlState.active) then hardEnableDefaultControls() end end)
end)

localPlayer:GetPropertyChangedSignal("Neutral"):Connect(function()
	updateHighlightActivation()
	setSprintEventDisabled(specialEventState.effects.sprintDisabled)
	applyInvertedControlState()
	-- Reset any stuck inputs immediately and shortly after spawn
	resetMovementState(humanoid)
	task.delay(0.20, function() resetMovementState(humanoid) end)
	task.delay(0.60, function() resetMovementState(humanoid) end)
	-- safety: if not inverted after spawn, re-enable defaults
	task.delay(0.2, function() if not (invertedControlState and invertedControlState.active) then hardEnableDefaultControls() end end)
	task.delay(1.0, function() if not (invertedControlState and invertedControlState.active) then hardEnableDefaultControls() end end)
	task.delay(2.0, function() if not (invertedControlState and invertedControlState.active) then hardEnableDefaultControls() end end)
	task.delay(3.0, function() if not (invertedControlState and invertedControlState.active) then hardEnableDefaultControls() end end)
end)

initializeBackpackTracking()
updateCursorForGearState()

if mouse then
	UserInputService.MouseIconEnabled = true
	applyDesktopCursorIcon()

	mouse:GetPropertyChangedSignal("Icon"):Connect(function()
		if not applyingMouseIcon then
			applyDesktopCursorIcon()
		end
	end)
end

UserInputService:GetPropertyChangedSignal("MouseBehavior"):Connect(function()
	if mouse then
		applyDesktopCursorIcon()
	end
	updateCenterCursorVisibility()
end)

UserInputService.WindowFocusReleased:Connect(function()
	sprintState.keyboardIntent = false
	sprintState.touchIntent = false
	recomputeSprintIntent()
	stopSprinting(true)
end)

updateCenterCursorVisibility()
updateEnergyUI()
updateHighlightActivation()

local function onHumanoidAdded(humanoid: Humanoid)
	if humanoidSpeedChangedConn then
		humanoidSpeedChangedConn:Disconnect()
		humanoidSpeedChangedConn = nil
	end

	currentHumanoid = humanoid
	if not invertedControlState.requested then
		enableDefaultControlsIfDisabled()
	end
	if humanoidSprintBonusConn then
		humanoidSprintBonusConn:Disconnect()
		humanoidSprintBonusConn = nil
	end
	if humanoid.WalkSpeed <= 0 then
		humanoid.WalkSpeed = DEFAULT_WALK_SPEED
	end

	local currentSpeed = humanoid.WalkSpeed
	local sprintTarget = getSprintTargetSpeed()
	if math.abs(currentSpeed - sprintTarget) < 0.001 then
		currentSpeed = DEFAULT_WALK_SPEED
	end
	sprintState.originalWalkSpeed = currentSpeed

	humanoidSprintBonusConn = humanoid:GetAttributeChangedSignal("SprintSpeedBonus"):Connect(function()
		if sprintState.isSprinting then
			tweenHumanoidSpeed(getSprintTargetSpeed(), true)
		end
	end)

	humanoidSpeedChangedConn = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if sprintState.isSprinting then
			return
		end

		if sprintState.speedTween then
			return
		end

		local newSpeed = humanoid.WalkSpeed
		local target = getSprintTargetSpeed()
		if newSpeed <= 0 then
			newSpeed = DEFAULT_WALK_SPEED
		elseif math.abs(newSpeed - target) < 0.001 then
			newSpeed = DEFAULT_WALK_SPEED
		end

		sprintState.originalWalkSpeed = newSpeed
	end)

	humanoid.Died:Connect(function()
		sprintState.keyboardIntent = false
		sprintState.touchIntent = false
		recomputeSprintIntent()
		stopSprinting(true)
		if invertedControlState.active then disableInvertedControls() end
	hardEnableDefaultControls()
resetMovementState(humanoid)
end)

	applyInvertedControlState()
	-- Reset any stuck inputs immediately and shortly after spawn
	resetMovementState(humanoid)
	task.delay(0.20, function() resetMovementState(humanoid) end)
	task.delay(0.60, function() resetMovementState(humanoid) end)
	-- safety: if not inverted after spawn, re-enable defaults
	task.delay(0.2, function() if not (invertedControlState and invertedControlState.active) then hardEnableDefaultControls() end end)
	task.delay(1.0, function() if not (invertedControlState and invertedControlState.active) then hardEnableDefaultControls() end end)
	task.delay(2.0, function() if not (invertedControlState and invertedControlState.active) then hardEnableDefaultControls() end end)
	task.delay(3.0, function() if not (invertedControlState and invertedControlState.active) then hardEnableDefaultControls() end end)
end

local function onCharacterAdded(character: Model)
	resetSprintState()
	watchCharacterTools(character)
	updateInventorySlots()

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		onHumanoidAdded(humanoid)
	else
		local pendingConn: RBXScriptConnection?
		pendingConn = character.ChildAdded:Connect(function(child)
			if child:IsA("Humanoid") then
				if pendingConn then
					pendingConn:Disconnect()
					pendingConn = nil
				end
				onHumanoidAdded(child)
			end
		end)
	end

	applyInvertedControlState()
	-- Reset any stuck inputs immediately and shortly after spawn
	resetMovementState(humanoid)
	task.delay(0.20, function() resetMovementState(humanoid) end)
	task.delay(0.60, function() resetMovementState(humanoid) end)
	-- safety: if not inverted after spawn, re-enable defaults
	task.delay(0.2, function() if not (invertedControlState and invertedControlState.active) then hardEnableDefaultControls() end end)
	task.delay(1.0, function() if not (invertedControlState and invertedControlState.active) then hardEnableDefaultControls() end end)
	task.delay(2.0, function() if not (invertedControlState and invertedControlState.active) then hardEnableDefaultControls() end end)
	task.delay(3.0, function() if not (invertedControlState and invertedControlState.active) then hardEnableDefaultControls() end end)
end

localPlayer.CharacterAdded:Connect(onCharacterAdded)

localPlayer.CharacterRemoving:Connect(function()
		resetMovementState(humanoid)if invertedControlState and invertedControlState.active then disableInvertedControls() end
		hardEnableDefaultControls()
	sprintState.keyboardIntent = false
	sprintState.touchIntent = false
	recomputeSprintIntent()
	stopSprinting(true)
	if humanoidSpeedChangedConn then
		humanoidSpeedChangedConn:Disconnect()
		humanoidSpeedChangedConn = nil
	end
	if humanoidSprintBonusConn then
		humanoidSprintBonusConn:Disconnect()
		humanoidSprintBonusConn = nil
	end
	currentHumanoid = nil
	if invertedControlState.active then disableInvertedControls() end
	enableDefaultControlsIfDisabled()
	if characterGearConn then
		characterGearConn:Disconnect()
		characterGearConn = nil
	end
	updateCursorForGearState()
	updateInventorySlots()
end)

if localPlayer.Character then
	onCharacterAdded(localPlayer.Character)
else
	resetSprintState()
end

local function toggleKeyboardSprintIntent()
	if sprintState.keyboardIntent then
		sprintState.keyboardIntent = false
		recomputeSprintIntent()
		if not sprintState.sprintIntent then
			stopSprinting(false)
		end
	else
		sprintState.keyboardIntent = true
		recomputeSprintIntent()
		if sprintState.energy > 0 then
			startSprinting()
		end
	end
end

local function sprintAction(_: string, inputState: Enum.UserInputState, inputObject: InputObject?): Enum.ContextActionResult
	local keyCode = if inputObject then inputObject.KeyCode else nil

	if keyCode == Enum.KeyCode.LeftControl or keyCode == Enum.KeyCode.RightControl then
		if inputState == Enum.UserInputState.Begin then
			toggleKeyboardSprintIntent()
		end
		return Enum.ContextActionResult.Sink
	elseif keyCode == Enum.KeyCode.ButtonL3 or keyCode == Enum.KeyCode.ButtonR3 then
		if inputState == Enum.UserInputState.Begin then
			sprintState.keyboardIntent = true
			recomputeSprintIntent()
			if sprintState.energy > 0 then
				startSprinting()
			end
			return Enum.ContextActionResult.Sink
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			sprintState.keyboardIntent = false
			recomputeSprintIntent()
			if not sprintState.sprintIntent then
				stopSprinting(false)
			end
			return Enum.ContextActionResult.Sink
		end
	elseif keyCode == Enum.KeyCode.ButtonX then
		if inputState == Enum.UserInputState.Begin then
			toggleKeyboardSprintIntent()
			return Enum.ContextActionResult.Sink
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			return Enum.ContextActionResult.Sink
		end
	elseif not inputObject then
		if inputState == Enum.UserInputState.Begin then
			toggleTouchSprintIntent()
			return Enum.ContextActionResult.Sink
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			return Enum.ContextActionResult.Sink
		end
	end

	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction(
	"SprintAction",
	sprintAction,
	true,
	Enum.KeyCode.LeftControl,
	Enum.KeyCode.RightControl,
	Enum.KeyCode.ButtonL3,
	Enum.KeyCode.ButtonR3,
	Enum.KeyCode.ButtonX
)
sprintInteraction.actionBound = true
ContextActionService:SetTitle("SprintAction", "Sprint")
ContextActionService:SetImage("SprintAction", GEAR_CURSOR_IMAGE_ASSET)
updateSprintButtonState()

local keyToSlotIndex: {[Enum.KeyCode]: number} = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
	[Enum.KeyCode.Zero] = 10,
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	local slotIndex = keyToSlotIndex[input.KeyCode]
	if slotIndex then
		equipInventorySlot(slotIndex)
	end
end)

RunService.Heartbeat:Connect(function(deltaTime)
	local dt = math.max(deltaTime, 0)
	local now = os.clock()
	local humanoid = currentHumanoid
	local isMoving = false
	if humanoid then
		isMoving = humanoid.MoveDirection.Magnitude > 0.01
	end

	if not isMoving and sprintState.rechargeBlockedUntil > now then
		sprintState.rechargeBlockedUntil = now
	end

	local zoneBlocked = false
	local zonePart = sprintInteraction.noSprintPart
	if zonePart and zonePart.Parent and humanoid then
		local rootPart = getHumanoidRootPart(humanoid)
		if rootPart then
			zoneBlocked = isPointInsidePart(zonePart, rootPart.Position)
		end
	end

	if zoneBlocked ~= sprintState.zoneBlocked then
		sprintState.zoneBlocked = zoneBlocked

		if zoneBlocked then
			local wasSprinting = sprintState.isSprinting
			if sprintState.touchIntent then
				sprintState.touchIntent = false
			end
			if sprintState.keyboardIntent then
				sprintState.keyboardIntent = false
			end

			if wasSprinting then
				stopSprinting(true)
				sprintState.rechargeBlockedUntil = 0
			else
				updateEnergyUI()
			end
		end

		recomputeSprintIntent()

		if not zoneBlocked then
			updateEnergyUI()
		end
	end

	if sprintState.sprintIntent and not sprintState.isSprinting and sprintState.energy > 0 then
		startSprinting()
	end

	if sprintState.isSprinting then
		if isMoving then
			sprintState.energy = math.max(0, sprintState.energy - dt * SPRINT_DRAIN_RATE)
			sprintState.rechargeBlockedUntil = now + SPRINT_RECHARGE_DELAY

			if sprintState.energy <= 0 then
				sprintState.energy = 0
				if sprintState.touchIntent then
					sprintState.touchIntent = false
				end
				if sprintState.keyboardIntent then
					sprintState.keyboardIntent = false
				end
				recomputeSprintIntent()
				stopSprinting(false)
			end
		else
			if sprintState.energy < MAX_SPRINT_ENERGY then
				sprintState.energy = math.min(MAX_SPRINT_ENERGY, sprintState.energy + dt * SPRINT_RECHARGE_RATE)
			end
			sprintState.rechargeBlockedUntil = now
		end
	elseif sprintState.energy < MAX_SPRINT_ENERGY and now >= sprintState.rechargeBlockedUntil then
		sprintState.energy = math.min(MAX_SPRINT_ENERGY, sprintState.energy + dt * SPRINT_RECHARGE_RATE)
	end

	updateEnergyUI()

	if mouse and not applyingMouseIcon and mouse.Icon ~= currentCursorImageAsset then
		applyDesktopCursorIcon()
	end
end)

local function resetFrameVisual()
	statusUI.frame.BackgroundColor3 = UI_CONFIG.DEFAULT_BACKGROUND_COLOR
	statusUI.frame.BackgroundTransparency = UI_CONFIG.DEFAULT_BACKGROUND_TRANSPARENCY
	statusUI.stroke.Color = Color3.fromRGB(120, 135, 200)
	statusUI.stroke.Transparency = 0.35
	statusUI.frame.Position = baseFramePosition
	statusUI.label.TextColor3 = defaultColor
	statusUI.label.TextSize = UI_CONFIG.DEFAULT_TEXT_SIZE
	statusUI.label.Position = baseLabelPosition
	statusUI.label.Rotation = 0
	statusUI.labelStroke.Transparency = 0.3
end

local function stopFlash()
	if flashConnection then
		flashConnection:Disconnect()
		flashConnection = nil
	end

	statusUI.label.TextColor3 = matchColor
	statusUI.labelStroke.Color = Color3.fromRGB(20, 20, 35)
	statusUI.labelStroke.Transparency = 0.3
end

local function startFlash()
	stopFlash()

	statusUI.labelStroke.Color = Color3.fromRGB(255, 110, 110)
	statusUI.labelStroke.Transparency = 0

	flashConnection = RunService.RenderStepped:Connect(function()
		local timeScale = math.clamp(currentRemaining / 30, 0, 1)
		local frequency = 3 + (1 - timeScale) * 6
		local pulse = math.abs(math.sin(os.clock() * frequency))
		local green = 60 + math.floor(140 * (1 - pulse))
		statusUI.label.TextColor3 = Color3.fromRGB(255, green, green)
	end)
end

local function resetNeutralButtonShakeTargets()
	for _, target in neutralButtonShakeTargets do
		local instance = target.instance
		if instance and instance.Parent then
			instance.Position = target.basePosition
			instance.Rotation = target.baseRotation or 0
		end
	end

	table.clear(neutralButtonShakeTargets)
end

local function collectNeutralButtonShakeTargets()
	resetNeutralButtonShakeTargets()

	if not localPlayer.Neutral then
		return
	end

	for _, slot in inventorySlots do
		local frame = slot.frame
		if frame then
			table.insert(neutralButtonShakeTargets, {
				instance = frame,
				basePosition = frame.Position,
				baseRotation = frame.Rotation,
			})
		end
	end
end

local function stopShake()
	if shakeConnection then
		shakeConnection:Disconnect()
		shakeConnection = nil
	end

	resetNeutralButtonShakeTargets()

	statusUI.frame.Position = baseFramePosition
	statusUI.label.Position = baseLabelPosition
	statusUI.label.Rotation = 0
	statusUI.label.TextColor3 = defaultColor
	statusUI.label.TextSize = UI_CONFIG.DEFAULT_TEXT_SIZE

	if uiRefs.inventoryFrame then
		uiRefs.inventoryFrame.Position = inventoryState.basePosition
		uiRefs.inventoryFrame.Rotation = inventoryState.baseRotation
	end
	sprintUI.container.Position = sprintUI.basePosition
	sprintUI.container.Rotation = sprintUI.baseRotation
	sprintUI.background.BackgroundColor3 = sprintUI.defaults.backgroundColor
	sprintUI.background.BackgroundTransparency = sprintUI.defaults.backgroundTransparency
	sprintUI.backgroundStroke.Color = sprintUI.defaults.strokeColor
	sprintUI.backgroundStroke.Transparency = sprintUI.defaults.strokeTransparency
	uiRefs.energyBarFill.BackgroundColor3 = sprintUI.defaults.energyBarFillColor
	uiRefs.energyTextLabel.TextColor3 = sprintUI.defaults.energyTextColor
	sprintUI.energyFillGradient.Color = sprintUI.defaults.energyGradientColor

	for _, slot in inventorySlots do
		local frame = slot.frame
		if frame then
			frame.Rotation = 0
		end
	end

	updateInventorySlots()
end

local function startDeathMatchEffect()
	stopFlash()
	stopShake()

	statusUI.frame.BackgroundColor3 = deathMatchBackground
	statusUI.stroke.Color = deathMatchStroke
	statusUI.stroke.Transparency = 0
	statusUI.frame.BackgroundTransparency = 1
	statusUI.label.TextSize = UI_CONFIG.EMPHASIZED_TEXT_SIZE
	statusUI.labelStroke.Transparency = 0

	collectNeutralButtonShakeTargets()

	shakeConnection = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local frameMagnitude = 1 + math.abs(math.sin(now * 5)) * 1.4
		local offsetX = math.noise(now * 8, 0, 0) * frameMagnitude * 4
		local offsetY = math.noise(now * 9, 1, 0) * frameMagnitude * 3
		statusUI.frame.Position = baseFramePosition + UDim2.fromOffset(offsetX, offsetY)

		local textMagnitude = 0.5 + math.abs(math.sin(now * 12)) * 1.5
		local textOffsetX = math.noise(now * 20, 2, 0) * textMagnitude * 4
		local textOffsetY = math.noise(now * 18, 3, 0) * textMagnitude * 3
		local buttonOffset = UDim2.fromOffset(textOffsetX, textOffsetY)
		statusUI.label.Position = baseLabelPosition + buttonOffset
		statusUI.label.Rotation = math.noise(now * 14, 4, 0) * 8

		local pulse = (math.sin(now * 6) + 1) / 2
		local colorOffset = math.floor(40 * pulse)
		statusUI.label.TextColor3 = Color3.fromRGB(255, 90 + colorOffset, 90 + colorOffset)

		if uiRefs.inventoryFrame then
			local inventoryMagnitude = 0.6 + math.abs(math.sin(now * 6)) * 1.3
			local inventoryOffsetX = math.noise(now * 11, 5, 0) * inventoryMagnitude * 3
			local inventoryOffsetY = math.noise(now * 10, 6, 0) * inventoryMagnitude * 2
			uiRefs.inventoryFrame.Position = inventoryState.basePosition + UDim2.fromOffset(inventoryOffsetX, inventoryOffsetY)
			uiRefs.inventoryFrame.Rotation = math.noise(now * 9, 7, 0) * 2.4
		end

		local sprintOffsetX = math.noise(now * 7, 8, 0) * 2.6
		local sprintOffsetY = math.noise(now * 8, 9, 0) * 2.1
		sprintUI.container.Position = sprintUI.basePosition + UDim2.fromOffset(sprintOffsetX, sprintOffsetY)
		sprintUI.container.Rotation = math.noise(now * 13, 10, 0) * 1.8

		local flashPulse = (math.sin(now * 12) + 1) * 0.5
		local flashNoise = math.clamp(math.noise(now * 15, 11, 0) * 0.5 + 0.5, 0, 1)
		local flashAmount = math.clamp(flashPulse * 0.6 + flashNoise * 0.4, 0, 1)
		local baseRed = 150 + math.floor(105 * flashAmount)
		local dimComponent = 25 + math.floor(90 * (1 - flashAmount))
		sprintUI.background.BackgroundColor3 = Color3.fromRGB(baseRed, dimComponent, dimComponent)
		sprintUI.background.BackgroundTransparency = 0.05 + (1 - flashAmount) * 0.2

		local strokeGreen = 60 + math.floor(120 * (1 - flashAmount))
		sprintUI.backgroundStroke.Color = Color3.fromRGB(255, strokeGreen, strokeGreen)
		sprintUI.backgroundStroke.Transparency = 0.05 + flashAmount * 0.25

		local energyPulse = math.abs(math.sin(now * 18))
		local energyGreen = 40 + math.floor(150 * (1 - energyPulse))
		uiRefs.energyBarFill.BackgroundColor3 = Color3.fromRGB(255, energyGreen, energyGreen)
		sprintUI.energyFillGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, math.max(0, energyGreen - 60), math.max(0, energyGreen - 60))),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, energyGreen, energyGreen)),
		})
		uiRefs.energyTextLabel.TextColor3 = Color3.fromRGB(255, 180 - math.floor(80 * flashAmount), 180 - math.floor(80 * flashAmount))

		for slotIndex = 1, 10 do
			local slot = inventorySlots[slotIndex]
			if slot then
				local slotPulse = math.abs(math.sin(now * 14 + slotIndex))
				local slotNoise = math.noise(now * 16, slotIndex, 0)
				local frame = slot.frame
				local stroke = slot.stroke
				if frame then
					frame.Rotation = slotNoise * 3
				end
				if stroke then
					local slotGreen = 50 + math.floor(150 * (1 - slotPulse))
					stroke.Color = Color3.fromRGB(255, slotGreen, slotGreen)
					stroke.Transparency = 0.05 + slotPulse * 0.25
				end
			end
		end

		if not localPlayer.Neutral then
			if #neutralButtonShakeTargets > 0 then
				resetNeutralButtonShakeTargets()
			end
		else
			for index = #neutralButtonShakeTargets, 1, -1 do
				local target = neutralButtonShakeTargets[index]
				local instance = target.instance
				if not instance or not instance.Parent then
					table.remove(neutralButtonShakeTargets, index)
				else
					instance.Position = target.basePosition + buttonOffset
				end
			end
		end
	end)
end

local function hideStatus()
	stopFlash()
	stopShake()
	stopDeathMatchTransition()
	statusUI.frame.Visible = false
	statusUI.label.Text = ""
end

local function getMapDisplayName(mapId: string): string
	return mapDisplayNames[mapId] or mapId
end

local function updateEventLabelText()
	local label = uiRefs.eventLabel
	local container = uiRefs.mapLabelContainer
	if not label or not container then
		return
	end

	if container:GetAttribute("HasMap") ~= true then
		label.Text = ""
		return
	end

	local displayName = currentEventDisplayName
	if displayName and displayName ~= "" then
		label.Text = string.format("Event: %s", displayName)
	else
		label.Text = "Event: None"
	end
end

local function setCurrentEventDisplayName(name: string?)
	if name and name ~= "" then
		currentEventDisplayName = name
	else
		currentEventDisplayName = nil
	end
	updateEventLabelText()
end

local function updateMapLabel(mapId: string?)
	currentMapId = mapId

	local targetLabel = uiRefs.mapLabel
	local container = uiRefs.mapLabelContainer
	if not targetLabel or not container then
		return
	end

	if mapId then
		targetLabel.Text = string.format("Map: %s", getMapDisplayName(mapId))
		container:SetAttribute("HasMap", true)
		container.Visible = statusUI.frame.Visible
		updateEventLabelText()
	else
		targetLabel.Text = ""
		container:SetAttribute("HasMap", false)
		container.Visible = false
		updateEventLabelText()
	end
end

local function formatCountdown(seconds: number): string
	if seconds <= 0 then
		return "Match starting..."
	end
	return string.format("Starting in %ds", seconds)
end

local function formatTimer(seconds: number): string
	local minutes = math.floor(seconds / 60)
	local remainingSeconds = seconds % 60
	return string.format("%d:%02d", minutes, remainingSeconds)
end


-- Lightweight StormEffects to avoid register pressure
local StormEffects = {}
function StormEffects.enable(...) end
function StormEffects.disable(...) end
function StormEffects.setTrackedPart(...) end
function StormEffects.update(...) end


statusRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local action = payload.action
	if action == "PrepCountdown" then
		currentRemaining = tonumber(payload.remaining) or 0
		if typeof(payload.map) == "string" then
			updateMapLabel(payload.map)
		end
		stopShake()
		stopFlash()
		resetFrameVisual()
		statusUI.frame.BackgroundTransparency = UI_CONFIG.DEFAULT_BACKGROUND_TRANSPARENCY
		statusUI.frame.Visible = true
		statusUI.label.TextColor3 = countdownColor
		statusUI.label.TextSize = UI_CONFIG.EMPHASIZED_TEXT_SIZE
		statusUI.label.Text = formatCountdown(currentRemaining)
		statusUI.labelStroke.Transparency = 0.1
	elseif action == "MatchTimer" then
		currentRemaining = math.max(0, math.floor(tonumber(payload.remaining) or 0))
		statusUI.frame.Visible = true
		resetFrameVisual()
		statusUI.label.TextColor3 = matchColor
		statusUI.label.Text = formatTimer(currentRemaining)

		if currentRemaining <= 30 then
			startFlash()
		else
			stopFlash()
		end
	elseif action == "MatchMessage" then
		stopFlash()
		stopShake()
		statusUI.frame.Visible = true
		resetFrameVisual()
		statusUI.label.TextColor3 = matchColor
		statusUI.label.TextSize = UI_CONFIG.EMPHASIZED_TEXT_SIZE
		statusUI.label.Text = if typeof(payload.text) == "string" then payload.text else ""
		statusUI.labelStroke.Transparency = 0.2
	elseif action == "DeathMatchTransition" then
		stopFlash()
		stopShake()
		statusUI.frame.Visible = true
		statusUI.frame.BackgroundColor3 = deathMatchBackground
		statusUI.stroke.Color = deathMatchStroke
		statusUI.stroke.Transparency = 0
		statusUI.label.TextColor3 = matchColor
		statusUI.label.TextSize = UI_CONFIG.EMPHASIZED_TEXT_SIZE
		statusUI.label.Text = "Death Match"
		statusUI.frame.BackgroundTransparency = 1
		statusUI.labelStroke.Transparency = 0

		local duration = tonumber(payload.duration) or 3
		deathMatchHighlightActive = true
		updateHighlightActivation()
		startDeathMatchTransition(duration)
	elseif action == "DeathMatch" then
		local isActive = payload.active == nil or payload.active
		if isActive then
			deathMatchHighlightActive = true
			stopDeathMatchTransition()
			statusUI.frame.Visible = true
			statusUI.label.Text = "Death Match"
			startDeathMatchEffect()
		else
			deathMatchHighlightActive = false
			stopShake()
			stopFlash()
			stopDeathMatchTransition()
			resetFrameVisual()
			statusUI.frame.Visible = false
		end
	elseif action == "RoundEnded" then
		deathMatchHighlightActive = false
		updateHighlightActivation()
		stopDeathMatchTransition()
		stopFlash()
		stopShake()
		resetFrameVisual()
		setHotTouchActive(false)
		statusUI.frame.Visible = true
		statusUI.label.TextColor3 = countdownColor
		statusUI.label.TextSize = UI_CONFIG.DEFAULT_TEXT_SIZE
		statusUI.label.Text = "Intermission"
		statusUI.labelStroke.Transparency = 0.3
		updateMapLabel(nil)
		specialEventState.active = false
		specialEventState.id = nil
		specialEventState.displayName = nil
		specialEventState.randomized = false
		specialEventState.options = {}
		specialEventState.finalName = nil
		specialEventState.effects.sprintDisabled = false
		specialEventState.effects.invisible = false
		specialEventState.effects.inverted = false
		setSprintEventDisabled(false)
		setInvisibilityEnabled(false)
		setInvertedControlsEnabled(false)
		hideSpecialEvent(true)
		setCurrentEventDisplayName(nil)
	elseif action == "SpecialEventRandomizing" then
		local headerText = if typeof(payload.header) == "string" then payload.header else "- Special Round -"
		specialEventUI.header.Text = headerText

		local options: {{id: string?, name: string?}} = {}
		if typeof(payload.options) == "table" then
			for _, item in ipairs(payload.options) do
				if typeof(item) == "table" then
					table.insert(options, {
						id = if typeof(item.id) == "string" then item.id else nil,
						name = if typeof(item.name) == "string" then item.name else nil,
					})
				elseif typeof(item) == "string" then
					table.insert(options, {id = item, name = item})
				end
			end
		end

		local duration = tonumber(payload.duration)
		local chosenName = if typeof(payload.chosenName) == "string" then payload.chosenName elseif typeof(payload.chosenId) == "string" then payload.chosenId else nil
		specialEventState.displayName = "Randomizing..."
		setCurrentEventDisplayName("Randomizing...")
		beginSpecialEventRandomization(options, chosenName, duration)
	elseif action == "SpecialEvent" then
		local headerText = if typeof(payload.header) == "string" then payload.header else "- Special Round -"
		specialEventUI.header.Text = headerText

		local isActive = payload.active
		if isActive == false then
			specialEventState.active = false
			specialEventState.id = nil
			specialEventState.displayName = nil
			specialEventState.randomized = false
			specialEventState.options = {}
			specialEventState.finalName = nil
			setSprintEventDisabled(false)
			setInvisibilityEnabled(false)
			setInvertedControlsEnabled(false)
			hideSpecialEvent(true)
			setHotTouchActive(false)
			setCurrentEventDisplayName(nil)
		else
			local eventId = if typeof(payload.id) == "string" then payload.id else nil
			local eventName = if typeof(payload.name) == "string" then payload.name elseif eventId then eventId else "Special Event"
			specialEventState.active = true
			specialEventState.id = eventId
			specialEventState.displayName = eventName
			setCurrentEventDisplayName(eventName)

			if eventId == "HotTouch" then
				setHotTouchActive(true)
			else
				setHotTouchActive(false)
			end

			if payload.randomized then
				completeSpecialEventRandomization(eventName)
			else
				specialEventState.randomized = false
				showSpecialEvent(eventName, 3)
			end
		end
	elseif action == "SpecialEventEffect" then
		if payload.sprintDisabled ~= nil then
			local disabled = payload.sprintDisabled == true
			specialEventState.effects.sprintDisabled = disabled
			setSprintEventDisabled(disabled)
		end

		if payload.invisible ~= nil then
			local invisibleEnabled = payload.invisible == true
			specialEventState.effects.invisible = invisibleEnabled
			setInvisibilityEnabled(invisibleEnabled)
		end

		if payload.inverted ~= nil then
			local invertedEnabled = payload.inverted == true
			specialEventState.effects.inverted = invertedEnabled
			setInvertedControlsEnabled(invertedEnabled)
		end
	elseif action == "HotTouchStatus" then
		local state = if typeof(payload.state) == "string" then payload.state else ""
		if state == "Holder" then
			local userId = if typeof(payload.userId) == "number" then payload.userId elseif typeof(payload.userId) == "string" then tonumber(payload.userId) else nil
			currentHotTouchHolderId = userId
			local name = if typeof(payload.displayName) == "string" then payload.displayName elseif typeof(payload.name) == "string" then payload.name else "Someone"
			setHotTouchActive(true)
			setHotTouchStatusText(string.format("%s has the BOMB!", name))
		elseif state == "Selecting" then
			currentHotTouchHolderId = nil
			setHotTouchActive(true)
			setHotTouchStatusText("Selecting random...")
		elseif state == "Complete" then
			currentHotTouchHolderId = nil
			setHotTouchActive(true)
			setHotTouchStatusText("GG")
		elseif state == "Clear" then
			currentHotTouchHolderId = nil
			setHotTouchActive(false)
		else
			currentHotTouchHolderId = nil
			setHotTouchStatusText(nil)
		end
	elseif action == "HotTouchTagged" then
		local taggedUserId = if typeof(payload.userId) == "number" then payload.userId elseif typeof(payload.userId) == "string" then tonumber(payload.userId) else nil
		if taggedUserId and localPlayer.UserId == taggedUserId then
			showHotTouchAlert()
		end
	end
end)

--!strict
-- Place this LocalScript in StarterPlayerScripts so it only runs for each player.
-- It will create an owner-only control panel button that slides in and out with animation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local allowedUserIds = {
	[347735445] = true,
}

type MapDefinition = {
	id: string,
	displayName: string,
	modelName: string,
}

type EventDefinition = {
	id: string,
	displayName: string,
	description: string?,
}

local mapDefinitions: {MapDefinition} = {
	{
		id = "Crossroad",
		displayName = "Crossroad",
		modelName = "Crossroad",
	},
	{
		id = "SFOTH",
		displayName = "SFOTH",
		modelName = "SFOTH",
	},
	{
		id = "ChaosCanyon",
		displayName = "Chaos Canyon",
		modelName = "ChaosCanyon",
	},
	{
		id = "Doomspire",
		displayName = "Doomspire",
		modelName = "Doomspire",
	},
	{
		id = "GlassHouses",
		displayName = "Glass Houses",
		modelName = "GlassHouses",
	},
	{
		id = "RobloxHQ",
		displayName = "Roblox HQ",
		modelName = "RobloxHQ",
	},
	{
		id = "RocketArena",
		displayName = "Rocket Arena",
		modelName = "RocketArena",
	},
	{
		id = "HauntedMansion",
		displayName = "Haunted Mansion",
		modelName = "HauntedMansion",
	},
	{
		id = "BowlingAlley",
		displayName = "Bowling Alley",
		modelName = "BowlingAlley",
	},
	{
		id = "HappyHomeOfRobloxia",
		displayName = "Happy Home of Robloxia",
		modelName = "HappyHomeOfRobloxia",
	},
        {
                id = "RavenRock",
                displayName = "Raven Rock",
                modelName = "RavenRock",
        },
        {
                id = "PirateBay",
                displayName = "Pirate Bay",
                modelName = "PirateBay",
        },

}

local specialEventOptions: {EventDefinition} = {
	{
		id = "RANDOM",
		displayName = "🎲 RANDOM",
		description = "Pick a surprise event when the round begins.",
	},
	{
		id = "ShatteredHeart",
		displayName = "💔 Shattered Heart",
		description = "Neutral players cling to a single hit point.",
	},
	{
		id = "SprintProhibit",
		displayName = "🚫 Sprint Prohibit",
		description = "Neutral players cannot sprint.",
	},
	{
		id = "Retro",
		displayName = "🕹️ RETRO",
		description = "Neutral players receive retro gear only.",
	},
	{
		id = "Invisible",
		displayName = "👻 Invisible",
		description = "Neutral players turn translucent ninjas.",
	},
	{
		id = "Bunny",
		displayName = "🐰 Bunny",
		description = "Neutral players are powered by pogo legs.",
	},
	{
		id = "Slippery",
		displayName = "🧊 Slippery",
		description = "The arena loses all traction.",
	},
	{
		id = "KillBot",
		displayName = "🤖 KillBot",
		description = "Three rogue bots patrol the arena.",
	},
        {
                id = "RainingBomb",
                displayName = "💣 Raining Bomb",
                description = "Explosive hail falls from the sky.",
        },
        {
                id = "HotTouch",
                displayName = "🔥 Hot Touch",
                description = "Pass the explosive countdown or perish.",
        },
}

local eventDefinitionById: {[string]: EventDefinition} = {}
for _, definition in ipairs(specialEventOptions) do
	eventDefinitionById[definition.id] = definition
end

local CHECK_ICON_ASSET_ID = "rbxassetid://7072706620"
local DEFAULT_EVENT_DESCRIPTION = "Pick an optional twist for the round."

local mapButtonDefaultColor = Color3.fromRGB(190, 60, 60)
local mapButtonSelectedColor = Color3.fromRGB(70, 170, 95)
local mapButtonTextColor = Color3.fromRGB(255, 255, 255)
local mapButtonDefaultGradient = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 70, 80)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 40, 50)),
})
local mapButtonSelectedGradient = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(85, 190, 120)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(55, 150, 90)),
})
local selectionTweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local remotesFolder = ReplicatedStorage:FindFirstChild("PVPRemotes")
if not remotesFolder then
	remotesFolder = ReplicatedStorage:WaitForChild("PVPRemotes", 5)
end

local startRoundRemote: RemoteEvent? = nil
local roundStateRemote: RemoteEvent? = nil

if remotesFolder and remotesFolder:IsA("Folder") then
	startRoundRemote = remotesFolder:FindFirstChild("StartRound") :: RemoteEvent?
	roundStateRemote = remotesFolder:FindFirstChild("RoundState") :: RemoteEvent?

	remotesFolder.ChildAdded:Connect(function(child)
		if child.Name == "StartRound" and child:IsA("RemoteEvent") then
			startRoundRemote = child
		elseif child.Name == "RoundState" and child:IsA("RemoteEvent") then
			roundStateRemote = child
		end
	end)
end

local function isGameOwner(): boolean
	if allowedUserIds[player.UserId] then
		return true
	end

	local creatorId = game.CreatorId
	local creatorType = game.CreatorType

	if creatorType == Enum.CreatorType.User then
		return player.UserId == creatorId
	elseif creatorType == Enum.CreatorType.Group then
		-- Treat the group owner (rank 255) as the "game owner"
		local success, rank = pcall(function()
			return player:GetRankInGroup(creatorId)
		end)

		return success and rank == 255
	end

	return false
end

if not isGameOwner() then
	return
end

local playerGui = player:WaitForChild("PlayerGui")

local existingScreenGui = playerGui:FindFirstChild("OwnerPanel")
if existingScreenGui then
	existingScreenGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "OwnerPanel"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local panelWidth = 240
local panelHeight = 200
local buttonWidth = 32

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(panelWidth, panelHeight)
panel.Position = UDim2.new(0, -panelWidth + buttonWidth, 0.5, -panelHeight / 2)
panel.BackgroundColor3 = Color3.fromRGB(32, 35, 50)
panel.BorderSizePixel = 0
panel.AnchorPoint = Vector2.new(0, 0)
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 62, 85)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(32, 35, 50))
})
gradient.Rotation = 90
gradient.Parent = panel

panel.ZIndex = 2

local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.Size = UDim2.new(1, 20, 1, 20)
shadow.Position = UDim2.new(0.5, 0, 0.5, 6)
shadow.AnchorPoint = Vector2.new(0.5, 0.5)
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://1316045217"
shadow.ImageTransparency = 0.4
shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
shadow.ZIndex = 0
shadow.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.AnchorPoint = Vector2.new(0, 0)
title.Position = UDim2.new(0, 20, 0, 20)
title.Size = UDim2.new(1, -40, 0, 32)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "Owner Panel"
title.TextColor3 = Color3.fromRGB(245, 245, 255)
title.TextSize = 22
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local buttonContainer = Instance.new("Frame")
buttonContainer.Name = "ButtonContainer"
buttonContainer.Size = UDim2.new(1, -40, 0, 48)
buttonContainer.Position = UDim2.new(0, 20, 0, 80)
buttonContainer.BackgroundTransparency = 1
buttonContainer.Parent = panel

local buttonLayout = Instance.new("UIListLayout")
buttonLayout.FillDirection = Enum.FillDirection.Vertical
buttonLayout.VerticalAlignment = Enum.VerticalAlignment.Top
buttonLayout.Padding = UDim.new(0, 10)
buttonLayout.Parent = buttonContainer

local pvpButton = Instance.new("TextButton")
pvpButton.Name = "PVPButton"
pvpButton.Size = UDim2.new(0, 160, 0, 36)
pvpButton.BackgroundColor3 = Color3.fromRGB(94, 108, 160)
pvpButton.AutoButtonColor = false
pvpButton.Font = Enum.Font.GothamBold
pvpButton.Text = "PVP"
pvpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
pvpButton.TextSize = 18
pvpButton.TextStrokeTransparency = 0.4
pvpButton.ZIndex = 4
pvpButton.Parent = buttonContainer

local pvpButtonCorner = Instance.new("UICorner")
pvpButtonCorner.CornerRadius = UDim.new(0, 8)
pvpButtonCorner.Parent = pvpButton

local pvpButtonStroke = Instance.new("UIStroke")
pvpButtonStroke.Thickness = 1.5
pvpButtonStroke.Color = Color3.fromRGB(150, 160, 210)
pvpButtonStroke.Transparency = 0.3
pvpButtonStroke.Parent = pvpButton

local toggleButton = Instance.new("ImageButton")
toggleButton.Name = "ToggleButton"
toggleButton.Size = UDim2.fromOffset(buttonWidth, 60)
toggleButton.AnchorPoint = Vector2.new(0.5, 0.5)
toggleButton.Position = UDim2.new(0, panelWidth - (buttonWidth / 2), 0.5, 0)
toggleButton.BackgroundColor3 = Color3.fromRGB(74, 87, 120)
toggleButton.AutoButtonColor = false
toggleButton.Image = "rbxassetid://4726772330"
toggleButton.ImageColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.ScaleType = Enum.ScaleType.Fit
toggleButton.Parent = panel

toggleButton.ZIndex = 3

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(1, 0)
buttonCorner.Parent = toggleButton

local buttonGradient = Instance.new("UIGradient")
buttonGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(101, 115, 173)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(74, 87, 120))
})
buttonGradient.Parent = toggleButton

local glow = Instance.new("UIStroke")
glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
glow.Thickness = 1.5
glow.Color = Color3.fromRGB(120, 135, 200)
glow.Transparency = 0.2
glow.Parent = toggleButton

local pvpFrame = Instance.new("Frame")
pvpFrame.Name = "PVPPanel"
pvpFrame.Size = UDim2.fromOffset(480, 560)
pvpFrame.Position = UDim2.fromScale(0.5, 0.5)
pvpFrame.AnchorPoint = Vector2.new(0.5, 0.5)
pvpFrame.BackgroundColor3 = Color3.fromRGB(25, 28, 40)
pvpFrame.Visible = false
pvpFrame.ZIndex = 5
pvpFrame.Parent = screenGui

local pvpCorner = Instance.new("UICorner")
pvpCorner.CornerRadius = UDim.new(0, 12)
pvpCorner.Parent = pvpFrame

local pvpStroke = Instance.new("UIStroke")
pvpStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
pvpStroke.Thickness = 3
pvpStroke.Color = Color3.fromRGB(100, 150, 255)
pvpStroke.Transparency = 0.2
pvpStroke.Parent = pvpFrame

local pvpGradient = Instance.new("UIGradient")
pvpGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 45, 65)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(25, 28, 40))
})
pvpGradient.Rotation = 90
pvpGradient.Parent = pvpFrame

local pvpTitle = Instance.new("TextLabel")
pvpTitle.Name = "PVPTitle"
pvpTitle.Size = UDim2.new(1, -40, 0, 35)
pvpTitle.Position = UDim2.new(0, 20, 0, 15)
pvpTitle.BackgroundTransparency = 1
pvpTitle.Font = Enum.Font.GothamBold
pvpTitle.Text = "⚔️ PVP MATCH"
pvpTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
pvpTitle.TextSize = 24
pvpTitle.TextXAlignment = Enum.TextXAlignment.Center
pvpTitle.TextStrokeTransparency = 0.3
pvpTitle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
pvpTitle.ZIndex = 6
pvpTitle.Parent = pvpFrame

local function createRowSection(
	name: string,
	headerText: string,
	positionOffset: number,
	sectionHeight: number?,
	listHeight: number?
)
	local section = Instance.new("Frame")
	section.Name = name
	section.Size = UDim2.new(1, -40, 0, sectionHeight or 120)
	section.Position = UDim2.new(0, 20, 0, positionOffset)
	section.BackgroundTransparency = 1
	section.ZIndex = 6
	section.Parent = pvpFrame

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 24)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.GothamBold
	header.Text = headerText
	header.TextColor3 = Color3.fromRGB(245, 245, 255)
	header.TextSize = 20
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.ZIndex = 6
	header.Parent = section

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Size = UDim2.new(1, 0, 0, listHeight or 72)
	list.Position = UDim2.new(0, 0, 0, 32)
	list.BackgroundTransparency = 1
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.ScrollBarThickness = 4
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.ZIndex = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.None
	list.BottomImage = "rbxassetid://9416839567"
	list.MidImage = "rbxassetid://9416839567"
	list.TopImage = "rbxassetid://9416839567"
	list.Parent = section

	local padding = Instance.new("UIPadding")
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 4)
	padding.Parent = list

	local layout = Instance.new("UIGridLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.CellPadding = UDim2.fromOffset(12, 10)
	layout.CellSize = UDim2.new(0.5, -10, 0, 52)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		local contentSize = layout.AbsoluteContentSize
		list.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 12)
	end)

	return section, list
end

local mapSection, mapList = createRowSection("MapSection", "🗺️ Map Selection", 60, 160, 120)
local eventSection, eventList = createRowSection("EventSection", "🎲 Special Events", 240, 260, 120)

local eventDescriptionLabel = Instance.new("TextLabel")
eventDescriptionLabel.Name = "EventDescription"
eventDescriptionLabel.Size = UDim2.new(1, 0, 0, 40)
eventDescriptionLabel.Position = UDim2.new(0, 0, 0, 160)
eventDescriptionLabel.BackgroundTransparency = 1
eventDescriptionLabel.Font = Enum.Font.Gotham
eventDescriptionLabel.Text = DEFAULT_EVENT_DESCRIPTION
eventDescriptionLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
eventDescriptionLabel.TextSize = 16
eventDescriptionLabel.TextWrapped = true
eventDescriptionLabel.TextXAlignment = Enum.TextXAlignment.Center
eventDescriptionLabel.TextYAlignment = Enum.TextYAlignment.Top
eventDescriptionLabel.TextTransparency = 0
eventDescriptionLabel.ZIndex = 6
eventDescriptionLabel.Parent = eventSection

local difficultyButtons: {[number]: TextButton} = {}
local selectedDifficulty: number? = nil
local difficultyStatusLabel: TextLabel? = nil

local function applySelectionVisual(button: TextButton, isSelected: boolean)
        button.BackgroundColor3 = isSelected and mapButtonSelectedColor or mapButtonDefaultColor
        button.TextColor3 = mapButtonTextColor
        button.AutoButtonColor = not isSelected

        local stroke = button:FindFirstChildOfClass("UIStroke")
        if stroke then
                stroke.Color = isSelected and Color3.fromRGB(185, 255, 205) or Color3.fromRGB(120, 40, 40)
                stroke.Transparency = isSelected and 0 or 0.2
        end

        local gradient = button:FindFirstChild("SelectionGradient")
        if gradient and gradient:IsA("UIGradient") then
                gradient.Color = isSelected and mapButtonSelectedGradient or mapButtonDefaultGradient
        end

        local icon = button:FindFirstChild("SelectionIcon")
        if icon and icon:IsA("ImageLabel") then
                icon.Visible = isSelected
                icon.ImageTransparency = isSelected and 0 or 0.35
        end

        local scale = button:FindFirstChild("SelectionScale")
        if scale and scale:IsA("UIScale") then
                TweenService:Create(scale, selectionTweenInfo, {Scale = isSelected and 1.05 or 1}):Play()
        end
end

local function updateDifficultyButtonVisual(button: TextButton, isSelected: boolean)
        applySelectionVisual(button, isSelected)
end

local function refreshDifficultyStatusLabel()
        if difficultyStatusLabel then
                if selectedDifficulty then
                        difficultyStatusLabel.Text = string.format("Locked to %d", selectedDifficulty)
                        difficultyStatusLabel.TextColor3 = Color3.fromRGB(255, 235, 160)
                else
                        difficultyStatusLabel.Text = "Random"
                        difficultyStatusLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
                end
        end
end

local function setSelectedDifficulty(level: number?)
        selectedDifficulty = level
        for value, button in difficultyButtons do
                updateDifficultyButtonVisual(button, value == selectedDifficulty)
        end
        refreshDifficultyStatusLabel()
end

local difficultyContainer = Instance.new("Frame")
difficultyContainer.Name = "DifficultyContainer"
difficultyContainer.Size = UDim2.new(1, 0, 0, 60)
difficultyContainer.Position = UDim2.new(0, 0, 0, 200)
difficultyContainer.BackgroundTransparency = 1
difficultyContainer.ZIndex = 6
difficultyContainer.Parent = eventSection

local difficultyHeader = Instance.new("TextLabel")
difficultyHeader.Name = "DifficultyHeader"
difficultyHeader.Size = UDim2.new(0.5, -10, 0, 20)
difficultyHeader.Position = UDim2.new(0, 0, 0, 0)
difficultyHeader.BackgroundTransparency = 1
difficultyHeader.Font = Enum.Font.GothamBold
difficultyHeader.Text = "🎚️ Difficulty Override"
difficultyHeader.TextColor3 = Color3.fromRGB(245, 245, 255)
difficultyHeader.TextSize = 16
difficultyHeader.TextXAlignment = Enum.TextXAlignment.Left
difficultyHeader.ZIndex = 6
difficultyHeader.Parent = difficultyContainer

difficultyStatusLabel = Instance.new("TextLabel")
difficultyStatusLabel.Name = "DifficultyStatus"
difficultyStatusLabel.Size = UDim2.new(0.5, -10, 0, 20)
difficultyStatusLabel.Position = UDim2.new(0.5, 10, 0, 0)
difficultyStatusLabel.BackgroundTransparency = 1
difficultyStatusLabel.Font = Enum.Font.GothamSemibold
difficultyStatusLabel.Text = ""
difficultyStatusLabel.TextSize = 14
difficultyStatusLabel.TextXAlignment = Enum.TextXAlignment.Right
difficultyStatusLabel.TextTransparency = 0
difficultyStatusLabel.ZIndex = 6
difficultyStatusLabel.Parent = difficultyContainer

local difficultyButtonFrame = Instance.new("Frame")
difficultyButtonFrame.Name = "DifficultyButtons"
difficultyButtonFrame.Size = UDim2.new(1, 0, 0, 36)
difficultyButtonFrame.Position = UDim2.new(0, 0, 0, 24)
difficultyButtonFrame.BackgroundTransparency = 1
difficultyButtonFrame.ZIndex = 6
difficultyButtonFrame.Parent = difficultyContainer

local difficultyLayout = Instance.new("UIGridLayout")
difficultyLayout.FillDirection = Enum.FillDirection.Horizontal
difficultyLayout.SortOrder = Enum.SortOrder.LayoutOrder
difficultyLayout.CellPadding = UDim2.fromOffset(8, 6)
difficultyLayout.CellSize = UDim2.new(0.333, -8, 1, 0)
difficultyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
difficultyLayout.VerticalAlignment = Enum.VerticalAlignment.Center
difficultyLayout.Parent = difficultyButtonFrame

local function createDifficultyButton(level: number, layoutOrder: number)
        local button = Instance.new("TextButton")
        button.Name = string.format("Difficulty%d", level)
        button.LayoutOrder = layoutOrder
        button.Size = UDim2.new(0, 0, 1, 0)
        button.BackgroundColor3 = mapButtonDefaultColor
        button.AutoButtonColor = false
        button.Font = Enum.Font.GothamBold
        button.Text = string.format("%d", level)
        button.TextColor3 = mapButtonTextColor
        button.TextSize = 16
        button.ZIndex = 6
        button.Parent = difficultyButtonFrame

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = button

        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 1.5
        stroke.Color = Color3.fromRGB(150, 160, 210)
        stroke.Transparency = 0.3
        stroke.Parent = button

        local gradient = Instance.new("UIGradient")
        gradient.Name = "SelectionGradient"
        gradient.Color = mapButtonDefaultGradient
        gradient.Rotation = 90
        gradient.Parent = button

        local scale = Instance.new("UIScale")
        scale.Name = "SelectionScale"
        scale.Parent = button

        difficultyButtons[level] = button
        updateDifficultyButtonVisual(button, false)

        button.Activated:Connect(function()
                if selectedDifficulty == level then
                        setSelectedDifficulty(nil)
                else
                        setSelectedDifficulty(level)
                end
        end)

        return button
end

for index = 1, 6 do
        createDifficultyButton(index, index)
end

local randomDifficultyButton = Instance.new("TextButton")
randomDifficultyButton.Name = "DifficultyRandom"
randomDifficultyButton.LayoutOrder = 99
randomDifficultyButton.Size = UDim2.new(0, 0, 1, 0)
randomDifficultyButton.BackgroundColor3 = Color3.fromRGB(74, 87, 120)
randomDifficultyButton.AutoButtonColor = false
randomDifficultyButton.Font = Enum.Font.GothamSemibold
randomDifficultyButton.Text = "🎲 Random"
randomDifficultyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
randomDifficultyButton.TextSize = 15
randomDifficultyButton.ZIndex = 6
randomDifficultyButton.Parent = difficultyButtonFrame

local randomCorner = Instance.new("UICorner")
randomCorner.CornerRadius = UDim.new(0, 8)
randomCorner.Parent = randomDifficultyButton

local randomStroke = Instance.new("UIStroke")
randomStroke.Thickness = 1.5
randomStroke.Color = Color3.fromRGB(120, 135, 200)
randomStroke.Transparency = 0.35
randomStroke.Parent = randomDifficultyButton

randomDifficultyButton.Activated:Connect(function()
        setSelectedDifficulty(nil)
end)

setSelectedDifficulty(nil)

local actionContainer = Instance.new("Frame")
actionContainer.Name = "ActionContainer"
actionContainer.AnchorPoint = Vector2.new(1, 1)
actionContainer.Position = UDim2.new(1, -20, 1, -20)
actionContainer.Size = UDim2.fromOffset(200, 40)
actionContainer.BackgroundTransparency = 1
actionContainer.ZIndex = 6
actionContainer.Parent = pvpFrame

local messageLabel = Instance.new("TextLabel")
messageLabel.Name = "MessageLabel"
messageLabel.AnchorPoint = Vector2.new(0, 1)
messageLabel.Position = UDim2.new(0, 20, 1, -70)
messageLabel.Size = UDim2.new(1, -40, 0, 25)
messageLabel.BackgroundTransparency = 1
messageLabel.Font = Enum.Font.GothamBold
messageLabel.Text = ""
messageLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
messageLabel.TextSize = 16
messageLabel.TextTransparency = 1
messageLabel.TextXAlignment = Enum.TextXAlignment.Center
messageLabel.TextStrokeTransparency = 0.5
messageLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
messageLabel.ZIndex = 6
messageLabel.Parent = pvpFrame

local actionLayout = Instance.new("UIListLayout")
actionLayout.FillDirection = Enum.FillDirection.Horizontal
actionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
actionLayout.Padding = UDim.new(0, 12)
actionLayout.Parent = actionContainer

local function createActionButton(name: string, text: string): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromOffset(90, 36)
	button.AutoButtonColor = false
	button.BackgroundColor3 = Color3.fromRGB(94, 108, 160)
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 18
	button.TextStrokeTransparency = 0.3
	button.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	button.ZIndex = 6
	button.Parent = actionContainer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Color = Color3.fromRGB(150, 160, 210)
	stroke.Transparency = 0.2
	stroke.Parent = button

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 140, 200)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 100, 150))
	})
	gradient.Rotation = 90
	gradient.Parent = button

	return button
end

local startButton = createActionButton("StartButton", "🚀 Start Match")
local cancelButton = createActionButton("CancelButton", "❌ Cancel")

local startButtonDefaultColor = startButton.BackgroundColor3
local startButtonDisabledColor = Color3.fromRGB(70, 80, 110)

local mapButtons: {[string]: TextButton} = {}
local eventButtons: {[string]: TextButton} = {}
local selectedMapId: string? = nil
local selectedEventId: string? = nil
local startButtonLocked = false
local startButtonLabel = startButton.Text
local messageFadeToken = 0
local messageFadeTween: Tween? = nil

local function updateStartButtonVisual()
	startButton.Text = startButtonLabel
	startButton.BackgroundColor3 = startButtonLocked and startButtonDisabledColor or startButtonDefaultColor
	startButton.Active = not startButtonLocked
	startButton.AutoButtonColor = not startButtonLocked
	startButton.TextTransparency = startButtonLocked and 0.2 or 0
end

local function setStartButtonState(isLocked: boolean, label: string?)
	startButtonLocked = isLocked
	if not isLocked then
		startButtonLabel = "Start"
	elseif label then
		startButtonLabel = label
	end
	updateStartButtonVisual()
end

local function clearMessage()
	if messageFadeTween then
		messageFadeTween:Cancel()
		messageFadeTween = nil
	end
	messageLabel.Text = ""
	messageLabel.TextTransparency = 1
end

local function showMessage(text: string, color: Color3?)
	messageFadeToken += 1
	local token = messageFadeToken

	if messageFadeTween then
		messageFadeTween:Cancel()
		messageFadeTween = nil
	end

	messageLabel.Text = text
	messageLabel.TextColor3 = color or Color3.fromRGB(255, 120, 120)
	messageLabel.TextTransparency = 0

	task.delay(3, function()
		if token ~= messageFadeToken then
			return
		end

		messageFadeTween = TweenService:Create(messageLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 1,
		})
		messageFadeTween:Play()
	end)
end

local function updateMapButtonVisual(button: TextButton, isSelected: boolean)
        applySelectionVisual(button, isSelected)
end

local function selectMap(mapId: string)
	selectedMapId = mapId
	for id, button in mapButtons do
		updateMapButtonVisual(button, id == selectedMapId)
	end
end

local function createSelectionButton(parent: Instance, order: number, id: string, displayName: string, buttonsTable: {[string]: TextButton}, onActivated: (string) -> ())
	local button = Instance.new("TextButton")
	button.Name = string.format("%sButton", id)
	button.LayoutOrder = order
	button.Size = UDim2.new(1, 0, 1, 0)
	button.BackgroundColor3 = mapButtonDefaultColor
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBold
	button.Text = displayName
	button.TextColor3 = mapButtonTextColor
	button.TextSize = 18
	button.ZIndex = 6
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.6
	stroke.Transparency = 0.2
	stroke.Color = Color3.fromRGB(120, 40, 40)
	stroke.Parent = button

	local gradient = Instance.new("UIGradient")
	gradient.Name = "SelectionGradient"
	gradient.Color = mapButtonDefaultGradient
	gradient.Rotation = 90
	gradient.Parent = button

	local scale = Instance.new("UIScale")
	scale.Name = "SelectionScale"
	scale.Parent = button

	local icon = Instance.new("ImageLabel")
	icon.Name = "SelectionIcon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(20, 20)
	icon.Position = UDim2.new(1, -10, 0, 10)
	icon.AnchorPoint = Vector2.new(1, 0)
	icon.Image = CHECK_ICON_ASSET_ID
	icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
	icon.ImageTransparency = 0.35
	icon.Visible = false
	icon.ZIndex = button.ZIndex + 1
	icon.Parent = button

	buttonsTable[id] = button
	updateMapButtonVisual(button, false)

	button.Activated:Connect(function()
		onActivated(id)
	end)

	return button
end

for order, definition in ipairs(mapDefinitions) do
	createSelectionButton(mapList, order, definition.id, definition.displayName, mapButtons, function(mapId)
		if selectedMapId ~= mapId then
			selectMap(mapId)
		end
	end)
end

local function updateEventButtonVisual(button: TextButton, isSelected: boolean)
	applySelectionVisual(button, isSelected)
end

local function selectEvent(eventId: string?)
	selectedEventId = eventId
	for id, button in eventButtons do
		updateEventButtonVisual(button, id == selectedEventId)
	end

	if eventDescriptionLabel then
		if eventId then
			local definition = eventDefinitionById[eventId]
			local description = definition and definition.description or nil
			if description and #description > 0 then
				eventDescriptionLabel.Text = description
			else
				eventDescriptionLabel.Text = string.format("%s ready to deploy.", definition and definition.displayName or "Event")
			end
		else
			eventDescriptionLabel.Text = DEFAULT_EVENT_DESCRIPTION
		end
	end
end

for order, definition in ipairs(specialEventOptions) do
	createSelectionButton(eventList, order, definition.id, definition.displayName, eventButtons, function(eventId)
		if selectedEventId == eventId then
			selectEvent(nil)
		else
			selectEvent(eventId)
		end
	end)
end

selectEvent(nil)

updateStartButtonVisual()

local opened = false
local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)

local openPosition = UDim2.new(0, 20, 0.5, -panelHeight / 2)
local closedPosition = UDim2.new(0, -panelWidth + buttonWidth, 0.5, -panelHeight / 2)

local function updateToggleVisual()
	local targetRotation = opened and 180 or 0
	TweenService:Create(toggleButton, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Rotation = targetRotation
	}):Play()
end

local function tweenPanel()
	local targetPosition = opened and openPosition or closedPosition
	TweenService:Create(panel, tweenInfo, {Position = targetPosition}):Play()
end

local function animateButtonPress()
	local pressTween = TweenService:Create(toggleButton, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(buttonWidth - 4, 56)
	})
	pressTween:Play()
	pressTween.Completed:Connect(function()
		TweenService:Create(toggleButton, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(buttonWidth, 60)
		}):Play()
	end)
end

local function showPanelUI()
	pvpFrame.Visible = false
	panel.Visible = true
	opened = true
	updateToggleVisual()
	tweenPanel()
	clearMessage()
end

local function closeAllUI()
	pvpFrame.Visible = false
	panel.Visible = true
	opened = false
	updateToggleVisual()
	tweenPanel()
	clearMessage()
end

local function showPVPUI()
	panel.Visible = false
	pvpFrame.Visible = true
	clearMessage()
	updateStartButtonVisual()
end

local toggleDebounce = false
local pvpDebounce = false

local function onPVPActivated()
	if pvpDebounce then
		return
	end

	pvpDebounce = true
	showPVPUI()
	task.wait(0.15)
	pvpDebounce = false
end

pvpButton.Activated:Connect(onPVPActivated)

startButton.Activated:Connect(function()
	if startButtonLocked then
		return
	end

	if not selectedMapId then
		showMessage("Select a map to begin a round.")
		return
	end

	if not startRoundRemote then
		showMessage("PVP controls are not ready yet.")
		return
	end

	setStartButtonState(true, "Starting...")
	local payload = {
		mapId = selectedMapId,
	}

	if selectedEventId and selectedEventId ~= "" then
		payload.eventId = selectedEventId
	end

	if selectedDifficulty then
		payload.difficulty = selectedDifficulty
	end

	startRoundRemote:FireServer(payload)
	closeAllUI()
end)

cancelButton.Activated:Connect(function()
	clearMessage()
	showPanelUI()
end)

if roundStateRemote then
	roundStateRemote.OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" then
			local state = payload.state
			if state == "Starting" then
				setStartButtonState(true, "Starting...")
			elseif state == "Active" then
				setStartButtonState(true, "In Progress")
			elseif state == "Idle" or state == "Ended" then
				setStartButtonState(false)
				clearMessage()
			elseif state == "Error" then
				setStartButtonState(false)
				if payload.message then
					showMessage(payload.message)
				end
			end
		elseif typeof(payload) == "string" then
			if payload == "Active" then
				setStartButtonState(true, "In Progress")
			elseif payload == "Idle" then
				setStartButtonState(false)
				clearMessage()
			end
		end
	end)
end

toggleButton.Activated:Connect(function()
	if toggleDebounce then
		return
	end

	toggleDebounce = true
	opened = not opened
	updateToggleVisual()
	tweenPanel()
	animateButtonPress()

	task.wait(0.25)
	toggleDebounce = false
end)

updateToggleVisual()
tweenPanel()

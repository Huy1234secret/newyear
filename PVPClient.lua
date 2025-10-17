--!strict
-- Place this LocalScript in StarterPlayerScripts so each player can see match updates.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

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

local DEFAULT_BACKGROUND_COLOR = Color3.fromRGB(28, 32, 45)
local DEFAULT_BACKGROUND_TRANSPARENCY = 0.15
local DEFAULT_TEXT_SIZE = if isTouchDevice then 22 else 26
local EMPHASIZED_TEXT_SIZE = if isTouchDevice then 28 else 32

local function setBackpackCoreGuiEnabled(enabled: boolean)
    local success, result = pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, enabled)
    end)

    if not success then
        warn("Failed to set backpack CoreGui state:", result)
    end
end

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

local GEAR_CURSOR_IMAGE_ASSET = "rbxassetid://9925913476"
local DEFAULT_CURSOR_IMAGE_ASSET = GEAR_CURSOR_IMAGE_ASSET
local currentCursorImageAsset = DEFAULT_CURSOR_IMAGE_ASSET
local DEFAULT_WALK_SPEED = 16

local INVENTORY_BASE_ZINDEX = 60
local SLOT_CONTENT_BASE_ZINDEX = INVENTORY_BASE_ZINDEX + 1
local SLOT_ICON_ZINDEX = SLOT_CONTENT_BASE_ZINDEX + 1
local SLOT_TEXT_ZINDEX = SLOT_CONTENT_BASE_ZINDEX + 2
local SLOT_BUTTON_ZINDEX = SLOT_CONTENT_BASE_ZINDEX + 4

local energyBarFill: Frame? = nil
local energyTextLabel: TextLabel? = nil
local sprintStatusLabel: TextLabel? = nil
local centerCursorImage: ImageLabel? = nil

local inventoryFrame: Frame? = nil
local inventoryToggleButton: ImageButton? = nil
local inventoryVisible = true
local inventoryAutoOpened = false
local setInventoryVisibility: (boolean) -> ()

inventoryVisible = not isTouchDevice

local noSprintPart: BasePart? = nil
local sprintActionButton: ImageButton? = nil
local sprintActionBound = false

local function updateNoSprintPartReference()
    local found = Workspace:FindFirstChild("NoSprintPart", true)
    if found and found:IsA("BasePart") then
        noSprintPart = found
    else
        noSprintPart = nil
    end
end

updateNoSprintPartReference()

Workspace.DescendantAdded:Connect(function(descendant)
    if descendant.Name == "NoSprintPart" and descendant:IsA("BasePart") then
        noSprintPart = descendant
    end
end)

Workspace.DescendantRemoving:Connect(function(descendant)
    if descendant == noSprintPart then
        noSprintPart = nil
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

local statusFrame = Instance.new("Frame")
statusFrame.Name = "StatusFrame"
statusFrame.Size = UDim2.fromOffset(isTouchDevice and 220 or 260, isTouchDevice and 52 or 56)
statusFrame.Position = UDim2.new(0.5, 0, 0, 32)
statusFrame.AnchorPoint = Vector2.new(0.5, 0)
statusFrame.BackgroundColor3 = DEFAULT_BACKGROUND_COLOR
statusFrame.BackgroundTransparency = DEFAULT_BACKGROUND_TRANSPARENCY
statusFrame.Visible = false
statusFrame.ZIndex = 10
statusFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = statusFrame

local frameStroke = Instance.new("UIStroke")
frameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
frameStroke.Thickness = 2
frameStroke.Color = Color3.fromRGB(120, 135, 200)
frameStroke.Transparency = 0.35
frameStroke.Parent = statusFrame

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 16)
padding.PaddingRight = UDim.new(0, 16)
padding.Parent = statusFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, 0, 1, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.AnchorPoint = Vector2.new(0.5, 0.5)
statusLabel.Position = UDim2.fromScale(0.5, 0.5)
statusLabel.Font = Enum.Font.GothamBold
statusLabel.Text = ""
statusLabel.TextSize = DEFAULT_TEXT_SIZE
statusLabel.TextColor3 = Color3.fromRGB(245, 245, 255)
statusLabel.TextXAlignment = Enum.TextXAlignment.Center
statusLabel.TextYAlignment = Enum.TextYAlignment.Center
statusLabel.ZIndex = 11
statusLabel.Parent = statusFrame

local labelStroke = Instance.new("UIStroke")
labelStroke.Color = Color3.fromRGB(20, 20, 35)
labelStroke.Thickness = 2
labelStroke.Transparency = 0.3
labelStroke.Parent = statusLabel

local viewportWidth = 1024
do
    local camera = Workspace.CurrentCamera
    if camera then
        viewportWidth = camera.ViewportSize.X
    end
end

local slotPadding = if isTouchDevice then 2 else 6
local calculatedAvailableWidth = if isTouchDevice
    then math.max(280, math.min(viewportWidth - 40, 540))
    else math.clamp(viewportWidth * 0.5, 520, 780)
local slotSize = math.clamp(
    math.floor((calculatedAvailableWidth - 24 - slotPadding * 9) / 10),
    if isTouchDevice then 24 else 40,
    if isTouchDevice then 40 else 56
)
local inventoryWidth = slotSize * 10 + slotPadding * 9 + 24
local inventoryHeight = slotSize + 20
local inventoryBottomMargin = if isTouchDevice then math.max(64, math.floor(slotSize * 1.4)) else 0
local minimumEnergyGap = 0
local energyContainerGap = minimumEnergyGap
local energyLabelHeight = if isTouchDevice then 16 else 18
local energyBarHeight = if isTouchDevice then 12 else 14
local energyTopPadding = if isTouchDevice then 2 else 3
local energyBottomPadding = if isTouchDevice then 4 else 5
local energySpacing = if isTouchDevice then 3 else 4
local sprintContainerHeight = energyTopPadding + energyLabelHeight + energySpacing + energyBarHeight + energyBottomPadding
local energyTextWidth = if isTouchDevice then 80 else 92

local sprintContainer = Instance.new("Frame")
sprintContainer.Name = "SprintEnergyContainer"
sprintContainer.Size = UDim2.fromOffset(inventoryWidth, sprintContainerHeight)
sprintContainer.Position = UDim2.new(0.5, 0, 1, -(inventoryBottomMargin + inventoryHeight + energyContainerGap))
sprintContainer.AnchorPoint = Vector2.new(0.5, 1)
sprintContainer.BackgroundTransparency = 1
sprintContainer.ZIndex = 5
sprintContainer.Parent = screenGui

local sprintPadding = Instance.new("UIPadding")
sprintPadding.PaddingTop = UDim.new(0, energyTopPadding)
sprintPadding.PaddingBottom = UDim.new(0, energyBottomPadding)
sprintPadding.PaddingLeft = UDim.new(0, 8)
sprintPadding.PaddingRight = UDim.new(0, 8)
sprintPadding.Parent = sprintContainer

sprintStatusLabel = Instance.new("TextLabel")
sprintStatusLabel.Name = "SprintStatus"
sprintStatusLabel.Size = UDim2.new(1, -8, 0, energyLabelHeight)
sprintStatusLabel.Position = UDim2.new(0.5, 0, 0, 0)
sprintStatusLabel.AnchorPoint = Vector2.new(0.5, 0)
sprintStatusLabel.BackgroundTransparency = 1
sprintStatusLabel.Font = Enum.Font.GothamSemibold
sprintStatusLabel.TextColor3 = Color3.fromRGB(210, 235, 255)
sprintStatusLabel.TextSize = isTouchDevice and 14 or 16
sprintStatusLabel.TextScaled = false
sprintStatusLabel.Text = "Sprint OFF"
sprintStatusLabel.ZIndex = 7
sprintStatusLabel.Parent = sprintContainer

local sprintBackground = Instance.new("Frame")
sprintBackground.Name = "EnergyBackground"
sprintBackground.Size = UDim2.new(1, -16, 0, energyBarHeight)
sprintBackground.Position = UDim2.new(0.5, 0, 0, energyLabelHeight + energySpacing)
sprintBackground.AnchorPoint = Vector2.new(0.5, 0)
sprintBackground.BackgroundColor3 = Color3.fromRGB(34, 52, 82)
sprintBackground.BackgroundTransparency = 0.15
sprintBackground.Parent = sprintContainer

local sprintBackgroundCorner = Instance.new("UICorner")
sprintBackgroundCorner.CornerRadius = UDim.new(0, 10)
sprintBackgroundCorner.Parent = sprintBackground

local sprintBackgroundStroke = Instance.new("UIStroke")
sprintBackgroundStroke.Thickness = 1.5
sprintBackgroundStroke.Transparency = 0.35
sprintBackgroundStroke.Color = Color3.fromRGB(80, 130, 200)
sprintBackgroundStroke.Parent = sprintBackground

local energyFillContainer = Instance.new("Frame")
energyFillContainer.Name = "EnergyFill"
energyFillContainer.AnchorPoint = Vector2.new(0, 0.5)
energyFillContainer.Position = UDim2.new(0, 6, 0.5, 0)
energyFillContainer.Size = UDim2.new(1, -(energyTextWidth + 20), 1, 0)
energyFillContainer.BackgroundTransparency = 1
energyFillContainer.ClipsDescendants = true
energyFillContainer.Parent = sprintBackground

local energyFillBackground = Instance.new("Frame")
energyFillBackground.Name = "EnergyFillBackground"
energyFillBackground.Size = UDim2.new(1, 0, 1, 0)
energyFillBackground.BackgroundColor3 = Color3.fromRGB(52, 80, 130)
energyFillBackground.BackgroundTransparency = 0.3
energyFillBackground.Parent = energyFillContainer

local energyFillBackgroundCorner = Instance.new("UICorner")
energyFillBackgroundCorner.CornerRadius = UDim.new(0, 7)
energyFillBackgroundCorner.Parent = energyFillBackground

energyBarFill = Instance.new("Frame")
energyBarFill.Name = "EnergyFillValue"
energyBarFill.AnchorPoint = Vector2.new(0, 0.5)
energyBarFill.Position = UDim2.new(0, 0, 0.5, 0)
energyBarFill.Size = UDim2.new(1, 0, 1, 0)
energyBarFill.BackgroundColor3 = Color3.fromRGB(80, 190, 255)
energyBarFill.Parent = energyFillBackground

local energyFillCorner = Instance.new("UICorner")
energyFillCorner.CornerRadius = UDim.new(0, 7)
energyFillCorner.Parent = energyBarFill

local energyFillGradient = Instance.new("UIGradient")
energyFillGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 190, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 240, 200)),
})
energyFillGradient.Parent = energyBarFill

energyTextLabel = Instance.new("TextLabel")
energyTextLabel.Name = "EnergyText"
energyTextLabel.AnchorPoint = Vector2.new(1, 0.5)
energyTextLabel.Position = UDim2.new(1, -8, 0.5, 0)
energyTextLabel.Size = UDim2.new(0, energyTextWidth, 0, energyBarHeight)
energyTextLabel.BackgroundTransparency = 1
energyTextLabel.Font = Enum.Font.GothamSemibold
energyTextLabel.TextColor3 = Color3.fromRGB(210, 235, 255)
energyTextLabel.TextScaled = false
energyTextLabel.TextSize = isTouchDevice and 14 or 15
energyTextLabel.TextXAlignment = Enum.TextXAlignment.Right
energyTextLabel.TextYAlignment = Enum.TextYAlignment.Center
energyTextLabel.Text = "Energy 100%"
energyTextLabel.Parent = sprintBackground

centerCursorImage = Instance.new("ImageLabel")
centerCursorImage.Name = "ShiftLockCursor"
centerCursorImage.BackgroundTransparency = 1
centerCursorImage.AnchorPoint = Vector2.new(0.5, 0.5)
centerCursorImage.Position = UDim2.fromScale(0.5, 0.5)
centerCursorImage.Size = UDim2.fromOffset(isTouchDevice and 40 or 48, isTouchDevice and 40 or 48)
centerCursorImage.Image = GEAR_CURSOR_IMAGE_ASSET
centerCursorImage.ZIndex = 50
centerCursorImage.Visible = false
centerCursorImage.Parent = screenGui

inventoryFrame = Instance.new("Frame")
inventoryFrame.Name = "InventoryBar"
inventoryFrame.AnchorPoint = Vector2.new(0.5, 1)
inventoryFrame.Size = UDim2.fromOffset(inventoryWidth, inventoryHeight)
inventoryFrame.Position = UDim2.new(0.5, 0, 1, -inventoryBottomMargin)
inventoryFrame.BackgroundTransparency = 1
inventoryFrame.ZIndex = INVENTORY_BASE_ZINDEX
inventoryFrame.Parent = screenGui

local sprintContainerBasePosition = sprintContainer.Position
local sprintContainerBaseRotation = sprintContainer.Rotation
local sprintBackgroundDefaultColor = sprintBackground.BackgroundColor3
local sprintBackgroundDefaultTransparency = sprintBackground.BackgroundTransparency
local sprintBackgroundStrokeDefaultColor = sprintBackgroundStroke.Color
local sprintBackgroundStrokeDefaultTransparency = sprintBackgroundStroke.Transparency
local energyBarFillDefaultColor = energyBarFill.BackgroundColor3
local energyTextDefaultColor = energyTextLabel.TextColor3
local energyGradientDefault = energyFillGradient.Color

local inventoryBasePosition = inventoryFrame.Position
local inventoryBaseRotation = inventoryFrame.Rotation

local function updateInventoryToggleVisual()
    local button = inventoryToggleButton
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

setInventoryVisibility = function(visible: boolean)
    inventoryVisible = visible

    if inventoryFrame then
        inventoryFrame.Visible = visible
    end

    updateInventoryToggleVisual()
end

if isTouchDevice then
    inventoryToggleButton = Instance.new("ImageButton")
    inventoryToggleButton.Name = "InventoryToggleButton"
    inventoryToggleButton.AnchorPoint = Vector2.new(0.5, 1)
    inventoryToggleButton.Size = UDim2.fromOffset(math.max(56, math.floor(slotSize * 1.1)), math.max(56, math.floor(slotSize * 1.1)))
    inventoryToggleButton.Position = UDim2.new(0.5, 0, 1, -8)
    inventoryToggleButton.BackgroundTransparency = 1
    inventoryToggleButton.AutoButtonColor = true
    inventoryToggleButton.Image = "rbxasset://textures/ui/Backpack/BackpackButton.png"
    inventoryToggleButton.ImageColor3 = Color3.fromRGB(255, 255, 255)
    inventoryToggleButton.ZIndex = 50
    inventoryToggleButton.Parent = screenGui

    inventoryToggleButton.Activated:Connect(function()
        setInventoryVisibility(not inventoryVisible)
        inventoryAutoOpened = true
    end)
end

setInventoryVisibility(inventoryVisible)

local slotContainer = Instance.new("Frame")
slotContainer.Name = "SlotContainer"
slotContainer.Size = UDim2.new(1, 0, 1, 0)
slotContainer.BackgroundTransparency = 1
slotContainer.Parent = inventoryFrame

local slotPaddingContainer = Instance.new("UIPadding")
slotPaddingContainer.PaddingLeft = UDim.new(0, 12)
slotPaddingContainer.PaddingRight = UDim.new(0, 12)
slotPaddingContainer.PaddingTop = UDim.new(0, 4)
slotPaddingContainer.PaddingBottom = UDim.new(0, 0)
slotPaddingContainer.Parent = slotContainer

local slotLayout = Instance.new("UIListLayout")
slotLayout.FillDirection = Enum.FillDirection.Horizontal
slotLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
slotLayout.VerticalAlignment = Enum.VerticalAlignment.Center
slotLayout.Padding = UDim.new(0, slotPadding)
slotLayout.SortOrder = Enum.SortOrder.LayoutOrder
slotLayout.Parent = slotContainer

for slotIndex = 1, 10 do
    local slotFrame = Instance.new("Frame")
    slotFrame.Name = string.format("Slot_%d", slotIndex)
    slotFrame.Size = UDim2.fromOffset(slotSize, slotSize)
    slotFrame.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
    slotFrame.BackgroundTransparency = 0.2
    slotFrame.ZIndex = SLOT_CONTENT_BASE_ZINDEX
    slotFrame.LayoutOrder = slotIndex
    slotFrame.Parent = slotContainer

    local slotCorner = Instance.new("UICorner")
    slotCorner.CornerRadius = UDim.new(0, 8)
    slotCorner.Parent = slotFrame

    local slotStroke = Instance.new("UIStroke")
    slotStroke.Color = Color3.fromRGB(80, 100, 150)
    slotStroke.Thickness = 1.5
    slotStroke.Transparency = 0.3
    slotStroke.Parent = slotFrame

    local numberLabel = Instance.new("TextLabel")
    numberLabel.Name = "KeyLabel"
    numberLabel.AnchorPoint = Vector2.new(0, 0)
    numberLabel.Size = UDim2.new(0, 24, 0, 18)
    numberLabel.Position = UDim2.new(0, 0, 0, 0)
    numberLabel.BackgroundTransparency = 1
    numberLabel.Font = Enum.Font.GothamSemibold
    numberLabel.TextColor3 = Color3.fromRGB(140, 150, 180)
    numberLabel.TextSize = 12
    numberLabel.TextXAlignment = Enum.TextXAlignment.Left
    numberLabel.TextYAlignment = Enum.TextYAlignment.Top
    numberLabel.Text = slotIndex == 10 and "0" or tostring(slotIndex)
    numberLabel.ZIndex = SLOT_TEXT_ZINDEX
    numberLabel.Parent = slotFrame

    local nameLabelHeight = math.max(12, math.floor(slotSize * 0.35))
    local iconPadding = math.max(8, math.floor(slotSize * 0.3))
    local iconImage = Instance.new("ImageLabel")
    iconImage.Name = "Icon"
    iconImage.BackgroundTransparency = 1
    iconImage.Size = UDim2.new(1, -12, 0, math.max(0, slotSize - (nameLabelHeight + iconPadding)))
    iconImage.Position = UDim2.new(0.5, 0, 0, math.floor(iconPadding * 0.5))
    iconImage.AnchorPoint = Vector2.new(0.5, 0)
    iconImage.Image = ""
    iconImage.ScaleType = Enum.ScaleType.Fit
    iconImage.ZIndex = SLOT_ICON_ZINDEX
    iconImage.Parent = slotFrame

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.BackgroundTransparency = 1
    nameLabel.Position = UDim2.new(0.5, 0, 1, -4)
    nameLabel.AnchorPoint = Vector2.new(0.5, 1)
    nameLabel.Size = UDim2.new(1, -8, 0, nameLabelHeight)
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.Text = ""
    nameLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
    nameLabel.TextSize = math.max(10, math.floor(nameLabelHeight * 0.65))
    nameLabel.TextScaled = false
    nameLabel.TextWrapped = true
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.ZIndex = SLOT_TEXT_ZINDEX
    nameLabel.Parent = slotFrame

    local slotButton = Instance.new("ImageButton")
    slotButton.Name = "SelectButton"
    slotButton.BackgroundTransparency = 1
    slotButton.Size = UDim2.new(1, 0, 1, 0)
    slotButton.AutoButtonColor = false
    slotButton.ImageTransparency = 1
    slotButton.Active = true
    slotButton.Selectable = false
    slotButton.ZIndex = SLOT_BUTTON_ZINDEX
    slotButton.Parent = slotFrame

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

    slotButton.Activated:Connect(triggerSelection)
    slotButton.InputBegan:Connect(function(input)
        local inputType = input.UserInputType
        if inputType == Enum.UserInputType.MouseButton1
            or inputType == Enum.UserInputType.Touch
            or inputType == Enum.UserInputType.Gamepad1
        then
            triggerSelection()
        end
    end)

    inventorySlots[slotIndex] = {
        frame = slotFrame,
        stroke = slotStroke,
        icon = iconImage,
        label = nameLabel,
        numberLabel = numberLabel,
        button = slotButton,
    }
end
local defaultColor = statusLabel.TextColor3
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

local baseFramePosition = statusFrame.Position
local baseLabelPosition = statusLabel.Position
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
local SPRINT_SPEED = 28
local SPRINT_TWEEN_TIME = 1
local SPRINT_FOV_OFFSET = 8

local sprintState: SprintState = {
    energy = MAX_SPRINT_ENERGY,
    isSprinting = false,
    sprintIntent = false,
    keyboardIntent = false,
    touchIntent = false,
    zoneBlocked = false,
    rechargeBlockedUntil = 0,
    originalWalkSpeed = DEFAULT_WALK_SPEED,
    speedTween = nil,
    cameraTween = nil,
    originalCameraFov = nil,
}

local currentHumanoid: Humanoid? = nil
local humanoidSpeedChangedConn: RBXScriptConnection? = nil

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
    elseif deathMatchHighlightActive and localPlayer.Neutral then
        desiredContext = "DeathMatch"
    end

    if desiredContext then
        enableHighlights(desiredContext)
    else
        disableHighlights()
    end
end

local function getSprintActionButton(): ImageButton?
    local button = sprintActionButton
    if button and button.Parent then
        return button
    end

    button = ContextActionService:GetButton("SprintAction")
    if button and button:IsA("ImageButton") then
        sprintActionButton = button
        return button
    end

    sprintActionButton = nil
    return nil
end

local function updateSprintButtonState()
    if not sprintActionBound then
        return
    end

    local hasEnergy = sprintState.energy > 0
    local canSprint = hasEnergy and not sprintState.zoneBlocked
    local buttonActive = sprintState.touchIntent and canSprint

    if not canSprint and not buttonActive then
        local title = if sprintState.zoneBlocked then "No Sprint" else "Rest"
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
    if sprintState.zoneBlocked then
        desiredIntent = false
    end

    sprintState.sprintIntent = desiredIntent
    updateSprintButtonState()
end

local function updateEnergyUI()
    if not energyBarFill or not energyTextLabel then
        return
    end

    local normalized = math.clamp(sprintState.energy / MAX_SPRINT_ENERGY, 0, 1)
    if normalized <= 0 then
        energyBarFill.Visible = false
    else
        energyBarFill.Visible = true
        energyBarFill.Size = UDim2.new(normalized, 0, 1, 0)
    end

    local percent = math.clamp(math.floor(normalized * 100 + 0.5), 0, 100)
    energyTextLabel.Text = string.format("Energy %d%%", percent)

    if percent <= 15 then
        energyTextLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
    elseif sprintState.isSprinting then
        energyTextLabel.TextColor3 = Color3.fromRGB(180, 255, 220)
    else
        energyTextLabel.TextColor3 = Color3.fromRGB(210, 235, 255)
    end

    if sprintStatusLabel then
        if sprintState.isSprinting then
            sprintStatusLabel.Text = "Sprint ON"
            sprintStatusLabel.TextColor3 = Color3.fromRGB(180, 255, 220)
        else
            sprintStatusLabel.Text = "Sprint OFF"
            if sprintState.energy <= 0 or sprintState.zoneBlocked then
                sprintStatusLabel.TextColor3 = Color3.fromRGB(255, 140, 140)
            else
                sprintStatusLabel.TextColor3 = Color3.fromRGB(210, 235, 255)
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

    if sprintState.energy <= 0 or sprintState.zoneBlocked then
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

    if sprintState.zoneBlocked then
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

    if math.abs(baselineSpeed - SPRINT_SPEED) < 0.001 then
        baselineSpeed = DEFAULT_WALK_SPEED
    elseif baselineSpeed <= 0 then
        baselineSpeed = DEFAULT_WALK_SPEED
    end

    sprintState.originalWalkSpeed = baselineSpeed

    tweenHumanoidSpeed(SPRINT_SPEED, false)

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

    if centerCursorImage then
        centerCursorImage.Image = if iconAsset ~= "" then iconAsset else ""
    end
end

local function updateCenterCursorVisibility()
    if not centerCursorImage then
        return
    end

    local shouldShow = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
        and currentCursorImageAsset ~= ""
    centerCursorImage.Visible = shouldShow
    if shouldShow then
        centerCursorImage.Image = currentCursorImageAsset
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
end)

localPlayer:GetPropertyChangedSignal("Neutral"):Connect(function()
    updateHighlightActivation()
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
    if humanoid.WalkSpeed <= 0 then
        humanoid.WalkSpeed = DEFAULT_WALK_SPEED
    end

    local currentSpeed = humanoid.WalkSpeed
    if math.abs(currentSpeed - SPRINT_SPEED) < 0.001 then
        currentSpeed = DEFAULT_WALK_SPEED
    end
    sprintState.originalWalkSpeed = currentSpeed

    humanoidSpeedChangedConn = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if sprintState.isSprinting then
            return
        end

        if sprintState.speedTween then
            return
        end

        local newSpeed = humanoid.WalkSpeed
        if newSpeed <= 0 then
            newSpeed = DEFAULT_WALK_SPEED
        elseif math.abs(newSpeed - SPRINT_SPEED) < 0.001 then
            newSpeed = DEFAULT_WALK_SPEED
        end

        sprintState.originalWalkSpeed = newSpeed
    end)

    humanoid.Died:Connect(function()
        sprintState.keyboardIntent = false
        sprintState.touchIntent = false
        recomputeSprintIntent()
        stopSprinting(true)
    end)
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
end

localPlayer.CharacterAdded:Connect(onCharacterAdded)

localPlayer.CharacterRemoving:Connect(function()
    sprintState.keyboardIntent = false
    sprintState.touchIntent = false
    recomputeSprintIntent()
    stopSprinting(true)
    if humanoidSpeedChangedConn then
        humanoidSpeedChangedConn:Disconnect()
        humanoidSpeedChangedConn = nil
    end
    currentHumanoid = nil
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
    elseif keyCode == Enum.KeyCode.ButtonL3 then
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

ContextActionService:BindAction("SprintAction", sprintAction, true, Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl, Enum.KeyCode.ButtonL3)
sprintActionBound = true
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

    local zoneBlocked = false
    local zonePart = noSprintPart
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
        else
            sprintState.rechargeBlockedUntil = math.max(sprintState.rechargeBlockedUntil, now + SPRINT_RECHARGE_DELAY)
        end

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
    elseif sprintState.energy < MAX_SPRINT_ENERGY and now >= sprintState.rechargeBlockedUntil then
        sprintState.energy = math.min(MAX_SPRINT_ENERGY, sprintState.energy + dt * SPRINT_RECHARGE_RATE)
    end

    updateEnergyUI()

    if mouse and not applyingMouseIcon and mouse.Icon ~= currentCursorImageAsset then
        applyDesktopCursorIcon()
    end
end)

local function resetFrameVisual()
    statusFrame.BackgroundColor3 = DEFAULT_BACKGROUND_COLOR
    statusFrame.BackgroundTransparency = DEFAULT_BACKGROUND_TRANSPARENCY
    frameStroke.Color = Color3.fromRGB(120, 135, 200)
    frameStroke.Transparency = 0.35
    statusFrame.Position = baseFramePosition
    statusLabel.TextColor3 = defaultColor
    statusLabel.TextSize = DEFAULT_TEXT_SIZE
    statusLabel.Position = baseLabelPosition
    statusLabel.Rotation = 0
    labelStroke.Transparency = 0.3
end

local function stopFlash()
    if flashConnection then
        flashConnection:Disconnect()
        flashConnection = nil
    end

    statusLabel.TextColor3 = matchColor
    labelStroke.Color = Color3.fromRGB(20, 20, 35)
    labelStroke.Transparency = 0.3
end

local function startFlash()
    stopFlash()

    labelStroke.Color = Color3.fromRGB(255, 110, 110)
    labelStroke.Transparency = 0

    flashConnection = RunService.RenderStepped:Connect(function()
        local timeScale = math.clamp(currentRemaining / 30, 0, 1)
        local frequency = 3 + (1 - timeScale) * 6
        local pulse = math.abs(math.sin(os.clock() * frequency))
        local green = 60 + math.floor(140 * (1 - pulse))
        statusLabel.TextColor3 = Color3.fromRGB(255, green, green)
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

    statusFrame.Position = baseFramePosition
    statusLabel.Position = baseLabelPosition
    statusLabel.Rotation = 0
    statusLabel.TextColor3 = defaultColor
    statusLabel.TextSize = DEFAULT_TEXT_SIZE

    inventoryFrame.Position = inventoryBasePosition
    inventoryFrame.Rotation = inventoryBaseRotation
    sprintContainer.Position = sprintContainerBasePosition
    sprintContainer.Rotation = sprintContainerBaseRotation
    sprintBackground.BackgroundColor3 = sprintBackgroundDefaultColor
    sprintBackground.BackgroundTransparency = sprintBackgroundDefaultTransparency
    sprintBackgroundStroke.Color = sprintBackgroundStrokeDefaultColor
    sprintBackgroundStroke.Transparency = sprintBackgroundStrokeDefaultTransparency
    energyBarFill.BackgroundColor3 = energyBarFillDefaultColor
    energyTextLabel.TextColor3 = energyTextDefaultColor
    energyFillGradient.Color = energyGradientDefault

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

    statusFrame.BackgroundColor3 = deathMatchBackground
    frameStroke.Color = deathMatchStroke
    frameStroke.Transparency = 0
    statusFrame.BackgroundTransparency = 1
    statusLabel.TextSize = EMPHASIZED_TEXT_SIZE
    labelStroke.Transparency = 0

    collectNeutralButtonShakeTargets()

    shakeConnection = RunService.RenderStepped:Connect(function()
        local now = os.clock()
        local frameMagnitude = 1 + math.abs(math.sin(now * 5)) * 1.4
        local offsetX = math.noise(now * 8, 0, 0) * frameMagnitude * 4
        local offsetY = math.noise(now * 9, 1, 0) * frameMagnitude * 3
        statusFrame.Position = baseFramePosition + UDim2.fromOffset(offsetX, offsetY)

        local textMagnitude = 0.5 + math.abs(math.sin(now * 12)) * 1.5
        local textOffsetX = math.noise(now * 20, 2, 0) * textMagnitude * 4
        local textOffsetY = math.noise(now * 18, 3, 0) * textMagnitude * 3
        local buttonOffset = UDim2.fromOffset(textOffsetX, textOffsetY)
        statusLabel.Position = baseLabelPosition + buttonOffset
        statusLabel.Rotation = math.noise(now * 14, 4, 0) * 8

        local pulse = (math.sin(now * 6) + 1) / 2
        local colorOffset = math.floor(40 * pulse)
        statusLabel.TextColor3 = Color3.fromRGB(255, 90 + colorOffset, 90 + colorOffset)

        local inventoryMagnitude = 0.6 + math.abs(math.sin(now * 6)) * 1.3
        local inventoryOffsetX = math.noise(now * 11, 5, 0) * inventoryMagnitude * 3
        local inventoryOffsetY = math.noise(now * 10, 6, 0) * inventoryMagnitude * 2
        inventoryFrame.Position = inventoryBasePosition + UDim2.fromOffset(inventoryOffsetX, inventoryOffsetY)
        inventoryFrame.Rotation = math.noise(now * 9, 7, 0) * 2.4

        local sprintOffsetX = math.noise(now * 7, 8, 0) * 2.6
        local sprintOffsetY = math.noise(now * 8, 9, 0) * 2.1
        sprintContainer.Position = sprintContainerBasePosition + UDim2.fromOffset(sprintOffsetX, sprintOffsetY)
        sprintContainer.Rotation = math.noise(now * 13, 10, 0) * 1.8

        local flashPulse = (math.sin(now * 12) + 1) * 0.5
        local flashNoise = math.clamp(math.noise(now * 15, 11, 0) * 0.5 + 0.5, 0, 1)
        local flashAmount = math.clamp(flashPulse * 0.6 + flashNoise * 0.4, 0, 1)
        local baseRed = 150 + math.floor(105 * flashAmount)
        local dimComponent = 25 + math.floor(90 * (1 - flashAmount))
        sprintBackground.BackgroundColor3 = Color3.fromRGB(baseRed, dimComponent, dimComponent)
        sprintBackground.BackgroundTransparency = 0.05 + (1 - flashAmount) * 0.2

        local strokeGreen = 60 + math.floor(120 * (1 - flashAmount))
        sprintBackgroundStroke.Color = Color3.fromRGB(255, strokeGreen, strokeGreen)
        sprintBackgroundStroke.Transparency = 0.05 + flashAmount * 0.25

        local energyPulse = math.abs(math.sin(now * 18))
        local energyGreen = 40 + math.floor(150 * (1 - energyPulse))
        energyBarFill.BackgroundColor3 = Color3.fromRGB(255, energyGreen, energyGreen)
        energyFillGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, math.max(0, energyGreen - 60), math.max(0, energyGreen - 60))),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, energyGreen, energyGreen)),
        })
        energyTextLabel.TextColor3 = Color3.fromRGB(255, 180 - math.floor(80 * flashAmount), 180 - math.floor(80 * flashAmount))

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
    statusFrame.Visible = false
    statusLabel.Text = ""
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

statusRemote.OnClientEvent:Connect(function(payload)
    if typeof(payload) ~= "table" then
        return
    end

    local action = payload.action
    if action == "PrepCountdown" then
        currentRemaining = tonumber(payload.remaining) or 0
        stopShake()
        stopFlash()
        resetFrameVisual()
        statusFrame.BackgroundTransparency = DEFAULT_BACKGROUND_TRANSPARENCY
        statusFrame.Visible = true
        statusLabel.TextColor3 = countdownColor
        statusLabel.TextSize = EMPHASIZED_TEXT_SIZE
        statusLabel.Text = formatCountdown(currentRemaining)
        labelStroke.Transparency = 0.1
    elseif action == "MatchTimer" then
        currentRemaining = math.max(0, math.floor(tonumber(payload.remaining) or 0))
        statusFrame.Visible = true
        resetFrameVisual()
        statusLabel.TextColor3 = matchColor
        statusLabel.Text = formatTimer(currentRemaining)

        if currentRemaining <= 30 then
            startFlash()
        else
            stopFlash()
        end
    elseif action == "DeathMatchTransition" then
        stopFlash()
        stopShake()
        statusFrame.Visible = true
        statusFrame.BackgroundColor3 = deathMatchBackground
        frameStroke.Color = deathMatchStroke
        frameStroke.Transparency = 0
        statusLabel.TextColor3 = matchColor
        statusLabel.TextSize = EMPHASIZED_TEXT_SIZE
        statusLabel.Text = "Death Match"
        statusFrame.BackgroundTransparency = 1
        labelStroke.Transparency = 0

        local duration = tonumber(payload.duration) or 3
        deathMatchHighlightActive = true
        updateHighlightActivation()
        startDeathMatchTransition(duration)
    elseif action == "DeathMatch" then
        local isActive = payload.active == nil or payload.active
        if isActive then
            deathMatchHighlightActive = true
            stopDeathMatchTransition()
            statusFrame.Visible = true
            statusLabel.Text = "Death Match"
            startDeathMatchEffect()
        else
            deathMatchHighlightActive = false
            stopShake()
            stopFlash()
            stopDeathMatchTransition()
            resetFrameVisual()
            statusFrame.Visible = false
        end
    elseif action == "RoundEnded" then
        deathMatchHighlightActive = false
        updateHighlightActivation()
        stopDeathMatchTransition()
        stopFlash()
        stopShake()
        resetFrameVisual()
        statusFrame.Visible = true
        statusLabel.TextColor3 = countdownColor
        statusLabel.TextSize = DEFAULT_TEXT_SIZE
        statusLabel.Text = "Intermission"
        labelStroke.Transparency = 0.3
    end
end)

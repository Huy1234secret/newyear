--!strict
-- Place this LocalScript in StarterPlayerScripts so it only runs for each player.
-- It will create an owner-only control panel button that slides in and out with animation.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local allowedUserIds = {
    [347735445] = true,
}

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

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "OwnerPanel"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = player:WaitForChild("PlayerGui")

local panelWidth = 220
local panelHeight = 180
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

local description = Instance.new("TextLabel")
description.Name = "Description"
description.Size = UDim2.new(1, -40, 0, 60)
description.Position = UDim2.new(0, 20, 0, 60)
description.BackgroundTransparency = 1
description.Font = Enum.Font.Gotham
description.Text = "Thêm nội dung dành riêng cho chủ game ở đây."
description.TextWrapped = true
description.TextColor3 = Color3.fromRGB(200, 205, 220)
description.TextSize = 16
description.TextXAlignment = Enum.TextXAlignment.Left
description.TextYAlignment = Enum.TextYAlignment.Top
description.Parent = panel

description.ZIndex = 2
panel.ZIndex = 2

local buttonContainer = Instance.new("Frame")
buttonContainer.Name = "ButtonContainer"
buttonContainer.Size = UDim2.new(1, -40, 0, 48)
buttonContainer.Position = UDim2.new(0, 20, 0, 130)
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
pvpFrame.Size = UDim2.fromOffset(360, 220)
pvpFrame.Position = UDim2.fromScale(0.5, 0.5)
pvpFrame.AnchorPoint = Vector2.new(0.5, 0.5)
pvpFrame.BackgroundColor3 = Color3.fromRGB(32, 35, 50)
pvpFrame.Visible = false
pvpFrame.ZIndex = 5
pvpFrame.Parent = screenGui

local pvpCorner = Instance.new("UICorner")
pvpCorner.CornerRadius = UDim.new(0, 12)
pvpCorner.Parent = pvpFrame

local pvpStroke = Instance.new("UIStroke")
pvpStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
pvpStroke.Thickness = 2
pvpStroke.Color = Color3.fromRGB(120, 135, 200)
pvpStroke.Transparency = 0.4
pvpStroke.Parent = pvpFrame

local pvpTitle = Instance.new("TextLabel")
pvpTitle.Name = "PVPTitle"
pvpTitle.Size = UDim2.new(1, -40, 0, 40)
pvpTitle.Position = UDim2.new(0, 20, 0, 20)
pvpTitle.BackgroundTransparency = 1
pvpTitle.Font = Enum.Font.GothamBold
pvpTitle.Text = "PVP"
pvpTitle.TextColor3 = Color3.fromRGB(245, 245, 255)
pvpTitle.TextSize = 26
pvpTitle.TextXAlignment = Enum.TextXAlignment.Left
pvpTitle.ZIndex = 6
pvpTitle.Parent = pvpFrame

local actionContainer = Instance.new("Frame")
actionContainer.Name = "ActionContainer"
actionContainer.AnchorPoint = Vector2.new(1, 1)
actionContainer.Position = UDim2.new(1, -20, 1, -20)
actionContainer.Size = UDim2.fromOffset(200, 40)
actionContainer.BackgroundTransparency = 1
actionContainer.ZIndex = 6
actionContainer.Parent = pvpFrame

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
    button.ZIndex = 6
    button.Parent = actionContainer

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1.5
    stroke.Color = Color3.fromRGB(150, 160, 210)
    stroke.Transparency = 0.3
    stroke.Parent = button

    return button
end

local startButton = createActionButton("StartButton", "Start")
local cancelButton = createActionButton("CancelButton", "Cancel")

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
end

local function showPVPUI()
    panel.Visible = false
    pvpFrame.Visible = true
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
    showPanelUI()
end)

cancelButton.Activated:Connect(function()
    showPanelUI()
end)

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

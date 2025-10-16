--!strict
-- Place this LocalScript in StarterPlayerScripts so it only runs for each player.
-- It will create an owner-only control panel button that slides in and out with animation.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local function isGameOwner(): boolean
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

local toggleButton = Instance.new("ImageButton")
toggleButton.Name = "ToggleButton"
toggleButton.Size = UDim2.fromOffset(buttonWidth, 60)
toggleButton.AnchorPoint = Vector2.new(0.5, 0.5)
toggleButton.Position = UDim2.new(0, panelWidth - (buttonWidth / 2), 0.5, 0)
toggleButton.BackgroundColor3 = Color3.fromRGB(74, 87, 120)
toggleButton.AutoButtonColor = false
toggleButton.Image = ""
toggleButton.Parent = panel

toggleButton.ZIndex = 3

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(1, 0)
buttonCorner.Parent = toggleButton

local buttonLabel = Instance.new("TextLabel")
buttonLabel.Size = UDim2.fromScale(1, 1)
buttonLabel.BackgroundTransparency = 1
buttonLabel.Font = Enum.Font.GothamBold
buttonLabel.Text = ">"
buttonLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
buttonLabel.TextSize = 24
buttonLabel.Parent = toggleButton

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

local opened = false
local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)

local openPosition = UDim2.new(0, 20, 0.5, -panelHeight / 2)
local closedPosition = UDim2.new(0, -panelWidth + buttonWidth, 0.5, -panelHeight / 2)

local function updateButtonSymbol()
    buttonLabel.Text = opened and "<" or ">"
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

local debounce = false

toggleButton.Activated:Connect(function()
    if debounce then
        return
    end

    debounce = true
    opened = not opened
    updateButtonSymbol()
    tweenPanel()
    animateButtonPress()

    task.wait(0.25)
    debounce = false
end)

updateButtonSymbol()
tweenPanel()

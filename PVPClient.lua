--!strict
-- Place this LocalScript in StarterPlayerScripts so each player can see match updates.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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

local playerGui = localPlayer:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PVPStatusGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local statusFrame = Instance.new("Frame")
statusFrame.Name = "StatusFrame"
statusFrame.Size = UDim2.fromOffset(260, 56)
statusFrame.Position = UDim2.new(0.5, 0, 0, 32)
statusFrame.AnchorPoint = Vector2.new(0.5, 0)
statusFrame.BackgroundColor3 = Color3.fromRGB(28, 32, 45)
statusFrame.BackgroundTransparency = 0.15
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
statusLabel.Font = Enum.Font.GothamBold
statusLabel.Text = ""
statusLabel.TextSize = 26
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

local defaultColor = statusLabel.TextColor3
local countdownColor = Color3.fromRGB(245, 245, 255)
local matchColor = Color3.fromRGB(210, 235, 255)
local deathMatchBackground = Color3.fromRGB(60, 10, 10)
local deathMatchStroke = Color3.fromRGB(255, 90, 90)

local baseFramePosition = statusFrame.Position
local currentRemaining = 0
local flashConnection: RBXScriptConnection? = nil
local shakeConnection: RBXScriptConnection? = nil

local function resetFrameVisual()
    statusFrame.BackgroundColor3 = Color3.fromRGB(28, 32, 45)
    frameStroke.Color = Color3.fromRGB(120, 135, 200)
    frameStroke.Transparency = 0.35
    statusFrame.Position = baseFramePosition
    statusLabel.TextColor3 = defaultColor
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

local function stopShake()
    if shakeConnection then
        shakeConnection:Disconnect()
        shakeConnection = nil
    end

    statusFrame.Position = baseFramePosition
    statusFrame.BackgroundColor3 = Color3.fromRGB(28, 32, 45)
    frameStroke.Color = Color3.fromRGB(120, 135, 200)
    frameStroke.Transparency = 0.35
    statusLabel.TextColor3 = defaultColor
end

local function startDeathMatchEffect()
    stopFlash()
    stopShake()

    statusFrame.BackgroundColor3 = deathMatchBackground
    frameStroke.Color = deathMatchStroke
    frameStroke.Transparency = 0

    shakeConnection = RunService.RenderStepped:Connect(function()
        local now = os.clock()
        local amplitude = 3 + math.abs(math.sin(now * 3)) * 5
        local offsetX = math.sin(now * 12) * amplitude
        local offsetY = math.cos(now * 9) * amplitude * 0.6
        statusFrame.Position = baseFramePosition + UDim2.fromOffset(offsetX, offsetY)

        local pulse = (math.sin(now * 6) + 1) / 2
        local colorOffset = math.floor(40 * pulse)
        statusLabel.TextColor3 = Color3.fromRGB(255, 90 + colorOffset, 90 + colorOffset)
    end)
end

local function hideStatus()
    stopFlash()
    stopShake()
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
        statusFrame.Visible = true
        statusLabel.TextColor3 = countdownColor
        statusLabel.Text = formatCountdown(currentRemaining)
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
    elseif action == "DeathMatch" then
        local isActive = payload.active == nil or payload.active
        if isActive then
            statusFrame.Visible = true
            statusLabel.Text = "Death Match"
            startDeathMatchEffect()
        else
            stopShake()
            stopFlash()
            resetFrameVisual()
            statusFrame.Visible = false
        end
    elseif action == "RoundEnded" then
        hideStatus()
    end
end)

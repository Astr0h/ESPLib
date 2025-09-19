-- =========================
-- SeosHub ESP Library
-- =========================

-- Reuse global instance if reloaded
if _G.SeosHubESP and _G.SeosHubESP.Destroy then
    _G.SeosHubESP:Destroy()
end
_G.SeosHubESP = _G.SeosHubESP or {}
local ESP = _G.SeosHubESP

-- Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- =========================
-- Defaults / Config
-- =========================
ESP.Enabled = ESP.Enabled or false
ESP.Objects = ESP.Objects or {}
ESP.BoxColor = ESP.BoxColor or Color3.fromRGB(0, 255, 0)
ESP.BoxThickness = ESP.BoxThickness or 1.5

ESP.NameEnabled = ESP.NameEnabled ~= false
ESP.NameColor = ESP.NameColor or Color3.fromRGB(255, 255, 255)

ESP.HealthEnabled = ESP.HealthEnabled ~= false

ESP.DistanceEnabled = ESP.DistanceEnabled ~= false
ESP.DistanceColor = ESP.DistanceColor or Color3.fromRGB(200, 200, 200)

ESP.SkeletonEnabled = ESP.SkeletonEnabled or false
ESP.SkeletonColor = ESP.SkeletonColor or Color3.fromRGB(255, 255, 255)
ESP.SkeletonThickness = ESP.SkeletonThickness or 1.5
ESP.Skeletons = ESP.Skeletons or {}

ESP.TracersEnabled = ESP.TracersEnabled or false
ESP.TracerColor = ESP.TracerColor or Color3.fromRGB(255, 255, 255)
ESP.TracerThickness = ESP.TracerThickness or 1.5

ESP.TeamColorEnabled = ESP.TeamColorEnabled or false
ESP.TeamCheck = ESP.TeamCheck or false
ESP.FriendCheck = ESP.FriendCheck or false
ESP.VisibilityCheck = ESP.VisibilityCheck or false

-- =========================
-- Helpers
-- =========================
local function newBox()
    local box = Drawing.new("Square")
    box.Thickness = ESP.BoxThickness
    box.Color = ESP.BoxColor
    box.Filled = false
    box.Transparency = 1
    box.Visible = false
    return box
end

local function newText(size, color)
    local tag = Drawing.new("Text")
    tag.Text = ""
    tag.Size = size
    tag.Center = true
    tag.Outline = false
    tag.Visible = false
    tag.Color = color
    return tag
end

local function newLine(thickness, color)
    local line = Drawing.new("Line")
    line.Thickness = thickness or 1.5
    line.Color = color or Color3.fromRGB(255, 255, 255)
    line.Transparency = 1
    line.Visible = false
    return line
end

-- Health color lerp
local function getHealthColor(current, max)
    if max <= 0 then return Color3.fromRGB(255, 0, 0) end
    local ratio = math.clamp(current / max, 0, 1)
    if ratio > 0.5 then
        local t = (ratio - 0.5) * 2
        return Color3.fromRGB(255 * (1 - t), 255, 0)
    else
        local t = ratio * 2
        return Color3.fromRGB(255, 255 * t, 0)
    end
end

-- Raycast visibility check
local function isVisible(origin, target)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    local dir = target - origin
    local result = workspace:Raycast(origin, dir, params)
    return result == nil
end

-- =========================
-- Box + Tags
-- =========================
local function createESP(char)
    if ESP.Objects[char] then return end
    ESP.Objects[char] = {
        Box = newBox(),
        NameTag = newText(18, ESP.NameColor),
        HealthTag = newText(16, Color3.fromRGB(255, 255, 255)),
        DistanceTag = newText(16, ESP.DistanceColor),
        Tracer = newLine(ESP.TracerThickness, ESP.TracerColor),
        Character = char,
    }
end

local function removeESP(char)
    local data = ESP.Objects[char]
    if not data then return end
    if data.Box then data.Box:Remove() end
    if data.NameTag then data.NameTag:Remove() end
    if data.HealthTag then data.HealthTag:Remove() end
    if data.DistanceTag then data.DistanceTag:Remove() end
    if data.Tracer then data.Tracer:Remove() end
    ESP.Objects[char] = nil
end

-- =========================
-- Skeleton
-- =========================
local function createSkeleton(char)
    if ESP.Skeletons[char] then return end
    local bones = {
        "HeadToUpperTorso","UpperTorsoToLowerTorso",
        "UpperTorsoToLeftUpperArm","LeftUpperArmToLeftLowerArm","LeftLowerArmToLeftHand",
        "UpperTorsoToRightUpperArm","RightUpperArmToRightLowerArm","RightLowerArmToRightHand",
        "LowerTorsoToLeftUpperLeg","LeftUpperLegToLeftLowerLeg","LeftLowerLegToLeftFoot",
        "LowerTorsoToRightUpperLeg","RightUpperLegToRightLowerLeg","RightLowerLegToRightFoot",
    }
    local lines = {}
    for _, bone in ipairs(bones) do
        lines[bone] = newLine(ESP.SkeletonThickness, ESP.SkeletonColor)
    end
    ESP.Skeletons[char] = lines
end

local function removeSkeleton(char)
    local lines = ESP.Skeletons[char]
    if lines then
        for _, line in pairs(lines) do line:Remove() end
        ESP.Skeletons[char] = nil
    end
end

-- =========================
-- Update Loops
-- =========================
local function updateESP()
    local cam = Camera
    if not cam then return end
    local toDelete = {}

    for char, data in pairs(ESP.Objects) do
        if not (char and char.Parent == workspace) then
            table.insert(toDelete, char)
            continue
        end

        local box, nameTag, healthTag, distTag, tracer =
            data.Box, data.NameTag, data.HealthTag, data.DistanceTag, data.Tracer
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        local hum = char:FindFirstChildOfClass("Humanoid")
        local plr = Players:GetPlayerFromCharacter(char)

        -- === Checks ===
        if ESP.TeamCheck and plr and plr.Team == LocalPlayer.Team then goto continue end
        if ESP.FriendCheck and plr and LocalPlayer:IsFriendsWith(plr.UserId) then goto continue end
        if ESP.VisibilityCheck and hrp then
            if not isVisible(cam.CFrame.Position, hrp.Position) then goto continue end
        end

        -- Final color (with team override)
        local finalColor = ESP.BoxColor
        if ESP.TeamColorEnabled and plr and plr.Team then
            finalColor = plr.TeamColor.Color
        end

        -- === Box ===
        if ESP.Enabled and hrp and head then
            local rootPos, vis = cam:WorldToViewportPoint(hrp.Position)
            local headPos = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
            local scale = (headPos - rootPos).Magnitude
            if vis and scale > 0 then
                box.Size = Vector2.new(scale * 2, scale * 3)
                box.Position = Vector2.new(rootPos.X - scale, rootPos.Y - scale * 1.5)
                box.Color = finalColor
                box.Thickness = ESP.BoxThickness
                box.Visible = true
            else
                box.Visible = false
            end
        else
            if box then box.Visible = false end
        end

        -- === Name Tag ===
        if ESP.NameEnabled and head then
            local pos, vis = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 2.5, 0))
            if vis then
                nameTag.Text = plr and plr.Name or "Unknown"
                nameTag.Position = Vector2.new(pos.X, pos.Y)
                nameTag.Color = ESP.NameColor
                nameTag.Visible = true
            else
                nameTag.Visible = false
            end
        else
            if nameTag then nameTag.Visible = false end
        end

        -- === Health Tag ===
        if ESP.HealthEnabled and head and hum then
            local pos, vis = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 1.9, 0))
            if vis then
                healthTag.Text = string.format("%d / %d", math.floor(hum.Health), hum.MaxHealth)
                healthTag.Position = Vector2.new(pos.X, pos.Y)
                healthTag.Color = getHealthColor(hum.Health, hum.MaxHealth)
                healthTag.Visible = true
            else
                healthTag.Visible = false
            end
        else
            if healthTag then healthTag.Visible = false end
        end

        -- === Distance Tag ===
        if ESP.DistanceEnabled and hrp and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local pos, vis = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
            if vis then
                local dist = (hrp.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                distTag.Text = string.format("[%dm]", math.floor(dist))
                distTag.Position = Vector2.new(pos.X, pos.Y)
                distTag.Color = ESP.DistanceColor
                distTag.Visible = true
            else
                distTag.Visible = false
            end
        else
            if distTag then distTag.Visible = false end
        end

        -- === Tracers ===
        if ESP.TracersEnabled and hrp then
            local pos, vis = cam:WorldToViewportPoint(hrp.Position)
            if vis then
                tracer.From = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y)
                tracer.To = Vector2.new(pos.X, pos.Y)
                tracer.Color = ESP.TracerColor
                tracer.Thickness = ESP.TracerThickness
                tracer.Visible = true
            else
                tracer.Visible = false
            end
        else
            if tracer then tracer.Visible = false end
        end

        ::continue::
    end

    for _, c in ipairs(toDelete) do removeESP(c) end
end

-- =========================
-- Skeleton Update (unchanged except using ESP.SkeletonColor/Thickness live)
-- =========================
local function to2D(part)
    local pos, vis = Camera:WorldToViewportPoint(part.Position)
    return Vector2.new(pos.X, pos.Y), vis
end

local function drawBone(line, partA, partB)
    if partA and partB then
        local a, visA = to2D(partA)
        local b, visB = to2D(partB)
        if visA and visB then
            line.From = a
            line.To = b
            line.Color = ESP.SkeletonColor
            line.Thickness = ESP.SkeletonThickness
            line.Visible = true
            return
        end
    end
    line.Visible = false
end

local function updateSkeletons()
    if not ESP.SkeletonEnabled then return end
    for char, lines in pairs(ESP.Skeletons) do
        if not (char and char.Parent == workspace) then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then continue end

        if hum.RigType == Enum.HumanoidRigType.R15 then
            drawBone(lines.HeadToUpperTorso, char:FindFirstChild("Head"), char:FindFirstChild("UpperTorso"))
            drawBone(lines.UpperTorsoToLowerTorso, char:FindFirstChild("UpperTorso"), char:FindFirstChild("LowerTorso"))
            drawBone(lines.UpperTorsoToLeftUpperArm, char:FindFirstChild("UpperTorso"), char:FindFirstChild("LeftUpperArm"))
            drawBone(lines.LeftUpperArmToLeftLowerArm, char:FindFirstChild("LeftUpperArm"), char:FindFirstChild("LeftLowerArm"))
            drawBone(lines.LeftLowerArmToLeftHand, char:FindFirstChild("LeftLowerArm"), char:FindFirstChild("LeftHand"))
            drawBone(lines.UpperTorsoToRightUpperArm, char:FindFirstChild("UpperTorso"), char:FindFirstChild("RightUpperArm"))
            drawBone(lines.RightUpperArmToRightLowerArm, char:FindFirstChild("RightUpperArm"), char:FindFirstChild("RightLowerArm"))
            drawBone(lines.RightLowerArmToRightHand, char:FindFirstChild("RightLowerArm"), char:FindFirstChild("RightHand"))
            drawBone(lines.LowerTorsoToLeftUpperLeg, char:FindFirstChild("LowerTorso"), char:FindFirstChild("LeftUpperLeg"))
            drawBone(lines.LeftUpperLegToLeftLowerLeg, char:FindFirstChild("LeftUpperLeg"), char:FindFirstChild("LeftLowerLeg"))
            drawBone(lines.LeftLowerLegToLeftFoot, char:FindFirstChild("LeftLowerLeg"), char:FindFirstChild("LeftFoot"))
            drawBone(lines.LowerTorsoToRightUpperLeg, char:FindFirstChild("LowerTorso"), char:FindFirstChild("RightUpperLeg"))
            drawBone(lines.RightUpperLegToRightLowerLeg, char:FindFirstChild("RightUpperLeg"), char:FindFirstChild("RightLowerLeg"))
            drawBone(lines.RightLowerLegToRightFoot, char:FindFirstChild("RightLowerLeg"), char:FindFirstChild("RightFoot"))
        else
            drawBone(lines.HeadToUpperTorso, char:FindFirstChild("Head"), char:FindFirstChild("Torso"))
            drawBone(lines.UpperTorsoToLeftUpperArm, char:FindFirstChild("Torso"), char:FindFirstChild("Left Arm"))
            drawBone(lines.UpperTorsoToRightUpperArm, char:FindFirstChild("Torso"), char:FindFirstChild("Right Arm"))
            drawBone(lines.LowerTorsoToLeftUpperLeg, char:FindFirstChild("Torso"), char:FindFirstChild("Left Leg"))
            drawBone(lines.LowerTorsoToRightUpperLeg, char:FindFirstChild("Torso"), char:FindFirstChild("Right Leg"))
        end
    end
end

-- =========================
-- Connections
-- =========================
if not ESP.__BoxConn or not ESP.__BoxConn.Connected then
    ESP.__BoxConn = RunService.RenderStepped:Connect(updateESP)
end
if not ESP.__SkeletonConn or not ESP.__SkeletonConn.Connected then
    ESP.__SkeletonConn = RunService.RenderStepped:Connect(updateSkeletons)
end

-- =========================
-- Public API
-- =========================
function ESP:Enable() self.Enabled = true end
function ESP:Disable() self.Enabled = false end
function ESP:EnableSkeleton() self.SkeletonEnabled = true end
function ESP:DisableSkeleton() self.SkeletonEnabled = false end

function ESP:Destroy()
    for char in pairs(self.Objects) do removeESP(char) end
    for char in pairs(self.Skeletons) do removeSkeleton(char) end
    if self.__BoxConn and self.__BoxConn.Connected then self.__BoxConn:Disconnect() end
    if self.__SkeletonConn and self.__SkeletonConn.Connected then self.__SkeletonConn:Disconnect() end
    self.Objects, self.Skeletons = {}, {}
end

-- =========================
-- Player Hooks
-- =========================
local function hookPlayer(plr)
    if plr == LocalPlayer then return end
    plr.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        createESP(char)
        createSkeleton(char)
    end)
    plr.CharacterRemoving:Connect(function(char)
        removeESP(char)
        removeSkeleton(char)
    end)
end

for _, plr in ipairs(Players:GetPlayers()) do hookPlayer(plr) end
Players.PlayerAdded:Connect(hookPlayer)
Players.PlayerRemoving:Connect(function(plr)
    for char in pairs(ESP.Objects) do if Players:GetPlayerFromCharacter(char) == plr then removeESP(char) end end
    for char in pairs(ESP.Skeletons) do if Players:GetPlayerFromCharacter(char) == plr then removeSkeleton(char) end end
end)

return ESP

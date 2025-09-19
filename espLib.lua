--Variables lol
_G.SeosHubESP = _G.SeosHubESP or {}
local ESP = _G.SeosHubESP
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

ESP.Enabled = false
ESP.Objects = ESP.Objects or {}

-- Config
ESP.BoxColor = ESP.BoxColor or Color3.fromRGB(0, 255, 0)
ESP.BoxThickness = ESP.BoxThickness or 1.5

ESP.NameEnabled = true
ESP.NameColor = ESP.NameColor or Color3.fromRGB(255, 255, 255)

ESP.HealthEnabled = true -- no static color, auto lerp

ESP.DistanceEnabled = true
ESP.DistanceColor = ESP.DistanceColor or Color3.fromRGB(200, 200, 200)

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
    tag.Outline = true
    tag.Visible = false
    tag.Color = color
    return tag
end

-- Health lerp color (Green -> Yellow -> Red)
local function getHealthColor(current, max)
    if max <= 0 then return Color3.fromRGB(255, 0, 0) end
    local ratio = math.clamp(current / max, 0, 1)
    if ratio > 0.5 then
        -- Green to Yellow
        local t = (ratio - 0.5) * 2
        return Color3.fromRGB(255 * (1 - t), 255, 0)
    else
        -- Yellow to Red
        local t = ratio * 2
        return Color3.fromRGB(255, 255 * t, 0)
    end
end

-- =========================
-- Create / Remove
-- =========================

local function createESP(char)
    if ESP.Objects[char] then return end

    ESP.Objects[char] = {
        Box = newBox(),
        NameTag = newText(16, ESP.NameColor),
        HealthTag = newText(14, Color3.fromRGB(255, 255, 255)), -- dynamic color
        DistanceTag = newText(14, ESP.DistanceColor),
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
    ESP.Objects[char] = nil
end

-- =========================
-- Update Loop
-- =========================

local function update()
    local cam = workspace.CurrentCamera
    if not cam then return end

    local toDelete = {}

    for char, data in pairs(ESP.Objects) do
        local alive = char and char.Parent == workspace
        if not alive then
            table.insert(toDelete, char)
            continue
        end

        local box, nameTag, healthTag, distTag = data.Box, data.NameTag, data.HealthTag, data.DistanceTag

        -- Apply latest styles
        box.Color = ESP.BoxColor
        box.Thickness = ESP.BoxThickness
        nameTag.Color = ESP.NameColor
        distTag.Color = ESP.DistanceColor

        if ESP.Enabled then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local head = char:FindFirstChild("Head")
            local hum = char:FindFirstChildOfClass("Humanoid")

            if hrp and head then
                -- === Box ===
                local rootPos, vis = cam:WorldToViewportPoint(hrp.Position)
                local headPos = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                local scale = (headPos - rootPos).Magnitude

                if vis and scale > 0 then
                    box.Size = Vector2.new(scale * 2, scale * 3)
                    box.Position = Vector2.new(rootPos.X - scale, rootPos.Y - scale * 1.5)
                    box.Visible = true
                else
                    box.Visible = false
                end

                -- === Name Tag ===
                if ESP.NameEnabled then
                    local pos, vis2 = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 2.5, 0))
                    if vis2 then
                        local plr = Players:GetPlayerFromCharacter(char)
                        nameTag.Text = plr and plr.Name or "Unknown"
                        nameTag.Position = Vector2.new(pos.X, pos.Y)
                        nameTag.Visible = true
                    else
                        nameTag.Visible = false
                    end
                else
                    nameTag.Visible = false
                end

                -- === Health Tag ===
                if ESP.HealthEnabled and hum then
                    local pos, vis3 = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 1.9, 0))
                    if vis3 then
                        healthTag.Text = string.format("%d / %d", math.floor(hum.Health), hum.MaxHealth)
                        healthTag.Position = Vector2.new(pos.X, pos.Y)
                        healthTag.Color = getHealthColor(hum.Health, hum.MaxHealth)
                        healthTag.Visible = true
                    else
                        healthTag.Visible = false
                    end
                else
                    healthTag.Visible = false
                end

                -- === Distance Tag ===
                if ESP.DistanceEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local pos, vis4 = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                    if vis4 then
                        local dist = (hrp.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                        distTag.Text = string.format("[%dm]", math.floor(dist))
                        distTag.Position = Vector2.new(pos.X, pos.Y)
                        distTag.Visible = true
                    else
                        distTag.Visible = false
                    end
                else
                    distTag.Visible = false
                end
            else
                box.Visible, nameTag.Visible, healthTag.Visible, distTag.Visible = false, false, false, false
            end
        else
            box.Visible, nameTag.Visible, healthTag.Visible, distTag.Visible = false, false, false, false
        end
    end

    for _, deadChar in ipairs(toDelete) do
        removeESP(deadChar)
    end
end

-- Hook update once
if not ESP.__BoxConn or not ESP.__BoxConn.Connected then
    ESP.__BoxConn = RunService.RenderStepped:Connect(update)
end

-- =========================
-- Public API
-- =========================

function ESP:Enable()
    self.Enabled = true
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            createESP(plr.Character)
        end
    end
end

function ESP:Disable()
    self.Enabled = false
    for _, data in pairs(self.Objects) do
        data.Box.Visible, data.NameTag.Visible, data.HealthTag.Visible, data.DistanceTag.Visible = false, false, false, false
    end
end

-- =========================
-- Player Hooks
-- =========================

local function hookPlayer(plr)
    if plr == LocalPlayer then return end

    plr.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        if ESP.Enabled then
            createESP(char)
        end
    end)

    plr.CharacterRemoving:Connect(function(char)
        removeESP(char)
    end)
end

for _, plr in ipairs(Players:GetPlayers()) do
    hookPlayer(plr)
end

Players.PlayerAdded:Connect(hookPlayer)

Players.PlayerRemoving:Connect(function(plr)
    for char in pairs(ESP.Objects) do
        local owner = Players:GetPlayerFromCharacter(char)
        if owner == plr then
            removeESP(char)
        end
    end
end)
-- =========================
-- Skeleton ESP (fixed)
-- =========================

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

ESP.SkeletonEnabled = false
ESP.SkeletonColor = ESP.SkeletonColor or Color3.fromRGB(255, 255, 255)
ESP.SkeletonThickness = ESP.SkeletonThickness or 1.5
ESP.Skeletons = ESP.Skeletons or {}

-- Utility: create a new line
local function newLine()
    local line = Drawing.new("Line")
    line.Thickness = ESP.SkeletonThickness
    line.Color = ESP.SkeletonColor
    line.Transparency = 1
    line.Visible = false
    return line
end

-- Create skeleton container for a character
local function createSkeleton(char)
    if ESP.Skeletons[char] then return end -- don’t double-create

    local lines = {}
    local bones = {
        "HeadToUpperTorso",
        "UpperTorsoToLowerTorso",
        "UpperTorsoToLeftUpperArm",
        "LeftUpperArmToLeftLowerArm",
        "LeftLowerArmToLeftHand",
        "UpperTorsoToRightUpperArm",
        "RightUpperArmToRightLowerArm",
        "RightLowerArmToRightHand",
        "LowerTorsoToLeftUpperLeg",
        "LeftUpperLegToLeftLowerLeg",
        "LeftLowerLegToLeftFoot",
        "LowerTorsoToRightUpperLeg",
        "RightUpperLegToRightLowerLeg",
        "RightLowerLegToRightFoot",
    }

    for _, bone in ipairs(bones) do
        lines[bone] = newLine()
    end

    ESP.Skeletons[char] = lines
end

-- Remove skeleton when character is gone
local function removeSkeleton(char)
    local lines = ESP.Skeletons[char]
    if lines then
        for _, line in pairs(lines) do
            line:Remove()
        end
        ESP.Skeletons[char] = nil
    end
end

-- Convert 3D -> 2D screen position
local function to2D(part)
    local cam = workspace.CurrentCamera
    local pos, vis = cam:WorldToViewportPoint(part.Position)
    return Vector2.new(pos.X, pos.Y), vis
end

-- Draw connection if both parts exist & visible
local function drawBone(line, partA, partB)
    if partA and partB then
        local a, visA = to2D(partA)
        local b, visB = to2D(partB)
        if visA and visB then
            line.From = a
            line.To = b
            line.Color = ESP.SkeletonColor -- live color update
            line.Thickness = ESP.SkeletonThickness -- live thickness update
            line.Visible = true
            return
        end
    end
    line.Visible = false
end

-- Main update loop for skeletons
local function updateSkeletons()
    if not ESP.SkeletonEnabled then return end

    local toDelete = {}
    for char, lines in pairs(ESP.Skeletons) do
        -- purge destroyed characters
        if not (char and char.Parent == workspace) then
            table.insert(toDelete, char)
            continue
        end

        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then
            table.insert(toDelete, char)
            continue
        end

        if hum.RigType == Enum.HumanoidRigType.R15 then
            drawBone(lines.HeadToUpperTorso, char:FindFirstChild("Head"), char:FindFirstChild("UpperTorso"))
            drawBone(lines.UpperTorsoToLowerTorso, char:FindFirstChild("UpperTorso"), char:FindFirstChild("LowerTorso"))

            -- Left Arm
            drawBone(lines.UpperTorsoToLeftUpperArm, char:FindFirstChild("UpperTorso"), char:FindFirstChild("LeftUpperArm"))
            drawBone(lines.LeftUpperArmToLeftLowerArm, char:FindFirstChild("LeftUpperArm"), char:FindFirstChild("LeftLowerArm"))
            drawBone(lines.LeftLowerArmToLeftHand, char:FindFirstChild("LeftLowerArm"), char:FindFirstChild("LeftHand"))

            -- Right Arm
            drawBone(lines.UpperTorsoToRightUpperArm, char:FindFirstChild("UpperTorso"), char:FindFirstChild("RightUpperArm"))
            drawBone(lines.RightUpperArmToRightLowerArm, char:FindFirstChild("RightUpperArm"), char:FindFirstChild("RightLowerArm"))
            drawBone(lines.RightLowerArmToRightHand, char:FindFirstChild("RightLowerArm"), char:FindFirstChild("RightHand"))

            -- Left Leg
            drawBone(lines.LowerTorsoToLeftUpperLeg, char:FindFirstChild("LowerTorso"), char:FindFirstChild("LeftUpperLeg"))
            drawBone(lines.LeftUpperLegToLeftLowerLeg, char:FindFirstChild("LeftUpperLeg"), char:FindFirstChild("LeftLowerLeg"))
            drawBone(lines.LeftLowerLegToLeftFoot, char:FindFirstChild("LeftLowerLeg"), char:FindFirstChild("LeftFoot"))

            -- Right Leg
            drawBone(lines.LowerTorsoToRightUpperLeg, char:FindFirstChild("LowerTorso"), char:FindFirstChild("RightUpperLeg"))
            drawBone(lines.RightUpperLegToRightLowerLeg, char:FindFirstChild("RightUpperLeg"), char:FindFirstChild("RightLowerLeg"))
            drawBone(lines.RightLowerLegToRightFoot, char:FindFirstChild("RightLowerLeg"), char:FindFirstChild("RightFoot"))

        else -- R6
            drawBone(lines.HeadToUpperTorso, char:FindFirstChild("Head"), char:FindFirstChild("Torso"))
            drawBone(lines.UpperTorsoToLeftUpperArm, char:FindFirstChild("Torso"), char:FindFirstChild("Left Arm"))
            drawBone(lines.UpperTorsoToRightUpperArm, char:FindFirstChild("Torso"), char:FindFirstChild("Right Arm"))
            drawBone(lines.LowerTorsoToLeftUpperLeg, char:FindFirstChild("Torso"), char:FindFirstChild("Left Leg"))
            drawBone(lines.LowerTorsoToRightUpperLeg, char:FindFirstChild("Torso"), char:FindFirstChild("Right Leg"))
        end
    end

    -- cleanup invalid skeletons
    for _, char in ipairs(toDelete) do
        removeSkeleton(char)
    end
end

-- Hook into render loop
if not ESP.__SkeletonConn or not ESP.__SkeletonConn.Connected then
    ESP.__SkeletonConn = RunService.RenderStepped:Connect(updateSkeletons)
end

-- Public API
function ESP:EnableSkeleton()
    self.SkeletonEnabled = true
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            createSkeleton(plr.Character)
        end
    end
end

function ESP:DisableSkeleton()
    self.SkeletonEnabled = false
    for _, lines in pairs(self.Skeletons) do
        for _, line in pairs(lines) do
            line.Visible = false
        end
    end
end

-- Handle player lifecycle
local function hookPlayer(plr)
    if plr == LocalPlayer then return end

    plr.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        if ESP.SkeletonEnabled then
            createSkeleton(char)
        end
    end)

    plr.CharacterRemoving:Connect(function(char)
        removeSkeleton(char)
    end)
end

for _, plr in ipairs(Players:GetPlayers()) do
    hookPlayer(plr)
end

Players.PlayerAdded:Connect(hookPlayer)

Players.PlayerRemoving:Connect(function(plr)
    if plr.Character then
        removeSkeleton(plr.Character)
    end
end)

return ESP

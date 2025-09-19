--Variables lol
local ESP = {}
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer



-- =========================
-- BOX ESP
-- =========================

ESP.Enabled = false
ESP.Objects = {}
ESP.BoxColor = Color3.fromRGB(0, 255, 0)


local function createBox(target)
    local box = Drawing.new("Square")
    box.Thickness = 1.5
    box.Color = ESP.BoxColor
    box.Filled = false
    box.Transparency = 1
    box.Visible = false

    ESP.Objects[target] = {
        Box = box,
        Character = target
    }
end

-- Remove ESP from a character
local function removeBox(target)
    if ESP.Objects[target] then
        ESP.Objects[target].Box:Remove()
        ESP.Objects[target] = nil
    end
end

-- Update ESP per frame
local function update()
    for target, data in pairs(ESP.Objects) do
        local char = data.Character
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")

        if hrp and head and ESP.Enabled then
            local rootPos, vis = workspace.CurrentCamera:WorldToViewportPoint(hrp.Position)
            local headPos = workspace.CurrentCamera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
            local scale = (headPos - rootPos).Magnitude

            if vis then
                data.Box.Size = Vector2.new(scale * 2, scale * 3)
                data.Box.Position = Vector2.new(rootPos.X - scale, rootPos.Y - scale * 1.5)
                data.Box.Visible = true
            else
                data.Box.Visible = false
            end
        else
            data.Box.Visible = false
        end
    end
end
-- Main loop
RunService.RenderStepped:Connect(update)

-- Public API
function ESP:Enable()
    self.Enabled = true
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            createBox(plr.Character)
        end
    end
end

function ESP:Disable()
    self.Enabled = false
    for _, obj in pairs(self.Objects) do
        obj.Box.Visible = false
    end
end

-- Auto-track players joining/leaving
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char)
        if ESP.Enabled then
            task.wait(1) -- wait for character to load
            createBox(char)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(plr)
    if plr.Character then
        removeBox(plr.Character)
    end
end)

-- =========================
-- Skeleton ESP
-- =========================

ESP.SkeletonEnabled = false
ESP.SkeletonColor = Color3.fromRGB(255, 255, 255)
ESP.Skeletons = {}

-- Utility: create a new line
local function newLine()
    local line = Drawing.new("Line")
    line.Thickness = 1.5
    line.Color = ESP.SkeletonColor
    line.Transparency = 1
    line.Visible = false
    return line
end

-- Create skeleton container for a character
local function createSkeleton(char)
    local lines = {}

    -- We'll store each bone connection by name
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
    if ESP.Skeletons[char] then
        for _, line in pairs(ESP.Skeletons[char]) do
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
            line.Color = ESP.SkeletonColor
            line.Visible = true
            return
        end
    end
    line.Visible = false
end

-- Main update loop for skeletons
local function updateSkeletons()
    if not ESP.SkeletonEnabled then return end

    for char, lines in pairs(ESP.Skeletons) do
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then continue end

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
end

-- Hook into render loop
RunService.RenderStepped:Connect(updateSkeletons)

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

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char)
        if ESP.SkeletonEnabled then
            task.wait(1)
            createSkeleton(char)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(plr)
    if plr.Character then
        removeSkeleton(plr.Character)
    end
end)

return ESP

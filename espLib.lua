--Variables lol
local ESP = {}
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer



-- =========================
-- BOX ESP (fixed)
-- =========================

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

ESP.Enabled = false
ESP.Objects = ESP.Objects or {}
ESP.BoxColor = ESP.BoxColor or Color3.fromRGB(0, 255, 0)
ESP.BoxThickness = ESP.BoxThickness or 1.5

-- Create a box for a specific character
local function createBox(char)
    -- guard: don't double-create for the same character
    if ESP.Objects[char] then return end

    local box = Drawing.new("Square")
    box.Thickness = ESP.BoxThickness
    box.Color = ESP.BoxColor
    box.Filled = false
    box.Transparency = 1
    box.Visible = false

    ESP.Objects[char] = {
        Box = box,
        Character = char,
    }
end

-- Remove a character's box and entry
local function removeBox(char)
    local data = ESP.Objects[char]
    if data then
        if data.Box then
            data.Box:Remove()
        end
        ESP.Objects[char] = nil
    end
end

-- Update all boxes each frame
local function update()
    local cam = workspace.CurrentCamera
    if not cam then return end

    -- collect invalid entries to delete after iteration
    local toDelete = {}

    for char, data in pairs(ESP.Objects) do
        local box = data.Box
        local alive = char and char.Parent == workspace

        -- If character got destroyed / left workspace, purge it
        if (not alive) then
            box.Visible = false
            table.insert(toDelete, char)
            continue
        end

        -- Always apply latest styles every frame
        box.Color = ESP.BoxColor
        box.Thickness = ESP.BoxThickness

        if ESP.Enabled then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local head = char:FindFirstChild("Head")

            if hrp and head then
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
            else
                box.Visible = false
            end
        else
            box.Visible = false
        end
    end

    -- finalize deletions
    for _, deadChar in ipairs(toDelete) do
        removeBox(deadChar)
    end
end

-- Hook the update loop once
if not ESP.__BoxConn or not ESP.__BoxConn.Connected then
    ESP.__BoxConn = RunService.RenderStepped:Connect(update)
end

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
    for _, data in pairs(self.Objects) do
        if data.Box then data.Box.Visible = false end
    end
end

-- Track players joining/leaving and respawning
local function hookPlayer(plr)
    if plr == LocalPlayer then return end

    -- On spawn, create (or replace) the box for the new Character
    plr.CharacterAdded:Connect(function(char)
        task.wait(0.5) -- small buffer for parts to exist
        if ESP.Enabled then
            createBox(char)
        end
    end)

    -- On despawn, remove the old Character's box so duplicates don't stack
    if plr.CharacterRemoving then
        plr.CharacterRemoving:Connect(function(char)
            removeBox(char)
        end)
    end
end

for _, plr in ipairs(Players:GetPlayers()) do
    hookPlayer(plr)
end

Players.PlayerAdded:Connect(hookPlayer)

Players.PlayerRemoving:Connect(function(plr)
    -- remove any boxes that belong to this player (in case character is still around)
    for char in pairs(ESP.Objects) do
        local owner = Players:GetPlayerFromCharacter(char)
        if owner == plr then
            removeBox(char)
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

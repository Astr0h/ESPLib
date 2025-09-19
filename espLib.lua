-- Main toggleables
local ESP = {}
ESP.Enabled = false
ESP.Objects = {}
ESP.SkeletonEnabled = false
ESP.Skeletons = {}

--Variables lol
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Create a box ESP for a character
local function createBox(target)
    local box = Drawing.new("Square")
    box.Thickness = 1.5
    box.Color = Color3.fromRGB(0, 255, 0)
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


-- Function to create skeleton lines for a character
local function createSkeleton(char)
    local lines = {}

    local function newLine()
        local line = Drawing.new("Line")
        line.Thickness = 1.5
        line.Color = Color3.fromRGB(255, 255, 255)
        line.Transparency = 1
        line.Visible = false
        return line
    end

    -- we’ll need lines for limbs + torso
    lines.Head = newLine()
    lines.Torso = newLine()
    lines.LeftArm = newLine()
    lines.RightArm = newLine()
    lines.LeftLeg = newLine()
    lines.RightLeg = newLine()

    ESP.Skeletons[char] = lines
end

-- Remove skeleton when player leaves
local function removeSkeleton(char)
    if ESP.Skeletons[char] then
        for _, line in pairs(ESP.Skeletons[char]) do
            line:Remove()
        end
        ESP.Skeletons[char] = nil
    end
end

-- Update skeleton drawing
local function updateSkeleton()
    if not ESP.SkeletonEnabled then return end

    for char, lines in pairs(ESP.Skeletons) do
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        local leftArm = char:FindFirstChild("LeftHand") or char:FindFirstChild("Left Arm")
        local rightArm = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
        local leftLeg = char:FindFirstChild("LeftFoot") or char:FindFirstChild("Left Leg")
        local rightLeg = char:FindFirstChild("RightFoot") or char:FindFirstChild("Right Leg")

        if hrp and head and torso then
            local cam = workspace.CurrentCamera

            local function to2D(part)
                local pos, vis = cam:WorldToViewportPoint(part.Position)
                return Vector2.new(pos.X, pos.Y), vis
            end

            local torsoPos, visTorso = to2D(torso)
            local headPos, visHead = to2D(head)

            if visTorso and visHead then
                -- Head to Torso
                lines.Head.From = headPos
                lines.Head.To = torsoPos
                lines.Head.Visible = true
            else
                lines.Head.Visible = false
            end

            -- Arms
            if leftArm then
                local pos, vis = to2D(leftArm)
                if vis then
                    lines.LeftArm.From = torsoPos
                    lines.LeftArm.To = pos
                    lines.LeftArm.Visible = true
                else
                    lines.LeftArm.Visible = false
                end
            end
            if rightArm then
                local pos, vis = to2D(rightArm)
                if vis then
                    lines.RightArm.From = torsoPos
                    lines.RightArm.To = pos
                    lines.RightArm.Visible = true
                else
                    lines.RightArm.Visible = false
                end
            end

            -- Legs
            if leftLeg then
                local pos, vis = to2D(leftLeg)
                if vis then
                    lines.LeftLeg.From = torsoPos
                    lines.LeftLeg.To = pos
                    lines.LeftLeg.Visible = true
                else
                    lines.LeftLeg.Visible = false
                end
            end
            if rightLeg then
                local pos, vis = to2D(rightLeg)
                if vis then
                    lines.RightLeg.From = torsoPos
                    lines.RightLeg.To = pos
                    lines.RightLeg.Visible = true
                else
                    lines.RightLeg.Visible = false
                end
            end
        else
            for _, line in pairs(lines) do
                line.Visible = false
            end
        end
    end
end



-- Main loop
RunService.RenderStepped:Connect(update)
RunService.RenderStepped:Connect(updateSkeleton)

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

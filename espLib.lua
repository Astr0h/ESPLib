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

local function newLine()
    local line = Drawing.new("Line")
    line.Thickness = ESP.SkeletonThickness
    line.Color = ESP.SkeletonColor
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

-- =========================
-- Box + Tags
-- =========================
local function createESP(char)
    if ESP.Objects[char] then return end
    ESP.Objects[char] = {
        Box = newBox(),
        NameTag = newText(16, ESP.NameColor),
        HealthTag = newText(14, Color3.fromRGB(255, 255, 255)),
        DistanceTag = newText(14, ESP.DistanceColor),
        Character = char,
    }
end

local function removeESP(char)
    local data = ESP.Objects[char]
    if not data then return end
    for _, obj in pairs(data) do
        if typeof(obj) == "userdata" and obj.Remove then
            obj:Remove()
        end
    end
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
        lines[bone] = newLine()
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
    local cam = workspace.CurrentCamera
    if not cam then return end
    local toDelete = {}
    for char, data in pairs(ESP.Objects) do
        if not (char and char.Parent == workspace) then
            table.insert(toDelete, char)
            continue
        end
        -- (Box/Name/Health/Distance update here, same as your working code)
        -- ...
    end
    for _, c in ipairs(toDelete) do removeESP(c) end
end

local function updateSkeletons()
    if not ESP.SkeletonEnabled then return end
    local toDelete = {}
    for char, lines in pairs(ESP.Skeletons) do
        if not (char and char.Parent == workspace) then
            table.insert(toDelete, char)
            continue
        end
        -- (drawBone logic here, same as your working code)
        -- ...
    end
    for _, c in ipairs(toDelete) do removeSkeleton(c) end
end

-- Hook loops once
if not ESP.__BoxConn or not ESP.__BoxConn.Connected then
    ESP.__BoxConn = RunService.RenderStepped:Connect(updateESP)
end
if not ESP.__SkeletonConn or not ESP.__SkeletonConn.Connected then
    ESP.__SkeletonConn = RunService.RenderStepped:Connect(updateSkeletons)
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
        for _, obj in pairs(data) do if obj.Visible ~= nil then obj.Visible = false end end
    end
end

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
        for _, line in pairs(lines) do line.Visible = false end
    end
end

-- Optional cleanup
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
        if ESP.Enabled then createESP(char) end
        if ESP.SkeletonEnabled then createSkeleton(char) end
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

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Config = {
    Aim = {
        Enabled = false,
        FOV = 150,
        Smoothness = 0.35,
        MaxDistance = 2000,
        TargetPart = "Head",
        TeamCheck = true,
        WallCheck = true,
        AutoPart = true,
        PredictionFactor = 0.15
    },
    ESP = {
        Enabled = false,
        EnemyOnly = true,
        Box = true,
        Name = true,
        Distance = true,
        HealthBar = true,
        HealthText = true,
        ArmorText = true,
        WeaponInfo = true,
        Tracer = true,
        TracerStart = "Bottom",
        Skeleton = true,
        HeadDot = true,
        MaxDistance = 3000,
        TeamColors = true
    },
    Visuals = {
        EnemyColor = Color3.fromRGB(255, 60, 60),
        TeamColor = Color3.fromRGB(60, 255, 60),
        TracerColor = Color3.fromRGB(255, 255, 255),
        HealthBarColor = Color3.fromRGB(0, 255, 60),
        HealthTextColor = Color3.fromRGB(255, 255, 255),
        SkeletonColor = Color3.fromRGB(255, 255, 255),
        HeadDotColor = Color3.fromRGB(255, 255, 255),
        FOVColor = Color3.fromRGB(255, 255, 255),
        FOVThickness = 1,
        FOVTransparency = 0.5,
        BoxThickness = 1,
        WeaponColor = Color3.fromRGB(255, 200, 60),
        ArmorColor = Color3.fromRGB(60, 150, 255)
    },
    UI = {
        Font = Enum.Font.GothamBold,
        BackgroundColor = Color3.fromRGB(18, 18, 22),
        HeaderColor = Color3.fromRGB(28, 28, 34),
        ButtonColor = Color3.fromRGB(38, 38, 44),
        ToggleOnColor = Color3.fromRGB(0, 170, 255),
        ToggleOffColor = Color3.fromRGB(50, 50, 55),
        TextColor = Color3.fromRGB(255, 255, 255),
        AccentColor = Color3.fromRGB(0, 170, 255),
        MenuWidth = 340,
        MenuHeight = 440
    },
    Status = {
        Targets = 0,
        CurrentTarget = "None",
        CurrentTeam = "Unknown"
    }
}

local Utility = {}

function Utility:Create(class, props, parent)
    local inst = Instance.new(class)
    for prop, val in pairs(props) do
        pcall(function() inst[prop] = val end)
    end
    if parent then inst.Parent = parent end
    return inst
end

function Utility:SafeCall(func, ...)
    local args = {...}
    local success, result = pcall(function()
        return func(unpack(args))
    end)
    if success then return result end
    return nil
end

function Utility:GetDistance(rootPart)
    if not rootPart then return 0 end
    local char = LocalPlayer.Character
    if not char then return 0 end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return 0 end
    return (rootPart.Position - root.Position).Magnitude
end

function Utility:GetHealth(humanoid)
    if humanoid and humanoid.Health then
        return math.floor(humanoid.Health), math.floor(humanoid.MaxHealth)
    end
    return 0, 100
end

function Utility:GetWeapon(player)
    if not player or not player.Character then return "None" end
    local tool = player.Character:FindFirstChildOfClass("Tool")
    if tool then return tool.Name end
    return "None"
end

function Utility:GetArmor(player)
    if not player or not player.Character then return 0, 100 end
    local char = player.Character
    local armor = char:FindFirstChild("Armor")
    if armor and armor:IsA("NumberValue") then
        return math.floor(armor.Value), 100
    end
    local kevlar = char:FindFirstChild("Kevlar")
    if kevlar and kevlar:IsA("NumberValue") then
        return math.floor(kevlar.Value), 100
    end
    local vest = char:FindFirstChild("Vest")
    if vest and vest:IsA("NumberValue") then
        return math.floor(vest.Value), 100
    end
    local helmet = char:FindFirstChild("Helmet")
    if helmet and helmet:IsA("BoolValue") then
        if helmet.Value then return 50, 100 end
    end
    local kevlarBool = char:FindFirstChild("Kevlar")
    if kevlarBool and kevlarBool:IsA("BoolValue") then
        if kevlarBool.Value then return 100, 100 end
    end
    return 0, 100
end

function Utility:IsEnemy(player)
    if not player then return false end
    if not player.Team then return true end
    if not LocalPlayer.Team then return false end
    return player.Team ~= LocalPlayer.Team
end

function Utility:GetTeamColor(isEnemy)
    if Config.ESP.TeamColors then
        if isEnemy then
            return Config.Visuals.EnemyColor
        else
            return Config.Visuals.TeamColor
        end
    end
    return Color3.fromRGB(255, 255, 255)
end

local PlayerManager = {}

function PlayerManager:Init()
    self.TrackedPlayers = {}
    self.Connections = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            self:AddPlayer(player)
        end
    end

    self.Connections[#self.Connections + 1] = Players.PlayerAdded:Connect(function(player)
        if player ~= LocalPlayer then
            task.wait(0.5)
            self:AddPlayer(player)
        end
    end)

    self.Connections[#self.Connections + 1] = Players.PlayerRemoving:Connect(function(player)
        self:RemovePlayer(player)
    end)

    self.Connections[#self.Connections + 1] = LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function()
        task.wait(0.1)
        self:OnTeamChanged()
    end)

    Config.Status.CurrentTeam = LocalPlayer.Team and LocalPlayer.Team.Name or "Unknown"
end

function PlayerManager:AddPlayer(player)
    if self.TrackedPlayers[player] then return end

    local data = {
        Player = player,
        Character = nil,
        HumanoidRootPart = nil,
        Humanoid = nil,
        Head = nil,
        Torso = nil,
        Team = player.Team,
        IsEnemy = false,
        Connections = {},
        ESPObjects = {}
    }

    self.TrackedPlayers[player] = data
    data.IsEnemy = Utility:IsEnemy(player)

    local function onChar(char)
        task.wait(0.1)
        data.Character = char
        self:UpdateData(data)
        ESPController:OnPlayerAdded(player)
    end

    if player.Character then
        task.spawn(onChar, player.Character)
    end

    data.Connections[#data.Connections + 1] = player.CharacterAdded:Connect(onChar)

    data.Connections[#data.Connections + 1] = player:GetPropertyChangedSignal("Team"):Connect(function()
        task.wait(0.1)
        data.Team = player.Team
        data.IsEnemy = Utility:IsEnemy(player)
        ESPController:OnTeamChanged(player)
    end)
end

function PlayerManager:RemovePlayer(player)
    local data = self.TrackedPlayers[player]
    if data then
        for _, conn in ipairs(data.Connections) do
            pcall(function() conn:Disconnect() end)
        end
        ESPController:OnPlayerRemoved(player)
        self.TrackedPlayers[player] = nil
    end
end

function PlayerManager:UpdateData(data)
    local player = data.Player
    if not player or not player.Parent then return end

    local char = player.Character
    if not char or not char.Parent then
        data.Character = nil
        data.HumanoidRootPart = nil
        data.Humanoid = nil
        data.Head = nil
        data.Torso = nil
        return
    end

    data.Character = char
    data.HumanoidRootPart = char:FindFirstChild("HumanoidRootPart")
    data.Humanoid = char:FindFirstChildOfClass("Humanoid")
    data.Head = char:FindFirstChild("Head")
    data.Torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("LowerTorso")
end

function PlayerManager:Update()
    for player, data in pairs(self.TrackedPlayers) do
        if not player.Parent then
            self:RemovePlayer(player)
        else
            self:UpdateData(data)
        end
    end
end

function PlayerManager:OnTeamChanged()
    Config.Status.CurrentTeam = LocalPlayer.Team and LocalPlayer.Team.Name or "Unknown"
    for _, data in pairs(self.TrackedPlayers) do
        data.IsEnemy = Utility:IsEnemy(data.Player)
    end
end

local FilterManager = {}

function FilterManager:IsValidTarget(data)
    if not data then return false end
    if not data.Player then return false end
    if data.Player == LocalPlayer then return false end
    if not data.Character then return false end
    if not data.Humanoid then return false end
    if data.Humanoid.Health <= 0 then return false end
    if Config.Aim.TeamCheck and not data.IsEnemy then return false end
    return true
end

function FilterManager:IsVisible(data)
    if not Config.Aim.WallCheck then return true end
    if not data.Head then return false end
    if not data.HumanoidRootPart then return false end

    local camera = Workspace.CurrentCamera
    if not camera then return false end

    local localChar = LocalPlayer.Character
    if not localChar then return false end

    local origin = camera.CFrame.Position

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {localChar, data.Character}
    rayParams.IgnoreWater = true

    local headResult = Workspace:Raycast(origin, data.Head.Position - origin, rayParams)
    if not headResult then return true end

    local rootResult = Workspace:Raycast(origin, data.HumanoidRootPart.Position - origin, rayParams)
    if not rootResult then return true end

    if data.Torso then
        local torsoResult = Workspace:Raycast(origin, data.Torso.Position - origin, rayParams)
        if not torsoResult then return true end
    end

    return false
end

function FilterManager:ApplyESPFilters(data)
    if not data.Character then return false end
    if not data.Humanoid then return false end
    if data.Humanoid.Health <= 0 then return false end
    if Config.ESP.EnemyOnly and not data.IsEnemy then return false end
    if data.HumanoidRootPart then
        local dist = Utility:GetDistance(data.HumanoidRootPart)
        if dist > Config.ESP.MaxDistance then return false end
    end
    return true
end

function FilterManager:ApplyAimFilters(data)
    if not self:IsValidTarget(data) then return false end
    if data.HumanoidRootPart then
        local dist = Utility:GetDistance(data.HumanoidRootPart)
        if dist > Config.Aim.MaxDistance then return false end
    end
    if Config.Aim.WallCheck and not self:IsVisible(data) then return false end
    return true
end

local ESPController = {}

function ESPController:Init()
    RunService.RenderStepped:Connect(function()
        pcall(function()
            self:Update()
        end)
    end)
end

function ESPController:CreateDrawing(type, props)
    local ok, drawing = pcall(function()
        local d = Drawing.new(type)
        for prop, val in pairs(props) do
            pcall(function() d[prop] = val end)
        end
        return d
    end)
    if ok then return drawing end
    return nil
end

function ESPController:OnPlayerAdded(player)
    local data = PlayerManager.TrackedPlayers[player]
    if not data then return end

    if data.ESPObjects and next(data.ESPObjects) then
        self:RemoveDrawings(data)
    end

    data.ESPObjects = {}

    data.ESPObjects.Box = self:CreateDrawing("Square", {
        Thickness = Config.Visuals.BoxThickness,
        Color = Config.Visuals.EnemyColor,
        Filled = false,
        Visible = false
    })

    data.ESPObjects.BoxOutline = self:CreateDrawing("Square", {
        Thickness = 3,
        Color = Color3.fromRGB(0, 0, 0),
        Filled = false,
        Visible = false
    })

    data.ESPObjects.Name = self:CreateDrawing("Text", {
        Size = 13,
        Center = true,
        Outline = true,
        Color = Color3.fromRGB(255, 255, 255),
        Visible = false
    })

    data.ESPObjects.HealthText = self:CreateDrawing("Text", {
        Size = 12,
        Center = true,
        Outline = true,
        Color = Config.Visuals.HealthTextColor,
        Visible = false
    })

    data.ESPObjects.HealthBar = self:CreateDrawing("Square", {
        Thickness = 1,
        Color = Config.Visuals.HealthBarColor,
        Filled = true,
        Visible = false
    })

    data.ESPObjects.HealthBarOutline = self:CreateDrawing("Square", {
        Thickness = 1,
        Color = Color3.fromRGB(0, 0, 0),
        Filled = true,
        Visible = false
    })

    data.ESPObjects.ArmorText = self:CreateDrawing("Text", {
        Size = 12,
        Center = true,
        Outline = true,
        Color = Config.Visuals.ArmorColor,
        Visible = false
    })

    data.ESPObjects.ArmorBar = self:CreateDrawing("Square", {
        Thickness = 1,
        Color = Config.Visuals.ArmorColor,
        Filled = true,
        Visible = false
    })

    data.ESPObjects.ArmorBarOutline = self:CreateDrawing("Square", {
        Thickness = 1,
        Color = Color3.fromRGB(0, 0, 0),
        Filled = true,
        Visible = false
    })

    data.ESPObjects.WeaponText = self:CreateDrawing("Text", {
        Size = 12,
        Center = true,
        Outline = true,
        Color = Config.Visuals.WeaponColor,
        Visible = false
    })

    data.ESPObjects.DistanceText = self:CreateDrawing("Text", {
        Size = 12,
        Center = true,
        Outline = true,
        Color = Color3.fromRGB(255, 255, 255),
        Visible = false
    })

    data.ESPObjects.Tracer = self:CreateDrawing("Line", {
        Thickness = 1,
        Color = Config.Visuals.TracerColor,
        Visible = false
    })

    data.ESPObjects.TracerOutline = self:CreateDrawing("Line", {
        Thickness = 3,
        Color = Color3.fromRGB(0, 0, 0),
        Visible = false
    })

    data.ESPObjects.HeadDot = self:CreateDrawing("Circle", {
        Thickness = 1,
        Color = Config.Visuals.HeadDotColor,
        Filled = false,
        Visible = false
    })

    data.ESPObjects.HeadDotOutline = self:CreateDrawing("Circle", {
        Thickness = 3,
        Color = Color3.fromRGB(0, 0, 0),
        Filled = false,
        Visible = false
    })

    data.ESPObjects.Skeleton = {}

    local skeletonLines = {
        "HeadToTorso", "TorsoToLeftArm", "TorsoToRightArm",
        "TorsoToLeftLeg", "TorsoToRightLeg",
        "LeftArmDown", "RightArmDown",
        "LeftLegDown", "RightLegDown"
    }

    for _, lineName in ipairs(skeletonLines) do
        data.ESPObjects.Skeleton[lineName] = self:CreateDrawing("Line", {
            Thickness = 1,
            Color = Config.Visuals.SkeletonColor,
            Visible = false
        })
    end
end

function ESPController:RemoveDrawings(data)
    if not data.ESPObjects then return end
    for key, drawing in pairs(data.ESPObjects) do
        if typeof(drawing) == "table" then
            for _, d in pairs(drawing) do
                pcall(function() d:Remove() end)
            end
        else
            pcall(function() drawing:Remove() end)
        end
    end
    data.ESPObjects = {}
end

function ESPController:OnPlayerRemoved(player)
    local data = PlayerManager.TrackedPlayers[player]
    if data then
        self:RemoveDrawings(data)
    end
end

function ESPController:OnTeamChanged(player)
    local data = PlayerManager.TrackedPlayers[player]
    if not data or not data.ESPObjects then return end

    local color = Utility:GetTeamColor(data.IsEnemy)

    if data.ESPObjects.Box then
        data.ESPObjects.Box.Color = color
    end
    if data.ESPObjects.Name then
        data.ESPObjects.Name.Color = color
    end
    if data.ESPObjects.Tracer then
        data.ESPObjects.Tracer.Color = color
    end
    if data.ESPObjects.Skeleton then
        for _, line in pairs(data.ESPObjects.Skeleton) do
            if line then line.Color = color end
        end
    end
end

function ESPController:HideAll(data)
    if not data.ESPObjects then return end
    for key, drawing in pairs(data.ESPObjects) do
        if typeof(drawing) == "table" then
            for _, d in pairs(drawing) do
                pcall(function() d.Visible = false end)
            end
        else
            pcall(function() drawing.Visible = false end)
        end
    end
end

function ESPController:Update()
    if not Config.ESP.Enabled then
        for _, data in pairs(PlayerManager.TrackedPlayers) do
            self:HideAll(data)
        end
        Config.Status.Targets = 0
        return
    end

    local camera = Workspace.CurrentCamera
    if not camera then return end

    local viewport = camera.ViewportSize
    local screenBottom = Vector2.new(viewport.X / 2, viewport.Y)

    local targetCount = 0

    for _, data in pairs(PlayerManager.TrackedPlayers) do
        if FilterManager:ApplyESPFilters(data) then
            local root = data.HumanoidRootPart
            local head = data.Head

            if root and head then
                local headPos, headOnScreen = camera:WorldToViewportPoint(head.Position)
                local rootPos, rootOnScreen = camera:WorldToViewportPoint(root.Position)

                if headOnScreen or rootOnScreen then
                    targetCount = targetCount + 1
                    local esp = data.ESPObjects
                    if not esp or not esp.Box then
                        self:OnPlayerAdded(data.Player)
                        esp = data.ESPObjects
                    end
                    if not esp or not esp.Box then return end

                    local height = math.abs(rootPos.Y - headPos.Y)
                    local width = height * 0.6
                    if width < 10 then width = 10 end
                    if height < 15 then height = 15 end

                    local boxPos = Vector2.new(headPos.X - width / 2, headPos.Y)
                    local boxSize = Vector2.new(width, height)
                    local teamColor = Utility:GetTeamColor(data.IsEnemy)

                    if Config.ESP.Box then
                        esp.Box.Visible = true
                        esp.Box.Size = boxSize
                        esp.Box.Position = boxPos
                        esp.Box.Color = teamColor
                        esp.BoxOutline.Visible = true
                        esp.BoxOutline.Size = boxSize
                        esp.BoxOutline.Position = boxPos
                    else
                        esp.Box.Visible = false
                        esp.BoxOutline.Visible = false
                    end

                    if Config.ESP.Name then
                        esp.Name.Visible = true
                        esp.Name.Text = data.Player.Name
                        esp.Name.Position = Vector2.new(boxPos.X + width / 2, boxPos.Y - 16)
                        esp.Name.Color = teamColor
                    else
                        esp.Name.Visible = false
                    end

                    local infoY = boxPos.Y + height + 5

                    if Config.ESP.HealthText then
                        local hp, maxHp = Utility:GetHealth(data.Humanoid)
                        esp.HealthText.Visible = true
                        esp.HealthText.Text = hp .. "/" .. maxHp
                        esp.HealthText.Position = Vector2.new(boxPos.X + width / 2, infoY)
                        local percent = hp / maxHp
                        if percent > 0.5 then
                            esp.HealthText.Color = Color3.fromRGB(0, 255, 60)
                        elseif percent > 0.25 then
                            esp.HealthText.Color = Color3.fromRGB(255, 255, 0)
                        else
                            esp.HealthText.Color = Color3.fromRGB(255, 0, 0)
                        end
                        infoY = infoY + 14
                    else
                        esp.HealthText.Visible = false
                    end

                    if Config.ESP.HealthBar then
                        local hp, maxHp = Utility:GetHealth(data.Humanoid)
                        local percent = hp / maxHp

                        esp.HealthBar.Visible = true
                        esp.HealthBarOutline.Visible = true

                        esp.HealthBarOutline.Size = Vector2.new(3, height)
                        esp.HealthBarOutline.Position = Vector2.new(boxPos.X - 6, boxPos.Y)

                        esp.HealthBar.Size = Vector2.new(2, height * percent)
                        esp.HealthBar.Position = Vector2.new(boxPos.X - 5, boxPos.Y + (height - height * percent))

                        if percent > 0.5 then
                            esp.HealthBar.Color = Color3.fromRGB(0, 255, 60)
                        elseif percent > 0.25 then
                            esp.HealthBar.Color = Color3.fromRGB(255, 255, 0)
                        else
                            esp.HealthBar.Color = Color3.fromRGB(255, 0, 0)
                        end
                    else
                        esp.HealthBar.Visible = false
                        esp.HealthBarOutline.Visible = false
                    end

                    local armor, maxArmor = Utility:GetArmor(data.Player)

                    if Config.ESP.ArmorText and armor > 0 then
                        esp.ArmorText.Visible = true
                        esp.ArmorText.Text = "Armor: " .. armor
                        esp.ArmorText.Position = Vector2.new(boxPos.X + width / 2, infoY)
                        infoY = infoY + 14
                    else
                        esp.ArmorText.Visible = false
                    end

                    if Config.ESP.ArmorBar and armor > 0 then
                        local armorPercent = armor / maxArmor
                        esp.ArmorBar.Visible = true
                        esp.ArmorBarOutline.Visible = true
                        esp.ArmorBarOutline.Size = Vector2.new(3, height)
                        esp.ArmorBarOutline.Position = Vector2.new(boxPos.X - 11, boxPos.Y)
                        esp.ArmorBar.Size = Vector2.new(2, height * armorPercent)
                        esp.ArmorBar.Position = Vector2.new(boxPos.X - 10, boxPos.Y + (height - height * armorPercent))
                    else
                        esp.ArmorBar.Visible = false
                        esp.ArmorBarOutline.Visible = false
                    end

                    if Config.ESP.WeaponInfo then
                        local weapon = Utility:GetWeapon(data.Player)
                        esp.WeaponText.Visible = true
                        esp.WeaponText.Text = weapon
                        esp.WeaponText.Position = Vector2.new(boxPos.X + width / 2, infoY)
                        infoY = infoY + 14
                    else
                        esp.WeaponText.Visible = false
                    end

                    if Config.ESP.Distance then
                        local dist = Utility:GetDistance(root)
                        esp.DistanceText.Visible = true
                        esp.DistanceText.Text = math.floor(dist) .. "m"
                        esp.DistanceText.Position = Vector2.new(boxPos.X + width / 2, infoY)
                        infoY = infoY + 14
                    else
                        esp.DistanceText.Visible = false
                    end

                    if Config.ESP.Tracer then
                        esp.Tracer.Visible = true
                        esp.TracerOutline.Visible = true

                        local tracerFrom
                        if Config.ESP.TracerStart == "Bottom" then
                            tracerFrom = screenBottom
                        elseif Config.ESP.TracerStart == "Center" then
                            tracerFrom = Vector2.new(viewport.X / 2, viewport.Y / 2)
                        else
                            tracerFrom = Vector2.new(viewport.X / 2, 0)
                        end

                        esp.Tracer.From = tracerFrom
                        esp.Tracer.To = Vector2.new(boxPos.X + width / 2, boxPos.Y + height)
                        esp.Tracer.Color = teamColor
                        esp.TracerOutline.From = tracerFrom
                        esp.TracerOutline.To = Vector2.new(boxPos.X + width / 2, boxPos.Y + height)
                    else
                        esp.Tracer.Visible = false
                        esp.TracerOutline.Visible = false
                    end

                    if Config.ESP.HeadDot then
                        esp.HeadDot.Visible = true
                        esp.HeadDotOutline.Visible = true
                        esp.HeadDot.Radius = math.max(height * 0.1, 3)
                        esp.HeadDot.Position = Vector2.new(headPos.X, headPos.Y)
                        esp.HeadDotOutline.Radius = math.max(height * 0.1, 3) + 2
                        esp.HeadDotOutline.Position = Vector2.new(headPos.X, headPos.Y)
                    else
                        esp.HeadDot.Visible = false
                        esp.HeadDotOutline.Visible = false
                    end

                    if Config.ESP.Skeleton and esp.Skeleton then
                        local char = data.Character
                        if char then
                            self:UpdateSkeleton(esp, char, camera)
                        end
                    else
                        if esp.Skeleton then
                            for _, line in pairs(esp.Skeleton) do
                                if line then line.Visible = false end
                            end
                        end
                    end
                else
                    self:HideAll(data)
                end
            else
                self:HideAll(data)
            end
        else
            self:HideAll(data)
        end
    end

    Config.Status.Targets = targetCount
end

function ESPController:UpdateSkeleton(esp, char, camera)
    local parts = {
        Head = char:FindFirstChild("Head"),
        Torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"),
        LeftUpperArm = char:FindFirstChild("Left Arm") or char:FindFirstChild("LeftUpperArm"),
        RightUpperArm = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightUpperArm"),
        LeftLowerArm = char:FindFirstChild("LeftLowerArm"),
        RightLowerArm = char:FindFirstChild("RightLowerArm"),
        LeftUpperLeg = char:FindFirstChild("Left Leg") or char:FindFirstChild("LeftUpperLeg"),
        RightUpperLeg = char:FindFirstChild("Right Leg") or char:FindFirstChild("RightUpperLeg"),
        LeftLowerLeg = char:FindFirstChild("LeftLowerLeg"),
        RightLowerLeg = char:FindFirstChild("RightLowerLeg")
    }

    local screenParts = {}
    for name, part in pairs(parts) do
        if part then
            local pos, onScreen = camera:WorldToViewportPoint(part.Position)
            screenParts[name] = Vector2.new(pos.X, pos.Y)
        end
    end

    if screenParts.Head and screenParts.Torso then
        esp.Skeleton.HeadToTorso.Visible = true
        esp.Skeleton.HeadToTorso.From = screenParts.Head
        esp.Skeleton.HeadToTorso.To = screenParts.Torso
    else
        esp.Skeleton.HeadToTorso.Visible = false
    end

    if screenParts.Torso and screenParts.LeftUpperArm then
        esp.Skeleton.TorsoToLeftArm.Visible = true
        esp.Skeleton.TorsoToLeftArm.From = screenParts.Torso
        esp.Skeleton.TorsoToLeftArm.To = screenParts.LeftUpperArm
    else
        esp.Skeleton.TorsoToLeftArm.Visible = false
    end

    if screenParts.Torso and screenParts.RightUpperArm then
        esp.Skeleton.TorsoToRightArm.Visible = true
        esp.Skeleton.TorsoToRightArm.From = screenParts.Torso
        esp.Skeleton.TorsoToRightArm.To = screenParts.RightUpperArm
    else
        esp.Skeleton.TorsoToRightArm.Visible = false
    end

    if screenParts.Torso and screenParts.LeftUpperLeg then
        esp.Skeleton.TorsoToLeftLeg.Visible = true
        esp.Skeleton.TorsoToLeftLeg.From = screenParts.Torso
        esp.Skeleton.TorsoToLeftLeg.To = screenParts.LeftUpperLeg
    else
        esp.Skeleton.TorsoToLeftLeg.Visible = false
    end

    if screenParts.Torso and screenParts.RightUpperLeg then
        esp.Skeleton.TorsoToRightLeg.Visible = true
        esp.Skeleton.TorsoToRightLeg.From = screenParts.Torso
        esp.Skeleton.TorsoToRightLeg.To = screenParts.RightUpperLeg
    else
        esp.Skeleton.TorsoToRightLeg.Visible = false
    end

    if screenParts.LeftUpperArm and screenParts.LeftLowerArm then
        esp.Skeleton.LeftArmDown.Visible = true
        esp.Skeleton.LeftArmDown.From = screenParts.LeftUpperArm
        esp.Skeleton.LeftArmDown.To = screenParts.LeftLowerArm
    else
        esp.Skeleton.LeftArmDown.Visible = false
    end

    if screenParts.RightUpperArm and screenParts.RightLowerArm then
        esp.Skeleton.RightArmDown.Visible = true
        esp.Skeleton.RightArmDown.From = screenParts.RightUpperArm
        esp.Skeleton.RightArmDown.To = screenParts.RightLowerArm
    else
        esp.Skeleton.RightArmDown.Visible = false
    end

    if screenParts.LeftUpperLeg and screenParts.LeftLowerLeg then
        esp.Skeleton.LeftLegDown.Visible = true
        esp.Skeleton.LeftLegDown.From = screenParts.LeftUpperLeg
        esp.Skeleton.LeftLegDown.To = screenParts.LeftLowerLeg
    else
        esp.Skeleton.LeftLegDown.Visible = false
    end

    if screenParts.RightUpperLeg and screenParts.RightLowerLeg then
        esp.Skeleton.RightLegDown.Visible = true
        esp.Skeleton.RightLegDown.From = screenParts.RightUpperLeg
        esp.Skeleton.RightLegDown.To = screenParts.RightLowerLeg
    else
        esp.Skeleton.RightLegDown.Visible = false
    end
end

local AimController = {}

function AimController:Init()
    self.CurrentTarget = nil

    self.FOVCircle = self:CreateDrawing("Circle", {
        Thickness = Config.Visuals.FOVThickness,
        Color = Config.Visuals.FOVColor,
        Filled = false,
        Visible = false
    })

    self.FOVCircleOutline = self:CreateDrawing("Circle", {
        Thickness = Config.Visuals.FOVThickness + 2,
        Color = Color3.fromRGB(0, 0, 0),
        Filled = false,
        Visible = false
    })

    RunService.RenderStepped:Connect(function()
        pcall(function()
            self:Update()
        end)
    end)
end

function AimController:CreateDrawing(type, props)
    local ok, drawing = pcall(function()
        local d = Drawing.new(type)
        for prop, val in pairs(props) do
            pcall(function() d[prop] = val end)
        end
        return d
    end)
    if ok then return drawing end
    return nil
end

function AimController:GetTargetPart(data)
    local char = data.Character
    if not char then return nil end

    local part = nil

    if Config.Aim.TargetPart == "Head" then
        part = char:FindFirstChild("Head")
        if not part and Config.Aim.AutoPart then
            part = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart")
        end
    elseif Config.Aim.TargetPart == "Torso" then
        part = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("LowerTorso")
        if not part and Config.Aim.AutoPart then
            part = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        end
    elseif Config.Aim.TargetPart == "HumanoidRootPart" then
        part = char:FindFirstChild("HumanoidRootPart")
        if not part and Config.Aim.AutoPart then
            part = char:FindFirstChild("Head") or char:FindFirstChild("Torso")
        end
    else
        part = char:FindFirstChild("Head") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart")
    end

    return part
end

function AimController:FindBestTarget()
    local bestTarget = nil
    local bestScore = math.huge
    local camera = Workspace.CurrentCamera
    if not camera then return nil end

    local viewport = camera.ViewportSize
    local screenCenter = Vector2.new(viewport.X / 2, viewport.Y / 2)

    local localChar = LocalPlayer.Character
    if not localChar then return nil end
    local localRoot = localChar:FindFirstChild("HumanoidRootPart")
    if not localRoot then return nil end

    for _, data in pairs(PlayerManager.TrackedPlayers) do
        if FilterManager:ApplyAimFilters(data) then
            local targetPart = self:GetTargetPart(data)
            if targetPart then
                local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                if onScreen then
                    local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                    if screenDist <= Config.Aim.FOV then
                        local worldDist = Utility:GetDistance(data.HumanoidRootPart)
                        local score = screenDist + worldDist * 0.1

                        if score < bestScore then
                            bestScore = score
                            bestTarget = data
                        end
                    end
                end
            end
        end
    end

    return bestTarget
end

function AimController:Update()
    local camera = Workspace.CurrentCamera
    if not camera then return end

    local viewport = camera.ViewportSize
    local screenCenter = Vector2.new(viewport.X / 2, viewport.Y / 2)

    if self.FOVCircle then
        if Config.Aim.Enabled then
            self.FOVCircle.Visible = true
            self.FOVCircle.Radius = Config.Aim.FOV
            self.FOVCircle.Position = screenCenter
            self.FOVCircle.Thickness = Config.Visuals.FOVThickness

            if self.FOVCircleOutline then
                self.FOVCircleOutline.Visible = true
                self.FOVCircleOutline.Radius = Config.Aim.FOV + 1
                self.FOVCircleOutline.Position = screenCenter
            end
        else
            self.FOVCircle.Visible = false
            if self.FOVCircleOutline then
                self.FOVCircleOutline.Visible = false
            end
        end
    end

    if not Config.Aim.Enabled then
        self.CurrentTarget = nil
        Config.Status.CurrentTarget = "None"
        return
    end

    local target = self:FindBestTarget()

    if target then
        self.CurrentTarget = target
        Config.Status.CurrentTarget = target.Player.Name

        local targetPart = self:GetTargetPart(target)
        if targetPart then
            local predictedPos = targetPart.Position

            if Config.Aim.PredictionFactor > 0 and target.HumanoidRootPart then
                local vel = target.HumanoidRootPart.AssemblyLinearVelocity
                if vel then
                    predictedPos = predictedPos + vel * Config.Aim.PredictionFactor
                end
            end

            local currentCFrame = camera.CFrame
            local targetCFrame = CFrame.new(currentCFrame.Position, predictedPos)
            local smoothness = math.clamp(Config.Aim.Smoothness, 0.01, 1.0)
            camera.CFrame = currentCFrame:Lerp(targetCFrame, smoothness)
        end
    else
        self.CurrentTarget = nil
        Config.Status.CurrentTarget = "None"
    end
end

local UIController = {}

function UIController:Init()
    self.ScreenGui = nil
    self.QuickButtons = {}
    self.Sections = {}
    self.TabButtons = {}

    self.ScreenGui = Utility:Create("ScreenGui", {
        Name = "CB_" .. tostring(math.random(10000, 99999)),
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    }, LocalPlayer:WaitForChild("PlayerGui"))

    if not self.ScreenGui then return end

    self:CreateToggleButton()
    self:CreateTopBar()
    self:CreateMainMenu()
end

function UIController:CreateToggleButton()
    local btn = Utility:Create("TextButton", {
        Name = "Toggle",
        Size = UDim2.new(0, 60, 0, 60),
        Position = UDim2.new(0, 10, 0.5, -30),
        BackgroundColor3 = Config.UI.BackgroundColor,
        BackgroundTransparency = 0.2,
        Text = "☰",
        TextColor3 = Config.UI.TextColor,
        TextSize = 28,
        Font = Config.UI.Font,
        AutoButtonColor = false,
        Parent = self.ScreenGui
    })

    pcall(function()
        Utility:Create("UICorner", {
            CornerRadius = UDim.new(1, 0)
        }, btn)
    end)

    pcall(function()
        Utility:Create("UIStroke", {
            Color = Config.UI.AccentColor,
            Thickness = 2,
            Transparency = 0.5
        }, btn)
    end)

    local isDragging = false
    local dragStart = nil
    local startPos = nil
    local lastTap = 0

    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = false
            dragStart = input.Position
            startPos = btn.Position
        end
    end)

    btn.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
            if dragStart and startPos then
                local delta = input.Position - dragStart
                if delta.Magnitude > 10 then
                    isDragging = true
                end
                if isDragging then
                    btn.Position = UDim2.new(
                        startPos.X.Scale, startPos.X.Offset + delta.X,
                        startPos.Y.Scale, startPos.Y.Offset + delta.Y
                    )
                end
            end
        end
    end)

    btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            if not isDragging then
                local now = os.clock()
                if now - lastTap > 0.1 then
                    lastTap = now
                    if self.MainMenu then
                        self.MainMenu.Visible = not self.MainMenu.Visible
                    end
                end
            end
            isDragging = false
            dragStart = nil
            startPos = nil
        end
    end)
end

function UIController:CreateTopBar()
    local topBar = Utility:Create("Frame", {
        Name = "TopBar",
        Size = UDim2.new(0, 360, 0, 40),
        Position = UDim2.new(0.5, -180, 0, 4),
        BackgroundColor3 = Config.UI.BackgroundColor,
        BackgroundTransparency = 0.3,
        Parent = self.ScreenGui
    })

    pcall(function()
        Utility:Create("UICorner", {
            CornerRadius = UDim.new(0, 8)
        }, topBar)
    end)

    pcall(function()
        Utility:Create("UIStroke", {
            Color = Config.UI.AccentColor,
            Thickness = 1,
            Transparency = 0.7
        }, topBar)
    end)

    local buttons = {
        {Name = "AIM", GetFunc = function() return Config.Aim.Enabled end, SetFunc = function(v) Config.Aim.Enabled = v end},
        {Name = "ESP", GetFunc = function() return Config.ESP.Enabled end, SetFunc = function(v) Config.ESP.Enabled = v end},
        {Name = "TEAM", GetFunc = function() return Config.Aim.TeamCheck end, SetFunc = function(v) Config.Aim.TeamCheck = v; Config.ESP.EnemyOnly = v end},
        {Name = "WALL", GetFunc = function() return Config.Aim.WallCheck end, SetFunc = function(v) Config.Aim.WallCheck = v end}
    }

    local btnWidth = 80
    local spacing = 6
    local totalWidth = (#buttons * btnWidth) + (#buttons - 1) * spacing
    local startX = (360 - totalWidth) / 2

    for i, btnInfo in ipairs(buttons) do
        local btn = Utility:Create("TextButton", {
            Name = btnInfo.Name,
            Size = UDim2.new(0, btnWidth, 0, 28),
            Position = UDim2.new(0, startX + (i-1) * (btnWidth + spacing), 0, 6),
            BackgroundColor3 = Config.UI.ToggleOffColor,
            Text = btnInfo.Name .. ": OFF",
            TextColor3 = Config.UI.TextColor,
            TextSize = 11,
            Font = Config.UI.Font,
            AutoButtonColor = false,
            Parent = topBar
        })

        pcall(function()
            Utility:Create("UICorner", {
                CornerRadius = UDim.new(0, 6)
            }, btn)
        end)

        self.QuickButtons[btnInfo.Name] = {Btn = btn, Info = btnInfo}

        local lastTap = 0

        local function onTap()
            local now = os.clock()
            if now - lastTap > 0.1 then
                lastTap = now
                btnInfo.SetFunc(not btnInfo.GetFunc())
                self:UpdateQuickButton(btnInfo.Name)
            end
        end

        btn.TouchTap:Connect(onTap)
        btn.MouseButton1Click:Connect(onTap)
    end

    self:UpdateAllQuickButtons()
end

function UIController:UpdateQuickButton(name)
    local info = self.QuickButtons[name]
    if not info then return end

    local isOn = info.Info.GetFunc()

    if isOn then
        info.Btn.BackgroundColor3 = Config.UI.ToggleOnColor
        info.Btn.Text = name .. ": ON"
    else
        info.Btn.BackgroundColor3 = Config.UI.ToggleOffColor
        info.Btn.Text = name .. ": OFF"
    end
end

function UIController:UpdateAllQuickButtons()
    for name, _ in pairs(self.QuickButtons) do
        self:UpdateQuickButton(name)
    end
end

function UIController:CreateMainMenu()
    self.MainMenu = Utility:Create("Frame", {
        Name = "Menu",
        Size = UDim2.new(0, Config.UI.MenuWidth, 0, Config.UI.MenuHeight),
        Position = UDim2.new(0.5, -Config.UI.MenuWidth / 2, 0.5, -Config.UI.MenuHeight / 2),
        BackgroundColor3 = Config.UI.BackgroundColor,
        Visible = false,
        Parent = self.ScreenGui
    })

    pcall(function()
        Utility:Create("UICorner", {
            CornerRadius = UDim.new(0, 12)
        }, self.MainMenu)
    end)

    pcall(function()
        Utility:Create("UIStroke", {
            Color = Config.UI.AccentColor,
            Thickness = 2,
            Transparency = 0.3
        }, self.MainMenu)
    end)

    local header = Utility:Create("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 44),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Config.UI.HeaderColor,
        Parent = self.MainMenu
    })

    Utility:Create("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, -80, 1, 0),
        Position = UDim2.new(0, 15, 0, 0),
        BackgroundTransparency = 1,
        Text = "CB MOBILE v5",
        TextColor3 = Config.UI.AccentColor,
        TextSize = 18,
        Font = Config.UI.Font,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header
    })

    local closeBtn = Utility:Create("TextButton", {
        Name = "Close",
        Size = UDim2.new(0, 36, 0, 36),
        Position = UDim2.new(1, -42, 0, 4),
        BackgroundColor3 = Color3.fromRGB(200, 50, 50),
        Text = "×",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 20,
        Font = Config.UI.Font,
        AutoButtonColor = false,
        Parent = header
    })

    pcall(function()
        Utility:Create("UICorner", {
            CornerRadius = UDim.new(0, 8)
        }, closeBtn)
    end)

    closeBtn.TouchTap:Connect(function()
        self.MainMenu.Visible = false
    end)

    closeBtn.MouseButton1Click:Connect(function()
        self.MainMenu.Visible = false
    end)

    local isDragging = false
    local dragStart, dragPos

    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = true
            dragStart = input.Position
            dragPos = self.MainMenu.Position
        end
    end)

    header.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
            if isDragging and dragStart and dragPos then
                local delta = input.Position - dragStart
                self.MainMenu.Position = UDim2.new(
                    dragPos.X.Scale, dragPos.X.Offset + delta.X,
                    dragPos.Y.Scale, dragPos.Y.Offset + delta.Y
                )
            end
        end
    end)

    header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = false
        end
    end)

    local tabs = {"AIM", "ESP", "FILTERS", "SETTINGS"}

    local tabHolder = Utility:Create("Frame", {
        Name = "Tabs",
        Size = UDim2.new(1, -16, 0, 36),
        Position = UDim2.new(0, 8, 0, 50),
        BackgroundColor3 = Config.UI.HeaderColor,
        Parent = self.MainMenu
    })

    pcall(function()
        Utility:Create("UICorner", {
            CornerRadius = UDim.new(0, 8)
        }, tabHolder)
    end)

    local tabWidth = 78
    local tabSpacing = 4
    local totalTabWidth = (#tabs * tabWidth) + (#tabs - 1) * tabSpacing
    local tabStartX = (Config.UI.MenuWidth - 16 - totalTabWidth) / 2

    for i, tabName in ipairs(tabs) do
        local tabBtn = Utility:Create("TextButton", {
            Name = tabName,
            Size = UDim2.new(0, tabWidth, 0, 28),
            Position = UDim2.new(0, tabStartX + (i-1) * (tabWidth + tabSpacing), 0, 4),
            BackgroundColor3 = i == 1 and Config.UI.AccentColor or Config.UI.ToggleOffColor,
            Text = tabName,
            TextColor3 = Config.UI.TextColor,
            TextSize = 11,
            Font = Config.UI.Font,
            AutoButtonColor = false,
            Parent = tabHolder
        })

        pcall(function()
            Utility:Create("UICorner", {
                CornerRadius = UDim.new(0, 6)
            }, tabBtn)
        end)

        self.TabButtons[tabName] = tabBtn

        local section = Utility:Create("ScrollingFrame", {
            Name = tabName .. "Section",
            Size = UDim2.new(1, -16, 1, -100),
            Position = UDim2.new(0, 8, 0, 94),
            BackgroundTransparency = 1,
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = Config.UI.AccentColor,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = i == 1,
            Parent = self.MainMenu
        })

        Utility:Create("UIListLayout", {
            Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder
        }, section)

        self.Sections[tabName] = section

        local function switchTab()
            for _, sec in pairs(self.Sections) do
                sec.Visible = false
            end
            for name, tb in pairs(self.TabButtons) do
                tb.BackgroundColor3 = Config.UI.ToggleOffColor
            end
            section.Visible = true
            tabBtn.BackgroundColor3 = Config.UI.AccentColor
        end

        tabBtn.TouchTap:Connect(switchTab)
        tabBtn.MouseButton1Click:Connect(switchTab)
    end

    self:CreateAimSettings()
    self:CreateESPSettings()
    self:CreateFilterSettings()
    self:CreateGeneralSettings()
end

function UIController:CreateToggle(parent, text, getFunc, setFunc)
    local container = Utility:Create("Frame", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = Config.UI.ButtonColor,
        Parent = parent
    })

    pcall(function()
        Utility:Create("UICorner", {
            CornerRadius = UDim.new(0, 8)
        }, container)
    end)

    Utility:Create("TextLabel", {
        Size = UDim2.new(0.6, 0, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Config.UI.TextColor,
        TextSize = 13,
        Font = Config.UI.Font,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = container
    })

    local toggleBtn = Utility:Create("TextButton", {
        Size = UDim2.new(0, 56, 0, 26),
        Position = UDim2.new(1, -66, 0.5, -13),
        BackgroundColor3 = getFunc() and Config.UI.ToggleOnColor or Config.UI.ToggleOffColor,
        Text = getFunc() and "ON" or "OFF",
        TextColor3 = Config.UI.TextColor,
        TextSize = 11,
        Font = Config.UI.Font,
        AutoButtonColor = false,
        Parent = container
    })

    pcall(function()
        Utility:Create("UICorner", {
            CornerRadius = UDim.new(0, 6)
        }, toggleBtn)
    end)

    local function updateVisual()
        if getFunc() then
            toggleBtn.BackgroundColor3 = Config.UI.ToggleOnColor
            toggleBtn.Text = "ON"
        else
            toggleBtn.BackgroundColor3 = Config.UI.ToggleOffColor
            toggleBtn.Text = "OFF"
        end
    end

    local lastTap = 0

    local function onTap()
        local now = os.clock()
        if now - lastTap > 0.1 then
            lastTap = now
            setFunc(not getFunc())
            updateVisual()
            self:UpdateAllQuickButtons()
        end
    end

    toggleBtn.TouchTap:Connect(onTap)
    toggleBtn.MouseButton1Click:Connect(onTap)

    updateVisual()

    return {
        Update = updateVisual
    }
end

function UIController:CreateSlider(parent, text, min, max, getFunc, setFunc)
    local container = Utility:Create("Frame", {
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundColor3 = Config.UI.ButtonColor,
        Parent = parent
    })

    pcall(function()
        Utility:Create("UICorner", {
            CornerRadius = UDim.new(0, 8)
        }, container)
    end)

    Utility:Create("TextLabel", {
        Size = UDim2.new(0.6, 0, 0, 18),
        Position = UDim2.new(0, 12, 0, 4),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Config.UI.TextColor,
        TextSize = 12,
        Font = Config.UI.Font,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = container
    })

    local valueLabel = Utility:Create("TextLabel", {
        Size = UDim2.new(0, 60, 0, 18),
        Position = UDim2.new(1, -72, 0, 4),
        BackgroundTransparency = 1,
        Text = tostring(math.floor(getFunc())),
        TextColor3 = Config.UI.AccentColor,
        TextSize = 12,
        Font = Config.UI.Font,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = container
    })

    local sliderBar = Utility:Create("Frame", {
        Size = UDim2.new(1, -24, 0, 8),
        Position = UDim2.new(0, 12, 0, 28),
        BackgroundColor3 = Config.UI.ToggleOffColor,
        Parent = container
    })

    pcall(function()
        Utility:Create("UICorner", {
            CornerRadius = UDim.new(0, 4)
        }, sliderBar)
    end)

    local default = getFunc()
    local sliderFill = Utility:Create("Frame", {
        Size = UDim2.new((default - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = Config.UI.AccentColor,
        BorderSizePixel = 0,
        Parent = sliderBar
    })

    pcall(function()
        Utility:Create("UICorner", {
            CornerRadius = UDim.new(0, 4)
        }, sliderFill)
    end)

    local sliderBtn = Utility:Create("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        Parent = sliderBar
    })

    local isDragging = false

    local function updateValue(inputPos)
        local relativeX = inputPos.X - sliderBar.AbsolutePosition.X
        local percent = math.clamp(relativeX / sliderBar.AbsoluteSize.X, 0, 1)
        local value = math.floor(min + (max - min) * percent)
        valueLabel.Text = tostring(value)
        sliderFill.Size = UDim2.new(percent, 0, 1, 0)
        setFunc(value)
    end

    sliderBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = true
            updateValue(input.Position)
        end
    end)

    sliderBtn.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
            if isDragging then
                updateValue(input.Position)
            end
        end
    end)

    sliderBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = false
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = false
        end
    end)

    return {
        Update = function()
            local value = getFunc()
            valueLabel.Text = tostring(math.floor(value))
            local percent = (value - min) / (max - min)
            sliderFill.Size = UDim2.new(percent, 0, 1, 0)
        end
    }
end

function UIController:CreateDropdown(parent, text, options, getFunc, setFunc)
    local container = Utility:Create("Frame", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = Config.UI.ButtonColor,
        Parent = parent
    })

    pcall(function()
        Utility:Create("UICorner", {
            CornerRadius = UDim.new(0, 8)
        }, container)
    end)

    Utility:Create("TextLabel", {
        Size = UDim2.new(0.5, 0, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Config.UI.TextColor,
        TextSize = 12,
        Font = Config.UI.Font,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = container
    })

    local btn = Utility:Create("TextButton", {
        Size = UDim2.new(0, 120, 0, 28),
        Position = UDim2.new(1, -132, 0.5, -14),
        BackgroundColor3 = Config.UI.ToggleOffColor,
        Text = getFunc(),
        TextColor3 = Config.UI.TextColor,
        TextSize = 11,
        Font = Config.UI.Font,
        AutoButtonColor = false,
        Parent = container
    })

    pcall(function()
        Utility:Create("UICorner", {
            CornerRadius = UDim.new(0, 6)
        }, btn)
    end)

    local currentIndex = table.find(options, getFunc()) or 1
    local lastTap = 0

    local function cycle()
        local now = os.clock()
        if now - lastTap > 0.1 then
            lastTap = now
            currentIndex = currentIndex % #options + 1
            btn.Text = options[currentIndex]
            setFunc(options[currentIndex])
        end
    end

    btn.TouchTap:Connect(cycle)
    btn.MouseButton1Click:Connect(cycle)
end

function UIController:CreateAimSettings()
    local section = self.Sections["AIM"]
    if not section then return end

    self:CreateToggle(section, "Aim Enabled",
        function() return Config.Aim.Enabled end,
        function(v) Config.Aim.Enabled = v end
    )

    self:CreateSlider(section, "FOV Radius", 50, 500,
        function() return Config.Aim.FOV end,
        function(v) Config.Aim.FOV = v end
    )

    self:CreateSlider(section, "Smoothness", 1, 100,
        function() return Config.Aim.Smoothness * 100 end,
        function(v) Config.Aim.Smoothness = v / 100 end
    )

    self:CreateSlider(section, "Max Distance", 100, 5000,
        function() return Config.Aim.MaxDistance end,
        function(v) Config.Aim.MaxDistance = v end
    )

    self:CreateDropdown(section, "Target Part", {"Head", "Torso", "HumanoidRootPart", "Auto"},
        function() return Config.Aim.TargetPart end,
        function(v) Config.Aim.TargetPart = v end
    )

    self:CreateToggle(section, "Team Check",
        function() return Config.Aim.TeamCheck end,
        function(v)
            Config.Aim.TeamCheck = v
            Config.ESP.EnemyOnly = v
        end
    )

    self:CreateToggle(section, "Wall Check",
        function() return Config.Aim.WallCheck end,
        function(v) Config.Aim.WallCheck = v end
    )

    self:CreateToggle(section, "Auto Part Fallback",
        function() return Config.Aim.AutoPart end,
        function(v) Config.Aim.AutoPart = v end
    )

    self:CreateSlider(section, "Prediction", 0, 100,
        function() return Config.Aim.PredictionFactor * 100 end,
        function(v) Config.Aim.PredictionFactor = v / 100 end
    )
end

function UIController:CreateESPSettings()
    local section = self.Sections["ESP"]
    if not section then return end

    self:CreateToggle(section, "ESP Enabled",
        function() return Config.ESP.Enabled end,
        function(v) Config.ESP.Enabled = v end
    )

    self:CreateToggle(section, "Enemies Only",
        function() return Config.ESP.EnemyOnly end,
        function(v) Config.ESP.EnemyOnly = v end
    )

    self:CreateToggle(section, "Box",
        function() return Config.ESP.Box end,
        function(v) Config.ESP.Box = v end
    )

    self:CreateToggle(section, "Name",
        function() return Config.ESP.Name end,
        function(v) Config.ESP.Name = v end
    )

    self:CreateToggle(section, "Distance",
        function() return Config.ESP.Distance end,
        function(v) Config.ESP.Distance = v end
    )

    self:CreateToggle(section, "Health Bar",
        function() return Config.ESP.HealthBar end,
        function(v) Config.ESP.HealthBar = v end
    )

    self:CreateToggle(section, "Health Text",
        function() return Config.ESP.HealthText end,
        function(v) Config.ESP.HealthText = v end
    )

    self:CreateToggle(section, "Armor Text",
        function() return Config.ESP.ArmorText end,
        function(v) Config.ESP.ArmorText = v end
    )

    self:CreateToggle(section, "Weapon Info",
        function() return Config.ESP.WeaponInfo end,
        function(v) Config.ESP.WeaponInfo = v end
    )

    self:CreateToggle(section, "Tracer",
        function() return Config.ESP.Tracer end,
        function(v) Config.ESP.Tracer = v end
    )

    self:CreateDropdown(section, "Tracer Origin", {"Bottom", "Center", "Top"},
        function() return Config.ESP.TracerStart end,
        function(v) Config.ESP.TracerStart = v end
    )

    self:CreateToggle(section, "Skeleton",
        function() return Config.ESP.Skeleton end,
        function(v) Config.ESP.Skeleton = v end
    )

    self:CreateToggle(section, "Head Dot",
        function() return Config.ESP.HeadDot end,
        function(v) Config.ESP.HeadDot = v end
    )

    self:CreateToggle(section, "Team Colors",
        function() return Config.ESP.TeamColors end,
        function(v) Config.ESP.TeamColors = v end
    )

    self:CreateSlider(section, "ESP Distance", 100, 10000,
        function() return Config.ESP.MaxDistance end,
        function(v) Config.ESP.MaxDistance = v end
    )
end

function UIController:CreateFilterSettings()
    local section = self.Sections["FILTERS"]
    if not section then return end

    self:CreateToggle(section, "Team Check",
        function() return Config.Aim.TeamCheck end,
        function(v)
            Config.Aim.TeamCheck = v
            Config.ESP.EnemyOnly = v
        end
    )

    self:CreateToggle(section, "Wall Check",
        function() return Config.Aim.WallCheck end,
        function(v) Config.Aim.WallCheck = v end
    )
end

function UIController:CreateGeneralSettings()
    local section = self.Sections["SETTINGS"]
    if not section then return end

    local statusFrame = Utility:Create("Frame", {
        Size = UDim2.new(1, 0, 0, 80),
        BackgroundColor3 = Config.UI.HeaderColor,
        Parent = section
    })

    pcall(function()
        Utility:Create("UICorner", {
            CornerRadius = UDim.new(0, 8)
        }, statusFrame)
    end)

    local statusText = Utility:Create("TextLabel", {
        Size = UDim2.new(1, -16, 1, -8),
        Position = UDim2.new(0, 8, 0, 4),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Config.UI.TextColor,
        TextSize = 12,
        Font = Config.UI.Font,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Parent = statusFrame
    })

    task.spawn(function()
        while true do
            task.wait(0.5)
            pcall(function()
                if self.ScreenGui and self.ScreenGui.Parent then
                    statusText.Text = "TARGETS: " .. Config.Status.Targets ..
                        "\nAIM: " .. Config.Status.CurrentTarget ..
                        "\nTEAM: " .. Config.Status.CurrentTeam
                else
                    break
                end
            end)
        end
    end)
end

local Main = {}

function Main:Init()
    pcall(function()
        PlayerManager:Init()
    end)

    pcall(function()
        ESPController:Init()
    end)

    pcall(function()
        AimController:Init()
    end)

    pcall(function()
        UIController:Init()
    end)

    RunService.Heartbeat:Connect(function()
        pcall(function()
            PlayerManager:Update()
        end)
    end)

    Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        Camera = Workspace.CurrentCamera
    end)
end

Main:Init()

--[[
    NOVA ESP ONLY V8
    Black/white animated UI
    Fixed skeleton, chams, color/thickness/size
    Secret bonus tab
]]

local SCRIPT_KEY = "NovaEspOnlyV8"

pcall(function()
    local old = _G[SCRIPT_KEY .. "_Destroy"]
    if typeof(old) == "function" then
        old()
    end
end)

pcall(function()
    local oldKeys = {
        "DefuseFixV7_Destroy",
        "DefuseFixV6_Destroy",
        "NovaDefuseV5_Destroy",
        "DefuseFixUI_Destroy",
    }

    for _, key in ipairs(oldKeys) do
        local f = _G[key]
        if typeof(f) == "function" then
            f()
        end
    end
end)

local function cleanupOldGuis()
    local function removeGuis(parent)
        if not parent then
            return
        end

        for _, gui in ipairs(parent:GetChildren()) do
            if gui:IsA("ScreenGui") then
                if gui.Name:find("DefuseFix", 1, true) or gui.Name:find("NovaDefuse", 1, true) or gui.Name:find("NovaEspOnly", 1, true) then
                    gui:Destroy()
                end
            end
        end
    end

    pcall(function()
        removeGuis(LocalPlayer:WaitForChild("PlayerGui"))
    end)

    pcall(function()
        if typeof(gethui) == "function" then
            removeGuis(gethui())
        end
    end)
end

cleanupOldGuis()

local Context = { Connections = {}, destroyed = false }

local function track(c)
    table.insert(Context.Connections, c)
    return c
end

local CleanupFunction = nil

_G[SCRIPT_KEY .. "_Destroy"] = function()
    if CleanupFunction then
        pcall(CleanupFunction)
    end
end

-------------------------------------------------------------------------------
-- SERVICES
-------------------------------------------------------------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer

-------------------------------------------------------------------------------
-- CONFIG
-------------------------------------------------------------------------------
local Config = {
    ESP = {
        Enabled = true,
        TeamCheck = true,
        ShowTeammates = false,
        FullBox = true,
        Filled = true,
        Names = true,
        Health = true,
        Armor = true,
        Weapon = true,
        Distance = true,
        Skeleton = false,
        Chams = false,
        Tracers = false,
        Color = "Белый",
        Thickness = 2,
        Scale = 100,
    },

    Team = {
        Method = "Авто", -- Авто | Роблокс | Атрибуты | Теги | Всегда враг
    },

    Bonus = {
        F1 = false,
        F2 = false,
        F3 = false,
        F4 = false,
        F5 = false,
    },
}

local ESPColorPresets = {
    Белый = Color3.fromRGB(255, 255, 255),
    Чёрный = Color3.fromRGB(0, 0, 0),
    Красный = Color3.fromRGB(255, 80, 100),
    Голубой = Color3.fromRGB(0, 220, 255),
    Зелёный = Color3.fromRGB(90, 255, 150),
    Жёлтый = Color3.fromRGB(255, 220, 90),
}

local function getESPColor(relation)
    local base = ESPColorPresets[Config.ESP.Color] or Color3.fromRGB(255, 255, 255)

    if relation == "teammate" then
        return Color3.fromRGB(90, 255, 150)
    end

    return base
end

-------------------------------------------------------------------------------
-- UTILS
-------------------------------------------------------------------------------
local function clamp(v, min, max)
    if v < min then return min end
    if v > max then return max end
    return v
end

local function getCamera()
    return workspace.CurrentCamera
end

local function getCharacterData(player)
    local character = player and player.Character
    if not character then
        return { alive = false }
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
    local head = character:FindFirstChild("Head")
    local upperTorso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")

    local alive = humanoid ~= nil and root ~= nil and humanoid.Health > 0

    return {
        character = character,
        humanoid = humanoid,
        root = root,
        head = head,
        upperTorso = upperTorso,
        alive = alive,
    }
end

local function localAlive()
    return getCharacterData(LocalPlayer).alive
end

-------------------------------------------------------------------------------
-- TEAM ENGINE
-------------------------------------------------------------------------------
local Team = { valid = false, method = "Нет", values = {}, confidence = 0, lastScan = 0 }

local TeamKeywords = {
    "team","side","faction","force","attacker","defender","attack","defend",
    "terror","ct","special","defuse","squad","group","alliance","party"
}

local BadKeywords = {
    "health","hp","money","cash","coins","kill","death","score","ammo","clip",
    "skin","level","xp","speed","jump","crouch","ads","zoom","recoil","spread",
    "reload","ping","fps","bomb","c4","weapon","gun","equip","hold","selected",
    "mouse","input","camera","gui","ui","client"
}

local SkipContainers = {
    playergui = true,
    playerscripts = true,
    backpack = true,
    character = true,
    camera = true,
}

local function scoreName(name)
    local lower = tostring(name):lower()

    for _, bad in ipairs(BadKeywords) do
        if lower:find(bad, 1, true) then
            return -1
        end
    end

    for _, good in ipairs(TeamKeywords) do
        if lower:find(good, 1, true) then
            return 120
        end
    end

    return 0
end

local function valuePatternScore(value)
    local v = tostring(value):lower()

    if v == "ct" or v == "t" then return 140 end
    if v:find("attacker") or v:find("attack") then return 135 end
    if v:find("defender") or v:find("defend") then return 135 end
    if v:find("counter") or v:find("special") then return 135 end
    if v:find("terror") then return 135 end

    return 0
end

local function evaluateValues(values)
    local localValue = values[LocalPlayer]
    if localValue == nil then
        return false, 0, 0
    end

    local covered = 0
    local distinctSet = {}
    local distinctCount = 0

    for _, value in pairs(values) do
        covered = covered + 1
        if not distinctSet[value] then
            distinctSet[value] = true
            distinctCount = distinctCount + 1
        end
    end

    local playerCount = #Players:GetPlayers()
    local minCovered = math.max(2, math.floor(playerCount * 0.35))

    if covered < minCovered then return false, distinctCount, covered end
    if distinctCount < 2 or distinctCount > 8 then return false, distinctCount, covered end
    if covered > 4 and distinctCount == covered then return false, distinctCount, covered end

    return true, distinctCount, covered
end

local function addCandidate(candidates, key, player, value)
    if typeof(value) == "Instance" then
        value = value.Name
    end

    local valueType = typeof(value)
    if valueType ~= "string" and valueType ~= "number" and valueType ~= "boolean" then
        return
    end

    local normalized = tostring(value):lower()
    if normalized == "" or normalized == "nil" then
        return
    end

    local keyScore = scoreName(key)
    if keyScore < 0 then
        return
    end

    local patternScore = valuePatternScore(normalized)
    local finalScore = math.max(keyScore, patternScore)

    if finalScore <= 0 then
        return
    end

    if not candidates[key] then
        candidates[key] = { score = finalScore, values = {} }
    end

    if finalScore > candidates[key].score then
        candidates[key].score = finalScore
    end

    candidates[key].values[player] = normalized
end

local function scanContainer(container, player, candidates, depth, counter, scanAttrs, scanVals)
    if not container or depth > 3 or counter.n > 800 then
        return
    end

    counter.n = counter.n + 1

    if scanAttrs then
        local okAttrs, attributes = pcall(function()
            return container:GetAttributes()
        end)

        if okAttrs and typeof(attributes) == "table" then
            for name, value in pairs(attributes) do
                addCandidate(candidates, "attr:" .. name, player, value)
            end
        end
    end

    local okChildren, children = pcall(function()
        return container:GetChildren()
    end)

    if not okChildren then
        return
    end

    for _, child in ipairs(children) do
        if counter.n > 800 then
            break
        end

        counter.n = counter.n + 1
        local lower = child.Name:lower()

        if not SkipContainers[lower] then
            if scanVals and child:IsA("ValueBase") then
                local okValue, value = pcall(function()
                    return child.Value
                end)

                if okValue then
                    addCandidate(candidates, "value:" .. child.Name, player, value)
                end
            end

            if depth < 3 then
                local shouldRecurse = false

                if child:IsA("Folder") or child:IsA("Configuration") then
                    shouldRecurse = true
                elseif child:IsA("Model") then
                    if lower:find("data") or lower:find("team") or lower:find("state") or lower:find("game") then
                        shouldRecurse = true
                    end
                end

                if shouldRecurse then
                    scanContainer(child, player, candidates, depth + 1, counter, scanAttrs, scanVals)
                end
            end
        end
    end
end

local function scanTagsInto(candidates)
    for _, player in ipairs(Players:GetPlayers()) do
        local instances = { player, player.Character }

        if player.Character then
            table.insert(instances, player.Character:FindFirstChild("HumanoidRootPart") or player.Character:FindFirstChild("Torso"))
            table.insert(instances, player.Character:FindFirstChild("Head"))
        end

        for _, instance in ipairs(instances) do
            if instance then
                local okTags, tags = pcall(function()
                    return CollectionService:GetTags(instance)
                end)

                if okTags and typeof(tags) == "table" then
                    for _, tag in ipairs(tags) do
                        addCandidate(candidates, "tag:" .. tostring(tag), player, tag)
                    end
                end
            end
        end
    end
end

local function scanTeams(force)
    if Context.destroyed then
        return
    end

    local now = os.clock()
    if not force and now - Team.lastScan < 0.8 then
        return
    end

    Team.lastScan = now

    local method = Config.Team.Method

    if method == "Всегда враг" then
        Team.valid = false
        Team.method = "Всегда враг"
        Team.values = {}
        Team.confidence = 0
        return
    end

    local best = nil

    local function consider(methodName, values, baseScore)
        local valid, distinctCount, covered = evaluateValues(values)
        if not valid then
            return
        end

        local confidence = baseScore + distinctCount * 8 + covered * 3

        if distinctCount == 2 then
            confidence = confidence + 25
        end

        if not best or confidence > best.confidence then
            best = {
                method = methodName,
                values = values,
                confidence = confidence,
            }
        end
    end

    if method == "Авто" or method == "Роблокс" then
        local robloxValues = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Team then
                robloxValues[player] = tostring(player.Team) .. "|" .. tostring(player.TeamColor)
            end
        end
        consider("Роблокс", robloxValues, 260)

        local colorValues = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player.TeamColor then
                colorValues[player] = tostring(player.TeamColor)
            end
        end
        consider("Цвет", colorValues, 120)
    end

    if method == "Авто" or method == "Атрибуты" or method == "Теги" then
        local candidates = {}

        if method == "Авто" or method == "Атрибуты" then
            for _, player in ipairs(Players:GetPlayers()) do
                scanContainer(player, player, candidates, 0, { n = 0 }, true, true)

                if player.Character then
                    scanContainer(player.Character, player, candidates, 0, { n = 0 }, true, true)
                end
            end
        end

        if method == "Авто" or method == "Теги" then
            scanTagsInto(candidates)
        end

        for key, candidate in pairs(candidates) do
            local prefix = key:match("^(%w+):")
            local candidateMethod = nil

            if prefix == "attr" or prefix == "value" then
                candidateMethod = "Атрибуты"
            elseif prefix == "tag" then
                candidateMethod = "Теги"
            end

            if candidateMethod and (method == "Авто" or method == candidateMethod) then
                consider(candidateMethod, candidate.values, candidate.score)
            end
        end
    end

    local threshold = method == "Авто" and 120 or 90

    if best and best.confidence >= threshold then
        Team.valid = true
        Team.method = best.method
        Team.values = best.values
        Team.confidence = best.confidence
    else
        Team.valid = false
        Team.method = best and best.method or "Нет"
        Team.values = best and best.values or {}
        Team.confidence = best and best.confidence or 0
    end
end

local function getRelation(player)
    if player == LocalPlayer then
        return "teammate"
    end

    if Config.Team.Method == "Всегда враг" then
        return "enemy"
    end

    if not Team.valid then
        return "unknown"
    end

    local myValue = Team.values[LocalPlayer]
    local theirValue = Team.values[player]

    if myValue ~= nil and theirValue ~= nil then
        return myValue == theirValue and "teammate" or "enemy"
    end

    return "unknown"
end

local function shouldShowESP(player)
    if not Config.ESP.Enabled then
        return false
    end

    if player == LocalPlayer then
        return false
    end

    if Config.ESP.TeamCheck then
        local relation = getRelation(player)

        if relation == "teammate" and not Config.ESP.ShowTeammates then
            return false
        end
    end

    return true
end

-------------------------------------------------------------------------------
-- TEAM EVENTS
-------------------------------------------------------------------------------
local function hookPlayerTeamEvents(player)
    pcall(function()
        player:GetPropertyChangedSignal("Team"):Connect(function()
            Team.lastScan = 0
        end)

        player:GetPropertyChangedSignal("TeamColor"):Connect(function()
            Team.lastScan = 0
        end)

        player.CharacterAdded:Connect(function()
            task.delay(0.4, function()
                Team.lastScan = 0
            end)
        end)
    end)
end

for _, player in ipairs(Players:GetPlayers()) do
    hookPlayerTeamEvents(player)
end

track(Players.PlayerAdded:Connect(function(player)
    hookPlayerTeamEvents(player)
    task.delay(0.25, function()
        pcall(scanTeams, true)
    end)
end))

track(Players.PlayerRemoving:Connect(function(player)
    task.delay(0.1, function()
        pcall(scanTeams, true)
    end)
end))

pcall(function()
    track(LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function()
        Team.lastScan = 0
    end))

    track(LocalPlayer:GetPropertyChangedSignal("TeamColor"):Connect(function()
        Team.lastScan = 0
    end))
end)

task.spawn(function()
    while not Context.destroyed do
        pcall(scanTeams, false)
        task.wait(0.8)
    end
end)

task.delay(0.4, function()
    pcall(scanTeams, true)
end)

-------------------------------------------------------------------------------
-- ESP DRAWING
-------------------------------------------------------------------------------
local DRAWING_OK = typeof(Drawing) == "table"
local ESPObjects = {}
local BonusObjects = {}
local ArmorCache = {}
local WeaponCache = {}
local ChamsObjects = {}
local TrailCache = {}

local function ensureDraw(player, key, class)
    if not DRAWING_OK then
        return nil
    end

    if not ESPObjects[player] then
        ESPObjects[player] = {}
    end

    if not ESPObjects[player][key] then
        pcall(function()
            ESPObjects[player][key] = Drawing.new(class)
        end)
    end

    return ESPObjects[player][key]
end

local function ensureBonus(key, class)
    if not DRAWING_OK then
        return nil
    end

    if not BonusObjects[key] then
        pcall(function()
            BonusObjects[key] = Drawing.new(class)
        end)
    end

    return BonusObjects[key]
end

local function setDraw(object, properties)
    if not object then
        return
    end

    for key, value in pairs(properties) do
        pcall(function()
            object[key] = value
        end)
    end
end

local function hideKey(player, key)
    local objects = ESPObjects[player]
    if not objects then
        return
    end

    local object = objects[key]
    if object then
        pcall(function()
            object.Visible = false
        end)
    end
end

local function hideBonus(key)
    local object = BonusObjects[key]
    if object then
        pcall(function()
            object.Visible = false
        end)
    end
end

local function hideAll(player)
    local objects = ESPObjects[player]
    if not objects then
        return
    end

    for _, object in pairs(objects) do
        pcall(function()
            object.Visible = false
        end)
    end
end

local function destroyPlayerESP(player)
    local objects = ESPObjects[player]
    if objects then
        for _, object in pairs(objects) do
            pcall(function()
                object:Remove()
            end)
        end
    end

    ESPObjects[player] = nil
    ArmorCache[player] = nil
    WeaponCache[player] = nil
    TrailCache[player] = nil

    local hl = ChamsObjects[player]
    if hl then
        pcall(function()
            hl:Destroy()
        end)
        ChamsObjects[player] = nil
    end
end

track(Players.PlayerRemoving:Connect(function(player)
    destroyPlayerESP(player)
end))

local function getBounds(player, camera, data)
    if not data or not data.alive or not data.root then
        return nil
    end

    local topWorld = data.root.Position + Vector3.new(0, 2.5, 0)

    if data.head then
        topWorld = data.head.Position + Vector3.new(0, 0.55, 0)
    end

    local bottomWorld = data.root.Position - Vector3.new(0, 3.2, 0)

    local topScreen, topVisible = camera:WorldToViewportPoint(topWorld)
    local bottomScreen, bottomVisible = camera:WorldToViewportPoint(bottomWorld)
    local rootScreen, rootVisible = camera:WorldToViewportPoint(data.root.Position)

    if topScreen.Z <= 0 and bottomScreen.Z <= 0 and rootScreen.Z <= 0 then
        return nil
    end

    if not topVisible and not bottomVisible and not rootVisible then
        return nil
    end

    local viewport = camera.ViewportSize
    local cameraFOV = clamp(camera.FieldOfView or 70, 10, 120)

    local worldHeight = (topWorld - bottomWorld).Magnitude
    local distance = math.max((data.root.Position - camera.CFrame.Position).Magnitude, 1)

    local expected = (worldHeight / distance) * (viewport.Y / (2 * math.tan(math.rad(cameraFOV) / 2)))
    expected = clamp(expected, 6, viewport.Y * 0.95)

    local height = expected
    local centerX = rootScreen.X
    local centerY = rootScreen.Y

    if topVisible and bottomVisible then
        height = math.abs(bottomScreen.Y - topScreen.Y)
        centerX = (topScreen.X + bottomScreen.X) / 2
        centerY = (topScreen.Y + bottomScreen.Y) / 2

        if height > expected * 2.75 then
            height = expected
        end
    elseif topVisible then
        centerX = topScreen.X
        centerY = topScreen.Y + expected / 2
    elseif bottomVisible then
        centerX = bottomScreen.X
        centerY = bottomScreen.Y - expected / 2
    end

    height = clamp(height, 6, viewport.Y * 0.95)

    local scale = clamp(Config.ESP.Scale / 100, 0.5, 1.5)
    local width = height * 0.52 * scale
    height = height * scale

    return {
        x = centerX - width / 2,
        y = centerY - height / 2,
        w = width,
        h = height,
        centerX = centerX,
        topY = centerY - height / 2,
        bottomY = centerY + height / 2,
    }
end

local function getArmor(player)
    local cached = ArmorCache[player]
    if cached and os.clock() - cached.t < 0.4 then
        return cached.v
    end

    local value = 0

    local function scanInstance(instance)
        if not instance then
            return
        end

        local ok, attrs = pcall(function()
            return instance:GetAttributes()
        end)

        if ok and typeof(attrs) == "table" then
            for k, v in pairs(attrs) do
                local lower = k:lower()
                if lower:find("armor") or lower:find("armour") or lower:find("ap") then
                    local num = tonumber(v)
                    if num then
                        value = math.max(value, num)
                    end
                end
            end
        end

        local okChildren, children = pcall(function()
            return instance:GetChildren()
        end)

        if okChildren then
            for _, child in ipairs(children) do
                if child:IsA("ValueBase") then
                    local lower = child.Name:lower()
                    if lower:find("armor") or lower:find("armour") or lower:find("ap") then
                        local okValue, val = pcall(function()
                            return child.Value
                        end)

                        if okValue then
                            local num = tonumber(val)
                            if num then
                                value = math.max(value, num)
                            end
                        end
                    end
                end
            end
        end
    end

    scanInstance(player)
    scanInstance(player.Character)

    ArmorCache[player] = { t = os.clock(), v = value }
    return value
end

local function getWeapon(player)
    local cached = WeaponCache[player]
    if cached and os.clock() - cached.t < 0.4 then
        return cached.v
    end

    local value = ""

    local character = player.Character
    local tool = character and character:FindFirstChildOfClass("Tool")

    if tool then
        value = tool.Name
    else
        local backpack = player:FindFirstChildOfClass("Backpack")
        if backpack then
            local t = backpack:FindFirstChildOfClass("Tool")
            if t then
                value = t.Name
            end
        end
    end

    if value == "" then
        local function scanInstance(instance)
            if not instance then
                return
            end

            local ok, attrs = pcall(function()
                return instance:GetAttributes()
            end)

            if ok and typeof(attrs) == "table" then
                for k, v in pairs(attrs) do
                    local lower = k:lower()
                    if lower:find("weapon") or lower:find("gun") then
                        value = tostring(v)
                    end
                end
            end
        end

        scanInstance(player)
        scanInstance(character)
    end

    WeaponCache[player] = { t = os.clock(), v = value }
    return value
end

local function updateChams()
    if not Config.ESP.Chams then
        for player, hl in pairs(ChamsObjects) do
            pcall(function()
                hl.Enabled = false
            end)
        end
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local data = getCharacterData(player)
            local show = shouldShowESP(player) and data.alive and data.character

            local hl = ChamsObjects[player]

            if show then
                if not hl or hl.Parent == nil then
                    pcall(function()
                        hl = Instance.new("Highlight")
                        hl.Name = "NovaCham"
                        hl.Adornee = data.character
                        hl.Parent = data.character
                        ChamsObjects[player] = hl
                    end)
                end

                if hl then
                    local relation = getRelation(player)
                    local color = getESPColor(relation)

                    pcall(function()
                        hl.Enabled = true
                        hl.Adornee = data.character
                        hl.FillColor = color
                        hl.OutlineColor = color
                        hl.FillTransparency = 0.65
                        hl.OutlineTransparency = 0
                        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    end)
                end
            else
                if hl then
                    pcall(function()
                        hl.Enabled = false
                    end)
                end
            end
        end
    end
end

local function drawSkeleton(player, camera, data, color, thickness, opacity)
    if not Config.ESP.Skeleton then
        for i = 1, 14 do
            hideKey(player, "Skel" .. i)
        end
        return
    end

    if not data or not data.alive or not data.character then
        for i = 1, 14 do
            hideKey(player, "Skel" .. i)
        end
        return
    end

    local character = data.character

    local bones = {}

    if character:FindFirstChild("UpperTorso") then
        bones = {
            { "Head", "UpperTorso" },
            { "UpperTorso", "LowerTorso" },
            { "UpperTorso", "LeftUpperArm" },
            { "LeftUpperArm", "LeftLowerArm" },
            { "UpperTorso", "RightUpperArm" },
            { "RightUpperArm", "RightLowerArm" },
            { "LowerTorso", "LeftUpperLeg" },
            { "LeftUpperLeg", "LeftLowerLeg" },
            { "LowerTorso", "RightUpperLeg" },
            { "RightUpperLeg", "RightLowerLeg" },
        }
    else
        bones = {
            { "Head", "Torso" },
            { "Torso", "Left Arm" },
            { "Torso", "Right Arm" },
            { "Torso", "Left Leg" },
            { "Torso", "Right Leg" },
        }
    end

    for i, bonePair in ipairs(bones) do
        local partA = character:FindFirstChild(bonePair[1])
        local partB = character:FindFirstChild(bonePair[2])

        local line = ensureDraw(player, "Skel" .. i, "Line")

        if partA and partB then
            local screenA, visA = camera:WorldToViewportPoint(partA.Position)
            local screenB, visB = camera:WorldToViewportPoint(partB.Position)

            if visA and visB and screenA.Z > 0 and screenB.Z > 0 then
                setDraw(line, {
                    Visible = true,
                    From = Vector2.new(screenA.X, screenA.Y),
                    To = Vector2.new(screenB.X, screenB.Y),
                    Color = color,
                    Thickness = thickness,
                    Transparency = opacity,
                })
            else
                setDraw(line, { Visible = false })
            end
        else
            setDraw(line, { Visible = false })
        end
    end

    for i = #bones + 1, 14 do
        hideKey(player, "Skel" .. i)
    end
end

local function updateESP()
    if not Config.ESP.Enabled or not DRAWING_OK then
        for _, player in ipairs(Players:GetPlayers()) do
            hideAll(player)
        end
        return
    end

    local camera = getCamera()
    if not camera then
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local data = getCharacterData(player)
            local show = shouldShowESP(player) and data.alive

            if not show then
                hideAll(player)
            else
                local bounds = getBounds(player, camera, data)

                if not bounds then
                    hideAll(player)
                else
                    local relation = getRelation(player)
                    local color = getESPColor(relation)

                    local thickness = clamp(Config.ESP.Thickness, 1, 5)
                    local opacity = 0.95

                    if Config.ESP.FullBox then
                        local outline = ensureDraw(player, "Box", "Square")
                        setDraw(outline, {
                            Visible = true,
                            Position = Vector2.new(bounds.x, bounds.y),
                            Size = Vector2.new(bounds.w, bounds.h),
                            Color = color,
                            Thickness = thickness,
                            Filled = false,
                            Transparency = opacity,
                        })

                        if Config.ESP.Filled then
                            local fill = ensureDraw(player, "Fill", "Square")
                            setDraw(fill, {
                                Visible = true,
                                Position = Vector2.new(bounds.x, bounds.y),
                                Size = Vector2.new(bounds.w, bounds.h),
                                Color = color,
                                Filled = true,
                                Thickness = 1,
                                Transparency = 0.08,
                            })
                        else
                            hideKey(player, "Fill")
                        end
                    else
                        hideKey(player, "Box")
                        hideKey(player, "Fill")
                    end

                    if Config.ESP.Names then
                        local name = ensureDraw(player, "Name", "Text")
                        setDraw(name, {
                            Visible = true,
                            Text = player.Name,
                            Position = Vector2.new(bounds.centerX, bounds.topY - 16),
                            Color = color,
                            Size = 12,
                            Center = true,
                            Transparency = opacity,
                        })
                    else
                        hideKey(player, "Name")
                    end

                    if Config.ESP.Distance then
                        local distance = math.floor((data.root.Position - camera.CFrame.Position).Magnitude)
                        local distanceText = ensureDraw(player, "Distance", "Text")
                        setDraw(distanceText, {
                            Visible = true,
                            Text = distance .. "m",
                            Position = Vector2.new(bounds.centerX, bounds.bottomY + 3),
                            Color = Color3.fromRGB(230, 230, 230),
                            Size = 11,
                            Center = true,
                            Transparency = opacity,
                        })
                    else
                        hideKey(player, "Distance")
                    end

                    local barX = bounds.x - 6

                    if Config.ESP.Health and data.humanoid then
                        local fraction = clamp(data.humanoid.Health / math.max(data.humanoid.MaxHealth, 1), 0, 1)

                        local healthBackground = ensureDraw(player, "HealthBG", "Line")
                        setDraw(healthBackground, {
                            Visible = true,
                            From = Vector2.new(barX, bounds.topY),
                            To = Vector2.new(barX, bounds.bottomY),
                            Color = Color3.new(0, 0, 0),
                            Thickness = 3,
                            Transparency = 0.65,
                        })

                        local healthColor = Color3.fromRGB(255, 90, 90):Lerp(Color3.fromRGB(90, 255, 140), fraction)
                        local healthBar = ensureDraw(player, "HealthBar", "Line")
                        setDraw(healthBar, {
                            Visible = true,
                            From = Vector2.new(barX, bounds.bottomY),
                            To = Vector2.new(barX, bounds.bottomY - bounds.h * fraction),
                            Color = healthColor,
                            Thickness = 2,
                            Transparency = opacity,
                        })
                    else
                        hideKey(player, "HealthBG")
                        hideKey(player, "HealthBar")
                    end

                    if Config.ESP.Armor then
                        local armor = getArmor(player)

                        if armor > 0 then
                            local armorX = bounds.x - 11
                            local armorFraction = clamp(armor / 100, 0, 1)

                            local armorBackground = ensureDraw(player, "ArmorBG", "Line")
                            setDraw(armorBackground, {
                                Visible = true,
                                From = Vector2.new(armorX, bounds.topY),
                                To = Vector2.new(armorX, bounds.bottomY),
                                Color = Color3.new(0, 0, 0),
                                Thickness = 3,
                                Transparency = 0.65,
                            })

                            local armorBar = ensureDraw(player, "ArmorBar", "Line")
                            setDraw(armorBar, {
                                Visible = true,
                                From = Vector2.new(armorX, bounds.bottomY),
                                To = Vector2.new(armorX, bounds.bottomY - bounds.h * armorFraction),
                                Color = Color3.fromRGB(90, 180, 255),
                                Thickness = 2,
                                Transparency = opacity,
                            })
                        else
                            hideKey(player, "ArmorBG")
                            hideKey(player, "ArmorBar")
                        end
                    else
                        hideKey(player, "ArmorBG")
                        hideKey(player, "ArmorBar")
                    end

                    if Config.ESP.Weapon then
                        local weapon = getWeapon(player)

                        if weapon ~= "" then
                            local weaponText = ensureDraw(player, "Weapon", "Text")
                            setDraw(weaponText, {
                                Visible = true,
                                Text = weapon,
                                Position = Vector2.new(bounds.x + bounds.w + 6, bounds.topY),
                                Color = Color3.fromRGB(230, 230, 230),
                                Size = 11,
                                Center = false,
                                Transparency = opacity,
                            })
                        else
                            hideKey(player, "Weapon")
                        end
                    else
                        hideKey(player, "Weapon")
                    end

                    drawSkeleton(player, camera, data, color, thickness, opacity)

                    if Config.ESP.Tracers then
                        local tracer = ensureDraw(player, "Tracer", "Line")
                        setDraw(tracer, {
                            Visible = true,
                            From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y),
                            To = Vector2.new(bounds.centerX, bounds.bottomY),
                            Color = color,
                            Thickness = 1,
                            Transparency = 0.55,
                        })
                    else
                        hideKey(player, "Tracer")
                    end
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- BONUS FEATURES
-------------------------------------------------------------------------------
local function updateBonus()
    if not DRAWING_OK then
        return
    end

    local camera = getCamera()
    if not camera then
        return
    end

    local viewport = camera.ViewportSize

    -- F1
    if Config.Bonus.F1 then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local data = getCharacterData(player)
                local show = shouldShowESP(player) and data.alive and data.root

                local arrow = ensureDraw(player, "OffArrow", "Text")

                if show then
                    local screen, onScreen = camera:WorldToViewportPoint(data.root.Position)

                    if screen.Z > 0 and not onScreen then
                        local margin = 28
                        local x = clamp(screen.X, margin, viewport.X - margin)
                        local y = clamp(screen.Y, margin, viewport.Y - margin)

                        local dx = screen.X - viewport.X / 2
                        local dy = screen.Y - viewport.Y / 2

                        local symbol = "•"

                        if math.abs(dx) > math.abs(dy) then
                            symbol = dx > 0 and "▶" or "◀"
                        else
                            symbol = dy > 0 and "▼" or "▲"
                        end

                        local relation = getRelation(player)
                        local color = getESPColor(relation)

                        setDraw(arrow, {
                            Visible = true,
                            Text = symbol,
                            Position = Vector2.new(x, y),
                            Color = color,
                            Size = 16,
                            Center = true,
                            Transparency = 0.9,
                        })
                    else
                        setDraw(arrow, { Visible = false })
                    end
                else
                    setDraw(arrow, { Visible = false })
                end
            end
        end
    else
        for _, player in ipairs(Players:GetPlayers()) do
            hideKey(player, "OffArrow")
        end
    end

    -- F2
    if Config.Bonus.F2 then
        local localData = getCharacterData(LocalPlayer)

        if localData.alive and localData.root then
            local radarSize = 120
            local radarPos = Vector2.new(viewport.X - radarSize - 10, 10)
            local radarCenter = radarPos + Vector2.new(radarSize / 2, radarSize / 2)
            local range = 200

            local bg = ensureBonus("RadarBG", "Square")
            setDraw(bg, {
                Visible = true,
                Position = radarPos,
                Size = Vector2.new(radarSize, radarSize),
                Color = Color3.fromRGB(0, 0, 0),
                Filled = true,
                Transparency = 0.35,
            })

            local border = ensureBonus("RadarBorder", "Square")
            setDraw(border, {
                Visible = true,
                Position = radarPos,
                Size = Vector2.new(radarSize, radarSize),
                Color = Color3.fromRGB(255, 255, 255),
                Thickness = 1,
                Filled = false,
                Transparency = 0.8,
            })

            local selfDot = ensureBonus("RadarSelf", "Circle")
            setDraw(selfDot, {
                Visible = true,
                Position = radarCenter,
                Radius = 3,
                Color = Color3.fromRGB(255, 255, 255),
                Filled = true,
                Transparency = 0.95,
            })

            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    local data = getCharacterData(player)
                    local show = shouldShowESP(player) and data.alive and data.root

                    local dot = ensureDraw(player, "RadarDot", "Circle")

                    if show then
                        local rel = camera.CFrame:PointToObjectSpace(data.root.Position)
                        local x = rel.X
                        local y = -rel.Z

                        local scale = (radarSize / 2) / range
                        local dotVector = Vector2.new(x * scale, y * scale)

                        if dotVector.Magnitude > radarSize / 2 - 5 then
                            dotVector = dotVector.Unit * (radarSize / 2 - 5)
                        end

                        local relation = getRelation(player)
                        local color = getESPColor(relation)

                        setDraw(dot, {
                            Visible = true,
                            Position = radarCenter + dotVector,
                            Radius = 2.5,
                            Color = color,
                            Filled = true,
                            Transparency = 0.9,
                        })
                    else
                        setDraw(dot, { Visible = false })
                    end
                end
            end
        else
            hideBonus("RadarBG")
            hideBonus("RadarBorder")
            hideBonus("RadarSelf")

            for _, player in ipairs(Players:GetPlayers()) do
                hideKey(player, "RadarDot")
            end
        end
    else
        hideBonus("RadarBG")
        hideBonus("RadarBorder")
        hideBonus("RadarSelf")

        for _, player in ipairs(Players:GetPlayers()) do
            hideKey(player, "RadarDot")
        end
    end

    -- F3
    if Config.Bonus.F3 then
        local localData = getCharacterData(LocalPlayer)
        local danger = false

        if localData.alive and localData.root then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    local data = getCharacterData(player)

                    if data.alive and data.root and shouldShowESP(player) then
                        local dist = (data.root.Position - localData.root.Position).Magnitude

                        if dist < 35 then
                            danger = true
                            break
                        end
                    end
                end
            end
        end

        local border = ensureBonus("DangerBorder", "Square")

        if danger then
            local pulse = 0.25 + math.abs(math.sin(os.clock() * 3)) * 0.35

            setDraw(border, {
                Visible = true,
                Position = Vector2.new(0, 0),
                Size = viewport,
                Color = Color3.fromRGB(255, 60, 70),
                Thickness = 6,
                Filled = false,
                Transparency = pulse,
            })
        else
            setDraw(border, { Visible = false })
        end
    else
        hideBonus("DangerBorder")
    end

    -- F4
    if Config.Bonus.F4 then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local data = getCharacterData(player)
                local show = shouldShowESP(player) and data.alive and data.head

                local dot = ensureDraw(player, "HeadDot", "Circle")

                if show then
                    local screen, onScreen = camera:WorldToViewportPoint(data.head.Position)

                    if onScreen and screen.Z > 0 then
                        local relation = getRelation(player)
                        local color = getESPColor(relation)

                        setDraw(dot, {
                            Visible = true,
                            Position = Vector2.new(screen.X, screen.Y),
                            Radius = 5,
                            Color = color,
                            Thickness = 1.5,
                            Filled = false,
                            Transparency = 0.9,
                        })
                    else
                        setDraw(dot, { Visible = false })
                    end
                else
                    setDraw(dot, { Visible = false })
                end
            end
        end
    else
        for _, player in ipairs(Players:GetPlayers()) do
            hideKey(player, "HeadDot")
        end
    end

    -- F5
    if Config.Bonus.F5 then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local data = getCharacterData(player)
                local show = shouldShowESP(player) and data.alive and data.root

                if show then
                    local screen, onScreen = camera:WorldToViewportPoint(data.root.Position)

                    if onScreen and screen.Z > 0 then
                        local trail = TrailCache[player] or {}

                        table.insert(trail, 1, Vector2.new(screen.X, screen.Y))

                        if #trail > 6 then
                            table.remove(trail)
                        end

                        TrailCache[player] = trail

                        local relation = getRelation(player)
                        local color = getESPColor(relation)

                        for i = 1, #trail - 1 do
                            local line = ensureDraw(player, "Trail" .. i, "Line")

                            setDraw(line, {
                                Visible = true,
                                From = trail[i],
                                To = trail[i + 1],
                                Color = color,
                                Thickness = 1,
                                Transparency = 0.35,
                            })
                        end

                        for i = #trail, 5 do
                            hideKey(player, "Trail" .. i)
                        end
                    else
                        TrailCache[player] = nil

                        for i = 1, 5 do
                            hideKey(player, "Trail" .. i)
                        end
                    end
                else
                    TrailCache[player] = nil

                    for i = 1, 5 do
                        hideKey(player, "Trail" .. i)
                    end
                end
            end
        end
    else
        for _, player in ipairs(Players:GetPlayers()) do
            TrailCache[player] = nil

            for i = 1, 5 do
                hideKey(player, "Trail" .. i)
            end
        end
    end
end

track(RunService.RenderStepped:Connect(function()
    pcall(updateESP)
    pcall(updateChams)
    pcall(updateBonus)
end))

-------------------------------------------------------------------------------
-- UI
-------------------------------------------------------------------------------
local guiParent = LocalPlayer:WaitForChild("PlayerGui")

pcall(function()
    if typeof(gethui) == "function" then
        local h = gethui()
        if h then
            guiParent = h
        end
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = SCRIPT_KEY
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999999
ScreenGui.IgnoreGuiInset = true

local okParent = pcall(function()
    ScreenGui.Parent = guiParent
end)

if not okParent then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local Theme = {
    BG = Color3.fromRGB(5, 5, 5),
    Panel = Color3.fromRGB(14, 14, 14),
    PanelLight = Color3.fromRGB(24, 24, 24),
    Accent = Color3.fromRGB(255, 255, 255),
    Text = Color3.fromRGB(240, 240, 240),
    Dim = Color3.fromRGB(120, 120, 120),
    Off = Color3.fromRGB(32, 32, 32),
}

local isMenuOpen = true
local menuTween = nil

local function addCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 10)
    corner.Parent = parent
    return corner
end

local function addStroke(parent, color, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Color3.fromRGB(30, 30, 30)
    stroke.Thickness = thickness or 1
    stroke.Parent = parent
    return stroke
end

local MainFrame = Instance.new("Frame")
MainFrame.BackgroundColor3 = Theme.BG
MainFrame.BackgroundTransparency = 0.02
MainFrame.BorderSizePixel = 0
MainFrame.Visible = true
MainFrame.Active = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
addCorner(MainFrame, 14)
addStroke(MainFrame, Color3.fromRGB(40, 40, 40), 1)

-- animated background
local Scanline = Instance.new("Frame")
Scanline.Size = UDim2.new(1, 0, 0, 2)
Scanline.Position = UDim2.new(0, 0, 0, 0)
Scanline.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Scanline.BackgroundTransparency = 0.88
Scanline.BorderSizePixel = 0
Scanline.ZIndex = 0
Scanline.Parent = MainFrame

task.spawn(function()
    while not Context.destroyed do
        if isMenuOpen then
            Scanline.Position = UDim2.new(0, 0, 0, 0)

            local tween = TweenService:Create(Scanline, TweenInfo.new(2.4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {
                Position = UDim2.new(0, 0, 1, 0),
            })

            tween:Play()
            tween.Completed:Wait()
        else
            task.wait(0.4)
        end
    end
end)

local function getMenuSize()
    local camera = getCamera()
    local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)

    local size = math.min(viewport.X * 0.88, viewport.Y * 0.78, 420)
    size = math.max(size, 300)

    return size
end

local function updateUISize()
    local size = getMenuSize()
    MainFrame.Size = UDim2.fromOffset(size, size)

    if isMenuOpen then
        MainFrame.Position = UDim2.new(0.5, -size / 2, 0.5, -size / 2)
    end
end

updateUISize()

pcall(function()
    track(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        task.defer(updateUISize)
    end))
end)

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 38)
Header.BackgroundColor3 = Theme.Panel
Header.BorderSizePixel = 0
Header.ZIndex = 2
Header.Parent = MainFrame
addCorner(Header, 14)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -70, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "NOVA ESP"
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 14
Title.TextColor3 = Theme.Accent
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 3
Title.Parent = Header

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.fromOffset(26, 26)
CloseButton.Position = UDim2.new(1, -34, 0.5, -13)
CloseButton.BackgroundColor3 = Theme.PanelLight
CloseButton.Text = "×"
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextSize = 14
CloseButton.TextColor3 = Theme.Text
CloseButton.BorderSizePixel = 0
CloseButton.ZIndex = 5
CloseButton.Parent = Header
addCorner(CloseButton, 8)

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 54, 1, -74)
Sidebar.Position = UDim2.new(0, 8, 0, 46)
Sidebar.BackgroundColor3 = Theme.Panel
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 2
Sidebar.Parent = MainFrame
addCorner(Sidebar, 12)

local SidebarLayout = Instance.new("UIListLayout")
SidebarLayout.FillDirection = Enum.FillDirection.Vertical
SidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
SidebarLayout.VerticalAlignment = Enum.VerticalAlignment.Top
SidebarLayout.Padding = UDim.new(0, 6)
SidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
SidebarLayout.Parent = Sidebar

local SidebarPadding = Instance.new("UIPadding")
SidebarPadding.PaddingTop = UDim.new(0, 8)
SidebarPadding.Parent = Sidebar

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -74, 1, -74)
Content.Position = UDim2.new(0, 68, 0, 46)
Content.BackgroundTransparency = 1
Content.ZIndex = 2
Content.Parent = MainFrame

local Footer = Instance.new("Frame")
Footer.Size = UDim2.new(1, -16, 0, 20)
Footer.Position = UDim2.new(0, 8, 1, -28)
Footer.BackgroundColor3 = Theme.Panel
Footer.BorderSizePixel = 0
Footer.ZIndex = 2
Footer.Parent = MainFrame
addCorner(Footer, 8)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -12, 1, 0)
StatusLabel.Position = UDim2.new(0, 6, 0, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "team: none"
StatusLabel.Font = Enum.Font.SourceSans
StatusLabel.TextSize = 10
StatusLabel.TextColor3 = Theme.Dim
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.ZIndex = 3
StatusLabel.Parent = Footer

local Pages = {}
local TabButtons = {}

local function setupPage(id)
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 2
    page.ScrollBarImageColor3 = Theme.Accent
    page.CanvasSize = UDim2.new()
    page.Visible = false
    page.ZIndex = 2
    page.Parent = Content

    pcall(function()
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    end)

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 2)
    padding.PaddingBottom = UDim.new(0, 10)
    padding.PaddingLeft = UDim.new(0, 1)
    padding.PaddingRight = UDim.new(0, 1)
    padding.Parent = page

    local function updateCanvas()
        pcall(function()
            page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
        end)
    end

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
    task.defer(updateCanvas)

    Pages[id] = page
    return page
end

local function setPage(id)
    for name, page in pairs(Pages) do
        page.Visible = name == id
    end

    for name, button in pairs(TabButtons) do
        if name == id then
            button.BackgroundColor3 = Theme.Accent
            button.TextColor3 = Color3.fromRGB(0, 0, 0)
        else
            button.BackgroundColor3 = Theme.Panel
            button.TextColor3 = Theme.Text
        end
    end
end

local function addTab(id, label, order)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 38, 0, 38)
    button.BackgroundColor3 = Theme.Panel
    button.Text = label
    button.Font = Enum.Font.GothamBold
    button.TextSize = 13
    button.TextColor3 = Theme.Text
    button.BorderSizePixel = 0
    button.LayoutOrder = order
    button.ZIndex = 3
    button.Parent = Sidebar
    addCorner(button, 10)

    TabButtons[id] = button

    button.MouseButton1Click:Connect(function()
        if isMenuOpen then
            setPage(id)
        end
    end)
end

setupPage("ESP")
setupPage("Team")
setupPage("Bonus")

addTab("ESP", "ЭСП", 1)
addTab("Team", "ТИМ", 2)
addTab("Bonus", "Б", 3)

setPage("ESP")

local function createControl(parent, height)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, height or 44)
    frame.BackgroundColor3 = Theme.Panel
    frame.BackgroundTransparency = 0.06
    frame.BorderSizePixel = 0
    frame.ZIndex = 2
    frame.Parent = parent
    addCorner(frame, 10)
    addStroke(frame, Color3.fromRGB(28, 28, 28), 1)
    return frame
end

local function createSection(parent, text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 16)
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = Enum.Font.GothamBlack
    label.TextSize = 11
    label.TextColor3 = Theme.Accent
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 2
    label.Parent = parent
    return label
end

local tweenInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local ActiveSlider = nil
local HeaderDragging = false
local headerDragStart = Vector2.new()
local headerDragStartPosition = UDim2.new()

track(UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        if HeaderDragging and isMenuOpen then
            local delta = Vector2.new(input.Position.X, input.Position.Y) - headerDragStart

            MainFrame.Position = UDim2.new(
                headerDragStartPosition.X.Scale,
                headerDragStartPosition.X.Offset + delta.X,
                headerDragStartPosition.Y.Scale,
                headerDragStartPosition.Y.Offset + delta.Y
            )
        end

        if ActiveSlider then
            ActiveSlider.Update(input.Position.X)
        end
    end
end))

track(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        HeaderDragging = false
        ActiveSlider = nil
    end
end))

local function createToggle(parent, label, default, callback)
    local value = default

    local frame = createControl(parent, 44)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -70, 1, 0)
    nameLabel.Position = UDim2.new(0, 12, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = label
    nameLabel.Font = Enum.Font.SourceSansSemibold
    nameLabel.TextSize = 13
    nameLabel.TextColor3 = Theme.Text
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextWrapped = true
    nameLabel.ZIndex = 3
    nameLabel.Parent = frame

    local switch = Instance.new("TextButton")
    switch.Size = UDim2.fromOffset(52, 26)
    switch.Position = UDim2.new(1, -62, 0.5, -13)
    switch.BackgroundColor3 = Theme.Off
    switch.Text = ""
    switch.BorderSizePixel = 0
    switch.AutoButtonColor = false
    switch.ZIndex = 4
    switch.Parent = frame
    addCorner(switch, 13)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(18, 18)
    knob.Position = UDim2.new(0, 3, 0.5, -9)
    knob.BackgroundColor3 = Theme.Dim
    knob.BorderSizePixel = 0
    knob.ZIndex = 5
    knob.Parent = switch
    addCorner(knob, 9)

    local function refresh()
        pcall(function()
            TweenService:Create(switch, tweenInfo, {
                BackgroundColor3 = value and Theme.Accent or Theme.Off,
            }):Play()

            TweenService:Create(knob, tweenInfo, {
                Position = value and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9),
                BackgroundColor3 = value and Color3.fromRGB(0, 0, 0) or Theme.Dim,
            }):Play()
        end)
    end

    switch.MouseButton1Click:Connect(function()
        if not isMenuOpen then
            return
        end

        value = not value
        refresh()

        pcall(function()
            callback(value)
        end)
    end)

    refresh()

    pcall(function()
        callback(default)
    end)
end

local function createSlider(parent, label, min, max, default, callback)
    local value = default

    local frame = createControl(parent, 56)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -58, 0, 18)
    nameLabel.Position = UDim2.new(0, 12, 0, 3)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = label
    nameLabel.Font = Enum.Font.SourceSansSemibold
    nameLabel.TextSize = 13
    nameLabel.TextColor3 = Theme.Text
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.ZIndex = 3
    nameLabel.Parent = frame

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0, 48, 0, 18)
    valueLabel.Position = UDim2.new(1, -58, 0, 3)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(value)
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 12
    valueLabel.TextColor3 = Theme.Accent
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.ZIndex = 3
    valueLabel.Parent = frame

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -24, 0, 4)
    bar.Position = UDim2.new(0, 12, 0, 44)
    bar.BackgroundColor3 = Theme.Off
    bar.BorderSizePixel = 0
    bar.ZIndex = 3
    bar.Parent = frame
    addCorner(bar, 2)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.BorderSizePixel = 0
    fill.ZIndex = 4
    fill.Parent = bar
    addCorner(fill, 2)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(12, 12)
    knob.Position = UDim2.new(0, -6, 0.5, -6)
    knob.BackgroundColor3 = Theme.Accent
    knob.BorderSizePixel = 0
    knob.ZIndex = 5
    knob.Parent = bar
    addCorner(knob, 6)

    local function refresh()
        valueLabel.Text = tostring(value)

        local rel = 0
        if max > min then
            rel = (value - min) / (max - min)
        end

        rel = clamp(rel, 0, 1)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, -6, 0.5, -6)
    end

    local function updateFromX(x)
        local barX = bar.AbsolutePosition.X
        local barWidth = bar.AbsoluteSize.X

        if barWidth <= 0 then
            return
        end

        local rel = clamp((x - barX) / barWidth, 0, 1)
        local newValue = clamp(math.floor(min + (max - min) * rel + 0.5), min, max)

        if newValue == value then
            return
        end

        value = newValue
        refresh()

        pcall(function()
            callback(value)
        end)
    end

    local hit = Instance.new("TextButton")
    hit.Size = UDim2.new(1, 0, 0, 26)
    hit.Position = UDim2.new(0, 0, 0, 26)
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.ZIndex = 5
    hit.Parent = frame

    hit.InputBegan:Connect(function(input)
        if not isMenuOpen then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            ActiveSlider = { Update = updateFromX }
            updateFromX(input.Position.X)
        end
    end)

    refresh()

    pcall(function()
        callback(default)
    end)
end

local function createDropdown(parent, label, options, default, callback)
    local index = 1

    for i, option in ipairs(options) do
        if option == default then
            index = i
            break
        end
    end

    local frame = createControl(parent, 44)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -104, 1, 0)
    nameLabel.Position = UDim2.new(0, 12, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = label
    nameLabel.Font = Enum.Font.SourceSansSemibold
    nameLabel.TextSize = 13
    nameLabel.TextColor3 = Theme.Text
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextWrapped = true
    nameLabel.ZIndex = 3
    nameLabel.Parent = frame

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 92, 0, 26)
    button.Position = UDim2.new(1, -100, 0.5, -13)
    button.BackgroundColor3 = Theme.Off
    button.Text = options[index]
    button.Font = Enum.Font.SourceSansSemibold
    button.TextSize = 11
    button.TextColor3 = Theme.Text
    button.BorderSizePixel = 0
    button.ZIndex = 4
    button.Parent = frame
    addCorner(button, 8)

    local function refresh()
        button.Text = options[index]
    end

    button.MouseButton1Click:Connect(function()
        if not isMenuOpen then
            return
        end

        index = (index % #options) + 1
        refresh()

        pcall(function()
            callback(options[index])
        end)
    end)

    refresh()

    pcall(function()
        callback(default)
    end)
end

local function createButton(parent, label, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 36)
    button.BackgroundColor3 = Theme.PanelLight
    button.Text = label
    button.Font = Enum.Font.SourceSansSemibold
    button.TextSize = 12
    button.TextColor3 = Theme.Text
    button.BorderSizePixel = 0
    button.ZIndex = 3
    button.Parent = parent
    addCorner(button, 10)
    addStroke(button, Color3.fromRGB(35, 35, 35), 1)

    button.MouseButton1Click:Connect(function()
        if isMenuOpen then
            pcall(callback)
        end
    end)

    return button
end

local function createInfoLabel(parent, text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 26)
    label.BackgroundColor3 = Theme.PanelLight
    label.BackgroundTransparency = 0.15
    label.Text = text
    label.Font = Enum.Font.SourceSans
    label.TextSize = 11
    label.TextColor3 = Theme.Dim
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.ZIndex = 3
    label.Parent = parent
    addCorner(label, 8)

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 8)
    padding.Parent = label

    return label
end

-- ESP PAGE
createSection(Pages.ESP, "ЭСП")

addToggle(Pages.ESP, "Включить ЭСП", Config.ESP.Enabled, function(v)
    Config.ESP.Enabled = v
end)

addToggle(Pages.ESP, "Тимчек", Config.ESP.TeamCheck, function(v)
    Config.ESP.TeamCheck = v
end)

addToggle(Pages.ESP, "Показывать тиммейтов", Config.ESP.ShowTeammates, function(v)
    Config.ESP.ShowTeammates = v
end)

addToggle(Pages.ESP, "Полная коробка", Config.ESP.FullBox, function(v)
    Config.ESP.FullBox = v
end)

addToggle(Pages.ESP, "Заливка", Config.ESP.Filled, function(v)
    Config.ESP.Filled = v
end)

addToggle(Pages.ESP, "Имена", Config.ESP.Names, function(v)
    Config.ESP.Names = v
end)

addToggle(Pages.ESP, "Здоровье", Config.ESP.Health, function(v)
    Config.ESP.Health = v
end)

addToggle(Pages.ESP, "Броня", Config.ESP.Armor, function(v)
    Config.ESP.Armor = v
end)

addToggle(Pages.ESP, "Оружие", Config.ESP.Weapon, function(v)
    Config.ESP.Weapon = v
end)

addToggle(Pages.ESP, "Дистанция", Config.ESP.Distance, function(v)
    Config.ESP.Distance = v
end)

addToggle(Pages.ESP, "Скелет", Config.ESP.Skeleton, function(v)
    Config.ESP.Skeleton = v
end)

addToggle(Pages.ESP, "Чамсы", Config.ESP.Chams, function(v)
    Config.ESP.Chams = v
end)

addToggle(Pages.ESP, "Трассеры", Config.ESP.Tracers, function(v)
    Config.ESP.Tracers = v
end)

createSection(Pages.ESP, "СТИЛЬ")

addDropdown(Pages.ESP, "Цвет", { "Белый", "Чёрный", "Красный", "Голубой", "Зелёный", "Жёлтый" }, Config.ESP.Color, function(v)
    Config.ESP.Color = v
end)

addSlider(Pages.ESP, "Толщина", 1, 5, Config.ESP.Thickness, function(v)
    Config.ESP.Thickness = v
end)

addSlider(Pages.ESP, "Размер", 50, 150, Config.ESP.Scale, function(v)
    Config.ESP.Scale = v
end)

-- TEAM PAGE
createSection(Pages.Team, "ТИМЧЕК")

addDropdown(Pages.Team, "Метод команды", { "Авто", "Роблокс", "Атрибуты", "Теги", "Всегда враг" }, Config.Team.Method, function(v)
    Config.Team.Method = v
    scanTeams(true)
end)

addButton(Pages.Team, "Обновить тимчек", function()
    scanTeams(true)
end)

createSection(Pages.Team, "СТАТУС")

local teamMethodLabel = createInfoLabel(Pages.Team, "Метод: нет")
local teamConfidenceLabel = createInfoLabel(Pages.Team, "Уверенность: 0")
local teamValidLabel = createInfoLabel(Pages.Team, "Тимчек: выключен")

-- BONUS PAGE
createSection(Pages.Bonus, "БОНУС")

addToggle(Pages.Bonus, "Модуль 1", Config.Bonus.F1, function(v)
    Config.Bonus.F1 = v
end)

addToggle(Pages.Bonus, "Модуль 2", Config.Bonus.F2, function(v)
    Config.Bonus.F2 = v
end)

addToggle(Pages.Bonus, "Модуль 3", Config.Bonus.F3, function(v)
    Config.Bonus.F3 = v
end)

addToggle(Pages.Bonus, "Модуль 4", Config.Bonus.F4, function(v)
    Config.Bonus.F4 = v
end)

addToggle(Pages.Bonus, "Модуль 5", Config.Bonus.F5, function(v)
    Config.Bonus.F5 = v
end)

-------------------------------------------------------------------------------
-- MENU OPEN/CLOSE
-------------------------------------------------------------------------------
local MenuButton = Instance.new("TextButton")
MenuButton.Size = UDim2.fromOffset(42, 42)
MenuButton.Position = UDim2.new(0, 10, 0, 60)
MenuButton.BackgroundColor3 = Theme.Accent
MenuButton.Text = "N"
MenuButton.Font = Enum.Font.GothamBlack
MenuButton.TextSize = 15
MenuButton.TextColor3 = Color3.fromRGB(0, 0, 0)
MenuButton.BorderSizePixel = 0
MenuButton.ZIndex = 10
MenuButton.Parent = ScreenGui
addCorner(MenuButton, 12)
addStroke(MenuButton, Color3.fromRGB(35, 35, 35), 1)

local function setMenuVisible(value)
    if isMenuOpen == value then
        return
    end

    isMenuOpen = value

    if menuTween then
        pcall(function()
            menuTween:Cancel()
        end)
    end

    local size = getMenuSize()
    MainFrame.Size = UDim2.fromOffset(size, size)

    if value then
        MainFrame.Visible = true
        MainFrame.Active = true
        MainFrame.Position = UDim2.new(0.5, -size / 2, 1, 20)

        menuTween = TweenService:Create(MainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, -size / 2, 0.5, -size / 2),
        })

        menuTween:Play()
    else
        MainFrame.Active = false

        menuTween = TweenService:Create(MainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, -size / 2, 1, 20),
        })

        menuTween:Play()

        menuTween.Completed:Connect(function()
            if not isMenuOpen then
                MainFrame.Visible = false
            end
        end)
    end
end

MenuButton.MouseButton1Click:Connect(function()
    setMenuVisible(not isMenuOpen)
end)

CloseButton.MouseButton1Click:Connect(function()
    setMenuVisible(false)
end)

Header.InputBegan:Connect(function(input)
    if not isMenuOpen then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        HeaderDragging = true
        headerDragStart = Vector2.new(input.Position.X, input.Position.Y)
        headerDragStartPosition = MainFrame.Position
    end
end)

track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end

    if input.KeyCode == Enum.KeyCode.RightShift then
        setMenuVisible(not isMenuOpen)
    end
end))

-------------------------------------------------------------------------------
-- STATUS LOOP
-------------------------------------------------------------------------------
task.spawn(function()
    while not Context.destroyed do
        pcall(function()
            StatusLabel.Text = "team: " .. tostring(Team.method)

            teamMethodLabel.Text = "Метод: " .. tostring(Team.method)
            teamConfidenceLabel.Text = "Уверенность: " .. tostring(math.floor(Team.confidence))
            teamValidLabel.Text = "Тимчек: " .. (Team.valid and "включён" or "выключен")
        end)

        task.wait(0.3)
    end
end)

-------------------------------------------------------------------------------
-- CLEANUP
-------------------------------------------------------------------------------
CleanupFunction = function()
    Context.destroyed = true

    for _, connection in ipairs(Context.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    for player in pairs(ESPObjects) do
        destroyPlayerESP(player)
    end

    for _, object in pairs(BonusObjects) do
        pcall(function()
            object:Remove()
        end)
    end

    for _, hl in pairs(ChamsObjects) do
        pcall(function()
            hl:Destroy()
        end)
    end

    if ScreenGui then
        pcall(function()
            ScreenGui:Destroy()
        end)
    end

    _G[SCRIPT_KEY .. "_Destroy"] = nil
end

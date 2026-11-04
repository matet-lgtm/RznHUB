-- ╔═════════════════════════════════════════════════════════════════╗
-- ║             R_ZONE HUB V3.4 — PROFESSIONAL EDITION            ║
-- ║   Eventos · Bosses · Auto · Radar · ESP+ · Temas · Perfiles   ║
-- ╚═════════════════════════════════════════════════════════════════╝

local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local TweenService        = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser         = game:GetService("VirtualUser")
local TeleportService     = game:GetService("TeleportService")
local Stats               = game:GetService("Stats")
local HttpService         = game:GetService("HttpService")
local CollectionService   = game:GetService("CollectionService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Lighting            = game:GetService("Lighting")
local SoundService        = game:GetService("SoundService")
local GuiService          = game:GetService("GuiService")

local LocalPlayer  = Players.LocalPlayer
local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")

-- Limpieza si el hub ya estaba cargado (evita duplicados al re-ejecutar)
for _, n in ipairs({ "RZoneHUB", "RZoneOverlay" }) do
    local old = PlayerGui:FindFirstChild(n)
    if old then old:Destroy() end
end
do
    local oldSnd = SoundService:FindFirstChild("RZoneAlert")
    if oldSnd then oldSnd:Destroy() end
end
pcall(function() RunService:UnbindFromRenderStep("RZoneCamLock") end)
pcall(function() RunService:UnbindFromRenderStep("RZoneESP2D") end)

-- ══════════════════════════════════════════════
--        CONSTANTES BLOX FRUITS (AJUSTABLES)
-- ══════════════════════════════════════════════
-- Si el juego cambia nombres/tags, edita solo esta tabla.

local BF = {
    seas         = { [2753915549] = "Mar 1", [4442272183] = "Mar 2", [7449423635] = "Mar 3" },
    chestTag     = "_ChestTagged",      -- tag de CollectionService (si existe)
    chestPattern = "^Chest%d*$",        -- Chest1 / Chest2 / Chest3
    fruitPattern = "[Ff]ruit",          -- Tools/Models con "Fruit" en el nombre
    chestTiers   = {
        ["1"] = { "Cofre de Plata",    Color3.fromRGB(205, 210, 220) },
        ["2"] = { "Cofre de Oro",      Color3.fromRGB(255, 205, 60)  },
        ["3"] = { "Cofre de Diamante", Color3.fromRGB(90, 220, 255)  },
    },
}
BF.sea = BF.seas[game.PlaceId] or "Mar ?"

-- ── Eventos, luna, frutas, flores, bosses, stats y diálogos ──
BF.alertSound       = "rbxasset://sounds/electronicpingshort.wav"   -- sonido de las alertas
BF.fullMoonDuration = 900      -- segundos que dura la luna llena (aprox.)
BF.fruitDespawn     = 1200     -- segundos hasta que una fruta suelta desaparece (20 min)
BF.flowerPattern    = "^Flower%d*$"
BF.miragePatterns   = { "^MysticIsland$", "[Mm]irage" }              -- dentro de workspace.Map
BF.messages         = { fullmoon = { "full moon peeks", "light of a full moon" } }
BF.moonPhases = {              -- MoonTextureId -> { nombre, icono, esLlena }  (IDs de comunidad: verifica)
    ["9709135895"] = { "Luna nueva",       "🌑", false },
    ["9709139597"] = { "Cuarto creciente", "🌒", false },
    ["9709143733"] = { "Media luna",       "🌓", false },
    ["9709149052"] = { "Gibosa",           "🌔", false },
    ["9709149431"] = { "Luna llena",       "🌕", true  },
}
BF.seaEvents = {               -- containers: carpetas de workspace ("" = raíz de workspace)
    { key = "seabeast",    label = "Sea Beast",   icon = "🐉", color = Color3.fromRGB(90, 170, 255),
      containers = { "SeaBeasts" }, exclude = { "[Ll]eviathan" } },
    { key = "leviathan",   label = "Leviathan",   icon = "🌊", color = Color3.fromRGB(120, 225, 255),
      containers = { "SeaBeasts" }, patterns = { "[Ll]eviathan" } },
    { key = "terrorshark", label = "Terrorshark", icon = "🦈", color = Color3.fromRGB(255, 95, 95),
      containers = { "Enemies" }, patterns = { "[Tt]error%s*[Ss]hark" } },
    { key = "ghostship",   label = "Ghost Ship",  icon = "👻", color = Color3.fromRGB(170, 255, 205),
      containers = { "Enemies", "" }, patterns = { "[Gg]host%s*[Ss]hip" } },
}
BF.bosses = {                  -- nombres tal como aparecen en workspace.Enemies
    [2753915549] = { "The Gorilla King", "Bobby", "Yeti", "Mob Leader", "Vice Admiral", "Saber Expert", "The Saw",
                     "Warden", "Chief Warden", "Swan", "Magma Admiral", "Fishman Lord", "Wysper", "Thunder God",
                     "Cyborg", "Ice Admiral", "Greybeard" },
    [4442272183] = { "Diamond", "Jeremy", "Fajita", "Don Swan", "Smoke Admiral", "Awakened Ice Admiral",
                     "Tide Keeper", "Darkbeard", "Cursed Captain" },
    [7449423635] = { "Stone", "Island Empress", "Kilo Admiral", "Captain Elephant", "Beautiful Pirate",
                     "Cake Queen", "Longma", "Soul Reaper", "Cake Prince", "Dough King" },
}
BF.statKeys = { Melee = "Melee", Defense = "Defense", Sword = "Sword", Gun = "Gun", Fruit = "Demon Fruit" }
BF.toolTips = { Melee = "Melee", Sword = "Sword", Gun = "Gun", Fruit = "Blox Fruit" }
BF.dialog = {                  -- rutas dentro de PlayerGui + textos de botones (en minúsculas)
    roots   = { "Main.Dialogue", "Dialogue", "Main.Quest", "Quest" },
    skip    = { "skip", "next", "continue", "omitir", "siguiente", "continuar" },
    accept  = { "accept", "aceptar", "yes", "sí", "si" },
    exclude = { "[Ss]hop", "[Bb]uy", "[Pp]urchase", "[Dd]ealer", "[Ss]tore", "[Rr]obux", "[Gg]amepass", "[Cc]onfirm" },
}

-- ══════════════════════════════════════════════
--          ARCHIVOS / JSON (CONFIGURACIÓN)
-- ══════════════════════════════════════════════

local FS = { root = "RZoneHub", mem = {} }
FS.ok = (type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function")

function FS.init()
    if FS.ok and type(isfolder) == "function" and type(makefolder) == "function" then
        pcall(function()
            if not isfolder(FS.root) then makefolder(FS.root) end
            if not isfolder(FS.root .. "/profiles") then makefolder(FS.root .. "/profiles") end
        end)
    end
end

function FS.write(path, text)
    if FS.ok then
        local ok = pcall(writefile, path, text)
        return ok
    end
    FS.mem[path] = text
    return true
end

function FS.read(path)
    if FS.ok then
        local ok, res = pcall(function()
            if isfile(path) then return readfile(path) end
            return nil
        end)
        if ok then return res end
        return nil
    end
    return FS.mem[path]
end

function FS.delete(path)
    if FS.ok then
        if type(delfile) == "function" then pcall(delfile, path) end
    else
        FS.mem[path] = nil
    end
end

function FS.list(dir)
    local out = {}
    if FS.ok then
        if type(listfiles) == "function" then
            local ok, res = pcall(listfiles, dir)
            if ok and type(res) == "table" then out = res end
        end
    else
        for p in pairs(FS.mem) do
            if p:sub(1, #dir) == dir then table.insert(out, p) end
        end
    end
    return out
end

FS.init()

local function jsonEnc(t)
    local ok, r = pcall(function() return HttpService:JSONEncode(t) end)
    if ok then return r end
    return nil
end

local function jsonDec(s)
    if type(s) ~= "string" or s == "" then return nil end
    local ok, r = pcall(function() return HttpService:JSONDecode(s) end)
    if ok and type(r) == "table" then return r end
    return nil
end

local function cleanName(s)
    s = tostring(s or "")
    s = s:gsub("[^%w_%- ]", "")
    s = s:gsub("^%s+", "")
    s = s:gsub("%s+$", "")
    return s:sub(1, 24)
end

-- Perfil de autocarga (se lee ahora para aplicar el tema antes de crear la UI)
local startupConfig = nil
do
    local auto = FS.read(FS.root .. "/autoload.txt")
    if auto then
        local n = cleanName(auto)
        if n ~= "" then
            startupConfig = jsonDec(FS.read(FS.root .. "/profiles/" .. n .. ".json"))
        end
    end
end

-- ══════════════════════════════════════════════
--            CONFIGURACIÓN Y ESTADOS
-- ══════════════════════════════════════════════

local BASE_WALKSPEED  = 16
local BASE_JUMPPOWER  = 50
local speedMultiplier = 1
local jumpMultiplier  = 1
local speedConn       = nil

local espEnabled      = false
local distEspEnabled  = false
local healthEspEnabled= false
local hitboxesVisible = false
local autoM1Enabled   = false
local fastM1Enabled   = false
local hideDashWarning = false
local hideBanWarning  = false

local MODES = {
    { key="normal", label="◆ Normal",   mult=1,  enemySize=Vector3.new(2,  2,  1)   },
    { key="x10",    label="◆ x10",     mult=3,  enemySize=Vector3.new(12, 12, 12)  },
    { key="x20",    label="◆ x20",     mult=5,  enemySize=Vector3.new(22, 22, 22)  },
    { key="x30",    label="◆ x30",     mult=7,  enemySize=Vector3.new(35, 35, 35)  },
    { key="x40",    label="◆ x40",     mult=9,  enemySize=Vector3.new(48, 48, 48)  },
    { key="x60",    label="◆ x60",     mult=13, enemySize=Vector3.new(70, 70, 70)  },
    { key="x70",    label="◆ x70",     mult=15, enemySize=Vector3.new(85, 85, 85)  },
    { key="x100",   label="◆ x100",    mult=20, enemySize=Vector3.new(120,120,120) },
    { key="x200",   label="◆ x200",    mult=38, enemySize=Vector3.new(240,240,240) },
    { key="x500",   label="◆ x500",    mult=95, enemySize=Vector3.new(600,600,600) },
}

local currentMode   = MODES[1]
local enemyCache    = {}
local originalSizes = {}
local lastCacheTime = 0
local CACHE_INTERVAL= 1.0

-- Estados nuevos agrupados en una tabla
local X = {
    antiAfk = true, notifications = true,
    camLock = false, strafe = false, autoNearest = false,
    target = nil, aimPart = "Head", camSmooth = 1,
    strafeRadius = 12, strafeSpeed = 6, strafeHeight = 0, strafeDir = 1, strafeAngle = 0,
    boxEsp = false, skelEsp = false, chestEsp = false, fruitEsp = false, espMaxDist = 3000,
    radar = true, radarSize = 170, radarRange = 600, radarRotate = true, radarAllies = true,
    tpMode = "tween", tpSpeed = 250,
    theme = "Nebula", sessionStart = os.clock(),
    -- alertas / eventos
    alertBanner = true, alertSound = true, alertVolume = 0.8,
    notifMoon = true, notifMirage = true, notifSea = true, notifFruit = true, notifBoss = false,
    compass = true, seaEsp = false, flowerEsp = false, bossEsp = false, learnedFull = "",
    -- automatización
    autoStats = false, statChoice = "Melee",
    mastery = false, masteryType = "Sword", mainType = "Melee", masteryHp = 15, masteryRange = 80,
    fastDialog = false, autoAccept = false,
    -- rendimiento
    noParticles = false, lowGfx = false, cap60 = false,
}

-- ══════════════════════════════════════════════
--                  TEMAS / UTILIDADES UI
-- ══════════════════════════════════════════════

local rgb = Color3.fromRGB

local THEME_LIST = {
    { name = "Nebula", c = {
        bg = rgb(11, 12, 19), panel = rgb(15, 16, 25), card = rgb(21, 23, 35), cardHover = rgb(28, 31, 47),
        stroke = rgb(38, 42, 62), accent = rgb(124, 92, 255), accent2 = rgb(34, 211, 238),
        text = rgb(232, 234, 245), textDim = rgb(190, 195, 215), muted = rgb(125, 132, 158),
        ok = rgb(74, 222, 128), warn = rgb(251, 191, 36), danger = rgb(248, 81, 99),
        selected = rgb(34, 28, 66), dangerBg = rgb(46, 18, 26), dangerBgHover = rgb(66, 24, 34),
        heroTop = rgb(16, 14, 28), heroBottom = rgb(9, 10, 16),
    } },
    { name = "R_Zone Crimson", c = {
        bg = rgb(12, 6, 7), panel = rgb(19, 9, 10), card = rgb(28, 14, 15), cardHover = rgb(40, 20, 22),
        stroke = rgb(66, 32, 34), accent = rgb(220, 38, 38), accent2 = rgb(251, 146, 60),
        text = rgb(246, 236, 233), textDim = rgb(214, 192, 188), muted = rgb(166, 134, 130),
        ok = rgb(74, 222, 128), warn = rgb(250, 204, 21), danger = rgb(255, 99, 132),
        selected = rgb(70, 18, 20), dangerBg = rgb(52, 16, 20), dangerBgHover = rgb(74, 22, 28),
        heroTop = rgb(30, 10, 12), heroBottom = rgb(10, 5, 6),
    } },
    { name = "Cyberpunk Neon", c = {
        bg = rgb(7, 6, 17), panel = rgb(12, 10, 27), card = rgb(20, 15, 42), cardHover = rgb(31, 23, 62),
        stroke = rgb(64, 42, 116), accent = rgb(255, 0, 170), accent2 = rgb(0, 240, 255),
        text = rgb(240, 240, 255), textDim = rgb(196, 186, 232), muted = rgb(138, 124, 190),
        ok = rgb(57, 255, 140), warn = rgb(255, 230, 0), danger = rgb(255, 70, 70),
        selected = rgb(58, 12, 66), dangerBg = rgb(50, 12, 30), dangerBgHover = rgb(72, 16, 42),
        heroTop = rgb(24, 8, 40), heroBottom = rgb(6, 5, 16),
    } },
    { name = "Emerald Glass", c = {
        bg = rgb(6, 15, 14), panel = rgb(10, 23, 21), card = rgb(15, 34, 31), cardHover = rgb(22, 48, 44),
        stroke = rgb(36, 80, 72), accent = rgb(16, 185, 129), accent2 = rgb(125, 235, 190),
        text = rgb(231, 251, 243), textDim = rgb(183, 219, 206), muted = rgb(115, 162, 148),
        ok = rgb(163, 230, 53), warn = rgb(251, 191, 36), danger = rgb(248, 113, 113),
        selected = rgb(13, 64, 52), dangerBg = rgb(50, 20, 22), dangerBgHover = rgb(72, 28, 30),
        heroTop = rgb(10, 34, 30), heroBottom = rgb(5, 12, 11),
    } },
    { name = "Dark Stealth", c = {
        bg = rgb(10, 10, 12), panel = rgb(15, 15, 18), card = rgb(22, 22, 26), cardHover = rgb(32, 32, 38),
        stroke = rgb(50, 50, 58), accent = rgb(148, 163, 184), accent2 = rgb(203, 213, 225),
        text = rgb(236, 236, 241), textDim = rgb(190, 190, 201), muted = rgb(126, 126, 140),
        ok = rgb(110, 200, 140), warn = rgb(212, 170, 70), danger = rgb(222, 92, 92),
        selected = rgb(38, 40, 50), dangerBg = rgb(44, 20, 22), dangerBgHover = rgb(62, 26, 30),
        heroTop = rgb(20, 20, 26), heroBottom = rgb(8, 8, 10),
    } },
}

local THEME = {}
do
    local base = THEME_LIST[1]
    if startupConfig and startupConfig.theme then
        for _, d in ipairs(THEME_LIST) do
            if d.name == startupConfig.theme then base = d end
        end
    end
    for k, v in pairs(base.c) do THEME[k] = v end
    X.theme = base.name
end

-- Colores semánticos (no cambian con el tema)
local COL = {
    enemy  = rgb(255, 59, 59),
    ally   = rgb(46, 230, 110),
    target = rgb(255, 214, 10),
}

local function create(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function applyCorner(parent, radius)
    local c = Instance.new("UICorner", parent)
    c.CornerRadius = UDim.new(0, radius or 8)
    return c
end

local function applyStroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke", parent)
    s.Color        = color or THEME.stroke
    s.Thickness    = thickness or 1
    s.Transparency = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    return s
end

local function applyGradient(parent, c0, c1, rotation)
    local g = Instance.new("UIGradient", parent)
    g.Color    = ColorSequence.new({ ColorSequenceKeypoint.new(0, c0), ColorSequenceKeypoint.new(1, c1) })
    g.Rotation = rotation or 0
    return g
end

local function applyPadding(parent, l, t, r, b)
    return create("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0), PaddingTop = UDim.new(0, t or 0),
        PaddingRight = UDim.new(0, r or 0), PaddingBottom = UDim.new(0, b or 0),
    }, parent)
end

local function tween(obj, props, time, style)
    local t = TweenService:Create(obj, TweenInfo.new(time or 0.18, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function label(parent, text, size, font, color, xAlign)
    return create("TextLabel", {
        BackgroundTransparency = 1,
        Text = text, TextSize = size, Font = font, TextColor3 = color,
        TextXAlignment = xAlign or Enum.TextXAlignment.Left,
    }, parent)
end

local function colorEq(a, b)
    return math.abs(a.R - b.R) < 0.0025 and math.abs(a.G - b.G) < 0.0025 and math.abs(a.B - b.B) < 0.0025
end

-- Registro de ajustes guardables + referencias que se asignan más adelante
local CFG = { toggles = {}, sliders = {}, segments = {} }
local rebuildPlayerList, refreshTargetCard, refreshModeRows, selectMode
local refreshBindRows, refreshThemeCards, rebuildWaypointList, rebuildProfileList, setVis

-- ══════════════════════════════════════════════
--      LÓGICA CORE (MODIFICACIÓN DIRECTA)
-- ══════════════════════════════════════════════

local function restoreOriginalSizes()
    for hrp, origSize in pairs(originalSizes) do
        if hrp and hrp.Parent then
            hrp.Size = origSize
            if hrp.Name == "HumanoidRootPart" and hrp.Parent ~= LocalPlayer.Character then
                hrp.Transparency = 1
            end
        end
    end
    originalSizes = {}
end

local function processHitbox(hrp, targetSize, isLocal)
    if not hrp or not hrp.Parent then return end
    
    if currentMode.key == "normal" then
        if originalSizes[hrp] then
            hrp.Size = originalSizes[hrp]
            if hrp.Name == "HumanoidRootPart" then
                hrp.Transparency = 1
            end
            originalSizes[hrp] = nil
        end
        return
    end

    if not originalSizes[hrp] then
        originalSizes[hrp] = hrp.Size
    end

    if isLocal then
        -- Mantiene la altura fija en Y para evitar flotar o deslizarse
        hrp.Size = Vector3.new(targetSize.X, math.min(targetSize.Y, 3), targetSize.Z)
        hrp.Transparency = 1
    else
        hrp.Size = targetSize
        hrp.Transparency = hitboxesVisible and 0.65 or 1
    end
    
    hrp.CanCollide = false
end

local function refreshEnemyCache()
    enemyCache = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if hrp and humanoid and humanoid.Health > 0 then
                table.insert(enemyCache, hrp)
            end
        end
    end
end

local function clearAllHitboxes()
    restoreOriginalSizes()
end

local function updateESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") then
            local char      = player.Character
            local highlight = char:FindFirstChild("RZoneHighlight")
            local info      = char.Head:FindFirstChild("RZoneInfo")
            if espEnabled then
                if not highlight then
                    highlight = Instance.new("Highlight")
                    highlight.Name       = "RZoneHighlight"
                    highlight.FillColor  = THEME.accent
                    highlight.OutlineColor = THEME.accent2
                    highlight.FillTransparency = 0.65
                    highlight.OutlineTransparency = 0.1
                    highlight.Parent     = char
                end
                if distEspEnabled or healthEspEnabled then
                    if not info then
                        info = Instance.new("BillboardGui")
                        info.Name            = "RZoneInfo"
                        info.Size            = UDim2.new(0, 130, 0, 26)
                        info.Adornee         = char.Head
                        info.AlwaysOnTop     = true
                        info.ExtentsOffset = Vector3.new(0, 3, 0)
                        local pill = Instance.new("Frame", info)
                        pill.Name = "Pill"
                        pill.Size = UDim2.new(1, 0, 1, 0)
                        pill.BackgroundColor3 = THEME.bg
                        pill.BackgroundTransparency = 0.25
                        pill.BorderSizePixel = 0
                        applyCorner(pill, 13)
                        applyStroke(pill, THEME.accent, 1, 0.2)
                        local l = Instance.new("TextLabel", info)
                        l.Name               = "Label"
                        l.Size               = UDim2.new(1, 0, 1, 0)
                        l.BackgroundTransparency = 1
                        l.TextColor3         = THEME.text
                        l.Font               = Enum.Font.GothamBold
                        l.TextSize           = 11
                        l.TextStrokeTransparency = 0.6
                        info.Parent = char.Head
                    end
                    local myHead = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
                    local d = myHead and math.floor((myHead.Position - char.Head.Position).Magnitude) or 0
                    local h = char:FindFirstChildOfClass("Humanoid") and math.floor(char:FindFirstChildOfClass("Humanoid").Health) or 0
                    local t = ""
                    if distEspEnabled  then t = t .. "📍 " .. d .. "m  " end
                    if healthEspEnabled then t = t .. "❤ " .. h end
                    info.Label.Text = t
                elseif info then info:Destroy() end
            else
                if highlight then highlight:Destroy() end
                if info      then info:Destroy()      end
            end
        end
    end
end

local function hookMovement(humanoid)
    if speedConn then speedConn:Disconnect() end
    speedConn = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if speedMultiplier > 1 then task.defer(function()
            if humanoid and humanoid.Parent then humanoid.WalkSpeed = BASE_WALKSPEED * speedMultiplier end
        end) end
    end)
    humanoid:GetPropertyChangedSignal("JumpPower"):Connect(function()
        if jumpMultiplier > 1 then task.defer(function()
            if humanoid and humanoid.Parent then humanoid.JumpPower = BASE_JUMPPOWER * jumpMultiplier end
        end) end
    end)
end

-- ══════════════════════════════════════════════
--            BASE GUI / OVERLAY / TOASTS
-- ══════════════════════════════════════════════

local screenGui             = Instance.new("ScreenGui")
screenGui.Name              = "RZoneHUB"
screenGui.ResetOnSpawn      = false
screenGui.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
screenGui.Parent            = PlayerGui

-- Capa para ESP 2D y Radar (debajo del hub)
local overlayGui = create("ScreenGui", {
    Name = "RZoneOverlay", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = -1,
}, PlayerGui)

local LOGO_ID = "rbxassetid://71914607262116"

local notify
do
    local holder = create("Frame", {
        Size = UDim2.new(0, 270, 1, -30), Position = UDim2.new(1, -286, 0, 15),
        BackgroundTransparency = 1, ZIndex = 500,
    }, screenGui)
    create("UIListLayout", {
        Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
    }, holder)
    local counter = 0
    notify = function(title, text, color, duration)
        if not X.notifications then return end
        counter = counter + 1
        color = color or THEME.accent
        local toast = create("CanvasGroup", {
            Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = THEME.panel, BorderSizePixel = 0,
            GroupTransparency = 1, LayoutOrder = counter,
        }, holder)
        applyCorner(toast, 10)
        applyStroke(toast, color, 1, 0.4)
        create("Frame", { Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = color, BorderSizePixel = 0 }, toast)
        local t1 = label(toast, title, 12, Enum.Font.GothamBold, THEME.text)
        t1.Size = UDim2.new(1, -24, 0, 18); t1.Position = UDim2.new(0, 16, 0, 8)
        local t2 = label(toast, text, 11, Enum.Font.Gotham, THEME.muted)
        t2.Size = UDim2.new(1, -24, 0, 16); t2.Position = UDim2.new(0, 16, 0, 28)
        t2.TextTruncate = Enum.TextTruncate.AtEnd
        tween(toast, { GroupTransparency = 0 }, 0.25)
        task.delay(duration or 2.2, function()
            if toast and toast.Parent then
                tween(toast, { GroupTransparency = 1 }, 0.3)
                task.wait(0.35)
                if toast then toast:Destroy() end
            end
        end)
    end
end

-- ══════════════════════════════════════════════
--                  ANTI-AFK
-- ══════════════════════════════════════════════

LocalPlayer.Idled:Connect(function()
    if X.antiAfk then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end
end)

-- ══════════════════════════════════════════════
--          OBJETIVO · CAM LOCK · STRAFE
-- ══════════════════════════════════════════════

local function clearTargetMarker(plr)
    local c = plr and plr.Character
    if not c then return end
    local hl = c:FindFirstChild("RZoneTarget"); if hl then hl:Destroy() end
    local head = c:FindFirstChild("Head")
    local tag = head and head:FindFirstChild("RZoneTargetTag"); if tag then tag:Destroy() end
end

local function ensureTargetMarker()
    if not X.target then return end
    local c = X.target.Character
    if not c then return end
    if not c:FindFirstChild("RZoneTarget") then
        local hl = Instance.new("Highlight")
        hl.Name = "RZoneTarget"
        hl.FillColor = THEME.danger
        hl.OutlineColor = Color3.new(1, 1, 1)
        hl.FillTransparency = 0.55
        hl.OutlineTransparency = 0
        hl.Parent = c
    end
    local head = c:FindFirstChild("Head")
    if head and not head:FindFirstChild("RZoneTargetTag") then
        local bb = Instance.new("BillboardGui")
        bb.Name = "RZoneTargetTag"
        bb.Size = UDim2.new(0, 96, 0, 22)
        bb.Adornee = head
        bb.AlwaysOnTop = true
        bb.ExtentsOffset = Vector3.new(0, 4.6, 0)
        local pill = Instance.new("TextLabel", bb)
        pill.Size = UDim2.new(1, 0, 1, 0)
        pill.BackgroundColor3 = THEME.danger
        pill.BackgroundTransparency = 0.1
        pill.Text = "🎯 OBJETIVO"
        pill.TextColor3 = Color3.new(1, 1, 1)
        pill.Font = Enum.Font.GothamBlack
        pill.TextSize = 11
        pill.BorderSizePixel = 0
        applyCorner(pill, 11)
        bb.Parent = head
    end
end

local function setTarget(plr, silent)
    if plr == X.target then return end
    clearTargetMarker(X.target)
    X.target = plr
    if plr then ensureTargetMarker() end
    if rebuildPlayerList then rebuildPlayerList() end
    if refreshTargetCard then refreshTargetCard() end
    if not silent then
        if plr then notify("🎯 Objetivo fijado", plr.DisplayName .. " (@" .. plr.Name .. ")", THEME.danger)
        else notify("Objetivo liberado", "Sin jugador seleccionado", THEME.muted) end
    end
end

local function getTargetParts()
    local p = X.target
    if not p then return end
    local c = p.Character; if not c then return end
    local hum = c:FindFirstChildOfClass("Humanoid")
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then return end
    local aim = c:FindFirstChild(X.aimPart) or hrp
    return c, hrp, hum, aim
end

local function findNearestPlayer()
    local char = LocalPlayer.Character
    local myHrp = char and char:FindFirstChild("HumanoidRootPart")
    if not myHrp then return nil end
    local best, bestD = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local h = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if h and hum and hum.Health > 0 then
                local d = (h.Position - myHrp.Position).Magnitude
                if d < bestD then best, bestD = p, d end
            end
        end
    end
    return best
end

Players.PlayerRemoving:Connect(function(p)
    if p == X.target then setTarget(nil) end
    if rebuildPlayerList then task.defer(rebuildPlayerList) end
end)
Players.PlayerAdded:Connect(function()
    if rebuildPlayerList then task.defer(rebuildPlayerList) end
end)

-- Cam Lock (se ejecuta después del script de cámara de Roblox)
RunService:BindToRenderStep("RZoneCamLock", Enum.RenderPriority.Camera.Value + 1, function(dt)
    if not X.camLock then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local _, _, _, aim = getTargetParts()
    if not aim then return end
    local goal = CFrame.new(cam.CFrame.Position, aim.Position)
    if X.camSmooth <= 1.01 then
        cam.CFrame = goal
    else
        cam.CFrame = cam.CFrame:Lerp(goal, math.clamp(dt * 60 / X.camSmooth, 0, 1))
    end
end)

-- Target Strafe (orbita alrededor del objetivo)
RunService.Heartbeat:Connect(function(dt)
    if not X.strafe then return end
    local char = LocalPlayer.Character
    local myHrp = char and char:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end
    local _, hrp = getTargetParts()
    if not hrp then return end
    X.strafeAngle = (X.strafeAngle + X.strafeDir * X.strafeSpeed * dt) % (math.pi * 2)
    local center = hrp.Position
    local pos = center + Vector3.new(math.cos(X.strafeAngle) * X.strafeRadius, X.strafeHeight, math.sin(X.strafeAngle) * X.strafeRadius)
    myHrp.CFrame = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z))
    myHrp.AssemblyLinearVelocity = Vector3.zero
end)

-- Auto-objetivo: jugador vivo más cercano
task.spawn(function()
    while true do
        task.wait(0.3)
        if X.autoNearest then
            local best = findNearestPlayer()
            if best then setTarget(best, true) end
        end
    end
end)

-- ══════════════════════════════════════════════
--        ALIADOS (equipo o amigos de Roblox)
-- ══════════════════════════════════════════════

local isAlly
do
    local cache = {}
    local function track(p)
        if p == LocalPlayer or cache[p.UserId] ~= nil then return end
        cache[p.UserId] = false
        task.spawn(function()
            local ok, res = pcall(function() return LocalPlayer:IsFriendsWith(p.UserId) end)
            if ok and res then cache[p.UserId] = true end
        end)
    end
    for _, p in ipairs(Players:GetPlayers()) do track(p) end
    Players.PlayerAdded:Connect(track)
    isAlly = function(plr)
        if cache[plr.UserId] then return true end
        return LocalPlayer.Team ~= nil and plr.Team == LocalPlayer.Team
    end
end

-- ══════════════════════════════════════════════
--            BOX ESP / SKELETON ESP (2D)
-- ══════════════════════════════════════════════
-- Usa la posición del HRP con offsets fijos: la caja NO crece con la hitbox ampliada.

local updateEsp2D
do
    local R15 = {
        { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
        { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
        { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
        { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
        { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
    }
    local R6 = {
        { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" },
        { "Torso", "Left Leg" }, { "Torso", "Right Leg" },
    }
    local objs = {}

    local function makeObj(plr)
        local holder = create("Frame", {
            Name = plr.Name, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
            BorderSizePixel = 0, Visible = false,
        }, overlayGui)
        local box = create("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0 }, holder)
        local stroke = create("UIStroke", { Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, box)
        local hpBack = create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, BorderSizePixel = 0,
        }, holder)
        local hpFill = create("Frame", {
            AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
            Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 1, 0), BorderSizePixel = 0,
        }, hpBack)
        local nameLbl = create("TextLabel", {
            AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(0, 220, 0, 14), BackgroundTransparency = 1,
            Text = "", TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 11,
            TextStrokeTransparency = 0.5,
        }, holder)
        local bones = {}
        for i = 1, 14 do
            bones[i] = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Visible = false }, holder)
        end
        local o = { holder = holder, box = box, stroke = stroke, hpBack = hpBack, hpFill = hpFill, name = nameLbl, bones = bones }
        objs[plr] = o
        return o
    end

    Players.PlayerRemoving:Connect(function(p)
        local o = objs[p]
        if o then o.holder:Destroy(); objs[p] = nil end
    end)

    updateEsp2D = function()
        local cam = workspace.CurrentCamera
        local wantBox, wantSkel = X.boxEsp, X.skelEsp
        if not cam or not (wantBox or wantSkel) then
            for _, o in pairs(objs) do
                if o.holder.Visible then o.holder.Visible = false end
            end
            return
        end
        local myChar = LocalPlayer.Character
        local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local o = objs[plr]
                local show = false
                local char = plr.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hrp and hum and hum.Health > 0 then
                    local dist = myHrp and (hrp.Position - myHrp.Position).Magnitude or 0
                    if dist <= X.espMaxDist then
                        local pos, onScreen = cam:WorldToViewportPoint(hrp.Position)
                        if onScreen then
                            local top = cam:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3, 0))
                            local bot = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3.2, 0))
                            local h = bot.Y - top.Y
                            if h > 4 then
                                show = true
                                o = o or makeObj(plr)
                                local w = h * 0.55
                                local col = (plr == X.target) and COL.target or (isAlly(plr) and COL.ally or COL.enemy)

                                o.box.Visible = wantBox
                                o.hpBack.Visible = wantBox
                                o.name.Visible = wantBox
                                if wantBox then
                                    o.box.Position = UDim2.fromOffset(pos.X - w / 2, top.Y)
                                    o.box.Size = UDim2.fromOffset(w, h)
                                    o.stroke.Color = col
                                    local ratio = 1
                                    if hum.MaxHealth > 0 then ratio = math.clamp(hum.Health / hum.MaxHealth, 0, 1) end
                                    o.hpBack.Position = UDim2.fromOffset(pos.X - w / 2 - 6, top.Y)
                                    o.hpBack.Size = UDim2.fromOffset(3, h)
                                    o.hpFill.Size = UDim2.new(1, 0, ratio, 0)
                                    o.hpFill.BackgroundColor3 = Color3.fromHSV(ratio * 0.33, 0.85, 1)
                                    o.name.Position = UDim2.fromOffset(pos.X, top.Y - 3)
                                    o.name.Text = plr.DisplayName .. "  ·  " .. math.floor(dist) .. "m"
                                end

                                if wantSkel then
                                    local set = char:FindFirstChild("UpperTorso") and R15 or R6
                                    for i = 1, 14 do
                                        local f = o.bones[i]
                                        local bn = set[i]
                                        local vis = false
                                        if bn then
                                            local pa = char:FindFirstChild(bn[1])
                                            local pb = char:FindFirstChild(bn[2])
                                            if pa and pb then
                                                local a = cam:WorldToViewportPoint(pa.Position)
                                                local b = cam:WorldToViewportPoint(pb.Position)
                                                if a.Z > 0 and b.Z > 0 then
                                                    local dx, dy = b.X - a.X, b.Y - a.Y
                                                    f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
                                                    f.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), 1.6)
                                                    f.Rotation = math.deg(math.atan2(dy, dx))
                                                    f.BackgroundColor3 = col
                                                    vis = true
                                                end
                                            end
                                        end
                                        f.Visible = vis
                                    end
                                else
                                    for i = 1, 14 do o.bones[i].Visible = false end
                                end
                            end
                        end
                    end
                end
                if o and o.holder.Visible ~= show then o.holder.Visible = show end
            end
        end
    end
end

-- ══════════════════════════════════════════════
--                  RADAR 2D
-- ══════════════════════════════════════════════

local updateRadar, radarApplyLayout
do
    local frame = create("Frame", {
        Name = "Radar", Size = UDim2.new(0, X.radarSize, 0, X.radarSize),
        Position = UDim2.new(0, 24, 0.5, -90),
        BackgroundColor3 = THEME.bg, BackgroundTransparency = 0.2,
        BorderSizePixel = 0, Visible = false, Active = true,
    }, overlayGui)
    applyCorner(frame, 999)
    local frameStroke = applyStroke(frame, THEME.accent, 2, 0.1)
    applyGradient(frameStroke, THEME.accent, THEME.accent2, 45)

    local ring = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0.5, 0, 0.5, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
    }, frame)
    applyCorner(ring, 999)
    applyStroke(ring, THEME.stroke, 1, 0.2)

    create("Frame", {
        Size = UDim2.new(1, -8, 0, 1), Position = UDim2.new(0, 4, 0.5, 0),
        BackgroundColor3 = THEME.stroke, BackgroundTransparency = 0.4, BorderSizePixel = 0,
    }, frame)
    create("Frame", {
        Size = UDim2.new(0, 1, 1, -8), Position = UDim2.new(0.5, 0, 0, 4),
        BackgroundColor3 = THEME.stroke, BackgroundTransparency = 0.4, BorderSizePixel = 0,
    }, frame)

    local arrow = create("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 14, 0, 14), BackgroundTransparency = 1,
        Text = "▲", TextColor3 = THEME.accent2, Font = Enum.Font.GothamBlack, TextSize = 12,
    }, frame)

    local rangeLbl = create("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8),
        Size = UDim2.new(0, 60, 0, 12), BackgroundTransparency = 1,
        Text = "", TextColor3 = THEME.muted, Font = Enum.Font.GothamBold, TextSize = 9,
    }, frame)

    local dots = {}
    local function getDot(plr)
        local entry = dots[plr]
        if entry then return entry end
        local d = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 7, 0, 7),
            BorderSizePixel = 0, Visible = false,
        }, frame)
        d:SetAttribute("NoTheme", true)
        applyCorner(d, 999)
        local st = Instance.new("UIStroke", d)
        st.Thickness = 1.5
        st.Color = Color3.new(1, 1, 1)
        st.Enabled = false
        st:SetAttribute("NoTheme", true)
        entry = { frame = d, stroke = st }
        dots[plr] = entry
        return entry
    end

    Players.PlayerRemoving:Connect(function(p)
        local e = dots[p]
        if e then e.frame:Destroy(); dots[p] = nil end
    end)

    radarApplyLayout = function()
        frame.Size = UDim2.new(0, X.radarSize, 0, X.radarSize)
    end

    updateRadar = function()
        if not X.radar then
            if frame.Visible then frame.Visible = false end
            return
        end
        if not frame.Visible then frame.Visible = true end
        rangeLbl.Text = math.floor(X.radarRange) .. "m"
        local cam = workspace.CurrentCamera
        local char = LocalPlayer.Character
        local myHrp = char and char:FindFirstChild("HumanoidRootPart")
        if not cam or not myHrp then return end

        local look = cam.CFrame.LookVector
        local fwd = Vector3.new(look.X, 0, look.Z)
        if fwd.Magnitude < 0.001 then fwd = Vector3.new(0, 0, -1) else fwd = fwd.Unit end
        local right = fwd:Cross(Vector3.new(0, 1, 0))
        local radius = X.radarSize / 2 - 6
        local scale = radius / X.radarRange
        if X.radarRotate then arrow.Rotation = 0 else arrow.Rotation = math.deg(math.atan2(fwd.X, -fwd.Z)) end

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local entry = dots[plr]
                local c = plr.Character
                local hrp = c and c:FindFirstChild("HumanoidRootPart")
                local hum = c and c:FindFirstChildOfClass("Humanoid")
                local ally = isAlly(plr)
                if hrp and hum and hum.Health > 0 and (X.radarAllies or not ally) then
                    entry = entry or getDot(plr)
                    local d = hrp.Position - myHrp.Position
                    local x, y
                    if X.radarRotate then
                        x, y = d:Dot(right), -d:Dot(fwd)
                    else
                        x, y = d.X, d.Z
                    end
                    local vx, vy = x * scale, y * scale
                    local mag = math.sqrt(vx * vx + vy * vy)
                    local outside = mag > radius
                    if outside and mag > 0 then
                        vx, vy = vx / mag * radius, vy / mag * radius
                    end
                    local isT = (plr == X.target)
                    entry.frame.Position = UDim2.new(0.5, vx, 0.5, vy)
                    entry.frame.BackgroundColor3 = isT and COL.target or (ally and COL.ally or COL.enemy)
                    entry.frame.BackgroundTransparency = outside and 0.55 or 0
                    entry.frame.Size = isT and UDim2.new(0, 10, 0, 10) or UDim2.new(0, 7, 0, 7)
                    entry.stroke.Enabled = isT
                    entry.frame.Visible = true
                elseif entry then
                    entry.frame.Visible = false
                end
            end
        end
    end

    -- El radar se puede arrastrar con clic izquierdo
    local dragging, dragStart, startPos = false, nil, nil
    frame.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = i.Position; startPos = frame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
end

-- ══════════════════════════════════════════════
--          TEMAS (CAMBIO EN CALIENTE)
-- ══════════════════════════════════════════════

local function resetWorldVisuals()
    for _, p in ipairs(Players:GetPlayers()) do
        local c = p.Character
        if c then
            local h = c:FindFirstChild("RZoneHighlight"); if h then h:Destroy() end
            local head = c:FindFirstChild("Head")
            local info = head and head:FindFirstChild("RZoneInfo"); if info then info:Destroy() end
            clearTargetMarker(p)
        end
    end
end

local COLOR_PROPS = {
    Frame = { "BackgroundColor3" }, CanvasGroup = { "BackgroundColor3" },
    TextLabel = { "BackgroundColor3", "TextColor3" }, TextButton = { "BackgroundColor3", "TextColor3" },
    TextBox = { "BackgroundColor3", "TextColor3", "PlaceholderColor3" },
    ImageLabel = { "BackgroundColor3" }, ScrollingFrame = { "BackgroundColor3", "ScrollBarImageColor3" },
    UIStroke = { "Color" },
}
local THEME_ROOTS = { screenGui, overlayGui }

local function applyTheme(def)
    local old = {}
    for k, v in pairs(THEME) do old[k] = v end
    for k, v in pairs(def.c) do THEME[k] = v end
    X.theme = def.name

    local function remap(c)
        for k, ov in pairs(old) do
            if colorEq(c, ov) then return THEME[k] end
        end
        return c
    end

    for _, root in ipairs(THEME_ROOTS) do
        for _, d in ipairs(root:GetDescendants()) do
            if not d:GetAttribute("NoTheme") then
                local props = COLOR_PROPS[d.ClassName]
                if props then
                    for _, p in ipairs(props) do
                        local cur = d[p]
                        local new = remap(cur)
                        if new ~= cur then d[p] = new end
                    end
                elseif d.ClassName == "UIGradient" then
                    local out, changed = {}, false
                    for i, kp in ipairs(d.Color.Keypoints) do
                        local nv = remap(kp.Value)
                        if nv ~= kp.Value then changed = true end
                        out[i] = ColorSequenceKeypoint.new(kp.Time, nv)
                    end
                    if changed then d.Color = ColorSequence.new(out) end
                end
            end
        end
    end

    resetWorldVisuals()
    if refreshThemeCards then refreshThemeCards() end
    if refreshModeRows then refreshModeRows() end
    if refreshTargetCard then refreshTargetCard() end
end

-- ══════════════════════════════════════════════
--                 SERVER HOP
-- ══════════════════════════════════════════════

local Hop = { busy = false, queue = {}, idx = 0, setStatus = function() end }

local function httpGet(url)
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if ok and type(res) == "string" and #res > 0 then return res end
    local req = (syn and syn.request) or request or http_request or (http and http.request)
    if req then
        local ok2, r = pcall(req, { Url = url, Method = "GET" })
        if ok2 and type(r) == "table" and type(r.Body) == "string" then return r.Body end
    end
    return nil
end

local function fetchServers(pages)
    local list, cursor = {}, nil
    for _ = 1, pages do
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        if cursor then url = url .. "&cursor=" .. cursor end
        local body = httpGet(url)
        local data = body and jsonDec(body)
        if not data or type(data.data) ~= "table" then break end
        for _, s in ipairs(data.data) do
            if type(s) == "table" and s.id and s.id ~= game.JobId
                and (s.playing or 0) < ((s.maxPlayers or 0) - 1) then
                table.insert(list, s)
            end
        end
        cursor = data.nextPageCursor
        if type(cursor) ~= "string" then break end
    end
    return list
end

local function hopNext()
    Hop.idx = Hop.idx + 1
    local s = Hop.queue[Hop.idx]
    if not s or Hop.idx > 6 then
        Hop.busy = false
        Hop.setStatus("No se pudo unir a ningún servidor")
        notify("Server Hop", "No se pudo unir a ningún servidor", THEME.danger)
        return
    end
    Hop.setStatus("Uniéndose… (" .. tostring(s.playing or "?") .. "/" .. tostring(s.maxPlayers or "?") .. " jugadores)")
    local ok = pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer) end)
    if not ok then task.defer(hopNext) end
end

TeleportService.TeleportInitFailed:Connect(function()
    if Hop.busy then task.delay(0.8, hopNext) end
end)

function Hop.start(mode)
    if Hop.busy then
        notify("Server Hop", "Ya hay una búsqueda en curso", THEME.warn)
        return
    end
    Hop.busy = true
    Hop.setStatus("Buscando servidores…")
    task.spawn(function()
        local list = fetchServers(mode == "low" and 3 or 2)
        if #list == 0 then
            Hop.busy = false
            Hop.setStatus("Sin servidores disponibles (¿límite de la API?)")
            notify("Server Hop", "No se encontraron servidores", THEME.danger)
            return
        end
        if mode == "low" then
            table.sort(list, function(a, b) return (a.playing or 0) < (b.playing or 0) end)
        else
            for i = #list, 2, -1 do
                local j = math.random(i)
                list[i], list[j] = list[j], list[i]
            end
        end
        Hop.queue, Hop.idx = list, 0
        hopNext()
    end)
    task.delay(40, function()
        if Hop.busy then
            Hop.busy = false
            Hop.setStatus("Tiempo de espera agotado")
        end
    end)
end

function Hop.join(jobId)
    jobId = tostring(jobId or "")
    jobId = jobId:gsub("%s+", "")
    if jobId == "" then
        notify("Server Hop", "Pega un JobId válido", THEME.warn)
        return
    end
    Hop.setStatus("Uniéndose al JobId indicado…")
    local ok = pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer) end)
    if not ok then
        Hop.setStatus("No se pudo unir a ese servidor")
        notify("Server Hop", "No se pudo unir a ese servidor", THEME.danger)
    end
end

-- ══════════════════════════════════════════════
--           WAYPOINTS / TELETRANSPORTE
-- ══════════════════════════════════════════════

local WP = { list = {}, file = FS.root .. "/waypoints.json", tween = nil }

function WP.load()
    local d = jsonDec(FS.read(WP.file))
    if d and type(d.list) == "table" then WP.list = d.list end
end

function WP.save()
    local s = jsonEnc({ list = WP.list })
    if s then FS.write(WP.file, s) end
end

function WP.forPlace()
    local out = {}
    for _, e in ipairs(WP.list) do
        if e.place == game.PlaceId then table.insert(out, e) end
    end
    return out
end

function WP.add(name, pos)
    table.insert(WP.list, {
        name = name, place = game.PlaceId,
        x = math.floor(pos.X * 10) / 10, y = math.floor(pos.Y * 10) / 10, z = math.floor(pos.Z * 10) / 10,
    })
    WP.save()
end

function WP.remove(entry)
    for i, e in ipairs(WP.list) do
        if e == entry then table.remove(WP.list, i) break end
    end
    WP.save()
end

function WP.teleport(pos)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        notify("Teletransporte", "Tu personaje no está disponible", THEME.danger)
        return
    end
    if WP.tween then WP.tween:Cancel(); WP.tween = nil end
    local goal = CFrame.new(pos + Vector3.new(0, 3, 0))
    if X.tpMode == "instant" then
        hrp.CFrame = goal
        hrp.AssemblyLinearVelocity = Vector3.zero
        return
    end
    local dist = (hrp.Position - goal.Position).Magnitude
    local tw = TweenService:Create(hrp, TweenInfo.new(math.max(dist / X.tpSpeed, 0.05), Enum.EasingStyle.Linear), { CFrame = goal })
    WP.tween = tw
    local hold = RunService.Heartbeat:Connect(function()
        if hrp.Parent then hrp.AssemblyLinearVelocity = Vector3.zero end
    end)
    tw.Completed:Connect(function()
        hold:Disconnect()
        if WP.tween == tw then WP.tween = nil end
    end)
    tw:Play()
end

WP.load()

-- ══════════════════════════════════════════════
--              ATAJOS (KEYBINDS)
-- ══════════════════════════════════════════════

local KB = {
    binds = { hub = { t = "K", n = "RightControl" } },
    listening = nil, actions = {}, labels = {},
}

function KB.text(b)
    if not b then return "Sin asignar" end
    if b.t == "K" then return b.n end
    if b.n == "MouseButton2" then return "Clic derecho" end
    if b.n == "MouseButton3" then return "Clic central" end
    return b.n
end

function KB.matches(b, input)
    if not b then return false end
    if b.t == "K" then
        return input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == b.n
    end
    return input.UserInputType.Name == b.n
end

function KB.assign(key, b)
    if key == "hub" and not b then
        notify("Atajos", "El atajo del Hub no se puede quitar", THEME.warn)
        KB.listening = nil
        if refreshBindRows then refreshBindRows() end
        return
    end
    if b then
        for k, other in pairs(KB.binds) do
            if k ~= key and other.t == b.t and other.n == b.n then
                KB.binds[k] = nil
                notify("Atajos", "Se quitó el atajo repetido de " .. (KB.labels[k] or k), THEME.warn)
            end
        end
    end
    KB.binds[key] = b
    KB.listening = nil
    if refreshBindRows then refreshBindRows() end
end

-- ══════════════════════════════════════════════
--           PERFILES (CONFIG SAVER)
-- ══════════════════════════════════════════════

local Prof = { dir = FS.root .. "/profiles", autoFile = FS.root .. "/autoload.txt" }

function Prof.collect()
    local data = {
        v = 4, theme = X.theme, hitbox = currentMode.key, moon = X.learnedFull,
        toggles = {}, sliders = {}, segments = {}, keybinds = {},
    }
    for k, o in pairs(CFG.toggles) do data.toggles[k] = o.get() end
    for k, o in pairs(CFG.sliders) do data.sliders[k] = o.get() end
    for k, o in pairs(CFG.segments) do data.segments[k] = o.get() end
    for k, b in pairs(KB.binds) do data.keybinds[k] = { t = b.t, n = b.n } end
    return data
end

function Prof.apply(data)
    if type(data) ~= "table" then return false end
    if type(data.theme) == "string" and data.theme ~= X.theme then
        for _, d in ipairs(THEME_LIST) do
            if d.name == data.theme then applyTheme(d) end
        end
    end
    if type(data.moon) == "string" then X.learnedFull = data.moon end
    if type(data.toggles) == "table" then
        for k, v in pairs(data.toggles) do
            local o = CFG.toggles[k]
            if o and type(v) == "boolean" then o.set(v, true, true) end
        end
    end
    if type(data.sliders) == "table" then
        for k, v in pairs(data.sliders) do
            local o = CFG.sliders[k]
            if o and type(v) == "number" then o.set(v) end
        end
    end
    if type(data.segments) == "table" then
        for k, v in pairs(data.segments) do
            local o = CFG.segments[k]
            if o then o.set(v) end
        end
    end
    if type(data.hitbox) == "string" and selectMode then
        for i, m in ipairs(MODES) do
            if m.key == data.hitbox then selectMode(i, false) end
        end
    end
    if type(data.keybinds) == "table" then
        local fresh = {}
        for k, b in pairs(data.keybinds) do
            if KB.labels[k] and type(b) == "table" and (b.t == "K" or b.t == "M") and type(b.n) == "string" then
                fresh[k] = { t = b.t, n = b.n }
            end
        end
        if not fresh.hub then fresh.hub = { t = "K", n = "RightControl" } end
        KB.binds = fresh
        if refreshBindRows then refreshBindRows() end
    end
    return true
end

function Prof.names()
    local out = {}
    for _, p in ipairs(FS.list(Prof.dir)) do
        local n = tostring(p):match("([^/\\]+)%.json$")
        if n then table.insert(out, n) end
    end
    table.sort(out, function(a, b) return a:lower() < b:lower() end)
    return out
end

function Prof.save(name)
    name = cleanName(name)
    if name == "" then return false, "Escribe un nombre válido" end
    local s = jsonEnc(Prof.collect())
    if not s then return false, "No se pudo serializar la configuración" end
    if not FS.write(Prof.dir .. "/" .. name .. ".json", s) then return false, "No se pudo escribir el archivo" end
    return true, name
end

function Prof.load(name)
    local data = jsonDec(FS.read(Prof.dir .. "/" .. cleanName(name) .. ".json"))
    if not data then return false end
    return Prof.apply(data)
end

function Prof.delete(name)
    FS.delete(Prof.dir .. "/" .. cleanName(name) .. ".json")
end

function Prof.autoload()
    return cleanName(FS.read(Prof.autoFile) or "")
end

function Prof.setAutoload(name)
    FS.write(Prof.autoFile, name or "")
end

-- ══════════════════════════════════════════════
--          ALERTAS (BANNER + SONIDO + TOAST)
-- ══════════════════════════════════════════════

local Alerts = {}
do
    local snd = Instance.new("Sound")
    snd.Name = "RZoneAlert"
    snd.SoundId = BF.alertSound
    snd.Volume = 0.8
    snd.Parent = SoundService
    local current = nil

    function Alerts.play()
        if not X.alertSound then return end
        pcall(function()
            snd.Volume = X.alertVolume
            snd:Stop()
            snd:Play()
        end)
    end

    function Alerts.banner(title, sub, color)
        if not X.alertBanner then return end
        if current then current:Destroy(); current = nil end
        local f = create("Frame", {
            Name = "RZoneBanner", Size = UDim2.new(0, 420, 0, 70), AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, -100), BackgroundColor3 = THEME.panel,
            BorderSizePixel = 0, ZIndex = 700,
        }, screenGui)
        applyCorner(f, 14)
        applyStroke(f, color, 2, 0)
        create("Frame", {
            Size = UDim2.new(0, 6, 1, -20), Position = UDim2.new(0, 10, 0, 10),
            BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 701,
        }, f)
        local t1 = label(f, title, 18, Enum.Font.GothamBlack, THEME.text)
        t1.Size = UDim2.new(1, -40, 0, 26); t1.Position = UDim2.new(0, 28, 0, 10); t1.ZIndex = 701
        local t2 = label(f, sub, 12, Enum.Font.GothamMedium, THEME.muted)
        t2.Size = UDim2.new(1, -40, 0, 18); t2.Position = UDim2.new(0, 28, 0, 40); t2.ZIndex = 701
        current = f
        tween(f, { Position = UDim2.new(0.5, 0, 0, 16) }, 0.4, Enum.EasingStyle.Back)
        task.delay(6, function()
            if f and f.Parent then
                tween(f, { Position = UDim2.new(0.5, 0, 0, -100) }, 0.3)
                task.wait(0.35)
                if f then f:Destroy() end
                if current == f then current = nil end
            end
        end)
    end

    function Alerts.fire(title, sub, color)
        notify(title, sub, color, 5)
        Alerts.banner(title, sub, color)
        Alerts.play()
    end
end

-- ══════════════════════════════════════════════
--     ESCÁNER DEL MUNDO (LUNA · ESPEJISMO · EVENTOS ·
--      FRUTAS · FLORES · BOSSES · COFRES)
-- ══════════════════════════════════════════════

local World = {
    fruits = {}, flowers = {}, events = {}, mirage = nil, bosses = {}, nextId = 0,
    moon = { id = "", num = "", name = "—", icon = "🌙", night = false, full = false,
             fullSince = nil, msgAt = -1000, texFull = false },
}

local scanWorld
do
    local tags = {}
    local scanCount = 0
    local prev = { mirage = false, full = false }

    local function adorneeOf(obj)
        if obj:IsA("BasePart") then return obj end
        if obj:IsA("Tool") then
            local h = obj:FindFirstChild("Handle")
            if h and h:IsA("BasePart") then return h end
        end
        if obj:IsA("Model") then
            local hrp = obj:FindFirstChild("HumanoidRootPart")
            if hrp and hrp:IsA("BasePart") then return hrp end
            if obj.PrimaryPart then return obj.PrimaryPart end
        end
        for _, d in ipairs(obj:GetDescendants()) do
            if d:IsA("BasePart") then return d end
        end
        return nil
    end

    local function pivotPos(obj)
        local ok, cf = pcall(function() return obj:GetPivot() end)
        if ok and cf then return cf.Position end
        local p = adorneeOf(obj)
        return p and p.Position or nil
    end

    local function classify(obj)
        if not (obj:IsA("Tool") or obj:IsA("Model") or obj:IsA("BasePart")) then return nil end
        local n = obj.Name
        if obj:IsA("Tool") then
            if n:find(BF.fruitPattern) then return "fruit" end
        elseif n:find(BF.fruitPattern .. "$") then
            return "fruit"
        end
        if n:match(BF.chestPattern) then return "chest" end
        if n:match(BF.flowerPattern) then return "flower" end
        return nil
    end

    local function chestInfo(obj)
        local tier = obj.Name:match("%d+")
        local info = BF.chestTiers[tier or ""] or { "Cofre", Color3.fromRGB(255, 205, 60) }
        return "📦 " .. info[1], info[2]
    end

    local function flowerInfo(obj, part)
        local best, bestScore = nil, -1
        local function consider(p)
            if p:IsA("BasePart") then
                local _, s, v = p.Color:ToHSV()
                local score = s * v
                if score > bestScore then best, bestScore = p.Color, score end
            end
        end
        consider(part)
        if obj:IsA("Model") then
            for _, d in ipairs(obj:GetDescendants()) do consider(d) end
        end
        local color = best or Color3.fromRGB(255, 160, 220)
        local h = color:ToHSV()
        local name = "Flor"
        if h > 0.5 and h < 0.72 then name = "Flor Azul"
        elseif h < 0.04 or h > 0.94 then name = "Flor Roja"
        elseif h > 0.1 and h < 0.2 then name = "Flor Amarilla" end
        return name, color
    end

    local function matchesDef(def, obj)
        if not (obj:IsA("Model") or obj:IsA("BasePart")) then return false end
        local n = obj.Name
        if def.exclude then
            for _, p in ipairs(def.exclude) do
                if n:find(p) then return false end
            end
        end
        if not def.patterns then return true end
        for _, p in ipairs(def.patterns) do
            if n:find(p) then return true end
        end
        return false
    end

    local function makeTag(part)
        local gui = Instance.new("BillboardGui")
        gui.Name = "RZoneItemTag"
        gui.Size = UDim2.new(0, 230, 0, 22)
        gui.Adornee = part
        gui.AlwaysOnTop = true
        gui.StudsOffset = Vector3.new(0, 3, 0)
        local lbl = Instance.new("TextLabel", gui)
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
        lbl.BackgroundTransparency = 0.3
        lbl.TextColor3 = Color3.new(1, 1, 1)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 11
        lbl.BorderSizePixel = 0
        applyCorner(lbl, 11)
        gui.Parent = part
        return { gui = gui, label = lbl, part = part }
    end

    local function isShown(d)
        local cur = d
        while cur and cur:IsA("GuiObject") do
            if not cur.Visible then return false end
            cur = cur.Parent
        end
        return d.TextTransparency < 0.95
    end

    -- Detecta el aviso en pantalla de la luna llena (independiente de las texturas)
    local function fullMoonMessage()
        for _, g in ipairs(PlayerGui:GetChildren()) do
            if g ~= screenGui and g ~= overlayGui then
                for _, d in ipairs(g:GetDescendants()) do
                    if d:IsA("TextLabel") and #d.Text > 8 and #d.Text < 160 then
                        local low = d.Text:lower()
                        for _, p in ipairs(BF.messages.fullmoon) do
                            if low:find(p, 1, true) and isShown(d) then return true end
                        end
                    end
                end
            end
        end
        return false
    end

    local function updateMoon(now, withMsg)
        local m = World.moon
        local sky = Lighting:FindFirstChildOfClass("Sky")
        local id = sky and tostring(sky.MoonTextureId) or ""
        local num = id:match("%d+") or ""
        m.id, m.num = id, num
        local info = BF.moonPhases[num]
        local texFull = (info ~= nil and info[3] == true) or (X.learnedFull ~= "" and num == X.learnedFull)
        local t = Lighting.ClockTime
        m.night = (t >= 18 or t < 5.5)

        if withMsg and fullMoonMessage() and (now - m.msgAt) > 120 then
            m.msgAt, m.fullSince = now, now
            if num ~= "" then X.learnedFull = num end
            texFull = true
        end

        local active = (m.fullSince ~= nil and (now - m.fullSince) < BF.fullMoonDuration) or (texFull and m.night)
        if info then
            m.name, m.icon = info[1], info[2]
        elseif texFull then
            m.name, m.icon = "Luna llena", "🌕"
        else
            m.name, m.icon = "Fase desconocida", "🌙"
        end
        m.texFull = texFull

        if active and not prev.full and X.notifMoon then
            Alerts.fire("🌕 ¡Luna Llena!", "La luna llena está activa en este servidor", rgb(255, 235, 140))
        end
        m.full = active
        prev.full = active
    end

    scanWorld = function()
        local now = os.clock()
        scanCount = scanCount + 1
        local myChar = LocalPlayer.Character
        local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local myPos = myHrp and myHrp.Position
        local function dist(p)
            if myPos and p then return math.floor((p - myPos).Magnitude) end
            return 0
        end
        local want = {}
        local function add(obj, part, text, color)
            want[obj] = { part = part, text = text, color = color }
        end

        updateMoon(now, scanCount % 2 == 1)

        local rootKids = workspace:GetChildren()

        -- Cofres / frutas / flores
        local fruitsNow, flowersNow = {}, {}
        local function chestAdd(obj)
            if not X.chestEsp then return end
            local part = adorneeOf(obj)
            if part then
                local text, color = chestInfo(obj)
                add(obj, part, text .. "  ·  " .. dist(part.Position) .. "m", color)
            end
        end
        for _, obj in ipairs(rootKids) do
            local kind = classify(obj)
            if kind == "chest" then
                chestAdd(obj)
            elseif kind == "fruit" then
                local part = adorneeOf(obj)
                if part then fruitsNow[obj] = part end
            elseif kind == "flower" then
                local part = adorneeOf(obj)
                if part then flowersNow[obj] = part end
            end
        end
        if X.chestEsp then
            local cm = workspace:FindFirstChild("ChestModels")
            if cm then
                for _, obj in ipairs(cm:GetChildren()) do chestAdd(obj) end
            end
            local ok, tagged = pcall(function() return CollectionService:GetTagged(BF.chestTag) end)
            if ok and type(tagged) == "table" then
                for _, obj in ipairs(tagged) do
                    if obj.Parent then chestAdd(obj) end
                end
            end
        end

        -- Frutas (con temporizador de despawn aproximado)
        for obj, part in pairs(fruitsNow) do
            local e = World.fruits[obj]
            if not e then
                World.nextId = World.nextId + 1
                e = { id = World.nextId, seen = now, name = obj.Name }
                World.fruits[obj] = e
                if X.notifFruit then
                    Alerts.fire("🍎 Fruta detectada", obj.Name .. "  ·  " .. dist(part.Position) .. "m", rgb(255, 120, 200))
                end
            end
            e.part = part
            if X.fruitEsp then
                local rem = BF.fruitDespawn - (now - e.seen)
                local timer = "⏳ por expirar"
                if rem > 0 then timer = string.format("⏳ ~%d:%02d", math.floor(rem / 60), math.floor(rem) % 60) end
                add(obj, part, "🍎 " .. obj.Name .. "  ·  " .. dist(part.Position) .. "m  ·  " .. timer, rgb(255, 120, 200))
            end
        end
        for obj in pairs(World.fruits) do
            if not fruitsNow[obj] then World.fruits[obj] = nil end
        end

        -- Flores (Raza V2)
        for obj, part in pairs(flowersNow) do
            local e = World.flowers[obj]
            local lbl, col = flowerInfo(obj, part)
            if not e then
                World.nextId = World.nextId + 1
                e = { id = World.nextId, name = obj.Name }
                World.flowers[obj] = e
                if X.notifFruit then
                    notify("🌸 " .. lbl .. " detectada", obj.Name .. "  ·  " .. dist(part.Position) .. "m", col, 4)
                end
            end
            e.part, e.label, e.color = part, lbl, col
            if X.flowerEsp then
                add(obj, part, "🌸 " .. lbl .. "  ·  " .. dist(part.Position) .. "m  (" .. obj.Name .. ")", col)
            end
        end
        for obj in pairs(World.flowers) do
            if not flowersNow[obj] then World.flowers[obj] = nil end
        end

        -- Eventos marinos
        local eventsNow = {}
        for _, def in ipairs(BF.seaEvents) do
            for _, cname in ipairs(def.containers) do
                local kids
                if cname == "" then
                    kids = rootKids
                else
                    local folder = workspace:FindFirstChild(cname)
                    kids = folder and folder:GetChildren() or {}
                end
                for _, obj in ipairs(kids) do
                    if not eventsNow[obj] and matchesDef(def, obj) then
                        local hum = obj:FindFirstChildOfClass("Humanoid")
                        if not hum or hum.Health > 0 then
                            local part = adorneeOf(obj)
                            if part then eventsNow[obj] = { def = def, part = part } end
                        end
                    end
                end
            end
        end
        for obj, info in pairs(eventsNow) do
            local e = World.events[obj]
            if not e then
                World.nextId = World.nextId + 1
                e = { id = World.nextId }
                World.events[obj] = e
                if X.notifSea then
                    Alerts.fire(info.def.icon .. " " .. info.def.label, "Detectado a " .. dist(info.part.Position) .. "m", info.def.color)
                end
            end
            e.def, e.part = info.def, info.part
            if X.seaEsp then
                add(obj, info.part, info.def.icon .. " " .. info.def.label .. "  ·  " .. dist(info.part.Position) .. "m", info.def.color)
            end
        end
        for obj in pairs(World.events) do
            if not eventsNow[obj] then World.events[obj] = nil end
        end

        -- Isla Espejismo
        local function findMirage(kids)
            for _, c in ipairs(kids) do
                for _, p in ipairs(BF.miragePatterns) do
                    if c.Name:find(p) then return c end
                end
            end
            return nil
        end
        local mirageObj = nil
        local map = workspace:FindFirstChild("Map")
        if map then mirageObj = findMirage(map:GetChildren()) end
        if not mirageObj then mirageObj = findMirage(rootKids) end
        if mirageObj then
            local pos = pivotPos(mirageObj)
            local part = adorneeOf(mirageObj)
            World.mirage = { obj = mirageObj, pos = pos, part = part }
            if not prev.mirage and X.notifMirage then
                Alerts.fire("🏝 ¡Isla Espejismo!", "Apareció en el servidor  ·  " .. dist(pos) .. "m", rgb(120, 230, 255))
            end
            if X.seaEsp and part then
                add(mirageObj, part, "🏝 Isla Espejismo  ·  " .. dist(pos) .. "m", rgb(120, 230, 255))
            end
            prev.mirage = true
        else
            World.mirage = nil
            prev.mirage = false
        end

        -- Bosses (estado de spawn)
        local list = BF.bosses[game.PlaceId]
        if list then
            local enemies = workspace:FindFirstChild("Enemies")
            local byName = {}
            if enemies then
                for _, m in ipairs(enemies:GetChildren()) do
                    local k = m.Name:lower()
                    if not byName[k] then byName[k] = m end
                end
            end
            for _, name in ipairs(list) do
                local b = World.bosses[name]
                if not b then
                    b = { state = "unknown" }
                    World.bosses[name] = b
                end
                local m = byName[name:lower()]
                local hum = m and m:FindFirstChildOfClass("Humanoid")
                local part = m and adorneeOf(m)
                if m and hum and hum.Health > 0 and part then
                    if b.state == "dead" and X.notifBoss then
                        Alerts.fire("👑 Boss disponible", name .. "  ·  " .. dist(part.Position) .. "m", rgb(255, 200, 60))
                    end
                    b.state, b.part, b.pos, b.deadAt = "alive", part, part.Position, nil
                    if hum.MaxHealth > 0 then b.hp = hum.Health / hum.MaxHealth else b.hp = 1 end
                    if X.bossEsp then
                        add(m, part, "👑 " .. name .. "  ·  HP " .. math.floor(b.hp * 100) .. "%  ·  " .. dist(part.Position) .. "m", rgb(255, 200, 60))
                    end
                else
                    if b.state == "alive" then b.deadAt = now end
                    b.state, b.part, b.pos = "dead", nil, nil
                end
            end
        end

        -- Etiquetas 3D
        for obj, w in pairs(want) do
            local t = tags[obj]
            if not t or not t.gui.Parent or t.part ~= w.part then
                if t then t.gui:Destroy() end
                t = makeTag(w.part)
                tags[obj] = t
            end
            t.label.Text = w.text
            t.label.TextColor3 = w.color
        end
        for obj, t in pairs(tags) do
            if not want[obj] then
                t.gui:Destroy()
                tags[obj] = nil
            end
        end
    end
end

-- ══════════════════════════════════════════════
--        BRÚJULA DE EVENTOS (dirección + distancia)
-- ══════════════════════════════════════════════

local updateCompass
do
    local MAXROWS = 6
    local frame = create("Frame", {
        Name = "Compass", Size = UDim2.new(0, 240, 0, 60), Position = UDim2.new(1, -262, 0, 130),
        BackgroundColor3 = THEME.bg, BackgroundTransparency = 0.15, BorderSizePixel = 0,
        Visible = false, Active = true,
    }, overlayGui)
    applyCorner(frame, 12)
    applyStroke(frame, THEME.accent, 1.5, 0.25)

    local title = label(frame, "🧭  EVENTOS", 10, Enum.Font.GothamBlack, THEME.accent2)
    title.Size = UDim2.new(1, -20, 0, 16); title.Position = UDim2.new(0, 12, 0, 8)

    local rows = {}
    for i = 1, MAXROWS do
        local rf = create("Frame", {
            Size = UDim2.new(1, -16, 0, 24), Position = UDim2.new(0, 8, 0, 28 + (i - 1) * 26),
            BackgroundTransparency = 1, Visible = false,
        }, frame)
        local arrow = create("TextLabel", {
            Size = UDim2.new(0, 22, 0, 22), Position = UDim2.new(0, 0, 0, 1), BackgroundTransparency = 1,
            Text = "▲", TextColor3 = THEME.accent2, Font = Enum.Font.GothamBlack, TextSize = 16,
        }, rf)
        local name = label(rf, "", 11, Enum.Font.GothamBold, THEME.text)
        name.Size = UDim2.new(1, -90, 1, 0); name.Position = UDim2.new(0, 28, 0, 0)
        name.TextTruncate = Enum.TextTruncate.AtEnd
        local dst = label(rf, "", 11, Enum.Font.GothamBold, THEME.accent2, Enum.TextXAlignment.Right)
        dst.Size = UDim2.new(0, 56, 1, 0); dst.Position = UDim2.new(1, -56, 0, 0)
        rows[i] = { frame = rf, arrow = arrow, name = name, dist = dst }
    end

    updateCompass = function()
        if not X.compass then
            if frame.Visible then frame.Visible = false end
            return
        end
        local cam = workspace.CurrentCamera
        local char = LocalPlayer.Character
        local myHrp = char and char:FindFirstChild("HumanoidRootPart")
        if not cam or not myHrp then return end

        local list = {}
        local function add(text, pos, color)
            if pos then
                list[#list + 1] = { text = text, pos = pos, color = color, d = (pos - myHrp.Position).Magnitude }
            end
        end
        if World.mirage then add("🏝 Isla Espejismo", World.mirage.pos, rgb(120, 230, 255)) end
        for _, e in pairs(World.events) do
            if e.part and e.part.Parent then add(e.def.icon .. " " .. e.def.label, e.part.Position, e.def.color) end
        end
        for _, f in pairs(World.fruits) do
            if f.part and f.part.Parent then add("🍎 " .. f.name, f.part.Position, rgb(255, 120, 200)) end
        end
        if X.flowerEsp then
            for _, f in pairs(World.flowers) do
                if f.part and f.part.Parent then add("🌸 " .. (f.label or "Flor"), f.part.Position, f.color or rgb(255, 160, 220)) end
            end
        end
        table.sort(list, function(a, b) return a.d < b.d end)

        if #list == 0 then
            if frame.Visible then frame.Visible = false end
            return
        end
        if not frame.Visible then frame.Visible = true end

        local look = cam.CFrame.LookVector
        local fwd = Vector3.new(look.X, 0, look.Z)
        if fwd.Magnitude < 0.001 then fwd = Vector3.new(0, 0, -1) else fwd = fwd.Unit end
        local right = fwd:Cross(Vector3.new(0, 1, 0))

        local n = math.min(#list, MAXROWS)
        frame.Size = UDim2.new(0, 240, 0, 34 + n * 26)
        for i = 1, MAXROWS do
            local r = rows[i]
            if i <= n then
                local it = list[i]
                local dv = it.pos - myHrp.Position
                r.frame.Visible = true
                r.arrow.Rotation = math.deg(math.atan2(dv:Dot(right), dv:Dot(fwd)))
                r.arrow.TextColor3 = it.color
                r.name.Text = it.text
                r.dist.Text = math.floor(it.d) .. "m"
            else
                r.frame.Visible = false
            end
        end
    end

    local dragging, dragStart, startPos = false, nil, nil
    frame.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = i.Position; startPos = frame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
end

-- ══════════════════════════════════════════════
--   AUTOMATIZACIÓN: STATS · MAESTRÍA · DIÁLOGOS
-- ══════════════════════════════════════════════

local Ext = {}

function Ext.points()
    local d = LocalPlayer:FindFirstChild("Data")
    local p = d and d:FindFirstChild("Points")
    if not p then return nil end
    local ok, v = pcall(function() return p.Value end)
    if ok and type(v) == "number" then return v end
    return nil
end

function Ext.addPoints(stat, amount)
    local rs = ReplicatedStorage:FindFirstChild("Remotes")
    local comm = rs and rs:FindFirstChild("CommF_")
    if not comm then return false end
    local ok = pcall(function() return comm:InvokeServer("AddPoint", stat, amount) end)
    return ok
end

function Ext.assignNow(auto)
    local pts = Ext.points()
    if not pts or pts <= 0 then
        if not auto then notify("Auto-Stats", "No tienes puntos disponibles", THEME.warn) end
        return
    end
    local key = BF.statKeys[X.statChoice] or "Melee"
    task.spawn(function()
        local ok = Ext.addPoints(key, pts)
        if ok then
            notify("📈 Puntos asignados", pts .. " → " .. X.statChoice, THEME.ok, 1.8)
        else
            notify("Auto-Stats", "No se pudo asignar (¿no se encontró Remotes.CommF_?)", THEME.danger, 3)
            if auto then
                local t = CFG.toggles.autoStats
                if t then t.set(false, true) end
            end
        end
    end)
end

task.spawn(function()
    while true do
        task.wait(1.2)
        if X.autoStats then pcall(Ext.assignNow, true) end
    end
end)

-- Auto-equipar según la vida del enemigo (maestría)
function Ext.equip(tip)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return false, false end
    local cur = char:FindFirstChildOfClass("Tool")
    if cur and cur.ToolTip == tip then return true, false end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return false, false end
    for _, t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") and t.ToolTip == tip then
            hum:EquipTool(t)
            return true, true
        end
    end
    return false, false
end

task.spawn(function()
    local lastSwitch = 0
    while true do
        task.wait(0.2)
        if X.mastery then
            pcall(function()
                local char = LocalPlayer.Character
                local myHrp = char and char:FindFirstChild("HumanoidRootPart")
                local enemies = workspace:FindFirstChild("Enemies")
                if not myHrp or not enemies then return end
                local low, any = false, false
                local thr = X.masteryHp / 100
                for _, e in ipairs(enemies:GetChildren()) do
                    local hum = e:FindFirstChildOfClass("Humanoid")
                    local hrp = e:FindFirstChild("HumanoidRootPart")
                    if hum and hrp and hum.Health > 0 and hum.MaxHealth > 0
                        and (hrp.Position - myHrp.Position).Magnitude <= X.masteryRange then
                        any = true
                        if hum.Health / hum.MaxHealth <= thr then
                            low = true
                            break
                        end
                    end
                end
                if os.clock() - lastSwitch < 0.35 then return end
                local tip = nil
                if low then
                    tip = BF.toolTips[X.masteryType]
                elseif any and X.mainType ~= "None" then
                    tip = BF.toolTips[X.mainType]
                end
                if tip then
                    local _, switched = Ext.equip(tip)
                    if switched then lastSwitch = os.clock() end
                end
            end)
        end
    end
end)

-- Diálogos rápidos / aceptar misiones (busca botones dentro de BF.dialog.roots)
do
    local function resolve(path)
        local cur = PlayerGui
        for part in path:gmatch("[^%.]+") do
            cur = cur and cur:FindFirstChild(part)
            if not cur then return nil end
        end
        return cur
    end

    local function excluded(inst)
        local cur = inst
        while cur and cur ~= PlayerGui do
            for _, p in ipairs(BF.dialog.exclude) do
                if cur.Name:find(p) then return true end
            end
            cur = cur.Parent
        end
        return false
    end

    local function shown(inst)
        local cur = inst
        while cur and cur:IsA("GuiObject") do
            if not cur.Visible then return false end
            cur = cur.Parent
        end
        return true
    end

    local function btnText(btn)
        local t = btn.Text
        if t == "" then
            for _, c in ipairs(btn:GetChildren()) do
                if c:IsA("TextLabel") and c.Text ~= "" then t = c.Text break end
            end
        end
        t = t:lower()
        t = t:gsub("^%s+", "")
        t = t:gsub("%s+$", "")
        t = t:gsub("[%.!>]+$", "")
        return t
    end

    local function inSet(set, txt)
        for _, w in ipairs(set) do
            if txt == w then return true end
        end
        return false
    end

    function Ext.click(btn)
        local fired = false
        if type(firesignal) == "function" then
            fired = pcall(firesignal, btn.MouseButton1Click)
        end
        if not fired and type(getconnections) == "function" then
            local ok, conns = pcall(getconnections, btn.MouseButton1Click)
            if ok and type(conns) == "table" then
                for _, c in ipairs(conns) do
                    pcall(function() c:Fire() end)
                    fired = true
                end
            end
        end
        if not fired then
            local gui = btn:FindFirstAncestorOfClass("ScreenGui")
            local inset = Vector2.new(0, 0)
            if not (gui and gui.IgnoreGuiInset) then inset = GuiService:GetGuiInset() end
            local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2 + inset
            VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
            task.wait(0.03)
            VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
        end
    end

    task.spawn(function()
        local lastClick = 0
        while true do
            task.wait(0.25)
            if X.fastDialog or X.autoAccept then
                pcall(function()
                    if os.clock() - lastClick < 0.5 then return end
                    for _, path in ipairs(BF.dialog.roots) do
                        local root = resolve(path)
                        if root and ((not root:IsA("GuiObject")) or root.Visible) then
                            for _, d in ipairs(root:GetDescendants()) do
                                if d:IsA("TextButton") and d.Visible and shown(d) and not excluded(d) then
                                    local txt = btnText(d)
                                    local hit = (X.fastDialog and inSet(BF.dialog.skip, txt))
                                        or (X.autoAccept and inSet(BF.dialog.accept, txt))
                                    if hit then
                                        lastClick = os.clock()
                                        Ext.click(d)
                                        return
                                    end
                                end
                            end
                        end
                    end
                end)
            end
        end
    end)
end

-- ══════════════════════════════════════════════
--      RENDIMIENTO (FPS BOOSTER / GRÁFICOS BAJOS)
-- ══════════════════════════════════════════════

local Perf = { saved = {}, tracked = setmetatable({}, { __mode = "k" }), conn = nil, prevCap = 0 }
do
    local EMITTERS = { ParticleEmitter = true, Trail = true, Beam = true, Smoke = true, Fire = true, Sparkles = true }

    function Perf.setParticles(on)
        if on then
            task.spawn(function()
                local n = 0
                for _, d in ipairs(workspace:GetDescendants()) do
                    if not X.noParticles then return end
                    if EMITTERS[d.ClassName] then
                        local ok, en = pcall(function() return d.Enabled end)
                        if ok and en then
                            Perf.tracked[d] = true
                            pcall(function() d.Enabled = false end)
                        end
                    end
                    n = n + 1
                    if n % 1500 == 0 then task.wait() end
                end
            end)
            if not Perf.conn then
                Perf.conn = workspace.DescendantAdded:Connect(function(d)
                    if X.noParticles and EMITTERS[d.ClassName] then
                        task.defer(function()
                            if d.Parent then
                                Perf.tracked[d] = true
                                pcall(function() d.Enabled = false end)
                            end
                        end)
                    end
                end)
            end
        else
            if Perf.conn then Perf.conn:Disconnect(); Perf.conn = nil end
            for d in pairs(Perf.tracked) do
                if d.Parent then pcall(function() d.Enabled = true end) end
            end
            Perf.tracked = setmetatable({}, { __mode = "k" })
        end
    end

    function Perf.setGfx(on)
        local T = workspace:FindFirstChildOfClass("Terrain")
        local s = Perf.saved
        if on then
            if s.gfx then return end
            s.gfx = true
            s.shadows = Lighting.GlobalShadows
            s.fx = {}
            for _, e in ipairs(Lighting:GetChildren()) do
                if e:IsA("BloomEffect") or e:IsA("BlurEffect") or e:IsA("SunRaysEffect") or e:IsA("DepthOfFieldEffect") then
                    s.fx[e] = e.Enabled
                    e.Enabled = false
                end
            end
            Lighting.GlobalShadows = false
            if T then
                s.water = { T.WaterWaveSize, T.WaterWaveSpeed, T.WaterReflectance }
                pcall(function()
                    T.WaterWaveSize = 0
                    T.WaterWaveSpeed = 0
                    T.WaterReflectance = 0
                end)
                local okd, dec = pcall(function() return T.Decoration end)
                if okd then
                    s.decoration = dec
                    pcall(function() T.Decoration = false end)
                end
            end
            local okq, q = pcall(function() return settings().Rendering.QualityLevel end)
            if okq then
                s.quality = q
                pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
            end
        else
            if not s.gfx then return end
            s.gfx = nil
            if s.shadows ~= nil then Lighting.GlobalShadows = s.shadows end
            for e, en in pairs(s.fx or {}) do
                if e.Parent then e.Enabled = en end
            end
            if T and s.water then
                pcall(function()
                    T.WaterWaveSize, T.WaterWaveSpeed, T.WaterReflectance = s.water[1], s.water[2], s.water[3]
                end)
                if s.decoration ~= nil then pcall(function() T.Decoration = s.decoration end) end
            end
            if s.quality then
                pcall(function() settings().Rendering.QualityLevel = s.quality end)
            end
            Perf.saved = {}
        end
    end

    function Perf.setCap(on)
        if type(setfpscap) ~= "function" then return end
        if on then
            if type(getfpscap) == "function" then
                local ok, c = pcall(getfpscap)
                if ok and type(c) == "number" then Perf.prevCap = c end
            end
            pcall(setfpscap, 60)
        else
            pcall(setfpscap, Perf.prevCap)
        end
    end
end

-- ══════════════════════════════════════════════
--          PANTALLA DE BIENVENIDA
-- ══════════════════════════════════════════════

do
    local welcomeFrame = create("CanvasGroup", {
        Size = UDim2.new(0, 420, 0, 280),
        Position = UDim2.new(0.5, -210, 0.5, -140),
        BackgroundColor3 = THEME.bg, BorderSizePixel = 0, ZIndex = 2000,
    }, screenGui)
    applyCorner(welcomeFrame, 16)
    applyStroke(welcomeFrame, THEME.accent, 2, 0.1)
    applyGradient(welcomeFrame, THEME.heroTop, THEME.heroBottom, 135)

    create("ImageLabel", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        Image = "rbxassetid://136783036634973", ScaleType = Enum.ScaleType.Crop,
        ImageTransparency = 0.88,
    }, welcomeFrame)

    create("ImageLabel", {
        Size = UDim2.new(0, 72, 0, 72), Position = UDim2.new(0.5, -36, 0, 22),
        BackgroundTransparency = 1, Image = LOGO_ID,
    }, welcomeFrame)

    local title = label(welcomeFrame, "BIENVENIDO, " .. LocalPlayer.Name:upper() .. "!", 19, Enum.Font.GothamBlack, THEME.text, Enum.TextXAlignment.Center)
    title.Size = UDim2.new(1, -20, 0, 30)
    title.Position = UDim2.new(0, 10, 0, 106)
    applyGradient(title, THEME.accent, THEME.accent2, 0)
    title.TextColor3 = Color3.new(1, 1, 1)

    local sub = label(welcomeFrame, "Estado: ✅ Seguro   •   Versión: 3.4.0 Pro\nCreador: R_Zone   •   " .. BF.sea .. "   •   HUB Cargado", 12, Enum.Font.GothamMedium, THEME.muted, Enum.TextXAlignment.Center)
    sub.Size = UDim2.new(1, -40, 0, 44)
    sub.Position = UDim2.new(0, 20, 0, 146)
    sub.TextWrapped = true

    local track = create("Frame", {
        Size = UDim2.new(1, -80, 0, 4), Position = UDim2.new(0, 40, 1, -56),
        BackgroundColor3 = THEME.card, BorderSizePixel = 0,
    }, welcomeFrame)
    applyCorner(track, 2)
    local fill = create("Frame", {
        Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
    }, track)
    applyCorner(fill, 2)
    applyGradient(fill, THEME.accent, THEME.accent2, 0)

    local ptext = label(welcomeFrame, "Cargando módulos…", 10, Enum.Font.Gotham, THEME.muted, Enum.TextXAlignment.Center)
    ptext.Size = UDim2.new(1, 0, 0, 16)
    ptext.Position = UDim2.new(0, 0, 1, -42)

    task.spawn(function()
        local steps = { "Cargando módulos…", "Preparando hitbox…", "Cargando radar y ESP…", "Aplicando perfil…" }
        task.spawn(function()
            for _, s in ipairs(steps) do
                if not ptext.Parent then return end
                ptext.Text = s
                task.wait(4.5 / #steps)
            end
        end)
        TweenService:Create(fill, TweenInfo.new(4.5, Enum.EasingStyle.Linear), { Size = UDim2.new(1, 0, 1, 0) }):Play()
        task.wait(4.5)
        ptext.Text = "Listo ✓"
        TweenService:Create(welcomeFrame, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { GroupTransparency = 1 }):Play()
        task.wait(1)
        welcomeFrame:Destroy()
    end)
end

-- ══════════════════════════════════════════════
--          VENTANAS DE ADVERTENCIA
-- ══════════════════════════════════════════════

local dashWarn, banWarn
do
    local function createWarning(name, titleText, bodyText, accentColor)
        local f = create("Frame", {
            Name = name, Size = UDim2.new(0, 340, 0, 184),
            Position = UDim2.new(0.5, -170, 0.5, -92),
            BackgroundColor3 = THEME.bg, BorderSizePixel = 0, Visible = false, ZIndex = 3000,
        }, screenGui)
        applyCorner(f, 14)
        applyStroke(f, accentColor, 1.5, 0.1)

        local strip = create("Frame", {
            Size = UDim2.new(1, -28, 0, 3), Position = UDim2.new(0, 14, 0, 0),
            BackgroundColor3 = accentColor, BorderSizePixel = 0,
        }, f)
        applyCorner(strip, 2)

        local fTitle = label(f, titleText, 14, Enum.Font.GothamBlack, accentColor)
        fTitle.Size = UDim2.new(1, -32, 0, 24)
        fTitle.Position = UDim2.new(0, 18, 0, 18)

        local fBody = label(f, bodyText, 12, Enum.Font.GothamMedium, THEME.text)
        fBody.Size = UDim2.new(1, -36, 0, 64)
        fBody.Position = UDim2.new(0, 18, 0, 50)
        fBody.TextWrapped = true
        fBody.TextYAlignment = Enum.TextYAlignment.Top

        local b1 = create("TextButton", {
            Size = UDim2.new(0, 100, 0, 32), Position = UDim2.new(0, 18, 1, -48),
            BackgroundColor3 = accentColor, Text = "Entendido", TextColor3 = Color3.new(1, 1, 1),
            Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false, BorderSizePixel = 0,
        }, f)
        applyCorner(b1, 8)

        local b2 = create("TextButton", {
            Size = UDim2.new(0, 170, 0, 32), Position = UDim2.new(1, -188, 1, -48),
            BackgroundColor3 = THEME.card, Text = "No mostrar de nuevo", TextColor3 = THEME.muted,
            Font = Enum.Font.GothamMedium, TextSize = 11, AutoButtonColor = false, BorderSizePixel = 0,
        }, f)
        applyCorner(b2, 8)
        applyStroke(b2, THEME.stroke, 1)

        b1.MouseEnter:Connect(function() tween(b1, { BackgroundTransparency = 0.15 }) end)
        b1.MouseLeave:Connect(function() tween(b1, { BackgroundTransparency = 0 }) end)
        b2.MouseEnter:Connect(function() tween(b2, { BackgroundColor3 = THEME.cardHover }) end)
        b2.MouseLeave:Connect(function() tween(b2, { BackgroundColor3 = THEME.card }) end)

        b1.MouseButton1Click:Connect(function() f.Visible = false end)
        return f, b2
    end

    local dNo, bNo
    dashWarn, dNo = createWarning("DashWarn", "⚠ DASH LENTO", "Por los errores del dash lento, se recomienda usar el multiplicador de velocidad.", THEME.warn)
    banWarn,  bNo = createWarning("BanWarn",  "☠ RIESGO DE BAN", "Este multiplicador es MUY visible. Riesgo alto de ban y reportes. ¡Cuidado!", THEME.danger)
    dNo.MouseButton1Click:Connect(function() hideDashWarning = true; dashWarn.Visible = false end)
    bNo.MouseButton1Click:Connect(function() hideBanWarning = true; banWarn.Visible = false end)
end

-- ══════════════════════════════════════════════
--          BURBUJA MINIMIZADA
-- ══════════════════════════════════════════════

local bubble = create("TextButton", {
    Size = UDim2.new(0, 56, 0, 56), Position = UDim2.new(0, 20, 0.3, 0),
    BackgroundColor3 = THEME.bg, Visible = false, ZIndex = 100, Text = "",
    AutoButtonColor = false, BorderSizePixel = 0,
}, screenGui)
do
    applyCorner(bubble, 28)
    local bs = applyStroke(bubble, THEME.accent, 2, 0.05)
    applyGradient(bs, THEME.accent, THEME.accent2, 45)
    create("ImageLabel", {
        Size = UDim2.new(0, 34, 0, 34), Position = UDim2.new(0.5, -17, 0.5, -17),
        BackgroundTransparency = 1, Image = LOGO_ID,
    }, bubble)
    bubble.MouseEnter:Connect(function() tween(bubble, { Size = UDim2.new(0, 62, 0, 62) }, 0.15) end)
    bubble.MouseLeave:Connect(function() tween(bubble, { Size = UDim2.new(0, 56, 0, 56) }, 0.15) end)
end

-- ══════════════════════════════════════════════
--            MAIN HUB FRAME
-- ══════════════════════════════════════════════

local mainHub = create("Frame", {
    Size = UDim2.new(0, 720, 0, 560),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    BackgroundColor3 = THEME.bg, BorderSizePixel = 0, ZIndex = 10,
}, screenGui)
applyCorner(mainHub, 14)
do
    local ms = applyStroke(mainHub, THEME.accent, 1.5, 0.35)
    applyGradient(ms, THEME.accent, THEME.accent2, 45)
end
applyGradient(mainHub, THEME.heroTop, THEME.heroBottom, 120)
local hubScale = create("UIScale", { Scale = 1 }, mainHub)

local UI = { playerRows = {}, wpRows = {} }
local P = {}

-- Barra superior
do
    local topBar = create("Frame", {
        Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = THEME.panel, BorderSizePixel = 0,
    }, mainHub)
    applyCorner(topBar, 14)
    create("Frame", {
        Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14),
        BackgroundColor3 = THEME.panel, BorderSizePixel = 0,
    }, topBar)
    local topLine = create("Frame", {
        Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
    }, topBar)
    applyGradient(topLine, THEME.accent, THEME.accent2, 0)

    local dot = create("Frame", {
        Size = UDim2.new(0, 8, 0, 8), Position = UDim2.new(0, 16, 0.5, -4),
        BackgroundColor3 = THEME.ok, BorderSizePixel = 0,
    }, topBar)
    applyCorner(dot, 4)

    local title = label(topBar, "R_ZONE HUB", 14, Enum.Font.GothamBlack, Color3.new(1, 1, 1))
    title.Size = UDim2.new(0, 110, 1, 0)
    title.Position = UDim2.new(0, 32, 0, 0)
    applyGradient(title, THEME.accent, THEME.accent2, 0)

    local function chip(x, w, text, color)
        local c = create("TextLabel", {
            Size = UDim2.new(0, w, 0, 20), Position = UDim2.new(0, x, 0.5, -10),
            BackgroundColor3 = THEME.card, Text = text, TextColor3 = color or THEME.muted,
            Font = Enum.Font.GothamBold, TextSize = 10, BorderSizePixel = 0,
        }, topBar)
        applyCorner(c, 10)
        applyStroke(c, THEME.stroke, 1)
        return c
    end
    chip(136, 92, "Pro · v3.4.0", THEME.muted)
    UI.fps  = chip(236, 66, "FPS --", THEME.ok)
    UI.ping = chip(308, 82, "Ping -- ms", THEME.accent2)
    chip(398, 64, BF.sea, THEME.warn)

    local minBtn = create("TextButton", {
        Size = UDim2.new(0, 28, 0, 28), Position = UDim2.new(1, -40, 0.5, -14),
        BackgroundColor3 = THEME.card, Text = "–", TextColor3 = THEME.text,
        Font = Enum.Font.GothamBold, TextSize = 16, AutoButtonColor = false, BorderSizePixel = 0,
    }, topBar)
    applyCorner(minBtn, 8)
    minBtn.MouseEnter:Connect(function() tween(minBtn, { BackgroundColor3 = THEME.accent }) end)
    minBtn.MouseLeave:Connect(function() tween(minBtn, { BackgroundColor3 = THEME.card }) end)

    UI.topBar, UI.min = topBar, minBtn
end

-- Barra inferior
do
    local footer = create("Frame", {
        Size = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0, 0, 1, -28),
        BackgroundColor3 = THEME.panel, BorderSizePixel = 0,
    }, mainHub)
    applyCorner(footer, 14)
    create("Frame", { Size = UDim2.new(1, 0, 0, 14), BackgroundColor3 = THEME.panel, BorderSizePixel = 0 }, footer)
    create("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = THEME.stroke, BorderSizePixel = 0 }, footer)
    UI.footerText = label(footer, "", 10, Enum.Font.GothamMedium, THEME.muted)
    UI.footerText.Size = UDim2.new(1, -190, 1, 0)
    UI.footerText.Position = UDim2.new(0, 16, 0, 0)
    UI.footerHint = label(footer, "RightControl · ocultar", 10, Enum.Font.Gotham, THEME.muted, Enum.TextXAlignment.Right)
    UI.footerHint.Size = UDim2.new(0, 170, 1, 0)
    UI.footerHint.Position = UDim2.new(1, -184, 0, 0)
end

-- Panel lateral y contenedor
do
    local side = create("Frame", {
        Size = UDim2.new(0, 140, 1, -73), Position = UDim2.new(0, 0, 0, 45),
        BackgroundColor3 = THEME.panel, BorderSizePixel = 0,
    }, mainHub)
    create("Frame", {
        Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = THEME.stroke, BorderSizePixel = 0,
    }, side)
    create("ImageLabel", {
        Size = UDim2.new(0, 46, 0, 46), Position = UDim2.new(0, 14, 0, 12),
        BackgroundTransparency = 1, Image = LOGO_ID,
    }, side)
    local nm = label(side, LocalPlayer.DisplayName, 11, Enum.Font.GothamBold, THEME.text)
    nm.Size = UDim2.new(1, -74, 0, 16); nm.Position = UDim2.new(0, 66, 0, 17)
    nm.TextTruncate = Enum.TextTruncate.AtEnd
    local role = label(side, "● Online", 10, Enum.Font.GothamMedium, THEME.ok)
    role.Size = UDim2.new(1, -74, 0, 14); role.Position = UDim2.new(0, 66, 0, 34)
    create("Frame", {
        Size = UDim2.new(1, -24, 0, 1), Position = UDim2.new(0, 12, 0, 70),
        BackgroundColor3 = THEME.stroke, BorderSizePixel = 0,
    }, side)
    local foot = label(side, "by R_Zone", 9, Enum.Font.Gotham, THEME.muted, Enum.TextXAlignment.Center)
    foot.Size = UDim2.new(1, 0, 0, 14); foot.Position = UDim2.new(0, 0, 1, -20)
    UI.side = side

    -- Lista de pestañas con scroll (hay más pestañas que alto disponible)
    UI.tabList = create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, -104), Position = UDim2.new(0, 0, 0, 80),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
        ScrollBarImageColor3 = THEME.accent, CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, side)
    create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, UI.tabList)
    applyPadding(UI.tabList, 8, 2, 8, 2)

    UI.container = create("Frame", {
        Size = UDim2.new(1, -168, 1, -94), Position = UDim2.new(0, 154, 0, 56),
        BackgroundTransparency = 1, ClipsDescendants = true,
    }, mainHub)
end

-- ══════════════════════════════════════════════
--        COMPONENTES REUTILIZABLES
-- ══════════════════════════════════════════════

local function makePage(key, title, desc)
    local p = create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = THEME.accent,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
    }, UI.container)
    create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, p)
    applyPadding(p, 0, 0, 8, 6)

    local header = create("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, LayoutOrder = 0 }, p)
    local t = label(header, title, 18, Enum.Font.GothamBlack, THEME.text)
    t.Size = UDim2.new(0.6, 0, 0, 24)
    local d = label(header, desc, 11, Enum.Font.Gotham, THEME.muted)
    d.Size = UDim2.new(1, 0, 0, 14)
    d.Position = UDim2.new(0, 0, 0, 25)
    P[key] = p
    return p, header
end

local function sectionLabel(parent, text, order)
    local l = label(parent, string.upper(text), 10, Enum.Font.GothamBold, THEME.accent2)
    l.Size = UDim2.new(1, 0, 0, 16)
    l.LayoutOrder = order
    return l
end

local function card(parent, height, order)
    local f = create("Frame", {
        Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = THEME.card,
        BorderSizePixel = 0, LayoutOrder = order,
    }, parent)
    applyCorner(f, 10)
    applyStroke(f, THEME.stroke, 1)
    return f
end

local function createInfo(parent, order, text, height)
    local c = card(parent, height or 54, order)
    local l = label(c, text, 11, Enum.Font.GothamMedium, THEME.muted)
    l.Size = UDim2.new(1, -28, 1, -16)
    l.Position = UDim2.new(0, 14, 0, 8)
    l.TextWrapped = true
    l.TextYAlignment = Enum.TextYAlignment.Top
    return l
end

local function createSlider(title, order, parent, maxVal, callback, minVal, initial, fmt, cfgKey)
    minVal = minVal or 1
    fmt = fmt or "x%.1f"
    local range = maxVal - minVal
    local startRel = initial and math.clamp((initial - minVal) / range, 0, 1) or 0
    local current = initial or minVal

    local c = card(parent, 66, order)

    local lbl = label(c, title, 11, Enum.Font.GothamBold, THEME.text)
    lbl.Size = UDim2.new(1, -100, 0, 18)
    lbl.Position = UDim2.new(0, 14, 0, 10)

    local valLbl = create("TextLabel", {
        Size = UDim2.new(0, 76, 0, 20), Position = UDim2.new(1, -90, 0, 9),
        BackgroundColor3 = THEME.bg, Text = string.format(fmt, current), TextColor3 = THEME.accent2,
        Font = Enum.Font.GothamBold, TextSize = 11, BorderSizePixel = 0,
    }, c)
    applyCorner(valLbl, 6)

    local hit = create("Frame", {
        Size = UDim2.new(1, -28, 0, 24), Position = UDim2.new(0, 14, 0, 34), BackgroundTransparency = 1,
    }, c)
    local bg = create("Frame", {
        Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 0.5, -3),
        BackgroundColor3 = THEME.bg, BorderSizePixel = 0,
    }, hit)
    applyCorner(bg, 3)
    local fill = create("Frame", {
        Size = UDim2.new(startRel, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
    }, bg)
    applyCorner(fill, 3)
    applyGradient(fill, THEME.accent, THEME.accent2, 0)
    local handle = create("Frame", {
        Size = UDim2.new(0, 16, 0, 16), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(startRel, 0, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
    }, bg)
    applyCorner(handle, 8)
    applyStroke(handle, THEME.accent, 2)

    local function applyRel(rel)
        rel = math.clamp(rel, 0, 1)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        handle.Position = UDim2.new(rel, 0, 0.5, 0)
        current = minVal + rel * range
        valLbl.Text = string.format(fmt, current)
        callback(current)
    end

    local dragging = false
    local function update()
        applyRel((UserInputService:GetMouseLocation().X - bg.AbsolutePosition.X) / bg.AbsoluteSize.X)
    end
    hit.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; update() end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
    RunService.RenderStepped:Connect(function() if dragging then update() end end)

    local obj = {
        get = function() return current end,
        set = function(v) applyRel((v - minVal) / range) end,
    }
    if cfgKey then CFG.sliders[cfgKey] = obj end
    return obj
end

local function createToggle(text, desc, order, parent, callback, default, cfgKey)
    local btn = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = THEME.card, Text = "",
        AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = order,
    }, parent)
    applyCorner(btn, 10)
    applyStroke(btn, THEME.stroke, 1)

    local t = label(btn, text, 12, Enum.Font.GothamBold, THEME.text)
    t.Size = UDim2.new(1, -80, 0, 18); t.Position = UDim2.new(0, 14, 0, 9)
    local d = label(btn, desc, 10, Enum.Font.Gotham, THEME.muted)
    d.Size = UDim2.new(1, -80, 0, 14); d.Position = UDim2.new(0, 14, 0, 28)

    local sw = create("Frame", {
        Size = UDim2.new(0, 42, 0, 22), Position = UDim2.new(1, -56, 0.5, -11),
        BackgroundColor3 = THEME.bg, BorderSizePixel = 0,
    }, btn)
    applyCorner(sw, 11)
    local swStroke = applyStroke(sw, THEME.stroke, 1)
    local knob = create("Frame", {
        Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(0, 3, 0.5, -8),
        BackgroundColor3 = THEME.muted, BorderSizePixel = 0,
    }, sw)
    applyCorner(knob, 8)

    local state = false
    local function apply(s, silent, instant)
        state = s and true or false
        local swc  = state and THEME.accent or THEME.bg
        local stc  = state and THEME.accent or THEME.stroke
        local kpos = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        local kcol = state and Color3.new(1, 1, 1) or THEME.muted
        if instant then
            sw.BackgroundColor3 = swc; swStroke.Color = stc
            knob.Position = kpos; knob.BackgroundColor3 = kcol
        else
            tween(sw, { BackgroundColor3 = swc })
            tween(swStroke, { Color = stc })
            tween(knob, { Position = kpos, BackgroundColor3 = kcol }, 0.2)
        end
        callback(state)
        if not silent then
            notify(text, state and "Activado" or "Desactivado", state and THEME.ok or THEME.muted, 1.6)
        end
    end

    btn.MouseEnter:Connect(function() tween(btn, { BackgroundColor3 = THEME.cardHover }) end)
    btn.MouseLeave:Connect(function() tween(btn, { BackgroundColor3 = THEME.card }) end)
    btn.MouseButton1Click:Connect(function() apply(not state, false, false) end)

    local obj = {
        get = function() return state end,
        set = function(s, silent, instant) apply(s, silent, instant) end,
    }
    if default then apply(true, true, true) end
    if cfgKey then CFG.toggles[cfgKey] = obj end
    return obj
end

local function createSegment(title, order, parent, options, default, callback, cfgKey)
    local c = card(parent, 66, order)
    local lbl = label(c, title, 11, Enum.Font.GothamBold, THEME.text)
    lbl.Size = UDim2.new(1, -28, 0, 18); lbl.Position = UDim2.new(0, 14, 0, 9)

    local track = create("Frame", {
        Size = UDim2.new(1, -28, 0, 28), Position = UDim2.new(0, 14, 0, 30),
        BackgroundColor3 = THEME.bg, BorderSizePixel = 0,
    }, c)
    applyCorner(track, 8)

    local btns, current = {}, default
    local function select(idx)
        for i, b in ipairs(btns) do
            local on = (i == idx)
            tween(b, { BackgroundColor3 = on and THEME.accent or THEME.bg })
            b.TextColor3 = on and Color3.new(1, 1, 1) or THEME.muted
        end
    end
    local n = #options
    for i, opt in ipairs(options) do
        local b = create("TextButton", {
            Size = UDim2.new(1 / n, -4, 1, -4), Position = UDim2.new((i - 1) / n, 2, 0, 2),
            BackgroundColor3 = THEME.bg, Text = opt.label, TextColor3 = THEME.muted,
            Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false, BorderSizePixel = 0,
        }, track)
        applyCorner(b, 6)
        btns[i] = b
        b.MouseButton1Click:Connect(function()
            current = opt.value
            select(i)
            callback(opt.value)
        end)
    end
    for i, opt in ipairs(options) do
        if opt.value == default then select(i) end
    end

    local obj = {
        get = function() return current end,
        set = function(v)
            for i, opt in ipairs(options) do
                if opt.value == v then
                    current = v
                    select(i)
                    callback(v)
                end
            end
        end,
    }
    if cfgKey then CFG.segments[cfgKey] = obj end
    return obj
end

local function kindColors(kind)
    if kind == "danger" then return THEME.dangerBg, THEME.dangerBgHover, THEME.danger, THEME.danger end
    if kind == "primary" then return THEME.selected, THEME.cardHover, THEME.text, THEME.accent end
    return THEME.card, THEME.cardHover, THEME.text, THEME.stroke
end

local function createButtons(parent, order, defs)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, LayoutOrder = order }, parent)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, row)
    local n = #defs
    local out = {}
    for i, d in ipairs(defs) do
        local bg, _, tc, sc = kindColors(d.kind)
        local b = create("TextButton", {
            Size = UDim2.new(1 / n, -(8 * (n - 1)) / n, 1, 0), BackgroundColor3 = bg,
            Text = d.text, TextColor3 = tc, Font = Enum.Font.GothamBold, TextSize = 12,
            AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = i,
        }, row)
        applyCorner(b, 10)
        applyStroke(b, sc, 1, 0.45)
        b.MouseEnter:Connect(function()
            local _, hv = kindColors(d.kind)
            tween(b, { BackgroundColor3 = hv })
        end)
        b.MouseLeave:Connect(function()
            local nbg = kindColors(d.kind)
            tween(b, { BackgroundColor3 = nbg })
        end)
        b.MouseButton1Click:Connect(d.cb)
        out[i] = b
    end
    return out
end

local function createTextAction(parent, order, placeholder, btnText, cb)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = order }, parent)
    local box = create("TextBox", {
        Size = UDim2.new(1, -128, 1, 0), BackgroundColor3 = THEME.card, BorderSizePixel = 0,
        PlaceholderText = placeholder, PlaceholderColor3 = THEME.muted, Text = "",
        TextColor3 = THEME.text, Font = Enum.Font.GothamMedium, TextSize = 12,
        ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    applyCorner(box, 10)
    applyStroke(box, THEME.stroke, 1)
    applyPadding(box, 12, 0, 12, 0)
    local btn = create("TextButton", {
        Size = UDim2.new(0, 120, 1, 0), Position = UDim2.new(1, -120, 0, 0),
        BackgroundColor3 = THEME.selected, Text = btnText, TextColor3 = THEME.text,
        Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false, BorderSizePixel = 0,
    }, row)
    applyCorner(btn, 10)
    applyStroke(btn, THEME.accent, 1, 0.4)
    btn.MouseEnter:Connect(function() tween(btn, { BackgroundColor3 = THEME.cardHover }) end)
    btn.MouseLeave:Connect(function() tween(btn, { BackgroundColor3 = THEME.selected }) end)
    btn.MouseButton1Click:Connect(function() cb(box.Text, box) end)
    return box
end

local function createStatRow(parent, order, names)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, LayoutOrder = order }, parent)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, row)
    local vals = {}
    for i, name in ipairs(names) do
        local tile = create("Frame", {
            Size = UDim2.new(1 / #names, -6, 1, 0), BackgroundColor3 = THEME.card,
            BorderSizePixel = 0, LayoutOrder = i,
        }, row)
        applyCorner(tile, 10)
        applyStroke(tile, THEME.stroke, 1)
        local v = label(tile, "--", 18, Enum.Font.GothamBlack, THEME.accent2, Enum.TextXAlignment.Center)
        v.Size = UDim2.new(1, 0, 0, 28); v.Position = UDim2.new(0, 0, 0, 10)
        local c = label(tile, name, 10, Enum.Font.GothamMedium, THEME.muted, Enum.TextXAlignment.Center)
        c.Size = UDim2.new(1, 0, 0, 14); c.Position = UDim2.new(0, 0, 0, 40)
        vals[i] = v
    end
    return vals
end

-- ══════════════════════════════════════════════
--     BOTONES PEQUEÑOS Y LISTAS EN VIVO
-- ══════════════════════════════════════════════

local function miniBtn(parent, text, pos, size, kind, cb)
    local bg, _, tc = kindColors(kind)
    local b = create("TextButton", {
        Size = size, Position = pos, BackgroundColor3 = bg, Text = text, TextColor3 = tc,
        Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false, BorderSizePixel = 0,
    }, parent)
    applyCorner(b, 7)
    b.MouseEnter:Connect(function()
        local _, hv = kindColors(kind)
        tween(b, { BackgroundColor3 = hv })
    end)
    b.MouseLeave:Connect(function()
        local nbg = kindColors(kind)
        tween(b, { BackgroundColor3 = nbg })
    end)
    b.MouseButton1Click:Connect(cb)
    return b
end

-- Lista que solo se reconstruye cuando cambia el conjunto de elementos
local function createLiveList(parent, order, height, emptyText)
    local list = create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = THEME.panel, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = THEME.accent,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, LayoutOrder = order,
    }, parent)
    applyCorner(list, 10)
    applyStroke(list, THEME.stroke, 1)
    create("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, list)
    applyPadding(list, 6, 6, 6, 6)

    local empty = label(list, emptyText, 11, Enum.Font.Gotham, THEME.muted, Enum.TextXAlignment.Center)
    empty.Size = UDim2.new(1, 0, 0, 40)
    empty.LayoutOrder = 0

    local rows, sig = {}, ""
    local obj = {}
    function obj.set(items)
        local keys = {}
        for i, it in ipairs(items) do keys[i] = it.key end
        local s = table.concat(keys, "|")
        if s ~= sig then
            for _, r in ipairs(rows) do r.frame:Destroy() end
            rows = {}
            for i, it in ipairs(items) do
                local row = create("Frame", {
                    Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = THEME.card,
                    BorderSizePixel = 0, LayoutOrder = i,
                }, list)
                applyCorner(row, 8)
                local r = { frame = row, pos = it.pos }
                r.title = label(row, "", 12, Enum.Font.GothamBold, THEME.text)
                r.title.Size = UDim2.new(1, -150, 0, 16); r.title.Position = UDim2.new(0, 12, 0, 6)
                r.title.TextTruncate = Enum.TextTruncate.AtEnd
                r.sub = label(row, "", 10, Enum.Font.Gotham, THEME.muted)
                r.sub.Size = UDim2.new(1, -150, 0, 14); r.sub.Position = UDim2.new(0, 12, 0, 24)
                r.sub.TextTruncate = Enum.TextTruncate.AtEnd
                r.badge = create("TextLabel", {
                    Size = UDim2.new(0, 66, 0, 20), Position = UDim2.new(1, -146, 0.5, -10),
                    BackgroundColor3 = THEME.bg, Text = "", TextColor3 = THEME.text,
                    Font = Enum.Font.GothamBold, TextSize = 10, BorderSizePixel = 0,
                }, row)
                applyCorner(r.badge, 6)
                r.tp = miniBtn(row, "TP", UDim2.new(1, -72, 0.5, -13), UDim2.new(0, 40, 0, 26), "primary", function()
                    if r.pos then WP.teleport(r.pos) end
                end)
                rows[i] = r
            end
            sig = s
        end
        for i, it in ipairs(items) do
            local r = rows[i]
            r.pos = it.pos
            r.title.Text = it.title
            r.sub.Text = it.sub or ""
            r.badge.Text = it.badge or ""
            r.badge.TextColor3 = it.badgeColor or THEME.muted
            r.badge.Visible = (it.badge ~= nil)
            r.tp.Visible = (it.pos ~= nil)
        end
        empty.Visible = (#items == 0)
    end
    return obj
end

-- ══════════════════════════════════════════════
--                PESTAÑA HITBOX
-- ══════════════════════════════════════════════

do
    local page, header = makePage("hb", "Hitbox", "Elige el tamaño de la hitbox objetivo")
    page.Visible = true

    local chip = create("TextLabel", {
        Size = UDim2.new(0, 110, 0, 20), Position = UDim2.new(1, -110, 0, 2),
        BackgroundColor3 = THEME.card, Text = "Modo: Normal", TextColor3 = THEME.accent2,
        Font = Enum.Font.GothamBold, TextSize = 10, BorderSizePixel = 0,
    }, header)
    applyCorner(chip, 10)
    applyStroke(chip, THEME.stroke, 1)

    local rows = {}

    refreshModeRows = function()
        for i, row in ipairs(rows) do
            local selected = (MODES[i] == currentMode)
            tween(row.btn,    { BackgroundColor3 = selected and THEME.selected or THEME.card })
            tween(row.stroke, { Color = selected and THEME.accent or THEME.stroke })
            tween(row.dot,    { BackgroundColor3 = selected and THEME.accent2 or THEME.stroke })
            row.name.TextColor3 = selected and THEME.text or THEME.textDim
        end
        chip.Text = "Modo: " .. (currentMode.key == "normal" and "Normal" or currentMode.key)
    end

    selectMode = function(i, userClick)
        local m = MODES[i]
        if not m then return end
        currentMode = m
        lastCacheTime = 0
        if m.key == "normal" then clearAllHitboxes() end
        if userClick then
            if i >= 4 and not hideDashWarning then dashWarn.Visible = true end
            if i >= 9 and not hideBanWarning  then banWarn.Visible  = true end
        end
        refreshModeRows()
    end

    for i, m in ipairs(MODES) do
        local btn = create("TextButton", {
            Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = THEME.card, Text = "",
            AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = i,
        }, page)
        applyCorner(btn, 9)
        local st = applyStroke(btn, THEME.stroke, 1)

        local dot = create("Frame", {
            Size = UDim2.new(0, 8, 0, 8), Position = UDim2.new(0, 14, 0.5, -4),
            BackgroundColor3 = THEME.stroke, BorderSizePixel = 0,
        }, btn)
        applyCorner(dot, 4)

        local nameL = label(btn, m.label, 12, Enum.Font.GothamBold, THEME.textDim)
        nameL.Size = UDim2.new(0.5, 0, 1, 0)
        nameL.Position = UDim2.new(0, 32, 0, 0)

        local tag = create("TextLabel", {
            Size = UDim2.new(0, 72, 0, 20), Position = UDim2.new(1, -84, 0.5, -10),
            BackgroundColor3 = THEME.bg, Text = (m.key == "normal") and "original" or (m.enemySize.X .. " studs"),
            TextColor3 = THEME.muted, Font = Enum.Font.GothamMedium, TextSize = 10, BorderSizePixel = 0,
        }, btn)
        applyCorner(tag, 6)

        rows[i] = { btn = btn, stroke = st, dot = dot, name = nameL }

        btn.MouseEnter:Connect(function()
            if currentMode ~= m then tween(btn, { BackgroundColor3 = THEME.cardHover }) end
        end)
        btn.MouseLeave:Connect(function()
            if currentMode ~= m then tween(btn, { BackgroundColor3 = THEME.card }) end
        end)
        btn.MouseButton1Click:Connect(function() selectMode(i, true) end)
    end
    refreshModeRows()
end

-- ══════════════════════════════════════════════
--              PESTAÑA MOVIMIENTO
-- ══════════════════════════════════════════════

do
    local page = makePage("mv", "Movimiento", "Ajusta velocidad y salto")
    createSlider("VELOCIDAD  (máx x20)", 1, page, 20, function(v) speedMultiplier = v end, nil, nil, nil, "speed")
    createSlider("SALTO  (máx x10)",     2, page, 10, function(v) jumpMultiplier = v end, nil, nil, nil, "jump")
end

-- ══════════════════════════════════════════════
--        PESTAÑA OBJETIVO (SELECTOR DE JUGADOR)
-- ══════════════════════════════════════════════

do
    local page = makePage("tg", "Objetivo", "Selecciona al jugador para Cam Lock y Strafe")

    sectionLabel(page, "Objetivo actual", 1)
    local tcard = card(page, 60, 2)
    local tStroke = tcard:FindFirstChildOfClass("UIStroke")

    local avatar = create("ImageLabel", {
        Size = UDim2.new(0, 40, 0, 40), Position = UDim2.new(0, 10, 0.5, -20),
        BackgroundColor3 = THEME.bg, Image = "", BorderSizePixel = 0,
    }, tcard)
    applyCorner(avatar, 20)

    local tName = label(tcard, "Sin objetivo", 13, Enum.Font.GothamBold, THEME.text)
    tName.Size = UDim2.new(1, -170, 0, 18); tName.Position = UDim2.new(0, 60, 0, 12)
    tName.TextTruncate = Enum.TextTruncate.AtEnd
    local tSub = label(tcard, "Elige un jugador de la lista", 10, Enum.Font.Gotham, THEME.muted)
    tSub.Size = UDim2.new(1, -170, 0, 14); tSub.Position = UDim2.new(0, 60, 0, 32)
    tSub.TextTruncate = Enum.TextTruncate.AtEnd

    local clearBtn = create("TextButton", {
        Size = UDim2.new(0, 76, 0, 28), Position = UDim2.new(1, -88, 0.5, -14),
        BackgroundColor3 = THEME.dangerBg, Text = "Quitar", TextColor3 = THEME.danger,
        Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false, BorderSizePixel = 0,
    }, tcard)
    applyCorner(clearBtn, 8)
    clearBtn.MouseButton1Click:Connect(function() setTarget(nil) end)

    refreshTargetCard = function()
        if X.target then
            tName.Text = X.target.DisplayName
            tSub.Text = "@" .. X.target.Name
            avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. X.target.UserId .. "&w=150&h=150"
            tStroke.Color = THEME.danger
        else
            tName.Text = "Sin objetivo"
            tSub.Text = "Elige un jugador de la lista"
            avatar.Image = ""
            tStroke.Color = THEME.stroke
        end
    end

    createToggle("Auto: más cercano", "Fija automáticamente al enemigo más próximo", 3, page,
        function(s) X.autoNearest = s end, nil, "autoNearest")

    sectionLabel(page, "Jugadores en el servidor", 4)

    local searchBox = create("TextBox", {
        Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = THEME.card, BorderSizePixel = 0,
        PlaceholderText = "🔍  Buscar jugador…", PlaceholderColor3 = THEME.muted,
        Text = "", TextColor3 = THEME.text, Font = Enum.Font.GothamMedium, TextSize = 12,
        ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 5,
    }, page)
    applyCorner(searchBox, 10)
    applyStroke(searchBox, THEME.stroke, 1)
    applyPadding(searchBox, 12, 0, 12, 0)

    local list = create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 190), BackgroundColor3 = THEME.panel, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = THEME.accent,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, LayoutOrder = 6,
    }, page)
    applyCorner(list, 10)
    applyStroke(list, THEME.stroke, 1)
    create("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, list)
    applyPadding(list, 6, 6, 6, 6)

    rebuildPlayerList = function()
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end
        UI.playerRows = {}
        local q = string.lower(searchBox.Text)
        local n = 0
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and (q == "" or string.find(string.lower(plr.Name), q, 1, true) or string.find(string.lower(plr.DisplayName), q, 1, true)) then
                n = n + 1
                local sel = (plr == X.target)
                local row = create("TextButton", {
                    Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = sel and THEME.selected or THEME.card,
                    Text = "", AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = n,
                }, list)
                applyCorner(row, 8)
                applyStroke(row, sel and THEME.accent or THEME.stroke, 1)

                local av = create("ImageLabel", {
                    Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(0, 8, 0.5, -15),
                    BackgroundColor3 = THEME.bg, BorderSizePixel = 0,
                    Image = "rbxthumb://type=AvatarHeadShot&id=" .. plr.UserId .. "&w=60&h=60",
                }, row)
                applyCorner(av, 15)

                local nm = label(row, plr.DisplayName, 12, Enum.Font.GothamBold, THEME.text)
                nm.Size = UDim2.new(1, -150, 0, 16); nm.Position = UDim2.new(0, 46, 0, 5)
                nm.TextTruncate = Enum.TextTruncate.AtEnd
                local un = label(row, "@" .. plr.Name, 10, Enum.Font.Gotham, THEME.muted)
                un.Size = UDim2.new(1, -150, 0, 14); un.Position = UDim2.new(0, 46, 0, 22)
                un.TextTruncate = Enum.TextTruncate.AtEnd

                local dist = create("TextLabel", {
                    Size = UDim2.new(0, 56, 0, 20), Position = UDim2.new(1, -66, 0.5, -10),
                    BackgroundColor3 = THEME.bg, Text = "--", TextColor3 = THEME.accent2,
                    Font = Enum.Font.GothamBold, TextSize = 10, BorderSizePixel = 0,
                }, row)
                applyCorner(dist, 6)

                UI.playerRows[plr] = { dist = dist }

                row.MouseEnter:Connect(function() if plr ~= X.target then tween(row, { BackgroundColor3 = THEME.cardHover }) end end)
                row.MouseLeave:Connect(function() if plr ~= X.target then tween(row, { BackgroundColor3 = THEME.card }) end end)
                row.MouseButton1Click:Connect(function()
                    setTarget(plr ~= X.target and plr or nil)
                end)
            end
        end
        if n == 0 then
            local e = label(list, "No hay otros jugadores", 11, Enum.Font.Gotham, THEME.muted, Enum.TextXAlignment.Center)
            e.Size = UDim2.new(1, 0, 0, 40)
        end
    end

    searchBox:GetPropertyChangedSignal("Text"):Connect(function() rebuildPlayerList() end)
    rebuildPlayerList()
    refreshTargetCard()
end

-- ══════════════════════════════════════════════
--        PESTAÑA COMBATE (CAM LOCK / STRAFE)
-- ══════════════════════════════════════════════

do
    local page = makePage("cm", "Combate", "Cam Lock y Target Strafe")

    sectionLabel(page, "Cam Lock", 1)
    createToggle("Cam Lock", "La cámara sigue al objetivo seleccionado", 2, page,
        function(s) X.camLock = s end, nil, "camLock")
    createSegment("Parte a seguir", 3, page, {
        { label = "Cabeza", value = "Head" },
        { label = "Torso",  value = "HumanoidRootPart" },
    }, "Head", function(v) X.aimPart = v end, "aimPart")
    createSlider("SUAVIDAD DE CÁMARA", 4, page, 20, function(v) X.camSmooth = v end, 1, 1, "%.1f", "camSmooth")

    sectionLabel(page, "Target Strafe", 5)
    createToggle("Target Strafe", "Orbita alrededor del objetivo", 6, page,
        function(s) X.strafe = s end, nil, "strafe")
    createSegment("Dirección de órbita", 7, page, {
        { label = "↻ Horario",     value = 1  },
        { label = "↺ Antihorario", value = -1 },
    }, 1, function(v) X.strafeDir = v end, "strafeDir")
    createSlider("RADIO",     8,  page, 40, function(v) X.strafeRadius = v end, 3, 12, "%.0f studs", "strafeRadius")
    createSlider("VELOCIDAD", 9,  page, 20, function(v) X.strafeSpeed  = v end, 1, 6,  "%.1f",       "strafeSpeed")
    createSlider("ALTURA",    10, page, 20, function(v) X.strafeHeight = v end, 0, 0,  "%.0f studs", "strafeHeight")
end

-- ══════════════════════════════════════════════
--        PESTAÑA VISUAL (ESP + RADAR)
-- ══════════════════════════════════════════════

do
    local page = makePage("vs", "Visual", "ESP, cofres, frutas y radar")

    sectionLabel(page, "Jugadores", 1)
    createToggle("ESP Jugadores",  "Resalta a los jugadores",          2, page, function(s) espEnabled        = s end, nil, "esp")
    createToggle("ESP Distancia",  "Muestra metros sobre la cabeza",    3, page, function(s) distEspEnabled   = s end, nil, "espDist")
    createToggle("ESP Vida",       "Muestra la vida del jugador",       4, page, function(s) healthEspEnabled = s end, nil, "espHealth")
    createToggle("Box ESP",        "Caja 2D con barra de vida y nombre", 5, page, function(s) X.boxEsp  = s end, nil, "boxEsp")
    createToggle("Skeleton ESP",   "Dibuja el esqueleto del jugador",   6, page, function(s) X.skelEsp = s end, nil, "skelEsp")
    createToggle("Hitbox Visible", "Hace visible la hitbox ampliada",   7, page, function(s) hitboxesVisible = s; lastCacheTime = 0 end, nil, "hitVis")
    createSlider("DISTANCIA MÁX. ESP", 8, page, 5000, function(v) X.espMaxDist = v end, 200, 3000, "%.0f m", "espMax")

    sectionLabel(page, "Blox Fruits", 9)
    createToggle("Chest ESP", "Marca cofres de Plata, Oro y Diamante", 10, page, function(s) X.chestEsp = s end, nil, "chestEsp")
    createToggle("Fruit ESP", "Marca frutas con distancia y tiempo hasta que desaparecen", 11, page, function(s) X.fruitEsp = s end, nil, "fruitEsp")

    sectionLabel(page, "Radar 2D", 12)
    createToggle("Radar", "Mini mapa circular · enemigos en rojo, aliados en verde", 13, page,
        function(s) X.radar = s end, true, "radar")
    createToggle("Rotar con la cámara", "Arriba = hacia donde miras", 14, page,
        function(s) X.radarRotate = s end, true, "radarRot")
    createToggle("Mostrar aliados", "Equipo o amigos de Roblox en verde", 15, page,
        function(s) X.radarAllies = s end, true, "radarAllies")
    createSlider("TAMAÑO DEL RADAR", 16, page, 260, function(v) X.radarSize = v; radarApplyLayout() end, 120, 170, "%.0f px", "radarSize")
    createSlider("ALCANCE DEL RADAR", 17, page, 2500, function(v) X.radarRange = v end, 100, 600, "%.0f m", "radarRange")
end

-- ══════════════════════════════════════════════
--        PESTAÑA MUNDO (SERVER HOP + WAYPOINTS)
-- ══════════════════════════════════════════════

do
    local page = makePage("wd", "Mundo", "Server hop y teletransporte · " .. BF.sea)

    sectionLabel(page, "Servidor actual", 1)
    local info = card(page, 56, 2)
    UI.serverInfo = label(info, "", 12, Enum.Font.GothamBold, THEME.text)
    UI.serverInfo.Size = UDim2.new(1, -28, 0, 18); UI.serverInfo.Position = UDim2.new(0, 14, 0, 10)
    UI.jobLabel = label(info, "", 10, Enum.Font.Gotham, THEME.muted)
    UI.jobLabel.Size = UDim2.new(1, -28, 0, 14); UI.jobLabel.Position = UDim2.new(0, 14, 0, 31)

    sectionLabel(page, "Server Hop", 3)
    createButtons(page, 4, {
        { text = "🆕  Servidor nuevo", kind = "primary", cb = function() Hop.start("new") end },
        { text = "📉  Servidor bajo",  kind = "primary", cb = function() Hop.start("low") end },
    })
    UI.hopStatus = label(page, "Servidor nuevo = aleatorio · Servidor bajo = el que menos jugadores tenga", 10, Enum.Font.Gotham, THEME.muted)
    UI.hopStatus.Size = UDim2.new(1, 0, 0, 16)
    UI.hopStatus.LayoutOrder = 5
    Hop.setStatus = function(t) UI.hopStatus.Text = t end

    createTextAction(page, 6, "Pegar JobId…", "➜ Unirse", function(text) Hop.join(text) end)
    if type(setclipboard) == "function" then
        createButtons(page, 7, {
            { text = "📋  Copiar JobId actual", kind = "neutral", cb = function()
                local ok = pcall(setclipboard, game.JobId)
                notify("JobId", ok and "Copiado al portapapeles" or "No se pudo copiar", ok and THEME.ok or THEME.danger, 1.8)
            end },
        })
    end

    sectionLabel(page, "Waypoints · " .. BF.sea, 8)
    createTextAction(page, 9, "Nombre (ej. Isla de Vainilla, Jefe X)", "📍 Guardar aquí", function(text, box)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            notify("Waypoints", "Tu personaje no está disponible", THEME.danger)
            return
        end
        local name = text:gsub("^%s+", "")
        name = name:gsub("%s+$", "")
        name = name:sub(1, 28)
        if name == "" then name = "Punto " .. (#WP.forPlace() + 1) end
        WP.add(name, hrp.Position)
        box.Text = ""
        rebuildWaypointList()
        notify("📍 Waypoint guardado", name, THEME.ok)
    end)

    createSegment("Modo de teletransporte", 10, page, {
        { label = "⚡ Instantáneo",      value = "instant" },
        { label = "🌀 Tween (deslizar)", value = "tween"   },
    }, "tween", function(v) X.tpMode = v end, "tpMode")
    createSlider("VELOCIDAD DEL TWEEN", 11, page, 600, function(v) X.tpSpeed = v end, 50, 250, "%.0f st/s", "tpSpeed")

    local list = create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 190), BackgroundColor3 = THEME.panel, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = THEME.accent,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, LayoutOrder = 12,
    }, page)
    applyCorner(list, 10)
    applyStroke(list, THEME.stroke, 1)
    create("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, list)
    applyPadding(list, 6, 6, 6, 6)

    rebuildWaypointList = function()
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end
        UI.wpRows = {}
        local items = WP.forPlace()
        for i, e in ipairs(items) do
            local row = create("Frame", {
                Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = THEME.card,
                BorderSizePixel = 0, LayoutOrder = i,
            }, list)
            applyCorner(row, 8)

            local nm = label(row, tostring(e.name or "Punto"), 12, Enum.Font.GothamBold, THEME.text)
            nm.Size = UDim2.new(1, -120, 0, 16); nm.Position = UDim2.new(0, 12, 0, 6)
            nm.TextTruncate = Enum.TextTruncate.AtEnd

            local coords = string.format("%.0f, %.0f, %.0f", e.x or 0, e.y or 0, e.z or 0)
            local sub = label(row, coords, 10, Enum.Font.Gotham, THEME.muted)
            sub.Size = UDim2.new(1, -120, 0, 14); sub.Position = UDim2.new(0, 12, 0, 24)

            local entry = e
            miniBtn(row, "TP", UDim2.new(1, -92, 0.5, -13), UDim2.new(0, 44, 0, 26), "primary", function()
                WP.teleport(Vector3.new(entry.x or 0, entry.y or 0, entry.z or 0))
                notify("🌀 Teletransporte", tostring(entry.name or "Punto"), THEME.accent, 1.6)
            end)
            miniBtn(row, "🗑", UDim2.new(1, -42, 0.5, -13), UDim2.new(0, 32, 0, 26), "danger", function()
                WP.remove(entry)
                rebuildWaypointList()
            end)
            table.insert(UI.wpRows, { entry = entry, sub = sub, coords = coords })
        end
        if #items == 0 then
            local e = label(list, "Aún no hay waypoints en " .. BF.sea .. ".\nParate donde quieras y pulsa «Guardar aquí».", 11, Enum.Font.Gotham, THEME.muted, Enum.TextXAlignment.Center)
            e.Size = UDim2.new(1, 0, 0, 50)
            e.TextWrapped = true
        end
    end
    rebuildWaypointList()
end

-- ══════════════════════════════════════════════
--                PESTAÑA EXTRA
-- ══════════════════════════════════════════════

do
    local page = makePage("ex", "Extra", "Utilidades, rendimiento y estado de la sesión")
    UI.stats = createStatRow(page, 1, { "Jugadores", "Ping", "Sesión" })
    sectionLabel(page, "Combate", 2)
    createToggle("Auto M1", "Clic automático", 3, page, function(s) autoM1Enabled = s end, nil, "autoM1")
    createToggle("Fast M1", "Aumenta la cadencia del M1", 4, page, function(s) fastM1Enabled = s end, nil, "fastM1")
    sectionLabel(page, "Utilidades", 5)
    createToggle("Anti-AFK", "Evita que te expulsen por inactividad", 6, page, function(s) X.antiAfk = s end, true, "antiAfk")
    createButtons(page, 7, {
        { text = "↻  REJOIN SERVER", kind = "danger", cb = function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end },
    })

    sectionLabel(page, "Rendimiento · FPS Booster", 8)
    createToggle("FPS Booster", "Activa los tres modos de abajo de golpe", 9, page, function(s)
        for _, k in ipairs({ "noParticles", "lowGfx", "cap60" }) do
            local t = CFG.toggles[k]
            if t and t.get() ~= s then t.set(s, true) end
        end
    end, nil, "fpsBoost")
    createToggle("Sin partículas", "Apaga los efectos masivos de frutas y habilidades", 10, page,
        function(s) X.noParticles = s; Perf.setParticles(s) end, nil, "noParticles")
    createToggle("Gráficos bajos", "Agua simple, sin sombras ni efectos de luz", 11, page,
        function(s) X.lowGfx = s; Perf.setGfx(s) end, nil, "lowGfx")
    createToggle("Limitar a 60 FPS", "FPS estables en peleas masivas (requiere setfpscap)", 12, page,
        function(s) X.cap60 = s; Perf.setCap(s) end, nil, "cap60")
end

-- ══════════════════════════════════════════════
--                PESTAÑA ATAJOS
-- ══════════════════════════════════════════════

do
    local page = makePage("kb", "Atajos", "Asigna teclas o botones del ratón")
    createInfo(page, 1, "Haz clic en un atajo y pulsa la nueva tecla o botón del ratón (clic derecho / central). Esc cancela · Retroceso lo quita.", 54)

    local function toggleKey(k)
        return function()
            local t = CFG.toggles[k]
            if t then t.set(not t.get()) end
        end
    end

    local defs = {
        { "hub",     "Mostrar / ocultar el Hub",  function() setVis(not mainHub.Visible) end },
        { "camLock", "Cam Lock",                   toggleKey("camLock") },
        { "strafe",  "Target Strafe",              toggleKey("strafe") },
        { "esp",     "ESP Jugadores",              toggleKey("esp") },
        { "boxEsp",  "Box ESP",                    toggleKey("boxEsp") },
        { "radar",   "Radar 2D",                   toggleKey("radar") },
        { "autoM1",  "Auto M1",                    toggleKey("autoM1") },
        { "fps",     "FPS Booster",                toggleKey("fpsBoost") },
        { "nearest", "Fijar objetivo más cercano", function()
            local p = findNearestPlayer()
            if p then setTarget(p) else notify("Objetivo", "No hay jugadores cerca", THEME.warn) end
        end },
    }

    local rows = {}
    for i, d in ipairs(defs) do
        local key, text, fire = d[1], d[2], d[3]
        KB.labels[key] = text
        KB.actions[key] = fire

        local row = card(page, 44, i + 1)
        local l = label(row, text, 12, Enum.Font.GothamBold, THEME.text)
        l.Size = UDim2.new(1, -190, 1, 0); l.Position = UDim2.new(0, 14, 0, 0)

        local kbtn = create("TextButton", {
            Size = UDim2.new(0, 116, 0, 28), Position = UDim2.new(1, -164, 0.5, -14),
            BackgroundColor3 = THEME.bg, Text = "", TextColor3 = THEME.accent2,
            Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false, BorderSizePixel = 0,
        }, row)
        applyCorner(kbtn, 8)
        applyStroke(kbtn, THEME.stroke, 1)
        kbtn.MouseButton1Click:Connect(function()
            KB.listening = key
            refreshBindRows()
        end)

        local clr = nil
        if key ~= "hub" then
            clr = miniBtn(row, "✕", UDim2.new(1, -42, 0.5, -14), UDim2.new(0, 28, 0, 28), "danger", function()
                KB.assign(key, nil)
            end)
        end
        rows[key] = { btn = kbtn, clear = clr }
    end

    refreshBindRows = function()
        for key, r in pairs(rows) do
            if KB.listening == key then
                r.btn.Text = "Pulsa una tecla…"
                r.btn.TextColor3 = THEME.warn
            else
                r.btn.Text = KB.text(KB.binds[key])
                r.btn.TextColor3 = KB.binds[key] and THEME.accent2 or THEME.muted
            end
            if r.clear then r.clear.Visible = (KB.binds[key] ~= nil) end
        end
        UI.footerHint.Text = KB.text(KB.binds.hub) .. " · ocultar"
    end

    createButtons(page, #defs + 2, {
        { text = "↺  Restablecer atajos", kind = "neutral", cb = function()
            KB.binds = { hub = { t = "K", n = "RightControl" } }
            KB.listening = nil
            refreshBindRows()
        end },
    })
    refreshBindRows()
end

-- ══════════════════════════════════════════════
--       PESTAÑA AJUSTES (TEMAS + PERFILES)
-- ══════════════════════════════════════════════

do
    local page = makePage("st", "Ajustes", "Temas, interfaz y perfiles")

    sectionLabel(page, "Tema", 1)
    local grid = create("Frame", { Size = UDim2.new(1, 0, 0, 190), BackgroundTransparency = 1, LayoutOrder = 2 }, page)
    create("UIGridLayout", {
        CellSize = UDim2.new(0.5, -4, 0, 58), CellPadding = UDim2.new(0, 8, 0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, grid)

    local cards = {}
    refreshThemeCards = function()
        for name, c in pairs(cards) do
            local on = (name == X.theme)
            c.stroke.Color = on and THEME.accent or THEME.stroke
            c.check.Visible = on
        end
    end

    for i, def in ipairs(THEME_LIST) do
        local btn = create("TextButton", {
            BackgroundColor3 = THEME.card, Text = "", AutoButtonColor = false,
            BorderSizePixel = 0, LayoutOrder = i,
        }, grid)
        applyCorner(btn, 10)
        local st = applyStroke(btn, THEME.stroke, 1.5)

        local swatches = { def.c.bg, def.c.accent, def.c.accent2, def.c.text }
        for j, col in ipairs(swatches) do
            local s = create("Frame", {
                Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(0, 12 + (j - 1) * 20, 0, 10),
                BackgroundColor3 = col, BorderSizePixel = 0,
            }, btn)
            s:SetAttribute("NoTheme", true)
            applyCorner(s, 8)
            local ss = applyStroke(s, Color3.fromRGB(255, 255, 255), 1, 0.75)
            ss:SetAttribute("NoTheme", true)
        end

        local nm = label(btn, def.name, 11, Enum.Font.GothamBold, THEME.text)
        nm.Size = UDim2.new(1, -24, 0, 16); nm.Position = UDim2.new(0, 12, 0, 33)
        local check = label(btn, "✓", 13, Enum.Font.GothamBlack, THEME.accent2, Enum.TextXAlignment.Right)
        check.Size = UDim2.new(0, 24, 0, 18); check.Position = UDim2.new(1, -34, 0, 8)

        cards[def.name] = { stroke = st, check = check }
        btn.MouseButton1Click:Connect(function()
            applyTheme(def)
            notify("🎨 Tema aplicado", def.name, THEME.accent, 1.6)
        end)
    end
    refreshThemeCards()

    sectionLabel(page, "Interfaz", 3)
    createSlider("TAMAÑO DE LA INTERFAZ", 4, page, 1.3, function(v) hubScale.Scale = v end, 0.7, 1, "x%.2f", "uiScale")
    createToggle("Notificaciones", "Avisos emergentes al activar funciones", 5, page,
        function(s) X.notifications = s end, true, "notifs")

    sectionLabel(page, "Perfiles", 6)
    if not FS.ok then
        createInfo(page, 7, "Tu executor no expone writefile/readfile: los perfiles y waypoints solo duran mientras el script siga abierto.", 54)
    end
    createTextAction(page, 8, "Nombre del perfil…", "💾 Guardar", function(text, box)
        local ok, res = Prof.save(text)
        if ok then
            notify("💾 Perfil guardado", res, THEME.ok)
            box.Text = ""
            rebuildProfileList()
        else
            notify("Perfiles", res, THEME.danger)
        end
    end)

    local plist = create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 150), BackgroundColor3 = THEME.panel, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = THEME.accent,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, LayoutOrder = 9,
    }, page)
    applyCorner(plist, 10)
    applyStroke(plist, THEME.stroke, 1)
    create("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, plist)
    applyPadding(plist, 6, 6, 6, 6)

    rebuildProfileList = function()
        for _, c in ipairs(plist:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end
        local names = Prof.names()
        local auto = Prof.autoload()
        for i, n in ipairs(names) do
            local row = create("Frame", {
                Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = THEME.card,
                BorderSizePixel = 0, LayoutOrder = i,
            }, plist)
            applyCorner(row, 8)
            local nl = label(row, n, 12, Enum.Font.GothamBold, THEME.text)
            nl.Size = UDim2.new(1, -170, 1, 0); nl.Position = UDim2.new(0, 12, 0, 0)
            nl.TextTruncate = Enum.TextTruncate.AtEnd

            miniBtn(row, "Cargar", UDim2.new(1, -148, 0.5, -13), UDim2.new(0, 60, 0, 26), "primary", function()
                if Prof.load(n) then
                    notify("📂 Perfil cargado", n, THEME.ok)
                else
                    notify("Perfiles", "No se pudo cargar «" .. n .. "»", THEME.danger)
                end
            end)

            local isAuto = (auto == n)
            local star = miniBtn(row, isAuto and "★" or "☆", UDim2.new(1, -82, 0.5, -13), UDim2.new(0, 32, 0, 26), "neutral", function()
                if isAuto then
                    Prof.setAutoload("")
                    notify("Autocarga", "Desactivada", THEME.muted, 1.6)
                else
                    Prof.setAutoload(n)
                    notify("★ Autocarga", "Se cargará «" .. n .. "» al iniciar", THEME.warn, 2)
                end
                rebuildProfileList()
            end)
            if isAuto then star.TextColor3 = THEME.warn end

            miniBtn(row, "🗑", UDim2.new(1, -44, 0.5, -13), UDim2.new(0, 32, 0, 26), "danger", function()
                Prof.delete(n)
                if auto == n then Prof.setAutoload("") end
                rebuildProfileList()
            end)
        end
        if #names == 0 then
            local e = label(plist, "Sin perfiles guardados todavía.", 11, Enum.Font.Gotham, THEME.muted, Enum.TextXAlignment.Center)
            e.Size = UDim2.new(1, 0, 0, 40)
        end
    end
    rebuildProfileList()

    sectionLabel(page, "Acerca de", 10)
    createInfo(page, 11, "R_ZONE HUB V3.4 · Professional Edition\nCreador: R_Zone  ·  " .. BF.sea .. "\nTemas: Nebula · Crimson · Neon · Emerald · Stealth", 70)
end

-- ══════════════════════════════════════════════
--     PESTAÑA EVENTOS (LUNA · ESPEJISMO · MAR)
-- ══════════════════════════════════════════════

do
    local page = makePage("ev", "Eventos", "Luna, Isla Espejismo, eventos marinos, frutas y flores")

    sectionLabel(page, "Luna", 1)
    local mc = card(page, 84, 2)
    UI.moonIcon = label(mc, "🌙", 38, Enum.Font.GothamBold, THEME.text, Enum.TextXAlignment.Center)
    UI.moonIcon.Size = UDim2.new(0, 60, 0, 60); UI.moonIcon.Position = UDim2.new(0, 10, 0, 12)
    UI.moonName = label(mc, "—", 16, Enum.Font.GothamBlack, THEME.text)
    UI.moonName.Size = UDim2.new(1, -90, 0, 22); UI.moonName.Position = UDim2.new(0, 78, 0, 12)
    UI.moonSub = label(mc, "", 10, Enum.Font.Gotham, THEME.muted)
    UI.moonSub.Size = UDim2.new(1, -90, 0, 14); UI.moonSub.Position = UDim2.new(0, 78, 0, 36)
    UI.moonTimer = label(mc, "", 11, Enum.Font.GothamBold, THEME.accent2)
    UI.moonTimer.Size = UDim2.new(1, -90, 0, 16); UI.moonTimer.Position = UDim2.new(0, 78, 0, 54)

    sectionLabel(page, "Isla Espejismo", 3)
    local mg = card(page, 52, 4)
    UI.mirageText = label(mg, "No detectada en este servidor", 12, Enum.Font.GothamBold, THEME.text)
    UI.mirageText.Size = UDim2.new(1, -100, 1, 0); UI.mirageText.Position = UDim2.new(0, 14, 0, 0)
    UI.mirageBtn = miniBtn(mg, "TP", UDim2.new(1, -62, 0.5, -13), UDim2.new(0, 48, 0, 26), "primary", function()
        if World.mirage and World.mirage.pos then WP.teleport(World.mirage.pos) end
    end)
    UI.mirageBtn.Visible = false

    sectionLabel(page, "Alertas", 5)
    createToggle("Aviso de Luna Llena", "Banner y sonido cuando empieza", 6, page, function(s) X.notifMoon = s end, true, "notifMoon")
    createToggle("Aviso de Isla Espejismo", "Cuando aparece en el servidor", 7, page, function(s) X.notifMirage = s end, true, "notifMirage")
    createToggle("Aviso de eventos marinos", "Sea Beast, Leviathan, Terrorshark, Ghost Ship", 8, page, function(s) X.notifSea = s end, true, "notifSea")
    createToggle("Aviso de frutas y flores", "Cuando cae una fruta o aparece una flor", 9, page, function(s) X.notifFruit = s end, true, "notifFruit")
    createToggle("Banner en pantalla", "Cartel grande en la parte superior", 10, page, function(s) X.alertBanner = s end, true, "alertBanner")
    createToggle("Sonido de alerta", "Pitido al detectar un evento", 11, page, function(s) X.alertSound = s end, true, "alertSound")
    createSlider("VOLUMEN DE ALERTAS", 12, page, 1, function(v) X.alertVolume = v end, 0, 0.8, "%.2f", "alertVolume")
    createButtons(page, 13, {
        { text = "🔔  Probar alerta", kind = "primary", cb = function()
            Alerts.fire("🔔 Alerta de prueba", "Así se verán los avisos", THEME.accent)
        end },
    })
    createToggle("Brújula de eventos", "Panel con flecha y distancia (arrastrable)", 14, page, function(s) X.compass = s end, true, "compass")

    sectionLabel(page, "Eventos marinos", 15)
    createToggle("Sea Events ESP", "Etiquetas 3D sobre los eventos y la Isla Espejismo", 16, page, function(s) X.seaEsp = s end, nil, "seaEsp")
    UI.seaList = createLiveList(page, 17, 120, "Sin eventos marinos activos")

    sectionLabel(page, "Frutas sueltas (desaparecen a los ~20 min)", 18)
    UI.fruitList = createLiveList(page, 19, 130, "Sin frutas detectadas en el servidor")

    sectionLabel(page, "Flores (Raza V2)", 20)
    createToggle("Flower ESP", "Marca la Flor Azul, Roja y Amarilla", 21, page, function(s) X.flowerEsp = s end, nil, "flowerEsp")
    UI.flowerList = createLiveList(page, 22, 110, "Sin flores detectadas")
end

-- ══════════════════════════════════════════════
--         PESTAÑA BOSSES (ESTADO DE SPAWN)
-- ══════════════════════════════════════════════

do
    local page = makePage("bs", "Bosses", "Estado de spawn de los bosses · " .. BF.sea)
    createToggle("Boss ESP", "Etiqueta 3D con vida y distancia de los bosses vivos", 1, page, function(s) X.bossEsp = s end, nil, "bossEsp")
    createToggle("Aviso de respawn", "Alerta cuando un boss vuelve a aparecer", 2, page, function(s) X.notifBoss = s end, nil, "notifBoss")
    UI.bossList = createLiveList(page, 3, 340, "No hay lista de bosses configurada para este mapa")
end

-- ══════════════════════════════════════════════
--     PESTAÑA AUTO (STATS · MAESTRÍA · DIÁLOGOS)
-- ══════════════════════════════════════════════

do
    local page = makePage("au", "Automatización", "Stats, maestría y diálogos de NPC")

    sectionLabel(page, "Auto-Stats", 1)
    local pc = card(page, 44, 2)
    UI.points = label(pc, "Puntos disponibles: —", 12, Enum.Font.GothamBold, THEME.text)
    UI.points.Size = UDim2.new(1, -28, 1, 0); UI.points.Position = UDim2.new(0, 14, 0, 0)
    createToggle("Auto-Stats", "Asigna los puntos al atributo elegido al subir de nivel", 3, page,
        function(s) X.autoStats = s end, nil, "autoStats")
    createSegment("Atributo", 4, page, {
        { label = "Melee",   value = "Melee"   }, { label = "Defense", value = "Defense" },
        { label = "Sword",   value = "Sword"   }, { label = "Gun",     value = "Gun"     },
        { label = "Fruta",   value = "Fruit"   },
    }, "Melee", function(v) X.statChoice = v end, "statChoice")
    createButtons(page, 5, {
        { text = "📈  Asignar ahora", kind = "primary", cb = function() Ext.assignNow(false) end },
    })

    sectionLabel(page, "Mastery Farm helper", 6)
    createToggle("Auto-equipar con poca vida", "Cambia al arma de maestría cuando el enemigo está casi muerto", 7, page,
        function(s) X.mastery = s end, nil, "mastery")
    createSegment("Arma a subir de maestría", 8, page, {
        { label = "Melee", value = "Melee" }, { label = "Sword", value = "Sword" },
        { label = "Gun",   value = "Gun"   }, { label = "Fruta", value = "Fruit" },
    }, "Sword", function(v) X.masteryType = v end, "masteryType")
    createSegment("Arma principal (resto del combate)", 9, page, {
        { label = "Melee", value = "Melee" }, { label = "Sword", value = "Sword" },
        { label = "Gun",   value = "Gun"   }, { label = "Fruta", value = "Fruit" },
        { label = "Ninguna", value = "None" },
    }, "Melee", function(v) X.mainType = v end, "mainType")
    createSlider("UMBRAL DE VIDA DEL ENEMIGO", 10, page, 40, function(v) X.masteryHp = v end, 5, 15, "%.0f%%", "masteryHp")
    createSlider("RADIO DE DETECCIÓN", 11, page, 200, function(v) X.masteryRange = v end, 20, 80, "%.0f studs", "masteryRange")

    sectionLabel(page, "Diálogos y misiones", 12)
    createToggle("Saltar diálogos", "Pulsa Skip / Siguiente / Continuar por ti", 13, page,
        function(s) X.fastDialog = s end, nil, "fastDialog")
    createToggle("Aceptar misiones", "Pulsa Aceptar / Sí en diálogos de NPC (evita tiendas)", 14, page,
        function(s) X.autoAccept = s end, nil, "autoAccept")
    createInfo(page, 15, "Busca los botones dentro de las rutas de BF.dialog.roots y evita ventanas de compra. Si tu versión del juego usa otra interfaz, ajusta esa tabla al inicio del script.", 64)
end

-- ══════════════════════════════════════════════
--        PANEL EN VIVO (EVENTOS / BOSSES / PUNTOS)
-- ══════════════════════════════════════════════

do
    local function fmtMs(sec)
        return string.format("%d:%02d", math.floor(sec / 60), math.floor(sec) % 60)
    end

    UI.tick = function()
        local now = os.clock()
        local myChar = LocalPlayer.Character
        local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local myPos = myHrp and myHrp.Position
        local function dist(p)
            if myPos and p then return math.floor((p - myPos).Magnitude) end
            return nil
        end

        -- Luna
        local m = World.moon
        UI.moonIcon.Text = m.icon
        UI.moonName.Text = m.full and (m.name .. "  ·  ACTIVA") or m.name
        UI.moonName.TextColor3 = m.full and rgb(255, 235, 140) or THEME.text
        UI.moonSub.Text = "ID " .. (m.num ~= "" and m.num or "—") .. "  ·  " .. (m.night and "Noche" or "Día")
        if m.fullSince and (now - m.fullSince) < BF.fullMoonDuration then
            UI.moonTimer.Text = "🌕 Luna llena · ~" .. fmtMs(BF.fullMoonDuration - (now - m.fullSince)) .. " restantes (aprox.)"
        elseif m.full then
            UI.moonTimer.Text = "🌕 Luna llena (detectada por la textura del cielo)"
        else
            UI.moonTimer.Text = ""
        end

        -- Isla Espejismo
        local mg = World.mirage
        if mg then
            UI.mirageText.Text = "🏝 ¡Presente!  ·  " .. tostring(dist(mg.pos) or "?") .. "m"
            UI.mirageText.TextColor3 = rgb(120, 230, 255)
            UI.mirageBtn.Visible = true
        else
            UI.mirageText.Text = "No detectada en este servidor"
            UI.mirageText.TextColor3 = THEME.text
            UI.mirageBtn.Visible = false
        end

        -- Eventos marinos
        local ev = {}
        for _, e in pairs(World.events) do ev[#ev + 1] = e end
        table.sort(ev, function(a, b) return a.id < b.id end)
        local items = {}
        for _, e in ipairs(ev) do
            if e.part and e.part.Parent then
                items[#items + 1] = {
                    key = "ev" .. e.id, title = e.def.icon .. " " .. e.def.label,
                    sub = "Distancia: " .. tostring(dist(e.part.Position) or "?") .. "m", pos = e.part.Position,
                }
            end
        end
        UI.seaList.set(items)

        -- Frutas
        local fr = {}
        for _, e in pairs(World.fruits) do fr[#fr + 1] = e end
        table.sort(fr, function(a, b) return a.id < b.id end)
        items = {}
        for _, e in ipairs(fr) do
            if e.part and e.part.Parent then
                local rem = BF.fruitDespawn - (now - e.seen)
                local badge, bcol = "⏳ ya", THEME.danger
                if rem > 0 then
                    badge = "⏳ " .. fmtMs(rem)
                    bcol = (rem < 300) and THEME.danger or THEME.warn
                end
                items[#items + 1] = {
                    key = "fr" .. e.id, title = "🍎 " .. e.name,
                    sub = "Distancia: " .. tostring(dist(e.part.Position) or "?") .. "m  ·  tiempo aproximado",
                    pos = e.part.Position, badge = badge, badgeColor = bcol,
                }
            end
        end
        UI.fruitList.set(items)

        -- Flores
        local fl = {}
        for _, e in pairs(World.flowers) do fl[#fl + 1] = e end
        table.sort(fl, function(a, b) return a.id < b.id end)
        items = {}
        for _, e in ipairs(fl) do
            if e.part and e.part.Parent then
                items[#items + 1] = {
                    key = "fl" .. e.id, title = "🌸 " .. (e.label or "Flor"),
                    sub = e.name .. "  ·  " .. tostring(dist(e.part.Position) or "?") .. "m",
                    pos = e.part.Position, badge = "FLOR", badgeColor = e.color or THEME.accent2,
                }
            end
        end
        UI.flowerList.set(items)

        -- Bosses
        items = {}
        local names = BF.bosses[game.PlaceId]
        if names then
            local alive, dead = {}, {}
            for _, name in ipairs(names) do
                local b = World.bosses[name]
                if b and b.state == "alive" then alive[#alive + 1] = name else dead[#dead + 1] = name end
            end
            for _, name in ipairs(alive) do
                local b = World.bosses[name]
                items[#items + 1] = {
                    key = "bs" .. name, title = "👑 " .. name,
                    sub = string.format("HP %d%%  ·  %sm", math.floor((b.hp or 1) * 100), tostring(dist(b.pos) or "?")),
                    pos = b.pos, badge = "VIVO", badgeColor = THEME.ok,
                }
            end
            for _, name in ipairs(dead) do
                local b = World.bosses[name]
                local sub = "sin datos de respawn"
                if b and b.deadAt then sub = "muerto hace " .. fmtMs(now - b.deadAt) end
                items[#items + 1] = {
                    key = "bs" .. name, title = name, sub = sub,
                    badge = (b and b.state == "unknown") and "…" or "MUERTO", badgeColor = THEME.danger,
                }
            end
        end
        UI.bossList.set(items)

        -- Puntos de stats
        local pts = Ext.points()
        if pts then
            UI.points.Text = "Puntos disponibles: " .. pts
        else
            UI.points.Text = "Puntos disponibles: —  (no se encontró Data/Points)"
        end
    end
end

-- ══════════════════════════════════════════════
--     PESTAÑAS / ARRASTRE / VISIBILIDAD
-- ══════════════════════════════════════════════

do
    local tabs = {
        { "hb", "⚔", "Hitbox"   }, { "mv", "⚡", "Movim."   }, { "tg", "🎯", "Objetivo" }, { "cm", "🔒", "Combate" },
        { "vs", "👁", "Visual"   }, { "ev", "🌙", "Eventos"  }, { "bs", "👑", "Bosses"   }, { "wd", "🌍", "Mundo"   },
        { "au", "🤖", "Auto"     }, { "ex", "⚙", "Extra"    }, { "kb", "⌨", "Atajos"   }, { "st", "🎨", "Ajustes" },
    }
    local btns = {}

    local function setTab(active)
        for j, row in ipairs(btns) do
            local on = (j == active)
            local page = P[tabs[j][1]]
            if on and not page.Visible then
                page.Position = UDim2.new(0, 16, 0, 0)
                tween(page, { Position = UDim2.new(0, 0, 0, 0) }, 0.22)
            end
            page.Visible = on
            tween(row.btn, { BackgroundColor3 = on and THEME.selected or THEME.panel, BackgroundTransparency = on and 0 or 1 })
            row.btn.TextColor3 = on and THEME.text or THEME.muted
            tween(row.bar, { BackgroundTransparency = on and 0 or 1 })
        end
    end

    for i, t in ipairs(tabs) do
        local b = create("TextButton", {
            Size = UDim2.new(1, 0, 0, 34), LayoutOrder = i,
            BackgroundColor3 = THEME.panel, BackgroundTransparency = 1,
            Text = t[2] .. "  " .. t[3], TextColor3 = THEME.muted,
            Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
            AutoButtonColor = false, BorderSizePixel = 0,
        }, UI.tabList)
        applyCorner(b, 9)
        applyPadding(b, 16, 0, 0, 0)

        local bar = create("Frame", {
            Size = UDim2.new(0, 3, 0, 18), Position = UDim2.new(0, -6, 0.5, -9),
            BackgroundColor3 = THEME.accent2, BackgroundTransparency = 1, BorderSizePixel = 0,
        }, b)
        applyCorner(bar, 2)

        btns[i] = { btn = b, bar = bar }
        b.MouseEnter:Connect(function()
            if not P[t[1]].Visible then tween(b, { BackgroundTransparency = 0.6, BackgroundColor3 = THEME.card }) end
        end)
        b.MouseLeave:Connect(function()
            if not P[t[1]].Visible then tween(b, { BackgroundTransparency = 1 }) end
        end)
        b.MouseButton1Click:Connect(function() setTab(i) end)
    end
    setTab(1)

    local dragT, dS, sP = false, nil, nil
    UI.topBar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragT = true; dS = i.Position; sP = mainHub.Position end end)
    UserInputService.InputChanged:Connect(function(i) if dragT and i.UserInputType == Enum.UserInputType.MouseMovement then local d = (i.Position - dS) / hubScale.Scale; mainHub.Position = UDim2.new(sP.X.Scale, sP.X.Offset + d.X, sP.Y.Scale, sP.Y.Offset + d.Y) end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragT = false end end)
end

setVis = function(v)
    mainHub.Visible = v
    bubble.Visible = not v
    if not v then
        bubble.Position = UDim2.new(0, mainHub.AbsolutePosition.X, 0, mainHub.AbsolutePosition.Y)
    end
end
bubble.MouseButton1Click:Connect(function() setVis(true) end)
UI.min.MouseButton1Click:Connect(function() setVis(false) end)

-- Despachador de atajos (reemplaza la tecla fija RightControl)
UserInputService.InputBegan:Connect(function(input, gp)
    if KB.listening then
        local ut = input.UserInputType
        if ut == Enum.UserInputType.Keyboard then
            local kc = input.KeyCode
            if kc == Enum.KeyCode.Unknown then return end
            if kc == Enum.KeyCode.Escape then
                KB.listening = nil
                refreshBindRows()
            elseif kc == Enum.KeyCode.Backspace or kc == Enum.KeyCode.Delete then
                KB.assign(KB.listening, nil)
            else
                KB.assign(KB.listening, { t = "K", n = kc.Name })
            end
        elseif ut == Enum.UserInputType.MouseButton2 or ut == Enum.UserInputType.MouseButton3 then
            KB.assign(KB.listening, { t = "M", n = ut.Name })
        end
        return
    end
    if gp then return end
    for key, b in pairs(KB.binds) do
        if KB.matches(b, input) then
            local f = KB.actions[key]
            if f then f() end
        end
    end
end)

-- ══════════════════════════════════════════════
--     LOOP DE ESTADO (FPS / PING / FOOTER / STATS)
-- ══════════════════════════════════════════════

do
    local frames, lastT = 0, os.clock()
    RunService.RenderStepped:Connect(function() frames = frames + 1 end)

    local function fmtTime(sec)
        sec = math.floor(sec)
        return string.format("%02d:%02d:%02d", math.floor(sec / 3600), math.floor(sec / 60) % 60, sec % 60)
    end

    task.spawn(function()
        while true do
            task.wait(0.5)
            pcall(function()
                local now = os.clock()
                local fps = math.floor(frames / math.max(now - lastT, 0.001) + 0.5)
                frames, lastT = 0, now

                local ping = 0
                pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)

                UI.fps.Text = "FPS " .. fps
                UI.fps.TextColor3 = fps >= 50 and THEME.ok or (fps >= 30 and THEME.warn or THEME.danger)
                UI.ping.Text = "Ping " .. ping .. " ms"
                UI.ping.TextColor3 = ping <= 120 and THEME.accent2 or (ping <= 250 and THEME.warn or THEME.danger)

                UI.stats[1].Text = tostring(#Players:GetPlayers())
                UI.stats[2].Text = ping .. "ms"
                UI.stats[3].Text = fmtTime(now - X.sessionStart)

                local parts = {
                    "⚔ " .. (currentMode.key == "normal" and "Normal" or currentMode.key),
                    "🎯 " .. (X.target and X.target.DisplayName or "—"),
                    "🛡 AFK " .. (X.antiAfk and "ON" or "OFF"),
                }
                if X.camLock then table.insert(parts, "🔒 CamLock") end
                if X.strafe  then table.insert(parts, "🌀 Strafe") end
                table.insert(parts, World.moon.icon .. (World.moon.full and " Luna llena" or ""))
                UI.footerText.Text = table.concat(parts, "   •   ")

                UI.serverInfo.Text = string.format("%s  ·  %d/%d jugadores", BF.sea, #Players:GetPlayers(), Players.MaxPlayers)
                if game.JobId ~= "" then
                    UI.jobLabel.Text = "JobId: " .. game.JobId:sub(1, 22) .. "…"
                else
                    UI.jobLabel.Text = "JobId: (Studio)"
                end

                local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                for plr, row in pairs(UI.playerRows) do
                    local th = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                    if row.dist and row.dist.Parent then
                        row.dist.Text = (myHrp and th) and (math.floor((myHrp.Position - th.Position).Magnitude) .. "m") or "--"
                    end
                end
                for _, r in ipairs(UI.wpRows) do
                    if r.sub and r.sub.Parent and myHrp then
                        local e = r.entry
                        local d = (myHrp.Position - Vector3.new(e.x or 0, e.y or 0, e.z or 0)).Magnitude
                        r.sub.Text = r.coords .. "   ·   " .. math.floor(d) .. "m"
                    end
                end

                ensureTargetMarker()
            end)
        end
    end)
end

-- ══════════════════════════════════════════════
--                     LOOPS
-- ══════════════════════════════════════════════

task.spawn(function()
    while true do
        if autoM1Enabled then
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true,  game, 0); task.wait(0.01)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0); task.wait(fastM1Enabled and 0.04 or 0.25)
        else task.wait(0.5) end
    end
end)

RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character; if not char then return end
    local h = char:FindFirstChildOfClass("Humanoid")
    if h then
        if not speedConn then hookMovement(h) end
        if speedMultiplier > 1 then h.WalkSpeed = BASE_WALKSPEED * speedMultiplier end
        if jumpMultiplier > 1 then h.JumpPower = BASE_JUMPPOWER * jumpMultiplier; h.UseJumpPower = true end
    end
    
    if currentMode.key ~= "normal" then
        if tick() - lastCacheTime > CACHE_INTERVAL then refreshEnemyCache(); lastCacheTime = tick() end
        
        -- 1. Ampliar enemigos (HRP)
        for _, hrp in ipairs(enemyCache) do 
            if hrp and hrp.Parent then 
                processHitbox(hrp, currentMode.enemySize, false) 
            end 
        end
        
        -- 2. Ampliar cliente (HRP local anti-float)
        local localHrp = char:FindFirstChild("HumanoidRootPart")
        if localHrp then
            processHitbox(localHrp, currentMode.enemySize, true)
            
            -- FIX 100% DAÑO BLOX FRUITS: Si estás atacando (clic o herramienta activa), alinea temporalmente el contacto al enemigo más cercano
            if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                for _, hrp in ipairs(enemyCache) do
                    if hrp and hrp.Parent and (hrp.Position - localHrp.Position).Magnitude <= (currentMode.enemySize.X / 1.5) then
                        -- Fuerza la sincronización de proximidad para el registro de daño del servidor
                        local tool = char:FindFirstChildOfClass("Tool")
                        if tool and tool:FindFirstChild("Handle") then
                            tool.Handle.CFrame = hrp.CFrame
                        end
                        break
                    end
                end
            end
        end
        
        -- 3. Ampliar herramientas equipadas
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then
                for _, part in ipairs(tool:GetDescendants()) do
                    if part:IsA("BasePart") then
                        processHitbox(part, currentMode.enemySize, false)
                    end
                end
            end
        end
    else
        restoreOriginalSizes()
    end
    
    updateESP()
end)

-- ESP 2D (después de la cámara)
RunService:BindToRenderStep("RZoneESP2D", Enum.RenderPriority.Camera.Value + 2, function()
    pcall(updateEsp2D)
end)

-- Radar (~30 fps)
do
    local acc = 0
    RunService.Heartbeat:Connect(function(dt)
        acc = acc + dt
        if acc >= 1 / 30 then
            acc = 0
            pcall(updateRadar)
        end
    end)
end

-- Escáner del mundo + panel de eventos (1 vez por segundo)
task.spawn(function()
    while true do
        task.wait(1)
        pcall(scanWorld)
        pcall(function() if UI.tick then UI.tick() end end)
    end
end)

-- Brújula de eventos (10 Hz)
do
    local acc = 0
    RunService.Heartbeat:Connect(function(dt)
        acc = acc + dt
        if acc >= 0.1 then
            acc = 0
            pcall(updateCompass)
        end
    end)
end

-- ══════════════════════════════════════════════
--                    ARRANQUE
-- ══════════════════════════════════════════════

if startupConfig then
    local ok = pcall(Prof.apply, startupConfig)
    if ok then
        task.delay(5.8, function() notify("📂 Perfil cargado", "Autocarga aplicada", THEME.ok, 2.5) end)
    end
end

task.delay(5.5, function()
    notify("R_ZONE HUB 3.4", BF.sea .. " · " .. KB.text(KB.binds.hub) .. " para ocultar", THEME.accent, 3)
end)

print("R_Zone HUB V3.4 — ACTIVADO (Eventos · Bosses · Auto · Radar · ESP+ · Temas · Perfiles)")

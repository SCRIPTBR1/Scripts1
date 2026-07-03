local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local DROP_ASCEND_DURATION = 0.2
local DROP_ASCEND_SPEED = 150
local dropBrainrotActive = false

local HIT_DIST = 8
local SWING_CD = 0.35
local CHASE_SPEED = 58

local cfg = {
    normalSpeed     = 60,
    carrySpeed      = 30,
    laggerSpeed     = 15,
    laggerCarrySpeed= 24.5,
    grabRadius      = 8,
    stealDuration   = 1.4,
    tpDownHeight    = 20,
    currentMode     = "Normal",
    laggerMode      = false,
    speedEnabled    = true,
    autoBat         = false,
    autoGrab        = false,
    infiniteJump    = false,
    antiRagdoll     = false,
    unwalk          = false,
    medusaCounter   = false,
    batCounter      = false,
    autoLeft        = false,
    autoRight       = false,
    autoLeftPhase   = 1,
    autoRightPhase  = 1,
    autoTPDown      = false,
    autoTPDownThreshold = 20,
    antiLag         = false,
    stretchRez      = false,
    removeAccess    = false,
    darkMode        = false,
    lockUI          = false,
    hideKey         = Enum.KeyCode.LeftControl,
    autoLeftKey     = Enum.KeyCode.Z,
    autoRightKey    = Enum.KeyCode.C,
    dropKey         = Enum.KeyCode.X,
    tpDownKey       = Enum.KeyCode.F,
    autoBatKey      = Enum.KeyCode.E,
    laggerKey       = Enum.KeyCode.R,
    modeKey         = Enum.KeyCode.Q,
    
    autoSwing       = true,
    uiScale         = 100,
    mobilePanelXOffset = -162,
    mobilePanelScale = 100,
    mobilePanelYOffset = -370,
    mainPanelPosition = nil,
    miniPanelPosition = nil,
}

local saveConfig
local SG, Main, UIScaleInst, EnvyMini, MobPanel, MobPanelScale
local _toggleSetters = {}
local _inputBoxes = {}
local _keybindBtns = {}

local BAT_SLAP_LIST = { "Bat", "Slap", "Iron Slap", "Gold Slap", "Diamond Slap", "Emerald Slap", "Ruby Slap", "Dark Matter Slap", "Flame Slap", "Nuclear Slap", "Galaxy Slap", "Glitched Slap" }
local hittingCooldown = false
local aimbotConn = nil
local prevAutoRotate = nil

local WAYPOINTS = {
    L1 = Vector3.new(-476.48, -6.28, 92.73),
    L2 = Vector3.new(-483.12, -4.95, 94.80),
    R1 = Vector3.new(-476.16, -6.52, 25.62),
    R2 = Vector3.new(-483.04, -5.09, 23.14),
}

local function getChar() return LocalPlayer.Character end
local function getHRP()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getBat()
    local char = getChar()
    if not char then return nil end
    
    for _, name in ipairs(BAT_SLAP_LIST) do
        local t = char:FindFirstChild(name)
        if t and t:IsA("Tool") then return t end
    end
    
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then
        for _, name in ipairs(BAT_SLAP_LIST) do
            local t = bp:FindFirstChild(name)
            if t and t:IsA("Tool") then
                local hum = getHum()
                if hum then pcall(function() hum:EquipTool(t) end) end
                return t
            end
        end
    end
    
    for _, ch in ipairs(char:GetChildren()) do
        if ch:IsA("Tool") and (ch.Name:lower():find("bat") or ch.Name:lower():find("slap")) then return ch end
    end
    
    if bp then
        for _, ch in ipairs(bp:GetChildren()) do
            if ch:IsA("Tool") and (ch.Name:lower():find("bat") or ch.Name:lower():find("slap")) then
                local hum = getHum()
                if hum then pcall(function() hum:EquipTool(ch) end) end
                return ch
            end
        end
    end
    
    return nil
end

local function trySwing()
    if hittingCooldown or not cfg.autoSwing then return end
    hittingCooldown = true
    
    pcall(function()
        local char = getChar()
        if char then
            local bat = getBat()
            if bat then
                if bat.Parent ~= char then
                    local hum = getHum()
                    if hum then pcall(function() hum:EquipTool(bat) end) end
                end
                pcall(function() bat:Activate() end)
            end
        end
    end)
    
    task.delay(SWING_CD, function() hittingCooldown = false end)
end

local function getClosestPlayer()
    local char = getChar()
    if not char then return nil, math.huge end
    
    local hrp = getHRP()
    if not hrp then return nil, math.huge end
    
    local closest, dist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local tr = p.Character:FindFirstChild("HumanoidRootPart")
            local ph = p.Character:FindFirstChildOfClass("Humanoid")
            if tr and ph and ph.Health > 0 then
                local d = (hrp.Position - tr.Position).Magnitude
                if d < dist then
                    dist = d
                    closest = p
                end
            end
        end
    end
    return closest, dist
end

local function startAimbot()
    if aimbotConn then return end
    
    local hum = getHum()
    if hum then
        if prevAutoRotate == nil then
            prevAutoRotate = hum.AutoRotate
        end
        hum.AutoRotate = false
    end
    
    aimbotConn = RunService.RenderStepped:Connect(function()
        if not cfg.autoBat then return end
        
        local char = getChar()
        if not char then return end
        
        local root = getHRP()
        if not root then return end
        
        local hum = getHum()
        if not hum then return end
        
        if not char:FindFirstChildOfClass("Tool") then
            local bat = getBat()
            if bat then pcall(function() hum:EquipTool(bat) end) end
        end
        
        local targetPlr, targetDist = getClosestPlayer()
        if not targetPlr or not targetPlr.Character then return end
        
        local target = targetPlr.Character:FindFirstChild("HumanoidRootPart")
        if not target then return end
        
        local targetVel = target.AssemblyLinearVelocity
        local myPos = root.Position
        local targetPos = target.Position
        
        local predictPos = targetPos + targetVel * 0.14 + target.CFrame.LookVector * 0.3
        local direction = predictPos - myPos
        
        local flatDir = Vector3.new(direction.X, 0, direction.Z)
        if flatDir.Magnitude > 0 then
            flatDir = flatDir.Unit
        else
            flatDir = Vector3.new(0, 0, 0)
        end
        
        local desiredHeight = targetPos.Y + 3.7
        local yVel = (desiredHeight - myPos.Y) * 19.5 + targetVel.Y * 0.8
        
        if hum.FloorMaterial ~= Enum.Material.Air then
            yVel = math.max(yVel, 13)
        end
        yVel = math.clamp(yVel, -70, 110)
        
        local desiredVel = Vector3.new(
            flatDir.X * CHASE_SPEED,
            yVel,
            flatDir.Z * CHASE_SPEED
        )
        
        root.AssemblyLinearVelocity = root.AssemblyLinearVelocity:Lerp(desiredVel, 0.8)
        
        local speed3 = targetVel.Magnitude
        local predictTime = math.clamp(speed3 / 150, 0.05, 0.2)
        local predictedPos = targetPos + targetVel * predictTime
        local toPredict = predictedPos - myPos
        
        if toPredict.Magnitude > 0.1 then
            local goalCF = CFrame.lookAt(myPos, predictedPos)
            local diffCF = root.CFrame:Inverse() * goalCF
            local rx, ry, rz = diffCF:ToEulerAnglesXYZ()
            
            rx = math.clamp(rx, -2.5, 2.5)
            ry = math.clamp(ry, -2.5, 2.5)
            rz = math.clamp(rz, -2.5, 2.5)
            
            root.AssemblyAngularVelocity = root.CFrame:VectorToWorldSpace(
                Vector3.new(rx * 42, ry * 42, rz * 42)
            )
        end
        
        if cfg.autoSwing and targetDist <= HIT_DIST then
            trySwing()
        end
    end)
end

local function stopAimbot()
    if aimbotConn then
        aimbotConn:Disconnect()
        aimbotConn = nil
    end
    
    local char = getChar()
    local root = getHRP()
    local hum = getHum()
    
    if hum then
        hum.AutoRotate = (prevAutoRotate == nil) and true or prevAutoRotate
        hum.PlatformStand = false
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
    end
    
    if root then
        root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y * 0.3, 0)
        root.AssemblyAngularVelocity = Vector3.zero
    end
    
    prevAutoRotate = nil
end

LocalPlayer.CharacterAdded:Connect(function()
    prevAutoRotate = nil
    if cfg.autoBat then
        task.wait(0.5)
        stopAimbot()
        startAimbot()
    end
end)

local function runDropBrainrot()
    if dropBrainrotActive then return end
    local char = getChar()
    if not char then return end
    local root = getHRP()
    if not root then return end
    
    dropBrainrotActive = true
    local startTime = tick()
    local connection
    
    connection = RunService.Heartbeat:Connect(function()
        local r = getHRP()
        if not r then
            connection:Disconnect()
            dropBrainrotActive = false
            return
        end
        
        if tick() - startTime >= DROP_ASCEND_DURATION then
            connection:Disconnect()
            
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {char}
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude
            local rayResult = workspace:Raycast(r.Position, Vector3.new(0, -2000, 0), raycastParams)
            
            if rayResult then
                local hum = getHum()
                local offset = (hum and hum.HipHeight or 2) + (r.Size.Y / 2)
                r.CFrame = CFrame.new(r.Position.X, rayResult.Position.Y + offset, r.Position.Z)
                r.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            end
            
            dropBrainrotActive = false
            return
        end
        
        r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, DROP_ASCEND_SPEED, r.AssemblyLinearVelocity.Z)
    end)
end

local Unwalk = { 
    Enabled = false, 
    savedAnimate = nil,
    characterAddedConn = nil
}

local function enableUnwalk()
    if Unwalk.Enabled then return end
    Unwalk.Enabled = true
    
    local function removeAnimate(char)
        if not char then return end
        local h = char:FindFirstChildOfClass("Humanoid")
        if h then 
            for _, t in ipairs(h:GetPlayingAnimationTracks()) do 
                t:Stop() 
            end 
        end
        local a = char:FindFirstChild("Animate")
        if a then 
            if not Unwalk.savedAnimate then
                Unwalk.savedAnimate = a:Clone() 
            end
            a:Destroy() 
        end
    end
    
    local c = LocalPlayer.Character
    if c then removeAnimate(c) end
    
    if Unwalk.characterAddedConn then Unwalk.characterAddedConn:Disconnect() end
    Unwalk.characterAddedConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
        task.wait(0.5)
        if Unwalk.Enabled then removeAnimate(newChar) end
    end)
end

local function disableUnwalk()
    Unwalk.Enabled = false
    if Unwalk.characterAddedConn then
        Unwalk.characterAddedConn:Disconnect()
        Unwalk.characterAddedConn = nil
    end
    local c = LocalPlayer.Character
    if c and Unwalk.savedAnimate then
        local existing = c:FindFirstChild("Animate")
        if existing then existing:Destroy() end
        Unwalk.savedAnimate:Clone().Parent = c
        Unwalk.savedAnimate = nil
    end
end

local antiRagdollActive = false
local antiRagdollConnection = nil

local function startAntiRagdoll()
    if antiRagdollConnection then return end
    antiRagdollConnection = RunService.Heartbeat:Connect(function()
        if not antiRagdollActive then return end
        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            local humState = hum:GetState()
            if humState == Enum.HumanoidStateType.Physics or 
               humState == Enum.HumanoidStateType.Ragdoll or 
               humState == Enum.HumanoidStateType.FallingDown then
                hum:ChangeState(Enum.HumanoidStateType.Running)
                workspace.CurrentCamera.CameraSubject = hum
                pcall(function()
                    if LocalPlayer.Character then
                        local PlayerModule = LocalPlayer.PlayerScripts:FindFirstChild("PlayerModule")
                        if PlayerModule then
                            local Controls = require(PlayerModule:FindFirstChild("ControlModule"))
                            Controls:Enable()
                        end
                    end
                end)
                if root then
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                end
            end
        end
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("Motor6D") and obj.Enabled == false then
                obj.Enabled = true
            end
        end
    end)
end

local function stopAntiRagdoll()
    if antiRagdollConnection then
        antiRagdollConnection:Disconnect()
        antiRagdollConnection = nil
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    if antiRagdollActive then
        task.wait(0.5)
        stopAntiRagdoll()
        startAntiRagdoll()
    end
end)

local function tpDown()
    pcall(function()
        local char = getChar()
        if not char then return end
        local root = getHRP()
        if not root then return end
        
        local rp = RaycastParams.new()
        rp.FilterDescendantsInstances = {char}
        rp.FilterType = Enum.RaycastFilterType.Exclude
        
        local res = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rp)
        if res then
            root.CFrame = CFrame.new(res.Position + Vector3.new(0, root.Size.Y / 2 + 0.5, 0))
            root.AssemblyLinearVelocity = Vector3.zero
        end
    end)
end

local autoTPDownEnabled = false
local autoTPDownConnection = nil
local autoTPDownYThreshold = cfg.autoTPDownThreshold or 20

local function autoTPDownTeleport()
    local char = getChar()
    if not char then return end
    local hrp = getHRP()
    if not hrp then return end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {char}

    local rayResult = workspace:Raycast(hrp.Position, Vector3.new(0, -5000, 0), rayParams)
    if rayResult then
        local hum = getHum()
        local offset = (hum and hum.HipHeight or 2) + (hrp.Size.Y / 2)
        hrp.CFrame = CFrame.new(hrp.Position.X, rayResult.Position.Y + offset, hrp.Position.Z)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
end

local function startAutoTPDownSystem()
    if autoTPDownConnection then return end
    autoTPDownConnection = RunService.Heartbeat:Connect(function()
        if not autoTPDownEnabled then return end
        
        if not cfg.autoLeft and not cfg.autoRight then
            local hrp = getHRP()
            if hrp and hrp.Position.Y >= autoTPDownYThreshold then
                autoTPDownTeleport()
            end
        end
    end)
end

local function stopAutoTPDownSystem()
    if autoTPDownConnection then
        autoTPDownConnection:Disconnect()
        autoTPDownConnection = nil
    end
end

local function setAutoTPDownEnabled(state)
    autoTPDownEnabled = state
    cfg.autoTPDown = state
    if autoTPDownEnabled then
        startAutoTPDownSystem()
    else
        stopAutoTPDownSystem()
    end
    saveConfig()
end

local function setAutoTPDownThreshold(value)
    if value and value >= -5000 and value <= 5000 then
        autoTPDownYThreshold = value
        cfg.autoTPDownThreshold = value
        saveConfig()
    end
end

local function getTargetSpeed()
    if cfg.autoLeft or cfg.autoRight then
        if cfg.laggerMode then
            return cfg.laggerSpeed
        else
            return cfg.normalSpeed
        end
    end
    
    if cfg.laggerMode then
        if cfg.currentMode == "Carry" then
            return cfg.laggerCarrySpeed
        else
            return cfg.laggerSpeed
        end
    else
        if cfg.currentMode == "Carry" then
            return cfg.carrySpeed
        else
            return cfg.normalSpeed
        end
    end
end

local function applyAntiLag()
    pcall(function()
        setfflag("S2PhysicsSenderRate", "15000")
    end)
end

local _origQuality, _origFOV
local function applyStretchRez(on)
    pcall(function()
        local cam = workspace.CurrentCamera
        if on then
            if _origQuality == nil then
                _origQuality = settings().Rendering.QualityLevel
            end
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            if cam then
                if _origFOV == nil then _origFOV = cam.FieldOfView end
                cam.FieldOfView = 120
            end
            pcall(function()
                sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
            end)
        else
            if _origQuality ~= nil then
                settings().Rendering.QualityLevel = _origQuality
                _origQuality = nil
            end
            if cam and _origFOV ~= nil then
                cam.FieldOfView = _origFOV
                _origFOV = nil
            end
        end
    end)
end

local function applyDarkMode(on)
    if on then
        Lighting.Brightness = 0
        Lighting.ClockTime = 0
        Lighting.OutdoorAmbient = Color3.fromRGB(0, 0, 0)
    else
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    end
end

local function removeAccessories()
    local c = getChar()
    if not c then return end
    for _, v in pairs(c:GetChildren()) do
        if v:IsA("Accessory") then
            v:Destroy()
        end
    end
end

local CONFIG_FILE = "EnvyHub_Config.json"
local autoSaveEnabled = true
local autoSaveInterval = 5

local function enumToString(enum)
    if typeof(enum) == "EnumItem" then
        return enum.Name
    end
    return tostring(enum)
end

saveConfig = function()
    local data = {
        normalSpeed = cfg.normalSpeed,
        carrySpeed = cfg.carrySpeed,
        laggerSpeed = cfg.laggerSpeed,
        laggerCarrySpeed = cfg.laggerCarrySpeed,
        grabRadius = cfg.grabRadius,
        stealDuration = cfg.stealDuration,
        tpDownHeight = cfg.tpDownHeight,
        autoSwing = cfg.autoSwing,
        uiScale = cfg.uiScale,
        laggerMode = cfg.laggerMode,
        autoBat = cfg.autoBat,
        autoGrab = cfg.autoGrab,
        autoLeft = cfg.autoLeft,
        autoRight = cfg.autoRight,
        infiniteJump = cfg.infiniteJump,
        antiRagdoll = cfg.antiRagdoll,
        unwalk = cfg.unwalk,
        medusaCounter = cfg.medusaCounter,
        batCounter = cfg.batCounter,
        autoTPDown = cfg.autoTPDown,
        autoTPDownThreshold = cfg.autoTPDownThreshold,
        antiLag = cfg.antiLag,
        stretchRez = cfg.stretchRez,
        removeAccess = cfg.removeAccess,
        darkMode = cfg.darkMode,
        lockUI = cfg.lockUI,
        currentMode = cfg.currentMode,
        chaseSpeed = CHASE_SPEED,
        hideKey = enumToString(cfg.hideKey),
        autoLeftKey = enumToString(cfg.autoLeftKey),
        autoRightKey = enumToString(cfg.autoRightKey),
        dropKey = enumToString(cfg.dropKey),
        tpDownKey = enumToString(cfg.tpDownKey),
        autoBatKey = enumToString(cfg.autoBatKey),
        laggerKey = enumToString(cfg.laggerKey),
        modeKey = enumToString(cfg.modeKey),
        mobilePanelXOffset = cfg.mobilePanelXOffset,
        mobilePanelScale = cfg.mobilePanelScale,
        mobilePanelYOffset = cfg.mobilePanelYOffset,
        mainPanelPosition = cfg.mainPanelPosition,
        miniPanelPosition = cfg.miniPanelPosition,
    }
    
    pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(data))
    end)
end

local function loadConfig()
    local success, raw = pcall(function()
        return readfile(CONFIG_FILE)
    end)
    
    if not success or not raw then return end
    
    local success2, data = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    
    if not success2 or not data then return end
    
    if data.normalSpeed then cfg.normalSpeed = data.normalSpeed end
    if data.carrySpeed then cfg.carrySpeed = data.carrySpeed end
    if data.laggerSpeed then cfg.laggerSpeed = data.laggerSpeed end
    if data.laggerCarrySpeed then cfg.laggerCarrySpeed = data.laggerCarrySpeed end
    if data.grabRadius then cfg.grabRadius = data.grabRadius end
    if data.stealDuration then cfg.stealDuration = data.stealDuration end
    if data.tpDownHeight then cfg.tpDownHeight = data.tpDownHeight end
    if data.autoSwing ~= nil then cfg.autoSwing = data.autoSwing end
    if data.uiScale then cfg.uiScale = data.uiScale end
    if data.laggerMode ~= nil then cfg.laggerMode = data.laggerMode end
    if data.autoBat ~= nil then cfg.autoBat = data.autoBat end
    if data.autoGrab ~= nil then cfg.autoGrab = data.autoGrab end
    if data.autoLeft ~= nil then cfg.autoLeft = data.autoLeft end
    if data.autoRight ~= nil then cfg.autoRight = data.autoRight end
    if data.infiniteJump ~= nil then cfg.infiniteJump = data.infiniteJump end
    if data.antiRagdoll ~= nil then 
        cfg.antiRagdoll = data.antiRagdoll
        if cfg.antiRagdoll then
            antiRagdollActive = true
            startAntiRagdoll()
        else
            antiRagdollActive = false
            stopAntiRagdoll()
        end
    end
    if data.unwalk ~= nil then 
        cfg.unwalk = data.unwalk
        if cfg.unwalk then enableUnwalk() end
    end
    if data.medusaCounter ~= nil then cfg.medusaCounter = data.medusaCounter end
    if data.batCounter ~= nil then cfg.batCounter = data.batCounter end
    if data.autoTPDown ~= nil then cfg.autoTPDown = data.autoTPDown end
    if data.autoTPDownThreshold ~= nil then cfg.autoTPDownThreshold = data.autoTPDownThreshold end
    if data.antiLag ~= nil then cfg.antiLag = data.antiLag end
    if data.stretchRez ~= nil then cfg.stretchRez = data.stretchRez end
    if cfg.stretchRez then applyStretchRez(true) end
    if data.removeAccess ~= nil then cfg.removeAccess = data.removeAccess end
    if data.darkMode ~= nil then cfg.darkMode = data.darkMode end
    if data.lockUI ~= nil then cfg.lockUI = data.lockUI end
    if data.currentMode then cfg.currentMode = data.currentMode end
    if data.chaseSpeed then CHASE_SPEED = data.chaseSpeed end
    if data.mobilePanelXOffset then cfg.mobilePanelXOffset = data.mobilePanelXOffset end
    if data.mobilePanelScale then cfg.mobilePanelScale = data.mobilePanelScale; if MobPanelScale then MobPanelScale.Scale = data.mobilePanelScale / 100 end end
    if data.mobilePanelYOffset then cfg.mobilePanelYOffset = data.mobilePanelYOffset end
    if data.mainPanelPosition then cfg.mainPanelPosition = data.mainPanelPosition end
    if data.miniPanelPosition then cfg.miniPanelPosition = data.miniPanelPosition end
    
    if data.hideKey then
        local key = Enum.KeyCode[data.hideKey]
        if key then cfg.hideKey = key end
    end
    if data.autoLeftKey then
        local key = Enum.KeyCode[data.autoLeftKey]
        if key then cfg.autoLeftKey = key end
    end
    if data.autoRightKey then
        local key = Enum.KeyCode[data.autoRightKey]
        if key then cfg.autoRightKey = key end
    end
    if data.dropKey then
        local key = Enum.KeyCode[data.dropKey]
        if key then cfg.dropKey = key end
    end
    if data.tpDownKey then
        local key = Enum.KeyCode[data.tpDownKey]
        if key then cfg.tpDownKey = key end
    end
    if data.autoBatKey then
        local key = Enum.KeyCode[data.autoBatKey]
        if key then cfg.autoBatKey = key end
    end
    if data.laggerKey then
        local key = Enum.KeyCode[data.laggerKey]
        if key then cfg.laggerKey = key end
    end
    if data.modeKey then
        local key = Enum.KeyCode[data.modeKey]
        if key then cfg.modeKey = key end
    end
end

loadConfig()
applyDarkMode(cfg.darkMode)
if cfg.antiLag then
    applyAntiLag()
end

local function startAutoSave()
    task.spawn(function()
        while autoSaveEnabled and task.wait(autoSaveInterval) do
            saveConfig()
        end
    end)
end

local function manualSave()
    saveConfig()
end

local function resetConfig()
    cfg.normalSpeed = 60
    cfg.carrySpeed = 30
    cfg.laggerSpeed = 15
    cfg.laggerCarrySpeed = 24.5
    cfg.grabRadius = 8
    cfg.stealDuration = 1.4
    cfg.tpDownHeight = 20
    cfg.autoSwing = true
    cfg.uiScale = 100
    cfg.laggerMode = false
    cfg.autoBat = false
    cfg.autoGrab = false
    cfg.infiniteJump = false
    cfg.antiRagdoll = false
    antiRagdollActive = false
    stopAntiRagdoll()
    cfg.unwalk = false
    disableUnwalk()
    cfg.medusaCounter = false
    cfg.batCounter = false
    cfg.autoTPDown = false
    cfg.autoTPDownThreshold = 20
    cfg.antiLag = false
    cfg.stretchRez = false
    cfg.removeAccess = false
    cfg.darkMode = false
    cfg.lockUI = false
    cfg.currentMode = "Normal"
    CHASE_SPEED = 58
    cfg.hideKey = Enum.KeyCode.LeftControl
    cfg.autoLeftKey = Enum.KeyCode.Z
    cfg.autoRightKey = Enum.KeyCode.C
    cfg.dropKey = Enum.KeyCode.X
    cfg.tpDownKey = Enum.KeyCode.F
    cfg.autoBatKey = Enum.KeyCode.E
    cfg.laggerKey = Enum.KeyCode.R
    cfg.modeKey = Enum.KeyCode.Q
    cfg.mobilePanelScale = 100
    if MobPanelScale then MobPanelScale.Scale = 1 end
    cfg.mobilePanelXOffset = -162
    cfg.mobilePanelYOffset = -370
    cfg.mainPanelPosition = nil
    cfg.miniPanelPosition = nil
    
    if UIScaleInst then UIScaleInst.Scale = 1 end
    applyDarkMode(false)
    
    if SG and SG:FindFirstChild("MobileButtonsPanel") then
        SG.MobileButtonsPanel.Position = UDim2.new(1, cfg.mobilePanelXOffset, 1, cfg.mobilePanelYOffset)
    end
    
    if Main then
        Main.Position = UDim2.new(0, 50, 0, 50)
    end
    
    if EnvyMini then
        EnvyMini.Position = UDim2.new(0, 50, 0, 50)
    end
    
    pcall(function() if stopAimbot then stopAimbot() end end)
    pcall(function() if stopAntiRagdoll then stopAntiRagdoll() end end)
    pcall(function() if disableUnwalk then disableUnwalk() end end)
    pcall(function() if setAutoTPDownEnabled then setAutoTPDownEnabled(false) end end)
    pcall(function() if applyStretchRez then applyStretchRez(false) end end)
    pcall(function() if applyAntiLag then applyAntiLag() end end)
    pcall(function() if applyDarkMode then applyDarkMode(false) end end)
    cfg.autoLeftPhase = 1
    cfg.autoRightPhase = 1
    
    local toggleVals = {
        ["Auto Swing"] = cfg.autoSwing,
        ["Auto Grab"] = cfg.autoGrab,
        ["Infinite Jump"] = cfg.infiniteJump,
        ["Anti Ragdoll"] = cfg.antiRagdoll,
        ["Unwalk"] = cfg.unwalk,
        ["Medusa Counter"] = cfg.medusaCounter,
        ["Bat Counter"] = cfg.batCounter,
        ["Auto TP Down"] = cfg.autoTPDown,
        ["Anti Lag"] = cfg.antiLag,
        ["Stretch Rez"] = cfg.stretchRez,
        ["Remove Accessories"] = cfg.removeAccess,
        ["Dark Mode"] = cfg.darkMode,
        ["Lock UI"] = cfg.lockUI,
    }
    for name, val in pairs(toggleVals) do
        if _toggleSetters[name] then pcall(_toggleSetters[name], val) end
    end
    
    local inputVals = {
        ["Normal Speed"] = cfg.normalSpeed,
        ["Carry Speed"] = cfg.carrySpeed,
        ["Lagger Speed"] = cfg.laggerSpeed,
        ["Lagger Carry Speed"] = cfg.laggerCarrySpeed,
        ["Chase Speed"] = CHASE_SPEED,
        ["Grab Radius"] = cfg.grabRadius,
        ["Steal Duration"] = cfg.stealDuration,
        ["TP Down Y Threshold"] = cfg.autoTPDownThreshold,
        ["UI Scale"] = cfg.uiScale,
        ["Panel Size"] = cfg.mobilePanelScale,
    }
    for name, val in pairs(inputVals) do
        if _inputBoxes[name] then pcall(function() _inputBoxes[name].Text = tostring(val) end) end
    end
    
    local function ks(k) return tostring(k):gsub("Enum%.KeyCode%.", "") end
    local kbVals = {
        ["Lagger Mode"] = ks(cfg.laggerKey),
        ["Toggle Aimbot"] = ks(cfg.autoBatKey),
        ["Auto Left"] = ks(cfg.autoLeftKey),
        ["Auto Right"] = ks(cfg.autoRightKey),
        ["Drop"] = ks(cfg.dropKey),
        ["TP Down"] = ks(cfg.tpDownKey),
        ["Hide / Show GUI"] = ks(cfg.hideKey),
    }
    for name, val in pairs(kbVals) do
        if _keybindBtns[name] then pcall(function() _keybindBtns[name].Text = val end) end
    end
    
    setStealProgress(0)
    AutoStealBar.Visible = false
    
    saveConfig()
end

pcall(function()
    if CoreGui:FindFirstChild("EnvyHubGUI") then
        CoreGui.EnvyHubGUI:Destroy()
    end
end)

SG = Instance.new("ScreenGui")
SG.Name = "EnvyHubGUI"
SG.ResetOnSpawn = false
SG.DisplayOrder = 10
SG.IgnoreGuiInset = true
SG.Parent = CoreGui

local AutoStealBar = Instance.new("Frame")
AutoStealBar.Name = "AutoStealBar"
AutoStealBar.Size = UDim2.new(0, 260, 0, 14)
AutoStealBar.Position = UDim2.new(0.5, -130, 0, 35)
AutoStealBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
AutoStealBar.BackgroundTransparency = 0.15
AutoStealBar.BorderSizePixel = 0
AutoStealBar.Visible = false
AutoStealBar.ZIndex = 200
AutoStealBar.Parent = SG

local AutoStealBarCorner = Instance.new("UICorner")
AutoStealBarCorner.CornerRadius = UDim.new(0, 10)
AutoStealBarCorner.Parent = AutoStealBar

local AutoStealBarStroke = Instance.new("UIStroke")
AutoStealBarStroke.Color = Color3.fromRGB(0, 0, 0)
AutoStealBarStroke.Thickness = 1
AutoStealBarStroke.Parent = AutoStealBar

local AutoStealFill = Instance.new("Frame")
AutoStealFill.Name = "Fill"
AutoStealFill.Size = UDim2.new(0, 0, 1, 0)
AutoStealFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
AutoStealFill.BorderSizePixel = 0
AutoStealFill.ZIndex = 201
AutoStealFill.Parent = AutoStealBar

local AutoStealFillCorner = Instance.new("UICorner")
AutoStealFillCorner.CornerRadius = UDim.new(0, 10)
AutoStealFillCorner.Parent = AutoStealFill

local AutoStealPercent = Instance.new("TextLabel")
AutoStealPercent.Name = "Percent"
AutoStealPercent.Size = UDim2.new(1, 0, 1, 0)
AutoStealPercent.BackgroundTransparency = 1
AutoStealPercent.Font = Enum.Font.GothamBold
AutoStealPercent.TextSize = 11
AutoStealPercent.TextColor3 = Color3.fromRGB(0, 0, 0)
AutoStealPercent.Text = "0%"
AutoStealPercent.ZIndex = 202
AutoStealPercent.Parent = AutoStealBar

local function setStealProgress(progress)
    local clamped = math.clamp(progress or 0, 0, 1)
    AutoStealBar.Visible = clamped > 0 and cfg.autoGrab
    AutoStealFill.Size = UDim2.new(clamped, 0, 1, 0)
    AutoStealPercent.Text = math.floor(clamped * 100) .. "%"
end

Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 490, 0, 460)
if cfg.mainPanelPosition then
    Main.Position = UDim2.new(cfg.mainPanelPosition.X.Scale, cfg.mainPanelPosition.X.Offset, cfg.mainPanelPosition.Y.Scale, cfg.mainPanelPosition.Y.Offset)
else
    Main.Position = UDim2.new(0, 50, 0, 50)
end
Main.BackgroundColor3 = Color3.new(0, 0, 0)
Main.BorderSizePixel = 0
Main.Active = true
Main.ClipsDescendants = true
Main.Parent = SG

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.new(0, 0, 0)
MainStroke.Thickness = 1
MainStroke.Parent = Main

UIScaleInst = Instance.new("UIScale")
UIScaleInst.Scale = cfg.uiScale / 100
UIScaleInst.Parent = Main

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 44)
TopBar.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
TopBar.BorderSizePixel = 0
TopBar.ZIndex = 10
TopBar.Parent = Main

local TopBarBottom = Instance.new("Frame")
TopBarBottom.Size = UDim2.new(1, 0, 0, 12)
TopBarBottom.Position = UDim2.new(0, 0, 1, -12)
TopBarBottom.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
TopBarBottom.BorderSizePixel = 0
TopBarBottom.ZIndex = 9
TopBarBottom.Parent = TopBar

local TopBarLine = Instance.new("Frame")
TopBarLine.Size = UDim2.new(1, 0, 0, 1)
TopBarLine.Position = UDim2.new(0, 0, 1, -1)
TopBarLine.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
TopBarLine.BorderSizePixel = 0
TopBarLine.ZIndex = 11
TopBarLine.Parent = TopBar

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size = UDim2.new(0, 160, 1, 0)
TitleLbl.Position = UDim2.new(0, 14, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text = "ENVY HUB"
TitleLbl.TextColor3 = Color3.new(1, 1, 1)
TitleLbl.Font = Enum.Font.GothamBlack
TitleLbl.TextSize = 13
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.ZIndex = 12
TitleLbl.Parent = TopBar

local DiscordLbl = Instance.new("TextLabel")
DiscordLbl.Size = UDim2.new(0, 130, 1, 0)
DiscordLbl.Position = UDim2.new(0, 100, 0, 0)
DiscordLbl.BackgroundTransparency = 1
DiscordLbl.Text = "discord.gg/envyhub"
DiscordLbl.TextColor3 = Color3.fromRGB(160, 160, 160)
DiscordLbl.Font = Enum.Font.Gotham
DiscordLbl.TextSize = 9
DiscordLbl.ZIndex = 12
DiscordLbl.Parent = TopBar

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 26, 0, 26)
MinBtn.Position = UDim2.new(1, -36, 0.5, -13)
MinBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
MinBtn.BorderSizePixel = 0
MinBtn.Text = "\u{2013}"
MinBtn.TextColor3 = Color3.new(1, 1, 1)
MinBtn.Font = Enum.Font.GothamBlack
MinBtn.TextSize = 16
MinBtn.ZIndex = 13
MinBtn.Parent = TopBar

local MinBtnCorner = Instance.new("UICorner")
MinBtnCorner.CornerRadius = UDim.new(0, 6)
MinBtnCorner.Parent = MinBtn

local MinBtnStroke = Instance.new("UIStroke")
MinBtnStroke.Color = Color3.fromRGB(40, 40, 40)
MinBtnStroke.Parent = MinBtn

local draggingMain, dragInputMain, dragStartMain, dragStartPosMain

TopBar.InputBegan:Connect(function(inp)
    if cfg.lockUI then return end
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        draggingMain = true
        dragStartMain = inp.Position
        dragStartPosMain = Main.Position
        inp.Changed:Connect(function()
            if inp.UserInputState == Enum.UserInputState.End then
                draggingMain = false
                cfg.mainPanelPosition = {
                    X = {Scale = Main.Position.X.Scale, Offset = Main.Position.X.Offset},
                    Y = {Scale = Main.Position.Y.Scale, Offset = Main.Position.Y.Offset}
                }
                saveConfig()
            end
        end)
    end
end)

TopBar.InputChanged:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
        dragInputMain = inp
    end
end)

UserInputService.InputChanged:Connect(function(inp)
    if inp == dragInputMain and draggingMain and not cfg.lockUI then
        local d = inp.Position - dragStartMain
        Main.Position = UDim2.new(
            dragStartPosMain.X.Scale,
            dragStartPosMain.X.Offset + d.X,
            dragStartPosMain.Y.Scale,
            dragStartPosMain.Y.Offset + d.Y
        )
    end
end)

MinBtn.MouseEnter:Connect(function()
    MinBtn.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
end)

MinBtn.MouseLeave:Connect(function()
    MinBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
end)

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 160, 1, -44)
Sidebar.Position = UDim2.new(0, 0, 0, 44)
Sidebar.BackgroundColor3 = Color3.fromRGB(6, 6, 6)
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 3
Sidebar.Parent = Main

local SideImgFrame = Instance.new("Frame")
SideImgFrame.Size = UDim2.new(1, 0, 1, 0)
SideImgFrame.BackgroundTransparency = 1
SideImgFrame.ZIndex = 3
SideImgFrame.Parent = Sidebar

local SideImg = Instance.new("ImageLabel")
SideImg.Size = UDim2.new(1, 0, 0.5, 0)
SideImg.BackgroundTransparency = 1
SideImg.Image = "rbxassetid://105044056375613"
SideImg.ScaleType = Enum.ScaleType.Crop
SideImg.ZIndex = 3
SideImg.Parent = SideImgFrame

local SideGradient = Instance.new("Frame")
SideGradient.Size = UDim2.new(1, 0, 0.3, 0)
SideGradient.Position = UDim2.new(0, 0, 0.7, 0)
SideGradient.BackgroundTransparency = 1
SideGradient.ZIndex = 4
SideGradient.Parent = SideImgFrame

local SideGradientUG = Instance.new("UIGradient")
SideGradientUG.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(1, 0)
})
SideGradientUG.Rotation = 90
SideGradientUG.Parent = SideGradient

local PlayerNameLbl = Instance.new("TextLabel")
PlayerNameLbl.Size = UDim2.new(1, -8, 0, 22)
PlayerNameLbl.Position = UDim2.new(0, 8, 1, -52)
PlayerNameLbl.BackgroundTransparency = 1
PlayerNameLbl.Text = LocalPlayer.Name
PlayerNameLbl.TextColor3 = Color3.new(1, 1, 1)
PlayerNameLbl.Font = Enum.Font.GothamBold
PlayerNameLbl.TextSize = 12
PlayerNameLbl.TextXAlignment = Enum.TextXAlignment.Left
PlayerNameLbl.ZIndex = 6
PlayerNameLbl.Parent = Sidebar

local NameLine = Instance.new("Frame")
NameLine.Size = UDim2.new(0.7, 0, 0, 1)
NameLine.Position = UDim2.new(0, 8, 1, -30)
NameLine.BackgroundColor3 = Color3.new(1, 1, 1)
NameLine.BorderSizePixel = 0
NameLine.ZIndex = 6
NameLine.Parent = Sidebar

local SubLbl = Instance.new("TextLabel")
SubLbl.Size = UDim2.new(1, -8, 0, 14)
SubLbl.Position = UDim2.new(0, 8, 1, -26)
SubLbl.BackgroundTransparency = 1
SubLbl.Text = "Envy Hub"
SubLbl.TextColor3 = Color3.fromRGB(160, 160, 160)
SubLbl.Font = Enum.Font.Gotham
SubLbl.TextSize = 9
SubLbl.TextXAlignment = Enum.TextXAlignment.Left
SubLbl.ZIndex = 6
SubLbl.Parent = Sidebar

local SBDiv = Instance.new("Frame")
SBDiv.Size = UDim2.new(0, 1, 1, -44)
SBDiv.Position = UDim2.new(0, 160, 0, 44)
SBDiv.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
SBDiv.BorderSizePixel = 0
SBDiv.ZIndex = 5
SBDiv.Parent = Main

local TabStrip = Instance.new("Frame")
TabStrip.Size = UDim2.new(0, 90, 1, -44)
TabStrip.Position = UDim2.new(0, 161, 0, 44)
TabStrip.BackgroundColor3 = Color3.fromRGB(6, 6, 6)
TabStrip.BorderSizePixel = 0
TabStrip.ClipsDescendants = true
TabStrip.ZIndex = 3
TabStrip.Parent = Main

local TSInner = Instance.new("Frame")
TSInner.Size = UDim2.new(1, 0, 1, 0)
TSInner.BackgroundTransparency = 1
TSInner.Parent = TabStrip

local TSList = Instance.new("UIListLayout")
TSList.SortOrder = Enum.SortOrder.LayoutOrder
TSList.Padding = UDim.new(0, 2)
TSList.Parent = TSInner

local TSPadding = Instance.new("UIPadding")
TSPadding.PaddingTop = UDim.new(0, 10)
TSPadding.PaddingLeft = UDim.new(0, 6)
TSPadding.PaddingRight = UDim.new(0, 6)
TSPadding.Parent = TSInner

local TSDiv = Instance.new("Frame")
TSDiv.Size = UDim2.new(0, 1, 1, 0)
TSDiv.Position = UDim2.new(1, -1, 0, 0)
TSDiv.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
TSDiv.BorderSizePixel = 0
TSDiv.ZIndex = 5
TSDiv.Parent = TabStrip

local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.Size = UDim2.new(1, -252, 1, -56)
ContentArea.Position = UDim2.new(0, 252, 0, 44)
ContentArea.BackgroundColor3 = Color3.new(0, 0, 0)
ContentArea.BackgroundTransparency = 0
ContentArea.BorderSizePixel = 0
ContentArea.ZIndex = 2
ContentArea.Parent = Main

EnvyMini = Instance.new("TextButton")
EnvyMini.Name = "EnvyMini"
EnvyMini.Size = UDim2.new(0, 160, 0, 30)
if cfg.miniPanelPosition then
    EnvyMini.Position = UDim2.new(cfg.miniPanelPosition.X.Scale, cfg.miniPanelPosition.X.Offset, cfg.miniPanelPosition.Y.Scale, cfg.miniPanelPosition.Y.Offset)
else
    EnvyMini.Position = UDim2.new(0, 50, 0, 50)
end
EnvyMini.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
EnvyMini.BorderSizePixel = 0
EnvyMini.Text = "ENVY HUB"
EnvyMini.TextColor3 = Color3.new(1, 1, 1)
EnvyMini.Font = Enum.Font.GothamBold
EnvyMini.TextSize = 11
EnvyMini.ZIndex = 20
EnvyMini.Visible = false
EnvyMini.Parent = SG

local EnvyMiniCorner = Instance.new("UICorner")
EnvyMiniCorner.CornerRadius = UDim.new(0, 8)
EnvyMiniCorner.Parent = EnvyMini

local draggingMini, dragStartMini, dragStartPosMini, dragInputMini

EnvyMini.InputBegan:Connect(function(inp)
    if cfg.lockUI then return end
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        draggingMini = true
        dragStartMini = inp.Position
        dragStartPosMini = EnvyMini.Position
        inp.Changed:Connect(function()
            if inp.UserInputState == Enum.UserInputState.End then
                draggingMini = false
                cfg.miniPanelPosition = {
                    X = {Scale = EnvyMini.Position.X.Scale, Offset = EnvyMini.Position.X.Offset},
                    Y = {Scale = EnvyMini.Position.Y.Scale, Offset = EnvyMini.Position.Y.Offset}
                }
                saveConfig()
            end
        end)
    end
end)

EnvyMini.InputChanged:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
        dragInputMini = inp
    end
end)

UserInputService.InputChanged:Connect(function(inp)
    if inp == dragInputMini and draggingMini and not cfg.lockUI then
        local d = inp.Position - dragStartMini
        EnvyMini.Position = UDim2.new(
            dragStartPosMini.X.Scale,
            dragStartPosMini.X.Offset + d.X,
            dragStartPosMini.Y.Scale,
            dragStartPosMini.Y.Offset + d.Y
        )
    end
end)

MinBtn.MouseButton1Click:Connect(function()
    Main.Visible = false
    EnvyMini.Visible = true
end)

EnvyMini.MouseButton1Click:Connect(function()
    Main.Visible = true
    EnvyMini.Visible = false
end)

EnvyMini.MouseEnter:Connect(function()
    EnvyMini.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
end)

EnvyMini.MouseLeave:Connect(function()
    EnvyMini.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
end)

local function hoverRow(f)
    f.MouseEnter:Connect(function()
        f.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    end)
    f.MouseLeave:Connect(function()
        f.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
    end)
end

local function makeHeader(parent, text, order)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 18)
    f.BackgroundTransparency = 1
    f.LayoutOrder = order
    f.Parent = parent
    
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 1, 0)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.fromRGB(128, 128, 128)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 8
    l.TextXAlignment = Enum.TextXAlignment.Center
    l.Parent = f
end

local function makeToggle(parent, text, order, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 38)
    f.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
    f.BorderSizePixel = 0
    f.LayoutOrder = order
    f.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = f
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 10
    lbl.Parent = f
    
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0, 36, 0, 19)
    bg.Position = UDim2.new(1, -46, 0.5, -9)
    bg.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
    bg.BorderSizePixel = 0
    bg.ZIndex = 8
    bg.Parent = f
    
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(1, 0)
    bgCorner.Parent = bg
    
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 13, 0, 13)
    dot.Position = UDim2.new(0, 2, 0.5, -6)
    dot.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    dot.BorderSizePixel = 0
    dot.ZIndex = 9
    dot.Parent = bg
    
    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(0, 4)
    dotCorner.Parent = dot
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 11
    btn.Parent = bg
    
    local on = false
    local toggleStateMap = {
        ["Auto Swing"] = cfg.autoSwing,
        ["Auto Grab"] = cfg.autoGrab,
        ["Infinite Jump"] = cfg.infiniteJump,
        ["Anti Ragdoll"] = cfg.antiRagdoll,
        ["Unwalk"] = cfg.unwalk,
        ["Medusa Counter"] = cfg.medusaCounter,
        ["Bat Counter"] = cfg.batCounter,
        ["Auto TP Down"] = cfg.autoTPDown,
        ["Anti Lag"] = cfg.antiLag,
        ["Stretch Rez"] = cfg.stretchRez,
        ["Remove Accessories"] = cfg.removeAccess,
        ["Dark Mode"] = cfg.darkMode,
        ["Lock UI"] = cfg.lockUI,
    }
    if toggleStateMap[text] ~= nil then
        on = toggleStateMap[text]
    end
    
    local function upd()
        if on then
            bg.BackgroundColor3 = Color3.fromRGB(51, 153, 255)
            dot.Position = UDim2.new(1, -15, 0.5, -6)
            dot.BackgroundColor3 = Color3.new(1, 1, 1)
        else
            bg.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
            dot.Position = UDim2.new(0, 2, 0.5, -6)
            dot.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        end
    end
    
    btn.Activated:Connect(function()
        on = not on
        upd()
        if cb then
            cb(on)
            saveConfig()
        end
    end)

    upd()
    
    hoverRow(f)
    
    local setter = function(v)
        on = v
        upd()
    end
    _toggleSetters[text] = setter
    return f, setter
end

local function makeInput(parent, text, def, order, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 38)
    f.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
    f.BorderSizePixel = 0
    f.LayoutOrder = order
    f.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = f
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -84, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 10
    lbl.Parent = f
    
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0, 64, 0, 24)
    box.Position = UDim2.new(1, -74, 0.5, -12)
    box.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    box.BorderSizePixel = 0
    box.Text = tostring(def)
    box.TextColor3 = Color3.new(1, 1, 1)
    box.Font = Enum.Font.GothamBold
    box.TextSize = 11
    box.ClearTextOnFocus = false
    box.ZIndex = 11
    box.Parent = f
    
    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 5)
    boxCorner.Parent = box
    
    local boxStroke = Instance.new("UIStroke")
    boxStroke.Color = Color3.fromRGB(70, 70, 70)
    boxStroke.ZIndex = 12
    boxStroke.Parent = box
    
    box.FocusLost:Connect(function()
        local v = tonumber(box.Text)
        if v and cb then
            cb(v)
            saveConfig()
        end
    end)
    
    _inputBoxes[text] = box
    hoverRow(f)
    
    return f, box
end

local function makeKeybind(parent, text, key, order, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 38)
    f.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
    f.BorderSizePixel = 0
    f.LayoutOrder = order
    f.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = f
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 120, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 10
    lbl.Parent = f
    
    local kb = Instance.new("TextButton")
    kb.Size = UDim2.new(0, 44, 0, 20)
    kb.Position = UDim2.new(1, -54, 0.5, -10)
    kb.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    kb.BorderSizePixel = 0
    kb.Text = key
    kb.TextColor3 = Color3.new(1, 1, 1)
    kb.Font = Enum.Font.GothamBold
    kb.TextSize = 8
    kb.ZIndex = 11
    kb.Parent = f
    
    local kbCorner = Instance.new("UICorner")
    kbCorner.CornerRadius = UDim.new(0, 4)
    kbCorner.Parent = kb
    
    local rowBtn = Instance.new("TextButton")
    rowBtn.Size = UDim2.new(0.65, 0, 1, 0)
    rowBtn.BackgroundTransparency = 1
    rowBtn.Text = ""
    rowBtn.ZIndex = 6
    rowBtn.Active = true
    rowBtn.Parent = f
    
    rowBtn.Activated:Connect(function()
        if cb then
            cb()
            saveConfig()
        end
    end)
    
    _keybindBtns[text] = kb
    hoverRow(f)
    
    return f, kb
end

local tabNames = {"Speed", "Aimbot", "Mechanics", "Movement", "Performance", "Settings"}
local tabBtns = {}
local tabSFs = {}
local activeTab = nil

local function setTab(name)
    activeTab = name
    for n, b in pairs(tabBtns) do
        if n == name then
            b.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
        else
            b.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
        end
    end
    for n, s in pairs(tabSFs) do
        s.Visible = (n == name)
    end
end

for i, name in ipairs(tabNames) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.ZIndex = 7
    btn.LayoutOrder = i
    btn.Parent = TSInner
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 7)
    btnCorner.Parent = btn
    
    local bl = Instance.new("TextLabel")
    bl.Size = UDim2.new(1, 0, 1, 0)
    bl.BackgroundTransparency = 1
    bl.Text = name
    bl.TextColor3 = Color3.new(1, 1, 1)
    bl.Font = Enum.Font.GothamBold
    bl.TextSize = 9
    bl.TextXAlignment = Enum.TextXAlignment.Center
    bl.TextWrapped = true
    bl.ZIndex = 9
    bl.Parent = btn
    
    tabBtns[name] = btn

    local sf = Instance.new("ScrollingFrame")
    sf.Size = UDim2.new(1, 0, 1, 0)
    sf.BackgroundColor3 = Color3.new(0, 0, 0)
    sf.BackgroundTransparency = 0
    sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 2
    sf.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 70)
    sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
    sf.Visible = false
    sf.ZIndex = 3
    sf.Parent = ContentArea
    
    local sfList = Instance.new("UIListLayout")
    sfList.SortOrder = Enum.SortOrder.LayoutOrder
    sfList.Padding = UDim.new(0, 4)
    sfList.Parent = sf
    
    local sfPadding = Instance.new("UIPadding")
    sfPadding.PaddingLeft = UDim.new(0, 8)
    sfPadding.PaddingRight = UDim.new(0, 8)
    sfPadding.PaddingTop = UDim.new(0, 8)
    sfPadding.PaddingBottom = UDim.new(0, 10)
    sfPadding.Parent = sf
    
    tabSFs[name] = sf

    btn.Activated:Connect(function()
        setTab(name)
    end)
    
    btn.MouseEnter:Connect(function()
        if activeTab ~= name then
            btn.BackgroundColor3 = Color3.fromRGB(23, 23, 23)
        end
    end)
    
    btn.MouseLeave:Connect(function()
        if activeTab ~= name then
            btn.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
        end
    end)
end

local spSF = tabSFs["Speed"]
makeHeader(spSF, "SPEED CONFIGURATION", 1)
makeInput(spSF, "Normal Speed", cfg.normalSpeed, 2, function(v) cfg.normalSpeed = v end)
makeInput(spSF, "Carry Speed", cfg.carrySpeed, 3, function(v) cfg.carrySpeed = v end)
makeInput(spSF, "Lagger Speed", cfg.laggerSpeed, 4, function(v) cfg.laggerSpeed = v end)
makeInput(spSF, "Lagger Carry Speed", cfg.laggerCarrySpeed, 5, function(v) cfg.laggerCarrySpeed = v end)

do
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 38)
    f.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
    f.BorderSizePixel = 0
    f.LayoutOrder = 6
    f.Parent = spSF
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = f
    
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0, 80, 1, 0)
    l.Position = UDim2.new(0, 10, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = "Mode"
    l.TextColor3 = Color3.new(1, 1, 1)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.ZIndex = 10
    l.Parent = f
    
    local ml = Instance.new("TextLabel")
    ml.Size = UDim2.new(0, 80, 1, 0)
    ml.Position = UDim2.new(0, 88, 0, 0)
    ml.BackgroundTransparency = 1
    ml.Text = cfg.currentMode
    ml.TextColor3 = Color3.fromRGB(160, 160, 160)
    ml.Font = Enum.Font.Gotham
    ml.TextSize = 10
    ml.ZIndex = 10
    ml.Parent = f
    
    local rb = Instance.new("TextButton")
    rb.Size = UDim2.new(0.65, 0, 1, 0)
    rb.BackgroundTransparency = 1
    rb.Text = ""
    rb.ZIndex = 6
    rb.Parent = f
    
    local modes = {"Normal", "Carry"}
    local mi = 1
    
    rb.Activated:Connect(function()
        mi = mi % #modes + 1
        cfg.currentMode = modes[mi]
        ml.Text = modes[mi]
        saveConfig()
    end)
    
    hoverRow(f)
end

makeKeybind(spSF, "Lagger Mode", "R", 7, function()
    cfg.laggerMode = not cfg.laggerMode
end)

local aimbotSF = tabSFs["Aimbot"]
makeHeader(aimbotSF, "ADAPT PC AIMBOT", 1)
makeKeybind(aimbotSF, "Toggle Aimbot", "E", 2, function()
    if cfg.autoBat then
        stopAimbot()
        cfg.autoBat = false
    else
        startAimbot()
        cfg.autoBat = true
    end
    saveConfig()
end)
makeToggle(aimbotSF, "Auto Swing", 3, function(v)
    cfg.autoSwing = v
    saveConfig()
end)
makeInput(aimbotSF, "Chase Speed", CHASE_SPEED, 4, function(v)
    CHASE_SPEED = v
    saveConfig()
end)

local mechSF = tabSFs["Mechanics"]
makeHeader(mechSF, "GAME MECHANICS", 1)
makeToggle(mechSF, "Auto Grab", 2, function(v) cfg.autoGrab = v end)
makeInput(mechSF, "Grab Radius", cfg.grabRadius, 3, function(v) cfg.grabRadius = v end)
makeInput(mechSF, "Steal Duration", cfg.stealDuration, 4, function(v) cfg.stealDuration = v end)

makeHeader(mechSF, "INFINITE JUMP", 5)
makeToggle(mechSF, "Infinite Jump", 6, function(v) cfg.infiniteJump = v end)

makeToggle(mechSF, "Anti Ragdoll", 7, function(v)
    cfg.antiRagdoll = v
    antiRagdollActive = v
    if v then startAntiRagdoll() else stopAntiRagdoll() end
    saveConfig()
end)

makeToggle(mechSF, "Unwalk", 8, function(v)
    cfg.unwalk = v
    if v then enableUnwalk() else disableUnwalk() end
    saveConfig()
end)

makeToggle(mechSF, "Medusa Counter", 9, function(v) cfg.medusaCounter = v end)
makeToggle(mechSF, "Bat Counter", 10, function(v) cfg.batCounter = v end)

local movSF = tabSFs["Movement"]
makeHeader(movSF, "MOVEMENT & TELEPORT", 1)
makeKeybind(movSF, "Auto Left", "Z", 2, function()
    cfg.autoLeft = not cfg.autoLeft
    if cfg.autoLeft then cfg.autoRight = false; cfg.autoLeftPhase = 1 end
    if cfg.autoBat then stopAimbot(); cfg.autoBat = false end
end)
makeKeybind(movSF, "Auto Right", "C", 3, function()
    cfg.autoRight = not cfg.autoRight
    if cfg.autoRight then cfg.autoLeft = false; cfg.autoRightPhase = 1 end
    if cfg.autoBat then stopAimbot(); cfg.autoBat = false end
end)
makeKeybind(movSF, "Drop", "X", 4, function() runDropBrainrot() end)
makeKeybind(movSF, "TP Down", "F", 5, function() tpDown() end)

makeToggle(movSF, "Auto TP Down", 6, function(v) setAutoTPDownEnabled(v) end)
makeInput(movSF, "TP Down Y Threshold", cfg.autoTPDownThreshold, 7, function(v) 
    if v then setAutoTPDownThreshold(v) end
end)

local perfSF = tabSFs["Performance"]
makeHeader(perfSF, "PERFORMANCE", 1)
makeToggle(perfSF, "Anti Lag", 2, function(v)
    cfg.antiLag = v
    if v then applyAntiLag() end
end)
makeToggle(perfSF, "Stretch Rez", 3, function(v)
    cfg.stretchRez = v
    applyStretchRez(v)
end)
makeToggle(perfSF, "Remove Accessories", 4, function(v)
    cfg.removeAccess = v
    if v then removeAccessories() end
end)
makeToggle(perfSF, "Dark Mode", 5, function(v)
    cfg.darkMode = v
    applyDarkMode(v)
end)

local setsSF = tabSFs["Settings"]
makeHeader(setsSF, "INTERFACE & BINDS", 1)
makeInput(setsSF, "UI Scale", cfg.uiScale, 2, function(v)
    cfg.uiScale = v
    UIScaleInst.Scale = v / 100
end)
makeInput(setsSF, "Panel Size", cfg.mobilePanelScale or 100, 2, function(v)
    cfg.mobilePanelScale = v
    MobPanelScale.Scale = v / 100
end)
makeKeybind(setsSF, "Hide / Show GUI", "LeftControl", 3, nil)

local lockUIFrame, lockUISetter = makeToggle(setsSF, "Lock UI", 4, function(v)
    cfg.lockUI = v
    if v then
    else
    end
end)

lockUISetter(cfg.lockUI)

local saveBtn = Instance.new("TextButton")
saveBtn.Size = UDim2.new(1, 0, 0, 36)
saveBtn.BackgroundColor3 = Color3.new(1, 1, 1)
saveBtn.BorderSizePixel = 0
saveBtn.Text = "Save Config"
saveBtn.TextColor3 = Color3.new(0, 0, 0)
saveBtn.Font = Enum.Font.GothamBold
saveBtn.TextSize = 11
saveBtn.ZIndex = 5
saveBtn.LayoutOrder = 5
saveBtn.Parent = setsSF

local saveBtnCorner = Instance.new("UICorner")
saveBtnCorner.CornerRadius = UDim.new(0, 7)
saveBtnCorner.Parent = saveBtn

saveBtn.MouseButton1Click:Connect(function()
    manualSave()
    saveBtn.Text = "Saved!"
    task.delay(1.5, function()
        saveBtn.Text = "Save Config"
    end)
end)

saveBtn.MouseEnter:Connect(function()
    saveBtn.BackgroundColor3 = Color3.fromRGB(217, 217, 217)
end)

saveBtn.MouseLeave:Connect(function()
    saveBtn.BackgroundColor3 = Color3.new(1, 1, 1)
end)

local resetBtn = Instance.new("TextButton")
resetBtn.Size = UDim2.new(1, 0, 0, 36)
resetBtn.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
resetBtn.BorderSizePixel = 0
resetBtn.Text = "Reset All Settings"
resetBtn.TextColor3 = Color3.new(1, 1, 1)
resetBtn.Font = Enum.Font.GothamBold
resetBtn.TextSize = 11
resetBtn.ZIndex = 5
resetBtn.LayoutOrder = 6
resetBtn.Parent = setsSF

local resetBtnCorner = Instance.new("UICorner")
resetBtnCorner.CornerRadius = UDim.new(0, 7)
resetBtnCorner.Parent = resetBtn

resetBtn.MouseButton1Click:Connect(function()
    resetConfig()
    resetBtn.Text = "Reset!"
    task.delay(1.5, function()
        resetBtn.Text = "Reset All Settings"
    end)
end)

local resetPosBtn = Instance.new("TextButton")
resetPosBtn.Size = UDim2.new(1, 0, 0, 36)
resetPosBtn.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
resetPosBtn.BorderSizePixel = 0
resetPosBtn.Text = "Reset Panel Positions"
resetPosBtn.TextColor3 = Color3.new(1, 1, 1)
resetPosBtn.Font = Enum.Font.GothamBold
resetPosBtn.TextSize = 11
resetPosBtn.ZIndex = 5
resetPosBtn.LayoutOrder = 7
resetPosBtn.Parent = setsSF

local resetPosBtnCorner = Instance.new("UICorner")
resetPosBtnCorner.CornerRadius = UDim.new(0, 7)
resetPosBtnCorner.Parent = resetPosBtn

resetPosBtn.MouseButton1Click:Connect(function()
    if SG:FindFirstChild("MobileButtonsPanel") then
        cfg.mobilePanelScale = 100
    if MobPanelScale then MobPanelScale.Scale = 1 end
    cfg.mobilePanelXOffset = -162
        cfg.mobilePanelYOffset = -370
        SG.MobileButtonsPanel.Position = UDim2.new(1, cfg.mobilePanelXOffset, 1, cfg.mobilePanelYOffset)
    end
    
    Main.Position = UDim2.new(0, 50, 0, 50)
    cfg.mainPanelPosition = nil
    
    EnvyMini.Position = UDim2.new(0, 50, 0, 50)
    cfg.miniPanelPosition = nil
    
    saveConfig()
    resetPosBtn.Text = "Positions Reset!"
    task.delay(1.5, function()
        resetPosBtn.Text = "Reset Panel Positions"
    end)
end)

MobPanel = Instance.new("Frame")
MobPanel.Name = "MobileButtonsPanel"
MobPanel.Size = UDim2.new(0, 142, 0, 286)
MobPanel.Position = UDim2.new(1, cfg.mobilePanelXOffset, 1, cfg.mobilePanelYOffset)
MobPanel.BackgroundColor3 = Color3.new(0, 0, 0)
MobPanel.BackgroundTransparency = 1
MobPanel.BorderSizePixel = 0
MobPanel.ZIndex = 95
MobPanel.Parent = SG

MobPanelScale = Instance.new("UIScale")
MobPanelScale.Scale = (cfg.mobilePanelScale or 100) / 100
MobPanelScale.Parent = MobPanel

local MobPanelCorner = Instance.new("UICorner")
MobPanelCorner.CornerRadius = UDim.new(0, 10)
MobPanelCorner.Parent = MobPanel

local draggingMobPanel, dragStartMobPanel, dragStartPosMobPanel, dragInputMobPanel

MobPanel.InputBegan:Connect(function(inp)
    if cfg.lockUI then return end
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        draggingMobPanel = true
        dragStartMobPanel = inp.Position
        dragStartPosMobPanel = MobPanel.Position
        inp.Changed:Connect(function()
            if inp.UserInputState == Enum.UserInputState.End then
                draggingMobPanel = false
                cfg.mobilePanelXOffset = MobPanel.Position.X.Offset
                cfg.mobilePanelYOffset = MobPanel.Position.Y.Offset
                saveConfig()
            end
        end)
    end
end)

MobPanel.InputChanged:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
        dragInputMobPanel = inp
    end
end)

UserInputService.InputChanged:Connect(function(inp)
    if inp == dragInputMobPanel and draggingMobPanel and not cfg.lockUI then
        local d = inp.Position - dragStartMobPanel
        MobPanel.Position = UDim2.new(
            dragStartPosMobPanel.X.Scale,
            dragStartPosMobPanel.X.Offset + d.X,
            dragStartPosMobPanel.Y.Scale,
            dragStartPosMobPanel.Y.Offset + d.Y
        )
    end
end)

local buttonStates = {
    Btn_Drop = false,
    Btn_AutoLeft = false,
    Btn_Aimbot = false,
    Btn_AutoRight = false,
    Btn_TPDown = false,
    Btn_Speed = false,
    Btn_Lagger = false,
    Btn_LaggerCarry = false
}

local function updateMobileButtonStyle(button, isActive)
    if isActive then
        button.BackgroundColor3 = Color3.new(1, 1, 1)
        button.TextColor3 = Color3.new(0, 0, 0)
        if button:FindFirstChild("UIStroke") then
            button.UIStroke.Color = Color3.fromRGB(200, 200, 200)
        end
    else
        button.BackgroundColor3 = Color3.new(0, 0, 0)
        button.TextColor3 = Color3.new(1, 1, 1)
        if button:FindFirstChild("UIStroke") then
            button.UIStroke.Color = Color3.fromRGB(77, 77, 77)
        end
    end
end

local function makeMobBtn(name, pos, txt, cb, isToggle)
    local b = Instance.new("TextButton")
    b.Name = name
    b.Size = UDim2.new(0, 58, 0, 58)
    b.Position = pos
    b.BackgroundColor3 = Color3.new(0, 0, 0)
    b.BackgroundTransparency = 0
    b.Text = txt
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 9
    b.TextScaled = false
    b.TextWrapped = true
    b.LineHeight = 1.2
    b.AutoButtonColor = false
    b.ZIndex = 99
    b.Parent = MobPanel
    
    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 8)
    bCorner.Parent = b
    
    local bStroke = Instance.new("UIStroke")
    bStroke.Color = Color3.fromRGB(77, 77, 77)
    bStroke.Parent = b
    
    b.Activated:Connect(function()
        if isToggle then
            buttonStates[name] = not buttonStates[name]
            updateMobileButtonStyle(b, buttonStates[name])
        end
        if cb then cb(b, buttonStates[name]) end
        saveConfig()
    end)
    
    return b
end

local dropBtn = makeMobBtn("Btn_Drop", UDim2.new(0, 6, 0, 6), "DROP\nBR", function(btn, isActive)
    runDropBrainrot()
    task.wait(0.1)
    buttonStates.Btn_Drop = false
    updateMobileButtonStyle(btn, false)
end, true)

local autoLeftBtn = makeMobBtn("Btn_AutoLeft", UDim2.new(0, 78, 0, 6), "AUTO\nLEFT", function(btn, isActive)
    cfg.autoLeft = isActive
    if cfg.autoLeft then 
        cfg.autoRight = false
        cfg.autoLeftPhase = 1
        if autoRightBtn then
            buttonStates.Btn_AutoRight = false
            updateMobileButtonStyle(autoRightBtn, false)
        end
    end
    if cfg.autoBat then 
        stopAimbot() 
        cfg.autoBat = false
        if aimbotBtn then
            buttonStates.Btn_Aimbot = false
            updateMobileButtonStyle(aimbotBtn, false)
        end
    end
end, true)

local aimbotBtn = makeMobBtn("Btn_Aimbot", UDim2.new(0, 6, 0, 78), "AIMBOT\nTOGGLE", function(btn, isActive)
    if isActive then
        startAimbot()
        cfg.autoBat = true
    else
        stopAimbot()
        cfg.autoBat = false
    end
end, true)

local autoRightBtn = makeMobBtn("Btn_AutoRight", UDim2.new(0, 78, 0, 78), "AUTO\nRIGHT", function(btn, isActive)
    cfg.autoRight = isActive
    if cfg.autoRight then 
        cfg.autoLeft = false
        cfg.autoRightPhase = 1
        if autoLeftBtn then
            buttonStates.Btn_AutoLeft = false
            updateMobileButtonStyle(autoLeftBtn, false)
        end
    end
    if cfg.autoBat then 
        stopAimbot() 
        cfg.autoBat = false
        if aimbotBtn then
            buttonStates.Btn_Aimbot = false
            updateMobileButtonStyle(aimbotBtn, false)
        end
    end
end, true)

local tpDownBtn = makeMobBtn("Btn_TPDown", UDim2.new(0, 6, 0, 150), "TP\nDOWN", function(btn, isActive)
    tpDown()
    task.wait(0.1)
    buttonStates.Btn_TPDown = false
    updateMobileButtonStyle(btn, false)
end, true)

local speedBtn = makeMobBtn("Btn_Speed", UDim2.new(0, 78, 0, 150), "CARRY\nSPD", function(btn, isActive)
    if isActive then
        cfg.currentMode = "Carry"
    else
        cfg.currentMode = "Normal"
    end
end, true)

local laggerBtn = makeMobBtn("Btn_Lagger", UDim2.new(0, 78, 0, 222), "LAGGER\nMODE", function(btn, isActive)
    cfg.laggerMode = isActive
end, true)

local laggerCarryBtn = makeMobBtn("Btn_LaggerCarry", UDim2.new(0, 6, 0, 222), "LAGGER\nCARRY", function(btn, isActive)
    if isActive then
        cfg.currentMode = "LaggerCarry"
    else
        cfg.currentMode = "Normal"
    end
end, true)

local function initMobileButtonStates()
    buttonStates.Btn_AutoLeft = cfg.autoLeft
    buttonStates.Btn_AutoRight = cfg.autoRight
    buttonStates.Btn_Aimbot = cfg.autoBat
    buttonStates.Btn_Speed = (cfg.currentMode == "Carry")
    buttonStates.Btn_Lagger = cfg.laggerMode
    buttonStates.Btn_LaggerCarry = (cfg.currentMode == "LaggerCarry")
    
    if autoLeftBtn then updateMobileButtonStyle(autoLeftBtn, buttonStates.Btn_AutoLeft) end
    if autoRightBtn then updateMobileButtonStyle(autoRightBtn, buttonStates.Btn_AutoRight) end
    if aimbotBtn then updateMobileButtonStyle(aimbotBtn, buttonStates.Btn_Aimbot) end
    if speedBtn then updateMobileButtonStyle(speedBtn, buttonStates.Btn_Speed) end
    if laggerBtn then updateMobileButtonStyle(laggerBtn, buttonStates.Btn_Lagger) end
    if laggerCarryBtn then updateMobileButtonStyle(laggerCarryBtn, buttonStates.Btn_LaggerCarry) end
end

local BB = Instance.new("BillboardGui")
BB.Name = "EnvyMobileBB"
BB.Size = UDim2.new(0, 160, 0, 52)
BB.StudsOffset = Vector3.new(0, 3, 0)
BB.AlwaysOnTop = true

local SpeedLbl = Instance.new("TextLabel")
SpeedLbl.Name = "SpeedBillLbl"
SpeedLbl.Size = UDim2.new(1, 0, 0, 24)
SpeedLbl.Position = UDim2.new(0, 0, 0, 0)
SpeedLbl.BackgroundTransparency = 1
SpeedLbl.Text = "0.0"
SpeedLbl.TextColor3 = Color3.new(1, 1, 1)
SpeedLbl.Font = Enum.Font.GothamBold
SpeedLbl.TextScaled = true
SpeedLbl.TextStrokeTransparency = 0
SpeedLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
SpeedLbl.Parent = BB

local ModeLbl = Instance.new("TextLabel")
ModeLbl.Size = UDim2.new(1, 0, 0, 28)
ModeLbl.Position = UDim2.new(0, 0, 0, 26)
ModeLbl.BackgroundTransparency = 1
ModeLbl.Text = "Normal"
ModeLbl.TextColor3 = Color3.fromRGB(179, 179, 179)
ModeLbl.Font = Enum.Font.Gotham
ModeLbl.TextScaled = true
ModeLbl.TextStrokeTransparency = 0.1
ModeLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
ModeLbl.Parent = BB

local function onChar(char)
    local hrp = char:WaitForChild("HumanoidRootPart", 10)
    if not hrp then return end
    BB.Adornee = hrp
    BB.Parent = char
    
    if cfg.removeAccess then
        removeAccessories()
    end
    
    if cfg.unwalk then
        task.wait(0.5)
        local h = char:FindFirstChildOfClass("Humanoid")
        if h then 
            for _, t in ipairs(h:GetPlayingAnimationTracks()) do 
                t:Stop() 
            end 
        end
        local a = char:FindFirstChild("Animate")
        if a then 
            if not Unwalk.savedAnimate then
                Unwalk.savedAnimate = a:Clone() 
            end
            a:Destroy() 
        end
    end
end

if LocalPlayer.Character then
    task.spawn(onChar, LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(onChar)

UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    
    if inp.KeyCode == cfg.hideKey then
        Main.Visible = not Main.Visible
        EnvyMini.Visible = not Main.Visible
    elseif inp.KeyCode == cfg.autoLeftKey then
        cfg.autoLeft = not cfg.autoLeft
        if cfg.autoLeft then cfg.autoRight = false; cfg.autoLeftPhase = 1 end
        if cfg.autoBat then stopAimbot(); cfg.autoBat = false end
        buttonStates.Btn_AutoLeft = cfg.autoLeft
        if autoLeftBtn then updateMobileButtonStyle(autoLeftBtn, buttonStates.Btn_AutoLeft) end
        if cfg.autoLeft and autoRightBtn then
            buttonStates.Btn_AutoRight = false
            updateMobileButtonStyle(autoRightBtn, false)
        end
    elseif inp.KeyCode == cfg.autoRightKey then
        cfg.autoRight = not cfg.autoRight
        if cfg.autoRight then cfg.autoLeft = false; cfg.autoRightPhase = 1 end
        if cfg.autoBat then stopAimbot(); cfg.autoBat = false end
        buttonStates.Btn_AutoRight = cfg.autoRight
        if autoRightBtn then updateMobileButtonStyle(autoRightBtn, buttonStates.Btn_AutoRight) end
        if cfg.autoRight and autoLeftBtn then
            buttonStates.Btn_AutoLeft = false
            updateMobileButtonStyle(autoLeftBtn, false)
        end
    elseif inp.KeyCode == cfg.dropKey then
        runDropBrainrot()
    elseif inp.KeyCode == cfg.tpDownKey then
        tpDown()
    elseif inp.KeyCode == cfg.autoBatKey then
        if cfg.autoBat then
            stopAimbot()
            cfg.autoBat = false
        else
            startAimbot()
            cfg.autoBat = true
        end
        buttonStates.Btn_Aimbot = cfg.autoBat
        if aimbotBtn then updateMobileButtonStyle(aimbotBtn, buttonStates.Btn_Aimbot) end
    elseif inp.KeyCode == cfg.laggerKey then
        cfg.laggerMode = not cfg.laggerMode
        buttonStates.Btn_Lagger = cfg.laggerMode
        if laggerBtn then updateMobileButtonStyle(laggerBtn, buttonStates.Btn_Lagger) end
    elseif inp.KeyCode == cfg.modeKey then
        cfg.currentMode = cfg.currentMode == "Carry" and "Normal" or "Carry"
        buttonStates.Btn_Speed = (cfg.currentMode == "Carry")
        if speedBtn then updateMobileButtonStyle(speedBtn, buttonStates.Btn_Speed) end
        buttonStates.Btn_LaggerCarry = (cfg.currentMode == "LaggerCarry")
        if laggerCarryBtn then updateMobileButtonStyle(laggerCarryBtn, buttonStates.Btn_LaggerCarry) end
    end
    saveConfig()
end)

UserInputService.JumpRequest:Connect(function()
    if cfg.infiniteJump then
        local hrp = getHRP()
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.new(
                hrp.AssemblyLinearVelocity.X,
                55,
                hrp.AssemblyLinearVelocity.Z
            )
        end
    end
end)

RunService.Stepped:Connect(function()
    if cfg.autoBat then return end
    
    local char = getChar()
    if not char then return end
    
    local hrp = getHRP()
    local hum = getHum()
    if not hrp or not hum then return end
    
    local spd = getTargetSpeed()
    local mv = hum.MoveDirection
    
    if mv.Magnitude > 0 then
        hrp.Velocity = Vector3.new(mv.X * spd, hrp.Velocity.Y, mv.Z * spd)
    end
    
    if cfg.autoLeft then
        local autoSpd = cfg.normalSpeed
        if cfg.autoLeftPhase == 1 then
            local target = Vector3.new(WAYPOINTS.L1.X, hrp.Position.Y, WAYPOINTS.L1.Z)
            if (target - hrp.Position).Magnitude < 1 then
                cfg.autoLeftPhase = 2
            else
                local direction = (target - hrp.Position).Unit
                hrp.Velocity = Vector3.new(direction.X * autoSpd, hrp.Velocity.Y, direction.Z * autoSpd)
            end
        elseif cfg.autoLeftPhase == 2 then
            local target = Vector3.new(WAYPOINTS.L2.X, hrp.Position.Y, WAYPOINTS.L2.Z)
            if (target - hrp.Position).Magnitude < 1 then
                cfg.autoLeft = false
                cfg.autoLeftPhase = 1
                hrp.Velocity = Vector3.zero
                buttonStates.Btn_AutoLeft = false
                if autoLeftBtn then updateMobileButtonStyle(autoLeftBtn, false) end
            else
                local direction = (target - hrp.Position).Unit
                hrp.Velocity = Vector3.new(direction.X * autoSpd, hrp.Velocity.Y, direction.Z * autoSpd)
            end
        end
    end
    
    if cfg.autoRight then
        local autoSpd = cfg.normalSpeed
        if cfg.autoRightPhase == 1 then
            local target = Vector3.new(WAYPOINTS.R1.X, hrp.Position.Y, WAYPOINTS.R1.Z)
            if (target - hrp.Position).Magnitude < 1 then
                cfg.autoRightPhase = 2
            else
                local direction = (target - hrp.Position).Unit
                hrp.Velocity = Vector3.new(direction.X * autoSpd, hrp.Velocity.Y, direction.Z * autoSpd)
            end
        elseif cfg.autoRightPhase == 2 then
            local target = Vector3.new(WAYPOINTS.R2.X, hrp.Position.Y, WAYPOINTS.R2.Z)
            if (target - hrp.Position).Magnitude < 1 then
                cfg.autoRight = false
                cfg.autoRightPhase = 1
                hrp.Velocity = Vector3.zero
                buttonStates.Btn_AutoRight = false
                if autoRightBtn then updateMobileButtonStyle(autoRightBtn, false) end
            else
                local direction = (target - hrp.Position).Unit
                hrp.Velocity = Vector3.new(direction.X * autoSpd, hrp.Velocity.Y, direction.Z * autoSpd)
            end
        end
    end
    
    local realSpd = Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z).Magnitude
    SpeedLbl.Text = string.format("%.1f", realSpd)
    
    local modeText = cfg.currentMode
    if cfg.laggerMode then modeText = modeText .. " [L]" end
    ModeLbl.Text = modeText
end)

do
    local STEAL_RADIUS = 60
    local isStealing = false
    local StealData = {}
    local function isMyPlotByName(pn)
        local plots = workspace:FindFirstChild("Plots")
        if not plots then return false end
        local plot = plots:FindFirstChild(pn)
        if not plot then return false end
        local sign = plot:FindFirstChild("PlotSign")
        if sign then
            local yb = sign:FindFirstChild("YourBase")
            if yb and yb:IsA("BillboardGui") then return yb.Enabled == true end
        end
        return false
    end
    local function findNearestPrompt()
        local hrp = getHRP()
        if not hrp then return nil end
        local plots = workspace:FindFirstChild("Plots")
        if not plots then return nil end
        local nearest, dist = nil, math.huge
        for _, plot in ipairs(plots:GetChildren()) do
            if isMyPlotByName(plot.Name) then continue end
            local pods = plot:FindFirstChild("AnimalPodiums")
            if not pods then continue end
            for _, pod in ipairs(pods:GetChildren()) do
                local base = pod:FindFirstChild("Base")
                if not base then continue end
                local spawn = base:FindFirstChild("Spawn")
                if not spawn then continue end
                local d = (spawn.Position - hrp.Position).Magnitude
                if d <= STEAL_RADIUS and d < dist then
                    local att = spawn:FindFirstChild("PromptAttachment")
                    if att then
                        for _, p in ipairs(att:GetChildren()) do
                            if p:IsA("ProximityPrompt") and p.ActionText and p.ActionText:find("Steal") then
                                nearest, dist = p, d
                            end
                        end
                    end
                end
            end
        end
        return nearest
    end
    local function executeSteal(prompt)
        if isStealing then return end
        if not StealData[prompt] then
            StealData[prompt] = {hold = {}, trigger = {}, ready = true}
            if getconnections then
                for _, c in ipairs(getconnections(prompt.PromptButtonHoldBegan)) do
                    if c.Function then table.insert(StealData[prompt].hold, c.Function) end
                end
                for _, c in ipairs(getconnections(prompt.Triggered)) do
                    if c.Function then table.insert(StealData[prompt].trigger, c.Function) end
                end
            end
        end
        local data = StealData[prompt]
        if not data.ready then return end
        data.ready = false
        isStealing = true
        local startTime = tick()
        local stealDuration = math.max(0.1, tonumber(cfg.stealDuration) or 1.4)
        setStealProgress(0)
        task.spawn(function()
            for _, f in ipairs(data.hold) do pcall(f) end
            while tick() - startTime < stealDuration do
                setStealProgress((tick() - startTime) / stealDuration)
                task.wait()
            end
            setStealProgress(1)
            for _, f in ipairs(data.trigger) do pcall(f) end
            task.wait(0.05)
            data.ready = true
            isStealing = false
            setStealProgress(0)
        end)
    end
    RunService.Heartbeat:Connect(function()
        if not cfg.autoGrab then
            if AutoStealBar.Visible then
                setStealProgress(0)
            end
            return
        end
        if isStealing then return end
        local success, prompt = pcall(findNearestPrompt)
        if success and prompt then pcall(executeSteal, prompt) end
    end)
end

startAutoSave()
initMobileButtonStates()
setTab("Speed")

if cfg.autoTPDown then
    setAutoTPDownEnabled(true)
end

if cfg.autoBat then
    startAimbot()
end

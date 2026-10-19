--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║         SCYTHE | YBA SUITE  —  Obsidian UI Build 2.0        ║
    ╚══════════════════════════════════════════════════════════════╝

    Paste into your executor and execute in-game.
    All configuration lives inside the Config table below.
--]]

-- ─────────────────────────────────────────────────────────────────────────────
-- § 0 · CONFIGURATION
-- ─────────────────────────────────────────────────────────────────────────────
local Config = {
    TargetStand     = "Star Platinum",
    ItemType        = "Mysterious Arrow",         -- "Mysterious Arrow" | "Lucky Arrow" | "Rib Cage of the Saint's Corpse"
    ScavengeTimeout = 10,
    ToggleKey       = Enum.KeyCode.RightControl,
    LoopDelay       = 0.5,
    ActivateDelay   = 0.8,
    ShopDelay       = 0.6,

    StandPool = {
        -- Arrow & Lucky Arrow pool
        "Star Platinum", "The World", "Crazy Diamond", "Killer Queen",
        "King Crimson", "Gold Experience", "Silver Chariot", "Hermit Purple",
        "Hierophant Green", "Magician's Red", "Purple Haze", "Cream",
        "The Hand", "Sticky Fingers", "Whitesnake", "Aerosmith",
        "Beach Boy", "Six Pistols", "Mr. President", "White Album",
        "Anubis", "Red Hot Chili Pepper", "Stone Free", "Diver Down",
        -- Rib Cage pool
        "The World (Alternate Universe)", "Dirty Deeds Done Dirt Cheap",
        "Scary Monsters", "Tusk Act 1", "Soft & Wet",
    },

    FarmItems = {
        -- Stand Modifiers
        ["Mysterious Arrow"]                = true,
        ["Lucky Arrow"]                     = true,
        ["Rokakaka"]                        = true,
        ["Pure Rokakaka"]                   = true,
        ["Rib Cage of the Saint's Corpse"]  = true,
        ["Requiem Arrow"]                   = true,
        -- Spec Items
        ["Stone Mask"]                      = true,
        ["Ancient Scroll"]                  = true,
        ["Quinton's Glove"]                 = true,
        ["Steel Ball"]                      = true,
        ["Zeppeli's Headband"]              = true,
        ["Clackers"]                        = true,
        ["Boxing Gloves"]                   = false,
        ["Boxing Claws"]                    = false,
        ["Bone Gloves"]                     = false,
        -- Evolution & Boss
        ["DIO's Diary"]                     = true,
        ["Green Baby"]                      = true,
        ["DIO's Bone"]                      = false,
        ["Jotaro's Disc"]                   = false,
        ["Left Arm of the Saint's Corpse"]  = true,
        ["Heart of the Saint's Corpse"]     = true,
        ["Pelvis of the Saint's Corpse"]    = true,
        -- Valuables
        ["Gold Coin"]                       = false,
        ["Diamond"]                         = true,
    },

    PatrolPoints = {
        Vector3.new(0,   5,   0),
        Vector3.new(80,  5,   0),
        Vector3.new(0,   5,   80),
        Vector3.new(-80, 5,   0),
        Vector3.new(0,   5,  -80),
    },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- § 1 · OBSIDIAN LIBRARY LOAD
-- ─────────────────────────────────────────────────────────────────────────────
local repo         = 'https://raw.githubusercontent.com/deividcomsono/Obsidian/main/'
local Library      = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager  = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

-- ─────────────────────────────────────────────────────────────────────────────
-- § 2 · SERVICES & REFERENCES
-- ─────────────────────────────────────────────────────────────────────────────
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer  = Players.LocalPlayer
local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")

-- ─────────────────────────────────────────────────────────────────────────────
-- § 3 · RUNTIME STATE
-- ─────────────────────────────────────────────────────────────────────────────
local State = {
    Running      = false,
    CurrentPhase = "IDLE",
    ActiveStand  = "None",
    ItemCount    = 0,
    RokaCount    = 0,
    Worthiness   = "UNKNOWN",
}

Modules = Modules or {}

local FarmState = {
    Running   = false,
    Status    = "IDLE",
    LastItem  = "—",
    Thread    = nil,
    Tally     = {},
    Blacklist = {},
}

local loopThread = nil

-- ─────────────────────────────────────────────────────────────────────────────
-- § 4 · UTILITY HELPERS
-- ─────────────────────────────────────────────────────────────────────────────

local function findDescendant(root, name)
    for _, v in ipairs(root:GetDescendants()) do
        if v.Name == name then return v end
    end
    return nil
end

local function findDescendantContaining(root, substr)
    local low = substr:lower()
    for _, v in ipairs(root:GetDescendants()) do
        if v.Name:lower():find(low, 1, true) then return v end
    end
    return nil
end

local function countInBackpack(substring)
    local count = 0
    local bp    = LocalPlayer:FindFirstChild("Backpack")
    local low   = substring:lower()
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") and tool.Name:lower():find(low, 1, true) then
                count += 1
            end
        end
    end
    local char = LocalPlayer.Character
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") and tool.Name:lower():find(low, 1, true) then
                count += 1
            end
        end
    end
    return count
end

local function equipTool(substring)
    local bp  = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return nil end
    local low = substring:lower()
    for _, tool in ipairs(bp:GetChildren()) do
        if tool:IsA("Tool") and tool.Name:lower():find(low, 1, true) then
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum:EquipTool(tool) end
            end
            return tool
        end
    end
    return nil
end

local function waitAlive()
    while true do
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then return end
        end
        task.wait(1)
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- § 5 · ENGINE FUNCTIONS
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 5A · Worthiness unlock ────────────────────────────────────────────────────
local function unlockWorthiness()
    State.CurrentPhase = "UNLOCKING_WORTHINESS"

    local menuBtn = findDescendantContaining(PlayerGui, "Menu")
    pcall(function()
        if menuBtn and menuBtn:IsA("GuiButton") then menuBtn:FireMouseButton1Click() end
    end)
    task.wait(Config.ShopDelay)

    local charBtn = findDescendantContaining(PlayerGui, "Персонаж")
        or findDescendantContaining(PlayerGui, "Character")
    pcall(function()
        if charBtn and charBtn:IsA("GuiButton") then charBtn:FireMouseButton1Click() end
    end)
    task.wait(Config.ShopDelay)

    local skillBtn = findDescendantContaining(PlayerGui, "Skill Tree")
        or findDescendantContaining(PlayerGui, "Навыки")
    pcall(function()
        if skillBtn and skillBtn:IsA("GuiButton") then skillBtn:FireMouseButton1Click() end
    end)
    task.wait(0.8)

    local worthNode = findDescendantContaining(PlayerGui, "Worthiness")
        or findDescendantContaining(PlayerGui, "Достоинство")

    if worthNode then
        local actionBtn = nil
        local parent = worthNode.Parent
        if parent then
            for _, child in ipairs(parent:GetDescendants()) do
                if child:IsA("TextButton") then
                    local txt = child.Text:upper()
                    if txt == "LEARN" or txt == "LEARNED" or txt == "ВЫУЧИТЬ" or txt == "ВЫУЧЕНО" then
                        actionBtn = child
                        break
                    end
                end
            end
        end

        if actionBtn then
            local btnText = actionBtn.Text:upper()
            if btnText == "LEARNED" or btnText == "ВЫУЧЕНО" then
                State.Worthiness = "LEARNED"
            elseif btnText == "LEARN" or btnText == "ВЫУЧИТЬ" then
                local spLabel = findDescendantContaining(PlayerGui, "Skill-Point")
                    or findDescendantContaining(PlayerGui, "SP")
                local spCount = 0
                if spLabel and spLabel:IsA("TextLabel") then
                    spCount = tonumber(spLabel.Text:match("%d+")) or 0
                end
                if spCount >= 1 then
                    pcall(function() actionBtn:FireMouseButton1Click() end)
                    task.wait(0.3)
                    State.Worthiness = "LEARNED"
                end
            end
        end
    end

    local closeBtn = findDescendantContaining(PlayerGui, "Close")
        or findDescendantContaining(PlayerGui, "Закрыть")
    pcall(function()
        if closeBtn and closeBtn:IsA("GuiButton") then closeBtn:FireMouseButton1Click() end
    end)
    task.wait(Config.ShopDelay)
end

-- ── 5B · Map Scavenger ────────────────────────────────────────────────────────
local function scavengeMap(missingItem, missingRoka)
    State.CurrentPhase = "SCAVENGING"
    local char = LocalPlayer.Character
    if not char then return false end
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return false end

    local startTime  = tick()
    local searchNames = {}
    if missingItem then table.insert(searchNames, Config.ItemType) end
    if missingRoka  then table.insert(searchNames, "Rokakaka") end

    while tick() - startTime < Config.ScavengeTimeout do
        for _, name in ipairs(searchNames) do
            local low = name:lower()
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj.Name:lower():find(low, 1, true) then
                    local pos = nil
                    if obj:IsA("BasePart") then
                        pos = obj.Position
                    elseif obj:IsA("Model") and obj.PrimaryPart then
                        pos = obj.PrimaryPart.Position
                    end
                    if pos and (hrp.Position - pos).Magnitude < 200 then
                        hum:MoveTo(pos)
                        local ms = tick()
                        repeat task.wait(0.1)
                        until (hrp.Position - pos).Magnitude < 6 or tick() - ms > 5

                        local pp = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                        if pp then pcall(function() fireclickdetector(pp) end) end
                        task.wait(0.4)

                        local ni = countInBackpack(Config.ItemType)
                        local nr = countInBackpack("Rokakaka")
                        State.ItemCount = ni
                        State.RokaCount = nr
                        if ni > 0 and nr > 0 then return true end
                    end
                end
            end
        end
        task.wait(0.5)
    end
    return false
end

-- ── 5C · Shop Auto-Buyer ──────────────────────────────────────────────────────
local function buyFromShop(needItem, needRoka)
    State.CurrentPhase = "BUYING"

    local menuBtns = {}
    for _, v in ipairs(PlayerGui:GetDescendants()) do
        if v:IsA("TextButton") and (v.Text:lower():find("menu") or v.Name:lower():find("menu")) then
            table.insert(menuBtns, v)
        end
    end
    local menuBtn = nil
    local lowestY = -math.huge
    for _, b in ipairs(menuBtns) do
        if b.AbsolutePosition.Y > lowestY then
            lowestY = b.AbsolutePosition.Y
            menuBtn = b
        end
    end
    if menuBtn then
        pcall(function() menuBtn:FireMouseButton1Click() end)
        task.wait(Config.ShopDelay)
    end

    local shopBtn = nil
    for _, v in ipairs(PlayerGui:GetDescendants()) do
        if v:IsA("GuiButton") then
            local txt = v.Text or ""
            if txt:find("%$") or txt:lower():find("shop") then
                shopBtn = v ; break
            end
        end
    end
    if shopBtn then
        pcall(function() shopBtn:FireMouseButton1Click() end)
        task.wait(Config.ShopDelay * 1.5)
    end

    local function purchaseItem(keyword)
        local targets = { "5x " .. keyword, "1x " .. keyword, keyword }
        for _, target in ipairs(targets) do
            local low = target:lower()
            for _, v in ipairs(PlayerGui:GetDescendants()) do
                if v:IsA("TextLabel") and v.Text:lower():find(low, 1, true) then
                    local parent = v.Parent
                    while parent and parent ~= PlayerGui do
                        for _, child in ipairs(parent:GetDescendants()) do
                            if child:IsA("TextButton") then
                                local ct = child.Text:lower()
                                if ct:find("buy") or ct:find("купить") or ct:find("purchase") then
                                    pcall(function() child:FireMouseButton1Click() end)
                                    task.wait(Config.ShopDelay)
                                    local confirmBtn = findDescendantContaining(PlayerGui, "Confirm")
                                        or findDescendantContaining(PlayerGui, "Yes")
                                        or findDescendantContaining(PlayerGui, "Да")
                                    if confirmBtn and confirmBtn:IsA("GuiButton") then
                                        pcall(function() confirmBtn:FireMouseButton1Click() end)
                                        task.wait(Config.ShopDelay)
                                    end
                                    return true
                                end
                            end
                        end
                        parent = parent.Parent
                    end
                end
            end
        end
        return false
    end

    if needItem then
        if Config.ItemType:lower():find("rib cage", 1, true) then
            purchaseItem("Rib Cage of the Saint's Corpse")
        else
            purchaseItem(Config.ItemType)
        end
    end
    task.wait(Config.ShopDelay)
    if needRoka then purchaseItem("Rokakaka") end
    task.wait(Config.ShopDelay)

    local closeShop = findDescendantContaining(PlayerGui, "Close")
        or findDescendantContaining(PlayerGui, "Закрыть")
    pcall(function()
        if closeShop and closeShop:IsA("GuiButton") then closeShop:FireMouseButton1Click() end
    end)
    task.wait(Config.ShopDelay)

    State.ItemCount = countInBackpack(Config.ItemType)
    State.RokaCount = countInBackpack("Rokakaka")
end

-- ── 5D · Dialogue Confirmer ───────────────────────────────────────────────────
local function confirmDialogue()
    task.wait(0.4)
    local yesBtn = findDescendantContaining(PlayerGui, "Yes")
        or findDescendantContaining(PlayerGui, "Да")
        or findDescendantContaining(PlayerGui, "Confirm")
    if yesBtn and yesBtn:IsA("GuiButton") then
        pcall(function() yesBtn:FireMouseButton1Click() end)
        task.wait(0.3)
    end
end

-- ── 5E · Stand Detection ──────────────────────────────────────────────────────
local function detectCurrentStand()
    local char = LocalPlayer.Character
    if char then
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("Model") then
                for _, s in ipairs(Config.StandPool) do
                    if obj.Name:lower():find(s:lower(), 1, true) then return s end
                end
            end
        end
    end
    for _, v in ipairs(PlayerGui:GetDescendants()) do
        if v:IsA("TextLabel") then
            for _, s in ipairs(Config.StandPool) do
                if v.Text:lower():find(s:lower(), 1, true) then return s end
            end
        end
    end
    return "None"
end

-- ── 5F · Reroll Loop ─────────────────────────────────────────────────────────
local function runLoop()
    while State.Running do
        waitAlive()

        State.ItemCount = countInBackpack(Config.ItemType)
        State.RokaCount = countInBackpack("Rokakaka")

        local needItem = State.ItemCount == 0
        local needRoka = State.RokaCount  == 0

        if needItem or needRoka then
            scavengeMap(needItem, needRoka)
            State.ItemCount = countInBackpack(Config.ItemType)
            State.RokaCount = countInBackpack("Rokakaka")
            needItem = State.ItemCount == 0
            needRoka = State.RokaCount  == 0

            if needItem or needRoka then
                buyFromShop(needItem, needRoka)
                State.ItemCount = countInBackpack(Config.ItemType)
                State.RokaCount = countInBackpack("Rokakaka")
                if State.ItemCount == 0 or State.RokaCount == 0 then
                    task.wait(2) ; continue
                end
            end
        end

        pcall(unlockWorthiness)
        waitAlive()

        State.CurrentPhase = "ROLLING"
        local rollingItem  = equipTool(Config.ItemType)
        if not rollingItem then
            task.wait(Config.LoopDelay) ; continue
        end

        local char = LocalPlayer.Character
        if char then
            local equipped = char:FindFirstChildOfClass("Tool")
            if equipped then
                pcall(function() equipped:Activate() end)
                task.wait(0.2)
                confirmDialogue()
            end
        end

        local detectStart = tick()
        local newStand    = "None"
        repeat
            task.wait(0.3)
            newStand = detectCurrentStand()
        until newStand ~= "None" or tick() - detectStart > 5

        State.ActiveStand = newStand

        if newStand ~= "None" and newStand:lower():find(Config.TargetStand:lower(), 1, true) then
            State.CurrentPhase = "FINISHED"
            State.Running      = false

            -- Obsidian notification
            pcall(function()
                Library:Notify("Все есть! Выбит: " .. newStand, 10)
            end)
            -- Fallback Roblox notification
            pcall(function()
                game:GetService("StarterGui"):SetCore("SendNotification", {
                    Title    = "Scythe | YBA",
                    Text     = "Все есть! Выбит: " .. newStand,
                    Duration = 10,
                })
            end)

            -- Sync toggle UI back to OFF
            pcall(function()
                if Toggles and Toggles.AutoRollToggle then
                    Toggles.AutoRollToggle:SetValue(false)
                end
            end)
            return
        end

        -- Wrong stand — reset with Rokakaka
        State.CurrentPhase = "RESETTING"
        local roka = equipTool("Rokakaka")
        if roka then
            local char2 = LocalPlayer.Character
            if char2 then
                local eq = char2:FindFirstChildOfClass("Tool")
                if eq then
                    pcall(function() eq:Activate() end)
                    task.wait(0.2)
                    confirmDialogue()
                end
            end
        end

        task.wait(2)
        State.CurrentPhase = "IDLE"
        task.wait(Config.LoopDelay)
    end

    State.CurrentPhase = "IDLE"
end

-- ─────────────────────────────────────────────────────────────────────────────
-- § 6 · FARM ENGINE
-- ─────────────────────────────────────────────────────────────────────────────

local function isWanted(name)
    if Config.FarmItems[name] == true then return true, name end
    local low = name:lower()
    for key, enabled in pairs(Config.FarmItems) do
        if enabled and low:find(key:lower(), 1, true) then return true, key end
    end
    return false, nil
end

local function getItemPart(obj)
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        return obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
    end
    return nil
end

local function triggerPrompt(prompt)
    if fireproximityprompt then
        pcall(fireproximityprompt, prompt, prompt.HoldDuration or 1)
        return
    end
    pcall(function()
        prompt:InputHoldBegin()
        task.wait((prompt.HoldDuration or 0) + 0.1)
        prompt:InputHoldEnd()
    end)
end

local function buildItemQueue()
    local queue = {}
    local now   = tick()
    local function scanContainer(container)
        if not container then return end
        for _, obj in ipairs(container:GetDescendants()) do
            if FarmState.Blacklist[obj] and FarmState.Blacklist[obj] > now then continue end
            if obj:IsA("Model") or obj:IsA("BasePart") then
                local wanted, matchedKey = isWanted(obj.Name)
                if wanted then
                    local part = getItemPart(obj)
                    if part then
                        table.insert(queue, { obj = obj, part = part, key = matchedKey })
                    end
                end
            end
        end
    end
    scanContainer(workspace)
    pcall(scanContainer, workspace:FindFirstChild("ItemSpawns"))
    pcall(scanContainer, workspace:FindFirstChild("Debris"))
    pcall(scanContainer, workspace:FindFirstChild("DroppedItems"))
    return queue
end

local function pickupItem(entry)
    local char = LocalPlayer.Character
    if not char then return false end
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    if not hrp or not entry.part or not entry.part.Parent then return false end

    FarmState.Status   = "TELEPORTING"
    FarmState.LastItem = entry.key

    pcall(function()
        hrp.CFrame = entry.part.CFrame + Vector3.new(0, 2, 0)
        hrp.AssemblyLinearVelocity = Vector3.zero
    end)
    task.wait(0.15)

    local prompt = entry.obj:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then triggerPrompt(prompt) end
    task.wait(0.3)

    if entry.part and entry.part.Parent then
        if prompt then triggerPrompt(prompt) end
        task.wait(0.3)
        if entry.part and entry.part.Parent then
            FarmState.Blacklist[entry.obj] = tick() + 30
            return false
        end
    end

    FarmState.Tally[entry.key] = (FarmState.Tally[entry.key] or 0) + 1
    return true
end

local patrolActive       = false
local patrolDescListener = nil

local function stopPatrol()
    patrolActive = false
    if patrolDescListener then
        pcall(function() patrolDescListener:Disconnect() end)
        patrolDescListener = nil
    end
end

local function farmLoop()
    while FarmState.Running do
        waitAlive()
        FarmState.Status = "SCANNING"

        local char = LocalPlayer.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then task.wait(1) continue end

        local now = tick()
        for obj, expiry in pairs(FarmState.Blacklist) do
            if expiry <= now then FarmState.Blacklist[obj] = nil end
        end

        local queue = buildItemQueue()

        if #queue == 0 then
            FarmState.Status   = "PATROLLING"
            FarmState.LastItem = "—"
            local wakeUp = false

            patrolActive = true
            patrolDescListener = workspace.DescendantAdded:Connect(function(obj)
                if not patrolActive then return end
                if isWanted(obj.Name) then
                    stopPatrol()
                    wakeUp = true
                end
            end)

            local hum     = char and char:FindFirstChildOfClass("Humanoid")
            local pidx    = 1
            local tStart  = tick()
            while patrolActive and FarmState.Running and tick() - tStart < 30 do
                if hum and Config.PatrolPoints[pidx] then
                    pcall(function() hum:MoveTo(Config.PatrolPoints[pidx]) end)
                    pidx = pidx % #Config.PatrolPoints + 1
                end
                task.wait(1.5)
                if wakeUp then break end
            end
            stopPatrol()
        else
            -- Sort by proximity
            local function sortDist(a, b)
                return (hrp.Position - a.part.Position).Magnitude
                     < (hrp.Position - b.part.Position).Magnitude
            end
            table.sort(queue, sortDist)

            for _, entry in ipairs(queue) do
                if not FarmState.Running then break end
                waitAlive()
                pickupItem(entry)
                task.wait(0.05)
            end
        end
        task.wait(0.3)
    end
    FarmState.Status   = "IDLE"
    FarmState.LastItem = "—"
end

Modules.Farm = {
    Start = function()
        if FarmState.Running then return end
        FarmState.Running = true
        FarmState.Thread  = task.spawn(farmLoop)
    end,
    Stop = function()
        FarmState.Running = false
        stopPatrol()
        if FarmState.Thread then
            pcall(task.cancel, FarmState.Thread)
            FarmState.Thread = nil
        end
    end,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- § 7 · OBSIDIAN WINDOW & TABS
-- ─────────────────────────────────────────────────────────────────────────────

local Window = Library:CreateWindow({
    Title          = 'Scythe | YBA Suite',
    Center         = true,
    AutoShow       = true,
    TabPadding     = 8,
    MenuFadeTime   = 0.2,
})

-- ── Tabs ─────────────────────────────────────────────────────────────────────
local Tabs = {
    AutoRoll = Window:AddTab('Auto Roll'),
    Farm     = Window:AddTab('Item Farm'),
    Settings = Window:AddTab('Settings'),
}

-- ── Groupboxes: Auto Roll ────────────────────────────────────────────────────
local RollLeft  = Tabs.AutoRoll:AddLeftGroupbox('Stand Rolling Configuration')
local RollRight = Tabs.AutoRoll:AddRightGroupbox('Live Status & Statistics')

-- ── Groupboxes: Item Farm ─────────────────────────────────────────────────────
local FarmLeft  = Tabs.Farm:AddLeftGroupbox('Farm Controls')
local FarmRight = Tabs.Farm:AddRightGroupbox('Item Whitelist')

-- ── Groupboxes: Settings ──────────────────────────────────────────────────────
local SettingsLeft  = Tabs.Settings:AddLeftGroupbox('Configuration')
local SettingsRight = Tabs.Settings:AddRightGroupbox('Theme & Saves')

-- ─────────────────────────────────────────────────────────────────────────────
-- § 8 · AUTO ROLL TAB — Controls
-- ─────────────────────────────────────────────────────────────────────────────

-- ── Target Stand Dropdown ─────────────────────────────────────────────────────
RollLeft:AddDropdown('TargetStandDropdown', {
    Text    = 'Target Stand',
    Values  = Config.StandPool,
    Default = Config.TargetStand,
    Callback = function(value)
        Config.TargetStand = value
    end,
})

-- ── Rolling Item Dropdown ─────────────────────────────────────────────────────
RollLeft:AddDropdown('RollingItemDropdown', {
    Text   = 'Rolling Item',
    Values = {
        'Mysterious Arrow',
        'Lucky Arrow',
        "Rib Cage of the Saint's Corpse",
    },
    Default  = Config.ItemType,
    Callback = function(value)
        Config.ItemType = value
    end,
})

-- ── Divider ───────────────────────────────────────────────────────────────────
RollLeft:AddDivider()

-- ── Auto-Roll Master Toggle ───────────────────────────────────────────────────
RollLeft:AddToggle('AutoRollToggle', {
    Text    = 'Enable Auto-Roll',
    Default = false,
    Tooltip = 'Starts the stand reroll state machine',
    Callback = function(value)
        if value then
            if not State.Running then
                State.Running      = true
                State.CurrentPhase = 'IDLE'
                loopThread         = task.spawn(runLoop)
            end
        else
            State.Running = false
            if loopThread then
                pcall(task.cancel, loopThread)
                loopThread = nil
            end
            State.CurrentPhase = 'IDLE'
        end
    end,
})

-- ── Keybind ───────────────────────────────────────────────────────────────────
RollLeft:AddKeybind('UIKeybind', {
    Text    = 'Toggle UI Visibility',
    Default = 'RightControl',
})

-- ─────────────────────────────────────────────────────────────────────────────
-- § 9 · AUTO ROLL TAB — Live Status Labels
-- ─────────────────────────────────────────────────────────────────────────────

local LblState      = RollRight:AddLabel('State: IDLE',        true)
local LblStand      = RollRight:AddLabel('Current Stand: None', true)
local LblInventory  = RollRight:AddLabel('Inventory: Arrows: 0 | Rokas: 0', true)
local LblWorthiness = RollRight:AddLabel('Worthiness: UNKNOWN', true)

RollRight:AddDivider()

-- Session summary (read-only)
local LblRollCount  = RollRight:AddLabel('Rolls this session: 0', true)
local sessionRolls  = 0

-- ─────────────────────────────────────────────────────────────────────────────
-- § 10 · ITEM FARM TAB — Controls
-- ─────────────────────────────────────────────────────────────────────────────

FarmLeft:AddToggle('EnableItemFarm', {
    Text    = 'Enable Item Farm',
    Default = false,
    Tooltip = 'Teleports to and collects enabled ground items',
    Callback = function(value)
        if value then
            Modules.Farm.Start()
        else
            Modules.Farm.Stop()
        end
    end,
})

FarmLeft:AddToggle('PatrolWhenEmpty', {
    Text    = 'Patrol Map when Empty',
    Default = true,
    Tooltip = 'Cycles patrol waypoints while waiting for item respawns',
    Callback = function(value)
        -- Toggle is read in farmLoop via Toggles.PatrolWhenEmpty.Value
    end,
})

FarmLeft:AddDivider()

FarmLeft:AddButton({
    Text = 'Scan Map Now',
    Func = function()
        task.spawn(function()
            local queue = buildItemQueue()
            Library:Notify('Scan complete — ' .. #queue .. ' item(s) found', 4)
        end)
    end,
})

FarmLeft:AddDivider()

-- Farm live status
local LblFarmStatus = FarmLeft:AddLabel('[FARM] IDLE', true)
local LblFarmTally  = FarmLeft:AddLabel('Arrows: 0  Rokas: 0  Ribs: 0  Diamonds: 0', true)

-- ─────────────────────────────────────────────────────────────────────────────
-- § 11 · ITEM FARM TAB — Whitelist Multi-Dropdown
-- ─────────────────────────────────────────────────────────────────────────────

-- Collect all FarmItems keys into an ordered list
local ALL_FARM_ITEMS = {
    -- Stand Modifiers
    "Mysterious Arrow", "Lucky Arrow", "Rokakaka", "Pure Rokakaka",
    "Rib Cage of the Saint's Corpse", "Requiem Arrow",
    -- Spec
    "Stone Mask", "Ancient Scroll", "Quinton's Glove", "Steel Ball",
    "Zeppeli's Headband", "Clackers", "Boxing Gloves", "Boxing Claws", "Bone Gloves",
    -- Evolution
    "DIO's Diary", "Green Baby", "DIO's Bone", "Jotaro's Disc",
    "Left Arm of the Saint's Corpse", "Heart of the Saint's Corpse",
    "Pelvis of the Saint's Corpse",
    -- Valuables
    "Gold Coin", "Diamond",
}

-- Build default selected list from Config.FarmItems
local defaultSelected = {}
for _, item in ipairs(ALL_FARM_ITEMS) do
    if Config.FarmItems[item] == true then
        table.insert(defaultSelected, item)
    end
end

FarmRight:AddMultiDropdown('ItemWhitelist', {
    Text    = 'Collectible Items',
    Values  = ALL_FARM_ITEMS,
    Default = defaultSelected,
    Tooltip = 'Select which items the Farm module will collect',
    Callback = function(selectedMap)
        -- selectedMap is a table where keys are item names and values are true/false
        for _, item in ipairs(ALL_FARM_ITEMS) do
            if Config.FarmItems[item] ~= nil then
                Config.FarmItems[item] = selectedMap[item] == true
            end
        end
    end,
})

-- ─────────────────────────────────────────────────────────────────────────────
-- § 12 · SETTINGS TAB
-- ─────────────────────────────────────────────────────────────────────────────

SettingsLeft:AddLabel('Scavenge Timeout (seconds): ' .. Config.ScavengeTimeout, true)

SettingsLeft:AddDivider()

-- Watermark
Library:SetWatermark('Scythe | YBA Suite  —  v2.0')
Library:SetWatermarkVisibility(true)

SettingsLeft:AddToggle('WatermarkVisible', {
    Text    = 'Show Watermark',
    Default = true,
    Callback = function(v)
        Library:SetWatermarkVisibility(v)
    end,
})

-- ThemeManager & SaveManager bindings
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'UIKeybind' })
SaveManager:SetFolder('Scythe_YBA')

ThemeManager:ApplyToGroupbox(SettingsRight)
SaveManager:BuildConfigSection(SettingsLeft)

-- ─────────────────────────────────────────────────────────────────────────────
-- § 13 · STATUS TICKER (0.5s background update loop)
-- ─────────────────────────────────────────────────────────────────────────────

task.spawn(function()
    local prevPhase = ""
    while true do
        -- ── AutoRoll status labels ──────────────────────────────────────────
        local phase = State.CurrentPhase

        -- Track rolls
        if phase == "ROLLING" and prevPhase ~= "ROLLING" then
            sessionRolls += 1
            pcall(function() LblRollCount:SetText('Rolls this session: ' .. sessionRolls) end)
        end
        prevPhase = phase

        -- State label with colour hint prefix
        local phaseStr = phase
        pcall(function()
            LblState:SetText('State: ' .. phaseStr)
        end)

        -- Current stand
        pcall(function()
            LblStand:SetText('Current Stand: ' .. State.ActiveStand)
        end)

        -- Inventory (live counts even when not rolling)
        local ic = countInBackpack(Config.ItemType)
        local rc = countInBackpack("Rokakaka")
        State.ItemCount = ic
        State.RokaCount = rc
        pcall(function()
            LblInventory:SetText(
                string.format('Inventory: Item: %d | Rokas: %d', ic, rc)
            )
        end)

        -- Worthiness
        pcall(function()
            LblWorthiness:SetText('Worthiness: ' .. State.Worthiness)
        end)

        -- ── Farm status labels ─────────────────────────────────────────────
        local farmPhase = FarmState.Status
        local farmLine  = '[FARM] ' .. farmPhase
        if farmPhase == "TELEPORTING" then
            farmLine = '[FARM] Teleporting to ' .. FarmState.LastItem
        elseif farmPhase == "PATROLLING" then
            farmLine = '[FARM] Patrolling map...'
        end

        pcall(function() LblFarmStatus:SetText(farmLine) end)

        -- Tally
        local arrowTally = (FarmState.Tally["Mysterious Arrow"] or 0)
                         + (FarmState.Tally["Lucky Arrow"] or 0)
        pcall(function()
            LblFarmTally:SetText(string.format(
                'Arrows: %d  Rokas: %d  Ribs: %d  Diamonds: %d',
                arrowTally,
                FarmState.Tally["Rokakaka"] or 0,
                FarmState.Tally["Rib Cage of the Saint's Corpse"] or 0,
                FarmState.Tally["Diamond"] or 0
            ))
        end)

        task.wait(0.5)
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- § 14 · CLEANUP ON LIBRARY UNLOAD
-- ─────────────────────────────────────────────────────────────────────────────
Library.Unloaded:Connect(function()
    State.Running = false
    if loopThread then pcall(task.cancel, loopThread) end
    pcall(Modules.Farm.Stop)
end)

-- Load saved config (must be called after all UI elements are built)
SaveManager:LoadAutoloadConfig()

print("[Scythe v2] Obsidian UI loaded. Toggle: " .. tostring(Config.ToggleKey))

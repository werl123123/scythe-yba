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
        if (v:IsA("TextButton") or v:IsA("TextLabel")) and v.Text:lower():find(low, 1, true) then
            return v
        end
    end
    return nil
end

local function clickWithCursor(guiObj)
    if not guiObj then return false end
    local clicked = false

    local cx, cy = 0, 0
    if guiObj:IsA("GuiObject") then
        local absPos = guiObj.AbsolutePosition
        local absSize = guiObj.AbsoluteSize
        cx = absPos.X + absSize.X / 2
        cy = absPos.Y + absSize.Y / 2
    end

    -- 1. VirtualInputManager cursor mouse click (simulates hardware mouse input)
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        if vim and cx > 0 and cy > 0 then
            vim:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
            task.wait(0.03)
            vim:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
            clicked = true
        end
    end)

    -- 2. VirtualUser fallback
    pcall(function()
        local vu = game:GetService("VirtualUser")
        if vu and cx > 0 and cy > 0 then
            vu:CaptureController()
            vu:Button1Down(Vector2.new(cx, cy))
            task.wait(0.02)
            vu:Button1Up(Vector2.new(cx, cy))
            clicked = true
        end
    end)

    -- 3. firesignal (executors like Synapse, Krnl, Fluxus, Solara, Wave, Delta, etc.)
    if firesignal then
        pcall(function() firesignal(guiObj.MouseButton1Down) end)
        pcall(function() firesignal(guiObj.MouseButton1Click) end)
        pcall(function() firesignal(guiObj.MouseButton1Up) end)
        pcall(function() firesignal(guiObj.Activated) end)
        clicked = true
    end

    -- 4. Executor FireMouseButton1Click if present
    pcall(function()
        if guiObj.FireMouseButton1Click then
            guiObj:FireMouseButton1Click()
            clicked = true
        end
    end)

    return clicked
end

-- Backward compatibility alias
local clickGuiButton = clickWithCursor

-- Screen click with mouse cursor to use / eat held tools (YBA input mechanic)
local function clickScreenWithCursor()
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
    local cx = vp.X / 2
    local cy = vp.Y / 2

    local vim = game:GetService("VirtualInputManager")
    if vim then
        pcall(function()
            vim:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
            task.wait(0.05)
            vim:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
        end)
    end

    local vu = game:GetService("VirtualUser")
    if vu then
        pcall(function()
            vu:CaptureController()
            vu:Button1Down(Vector2.new(cx, cy))
            task.wait(0.05)
            vu:Button1Up(Vector2.new(cx, cy))
        end)
    end

    local char = LocalPlayer.Character
    if char then
        local t = char:FindFirstChildOfClass("Tool")
        if t then pcall(function() t:Activate() end) end
    end
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

-- ── Color & Skill Tree Helpers ────────────────────────────────────────────────
local function isPurpleColor(c)
    if not c then return false end
    local h, s, v = c:ToHSV()
    return (h >= 0.68 and h <= 0.92 and s >= 0.25 and v >= 0.35)
        or (c.R > 0.4 and c.B > 0.45 and c.G < 0.6 and c.B > c.G * 1.2)
end

local function hasPurpleAppearance(guiObj)
    if not guiObj or not guiObj:IsA("GuiObject") then return false end
    if isPurpleColor(guiObj.BackgroundColor3) or isPurpleColor(guiObj.BorderColor3) then
        return true
    end
    if (guiObj:IsA("ImageButton") or guiObj:IsA("ImageLabel")) and isPurpleColor(guiObj.ImageColor3) then
        return true
    end
    for _, child in ipairs(guiObj:GetDescendants()) do
        if child:IsA("UIStroke") and isPurpleColor(child.Color) then return true end
        if child:IsA("ImageLabel") and isPurpleColor(child.ImageColor3) then return true end
        if child:IsA("GuiObject") and (isPurpleColor(child.BackgroundColor3) or isPurpleColor(child.BorderColor3)) then
            return true
        end
    end
    return false
end

local function isWorthinessText(str)
    if not str or type(str) ~= "string" then return false end
    local low = str:lower()
    return low:find("worth") or low:find("достоин") or low:find("достойн")
end

local function hasWorthinessName(guiObj)
    if not guiObj then return false end
    if isWorthinessText(guiObj.Name) then return true end
    if guiObj:IsA("TextButton") and isWorthinessText(guiObj.Text) then return true end
    for _, child in ipairs(guiObj:GetDescendants()) do
        if child:IsA("TextLabel") and isWorthinessText(child.Text) then return true end
    end
    return false
end

-- ── Background Mode: Hide Menu UI from Player's Screen ────────────────────────
local hiddenFrames = {}

local function setMenuBackgroundMode(enabled)
    if enabled then
        hiddenFrames = {}
        for _, g in ipairs(PlayerGui:GetChildren()) do
            if g:IsA("ScreenGui") and g.Name ~= "Obsidian" and g.Name ~= "Library" then
                for _, f in ipairs(g:GetChildren()) do
                    if f:IsA("GuiObject") then
                        local n = f.Name:lower()
                        if n:find("menu") or n:find("skill") or n:find("tree") or n:find("char") or n:find("inv") then
                            if f.Visible and f.Position.X.Scale < 5 then
                                table.insert(hiddenFrames, { frame = f, origPos = f.Position, origVis = f.Visible })
                                -- Move offscreen immediately so player never sees it
                                f.Position = UDim2.new(50, 0, f.Position.Y.Scale, f.Position.Y.Offset)
                            end
                        end
                    end
                end
            end
        end
    else
        for _, entry in ipairs(hiddenFrames) do
            pcall(function()
                entry.frame.Position = entry.origPos
                entry.frame.Visible = entry.origVis
            end)
        end
        hiddenFrames = {}
    end
end

-- ── Locate Menu Button with Cursor ───────────────────────────────────────────
local function findMenuButton()
    -- 1. By name / text
    for _, v in ipairs(PlayerGui:GetDescendants()) do
        if v:IsA("GuiButton") and v.Visible then
            local n = v.Name:lower()
            local t = (v.Text or ""):lower()
            if n == "menu" or t == "menu" or n == "меню" or t == "меню"
               or n:find("menubutton") or n:find("openmenu") or n:find("togglemenu") then
                return v
            end
        end
    end

    -- 2. By position in bottom-right corner (YBA standard HUD menu location)
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
    local bestBtn = nil
    local maxScore = -1

    for _, v in ipairs(PlayerGui:GetDescendants()) do
        if v:IsA("GuiButton") and v.Visible then
            local pos = v.AbsolutePosition
            local sz = v.AbsoluteSize
            if pos.X > vp.X * 0.60 and pos.Y > vp.Y * 0.60 and sz.X >= 18 and sz.Y >= 18 and sz.X <= 250 and sz.Y <= 250 then
                local score = pos.X + pos.Y
                if score > maxScore then
                    maxScore = score
                    bestBtn = v
                end
            end
        end
    end

    return bestBtn
end

-- ── Smart Item Equipper (Hotbar, Backpack, or Background Inventory) ───────────
local function smartEquipItem(itemName)
    local low = itemName:lower()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")

    -- 1. Check if tool is ALREADY in hand
    local inHand = char:FindFirstChildOfClass("Tool")
    if inHand and inHand.Name:lower():find(low, 1, true) then
        return inHand
    end

    -- 2. Check Backpack
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") and tool.Name:lower():find(low, 1, true) then
                if hum then hum:EquipTool(tool) end
                task.wait(0.2)
                return tool
            end
        end
    end

    -- 3. Check Hotbar in HUD
    for _, v in ipairs(PlayerGui:GetDescendants()) do
        if v:IsA("GuiButton") and v.Visible then
            local txt = (v.Text or ""):lower()
            local name = v.Name:lower()
            if txt:find(low, 1, true) or name:find(low, 1, true) then
                clickWithCursor(v)
                task.wait(0.2)
                local eq = char:FindFirstChildOfClass("Tool")
                if eq and eq.Name:lower():find(low, 1, true) then
                    return eq
                end
            end
        end
    end

    -- 4. Check Inventory Menu in background mode (if item is stored in inventory)
    local menuBtn = findMenuButton()
    if menuBtn then
        clickWithCursor(menuBtn)
        task.wait(0.1)
        setMenuBackgroundMode(true)

        local invBtn = findDescendantContaining(PlayerGui, "Inventory")
            or findDescendantContaining(PlayerGui, "Инвентарь")
        if invBtn and invBtn:IsA("GuiButton") then
            clickWithCursor(invBtn)
            task.wait(0.15)

            local itemBtn = findDescendantContaining(PlayerGui, itemName)
            if itemBtn and itemBtn:IsA("GuiButton") then
                clickWithCursor(itemBtn)
                task.wait(0.2)
            end
        end

        local closeBtn = findDescendantContaining(PlayerGui, "Close")
            or findDescendantContaining(PlayerGui, "Закрыть")
        if closeBtn and closeBtn:IsA("GuiButton") then
            clickWithCursor(closeBtn)
        end
        setMenuBackgroundMode(false)
        task.wait(0.15)
    end

    -- Verify if now in hand or backpack
    local eqNow = char:FindFirstChildOfClass("Tool")
    if eqNow and eqNow.Name:lower():find(low, 1, true) then
        return eqNow
    end
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") and tool.Name:lower():find(low, 1, true) then
                if hum then hum:EquipTool(tool) end
                task.wait(0.2)
                return tool
            end
        end
    end

    return nil
end

local function equipTool(substring)
    return smartEquipItem(substring)
end

-- ── Skill Tree Open / Close in Background Mode ────────────────────────────────
local function openSkillTree()
    local backBtn = findDescendantContaining(PlayerGui, "BACK")
        or findDescendantContaining(PlayerGui, "Назад")
    if backBtn and backBtn:IsA("GuiButton") and backBtn.Visible then
        return true
    end

    -- 1. Click Menu button with CURSOR (not key M)
    local menuBtn = findMenuButton()
    if menuBtn then
        clickWithCursor(menuBtn)
    end
    task.wait(0.2)

    -- Hide menu from view immediately for background mode
    setMenuBackgroundMode(true)

    -- 2. Click Character / Персонаж with CURSOR
    local charBtn = findDescendantContaining(PlayerGui, "Персонаж")
        or findDescendantContaining(PlayerGui, "Character")
    if charBtn and charBtn:IsA("GuiButton") then
        clickWithCursor(charBtn)
        task.wait(0.25)
    end

    -- 3. Click Skill Tree / Навыки if present
    local skillBtn = findDescendantContaining(PlayerGui, "Skill Tree")
        or findDescendantContaining(PlayerGui, "Навыки")
    if skillBtn and skillBtn:IsA("GuiButton") then
        clickWithCursor(skillBtn)
        task.wait(0.25)
    end

    for _ = 1, 8 do
        backBtn = findDescendantContaining(PlayerGui, "BACK")
            or findDescendantContaining(PlayerGui, "Назад")
        if backBtn and backBtn:IsA("GuiButton") then
            return true
        end
        task.wait(0.05)
    end
    return false
end

local function closeSkillTree()
    local backBtn = findDescendantContaining(PlayerGui, "BACK")
        or findDescendantContaining(PlayerGui, "Назад")
    if backBtn and backBtn:IsA("GuiButton") then
        clickWithCursor(backBtn)
        task.wait(0.2)
    end

    local closeBtn = findDescendantContaining(PlayerGui, "Close")
        or findDescendantContaining(PlayerGui, "Закрыть")
        or findDescendantContaining(PlayerGui, "Exit")
    if closeBtn and closeBtn:IsA("GuiButton") then
        clickWithCursor(closeBtn)
        task.wait(0.15)
    end

    setMenuBackgroundMode(false)
end

local function learnSkillNode(node)
    if not node then return false end
    -- First click: select node with cursor
    clickWithCursor(node)
    task.wait(0.15)

    -- Check if card has "Нажмите еще раз, чтобы узнать" or "Click again to learn"
    local needsSecondClick = false
    for _, v in ipairs(PlayerGui:GetDescendants()) do
        if v:IsA("TextLabel") and v.Visible then
            local t = v.Text:lower()
            if t:find("нажмите еще раз") or t:find("click again") then
                needsSecondClick = true
                break
            end
        end
    end

    -- Check for explicit learn button
    for _, v in ipairs(PlayerGui:GetDescendants()) do
        if v:IsA("GuiButton") and v.Visible then
            local t = (v.Text or ""):lower()
            if t == "learn" or t == "выучить" or t == "купить" then
                clickWithCursor(v)
                task.wait(0.2)
                return true
            end
        end
    end

    -- Second click: Learn skill with cursor (YBA mechanic)
    if needsSecondClick then
        clickWithCursor(node)
        task.wait(0.2)
        return true
    end

    return false
end

-- ── 5A · Worthiness unlock (Background Mode) ──────────────────────────────────
local function unlockWorthiness()
    State.CurrentPhase = "UNLOCKING_WORTHINESS"

    local opened = openSkillTree()
    if not opened then
        task.wait(0.2)
        openSkillTree()
    end
    task.wait(0.2)

    -- Collect all potential skill node buttons
    local allButtons = {}
    for _, v in ipairs(PlayerGui:GetDescendants()) do
        if v:IsA("GuiButton") then
            local txt = (v.Text or ""):lower()
            local name = v.Name:lower()
            if txt ~= "back" and txt ~= "назад" and txt ~= "close" and txt ~= "закрыть"
               and not txt:find("очки навыков") and not txt:find("skill point")
               and not name:find("menu") and not name:find("close") and not name:find("back") then
                local s = v.AbsoluteSize
                if s.X >= 25 and s.X <= 160 and s.Y >= 25 and s.Y <= 160 then
                    local aspect = s.X / math.max(s.Y, 1)
                    if aspect >= 0.7 and aspect <= 1.4 then
                        table.insert(allButtons, v)
                    end
                end
            end
        end
    end

    -- Find the Worthiness node
    -- 1. By purple appearance ("до фиолетового кружочка")
    -- 2. By name / text ("достойность-worthiness")
    local worthinessNode = nil
    for _, btn in ipairs(allButtons) do
        if hasPurpleAppearance(btn) or hasWorthinessName(btn) then
            worthinessNode = btn
            break
        end
    end

    -- Fallback: click buttons with cursor and check card title
    if not worthinessNode then
        for _, btn in ipairs(allButtons) do
            clickWithCursor(btn)
            task.wait(0.08)
            for _, lbl in ipairs(PlayerGui:GetDescendants()) do
                if lbl:IsA("TextLabel") and lbl.Visible and isWorthinessText(lbl.Text) then
                    worthinessNode = btn
                    break
                end
            end
            if worthinessNode then break end
        end
    end

    if worthinessNode then
        -- Find prerequisite nodes leading to it in the same vertical column
        local prereqs = {}
        local wx = worthinessNode.AbsolutePosition.X
        local wy = worthinessNode.AbsolutePosition.Y

        for _, btn in ipairs(allButtons) do
            if btn ~= worthinessNode then
                local bx = btn.AbsolutePosition.X
                local by = btn.AbsolutePosition.Y
                if math.abs(bx - wx) <= 35 and by > wy then
                    table.insert(prereqs, btn)
                end
            end
        end

        -- Sort prerequisites from bottom (largest Y) to top (smaller Y)
        table.sort(prereqs, function(a, b)
            return a.AbsolutePosition.Y > b.AbsolutePosition.Y
        end)

        -- Unlock prerequisite nodes in order
        for _, preNode in ipairs(prereqs) do
            learnSkillNode(preNode)
            task.wait(0.12)
        end

        -- Unlock the purple Worthiness node
        learnSkillNode(worthinessNode)
        task.wait(0.15)
        State.Worthiness = "LEARNED"
    else
        local worthFallback = findDescendantContaining(PlayerGui, "Worthiness")
            or findDescendantContaining(PlayerGui, "Достоинство")
        if worthFallback then
            learnSkillNode(worthFallback)
            State.Worthiness = "LEARNED"
        end
    end

    -- Close skill tree and return to game
    closeSkillTree()
    task.wait(0.2)
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

    local menuBtn = findMenuButton()
    if menuBtn then
        clickWithCursor(menuBtn)
        task.wait(Config.ShopDelay)
    end

    local shopBtn = nil
    for _, v in ipairs(PlayerGui:GetDescendants()) do
        if v:IsA("GuiButton") and v.Visible then
            local txt = v.Text or ""
            if txt:find("%$") or txt:lower():find("shop") then
                shopBtn = v ; break
            end
        end
    end
    if shopBtn then
        clickWithCursor(shopBtn)
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
                                    clickWithCursor(child)
                                    task.wait(Config.ShopDelay)
                                    local confirmBtn = findDescendantContaining(PlayerGui, "Confirm")
                                        or findDescendantContaining(PlayerGui, "Yes")
                                        or findDescendantContaining(PlayerGui, "Да")
                                    if confirmBtn and confirmBtn:IsA("GuiButton") then
                                        clickWithCursor(confirmBtn)
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
    if closeShop and closeShop:IsA("GuiButton") then
        clickWithCursor(closeShop)
    end
    task.wait(Config.ShopDelay)

    State.ItemCount = countInBackpack(Config.ItemType)
    State.RokaCount = countInBackpack("Rokakaka")
end

-- ── 5D · Dialogue Confirmer with Cursor ───────────────────────────────────────
local function confirmDialogue()
    local startTime = tick()
    while tick() - startTime < 3.5 do
        for _, v in ipairs(PlayerGui:GetDescendants()) do
            if v:IsA("GuiButton") and v.Visible then
                local txt = (v.Text or ""):lower():gsub("%s+", "")
                local name = v.Name:lower():gsub("%s+", "")

                if txt == "yes" or txt == "да"
                   or txt == "eat" or txt == "съесть" or txt == "покушать"
                   or txt == "use" or txt == "использовать" or txt == "применить"
                   or txt:find("confirm") or txt:find("подтверд")
                   or name == "option1" or name == "choice1" or name == "yes" then
                    clickWithCursor(v)
                    task.wait(0.3)
                    return true
                end
            end
        end
        task.wait(0.1)
    end
    return false
end

-- ── Use Item with Cursor (Equip -> Click Screen -> Confirm Dialogue) ──────────
local function useItemWithCursor(itemName)
    local tool = smartEquipItem(itemName)
    if not tool then
        return false
    end
    task.wait(0.2)

    -- Click screen with mouse cursor to trigger item dialogue
    clickScreenWithCursor()
    task.wait(0.3)

    -- Confirm dialogue prompt with cursor click
    local ok = confirmDialogue()
    if not ok then
        -- Retry screen click once if dialogue hasn't opened yet
        clickScreenWithCursor()
        task.wait(0.2)
        ok = confirmDialogue()
    end
    return ok
end

-- ── 5E · Stand Detection ──────────────────────────────────────────────────────
local function detectCurrentStand()
    -- 1. Check PlayerStats (most reliable in YBA)
    local pStats = LocalPlayer:FindFirstChild("PlayerStats")
    if pStats then
        local sVal = pStats:FindFirstChild("Stand")
        if sVal and sVal:IsA("StringValue") and sVal.Value ~= "" and sVal.Value ~= "None" and sVal.Value ~= "Standless" then
            return sVal.Value
        end
    end

    -- 2. Check Player / Character Attributes
    local attrStand = LocalPlayer:GetAttribute("Stand")
    if attrStand and type(attrStand) == "string" and attrStand ~= "" and attrStand ~= "None" and attrStand ~= "Standless" then
        return attrStand
    end

    local char = LocalPlayer.Character
    if char then
        local charAttr = char:GetAttribute("Stand")
        if charAttr and type(charAttr) == "string" and charAttr ~= "" and charAttr ~= "None" and charAttr ~= "Standless" then
            return charAttr
        end

        -- 3. Check Character Models
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("Model") then
                for _, s in ipairs(Config.StandPool) do
                    if obj.Name:lower():find(s:lower(), 1, true) then return s end
                end
            end
        end
    end

    -- 4. Check PlayerGui HUD labels
    for _, v in ipairs(PlayerGui:GetDescendants()) do
        if v:IsA("TextLabel") and v.Visible then
            local t = v.Text:lower()
            for _, s in ipairs(Config.StandPool) do
                if t:find(s:lower(), 1, true) then return s end
            end
        end
    end

    return "None"
end

-- ── 5F · Reroll Loop ─────────────────────────────────────────────────────────
local function runLoop()
    while State.Running do
        waitAlive()

        -- Check if target stand is already equipped right at the start
        local initialStand = detectCurrentStand()
        State.ActiveStand = initialStand
        if initialStand ~= "None" and initialStand:lower():find(Config.TargetStand:lower(), 1, true) then
            State.CurrentPhase = "FINISHED"
            State.Running      = false

            pcall(function()
                Library:Notify("Целевой стенд уже получен: " .. initialStand, 10)
            end)
            pcall(function()
                game:GetService("StarterGui"):SetCore("SendNotification", {
                    Title    = "Scythe | YBA",
                    Text     = "Целевой стенд уже получен: " .. initialStand,
                    Duration = 10,
                })
            end)
            pcall(function()
                if Toggles and Toggles.AutoRollToggle then
                    Toggles.AutoRollToggle:SetValue(false)
                end
            end)
            return
        end

        -- Check inventory counts
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
                    pcall(function()
                        Library:Notify("Недостаточно предметов! Стрелы: " .. State.ItemCount .. " | Рока: " .. State.RokaCount, 3)
                    end)
                    task.wait(2)
                    continue
                end
            end
        end

        -- ── STEP 1 · EAT ROKAKAKA WITH CURSOR ───────────────────────────────
        -- "как только я включаю функцию что бы он брал рокаку в руки использывал ее курсором"
        State.CurrentPhase = "RESETTING"
        local rokaOk = useItemWithCursor("Rokakaka")
        if rokaOk then
            task.wait(2.5)
            waitAlive()
            task.wait(0.3)
        else
            pcall(function()
                Library:Notify("Не удалось использовать Рокакаку (проверьте наличие)", 3)
            end)
            task.wait(1)
            continue
        end

        -- ── STEP 2 · BACKGROUND WORTHINESS UPGRADE ──────────────────────────
        -- "делал фоновую прокачку ... что бы я не видел меню тд тп"
        State.CurrentPhase = "UNLOCKING_WORTHINESS"
        pcall(unlockWorthiness)
        task.wait(0.3)
        waitAlive()

        -- ── STEP 3 · USE ROLLING ITEM WITH CURSOR ───────────────────────────
        -- "брал стрелу или то что выбрано в rolling item и использывал ее курсором"
        State.CurrentPhase = "ROLLING"
        local itemOk = useItemWithCursor(Config.ItemType)
        if itemOk then
            task.wait(2.0)
            waitAlive()
        else
            pcall(function()
                Library:Notify("Не удалось использовать " .. Config.ItemType, 3)
            end)
            task.wait(1)
            continue
        end

        -- ── STEP 4 · STAND DETECTION & TARGET CHECK ─────────────────────────
        -- "и так пока не выбьет определенный стенд который выбран в target stand"
        State.CurrentPhase = "DETECTING_STAND"
        local detectStart = tick()
        local newStand    = "None"
        repeat
            task.wait(0.4)
            newStand = detectCurrentStand()
        until (newStand ~= "None" and newStand ~= "Standless") or tick() - detectStart > 6

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
        else
            pcall(function()
                Library:Notify("Выпал стенд: " .. newStand .. " (Нужен: " .. Config.TargetStand .. ")", 3)
            end)
        end

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

-- Защита от повторного запуска
if getgenv().ScytheLoaded then return end

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
    TargetStand          = "Star Platinum",
    ItemType             = "Mysterious Arrow",         -- "Mysterious Arrow" | "Lucky Arrow" | "Rib Cage of the Saint's Corpse"
    ScavengeTimeout      = 10,
    LoopDelay            = 0.5,
    ShopDelay            = 0.6,
    StackCap             = 25,
    ItemContainerPath    = "",                         -- e.g. "Item_Spawns" or "Workspace.Items" (leave empty to scan workspace)
    HopAfterEmptySeconds = 120,
    ServerHopWhenEmpty   = false,

    -- Sequential skill tree nodes to learn after stand reset
    SkillChain = {
        "Agility I",
        "Agility II",
        "Agility III",
        "Worthiness",
    },

    StandPool = {
        -- Arrow & Lucky Arrow pool
        "Star Platinum", "The World", "Crazy Diamond", "Killer Queen",
        "King Crimson", "Gold Experience", "Silver Chariot", "Hermit Purple",
        "Hierophant Green", "Magician's Red", "Purple Haze", "Cream",
        "The Hand", "Sticky Fingers", "Whitesnake", "Aerosmith",
        "Beach Boy", "Six Pistols", "Mr. President", "White Album",
        "Anubis", "Red Hot Chili Pepper", "Stone Free", "Diver Down",
        "Crazy Diamond Requiem",
        -- Rib Cage pool
        "The World (Alternate Universe)", "Dirty Deeds Done Dirt Cheap",
        "Scary Monsters", "Tusk Act 1", "Soft & Wet",
    },

    ItemPriority = {
        ["Lucky Arrow"]                    = 100,
        ["Heart of the Saint's Corpse"]    = 90,
        ["Pelvis of the Saint's Corpse"]   = 90,
        ["Left Arm of the Saint's Corpse"] = 85,
        ["Pure Rokakaka"]                  = 80,
        ["Requiem Arrow"]                  = 75,
        ["Rib Cage of the Saint's Corpse"] = 70,
        ["DIO's Diary"]                    = 65,
        ["Green Baby"]                     = 60,
        ["Rokakaka"]                       = 50,
        ["Mysterious Arrow"]               = 45,
        ["Diamond"]                        = 40,
        ["Steel Ball"]                     = 35,
        ["Quinton's Glove"]                = 30,
        ["Ancient Scroll"]                 = 30,
        ["Zeppeli's Headband"]             = 30,
        ["Clackers"]                       = 30,
        ["Stone Mask"]                     = 25,
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
local TeleportService  = game:GetService("TeleportService")
local HttpService      = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

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

local Modules = {}

local FarmState = {
    Running        = false,
    Status         = "IDLE",
    LastItem       = "—",
    Thread         = nil,
    Tally          = {},
    Blacklist      = {},
    LastItemSeenAt = tick(),
}

local loopThread = nil
local floatToggleGui = nil
local standBannerGui = nil

-- ─────────────────────────────────────────────────────────────────────────────
-- § 4 · UTILITY HELPERS
-- ─────────────────────────────────────────────────────────────────────────────

-- UTF-8 Cyrillic & Latin lowercase helper (gsub-версия)
local function toLowerUtf8(s)
    if type(s) ~= "string" then return "" end
    s = s:lower()
    s = s:gsub("\208([\144-\159])", function(c) return "\208" .. string.char(c:byte() + 32) end)
    s = s:gsub("\208([\160-\175])", function(c) return "\209" .. string.char(c:byte() - 32) end)
    s = s:gsub("\208\129", "\209\145")
    return s
end

local function copyToClipboard(text)
    pcall(function()
        if setclipboard then
            setclipboard(text)
        elseif toclipboard then
            toclipboard(text)
        elseif syn and syn.write_clipboard then
            syn.write_clipboard(text)
        end
    end)
end

local function findDescendantContaining(root, substr)
    local low = toLowerUtf8(substr)
    for _, v in ipairs(root:GetDescendants()) do
        if toLowerUtf8(v.Name):find(low, 1, true) then return v end
        if (v:IsA("TextButton") or v:IsA("TextLabel")) and toLowerUtf8(v.Text):find(low, 1, true) then
            return v
        end
    end
    return nil
end

local function findGuiButton(root, substr)
    local low = toLowerUtf8(substr)
    for _, v in ipairs(root:GetDescendants()) do
        if v:IsA("GuiButton") then
            if toLowerUtf8(v.Name):find(low, 1, true) then return v end
            if v:IsA("TextButton") and toLowerUtf8(v.Text):find(low, 1, true) then return v end
        end
    end
    return nil
end

local function clickWithCursor(guiObj)
    if not guiObj then return false end

    local function getCenter(obj)
        local pos  = obj.AbsolutePosition
        local size = obj.AbsoluteSize
        local cx   = pos.X + size.X / 2
        local cy   = pos.Y + size.Y / 2
        local sg   = obj:FindFirstAncestorOfClass("ScreenGui")
        local gs   = game:GetService("GuiService")
        if sg and not sg.IgnoreGuiInset and gs then
            local inset = gs:GetGuiInset()
            cx = cx + inset.X
            cy = cy + inset.Y
        end
        return cx, cy
    end

    -- 1. firesignal
    if firesignal then
        local ok = pcall(function()
            if guiObj:IsA("GuiButton") then
                firesignal(guiObj.MouseButton1Click)
                firesignal(guiObj.Activated)
            end
        end)
        if ok then return true end
    end

    -- 2. FireMouseButton1Click
    do
        local ok = pcall(function()
            if guiObj.FireMouseButton1Click then
                guiObj:FireMouseButton1Click()
            end
        end)
        if ok then return true end
    end

    -- 3. VIM
    do
        local ok = pcall(function()
            local vim = game:GetService("VirtualInputManager")
            local cx, cy = getCenter(guiObj)
            if cx > 0 and cy > 0 then
                vim:SendMouseMoveEvent(cx, cy, game)
                task.wait(0.02)
                vim:SendMouseButtonEvent(cx, cy, 0, true,  game, 0)
                task.wait(0.03)
                vim:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
            end
        end)
        if ok then return true end
    end

    -- 4. VirtualUser
    do
        local ok = pcall(function()
            local vu = game:GetService("VirtualUser")
            local cx, cy = getCenter(guiObj)
            vu:CaptureController()
            vu:MouseMove(Vector2.new(cx, cy))
            vu:Button1Down(Vector2.new(cx, cy))
            task.wait(0.02)
            vu:Button1Up(Vector2.new(cx, cy))
        end)
        if ok then return true end
    end

    return false
end

local ITEM_GROUPS = {
    arrow = { "mysterious arrow", "таинственная стрела", "таинственн" },
    lucky = { "lucky arrow", "удачная стрела", "удачлив" },
    roka  = { "rokakaka", "рокакака" },
    pure  = { "pure rokakaka", "чистая рокакака", "чистая рока" },
    rib   = { "rib cage", "ребро", "труп", "saint's corpse" },
}

local function itemMatches(name, targetKey)
    if not name or not targetKey then return false end

    local nLow = toLowerUtf8(tostring(name)):gsub("^%s+", ""):gsub("%s+$", "")
    local kLow = toLowerUtf8(tostring(targetKey)):gsub("^%s+", ""):gsub("%s+$", "")

    if nLow == "" or kLow == "" then return false end

    -- Remove "redeemed" prefix (e.g., "Redeemed Mysterious Arrow", "Redeemed Rokakaka")
    nLow = nLow:gsub("^redeemed%s+", ""):gsub("^полученная%s+", "")
    kLow = kLow:gsub("^redeemed%s+", ""):gsub("^полученная%s+", "")

    -- SAFETY GUARDS: prevent cross-tier item matching
    -- Lucky Arrow must never match a Mysterious Arrow query or generic arrow
    if not kLow:find("lucky", 1, true) and nLow:find("lucky", 1, true) then return false end
    if kLow:find("mysterious", 1, true) and nLow:find("lucky", 1, true) then return false end
    -- Pure Rokakaka must never match a plain Rokakaka query
    if not kLow:find("pure", 1, true) and not kLow:find("чистая", 1, true) then
        if nLow:find("pure", 1, true) or nLow:find("чистая", 1, true) then return false end
    end

    local n = nLow
    local k = kLow
    if n:find(k, 1, true) or k:find(n, 1, true) then return true end

    for _, group in pairs(ITEM_GROUPS) do
        local nMatch = false
        local kMatch = false
        for _, alias in ipairs(group) do
            if n:find(alias, 1, true) then nMatch = true end
            if k:find(alias, 1, true) then kMatch = true end
        end
        if nMatch and kMatch then return true end
    end
    return false
end

local function countInBackpack(substring, useHud)
    local count = 0
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") and itemMatches(tool.Name, substring) then
                count = count + 1
            end
        end
    end
    local char = LocalPlayer.Character
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") and itemMatches(tool.Name, substring) then
                count = count + 1
            end
        end
    end
    -- HUD-обход выполняем только если count == 0 и useHud ~= false
    if count == 0 and useHud ~= false then
        local hud = PlayerGui:FindFirstChild("HUD")
        if hud then
            for _, v in ipairs(hud:GetDescendants()) do
                if v:IsA("GuiButton") and v.Visible then
                    local txt = v:IsA("TextButton") and v.Text or ""
                    local nm  = v.Name or ""
                    if itemMatches(txt, substring) or itemMatches(nm, substring) then
                        count = count + 1
                    end
                end
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

local function triggerPrompt(prompt)
    if fireproximityprompt then
        pcall(fireproximityprompt, prompt)
        return
    end
    pcall(function()
        prompt:InputHoldBegin()
        task.wait((prompt.HoldDuration or 0) + 0.1)
        prompt:InputHoldEnd()
    end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- § 5 · ENGINE FUNCTIONS
-- ─────────────────────────────────────────────────────────────────────────────

-- ── Color & Skill Tree Helpers ────────────────────────────────────────────────
local function isWorthinessText(str)
    if not str or type(str) ~= "string" then return false end
    local low = toLowerUtf8(str)
    return low:find("worth", 1, true) or low:find("достоин", 1, true) or low:find("достойн", 1, true)
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

-- ── GUI Visibility & Safe Activation Engine (Ultrawide-Safe) ─────────────────
local function isEffectivelyVisible(guiObj)
    if not guiObj or not guiObj:IsA("GuiObject") then return false end
    if not guiObj.Visible then return false end
    local sz = guiObj.AbsoluteSize
    if sz.X <= 5 or sz.Y <= 5 then return false end

    local current = guiObj.Parent
    while current and current:IsA("GuiObject") do
        if not current.Visible then return false end
        current = current.Parent
    end

    local sg = guiObj:FindFirstAncestorOfClass("ScreenGui")
    if not sg or not sg.Enabled then return false end

    return true
end

local function activateDialogueButton(targetButton)
    if not targetButton or not targetButton:IsA("GuiObject") then return false end

    -- 1. firesignal (самый надёжный на большинстве экзекьюторов)
    if firesignal then
        local ok = pcall(function()
            firesignal(targetButton.Activated)
            firesignal(targetButton.MouseButton1Click)
        end)
        if ok then return true end
    end

    -- 2. FireMouseButton1Click (Synapse X / Wave)
    do
        local ok = pcall(function()
            if targetButton.FireMouseButton1Click then
                targetButton:FireMouseButton1Click()
            end
        end)
        if ok then return true end
    end

    -- 3. VirtualInputManager — центр кнопки без смещений
    do
        local ok = pcall(function()
            local vim = game:GetService("VirtualInputManager")
            local pos  = targetButton.AbsolutePosition
            local size = targetButton.AbsoluteSize
            local cx   = pos.X + size.X / 2
            local cy   = pos.Y + size.Y / 2
            local sg   = targetButton:FindFirstAncestorOfClass("ScreenGui")
            local gs   = game:GetService("GuiService")
            if sg and not sg.IgnoreGuiInset and gs then
                local inset = gs:GetGuiInset()
                cx = cx + inset.X
                cy = cy + inset.Y
            end
            if cx > 0 and cy > 0 then
                vim:SendMouseMoveEvent(cx, cy, game)
                task.wait(0.02)
                vim:SendMouseButtonEvent(cx, cy, 0, true,  game, 0)
                task.wait(0.03)
                vim:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
            end
        end)
        if ok then return true end
    end

    -- 4. VirtualUser fallback
    do
        local ok = pcall(function()
            local vu  = game:GetService("VirtualUser")
            local pos  = targetButton.AbsolutePosition
            local size = targetButton.AbsoluteSize
            local cx   = pos.X + size.X / 2
            local cy   = pos.Y + size.Y / 2
            vu:CaptureController()
            vu:MouseMove(Vector2.new(cx, cy))
            vu:Button1Down(Vector2.new(cx, cy))
            task.wait(0.02)
            vu:Button1Up(Vector2.new(cx, cy))
        end)
        if ok then return true end
    end

    return false
end

-- ── Locate Menu Button with Cursor ───────────────────────────────────────────
local function findMenuButton()
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)

    -- 1. Search by location in bottom-LEFT corner (YBA menu button is at bottom-left in updated UI)
    local bestBtn = nil
    local maxScore = -1
    local hud = PlayerGui:FindFirstChild("HUD")
    local searchRoots = { hud, PlayerGui }

    for _, root in ipairs(searchRoots) do
        if root then
            for _, v in ipairs(root:GetDescendants()) do
                if (v:IsA("GuiButton") or v:IsA("ImageButton") or v:IsA("TextButton")) and isEffectivelyVisible(v) then
                    local sg = v:FindFirstAncestorOfClass("ScreenGui")
                    local sgName = sg and sg.Name:lower() or ""
                    if not sgName:find("obsidian") and not sgName:find("library") and not sgName:find("scythe") then
                        local pos = v.AbsolutePosition
                        local sz = v.AbsoluteSize
                        if pos.X < vp.X * 0.35 and pos.Y > vp.Y * 0.70 and sz.X >= 18 and sz.Y >= 18 and sz.X <= 200 and sz.Y <= 200 then
                            local score = pos.X + pos.Y
                            if score > maxScore then
                                maxScore = score
                                bestBtn = v
                            end
                        end
                    end
                end
            end
            if bestBtn then return bestBtn end
        end
    end

    -- 2. By name / text
    for _, v in ipairs(PlayerGui:GetDescendants()) do
        if (v:IsA("GuiButton") or v:IsA("ImageButton") or v:IsA("TextButton")) and isEffectivelyVisible(v) then
            local n = toLowerUtf8(v.Name)
            local t = toLowerUtf8(v:IsA("TextButton") and v.Text or "")
            if n == "menu" or t == "menu" or n == "меню" or t == "меню"
               or n:find("menubutton") or n:find("openmenu") or n:find("togglemenu") then
                return v
            end
        end
    end

    return nil
end

-- ── 5A · Character Skill Tree Automation (GUI-Only) ───────────────────────────
local function isSkillTreeOpen()
    for _, v in ipairs(PlayerGui:GetDescendants()) do
        if v:IsA("GuiButton") and isEffectivelyVisible(v) then
            local sg = v:FindFirstAncestorOfClass("ScreenGui")
            local sgName = sg and sg.Name:lower() or ""
            if not sgName:find("obsidian") and not sgName:find("library") and not sgName:find("scythe") then
                local t = toLowerUtf8(v:IsA("TextButton") and v.Text or "")
                local n = toLowerUtf8(v.Name)
                if t == "back" or t == "назад" or n == "back" or n == "назад" then
                    return true
                end
            end
        end
    end
    return false
end

local function findCharacterOrSkillButton()
    local searchTerms = {
        "skill tree", "skilltree", "skills", "древо", "дерево", "навыки",
        "character", "персонаж", "stats", "статистика", "player", "профиль"
    }
    for _, v in ipairs(PlayerGui:GetDescendants()) do
        if (v:IsA("GuiButton") or v:IsA("TextButton") or v:IsA("ImageButton")) and isEffectivelyVisible(v) then
            local sg = v:FindFirstAncestorOfClass("ScreenGui")
            local sgName = sg and sg.Name:lower() or ""
            if not sgName:find("obsidian") and not sgName:find("library") and not sgName:find("scythe") then
                local n = toLowerUtf8(v.Name)
                local t = toLowerUtf8(v:IsA("TextButton") and v.Text or "")
                local full = n .. " " .. t
                for _, child in ipairs(v:GetDescendants()) do
                    if child:IsA("TextLabel") then
                        full = full .. " " .. toLowerUtf8(child.Text)
                    end
                end
                for _, term in ipairs(searchTerms) do
                    if full:find(term, 1, true) then
                        return v
                    end
                end
            end
        end
    end
    return nil
end

local function openSkillTree()
    if isSkillTreeOpen() then return true end

    -- 1. Нажатие кнопки Menu в левом нижнем углу
    local menuBtn = findMenuButton()
    if menuBtn then
        activateDialogueButton(menuBtn)
        task.wait(0.35)
    end

    if isSkillTreeOpen() then return true end

    -- 2. Поиск и нажатие кнопки Character / Персонаж / Навыки в открывшемся меню
    local charBtn = findCharacterOrSkillButton()
    if charBtn then
        activateDialogueButton(charBtn)
        task.wait(0.4)
    end

    if isSkillTreeOpen() then return true end

    -- 3. Если требуется переключиться на вкладку Skill Tree внутри меню персонажа
    local skillTab = findCharacterOrSkillButton()
    if skillTab and skillTab ~= charBtn then
        activateDialogueButton(skillTab)
        task.wait(0.4)
    end

    -- 4. Ожидание появления окна Skill Tree (до 1.5 сек)
    for _ = 1, 15 do
        if isSkillTreeOpen() then return true end
        task.wait(0.1)
    end

    return isSkillTreeOpen()
end

local function closeSkillTree()
    local backBtn = nil
    for _, v in ipairs(PlayerGui:GetDescendants()) do
        if v:IsA("GuiButton") and isEffectivelyVisible(v) then
            local sg = v:FindFirstAncestorOfClass("ScreenGui")
            local sgName = sg and sg.Name:lower() or ""
            if not sgName:find("obsidian") and not sgName:find("library") and not sgName:find("scythe") then
                local t = toLowerUtf8(v:IsA("TextButton") and v.Text or "")
                local n = toLowerUtf8(v.Name)
                if t == "back" or t == "назад" or n == "back" or n == "назад" then
                    backBtn = v
                    break
                end
            end
        end
    end

    if backBtn then
        activateDialogueButton(backBtn)
        task.wait(0.25)
    end

    local closeBtn = nil
    for _, v in ipairs(PlayerGui:GetDescendants()) do
        if v:IsA("GuiButton") and isEffectivelyVisible(v) then
            local sg = v:FindFirstAncestorOfClass("ScreenGui")
            local sgName = sg and sg.Name:lower() or ""
            if not sgName:find("obsidian") and not sgName:find("library") and not sgName:find("scythe") then
                local t = toLowerUtf8(v:IsA("TextButton") and v.Text or "")
                local n = toLowerUtf8(v.Name)
                if t == "close" or t == "закрыть" or t == "exit" or n == "close" or n == "exit" then
                    closeBtn = v
                    break
                end
            end
        end
    end
    if closeBtn then
        activateDialogueButton(closeBtn)
        task.wait(0.15)
    end
end

-- ── Smart Item Equipper (Headless Backpack -> Character) ───────────────────────
local function smartEquipItem(itemName)
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end

    -- 1. Check if tool is ALREADY in hand
    local inHand = char:FindFirstChildOfClass("Tool")
    if inHand and itemMatches(inHand.Name, itemName) and not inHand.Name:lower():find("использован") and not inHand.Name:lower():find("used") then
        return inHand
    end

    -- 2. Direct equip from LocalPlayer.Backpack via Humanoid:EquipTool() (Headless)
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") and itemMatches(tool.Name, itemName) and not tool.Name:lower():find("использован") and not tool.Name:lower():find("used") then
                pcall(function()
                    hum:EquipTool(tool)
                end)
                for _ = 1, 10 do
                    task.wait(0.05)
                    local eq = char:FindFirstChildOfClass("Tool")
                    if eq and itemMatches(eq.Name, itemName) then
                        return eq
                    end
                end
                -- Fallback parenting if EquipTool was delayed
                if tool.Parent == bp then
                    pcall(function() tool.Parent = char end)
                    task.wait(0.1)
                end
                local eq = char:FindFirstChildOfClass("Tool")
                if eq and itemMatches(eq.Name, itemName) then
                    return eq
                end
            end
        end
    end

    -- Final verify
    local eqNow = char:FindFirstChildOfClass("Tool")
    if eqNow and itemMatches(eqNow.Name, itemName) then
        return eqNow
    end

    return nil
end

-- Helper: Get combined node text
local function getNodeFullText(nodeObj)
    local full = toLowerUtf8(nodeObj.Name)
    if nodeObj:IsA("TextButton") or nodeObj:IsA("TextLabel") then
        full = full .. " " .. toLowerUtf8(nodeObj.Text)
    end
    for _, child in ipairs(nodeObj:GetDescendants()) do
        if child:IsA("TextLabel") or child:IsA("TextButton") then
            full = full .. " " .. toLowerUtf8(child.Text)
        end
    end
    return full
end

-- Helper: Check if a node text indicates it is already learned
local function isNodeLearned(nodeObj)
    local t = getNodeFullText(nodeObj)
    if t:find("learned", 1, true) or t:find("выучено", 1, true) or t:find("изучено", 1, true)
       or t:find("purchased", 1, true) or t:find("куплено", 1, true) or t:find("max", 1, true) then
        return true
    end
    return false
end

-- Helper: Find a skill tree node matching a name
local function findSkillNode(nodeName)
    local targetLow = toLowerUtf8(nodeName)
    for _, v in ipairs(PlayerGui:GetDescendants()) do
        if (v:IsA("GuiButton") or v:IsA("TextButton") or v:IsA("ImageButton")) and isEffectivelyVisible(v) then
            local sg = v:FindFirstAncestorOfClass("ScreenGui")
            local sgName = sg and sg.Name:lower() or ""
            if not sgName:find("obsidian") and not sgName:find("library") and not sgName:find("scythe") then
                local full = getNodeFullText(v)
                if full:find(targetLow, 1, true) then
                    return v
                end
                -- Also check Russian translations / aliases
                if targetLow:find("worthiness", 1, true) and isWorthinessText(full) then
                    return v
                end
                if targetLow:find("agility", 1, true) and (full:find("ловкость", 1, true) or full:find("agility", 1, true)) then
                    local num = targetLow:match("[ivx0-9]+")
                    if num and full:find(num, 1, true) then
                        return v
                    end
                end
            end
        end
    end
    return nil
end

-- ── 5A · Sequential Skill Upgrade via GUI (Agility I -> Agility II -> Agility III -> Worthiness)
local function upgradeSkillChain()
    State.CurrentPhase = "UNLOCKING_SKILLS"
    pcall(function() Library:Notify("Прокачка древа навыков...", 3) end)

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum or hum.Health <= 0 then
        char = LocalPlayer.CharacterAdded:Wait()
    end
    hum = char:WaitForChild("Humanoid", 5)
    char:WaitForChild("HumanoidRootPart", 5)
    task.wait(0.5)

    local guiOpened = openSkillTree()
    if not guiOpened then
        pcall(function() Library:Notify("Не удалось открыть Skill Tree!", 4) end)
        return false, "failed to open skill tree"
    end
    task.wait(0.4)

    local allSuccess = true
    local failedNode = nil

    for _, nodeName in ipairs(Config.SkillChain) do
        local nodeObj = findSkillNode(nodeName)
        if not nodeObj then
            allSuccess = false
            failedNode = nodeName .. " (нода не найдена на экране)"
            break
        end

        if isNodeLearned(nodeObj) then
            print("[Scythe YBA] Навык " .. nodeName .. " уже изучен.")
        else
            activateDialogueButton(nodeObj)
            task.wait(0.3)

            -- Confirm button click
            for _, v in ipairs(PlayerGui:GetDescendants()) do
                if v:IsA("GuiButton") and isEffectivelyVisible(v) then
                    local sg = v:FindFirstAncestorOfClass("ScreenGui")
                    local sgName = sg and sg.Name:lower() or ""
                    if not sgName:find("obsidian") and not sgName:find("library") and not sgName:find("scythe") then
                        local t = toLowerUtf8(v:IsA("TextButton") and v.Text or "")
                        local n = toLowerUtf8(v.Name)
                        if t:find("confirm", 1, true) or t:find("learn", 1, true) or t:find("upgrade", 1, true) or t:find("buy", 1, true)
                           or t:find("подтверд", 1, true) or t:find("узнать", 1, true) or t:find("купить", 1, true) or t:find("press again", 1, true)
                           or n:find("confirm", 1, true) or n:find("learn", 1, true) or n:find("buy", 1, true) then
                            activateDialogueButton(v)
                            task.wait(0.2)
                            break
                        end
                    end
                end
            end

            task.wait(0.4)
            -- Verify node became learned
            local nodeCheck = findSkillNode(nodeName)
            if not nodeCheck or not isNodeLearned(nodeCheck) then
                allSuccess = false
                failedNode = nodeName .. " (не изучено: не хватает очков навыков или заблокировано)"
                break
            end
            print("[Scythe YBA] Навык " .. nodeName .. " успешно изучен.")
        end
        task.wait(0.2)
    end

    task.wait(0.25)
    closeSkillTree()
    task.wait(0.2)

    if allSuccess then
        State.Worthiness = "LEARNED"
        return true
    else
        State.Worthiness = "FAILED"
        return false, failedNode
    end
end

-- ── 5B · Map Scavenger (Teleport Mode) ─────────────────────────────────────────
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
        local foundAny = false
        for _, name in ipairs(searchNames) do
            local low = toLowerUtf8(name)
            for _, obj in ipairs(workspace:GetDescendants()) do
                if toLowerUtf8(obj.Name):find(low, 1, true) then
                    -- Exclude player characters
                    local inPlayerChar = false
                    for _, plr in ipairs(Players:GetPlayers()) do
                        local pc = plr.Character
                        if pc and obj:IsDescendantOf(pc) then
                            inPlayerChar = true
                            break
                        end
                    end
                    if inPlayerChar then continue end

                    local pos = nil
                    if obj:IsA("BasePart") then
                        pos = obj.Position
                    elseif obj:IsA("Model") and obj.PrimaryPart then
                        pos = obj.PrimaryPart.Position
                    elseif obj:IsA("Model") then
                        local p = obj:FindFirstChildWhichIsA("BasePart")
                        if p then pos = p.Position end
                    end

                    if pos then
                        foundAny = true
                        local beforeCount = countInBackpack(name, false)

                        -- Teleport directly; safe velocity
                        hrp.CFrame = CFrame.new(pos) + Vector3.new(0, 2, 0)
                        hrp.AssemblyLinearVelocity = Vector3.zero
                        task.wait(0.15)

                        local pp = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                        if pp then triggerPrompt(pp) end
                        task.wait(0.35)

                        local afterCount = countInBackpack(name, false)
                        if afterCount > beforeCount then
                            print("[Scythe YBA] Подобрали нужный предмет: " .. name)
                        end

                        local ni = countInBackpack(Config.ItemType)
                        local nr = countInBackpack("Rokakaka")
                        State.ItemCount = ni
                        State.RokaCount = nr
                        if (not missingItem or ni > 0) and (not missingRoka or nr > 0) then
                            return true
                        end
                    end
                end
            end
        end
        if not foundAny then
            task.wait(0.5)
        end
    end
    return false
end

-- ── 5C · Shop Auto-Buyer ──────────────────────────────────────────────────────
local function isEventShopElement(v)
    if not v then return false end
    local name = toLowerUtf8(v.Name)
    local text = (v:IsA("TextButton") or v:IsA("TextLabel")) and toLowerUtf8(v.Text) or ""
    local full = name .. " " .. text
    if full:find("headless", 1, true) or full:find("horseman", 1, true)
       or full:find("candy", 1, true) or full:find("конфет", 1, true)
       or full:find("halloween", 1, true) or full:find("хэллоуин", 1, true) then
        return true
    end
    return false
end

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
            local n = toLowerUtf8(v.Name)
            local t = v:IsA("TextButton") and toLowerUtf8(v.Text) or ""
            if (n:find("shop", 1, true) or t:find("shop", 1, true) or n:find("магазин", 1, true) or t:find("магазин", 1, true))
               and not isEventShopElement(v) then
                shopBtn = v
                break
            end
        end
    end
    if shopBtn then
        clickWithCursor(shopBtn)
        task.wait(Config.ShopDelay * 1.5)
    end

    local function purchaseItem(keyword)
        local initialCount = countInBackpack(keyword, false)
        local targets = { "5x " .. keyword, "1x " .. keyword, keyword }
        local bought = false

        for _, target in ipairs(targets) do
            local low = toLowerUtf8(target)
            for _, v in ipairs(PlayerGui:GetDescendants()) do
                if (v:IsA("TextLabel") or v:IsA("TextButton")) and toLowerUtf8(v.Text):find(low, 1, true) then
                    -- Exclude event shop items
                    if not isEventShopElement(v) and not isEventShopElement(v.Parent) then
                        if v:IsA("TextButton") then
                            local ct = toLowerUtf8(v.Text)
                            if ct:find("buy", 1, true) or ct:find("купить", 1, true) or ct:find("purchase", 1, true) or ct:find(low, 1, true) then
                                clickWithCursor(v)
                                task.wait(Config.ShopDelay)
                                local confirmBtn = findGuiButton(PlayerGui, "Confirm")
                                    or findGuiButton(PlayerGui, "Yes")
                                    or findGuiButton(PlayerGui, "Да")
                                if confirmBtn then
                                    clickWithCursor(confirmBtn)
                                    task.wait(Config.ShopDelay)
                                end
                                bought = true
                                break
                            end
                        end
                        local parent = v.Parent
                        while parent and parent ~= PlayerGui do
                            if isEventShopElement(parent) then break end
                            local btn = parent:FindFirstChildWhichIsA("GuiButton", true)
                            if btn and btn.Visible then
                                clickWithCursor(btn)
                                task.wait(Config.ShopDelay)
                                local confirmBtn = findGuiButton(PlayerGui, "Confirm")
                                    or findGuiButton(PlayerGui, "Yes")
                                    or findGuiButton(PlayerGui, "Да")
                                if confirmBtn then
                                    clickWithCursor(confirmBtn)
                                    task.wait(Config.ShopDelay)
                                end
                                bought = true
                                break
                            end
                            parent = parent.Parent
                        end
                    end
                end
                if bought then break end
            end
            if bought then break end
        end

        task.wait(0.4)
        local newCount = countInBackpack(keyword, false)
        if newCount > initialCount then
            print("[Scythe YBA] Покупка " .. keyword .. " подтверждена ростом рюкзака: " .. initialCount .. " -> " .. newCount)
            return true
        end
        return false
    end

    local successItem = true
    local successRoka = true

    if needItem then
        local kw = Config.ItemType
        if kw:find("Arrow", 1, true) then kw = "Arrow" end
        successItem = purchaseItem(kw)
    end
    if needRoka then
        successRoka = purchaseItem("Rokakaka")
    end

    -- Close shop GUI
    local closeShop = findGuiButton(PlayerGui, "Close") or findGuiButton(PlayerGui, "Закрыть")
    if closeShop then
        clickWithCursor(closeShop)
        task.wait(Config.ShopDelay)
    end

    return successItem and successRoka
end

-- ── 5D · Dialogue Helper & Confirmer ─────────────────────────────────────────
local EXACT_MATCH_TERMS = {
    ["да"] = true, ["нет"] = true, ["ок"] = true, ["ok"] = true,
    ["yes"] = true, ["no"] = true, ["use"] = true, ["eat"] = true,
    ["sure"] = true,
}

local AFFIRMATIVE_TERMS = {
    "да", "съесть", "сьесть", "использовать", "применить", "принять",
    "покушать", "скушать", "подтвердить", "хорошо", "ок", "вперед",
    "yes", "eat", "use", "confirm", "accept", "sure", "ok"
}

local NEGATIVE_TERMS = {
    "нет", "отмена", "не надо", "не хочу", "отказаться", "закрыть", "уйти", "отклонить",
    "no", "cancel", "decline", "refuse", "close", "leave", "don't"
}

local function isAffirmativeDialogueWord(str)
    if not str or type(str) ~= "string" or str == "" then return false end
    local lower = toLowerUtf8(str)
    local clean = lower:gsub("[%p%s]+", "")

    for _, neg in ipairs(NEGATIVE_TERMS) do
        if EXACT_MATCH_TERMS[neg] then
            if clean == neg then return false end
        else
            if clean == neg or lower:find(neg, 1, true) then return false end
        end
    end

    for _, aff in ipairs(AFFIRMATIVE_TERMS) do
        if EXACT_MATCH_TERMS[aff] then
            if clean == aff then return true end
        else
            if clean == aff or lower:find(aff, 1, true) then return true end
        end
    end
    return false
end

local function isDialogueButtonAffirmative(btn)
    if not btn or not isEffectivelyVisible(btn) then return false end
    local txt = btn:IsA("TextButton") and toLowerUtf8(btn.Text) or ""
    local nm  = toLowerUtf8(btn.Name)

    local cleanTxt = txt:gsub("[%p%s]+", "")
    for _, neg in ipairs(NEGATIVE_TERMS) do
        if EXACT_MATCH_TERMS[neg] then
            if cleanTxt == neg or nm == neg then return false end
        else
            if cleanTxt == neg or txt:find(neg, 1, true) or nm:find(neg, 1, true) then return false end
        end
    end

    for _, aff in ipairs(AFFIRMATIVE_TERMS) do
        if EXACT_MATCH_TERMS[aff] then
            if cleanTxt == aff or nm == aff then return true end
        else
            if cleanTxt == aff or txt:find(aff, 1, true) or nm:find(aff, 1, true) then return true end
        end
    end

    for _, child in ipairs(btn:GetDescendants()) do
        if child:IsA("TextLabel") and isEffectivelyVisible(child) then
            if isAffirmativeDialogueWord(child.Text) then return true end
        end
    end

    return false
end

local function fireDialogueRemotes(toolName)
    local char = LocalPlayer.Character
    local re = (char and char:FindFirstChild("RemoteEvent"))
        or game:GetService("ReplicatedStorage"):FindFirstChild("RemoteEvent", true)
    local rf = (char and char:FindFirstChild("RemoteFunction"))
        or game:GetService("ReplicatedStorage"):FindFirstChild("RemoteFunction", true)
    if not re and not rf then return end

    local npcs = {}
    if toolName then
        table.insert(npcs, toolName)
        if itemMatches(toolName, "Rokakaka") then
            table.insert(npcs, "Rokakaka")
            table.insert(npcs, "Roka")
        elseif itemMatches(toolName, "Mysterious Arrow") then
            table.insert(npcs, "Mysterious Arrow")
            table.insert(npcs, "Arrow")
        end
    end

    local dialogueArgs = { "Yes", "Confirm", "True", "Eat", "Use", "Да" }
    for _, npc in ipairs(npcs) do
        for _, arg in ipairs(dialogueArgs) do
            pcall(function()
                if re then
                    re:FireServer("EndDialogue", { ["NPC"] = npc, ["Option"] = arg, ["Dialogue"] = "Dialogue" })
                    re:FireServer("EndDialogue", npc, arg)
                end
                if rf then
                    rf:InvokeServer("EndDialogue", { ["NPC"] = npc, ["Option"] = arg, ["Dialogue"] = "Dialogue" })
                    rf:InvokeServer("EndDialogue", npc, arg)
                end
            end)
        end
    end
end

local function confirmDialogue(toolName)
    local targetButton = nil
    for _, v in ipairs(PlayerGui:GetDescendants()) do
        if v:IsA("GuiButton") and isDialogueButtonAffirmative(v) then
            local sg = v:FindFirstAncestorOfClass("ScreenGui")
            local sgName = sg and sg.Name:lower() or ""
            if not sgName:find("obsidian") and not sgName:find("library") and not sgName:find("scythe") then
                targetButton = v
                break
            end
        end
    end

    local activated = false
    if targetButton then
        activated = activateDialogueButton(targetButton)
        if not activated then
            activated = clickWithCursor(targetButton)
        end
    end

    fireDialogueRemotes(toolName)
    return activated or (targetButton ~= nil)
end

local function useItemHeadless(itemName)
    local char = LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end

    -- 1. Экипировать предмет в руки напрямую из Backpack
    local tool = smartEquipItem(itemName)
    if not tool then
        return false
    end
    task.wait(0.15)

    local inHand = char:FindFirstChildOfClass("Tool")
    if not inHand or not itemMatches(inHand.Name, itemName) then
        return false
    end

    -- 2. Активация инструмента всеми возможными способами
    pcall(function() inHand:Activate() end)
    task.wait(0.05)

    local toolHandle = inHand:FindFirstChild("Handle") or inHand:FindFirstChildWhichIsA("BasePart")
    if toolHandle then
        local cd = toolHandle:FindFirstChildWhichIsA("ClickDetector")
        if cd and fireclickdetector then
            pcall(fireclickdetector, cd)
        end
    end

    -- 3. firesignal на кнопку мыши по экрану
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
        local cx = vp.X / 2
        local cy = vp.Y / 2
        vim:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
        task.wait(0.04)
        vim:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
    end)

    -- 4. Подтверждение диалогового окна съедания / использования
    task.wait(0.3)
    local dialogueConfirmed = false
    local t0 = tick()
    while tick() - t0 < 2.0 do
        if confirmDialogue(inHand.Name) then
            dialogueConfirmed = true
            break
        end
        task.wait(0.1)
    end

    if not dialogueConfirmed then
        fireDialogueRemotes(inHand.Name)
    end

    return true
end

-- ── 5E · Stand Detection ──────────────────────────────────────────────────────
local function detectCurrentStand()
    -- 1. Check PlayerStats (Official YBA data container)
    local pStats = LocalPlayer:FindFirstChild("PlayerStats")
    if pStats then
        local sVal = pStats:FindFirstChild("Stand")
        if sVal and sVal:IsA("StringValue") then
            local val = sVal.Value
            if val and val ~= "" and val ~= "None" and val ~= "Standless" and val ~= "nil" then
                for _, s in ipairs(Config.StandPool) do
                    if toLowerUtf8(val) == toLowerUtf8(s) then
                        return s
                    end
                end
                return val
            else
                return "None"
            end
        end
    end

    -- 2. Check Attributes on Character or Player
    local attrStand = LocalPlayer:GetAttribute("Stand") or (LocalPlayer.Character and LocalPlayer.Character:GetAttribute("Stand"))
    if attrStand and type(attrStand) == "string" and attrStand ~= "" and attrStand ~= "None" and attrStand ~= "Standless" then
        for _, s in ipairs(Config.StandPool) do
            if toLowerUtf8(attrStand) == toLowerUtf8(s) then
                return s
            end
        end
    end

    -- 3. Check for Stand Model inside Character
    local char = LocalPlayer.Character
    if char then
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("Model") and obj.Name ~= char.Name and not obj:IsA("Tool") and not obj:IsA("Accessory") then
                for _, s in ipairs(Config.StandPool) do
                    if toLowerUtf8(obj.Name):find(toLowerUtf8(s), 1, true) then
                        return s
                    end
                end
            end
        end
    end

    -- 4. Check HUD text labels
    local hud = PlayerGui:FindFirstChild("HUD")
    if hud then
        for _, v in ipairs(hud:GetDescendants()) do
            if v:IsA("TextLabel") and v.Visible and isEffectivelyVisible(v) then
                local txt = v.Text
                if txt and txt ~= "" then
                    for _, s in ipairs(Config.StandPool) do
                        if toLowerUtf8(txt) == toLowerUtf8(s) then
                            return s
                        end
                    end
                end
            end
        end
    end

    return "None"
end

local function showStandBanner(standName, targetName, isMatch)
    pcall(function()
        if standBannerGui and standBannerGui.Parent then
            standBannerGui:Destroy()
        end

        standBannerGui = Instance.new("ScreenGui")
        standBannerGui.Name = "Scythe_StandBanner"
        standBannerGui.ResetOnSpawn = false
        standBannerGui.DisplayOrder = 999999
        standBannerGui.Parent = gethui and gethui() or game:GetService("CoreGui")

        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 420, 0, 80)
        frame.Position = UDim2.new(0.5, -210, 0.15, 0)
        frame.BackgroundColor3 = isMatch and Color3.fromRGB(20, 60, 25) or Color3.fromRGB(35, 25, 45)
        frame.BorderSizePixel = 0
        frame.Parent = standBannerGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = frame

        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 2
        stroke.Color = isMatch and Color3.fromRGB(50, 205, 50) or Color3.fromRGB(180, 100, 240)
        stroke.Parent = frame

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0, 32)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.TextSize = 18
        title.TextColor3 = isMatch and Color3.fromRGB(80, 255, 80) or Color3.fromRGB(255, 220, 100)
        title.Text = isMatch and "★ ЦЕЛЕВОЙ СТЕНД ПОЛУЧЕН! ★" or "ВЫПАЛ СТЕНД"
        title.Parent = frame

        local desc = Instance.new("TextLabel")
        desc.Size = UDim2.new(1, 0, 0, 36)
        desc.Position = UDim2.new(0, 0, 0, 34)
        desc.BackgroundTransparency = 1
        desc.Font = Enum.Font.GothamMedium
        desc.TextSize = 16
        desc.TextColor3 = Color3.fromRGB(255, 255, 255)
        desc.Text = string.format("%s (Цель: %s)", tostring(standName), tostring(targetName))
        desc.Parent = frame

        task.delay(isMatch and 10 or 4, function()
            if standBannerGui and standBannerGui.Parent then
                standBannerGui:Destroy()
                standBannerGui = nil
            end
        end)
    end)
end

-- ── 5F · Reroll Loop (Headless Auto-Roll) ────────────────────────────────────
local function runLoop()
    while State.Running do
        waitAlive()

        -- 1. Check current stand right at start of iteration
        local currentStand = detectCurrentStand()
        State.ActiveStand  = currentStand

        if currentStand ~= "None" and currentStand ~= "Standless" and currentStand ~= "" then
            local isMatch = (toLowerUtf8(currentStand)) == (toLowerUtf8(Config.TargetStand))
            if isMatch then
                showStandBanner(currentStand, Config.TargetStand, true)
                State.CurrentPhase = "FINISHED"
                State.Running      = false

                pcall(function()
                    Library:Notify("Целевой стенд уже получен: " .. currentStand, 10)
                end)
                pcall(function()
                    game:GetService("StarterGui"):SetCore("SendNotification", {
                        Title    = "Scythe | YBA",
                        Text     = "Целевой стенд уже получен: " .. currentStand,
                        Duration = 10,
                    })
                end)
                pcall(function()
                    if Library.Toggles and Library.Toggles.AutoRollToggle then
                        Library.Toggles.AutoRollToggle:SetValue(false)
                    end
                end)
                return
            end
        end

        -- 2. Resource check & replenishment (Shop first, Scavenge second)
        do
            local hasStandNow = currentStand ~= "None" and currentStand ~= "Standless" and currentStand ~= ""
            local needItem = countInBackpack(Config.ItemType) == 0
            local needRoka = hasStandNow and countInBackpack("Rokakaka") == 0

            if needItem or needRoka then
                -- Step 1: Buy from shop
                buyFromShop(needItem, needRoka)

                needItem = countInBackpack(Config.ItemType) == 0
                needRoka = hasStandNow and countInBackpack("Rokakaka") == 0

                -- Step 2: Scavenge map if still needed
                if needItem or needRoka then
                    scavengeMap(needItem, needRoka)
                end

                needItem = countInBackpack(Config.ItemType) == 0
                needRoka = hasStandNow and countInBackpack("Rokakaka") == 0

                if needItem or needRoka then
                    pcall(function()
                        Library:Notify("Предупреждение: не удалось получить предметы (магазин и карта пусты)! Пауза 5 сек...", 5)
                    end)
                    task.wait(5)
                    continue
                end
            end
        end

        -- 3. Reset stand with Rokakaka if player has a non-target stand
        local hasStand = (currentStand ~= "None" and currentStand ~= "Standless" and currentStand ~= "")
        local toolInHand = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        local holdingRoka = toolInHand and itemMatches(toolInHand.Name, "Rokakaka")

        if hasStand or holdingRoka then
            State.CurrentPhase = "RESETTING"
            pcall(function()
                Library:Notify("Использование Рокакаки (сброс)...", 3)
            end)

            local eaten = false
            local rokaTries = 0

            while State.Running and not eaten and rokaTries < 4 do
                rokaTries = rokaTries + 1
                local initialChar = LocalPlayer.Character
                local ok = useItemHeadless("Rokakaka")
                if ok then
                    local t0 = tick()
                    while tick() - t0 < 3.5 do
                        local c = LocalPlayer.Character
                        local h = c and c:FindFirstChildOfClass("Humanoid")
                        if c ~= initialChar or not h or h.Health <= 0 then
                            eaten = true
                            break
                        end
                        local curS = detectCurrentStand()
                        if curS == "None" or curS == "Standless" or curS == "" then
                            eaten = true
                            break
                        end
                        task.wait(0.2)
                    end
                end
                if eaten then break end
                task.wait(0.4)
            end

            -- Reset Worthiness state to UNKNOWN after stand reset
            State.Worthiness = "UNKNOWN"

            -- Ensure character is fully alive and respawned after Rokakaka
            waitAlive()
            task.wait(0.8)
        end

        if not State.Running then break end

        -- 4. Sequential Skill Upgrade (Agility I-III -> Worthiness)
        do
            local ok, errReason = upgradeSkillChain()
            if not ok then
                pcall(function()
                    Library:Notify("Авторол остановлен! Не удалось прокачать: " .. tostring(errReason), 8)
                end)
                pcall(function()
                    if Library.Toggles and Library.Toggles.AutoRollToggle then
                        Library.Toggles.AutoRollToggle:SetValue(false)
                    end
                end)
                State.Running = false
                State.CurrentPhase = "IDLE"
                return
            end
        end

        task.wait(0.3)
        waitAlive()

        if not State.Running then break end

        -- 5. Use Rolling Item Headless (Arrow / Rib)
        State.CurrentPhase = "ROLLING"
        pcall(function()
            Library:Notify("Использование " .. tostring(Config.ItemType) .. "...", 3)
        end)

        local arrowUsed = false
        local arrowTries = 0
        while State.Running and not arrowUsed and arrowTries < 3 do
            arrowTries = arrowTries + 1
            local itemOk = useItemHeadless(Config.ItemType)
            if itemOk then
                arrowUsed = true
                break
            else
                task.wait(0.5)
            end
        end

        if not arrowUsed then
            task.wait(0.5)
            continue
        end

        -- Wait for stand animation and spawn
        task.wait(3.5)
        waitAlive()

        if not State.Running then break end

        -- 6. Stand Detection & Target Check
        State.CurrentPhase = "DETECTING_STAND"
        local detectStart = tick()
        local newStand    = "None"
        repeat
            task.wait(0.4)
            newStand = detectCurrentStand()
        until (newStand ~= "None" and newStand ~= "Standless") or tick() - detectStart > 7

        State.ActiveStand = newStand
        local isTarget = newStand ~= "None" and newStand ~= "Standless" and (toLowerUtf8(newStand) == toLowerUtf8(Config.TargetStand))

        -- Write on screen which stand dropped
        showStandBanner(newStand, Config.TargetStand, isTarget)

        if isTarget then
            State.CurrentPhase = "FINISHED"
            State.Running      = false

            pcall(function()
                Library:Notify("Целевой стенд успешно получен: " .. newStand, 10)
            end)
            pcall(function()
                game:GetService("StarterGui"):SetCore("SendNotification", {
                    Title    = "Scythe | YBA",
                    Text     = "Целевой стенд успешно получен: " .. newStand,
                    Duration = 10,
                })
            end)
            pcall(function()
                if Library.Toggles and Library.Toggles.AutoRollToggle then
                    Library.Toggles.AutoRollToggle:SetValue(false)
                end
            end)
            return
        else
            pcall(function()
                Library:Notify("Выпал стенд: " .. newStand .. " (Нужен: " .. Config.TargetStand .. ")", 3)
            end)
        end

        task.wait(Config.LoopDelay or 0.5)
    end

    State.CurrentPhase = "IDLE"
end

-- ─────────────────────────────────────────────────────────────────────────────
-- § 6 · FARM ENGINE
-- ─────────────────────────────────────────────────────────────────────────────

local LowerFarmItems = {}

local function rebuildLowerFarmItems()
    table.clear(LowerFarmItems)
    for key, enabled in pairs(Config.FarmItems) do
        if enabled == true then
            LowerFarmItems[toLowerUtf8(key)] = key
        end
    end
end
rebuildLowerFarmItems()

local function isWanted(name)
    if not name then return false, nil end
    if Config.FarmItems[name] == true then return true, name end
    local lowName = toLowerUtf8(name)
    for lowKey, origKey in pairs(LowerFarmItems) do
        if lowName:find(lowKey, 1, true) then
            return true, origKey
        end
    end
    return false, nil
end

local function getItemPart(obj)
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        if obj.PrimaryPart then return obj.PrimaryPart end
        local p = obj:FindFirstChildWhichIsA("BasePart")
        if p then return p end
    end
    return nil
end

local function getItemContainer()
    if Config.ItemContainerPath and Config.ItemContainerPath ~= "" then
        local current = game
        for part in string.gmatch(Config.ItemContainerPath, "[^%.]+") do
            current = current:FindFirstChild(part)
            if not current then break end
        end
        if current then return current end
    end
    return nil
end

local cachedQueue = {}
local lastScanTime = 0

local function buildItemQueue(forceRescan)
    local now = tick()
    if not forceRescan and (now - lastScanTime < 2) and #cachedQueue > 0 then
        return cachedQueue
    end

    local queue = {}
    local seen  = {}
    local container = getItemContainer()
    local searchRoot = container or workspace

    -- Precompute stack counts to respect Config.StackCap
    local stackCounts = {}
    for itemKey, enabled in pairs(Config.FarmItems) do
        if enabled then
            stackCounts[itemKey] = countInBackpack(itemKey, false)
        end
    end

    for _, obj in ipairs(searchRoot:GetDescendants()) do
        if FarmState.Blacklist[obj] and FarmState.Blacklist[obj] > now then continue end

        -- Skip items inside player characters
        local inPlayerChar = false
        for _, plr in ipairs(Players:GetPlayers()) do
            local pc = plr.Character
            if pc and obj:IsDescendantOf(pc) then
                inPlayerChar = true
                break
            end
        end
        if inPlayerChar then continue end

        if obj:IsA("Model") or obj:IsA("BasePart") then
            -- Пропускаем BasePart, если её родительская Model с тем же именем уже добавлена
            if obj:IsA("BasePart") then
                local par = obj.Parent
                if par and par:IsA("Model") and par.Name == obj.Name and seen[par] then
                    continue
                end
            end
            local wanted, matchedKey = isWanted(obj.Name)
            if wanted then
                -- Check StackCap
                local currentStock = stackCounts[matchedKey] or 0
                if currentStock < (Config.StackCap or 25) then
                    local part = getItemPart(obj)
                    if part then
                        seen[obj] = true
                        local priority = Config.ItemPriority[matchedKey] or 10
                        table.insert(queue, { obj = obj, part = part, key = matchedKey, priority = priority })
                    end
                end
            end
        end
    end

    cachedQueue = queue
    lastScanTime = now
    if #queue > 0 then
        FarmState.LastItemSeenAt = now
    end
    return queue
end

local function pickupItem(entry)
    local char = LocalPlayer.Character
    if not char then return false end
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    if not hrp or not entry.part or not entry.part.Parent then return false end

    FarmState.Status   = "TELEPORTING"
    FarmState.LastItem = entry.key

    local initialCount = countInBackpack(entry.key, false)

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
    end

    local finalCount = countInBackpack(entry.key, false)
    if finalCount > initialCount then
        FarmState.Tally[entry.key] = (FarmState.Tally[entry.key] or 0) + 1
        return true
    else
        -- Item pickup failed or still exists -> blacklist for 30s
        FarmState.Blacklist[entry.obj] = tick() + 30
        return false
    end
end

-- Server hopping function via TeleportService
local function serverHop()
    FarmState.Status = "SERVER HOPPING"
    pcall(function() Library:Notify("Поиск нового сервера...", 5) end)

    local placeId = game.PlaceId
    local serversApi = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Desc&limit=100"
    local req = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

    if req then
        local success, res = pcall(function()
            return req({ Url = serversApi, Method = "GET" })
        end)
        if success and res and res.Body then
            local data = HttpService:JSONDecode(res.Body)
            if data and data.data then
                for _, srv in ipairs(data.data) do
                    if srv.playing and srv.maxPlayers and srv.playing < srv.maxPlayers and srv.id ~= game.JobId then
                        pcall(function()
                            TeleportService:TeleportToPlaceInstance(placeId, srv.id, LocalPlayer)
                        end)
                        task.wait(2)
                        return
                    end
                end
            end
        end
    end

    -- Fallback generic teleport
    pcall(function()
        TeleportService:Teleport(placeId, LocalPlayer)
    end)
end

local containerAddedListener = nil

local function farmLoop()
    local searchRoot = getItemContainer() or workspace
    containerAddedListener = searchRoot.DescendantAdded:Connect(function(desc)
        if isWanted(desc.Name) then
            buildItemQueue(true)
        end
    end)

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
            FarmState.LastItem = "—"
            FarmState.Status = "WAITING RESPAWNS"

            -- Check if map has been empty for too long -> Server Hop
            local emptyElapsed = tick() - FarmState.LastItemSeenAt
            local shouldHop = Config.ServerHopWhenEmpty
            if Library.Toggles and Library.Toggles.ServerHopWhenEmpty then
                shouldHop = Library.Toggles.ServerHopWhenEmpty.Value
            end

            if shouldHop and emptyElapsed > (Config.HopAfterEmptySeconds or 120) then
                serverHop()
                task.wait(5)
                continue
            end

            task.wait(1.5)
        else
            FarmState.LastItemSeenAt = tick()

            -- Sort by priority first (higher = better), then by distance (closer = better)
            local function sortPriorityAndDist(a, b)
                if a.priority ~= b.priority then
                    return a.priority > b.priority
                end
                return (hrp.Position - a.part.Position).Magnitude < (hrp.Position - b.part.Position).Magnitude
            end
            table.sort(queue, sortPriorityAndDist)

            for _, entry in ipairs(queue) do
                if not FarmState.Running then break end
                waitAlive()
                pickupItem(entry)
                task.wait(0.05)
            end
        end
        task.wait(0.3)
    end

    if containerAddedListener then
        pcall(function() containerAddedListener:Disconnect() end)
        containerAddedListener = nil
    end

    FarmState.Status   = "IDLE"
    FarmState.LastItem = "—"
end

Modules.Farm = {
    Start = function()
        if FarmState.Running then return end
        FarmState.Running = true
        FarmState.LastItemSeenAt = tick()
        FarmState.Thread  = task.spawn(farmLoop)
    end,
    Stop = function()
        FarmState.Running = false
        if containerAddedListener then
            pcall(function() containerAddedListener:Disconnect() end)
            containerAddedListener = nil
        end
        if FarmState.Thread then
            pcall(task.cancel, FarmState.Thread)
            FarmState.Thread = nil
        end
    end,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- § 7 · OBSIDIAN WINDOW & TABS
-- ─────────────────────────────────────────────────────────────────────────────

local Window
local uiSuccess, uiErr = pcall(function()
Window = Library:CreateWindow({
    Title          = 'Scythe | YBA Suite',
    Center         = true,
    AutoShow       = true,
    TabPadding     = 8,
    MenuFadeTime   = 0.2,
})
getgenv().ScytheLoaded = true

-- ─────────────────────────────────────────────────────────────────────────────
-- § 7A · PERSISTENT FLOATING "S" TOGGLE BUTTON
-- ─────────────────────────────────────────────────────────────────────────────
pcall(function()
    floatToggleGui = Instance.new("ScreenGui")
    local floatGui = floatToggleGui
    floatGui.Name            = "Scythe_FloatToggle"
    floatGui.ResetOnSpawn    = false
    floatGui.DisplayOrder    = 1000001
    floatGui.IgnoreGuiInset  = true
    floatGui.Parent          = gethui and gethui() or game:GetService("CoreGui")

    local btn = Instance.new("TextButton")
    btn.Name                 = "SToggleBtn"
    btn.Size                 = UDim2.new(0, 36, 0, 36)
    btn.Position             = UDim2.new(0, 10, 0.5, -18)
    btn.BackgroundColor3     = Color3.fromRGB(30, 30, 40)
    btn.BorderSizePixel      = 0
    btn.Text                 = "S"
    btn.Font                 = Enum.Font.GothamBold
    btn.TextSize             = 18
    btn.TextColor3           = Color3.fromRGB(190, 110, 255)
    btn.AutoButtonColor      = false
    btn.Parent               = floatGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius      = UDim.new(0, 6)
    corner.Parent            = btn

    local stroke = Instance.new("UIStroke")
    stroke.Thickness         = 1.5
    stroke.Color             = Color3.fromRGB(190, 110, 255)
    stroke.Parent            = btn

    -- Dragging logic
    local dragging, dragStart, startPos = false, nil, nil
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = btn.Position
        end
    end)
    btn.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                         or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            btn.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    -- Click: toggle Obsidian Library menu
    btn.MouseButton1Click:Connect(function()
        pcall(function() Library:Toggle() end)
    end)
end)

-- ── Tabs ─────────────────────────────────────────────────────────────────────
local Tabs = {
    AutoRoll = Window:AddTab('Auto Roll'),
    Farm     = Window:AddTab('Item Farm'),
    Debug    = Window:AddTab('Debug'),
    Settings = Window:AddTab('Settings'),
}

-- ── Groupboxes: Auto Roll ────────────────────────────────────────────────────
local RollLeft  = Tabs.AutoRoll:AddLeftGroupbox('Stand Rolling Configuration')
local RollRight = Tabs.AutoRoll:AddRightGroupbox('Live Status & Statistics')

-- ── Groupboxes: Item Farm ─────────────────────────────────────────────────────
local FarmLeft  = Tabs.Farm:AddLeftGroupbox('Farm Controls')
local FarmRight = Tabs.Farm:AddRightGroupbox('Item Whitelist')

-- ── Groupboxes: Debug ─────────────────────────────────────────────────────────
local DebugLeft  = Tabs.Debug:AddLeftGroupbox('Inspector Tools')
local DebugRight = Tabs.Debug:AddRightGroupbox('Environment & Stats')

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
            -- Mutual exclusion: stop Farm if it is running
            if FarmState.Running then
                Modules.Farm.Stop()
                pcall(function()
                    if Library.Toggles and Library.Toggles.EnableItemFarm then
                        Library.Toggles.EnableItemFarm:SetValue(false)
                    end
                end)
            end
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

-- Кнопка открытия/закрытия меню (KeyPicker, привязан к Library:Toggle)
RollLeft:AddLabel('Переключатель меню'):AddKeyPicker('UIKeybind', {
    Default = 'RightControl',
    NoUI    = true,
    Text    = 'Menu keybind',
})
Library.ToggleKeybind = Library.Options.UIKeybind

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
            -- Mutual exclusion: stop AutoRoll if it is running
            if State.Running then
                State.Running = false
                if loopThread then
                    pcall(task.cancel, loopThread)
                    loopThread = nil
                end
                State.CurrentPhase = 'IDLE'
                pcall(function()
                    if Library.Toggles and Library.Toggles.AutoRollToggle then
                        Library.Toggles.AutoRollToggle:SetValue(false)
                    end
                end)
            end
            Modules.Farm.Start()
        else
            Modules.Farm.Stop()
        end
    end,
})

FarmLeft:AddToggle('ServerHopWhenEmpty', {
    Text    = 'Server Hop when Empty',
    Default = Config.ServerHopWhenEmpty,
    Tooltip = 'Hops server if map has no items for configured time',
    Callback = function(value)
        Config.ServerHopWhenEmpty = value
    end,
})

FarmLeft:AddDivider()

FarmLeft:AddButton('Scan Map Now', {
    Func = function()
        task.spawn(function()
            local queue = buildItemQueue(true)
            Library:Notify('Сканирование завершено — найдено ' .. #queue .. ' предметов', 4)
        end)
    end,
})

FarmLeft:AddDivider()

-- Farm live status
local LblFarmStatus = FarmLeft:AddLabel('[FARM] IDLE', true)
local LblFarmTally  = FarmLeft:AddLabel('Arrows: 0  Rokas: 0  Ribs: 0  Diamonds: 0', true)

-- ─────────────────────────────────────────────────────────────────────────────
-- § 10A · DEBUG TAB — Inspector Tools
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Dump PlayerGui
DebugLeft:AddButton('Dump PlayerGui', {
    Func = function()
        pcall(function()
            local lines = {}
            table.insert(lines, "=== DUMP PLAYERGUI ===")
            for _, v in ipairs(PlayerGui:GetDescendants()) do
                if (v:IsA("GuiButton") or v:IsA("TextLabel")) and isEffectivelyVisible(v) then
                    local sg = v:FindFirstAncestorOfClass("ScreenGui")
                    local sgName = sg and sg.Name:lower() or ""
                    if not sgName:find("obsidian") and not sgName:find("library") and not sgName:find("scythe") then
                        local text = v:IsA("TextButton") or v:IsA("TextLabel") and v.Text or ""
                        local path = v:GetFullName()
                        table.insert(lines, string.format("[%s] %s | Text: '%s' | Path: %s", v.ClassName, v.Name, text, path))
                    end
                end
            end
            local res = table.concat(lines, "\n")
            print(res)
            copyToClipboard(res)
            Library:Notify("PlayerGui сдамплен в консоль и буфер обмена (" .. #lines .. " строк)", 4)
        end)
    end,
})

-- 2. Dump Skill Tree
DebugLeft:AddButton('Dump Skill Tree', {
    Func = function()
        pcall(function()
            local lines = {}
            table.insert(lines, "=== DUMP SKILL TREE ===")
            local count = 0
            for _, v in ipairs(PlayerGui:GetDescendants()) do
                if (v:IsA("GuiButton") or v:IsA("TextButton") or v:IsA("ImageButton") or v:IsA("TextLabel")) and isEffectivelyVisible(v) then
                    local sg = v:FindFirstAncestorOfClass("ScreenGui")
                    local sgName = sg and sg.Name:lower() or ""
                    if not sgName:find("obsidian") and not sgName:find("library") and not sgName:find("scythe") then
                        local full = getNodeFullText(v)
                        local status = "UNLEARNED / AVAILABLE"
                        if isNodeLearned(v) then
                            status = "LEARNED"
                        elseif full:find("locked", 1, true) or full:find("заблокир", 1, true) then
                            status = "LOCKED"
                        end
                        count = count + 1
                        table.insert(lines, string.format("Node: '%s' [%s] | Status: %s | Text: '%s' | Path: %s", v.Name, v.ClassName, status, full, v:GetFullName()))
                    end
                end
            end
            local res = table.concat(lines, "\n")
            print(res)
            copyToClipboard(res)
            Library:Notify("Skill Tree сдамплен (" .. count .. " элементов)", 4)
        end)
    end,
})

-- 3. Dump Item Containers
DebugLeft:AddButton('Dump Item Containers', {
    Func = function()
        pcall(function()
            local lines = {}
            table.insert(lines, "=== DUMP ITEM CONTAINERS ===")
            local counts = {}
            local parents = {}

            for _, obj in ipairs(workspace:GetDescendants()) do
                local wanted, matchedKey = isWanted(obj.Name)
                if wanted then
                    local par = obj.Parent and obj.Parent:GetFullName() or "No Parent"
                    counts[matchedKey] = (counts[matchedKey] or 0) + 1
                    parents[par] = (parents[par] or 0) + 1
                end
            end

            table.insert(lines, "-- Items found:")
            for k, c in pairs(counts) do
                table.insert(lines, string.format("  %s: %d", k, c))
            end
            table.insert(lines, "-- Parent containers:")
            for p, c in pairs(parents) do
                table.insert(lines, string.format("  [%d items] %s", c, p))
            end

            local res = table.concat(lines, "\n")
            print(res)
            copyToClipboard(res)
            Library:Notify("Item Containers сдамплены в консоль и буфер", 4)
        end)
    end,
})

-- 4. Dump Remotes
DebugRight:AddButton('Dump Remotes', {
    Func = function()
        pcall(function()
            local lines = {}
            table.insert(lines, "=== DUMP REMOTES ===")
            local roots = { game:GetService("ReplicatedStorage"), LocalPlayer.Character }
            for _, r in ipairs(roots) do
                if r then
                    for _, obj in ipairs(r:GetDescendants()) do
                        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                            table.insert(lines, string.format("[%s] %s | Path: %s", obj.ClassName, obj.Name, obj:GetFullName()))
                        end
                    end
                end
            end
            local res = table.concat(lines, "\n")
            print(res)
            copyToClipboard(res)
            Library:Notify("Remotes сдамплены (" .. #lines .. " записей)", 4)
        end)
    end,
})

-- 5. Dump Stand Info
DebugRight:AddButton('Dump Stand Info', {
    Func = function()
        pcall(function()
            local lines = {}
            table.insert(lines, "=== DUMP STAND INFO ===")

            -- PlayerStats
            local pStats = LocalPlayer:FindFirstChild("PlayerStats")
            if pStats then
                table.insert(lines, "-- PlayerStats:")
                for _, child in ipairs(pStats:GetChildren()) do
                    local val = child:IsA("ValueBase") and tostring(child.Value) or child.ClassName
                    table.insert(lines, string.format("  %s = %s", child.Name, val))
                end
            else
                table.insert(lines, "-- PlayerStats: NOT FOUND")
            end

            -- Attributes
            table.insert(lines, "-- Attributes (Player):")
            for k, v in pairs(LocalPlayer:GetAttributes()) do
                table.insert(lines, string.format("  %s = %s", k, tostring(v)))
            end
            if LocalPlayer.Character then
                table.insert(lines, "-- Attributes (Character):")
                for k, v in pairs(LocalPlayer.Character:GetAttributes()) do
                    table.insert(lines, string.format("  %s = %s", k, tostring(v)))
                end
            end

            -- Backpack tools
            table.insert(lines, "-- Backpack Tools:")
            local bp = LocalPlayer:FindFirstChild("Backpack")
            if bp then
                for _, t in ipairs(bp:GetChildren()) do
                    table.insert(lines, string.format("  [%s] %s", t.ClassName, t.Name))
                end
            end

            -- Current detected stand
            table.insert(lines, "Detected Active Stand: " .. detectCurrentStand())

            local res = table.concat(lines, "\n")
            print(res)
            copyToClipboard(res)
            Library:Notify("Stand Info сдамплено в консоль и буфер", 4)
        end)
    end,
})

-- ─────────────────────────────────────────────────────────────────────────────
-- § 11 · ITEM FARM TAB — Whitelist Multi-Dropdown
-- ─────────────────────────────────────────────────────────────────────────────

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

local defaultSelected = {}
for _, item in ipairs(ALL_FARM_ITEMS) do
    if Config.FarmItems[item] == true then
        defaultSelected[item] = true
    end
end

FarmRight:AddDropdown('ItemWhitelist', {
    Multi   = true,
    Text    = 'Collectible Items',
    Values  = ALL_FARM_ITEMS,
    Default = defaultSelected,
    Tooltip = 'Select which items the Farm module will collect',
    Callback = function(selectedMap)
        for _, item in ipairs(ALL_FARM_ITEMS) do
            if Config.FarmItems[item] ~= nil then
                Config.FarmItems[item] = selectedMap[item] == true
            end
        end
        rebuildLowerFarmItems()
    end,
})

-- ─────────────────────────────────────────────────────────────────────────────
-- § 12 · SETTINGS TAB
-- ─────────────────────────────────────────────────────────────────────────────

SettingsLeft:AddLabel('Scavenge Timeout (seconds): ' .. Config.ScavengeTimeout, true)
SettingsLeft:AddLabel('Stack Limit Cap: ' .. (Config.StackCap or 25), true)
SettingsLeft:AddLabel('Empty Hop Timeout: ' .. (Config.HopAfterEmptySeconds or 120) .. 's', true)

SettingsLeft:AddDivider()

-- Watermark
pcall(function()
    Library:SetWatermark('Scythe | YBA Suite  —  v2.0')
    Library:SetWatermarkVisibility(true)
end)

SettingsLeft:AddToggle('WatermarkVisible', {
    Text    = 'Show Watermark',
    Default = true,
    Callback = function(v)
        pcall(function()
            Library:SetWatermarkVisibility(v)
        end)
    end,
})

-- ThemeManager & SaveManager bindings
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'UIKeybind' })
SaveManager:SetFolder('Scythe_YBA')

ThemeManager:ApplyToGroupbox(SettingsRight)
SaveManager:BuildConfigSection(Tabs.Settings)

-- ─────────────────────────────────────────────────────────────────────────────
-- § 13 · STATUS TICKER (0.5s background update loop)
-- ─────────────────────────────────────────────────────────────────────────────

task.spawn(function()
    local prevPhase = ""
    while true do
        -- ── AutoRoll status labels ──────────────────────────────────────────
        local phase = State.CurrentPhase

        if phase == "ROLLING" and prevPhase ~= "ROLLING" then
            sessionRolls = sessionRolls + 1
            pcall(function() LblRollCount:SetText('Rolls this session: ' .. sessionRolls) end)
        end
        prevPhase = phase

        pcall(function()
            LblState:SetText('State: ' .. phase)
        end)

        pcall(function()
            LblStand:SetText('Current Stand: ' .. State.ActiveStand)
        end)

        local ic = 0
        local rc = 0
        pcall(function()
            ic = countInBackpack(Config.ItemType, false)
            rc = countInBackpack("Rokakaka", false)
        end)
        State.ItemCount = ic
        State.RokaCount = rc
        pcall(function()
            LblInventory:SetText(
                string.format('Inventory: Item: %d | Rokas: %d', ic, rc)
            )
        end)

        pcall(function()
            LblWorthiness:SetText('Worthiness: ' .. State.Worthiness)
        end)

        -- ── Farm status labels ─────────────────────────────────────────────
        local farmPhase = FarmState.Status
        local farmLine  = '[FARM] ' .. farmPhase
        if farmPhase == "TELEPORTING" then
            farmLine = '[FARM] Teleporting to ' .. FarmState.LastItem
        end

        pcall(function() LblFarmStatus:SetText(farmLine) end)

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
Library:OnUnload(function()
    State.Running = false
    if loopThread then pcall(task.cancel, loopThread) end
    pcall(Modules.Farm.Stop)
    getgenv().ScytheLoaded = false
    if floatToggleGui and floatToggleGui.Parent then
        pcall(function() floatToggleGui:Destroy() end)
        floatToggleGui = nil
    end
    if standBannerGui and standBannerGui.Parent then
        pcall(function() standBannerGui:Destroy() end)
        standBannerGui = nil
    end
end)

end)

if not uiSuccess then
    getgenv().ScytheLoaded = false
    error("[Scythe YBA] Ошибка инициализации интерфейса: " .. tostring(uiErr))
end

-- Load saved config (must be called after all UI elements are built)
pcall(function()
    SaveManager:LoadAutoloadConfig()
end)

print("[Scythe v2] Obsidian UI загружен. Нажмите RightControl для открытия меню.")

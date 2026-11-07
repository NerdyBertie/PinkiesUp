-- Pinkies Up!
-- A tea-sipping fish pops up with a silly "grats" every time you earn an
-- achievement. Works in Retail and in WoW Forever, where Legacy Challenges
-- use the same achievement system underneath.

local ADDON = ...

---------------------------------------------------------------------------
-- Settings and constants
---------------------------------------------------------------------------
local DB_DEFAULTS = {
    enabled     = true,    -- show the toast
    showPoints  = true,    -- "(10 points)" after the achievement name
    chatLine    = false,   -- also print a grats line in your own chat window
    stepAside   = true,    -- stay quiet if Holiday Herald's own achievement toast is on
}

local MASCOT      = "Interface\\AddOns\\" .. ADDON .. "\\Media\\teatime"
local COLORS      = { main = "E3C27A", accent = "B48CE0", card = "1C1824", border = "B48CE0" }
local GRAY        = "8A8477"
local SHOW_TIME   = 6      -- seconds on screen before fading (hovering pauses it)
local FADE_TIME   = 1.5
local MAX_QUEUED  = 5      -- a big batch at once shows the first few, then "and X more"
local NO_REPEAT   = 6      -- a saying won't come back until this many others have had a turn

-- The fun part. Add as many as you like!
local SAYINGS = {
    "Pinkies up!",
    "You did the thing, and got the stuff!",
    "Boom shakalaka!",
    "Tea-rrific!",
    "Jolly good show!",
    "Splendid, simply splendid!",
    "How delightful!",
    "Crumpets all around!",
    "Oh, I say! Smashing!",
    "Fetch the good china!",
    "Most fin-tastic, darling!",
    "Put the kettle on, we're celebrating!",
    "Bravo! Encore! Huzzah!",
    "Monocle-popping work!",
    "That deserves a second scone!",
    "Simply scale-tacular!",
    "Well, butter my crumpet!",
    "A tip of the top hat to you!",
    "Absolutely jammy!",
    "My gills are all a-flutter!",
    "Look at you go!",
    "Achievement unlocked, dahling!",
    "A triumph of the highest order!",
    "Ding ding! Tea's ready!",
    "Sugar cubes for everyone!",
    "Fancy that!",
    "One lump or two? You earned both!",
    "Steeped in glory!",
    "Earl Grey-t job!",
    "Oolong last! Grats!",
    "Totally fin-omenal!",
    "Hold my teacup!",
    "Hip hip, hooray!",
    "Raise your saucers!",
    "Big brain, bigger hat!",
    "Gold star, with sprinkles!",
    "The cream of the crop, you are!",
    "Nailed it! Pass the biscuits.",
    "Absolutely spiffing!",
    "Quite the feather in your cap!",
}

-- Feats of Strength (worth 0 points) get their own sayings
local FEAT_SAYINGS = {
    "A Feat of Strength! How very posh.",
    "Zero points, infinite bragging rights!",
    "Ooh, a rare one! Frame it!",
    "Fancy! That one's for the trophy shelf.",
}

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------
local function Hex(h)
    return tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255
end

-- Same hue, darker: used for the raised "3D" shadow behind the title
local function DarkHex(h, factor)
    local r, g, b = Hex(h)
    factor = factor or 0.35
    return r * factor, g * factor, b * factor
end

local function Color(hex, text)
    return "|cff" .. hex .. text .. "|r"
end

local function Print(msg)
    print(Color(COLORS.main, "Pinkies Up:") .. " " .. msg)
end

-- Picks a random saying, skipping the last few so they don't repeat back to back
local recent = {}
local function PickSaying(list)
    local choices = {}
    for _, saying in ipairs(list) do
        if not recent[saying] then choices[#choices + 1] = saying end
    end
    if #choices == 0 then choices = list end
    local saying = choices[math.random(#choices)]
    recent[saying] = true
    recent[#recent + 1] = saying
    if #recent > math.min(NO_REPEAT, #SAYINGS - 1) then
        recent[table.remove(recent, 1)] = nil
    end
    return saying
end

-- Holiday Herald (also by NerdyBertie) has its own tea-sipping achievement toast.
-- If both are installed and that one is on, step aside so you don't get two.
local function HeraldIsToasting()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("HolidayHerald")
    return loaded and HolidayHeraldDB and HolidayHeraldDB.achievementToast
end

---------------------------------------------------------------------------
-- The toast
---------------------------------------------------------------------------
local toast = CreateFrame("Button", "PinkiesUpToast", UIParent, "BackdropTemplate")
toast:SetSize(440, 84)
toast:SetFrameStrata("HIGH")
toast:SetClampedToScreen(true)
toast:SetMovable(true)
toast:RegisterForDrag("LeftButton")
toast:RegisterForClicks("LeftButtonUp", "RightButtonUp")
toast:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
toast:SetBackdropColor(Hex(COLORS.card))
toast:SetBackdropBorderColor(Hex(COLORS.border))
toast:Hide()

toast.mascot = toast:CreateTexture(nil, "ARTWORK")
toast.mascot:SetSize(64, 64)
toast.mascot:SetPoint("LEFT", 10, 0)
toast.mascot:SetTexture(MASCOT)

-- The achievement's own icon, small, tucked in the top-right corner
toast.badge = toast:CreateTexture(nil, "ARTWORK")
toast.badge:SetSize(28, 28)
toast.badge:SetPoint("TOPRIGHT", -10, -10)
toast.badge:SetTexCoord(0.08, 0.92, 0.08, 0.92)

-- Two copies of the title, slightly offset, for a little raised "3D" look
toast.titleBack = toast:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
toast.titleBack:SetPoint("TOPLEFT", 86, -18)
toast.title = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
toast.title:SetPoint("TOPLEFT", toast.titleBack, "TOPLEFT", -2, 2)
toast.title:SetTextColor(Hex(COLORS.main))
toast.titleBack:SetTextColor(DarkHex(COLORS.main))

toast.subtitle = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
toast.subtitle:SetPoint("TOPLEFT", toast.titleBack, "BOTTOMLEFT", 0, -8)
toast.subtitle:SetJustifyH("LEFT")
toast.subtitle:SetWordWrap(true)

local function PlaceToast()
    toast:ClearAllPoints()
    local pos = PinkiesUpDB and PinkiesUpDB.position
    if pos then
        toast:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        -- A little lower than Holiday Herald's holiday toasts, so the two never overlap
        toast:SetPoint("TOP", UIParent, "TOP", 0, -240)
    end
end

local function ResetPosition()
    PinkiesUpDB.position = nil
    PlaceToast()
end

-- Queue: several achievements at once take turns instead of piling up
local queue, showing, overflow = {}, false, 0
local timeLeft, fading = 0, false
local ShowNext

local function FinishToast()
    toast:Hide()
    toast:SetAlpha(1)
    showing, fading = false, false
    ShowNext()
end

local function Display(t)
    showing, fading = true, false
    toast.current = t
    toast.title:SetText(t.title)
    toast.titleBack:SetText(t.title)
    toast.subtitle:SetText(t.subtitle)
    toast.badge:SetTexture(t.icon)
    toast.badge:SetShown(t.icon ~= nil)

    -- Grow the toast for long titles so nothing gets cut off
    local width = math.max(440, toast.title:GetStringWidth() + 86 + 50)
    toast:SetWidth(width)
    toast.subtitle:SetWidth(width - 86 - 20)
    toast:SetHeight(math.max(84, 18 + toast.title:GetStringHeight() + 8 + toast.subtitle:GetStringHeight() + 18))

    toast:SetAlpha(1)
    toast:Show()
    timeLeft = t.duration or SHOW_TIME
end

function ShowNext()
    if showing then return end
    if #queue > 0 then
        Display(table.remove(queue, 1))
    elseif overflow > 0 then
        local count = overflow
        overflow = 0
        Display({
            title = "And " .. count .. " more! Goodness!",
            subtitle = "Open your achievements to see them all.",
            duration = 4,
        })
    end
end

local function Queue(t)
    if #queue >= MAX_QUEUED then
        overflow = overflow + 1
        return
    end
    queue[#queue + 1] = t
    ShowNext()
end

-- Countdown, paused while the mouse is over the toast so you can click it
toast:SetScript("OnUpdate", function(self, elapsed)
    if self:IsMouseOver() and not fading then return end
    timeLeft = timeLeft - elapsed
    if timeLeft <= 0 then
        if not fading then
            fading = true
            timeLeft = FADE_TIME
        else
            FinishToast()
            return
        end
    end
    if fading then self:SetAlpha(math.max(0, timeLeft / FADE_TIME)) end
end)

-- Click: open the achievement. Shift-click: link it in chat. Right-click: dismiss.
toast:SetScript("OnClick", function(self, button)
    if self.dragged then          -- letting go after a drag isn't a click
        self.dragged = false
        return
    end
    local id = self.current and self.current.achievementID
    if button == "RightButton" then
        FinishToast()
        return
    end
    if not id then return end
    if IsModifiedClick("CHATLINK") and GetAchievementLink then
        local link = GetAchievementLink(id)
        if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
        return
    end
    -- The achievement window is load-on-demand; this is skipped quietly where it doesn't exist
    pcall(function()
        if not AchievementFrame and C_AddOns and C_AddOns.LoadAddOn then
            C_AddOns.LoadAddOn("Blizzard_AchievementUI")
        end
        if OpenAchievementFrameToAchievement then
            OpenAchievementFrameToAchievement(id)
        end
    end)
end)

toast:SetScript("OnEnter", function(self)
    if not (self.current and self.current.achievementID) then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Pinkies Up!", Hex(COLORS.main))
    GameTooltip:AddLine("Click: open this achievement", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Shift-click: link it in chat", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Drag: move the toast", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: dismiss", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
toast:SetScript("OnLeave", function() GameTooltip:Hide() end)

toast:SetScript("OnDragStart", function(self)
    self.dragged = true
    self:StartMoving()
end)
toast:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    PinkiesUpDB.position = { point = point, relPoint = relPoint, x = x, y = y }
end)

---------------------------------------------------------------------------
-- Celebrating
---------------------------------------------------------------------------
local function Celebrate(achievementID, isTest)
    if not isTest then
        if not PinkiesUpDB.enabled then return end
        if PinkiesUpDB.stepAside and HeraldIsToasting() then return end
    end

    local name, points, icon, isGuild
    if GetAchievementInfo then
        local info = { pcall(GetAchievementInfo, achievementID) }
        if info[1] then
            name, points, icon, isGuild = info[3], info[4], info[11], info[13]
        end
    end
    if not name then
        if not isTest then return end
        name, points, icon, achievementID = "A Very Fancy Test Achievement", 10, nil, nil
    end

    local title = (points == 0) and PickSaying(FEAT_SAYINGS) or PickSaying(SAYINGS)
    local subtitle = name
    if isGuild then subtitle = "Your guild earned: " .. name end
    if PinkiesUpDB.showPoints and points and points > 0 then
        subtitle = subtitle .. Color(GRAY, "  (" .. points .. " points)")
    end

    Queue({
        title = title,
        subtitle = subtitle,
        icon = icon,
        achievementID = achievementID,
    })

    if PinkiesUpDB.chatLine and not isTest then
        local link = (GetAchievementLink and achievementID and GetAchievementLink(achievementID)) or name
        Print(title .. " " .. link)
    end
end

---------------------------------------------------------------------------
-- Settings panel (Options > AddOns > NerdyBertie > Pinkies Up!)
---------------------------------------------------------------------------
local settingsCategory

-- Shared "NerdyBertie" heading: whichever NerdyBertie addon loads first creates it.
-- Every NerdyBertie addon carries this same function, the same list, and the
-- same Media/workshop.tga image, so the page looks the same whoever builds it.
local WORKSHOP_ADDONS = {
    { name = "HandyNotes: Dive Bar Front Crawl",   folder = "HandyNotes_DiveBarCrawl" },
    { name = "HandyNotes: Seeking the Soulstones", folder = "HandyNotes_SeekingTheSoulstones" },
    { name = "ItemWatch",                          folder = "ItemWatch" },
    { name = "Boomkin Buff Watcher",               folder = "BoomkinBuffWatcher" },
    { name = "Holiday Herald",                     folder = "HolidayHerald" },
    { name = "Pinkies Up!",                        folder = "PinkiesUp" },
}

local function GetBrandCategory()
    if NerdyBertie_SettingsCategory then return NerdyBertie_SettingsCategory end
    local panel = CreateFrame("Frame")

    local mascot = panel:CreateTexture(nil, "ARTWORK")
    mascot:SetSize(80, 80)
    mascot:SetPoint("TOPLEFT", 16, -16)
    mascot:SetTexture("Interface\\AddOns\\" .. ADDON .. "\\Media\\workshop")

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    heading:SetPoint("TOPLEFT", mascot, "TOPRIGHT", 14, -10)
    heading:SetText("NerdyBertie's Addon Workshop")

    local presents = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    presents:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -6)
    presents:SetText("presents...")

    local blurb = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    blurb:SetPoint("TOPLEFT", mascot, "BOTTOMLEFT", 0, -16)
    blurb:SetWidth(560)
    blurb:SetJustifyH("LEFT")
    blurb:SetText("Addons for quality of life improvements. If you'd like to check out my other addons, here's the list:")

    local lines = {}
    for i, addon in ipairs(WORKSHOP_ADDONS) do
        local line = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        line:SetPoint("TOPLEFT", (i == 1) and blurb or lines[i - 1], "BOTTOMLEFT", (i == 1) and 12 or 0, (i == 1) and -12 or -6)
        lines[i] = line
        line.addon = addon
    end

    local footer = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    footer:SetPoint("TOPLEFT", lines[#lines], "BOTTOMLEFT", -12, -16)
    footer:SetWidth(560)
    footer:SetJustifyH("LEFT")
    footer:SetText("Find them all on CurseForge, Wago, and WoWInterface. Pick an installed one from the list on the left to see its settings.")

    -- Fill in the list, with "installed" marks. This runs right away, and again
    -- every time the page is shown, since other addons may load after this one.
    local function RefreshList()
        for i, line in ipairs(lines) do
            local loaded = C_AddOns and C_AddOns.IsAddOnLoaded(line.addon.folder)
            line:SetText(i .. ". " .. line.addon.name
                .. (loaded and "  |cff33ff33(installed)|r" or ""))
        end
    end
    RefreshList()
    panel:SetScript("OnShow", RefreshList)
    -- Start hidden so the first time the page is opened counts as "shown"
    panel:Hide()

    local category = Settings.RegisterCanvasLayoutCategory(panel, "NerdyBertie")
    Settings.RegisterAddOnCategory(category)
    NerdyBertie_SettingsCategory = category
    return category
end

local function BuildSettings()
    local category, layout = Settings.RegisterVerticalLayoutSubcategory(GetBrandCategory(), "Pinkies Up!")
    settingsCategory = category

    local function Checkbox(key, label, tooltip)
        local setting = Settings.RegisterAddOnSetting(category, "PinkiesUp_" .. key, key,
            PinkiesUpDB, type(DB_DEFAULTS[key]), label, DB_DEFAULTS[key])
        Settings.CreateCheckbox(category, setting, tooltip)
    end
    local function Button(label, buttonText, onClick, tooltip)
        layout:AddInitializer(CreateSettingsButtonInitializer(label, buttonText, onClick, tooltip, true))
    end

    Checkbox("enabled", "Grats toast for every achievement",
        "The tea-sipping fish pops up with a silly saying whenever you earn an achievement (or a Legacy Challenge in WoW Forever).")
    Checkbox("showPoints", "Show the points on the toast",
        "Adds the achievement's points after its name, like \"(10 points)\".")
    Checkbox("chatLine", "Also say grats in my chat window",
        "Prints the saying and a link to the achievement in your own chat window. Only you can see it.")
    Checkbox("stepAside", "Stay quiet if Holiday Herald's toast is on",
        "Holiday Herald has its own achievement toast. With this on, Pinkies Up! steps aside while that one is turned on, so you never get two toasts for one achievement.")
    Button("Try it out", "Show a test toast", function() Celebrate(6, true) end,
        "Shows a toast right now, so you can see it and drag it where you like.")
    Button("Toast position", "Reset position", ResetPosition,
        "Moves the toast back to its starting spot near the top of the screen.")
end

local function SetUpSettings()
    -- If the settings system is missing or different, slash commands still work
    if not (Settings and Settings.RegisterVerticalLayoutSubcategory) then return end
    local ok, err = pcall(BuildSettings)
    if not ok then Print("settings page couldn't be built (" .. tostring(err) .. ")") end
end

local function OpenSettings()
    if settingsCategory and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(settingsCategory:GetID())
    else
        Print("type /pinkies test to see a toast, or /pinkies reset to move it back.")
    end
end

---------------------------------------------------------------------------
-- Addon compartment (the little puzzle-piece menu by the minimap)
-- These must be true globals: the .toc refers to them by name
---------------------------------------------------------------------------
function PinkiesUp_OnAddonCompartmentClick(_, button)
    if button == "RightButton" then Celebrate(6, true) else OpenSettings() end
end

function PinkiesUp_OnAddonCompartmentEnter(_, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:AddLine("Pinkies Up!", Hex(COLORS.main))
    GameTooltip:AddLine("Left-click: open settings", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: show a test toast", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

function PinkiesUp_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        PinkiesUpDB = PinkiesUpDB or {}
        for key, value in pairs(DB_DEFAULTS) do
            if PinkiesUpDB[key] == nil then PinkiesUpDB[key] = value end
        end
        PlaceToast()
        SetUpSettings()
        self:RegisterEvent("ACHIEVEMENT_EARNED")
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "ACHIEVEMENT_EARNED" then
        Celebrate(arg1)
    end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
SLASH_PINKIESUP1 = "/pinkies"
SLASH_PINKIESUP2 = "/pinkiesup"
SlashCmdList.PINKIESUP = function(msg)
    local cmd = strtrim((msg or ""):lower())
    if cmd == "" or cmd == "options" or cmd == "settings" then
        OpenSettings()
    elseif cmd == "test" then
        Celebrate(6, true)       -- "Level 10" in Retail; a pretend one anywhere it doesn't exist
    elseif cmd == "reset" then
        ResetPosition()
        Print("toast moved back to its starting spot.")
    elseif cmd == "on" or cmd == "off" then
        PinkiesUpDB.enabled = (cmd == "on")
        Print("achievement toasts " .. (PinkiesUpDB.enabled and "on." or "off."))
    else
        Print("commands: /pinkies (settings), /pinkies test, /pinkies reset, /pinkies on, /pinkies off")
    end
end

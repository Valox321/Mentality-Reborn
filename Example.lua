local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Valox321/Mentality-Reborn/refs/heads/main/Libary.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/Valox321/Mentality-Reborn/refs/heads/main/SaveManager.lua"))()

-- // Window Configuration
local Window = Library:Window({
    Name = "Mentality Reborn",
    SubName = "Example Template",
    Logo = "120959262762131"
})

-- // Keybind List (Visible when keybinds are active)
local KeybindList = Library:KeybindList("Active Keybinds")

-- // Categories & Pages
Window:Category("Combat & Movement")
local MainPage = Window:Page({Name = "Main", Icon = "house"})
local MovementPage = Window:Page({Name = "Movement", Icon = "108839695397679"})

Window:Category("Visuals")
local ESPPage = Window:Page({Name = "ESP", Icon = "100050851789190"})
local WorldPage = Window:Page({Name = "World", Icon = "123944728972740"})

Window:Category("Utilities & Settings")
local MiscPage = Window:Page({Name = "Misc", Icon = "103180437044643"})
local SettingsPage = Window:Page({Name = "Settings", Icon = "122669828593160"})

-- // SaveManager Setup  (Obsidian-compatible API)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()                        -- skip theme flags from configs
SaveManager:SetIgnoreIndexes({ "MenuBind" })          -- skip menu keybind
SaveManager:SetFolder("MentalityReborn")                 -- root folder
-- SaveManager:SetSubFolder("specific-place")            -- optional: per-place subfolder
SaveManager:BuildConfigSection(SettingsPage)

-- // --- Settings Customization ---
local StyleSection = SettingsPage:Section({Name = "UI Theme & Style", Side = 2})

StyleSection:Slider({
    Name = "Corner Roundness",
    Flag = "UI_CornerRoundness",
    Min = 0,
    Max = 30,
    Default = 16,
    Suffix = "px",
    Decimals = 1,
    Callback = function(Value)
        Library:SetCornerRadius(Value)
    end
})

-- // --- Main Page ---
local CombatSection = MainPage:Section({Name = "Combat", Side = 1})

CombatSection:Toggle({
    Name = "Kill Aura",
    Flag = "KillAura_Enabled",
    Default = false,
    Callback = function(Value)
        print("Kill Aura:", Value)
    end
})

CombatSection:Slider({
    Name = "Aura Range",
    Flag = "KillAura_Range",
    Min = 1,
    Max = 50,
    Default = 15,
    Suffix = " studs",
    Decimals = 1,
    Callback = function(Value)
        print("Aura Range:", Value)
    end
})

-- // --- Movement Page ---
local SpeedSection = MovementPage:Section({Name = "Speed & Jump", Side = 1})

local WalkSpeedToggle = SpeedSection:Toggle({
    Name = "WalkSpeed Hack",
    Flag = "WalkSpeed_Enabled",
    Default = false,
    Callback = function(Value)
        print("WalkSpeed:", Value)
    end
})

-- Nested Settings for the Toggle
local SpeedSettings = WalkSpeedToggle:Settings(200)
SpeedSettings:Slider({
    Name = "Speed Value",
    Flag = "WalkSpeed_Value",
    Min = 16,
    Max = 250,
    Default = 16,
    Callback = function(Value)
        print("New Speed:", Value)
    end
})

SpeedSection:Keybind({
    Name = "Toggle Speed",
    Flag = "WalkSpeed_Keybind",
    Default = Enum.KeyCode.V,
    Callback = function()
        Library.Flags["WalkSpeed_Enabled"] = not Library.Flags["WalkSpeed_Enabled"]
        -- Note: You might need to call a Set function if the library doesn't auto-update UI
    end
})

-- // --- ESP Page ---
local ESPSection = ESPPage:Section({Name = "Player ESP", Side = 1})

ESPSection:Toggle({
    Name = "Enable ESP",
    Flag = "ESP_Enabled",
    Default = false,
    Callback = function(Value)
        print("ESP:", Value)
    end
})

ESPSection:Label("ESP Color"):Colorpicker({
    Name = "Color",
    Flag = "ESP_Color",
    Default = Color3.fromRGB(0, 195, 255),
    Callback = function(Value)
        print("ESP Color changed")
    end
})

-- // --- Global Chat Example ---
local ChatSection = MiscPage:Section({Name = "Chat", Side = 1})
local GlobalChat = MiscPage:GlobalChat(1)

GlobalChat:OnMessageSendPressed(function()
    local msg = GlobalChat:GetTypedMessage()
    if msg ~= "" then
        GlobalChat:SendMessage("rbxassetid://78993485446406", "Local Player", msg, true)
    end
end)

-- // --- Watermark (Draggable Label) ---
local Watermark = Library:AddDraggableLabel("Mentality Reborn", "shield")

local FrameTimer = tick()
local FrameCounter = 0
local FPS = 60
local WatermarkConnection = Library:Connect(game:GetService("RunService").RenderStepped, function()
    FrameCounter = FrameCounter + 1
    if (tick() - FrameTimer) >= 1 then
        FPS = FrameCounter
        FrameTimer = tick()
        FrameCounter = 0
    end
    Watermark:SetText(string.format("Mentality Reborn | %d FPS | %d ms",
        math.floor(FPS),
        math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
    ))
end)

-- // --- Notifications & Init ---
Library:Notification({
    Title = "Mentality Reborn",
    Description = "Script successfully loaded!",
    Duration = 5,
    Icon = "73789337996373"
})

-- // Autoload Configuration
SaveManager:LoadAutoloadConfig()
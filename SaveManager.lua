-- SaveManager (Obsidian-compatible API)
-- Adapted for custom Library (uses Library.Flags + Library.SetFlags)

local cloneref = (cloneref or clonereference or function(instance) return instance end)
local HttpService = cloneref(game:GetService("HttpService"))

local SaveManager = {} do
    SaveManager.Folder    = "ObsidianLibSettings"
    SaveManager.SubFolder = ""
    SaveManager.Ignore    = {}
    SaveManager.Library   = nil

    -- ─── Helpers ──────────────────────────────────────────────────────────────
    local function _isfolder(p)  local ok, r = pcall(isfolder, p)  return ok and r  end
    local function _isfile(p)    local ok, r = pcall(isfile, p)    return ok and r  end
    local function _listfiles(p) local ok, r = pcall(listfiles, p) return ok and r or {} end

    -- ─── API: Library ─────────────────────────────────────────────────────────
    function SaveManager:SetLibrary(library)
        self.Library = library
    end

    function SaveManager:IgnoreThemeSettings()
        self:SetIgnoreIndexes({
            -- Built-in theme flags your library might expose
            "BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor",
            "ThemeManager_ThemeList", "ThemeManager_CustomThemeList", "ThemeManager_CustomThemeName",
        })
    end

    function SaveManager:SetIgnoreIndexes(list)
        for _, key in pairs(list) do
            self.Ignore[key] = true
        end
    end

    -- ─── API: Folders ─────────────────────────────────────────────────────────
    function SaveManager:CheckSubFolder(createFolder)
        if type(self.SubFolder) ~= "string" or self.SubFolder == "" then return false end
        if createFolder then
            local path = self.Folder .. "/settings/" .. self.SubFolder
            if not _isfolder(path) then makefolder(path) end
        end
        return true
    end

    function SaveManager:GetPaths()
        local paths = {}

        -- Build every parent segment of Folder
        local parts = self.Folder:split("/")
        for i = 1, #parts do
            local p = table.concat(parts, "/", 1, i)
            if not table.find(paths, p) then paths[#paths + 1] = p end
        end

        paths[#paths + 1] = self.Folder .. "/themes"
        paths[#paths + 1] = self.Folder .. "/settings"

        if self:CheckSubFolder(false) then
            local sub = self.Folder .. "/settings/" .. self.SubFolder
            parts = sub:split("/")
            for i = 1, #parts do
                local p = table.concat(parts, "/", 1, i)
                if not table.find(paths, p) then paths[#paths + 1] = p end
            end
        end

        return paths
    end

    function SaveManager:BuildFolderTree()
        for _, path in ipairs(self:GetPaths()) do
            if not _isfolder(path) then makefolder(path) end
        end
    end

    function SaveManager:CheckFolderTree()
        if not _isfolder(self.Folder) then
            self:BuildFolderTree()
            task.wait(0.1)
        end
    end

    function SaveManager:SetFolder(folder)
        self.Folder = folder
        self:BuildFolderTree()
    end

    function SaveManager:SetSubFolder(folder)
        self.SubFolder = folder
        self:BuildFolderTree()
    end

    -- ─── Internal path helpers ─────────────────────────────────────────────────
    function SaveManager:_configPath(name)
        if self:CheckSubFolder(true) then
            return self.Folder .. "/settings/" .. self.SubFolder .. "/" .. name .. ".json"
        end
        return self.Folder .. "/settings/" .. name .. ".json"
    end

    function SaveManager:_autoloadPath()
        if self:CheckSubFolder(true) then
            return self.Folder .. "/settings/" .. self.SubFolder .. "/autoload.txt"
        end
        return self.Folder .. "/settings/autoload.txt"
    end

    -- ─── API: Save / Load / Delete ────────────────────────────────────────────
    function SaveManager:Save(name)
        if not name or name == "" then return false, "no config file is selected" end
        self:CheckFolderTree()

        local lib = self.Library
        if not lib then return false, "library not set" end

        -- Collect all flag values, skip ignored
        local data = {}
        for flag, value in pairs(lib.Flags) do
            if not self.Ignore[flag] then
                if type(value) == "table" and value.Key then
                    -- Keybind value
                    data[flag] = { Key = tostring(value.Key), Mode = value.Mode }
                elseif type(value) == "table" and value.Color then
                    -- Colorpicker value
                    data[flag] = { Color = "#" .. (value.HexValue or "ffffff"), Alpha = value.Alpha }
                else
                    data[flag] = value
                end
            end
        end

        local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
        if not ok then return false, "failed to encode data" end

        local writeOk = pcall(writefile, self:_configPath(name), encoded)
        if not writeOk then return false, "failed to write file" end

        return true
    end

    function SaveManager:Load(name)
        if not name or name == "" then return false, "no config file is selected" end
        self:CheckFolderTree()

        local path = self:_configPath(name)
        if not _isfile(path) then return false, "invalid file" end

        local ok, decoded = pcall(function()
            return HttpService:JSONDecode(readfile(path))
        end)
        if not ok then return false, "decode error" end

        local lib = self.Library
        for flag, value in pairs(decoded) do
            if not self.Ignore[flag] then
                local setter = lib.SetFlags[flag]
                if setter then
                    task.spawn(function()
                        if type(value) == "table" and value.Key then
                            setter(value)
                        elseif type(value) == "table" and value.Color then
                            setter(value.Color, value.Alpha)
                        else
                            setter(value)
                        end
                    end)
                end
            end
        end

        return true
    end

    function SaveManager:Delete(name)
        if not name or name == "" then return false, "no config file is selected" end

        local path = self:_configPath(name)
        if not _isfile(path) then return false, "invalid file" end

        local ok = pcall(delfile, path)
        if not ok then return false, "delete file error" end

        return true
    end

    function SaveManager:RefreshConfigList()
        local success, data = pcall(function()
            self:CheckFolderTree()

            local folder = self:CheckSubFolder(true)
                and (self.Folder .. "/settings/" .. self.SubFolder)
                or  (self.Folder .. "/settings")

            local list = _listfiles(folder)
            local out  = {}

            for _, file in ipairs(list) do
                if file:sub(-5) == ".json" then
                    -- Extract filename without path prefix and extension
                    local pos   = file:find(".json", 1, true)
                    local start = pos
                    local char  = file:sub(pos, pos)
                    while char ~= "/" and char ~= "\\" and char ~= "" do
                        pos  = pos - 1
                        char = file:sub(pos, pos)
                    end
                    if char == "/" or char == "\\" then
                        table.insert(out, file:sub(pos + 1, start - 1))
                    end
                end
            end

            return out
        end)

        if not success then
            if self.Library then
                self.Library:Notification({ Title = "SaveManager", Description = "Failed to load config list: " .. tostring(data), Duration = 3 })
            else
                warn("SaveManager: Failed to load config list: " .. tostring(data))
            end
            return {}
        end

        return data
    end

    -- ─── API: Autoload ────────────────────────────────────────────────────────
    function SaveManager:GetAutoloadConfig()
        self:CheckFolderTree()
        local path = self:_autoloadPath()
        if _isfile(path) then
            local ok, name = pcall(readfile, path)
            if not ok then return "none" end
            name = tostring(name)
            return (name == "" and "none" or name)
        end
        return "none"
    end

    function SaveManager:LoadAutoloadConfig()
        self:CheckFolderTree()
        local path = self:_autoloadPath()
        if _isfile(path) then
            local ok, name = pcall(readfile, path)
            if not ok then
                self.Library:Notification({ Title = "SaveManager", Description = "Failed to read autoload config", Duration = 3 })
                return
            end

            local success, err = self:Load(name)
            if not success then
                self.Library:Notification({ Title = "SaveManager", Description = "Failed to load autoload: " .. tostring(err), Duration = 3 })
                return
            end

            self.Library:Notification({ Title = "SaveManager", Description = string.format('Auto loaded config "%s"', name), Duration = 3 })
        end
    end

    function SaveManager:SaveAutoloadConfig(name)
        self:CheckFolderTree()
        local ok = pcall(writefile, self:_autoloadPath(), name)
        if not ok then return false, "write file error" end
        return true, ""
    end

    function SaveManager:DeleteAutoLoadConfig()
        self:CheckFolderTree()
        local ok = pcall(delfile, self:_autoloadPath())
        if not ok then return false, "delete file error" end
        return true, ""
    end

    -- ─── API: BuildConfigSection ──────────────────────────────────────────────
    function SaveManager:BuildConfigSection(tab)
        assert(self.Library, "SaveManager: Must call SetLibrary() before BuildConfigSection()")

        local section = tab:Section({ Name = "Configuration", Side = 2 })

        -- Config name input
        section:Textbox({
            Flag        = "SaveManager_ConfigName",
            Placeholder = "Config name",
            Callback    = function(v) self.ConfigName = v end,
        })

        section:Button({
            Name     = "Create config",
            Callback = function()
                local name = self.ConfigName or ""
                if name:gsub(" ", "") == "" then
                    self.Library:Notification({ Title = "SaveManager", Description = "Invalid config name (empty)", Duration = 2 })
                    return
                end
                local success, err = self:Save(name)
                if not success then
                    self.Library:Notification({ Title = "SaveManager", Description = "Failed to create: " .. tostring(err), Duration = 3 })
                    return
                end
                self.Library:Notification({ Title = "SaveManager", Description = string.format('Created config "%s"', name), Duration = 3 })
                if self.ConfigListDropdown then
                    self.ConfigListDropdown:Refresh(self:RefreshConfigList())
                end
            end,
        })

        -- Config list dropdown
        self.ConfigListDropdown = section:Listbox({
            Flag     = "SaveManager_ConfigList",
            Items    = self:RefreshConfigList(),
            Callback = function(v) self.SelectedConfig = v end,
        })

        section:Button({
            Name     = "Load config",
            Callback = function()
                local name = self.SelectedConfig
                if not name then
                    self.Library:Notification({ Title = "SaveManager", Description = "No config selected", Duration = 2 })
                    return
                end
                local success, err = self:Load(name)
                if not success then
                    self.Library:Notification({ Title = "SaveManager", Description = "Failed to load: " .. tostring(err), Duration = 3 })
                    return
                end
                self.Library:Notification({ Title = "SaveManager", Description = string.format('Loaded config "%s"', name), Duration = 3 })
            end,
        })

        section:Button({
            Name     = "Overwrite config",
            Callback = function()
                local name = self.SelectedConfig
                if not name then
                    self.Library:Notification({ Title = "SaveManager", Description = "No config selected", Duration = 2 })
                    return
                end
                local success, err = self:Save(name)
                if not success then
                    self.Library:Notification({ Title = "SaveManager", Description = "Failed to overwrite: " .. tostring(err), Duration = 3 })
                    return
                end
                self.Library:Notification({ Title = "SaveManager", Description = string.format('Overwrote config "%s"', name), Duration = 3 })
            end,
        })

        section:Button({
            Name     = "Delete config",
            Callback = function()
                local name = self.SelectedConfig
                if not name then
                    self.Library:Notification({ Title = "SaveManager", Description = "No config selected", Duration = 2 })
                    return
                end
                local success, err = self:Delete(name)
                if not success then
                    self.Library:Notification({ Title = "SaveManager", Description = "Failed to delete: " .. tostring(err), Duration = 3 })
                    return
                end
                self.Library:Notification({ Title = "SaveManager", Description = string.format('Deleted config "%s"', name), Duration = 3 })
                self.SelectedConfig = nil
                if self.ConfigListDropdown then
                    self.ConfigListDropdown:Refresh(self:RefreshConfigList())
                end
            end,
        })

        section:Button({
            Name     = "Refresh list",
            Callback = function()
                if self.ConfigListDropdown then
                    self.ConfigListDropdown:Refresh(self:RefreshConfigList())
                end
            end,
        })

        section:MultiButton({
            Buttons = {
                {
                    Name     = "Set as autoload",
                    Callback = function()
                        local name = self.SelectedConfig
                        if not name then
                            self.Library:Notification({ Title = "SaveManager", Description = "No config selected", Duration = 2 })
                            return
                        end
                        local success, err = self:SaveAutoloadConfig(name)
                        if not success then
                            self.Library:Notification({ Title = "SaveManager", Description = "Failed to set autoload: " .. tostring(err), Duration = 3 })
                            return
                        end
                        self.Library:Notification({ Title = "SaveManager", Description = string.format('Set "%s" as autoload', name), Duration = 3 })
                        if self.AutoloadLabel then
                            self.AutoloadLabel:SetText("Current autoload config: " .. name)
                        end
                    end,
                },
                {
                    Name     = "Reset autoload",
                    Callback = function()
                        local success, err = self:DeleteAutoLoadConfig()
                        if not success then
                            self.Library:Notification({ Title = "SaveManager", Description = "Failed to reset autoload: " .. tostring(err), Duration = 3 })
                            return
                        end
                        self.Library:Notification({ Title = "SaveManager", Description = "Autoload reset to none", Duration = 3 })
                        if self.AutoloadLabel then
                            self.AutoloadLabel:SetText("Current autoload config: none")
                        end
                    end,
                }
            }
        })

        -- Shows the currently active autoload config
        self.AutoloadLabel = section:Label("Current autoload config: " .. self:GetAutoloadConfig())

        -- Ignore the UI-only flags so they are never saved to config
        self:SetIgnoreIndexes({ "SaveManager_ConfigList", "SaveManager_ConfigName" })
    end

    -- Build folders on require
    SaveManager:BuildFolderTree()
end

return SaveManager

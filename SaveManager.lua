local cloneref = (cloneref or clonereference or function(instance: any) return instance end)
local HttpService = cloneref(game:GetService("HttpService"))

local SaveManager = {} do
    SaveManager.Folder = "MentalityReborn"
    SaveManager.SubFolder = "Configs"
    SaveManager.Ignore = {}
    SaveManager.Library = nil

    function SaveManager:SetLibrary(library)
        self.Library = library
    end

    function SaveManager:SetFolder(folder)
        self.Folder = folder
        if not isfolder(folder) then makefolder(folder) end
    end

    function SaveManager:SetSubFolder(folder)
        self.SubFolder = folder
        local path = self.Folder .. "/" .. folder
        if not isfolder(path) then makefolder(path) end
    end

    function SaveManager:IgnoreThemeSettings()
        self:SetIgnoreIndexes({ 
            "BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor", -- Basic theme elements
            "ThemeManager_ThemeList", "ThemeManager_CustomThemeList", "ThemeManager_CustomThemeName"
        })
    end

    function SaveManager:SetIgnoreIndexes(list)
        for _, key in pairs(list) do
            table.insert(self.Ignore, key)
        end
    end

    function SaveManager:Save(name)
        if not name or name == "" then return false, "No name provided" end
        local fullPath = self.Folder .. "/" .. self.SubFolder .. "/" .. name .. ".json"
        local data = self.Library:GetConfig()
        writefile(fullPath, data)
        return true
    end

    function SaveManager:Load(name)
        if not name or name == "" then return false, "No name provided" end
        local fullPath = self.Folder .. "/" .. self.SubFolder .. "/" .. name .. ".json"
        if not isfile(fullPath) then return false, "File does not exist" end
        local data = readfile(fullPath)
        self.Library:LoadConfig(data)
        return true
    end

    function SaveManager:Delete(name)
        if not name or name == "" then return false, "No name provided" end
        local fullPath = self.Folder .. "/" .. self.SubFolder .. "/" .. name .. ".json"
        if isfile(fullPath) then 
            delfile(fullPath)
            return true
        end
        return false, "File does not exist"
    end

    function SaveManager:RefreshConfigList()
        local list = {}
        local path = self.Folder .. "/" .. self.SubFolder
        if isfolder(path) then
            for _, file in listfiles(path) do
                if file:sub(-5) == ".json" then
                    local name = file:match("([^/\\]+)%.json$")
                    if name then table.insert(list, name) end
                end
            end
        end
        return list
    end

    function SaveManager:GetAutoloadConfig()
        local path = self.Folder .. "/autoload.txt"
        if isfile(path) then
            return readfile(path)
        end
        return "none"
    end

    function SaveManager:SaveAutoloadConfig(name)
        local path = self.Folder .. "/autoload.txt"
        writefile(path, name or "none")
    end

    function SaveManager:LoadAutoloadConfig()
        task.spawn(function()
            local autoload = self:GetAutoloadConfig()
            if autoload ~= "none" then
                self:Load(autoload)
            end
        end)
    end

    function SaveManager:BuildConfigSection(tab)
        assert(self.Library, "Must set SaveManager.Library")
        local section = tab:Section({Name = "Configuration", Side = 2})

        section:Textbox({
            Flag = "SaveManager_ConfigName",
            Placeholder = "Config name",
            Callback = function(v) self.ConfigName = v end
        })

        section:Button({
            Name = "Create config",
            Callback = function()
                local name = self.ConfigName
                if not name or name:gsub(" ", "") == "" then
                    return self.Library:Notification({Title = "Error", Description = "Invalid config name", Duration = 3})
                end
                local success, err = self:Save(name)
                if success then
                    self.Library:Notification({Title = "Success", Description = "Created config " .. name, Duration = 3})
                    self:RefreshDropdown()
                else
                    self.Library:Notification({Title = "Error", Description = err, Duration = 3})
                end
            end
        })

        section:Label("Config list")
        self.ConfigListDropdown = section:Listbox({
            Flag = "SaveManager_ConfigList",
            Items = self:RefreshConfigList(),
            Callback = function(v) self.SelectedConfig = v end
        })

        section:Button({
            Name = "Load config",
            Callback = function()
                if self.SelectedConfig then
                    local success, err = self:Load(self.SelectedConfig)
                    if success then
                        self.Library:Notification({Title = "Success", Description = "Loaded config " .. self.SelectedConfig, Duration = 3})
                    else
                        self.Library:Notification({Title = "Error", Description = err, Duration = 3})
                    end
                else
                    self.Library:Notification({Title = "Error", Description = "No config selected", Duration = 3})
                end
            end
        })

        section:Button({
            Name = "Overwrite config",
            Callback = function()
                if self.SelectedConfig then
                    local success, err = self:Save(self.SelectedConfig)
                    if success then
                        self.Library:Notification({Title = "Success", Description = "Overwrote config " .. self.SelectedConfig, Duration = 3})
                    else
                        self.Library:Notification({Title = "Error", Description = err, Duration = 3})
                    end
                else
                    self.Library:Notification({Title = "Error", Description = "No config selected", Duration = 3})
                end
            end
        })

        section:Button({
            Name = "Delete config",
            Callback = function()
                if self.SelectedConfig then
                    self:Delete(self.SelectedConfig)
                    self:RefreshDropdown()
                    self.Library:Notification({Title = "Success", Description = "Deleted config " .. self.SelectedConfig, Duration = 3})
                else
                    self.Library:Notification({Title = "Error", Description = "No config selected", Duration = 3})
                end
            end
        })

        section:Button({
            Name = "Refresh list",
            Callback = function()
                self:RefreshDropdown()
            end
        })

        self.AutoloadLabel = section:Label("Current autoload config: " .. self:GetAutoloadConfig())

        section:Button({
            Name = "Set as autoload",
            Callback = function()
                if self.SelectedConfig then
                    self:SaveAutoloadConfig(self.SelectedConfig)
                    self.AutoloadLabel:SetText("Current autoload config: " .. self.SelectedConfig)
                    self.Library:Notification({Title = "Success", Description = "Set " .. self.SelectedConfig .. " as autoload", Duration = 3})
                else
                    self.Library:Notification({Title = "Error", Description = "No config selected", Duration = 3})
                end
            end
        })

        section:Button({
            Name = "Reset autoload",
            Callback = function()
                self:SaveAutoloadConfig("none")
                self.AutoloadLabel:SetText("Current autoload config: none")
                self.Library:Notification({Title = "Success", Description = "Reset autoload config", Duration = 3})
            end
        })
    end

    function SaveManager:RefreshDropdown()
        if self.ConfigListDropdown then
            self.ConfigListDropdown:Refresh(self:RefreshConfigList())
        end
    end
end

return SaveManager

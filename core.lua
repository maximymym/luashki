
---------------------------------------------------------
----------------Auto generated code block----------------
---------------------------------------------------------

do
    local searchers = package.searchers or package.loaders
    local origin_seacher = searchers[2]
    searchers[2] = function(path)
        local files =
        {
------------------------
-- Modules part begin --
------------------------

["main.information"] = function()
--------------------
-- Module: 'main.information'
--------------------
local information = {}

information.MenuTarget = "main"

local data = require("api.data.profile")

function information.OnLoad(menu)
    local infoMenu = menu:Create("Profile")

    local profileSection = infoMenu:Create("User Data")
    profileSection:Label("Nickname: " .. (data.Profile.nickname or user_info.username))

    local subscriptionSection = infoMenu:Create("Subscription")
    if data.HasActiveSubscription() then
        subscriptionSection:Label("Status: Active ✅")
        subscriptionSection:Label(data.GetSubscriptionTimeLeftString())
    else
        subscriptionSection:Label("Status: Expired ❌")
    end

    local telegramSection = infoMenu:Create("Telegram")
    if data.Profile.telegramId then
        telegramSection:Label("Linked ✅")
        telegramSection:Label("Telegram ID: " .. data.Profile.telegramId)
    else
        telegramSection:Label("Not linked ❌")
    end
end

return information
end,

["main.telegram"] = function()
--------------------
-- Module: 'main.telegram'
--------------------
local telegramLink = {}
local api = require("api.request.http")
local data = require("api.data.profile")

telegramLink.MenuTarget = "main"

local uniqueId = tostring(user_info.user_id)

local function requestToken(callback)
    api.post("/generate-token", { uniqueId = uniqueId }, function(result)
        callback(result and result.token)
    end)
end

local function unlinkTelegram(callback)
    api.post("/unlink-telegram", { uniqueId = uniqueId }, function(result, statusCode)
        if statusCode == 200 then
            data.Profile.telegramId = nil
            callback(true)
        else
            callback(false)
        end
    end)
end


function telegramLink.OnLoad(menu)
    local telegramMenu = menu:Create("Telegram")
    local telegramGroup = telegramMenu:Create("Link")

    if data.Profile.telegramId then
        telegramGroup:Label("Your Telegram ID: " .. data.Profile.telegramId)

        telegramGroup:Button("Unlink account", function()
            unlinkTelegram(function()
                Engine.ReloadScriptSystem()
            end)
        end)

    else
        local inputBox = telegramGroup:Input("Your token", "Press 'Get token'")
        inputBox:Set("Press 'Get token'")

        local infoLabel = telegramGroup:Label("Copy and send token to telegram bot! @umbrella_marketplace_bot")
        infoLabel:Visible(false);
        telegramGroup:Button("Get token", function()
            requestToken(function(token)
                inputBox:Set(token or "Failed to get token ❌")
                infoLabel:Visible(true)
            end)
        end)

        telegramGroup:Button("Reload menu", function()
            Engine.ReloadScriptSystem()
        end)
    end
end


return telegramLink
end,

["api.data.profile"] = function()
--------------------
-- Module: 'api.data.profile'
--------------------
local data = {}

data.Profile = {
    id = nil,
    nickname = nil,
    uniqueId = nil,
    subscriptionUntil = nil,
    telegramId = nil,
    scripts = {} 
}

function data.GetSubscriptionExpiryTimestamp()
    if data.Profile.subscriptionUntil then
        local pattern = "(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)"
        local y, m, d, h, min, s = data.Profile.subscriptionUntil:match(pattern)
        if y then
            return os.time({
                year = tonumber(y),
                month = tonumber(m),
                day = tonumber(d),
                hour = tonumber(h),
                min = tonumber(min),
                sec = tonumber(s)
            })
        end
    end
    return 0
end

function data.GetSubscriptionTimeLeftString()
    if data.Profile.subscriptionUntil then
        local pattern = "(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)"
        local year, month, day, hour, min, sec = data.Profile.subscriptionUntil:match(pattern)
        if year then
            local expiry = os.time({
                year = tonumber(year),
                month = tonumber(month),
                day = tonumber(day),
                hour = tonumber(hour),
                min = tonumber(min),
                sec = tonumber(sec)
            })

            local now = os.time()
            local secondsLeft = expiry - now
            local days = math.floor(secondsLeft / (60 * 60 * 24))
            local hours = math.floor((secondsLeft % (60 * 60 * 24)) / (60 * 60))
            local minutes = math.floor((secondsLeft % (60 * 60)) / 60)

            if secondsLeft > 0 then
                if days > 0 then
                    return "Expires in " .. days .. " day" .. (days ~= 1 and "s" or "")
                elseif hours > 0 then
                    return "Expires in " .. hours .. " hour" .. (hours ~= 1 and "s" or "")
                elseif minutes > 0 then
                    return "Expires in " .. minutes .. " minute" .. (minutes ~= 1 and "s" or "")
                else
                    return "Expires in less than a minute"
                end
            else
                days = math.abs(days)
                return "Expired " .. days .. " day" .. (days ~= 1 and "s" or "") .. " ago"
            end
        end
    end
    return "Expiration date unknown"
end



function data.HasActiveSubscription()
    return data.GetSubscriptionExpiryTimestamp() > os.time()
end


return data

end,

["api.outside.auth"] = function()
--------------------
-- Module: 'api.outside.auth'
--------------------
local auth = {}
auth.Priority = 999

local data = require("api.data.profile")
local api = require("api.request.http")

local nickname = user_info.username
local uniqueId = user_info.user_id

local scriptsFolder = "scripts"
local keepFile = "afkbot.lua"

local reloadFlagFile = "scripts/.reload_done.txt"
local needReload = false

local function hasReloaded()
    local file = io.open(reloadFlagFile, "r")
    if file then
        file:close()
        return true
    else
        return false
    end
end

local function setReloaded()
    local file = io.open(reloadFlagFile, "w+")
    if file then
        file:write("ok")
        file:close()
    end
end

local function clearReloaded()
    os.remove(reloadFlagFile)
end

local function saveFileIfNotExists(fileName, content)
    if fileName == keepFile then return end

    local path = scriptsFolder .. "/" .. fileName
    local file = io.open(path, "r")
    if file then
        file:close()
        return
    end

    file = io.open(path, "w+")
    if file then
        file:write(content)
        file:close()
        needReload = true
    end
end

local function downloadScripts(onFinished)
    if not data.Profile.scripts then
        if onFinished then onFinished() end
        return
    end

    local pending = #data.Profile.scripts
    if pending == 0 then
        if onFinished then onFinished() end
        return
    end

    for _, scriptName in ipairs(data.Profile.scripts) do
        if scriptName ~= keepFile then
            api.get("/lua?name=" .. scriptName:gsub(" ", "%%20"), function(scriptData, code)
                if code == 200 and scriptData then
                    saveFileIfNotExists(scriptData.name, scriptData.content)
                end
                pending = pending - 1
                if pending == 0 and onFinished then
                    onFinished()
                end
            end)
        else
            pending = pending - 1
            if pending == 0 and onFinished then
                onFinished()
            end
        end
    end
end

local function login(onSuccess)
    api.post("/login", { nickname = nickname, uniqueId = uniqueId }, function(user)
        if user and type(user) == "table" then
            data.Profile.id = user.id
            data.Profile.nickname = user.nickname
            data.Profile.uniqueId = user.uniqueId
            data.Profile.subscriptionUntil = user.subscriptionUntil
            data.Profile.telegramId = user.telegramId
            data.Profile.scripts = user.scripts or {}
        else
            data.Profile = {}
        end

        downloadScripts(function()
            if needReload then
                setReloaded()
                Engine.ReloadScriptSystem()
            else
                if hasReloaded() then
                    clearReloaded()
                end
                if onSuccess then
                    onSuccess()
                end
            end
        end)
    end)
end

function auth.OnLoad(callback)
    if not hasReloaded() then
        login(callback)
    else
        if callback then
            callback()
        end
    end
end

return auth
end,

["api.request.http"] = function()
--------------------
-- Module: 'api.request.http'
--------------------
local json = require("assets.JSON")

local apiUrl = "http://87.120.166.6:8081/api"
local headers = { ["Content-Type"] = "application/json" }

local function post(path, payload, callback)
    HTTP.Request("POST", apiUrl .. path, {
        headers = headers,
        data = json:encode(payload)
    }, function(response)
        if response then
            local decoded = nil
            if response.response and response.response ~= "" then
                decoded = json:decode(response.response)
            end
            callback(decoded, response.code or 0)
        else
            callback(nil, 0)
        end
    end, path)
end

local function get(path, callback)
    HTTP.Request("GET", apiUrl .. path, {
        headers = headers
    }, function(response)
        if response then
            local decoded = nil
            if response.response and response.response ~= "" then
                decoded = json:decode(response.response)
            end
            callback(decoded, response.code or 0)
        else
            callback(nil, 0)
        end
    end, path)
end

return {
    post = post,
    get = get
}

end,

["core.loader"] = function()
--------------------
-- Module: 'core.loader'
--------------------
local loader = {}

local function getPriority(mod)
    return type(mod.Priority) == "number" and mod.Priority or 0
end

function loader.loadModules(mods)
    table.sort(mods, function(a, b)
        return getPriority(a) > getPriority(b)
    end)

    for _, mod in ipairs(mods) do
        if mod and mod.OnLoad then
            if mod.Menu then
                mod.OnLoad(mod.Menu)
            else
                mod.OnLoad()
            end
        end
    end
end


function loader.updateModules(mods)
    for _, mod in ipairs(mods) do
        if mod.OnUpdate then
            mod.OnUpdate()
        end
    end
end

return loader

end,

----------------------
-- Modules part end --
----------------------
        }
        if files[path] then
            return files[path]
        else
            return origin_seacher(path)
        end
    end
end
---------------------------------------------------------
----------------Auto generated code block----------------
---------------------------------------------------------
local loader = require("core.loader")
local data = require("api.data.profile")
local auth = require("api.outside.auth")

local infoMenu = Menu.Create("Scripts", "Marketplace", "Main")
infoMenu:Icon("\u{f013}")

local menus = {
    main = infoMenu
}

local modules = {}

local function loadModules(folder, list)
    for _, name in ipairs(list) do
        local mod = require(folder .. "." .. name)
        local menu = menus[mod.MenuTarget or "main"] or menus.main
        mod.Menu = menu
        table.insert(modules, mod)
    end
end

local reloadFlagFile = "scripts/.reload_done.txt"

local function hasReloaded()
    local file = io.open(reloadFlagFile, "r")
    if file then
        file:close()
        return true
    else
        return false
    end
end

local function clearReloaded()
    os.remove(reloadFlagFile)
end

loadModules("main", { "information", "telegram" })

if hasReloaded() then
    clearReloaded()
    auth.OnLoad(function()
        loader.loadModules(modules)
    end)
else
    auth.OnLoad(function()
        loader.loadModules(modules)
    end)
end

return {
    OnUpdate = function()
        loader.updateModules(modules)
    end
}
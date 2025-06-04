-- File: C:/Users/aleks/Downloads/scripts1/voice_chat.lua

local script = {}
local HTTP   = HTTP   -- встроенный HTTP-модуль

-- Адреса локального координатора
local CONTROL_URL    = "http://127.0.0.1:5000/control"
local TRANSCRIPT_URL = "http://127.0.0.1:5000/transcript"

-- Получаем список доступных каналов
local channels = Chat.GetChannels() or {"say_team","say"}

-- UI
local tab   = Menu.Create("Scripts", "Voice Chat", "🎙")
local group = tab:Create("Options"):Create("Main")
local ui    = {}
ui.voiceBind = group:Bind("Voice Record (hold)", Enum.ButtonCode.KEY_5, "🎤")
ui.channel   = group:Combo("Chat Channel", channels, 1, "📣")
ui.debug     = group:Switch("Enable Debug", false, "🐞")

-- Внутреннее состояние
local lastRec      = false    -- предыдущее состояние бинда
local lastText     = ""       -- последний отправленный текст
local lastPollTime = 0        -- время последнего опроса

-- Утилита для отладки
local function dbg(msg)
    if not ui.debug:Get() then return end
    Log.Write("[VoiceChat] " .. msg)
    Chat.Print("VoiceChat", msg)
end

-- Callback для /control
local function onControl(resp)
    dbg(("Control ← code=%s"):format(tostring(resp.code)))
end

-- Callback для /transcript
local function onTranscript(resp)
    dbg(("Transcript ← code=%s body=\"%s\"")
        :format(tostring(resp.code), tostring(resp.response)))
    if tonumber(resp.code) == 200 and resp.response ~= "" then
        local text = resp.response
        if text ~= lastText then
            lastText = text
            local chanName = channels[ ui.channel:Get() ]
            dbg(("Chat.Print → channel=%s text=\"%s\"")
                :format(chanName, text))
            Chat.Say(chanName, text)
        end
    end
end

function script.OnUpdate()
    -- 1) Управление записью
    local rec = ui.voiceBind:IsDown()
    if rec ~= lastRec then
        lastRec = rec
        local url  = CONTROL_URL .. "?record=" .. tostring(rec)
        local sent = HTTP.Request("GET", url, {}, onControl, "")
        dbg(("HTTP.Request(control) → sent=%s url=%s")
            :format(tostring(sent), url))
    end

    -- 2) Периодический опрос транскрипта (каждые 0.5 с)
    local now = GameRules.GetGameTime()
    if now - lastPollTime >= 0.5 then
        lastPollTime = now
        local sent2 = HTTP.Request("GET", TRANSCRIPT_URL, {}, onTranscript, "")
        dbg(("HTTP.Request(transcript) → sent=%s url=%s")
            :format(tostring(sent2), TRANSCRIPT_URL))
    end
end

return script

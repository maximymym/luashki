-- game_events.lua
-- лёгкая обёртка над движковым AddListener, чтобы можно было писать Event.AddListener(name, callback)

-- 1) сохраняем оригинальную функцию, которую движок вам даёт «из коробки»
local _engineAddListener = Event.AddListener

local Event = {}
-- сюда будут складываться ваши коллбэки: Event._callbacks["dota_player_pick_hero"] = {fn1, fn2, ...}
Event._callbacks = {}

--- Подписаться на событие с коллбэком
-- @param name string — имя события
-- @param callback function — function(evt:CEvent)
function Event.AddListener(name, callback)
    assert(type(name) == "string",   "Event.AddListener: name must be string")
    assert(type(callback) == "function","Event.AddListener: callback must be function")

    -- если первый раз подписываемся на это имя — «прокидываем» регистрацию в движок
    if not Event._callbacks[name] then
        Event._callbacks[name] = {}
        _engineAddListener(name)
    end

    -- сохраняем ваш callback
    table.insert(Event._callbacks[name], callback)
end

-- 2) эту функцию движок будет вызывать при каждом ивенте
--    (имя ивента + сам CEvent)
--    вы можете проверить, действительно ли вам нужно реагировать на него
function OnEvent(name, evt)
    local handlers = Event._callbacks[name]
    if not handlers then return end

    for _, fn in ipairs(handlers) do
        -- вызываем ваш коллбэк
        fn(evt)
    end
end

-- 3) прокси для всех методов CEvent
function Event.IsReliable(evt)     return evt:IsReliable()   end
function Event.IsLocal(evt)        return evt:IsLocal()      end
function Event.IsEmpty(evt)        return evt:IsEmpty()      end
function Event.GetBool(evt, fld)   return evt:GetBool(fld)   end
function Event.GetInt(evt, fld)    return evt:GetInt(fld)    end
function Event.GetUint64(evt, fld) return evt:GetUint64(fld) end
function Event.GetFloat(evt, fld)  return evt:GetFloat(fld)  end
function Event.GetString(evt, fld) return evt:GetString(fld) end

return Event

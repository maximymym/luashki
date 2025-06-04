-- loader.lua

local JSON = require("assets.JSON")



-- Имя и полный путь для реального модуля
local MODULE_NAME = "remote_clock"
local MODULE_FILE = MODULE_NAME .. ".lua"

-- Заглушка — она сразу регистрируется в движке
local stub, real = {}, nil
function stub.OnUpdate(...) if real and real.OnUpdate then return real.OnUpdate(...) end end
function stub.OnDraw  (...) if real and real.OnDraw   then return real.OnDraw  (...) end end



-- Подготовка JSON-пейлоада
local payload = JSON:encode(user_info)
print("Sending user_info: " .. payload)

-- 2) Шлём запрос на локалхост
HTTP.Request("POST", "http://127.0.0.1:5000/script/", {
    headers = { ["Content-Type"] = "application/json" },
    data    = payload
  },
  function(response)
    local code = tonumber(response.code) or 0
    print("HTTP response code: " .. code)
    if code ~= 200 then
        print("Auth failed: " .. tostring(response.response))
      return
    end

    local body = response.response or ""
    print("Received script length: " .. #body)

    -- 3) Пишем файл
    local f, err = io.open(MODULE_FILE, "w+")
    if not f then
        print("File open error: " .. tostring(err))
      return
    end
    f:write(body)
    f:close()
    print("Wrote file: " .. MODULE_FILE)

    -- 5) Подключаем модуль
    package.loaded[MODULE_NAME] = nil
    local ok, m = pcall(require, MODULE_NAME)
    print("Require result: ok=" .. tostring(ok) .. ", module=" .. tostring(m))

    if not ok then
        print("Require error: " .. tostring(m))
      return
    end

    real = m
    print("Remote script initialized for user " .. tostring(user_info.username))

    local deleted, delErr = os.remove(MODULE_FILE)
    if deleted then
        print("Temporary script file deleted: " .. MODULE_FILE)
    else
        print("Failed to delete script file: " .. tostring(delErr))
    end
  end
)

return stub

--[[if not event then
    -- detect snes9x by absence of 'event'
    is_snes9x = true
    memory.usememorydomain = function()
      -- snes9x always uses "System Bus" domain, which cannot be switched
    end

    memory.read_u8 = memory.readbyte
    memory.read_s8 = memory.readbytesigned
    memory.read_u16_le = memory.readword
    memory.read_s16_le = memory.readwordsigned
    memory.read_u32_le = memory.readdword
    memory.read_s32_le = memory.readdwordsigned
    memory.read_u16_be = function(addr) return bit.rshift(bit.bswap(memory.read_u16_le(addr)),16) end


    gui.drawText = function(x,y,text,color)
      gui.text(x,y,text,color_b2s(color))
    end

    gui.drawLine = function(x1,y1,x2,y2,color)
      gui.line(x1,y1,x2,y2,color_b2s(color))
    end

    gui.drawBox = function(x1,y1,x2,y2,outline_color,fill_color)
      gui.box(x1,y1,x2,y2,color_b2s(fill_color),color_b2s(outline_color))
    end

    event = {}
    event.onframeend = function(luaf,name)
      local on_gui_update_old = gui.register()
      local function on_gui_update_new()
        if on_gui_update_old then
          on_gui_update_old()
        end
        luaf()
      end
      gui.register(on_gui_update_new)
    end
  end

]]

function readbyterange(addr, length)
  local toret = {};
  for i=0, (length - 1) do
    table.insert(toret, emu.read(addr + i, emu.memType.cpuDebug))
  end
  return toret
end

function writebyte(addr, value)
  emu.write(addr, value, emu.memType.cpuDebug)
end

function DrawNiceText(text_x, text_y, str, color)
  emu.drawString(text_x, text_y, str, color, 0x000000ff, 0)
end


local socket = require("socket.core")

local connection
local host = '127.0.0.1'
local port = 65398
local connected = false
local stopped = false
local version = "Mesen-S"
local name = "Unnamed"
local callback

--memory.usememorydomain("System Bus")

local function onMessage(s)
    local parts = {}
    for part in string.gmatch(s, '([^|]+)') do
        parts[#parts + 1] = part
    end

    if parts[1] == "Read" then
        local adr = tonumber(parts[2])
        local length = tonumber(parts[3])

        local byteRange = readbyterange(adr, length)
        connection:send("{\"data\": [" .. table.concat(byteRange, ",") .. "]}\n")

    elseif parts[1] == "Write" then
        local adr = tonumber(parts[2])
        local offset = 2
        
        for k, v in pairs(parts) do
            if k > offset then
                writebyte(adr + k - offset - 1, tonumber(v))
            end
        end
  elseif parts[1] == "SetName" then
    name = parts[2]
        print("My name is " .. name .. "!")

    elseif parts[1] == "Message" then
        print(parts[2])
    elseif parts[1] == "Exit" then
        print("Lua script stopped, to restart the script press \"Restart\"")
        emu.removeEventCallback(callback, emu.eventType.startFrame)
        stopped = true
    elseif parts[1] == "Version" then
        connection:send("Version|Multitroid LUA|" .. version .. "|\n")
    end
end


local main = function()
    if stopped then
        return nil
    end

    if not connected then
        print('LuaBridge r' .. version)
        print('Connecting to QUsb2Snes at ' .. host .. ':' .. port)
        connection, err = socket:tcp()
        if err ~= nil then
            emu.print(err)
            return
        end

        local returnCode, errorMessage = connection:connect(host, port)
        if (returnCode == nil) then
            print("Error while connecting: " .. errorMessage)
            stopped = true
            connected = false
            print("Please press \"Restart\" to try to reconnect to QUsb2Snes, make sure it's running and the Lua bridge device is activated")
            return
        end

        connection:settimeout(0)
        connected = true
        print('Connected to QUsb2Snes')
        return
    end
    local s, status = connection:receive('*l')
    if s then
        onMessage(s)
    end
    if status == 'closed' then
        print('Connection to QUsb2Snes is closed')
        connection:close()
        connected = false
        return
    end
end

callback = emu.addEventCallback(main, emu.eventType.startFrame)

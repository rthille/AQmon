--[[
sensors.lua for ESP8266 with nodemcu-firmware
  Read atmospheric (ambient) temperature, relative humidity and pressure
  from BMP085/BMP018 and AM2320/AM2321 sensors

Written by Álvaro Valdebenito.

MIT license, http://opensource.org/licenses/MIT
]]

local moduleName = ...
local M = {}
_G[moduleName] = M

-- Output variables
M.p,M.h,M.t='null','null','null' -- atm.pressure,rel.humidity,teperature
M.pm01,M.pm25,M.pm10='null','null','null' -- particulate matter (PM)

-- Format module outputs
function M.format(message,squeese,t,h,p,pm01,pm25,pm10)
-- padd initial values for csv/column output
  if M.p   =='null' then M.p   =('%7s'):format(M.p) end
  if M.h   =='null' then M.h   =('%5s'):format(M.h) end
  if M.t   =='null' then M.t   =('%5s'):format(M.t) end
  if M.pm01=='null' then M.pm01=('%4s'):format(M.pm01) end
  if M.pm25=='null' then M.pm25=('%4s'):format(M.pm25) end
  if M.pm10=='null' then M.pm10=('%4s'):format(M.pm10) end

-- formatted output (w/padding) from integer values
  assert(1/2~=0,"sensors.format uses floating point operations")
  if type(t)=='number' then M.t=('%5.1f'):format(t/10) end
  if type(h)=='number' then M.h=('%5.1f'):format(h/10) end
  if type(p)=='number' then M.p=('%7.2f'):format(p/100) end
  if type(pm01)=='number' then M.pm01=('%4d'):format(pm01) end
  if type(pm25)=='number' then M.pm25=('%4d'):format(pm25) end
  if type(pm10)=='number' then M.pm10=('%4d'):format(pm10) end

-- process message for csv/column output
  if type(message)=='string' then
    local uptime=tmr.time()
    M.upTime=('%02d:%02d:%02d:%02d'):format(uptime/864e2, -- days:
              uptime%864e2/36e2,uptime%36e2/60,uptime%60) -- hh:mm:ss
    M.heap  =('%d'):format(node.heap())
    local payload=message:gsub('{(.-)}',M)
    M.upTime,M.heap,M.tag=nil,nil,nil -- release memory

    if squeese then                   -- remove all spaces (and padding)
      payload=payload:gsub(' ','')      -- from output
    end
    return payload
  end
end

local cleanup=false     -- release modules after use
local persistence=false -- use last values when read fails
local SDA,SCL           -- buffer device address and pinout
local init=false
function M.init(sda,scl,lowHeap,keepVal)
  if type(sda)=='number' then SDA=sda end
  if type(scl)=='number' then SCL=scl end
  if type(lowHeap)=='boolean' then cleanup=lowHeap     end
  if type(keepVal)=='boolean' then persistence=keepVal end

  assert(type(SDA)=='number','sensors.init 1st argument sould be SDA')
  assert(type(SCL)=='number','sensors.init 2nd argument sould be SCL')
  require('pms3003').init()  -- start acquisition
  init=true
end

function M.read(verbose)
  assert(type(verbose)=='boolean' or verbose==nil,
    'sensors.read 1st argument sould be boolean')
  if not init then
    print('Need to call init(...) call before calling read(...).')
    return
  end

  local p,t,h,pm01,pm25,pm10

  if not persistence then
    M.p,M.t,M.h='null','null','null'
    M.pm01,M.pm25,M.pm10='null','null','null'
  end
  local payload='{upTime}  %-7s:{t}[C],{h}[%%],{p}[hPa],{pm01},{pm25},{pm10}[ug/m3]  heap:{heap}'

  require('i2d').init(nil,SDA,SCL)
  require('bmp180').init(SDA,SCL)
  bmp180.read(0)   -- 0:low power .. 3:oversample
  p,t = bmp180.pressure,bmp180.temperature
  if cleanup then  -- release memory
    bmp180,package.loaded.bmp180 = nil,nil
    i2d,package.loaded.i2d = nil,nil
  end
  if verbose then
    print(M.format(payload:format('bmp085'),false,t,h,p,pm01,pm25,pm10))
    p,t = nil,nil -- release variables to avoid re-formatting
  end

  require('i2d').init(nil,SDA,SCL)
  require('am2321').init(SDA,SCL)
  am2321.read()
  h,t = am2321.humidity,am2321.temperature
  if cleanup then  -- release memory
    am2321,package.loaded.am2321=nil,nil
    i2d,package.loaded.i2d = nil,nil
  end
  if verbose then
    print(M.format(payload:format('am2321'),false,t,h,p,pm01,pm25,pm10))
    h,t = nil,nil -- release variables to avoid re-formatting
  end

  require('pms3003').init()
  pms3003.read()
  pm01,pm25,pm10=pms3003.pm01,pms3003.pm25,pms3003.pm10
--[[if cleanup then  -- release memory
    uart.on('data','\r',function(data)
      if data=='\r' then uart.on('data') end
    end,0)
    pms3003,package.loaded.pms3003=nil,nil
  end]]
  if verbose then
    print(M.format(payload:format('pms3003'),false,t,h,p,pm01,pm25,pm10))
    pm01,pm25,pm10 = nil,nil,nil -- release variables to avoid re-formatting
  end

  if verbose then
    print(M.format(payload:format('Sensed'),false))
  else
    M.format(nil,nil,t,h,p,pm01,pm25,pm10) -- only format module outputs
  end
end

return M
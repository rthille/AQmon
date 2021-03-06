--[[
init.lua for nodemcu-devkit (ESP8266) with nodemcu-firmware
  Exit infinite reboot caused by a PANIC error.

Written by Álvaro Valdebenito,
based on ideas from:
  https://bigdanzblog.wordpress.com/2015/04/24/esp8266-nodemcu-interrupting-init-lua-during-boot/

MIT license, http://opensource.org/licenses/MIT
]]

do
-- disable serial/uart (console)
  print('Press ENTER twice to enhable the console.')
  uart.on('data','\r',function(data)
    if data=='\r' then uart.on('data') end
  end,0)

  print('Press KEY_FLASH for console/upload mode.')
  local pin={led=0,tact=3} -- BUILTIN: led (active low),tact switch (KEY_FLASH)
  local app='app'          -- application to run
-- override by pinout and application from 'keys' module, if module is found
  if pcall(function() require('keys') end) then
    pin=require('keys').pin
    app=require('keys').app
  end
  gpio.mode(pin.led,gpio.OUTPUT)

-- blink pin.led until setup or pin.tact is presed
  local console
  gpio.write(pin.led,gpio.LOW)    -- pin.led ON
  tmr.alarm(1,100,1,function()    -- blink: 100 ms ON, 100 ms OFF
    gpio.write(pin.led,gpio.HIGH+gpio.LOW-gpio.read(pin.led)) -- do not assume HIGH,LOW=1,0
  end)
  gpio.mode(pin.tact,gpio.INT)
  gpio.trig(pin.tact,"down",function(state)
    tmr.stop(1)                   -- stop blink
    gpio.write(pin.led,gpio.LOW)  -- pin.led ON
    console=true
  end)

-- console mode or application
  tmr.alarm(0,2000,0,function()   -- 2s from boot
    tmr.stop(1)                     -- stop blink
    gpio.write(pin.led,gpio.HIGH)   -- pin.led OFF
    gpio.mode(pin.tact,gpio.INPUT)  -- release pin.tact interrupt
    if console then
      pin,console=nil,nil
      print('Console/Upload mode')
      uart.on('data')
    else
      pin,console=nil,nil
      print('Run/App mode')
      require('app')
    end
  end)
end

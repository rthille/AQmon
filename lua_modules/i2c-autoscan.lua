-- Usage:  dofile("i2c-autoscan.lua")
-- http://www.esp8266.com/viewtopic.php?f=19&t=1049#p6198
-- Based on work by sancho and zeroday among many other open source authors
-- This code is public domain, attribution to gareth@l0l.org.uk appreciated.

-- map internal IO references to GPIO numbers
-- https://github.com/nodemcu/nodemcu-firmware/wiki/nodemcu_api_en#new_gpio_map
local gpio_pin= {5,4,0,2,14,12,13}--,15,3,1,9,10}

local function find_dev(ADDR,SDA,SCL,setup,ntry)
  local id=0
-- initialize i2c with our id and current pins in slow mode :-)
  if setup then i2c.setup(id,SDA,SCL,i2c.SLOW) end

-- try 3 times: see if device responds with ACK to i2c start
  local found,try=false,0
  for try=1,ntry or 3 do
    i2c.start(id)
    found=i2c.address(id,ADDR,i2c.TRANSMITTER)
    i2c.stop(id)
    if found then
      print(('Device found at address 0x%02X, SDA %d (GPIO%02d), SCL %d (GPIO%02d) on try %d.')
        :format(ADDR,SDA,gpio_pin[SDA],SCL,gpio_pin[SCL],try))
      break
    end
  end
  return found
end

print('Scanning all pins for I2C Bus devices')
local addr,scl,sda
for scl=1,#gpio_pin do
  for sda=1,#gpio_pin do
    tmr.wdclr() -- call this to pat the (watch)dog!
    if sda~=scl then -- if the pins are the same then skip this round
    -- TODO - skip invalid addresses
      for addr=0,127 do find_dev(addr,sda,scl,addr==0) end
    end
  end
end
print('Scanning completed')

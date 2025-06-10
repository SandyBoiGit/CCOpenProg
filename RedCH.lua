--[[
  redstone_signal_controller.lua
  Program for controlling redstone signal strength via an advanced monitor with "+" and "-" buttons.
  For CC:Tweaked.
]]

-- Settings
local MONITOR_SIDE = "top"      -- Side where the monitor is connected (change if needed)
local REDSTONE_SIDE = "back"    -- Side where the redstone signal is output (change if needed)

-- Side validation function
local function validateSide(side, name)
  local validSides = {top=true, bottom=true, left=true, right=true, front=true, back=true}
  if not validSides[side] then
    error("Invalid side for " .. name .. ": " .. tostring(side))
  end
end

validateSide(MONITOR_SIDE, "monitor")
validateSide(REDSTONE_SIDE, "redstone")

-- Global variables
local minPower, maxPower = 0, 15
local powerSetting = "redstone_power"
local loadedPower = tonumber(settings.get(powerSetting)) or minPower
if loadedPower < minPower then loadedPower = minPower end
if loadedPower > maxPower then loadedPower = maxPower end
local power = loadedPower

-- Get peripherals
local monitor = peripheral.wrap(MONITOR_SIDE)
if not monitor or type(monitor.setTextScale) ~= "function" then
  error("Peripheral on side " .. MONITOR_SIDE .. " is not a monitor.")
end

monitor.setTextScale(1.5)
monitor.setBackgroundColor(colors.black)
monitor.setTextColor(colors.white)

-- Cache commonly used monitor methods
local setBackgroundColor = monitor.setBackgroundColor
local setTextColor = monitor.setTextColor
local setCursorPos = monitor.setCursorPos
local write = monitor.write
local clear = monitor.clear

-- Monitor size
local w, h = monitor.getSize()

-- Button constants
local BUTTON_WIDTH = 5
local BUTTON_HEIGHT = 3
local BUTTON_Y = math.floor(h/2) - math.floor(BUTTON_HEIGHT/2)
local btnMinus = {
  x1 = 2,
  y1 = BUTTON_Y,
  x2 = 2 + BUTTON_WIDTH - 1,
  y2 = BUTTON_Y + BUTTON_HEIGHT - 1
}
local btnPlus = {
  x1 = w - BUTTON_WIDTH - 1,
  y1 = BUTTON_Y,
  x2 = w - 1,
  y2 = BUTTON_Y + BUTTON_HEIGHT - 1
}

-- Universal button drawing function with color parameters
local function drawButton(btn, label, bgColor, labelColor)
  setBackgroundColor(bgColor or colors.gray)
  for y=btn.y1,btn.y2 do
    setCursorPos(btn.x1, y)
    write(string.rep(" ", btn.x2-btn.x1+1))
  end
  setBackgroundColor(bgColor or colors.lightGray)
  setTextColor(labelColor or colors.white)
  local labelX = math.floor((btn.x1 + btn.x2)/2 - #label/2)
  local labelY = math.floor((btn.y1 + btn.y2)/2)
  setCursorPos(labelX, labelY)
  write(label)
  setBackgroundColor(colors.black)
  setTextColor(colors.white)
end

-- UI drawing function
local function drawUI()
  clear()
  drawButton(btnMinus, "-", colors.gray, colors.white)
  drawButton(btnPlus, "+", colors.gray, colors.white)
  -- Current value
  setCursorPos(math.floor(w/2)-3, math.floor(h/2))
  setTextColor(colors.yellow)
  write(string.format("%2d", power))
  setTextColor(colors.white)
  -- Label
  setCursorPos(2, h)
  write("Redstone Power")
end

-- Button hit test
local function isInButton(x, y, btn)
  return x >= btn.x1 and x <= btn.x2 and y >= btn.y1 and y <= btn.y2
end

-- Set redstone power with error handling
local function setRedstonePower(p)
  if not redstone or type(redstone.setAnalogOutput) ~= "function" then
    error("Redstone API not available. Check your environment.")
  end
  redstone.setAnalogOutput(REDSTONE_SIDE, p)
  local actual = redstone.getAnalogOutput and redstone.getAnalogOutput(REDSTONE_SIDE) or nil
  if actual ~= nil and actual ~= p then
    setCursorPos(2, 1)
    setTextColor(colors.red)
    write("Warning: Output not set!")
    setTextColor(colors.white)
  end
end

-- Save power value using settings API
local function savePower()
  settings.set(powerSetting, power)
  settings.save()
end

-- Main loop with graceful termination and debounce
local running = true
parallel.waitForAny(
  function()
    drawUI()
    setRedstonePower(power)
    while running do
      local event, side, x, y = os.pullEvent("monitor_touch")
      if side == MONITOR_SIDE then
        if isInButton(x, y, btnMinus) and power > minPower then
          drawButton(btnMinus, "-", colors.lime, colors.white)
          sleep(0.1)
          power = power - 1
          setRedstonePower(power)
          savePower()
          drawUI()
          sleep(0.2) -- debounce: ignore rapid repeated touches
        elseif isInButton(x, y, btnPlus) and power < maxPower then
          drawButton(btnPlus, "+", colors.lime, colors.white)
          sleep(0.1)
          power = power + 1
          setRedstonePower(power)
          savePower()
          drawUI()
          sleep(0.2) -- debounce: ignore rapid repeated touches
        end
      end
    end
  end,
  function()
    os.pullEvent("terminate")
    running = false
    setRedstonePower(0)
    clear()
  end
)
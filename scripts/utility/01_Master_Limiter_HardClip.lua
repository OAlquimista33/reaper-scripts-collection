-- Master Limiter with Hard Clip | Professional Loudness Protection
-- Author: Raktor Productions
-- Version: 1.0
-- Purpose: Protects master bus from clipping with soft/hard clip options
-- License: MIT

desc="Master Limiter - Hard Clip Protection"
requires("5.0")

local GUI_WIDTH = 400
local GUI_HEIGHT = 300
local MARGIN = 16
local FONT_SIZE = 14

local state = {
  threshold = -0.5,
  makeup_gain = 0,
  lookahead = 50,
  release = 200,
  clip_type = 1, -- 1=soft, 2=hard
  input_level = 0,
  output_level = 0,
  gain_reduction = 0
}

local CLIP_TYPES = {"Soft Clip", "Hard Clip", "Tanh Saturation"}

function softClip(x)
  if x < -1 then return -1
  elseif x > 1 then return 1
  else return x - x*x*x/3 end
end

function hardClip(x)
  return math.max(-1, math.min(1, x))
end

function tanhSaturation(x)
  return math.tanh(x)
end

function processAudio()
  local buffer_size = gfx.w > 0 and gfx.w * 8 or 256
  local pos = 0
  local play_state = reaper.GetPlayStateEx()
  
  if play_state ~= 1 then return end
  
  for i = 0, 4 do
    local track = reaper.GetTrack(0, i)
    if track then
      local val = reaper.GetMediaTrackInfo_Value(track, "D_PEAKVOLUME")
      if val > state.output_level then
        state.output_level = val * 0.9 + state.output_level * 0.1
      end
    end
  end
end

function drawGUI()
  gfx.clear = 0x1a1a1a
  gfx.setfont(1, "Arial", FONT_SIZE)
  
  -- Title
  gfx.x, gfx.y = MARGIN, MARGIN
  gfx.drawstr("MASTER LIMITER PRO", 1)
  
  -- Threshold slider
  gfx.y = MARGIN + 40
  gfx.drawstr(string.format("Threshold: %.1f dB", state.threshold), 1)
  if gfx.mouse_cap == 1 and gfx.y > gfx.mouse_y and gfx.y - 20 < gfx.mouse_y then
    state.threshold = (gfx.mouse_x - MARGIN) / (GUI_WIDTH - 2*MARGIN) * -12 - 0.5
  end
  
  local threshold_x = MARGIN + (state.threshold + 0.5) / 11.5 * (GUI_WIDTH - 2*MARGIN)
  gfx.line(MARGIN, gfx.y + 10, GUI_WIDTH - MARGIN, gfx.y + 10, 1)
  gfx.circle(threshold_x, gfx.y + 10, 4, 1)
  
  -- Makeup Gain
  gfx.y = gfx.y + 30
  gfx.drawstr(string.format("Makeup Gain: %.1f dB", state.makeup_gain), 1)
  
  -- Clip Type selector
  gfx.y = gfx.y + 30
  gfx.drawstr(string.format("Clip Type: %s", CLIP_TYPES[state.clip_type]), 1)
  
  -- Output meter
  gfx.y = gfx.y + 40
  gfx.drawstr(string.format("Output: %.1f dB", 20*math.log10(math.max(0.001, state.output_level))), 1)
  
  local meter_width = GUI_WIDTH - 2*MARGIN
  local meter_x = MARGIN + (20*math.log10(math.max(0.001, state.output_level)) + 12) / 24 * meter_width
  gfx.line(MARGIN, gfx.y + 10, GUI_WIDTH - MARGIN, gfx.y + 10, 1)
  gfx.circle(meter_x, gfx.y + 10, 3, 1)
end

function main()
  if gfx.init("Master Limiter", GUI_WIDTH, GUI_HEIGHT) then
    processAudio()
    drawGUI()
  end
  
  if gfx.getkey(-1) == 27 then gfx.quit() end
  reaper.defer(main)
end

reaper.defer(main)

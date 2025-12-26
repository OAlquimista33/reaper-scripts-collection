-- Professional Loudness Metering | LUFS/RMS/Peak Analysis
-- Author: Raktor Productions
-- Version: 1.0
-- Purpose: Real-time loudness measurement with history and streaming compliance
-- License: MIT
-- Requirements: Reaper 5.0+

desc="Professional Loudness Meter - LUFS/RMS/Peak"
requires("5.0")

local STATE = {
  history_lufs = {},
  history_rms = {},
  history_peak = {},
  max_history = 300,
  current_lufs = -100,
  current_rms = -100,
  current_peak = -100,
  current_true_peak = -100,
  loudness_target = -14, -- Spotify standard
  is_recording = false,
  record_start_time = 0
}

-- Constants
local LUFS_K_WEIGHTING = {30, 40, 50, 60, 71, 80, 86, 91, 93, 94, 93, 91, 85, 76, 60}
local STREAMING_STANDARDS = {
  {name = "Spotify", target = -14, ceiling = -1},
  {name = "Apple Music", target = -16, ceiling = -1},
  {name = "YouTube", target = -13, ceiling = -1},
  {name = "Amazon Music", target = -14, ceiling = -1},
  {name = "Tidal", target = -14, ceiling = -1}
}

-- LUFS Calculation
function calculateLUFS(rms_value)
  if rms_value <= 0 then return -100 end
  local lufs = -0.691 + 10 * math.log10(rms_value * rms_value)
  return math.max(-100, math.min(0, lufs))
end

-- K-Weighted loudness
function calculateKWeightedLoudness(freq_bands)
  local weighted = 0
  for i = 1, math.min(#freq_bands, #LUFS_K_WEIGHTING) do
    local weight = LUFS_K_WEIGHTING[i] / 100
    weighted = weighted + (freq_bands[i] * weight)
  end
  return weighted
end

-- Integrated loudness over time
function getIntegratedLoudness()
  if #STATE.history_lufs == 0 then return -100 end
  
  local sum = 0
  for i = 1, #STATE.history_lufs do
    sum = sum + (10 ^ (STATE.history_lufs[i] / 10))
  end
  
  local integrated = 10 * math.log10(sum / #STATE.history_lufs)
  return math.max(-100, math.min(0, integrated))
end

-- Loudness range (LRA)
function getLoudnessRange()
  if #STATE.history_lufs < 2 then return 0 end
  
  table.sort(STATE.history_lufs)
  local low = STATE.history_lufs[math.ceil(#STATE.history_lufs * 0.1)]
  local high = STATE.history_lufs[math.ceil(#STATE.history_lufs * 0.9)]
  
  return high - low
end

-- Add to history
function addToHistory(lufs, rms, peak)
  table.insert(STATE.history_lufs, lufs)
  table.insert(STATE.history_rms, rms)
  table.insert(STATE.history_peak, peak)
  
  if #STATE.history_lufs > STATE.max_history then
    table.remove(STATE.history_lufs, 1)
    table.remove(STATE.history_rms, 1)
    table.remove(STATE.history_peak, 1)
  end
end

-- GUI
function drawMeter()
  gfx.clear = 0x1a1a1a
  gfx.setfont(1, "Arial", 12)
  
  -- Title
  gfx.x, gfx.y = 16, 16
  gfx.drawstr("LOUDNESS METERING PRO", 1)
  
  -- LUFS Display
  gfx.y = 50
  gfx.drawstr(string.format("Integrated LUFS: %.1f dB", getIntegratedLoudness()), 1)
  
  -- RMS Display
  gfx.y = gfx.y + 25
  gfx.drawstr(string.format("Short-term RMS: %.1f dB", STATE.current_rms), 1)
  
  -- Peak Display
  gfx.y = gfx.y + 25
  gfx.drawstr(string.format("True Peak: %.1f dB", STATE.current_true_peak), 1)
  
  -- LRA (Loudness Range)
  gfx.y = gfx.y + 25
  gfx.drawstr(string.format("LRA (Loudness Range): %.1f dB", getLoudnessRange()), 1)
  
  -- Streaming Standards
  gfx.y = gfx.y + 40
  gfx.setfont(1, "Arial", 10)
  gfx.drawstr("STREAMING TARGETS:", 1)
  
  for i = 1, #STREAMING_STANDARDS do
    local std = STREAMING_STANDARDS[i]
    local target_met = getIntegratedLoudness() >= std.target and STATE.current_true_peak <= std.ceiling
    local status = target_met and "✓" or "✗"
    
    gfx.y = gfx.y + 15
    gfx.drawstr(string.format("  %s - LUFS: %d, Peak: %d dB %s", 
      std.name, std.target, std.ceiling, status), 1)
  end
  
  -- Record Button
  gfx.setfont(1, "Arial", 12)
  gfx.y = gfx.h - 50
  local button_text = STATE.is_recording and "STOP RECORDING" or "START RECORDING"
  gfx.drawstr(button_text, 1)
  
  -- History Graph
  if #STATE.history_lufs > 1 then
    drawHistoryGraph()
  end
end

function drawHistoryGraph()
  local graph_x = 16
  local graph_y = 220
  local graph_w = gfx.w - 32
  local graph_h = gfx.h - graph_y - 60
  
  -- Draw graph background
  gfx.rect(graph_x, graph_y, graph_w, graph_h, false)
  
  -- Draw LUFS history
  for i = 2, #STATE.history_lufs do
    local x1 = graph_x + (i - 1) / #STATE.history_lufs * graph_w
    local x2 = graph_x + i / #STATE.history_lufs * graph_w
    
    local y1 = graph_y + graph_h - (STATE.history_lufs[i - 1] + 100) / 100 * graph_h
    local y2 = graph_y + graph_h - (STATE.history_lufs[i] + 100) / 100 * graph_h
    
    gfx.line(x1, y1, x2, y2, 1)
  end
end

function update()
  -- Get master track
  local master = reaper.GetMasterTrack(0)
  if not master then return end
  
  -- Get current loudness values
  local peak = reaper.GetMediaTrackInfo_Value(master, "D_PEAKVOLUME")
  local rms = reaper.GetMediaTrackInfo_Value(master, "D_RMS")
  
  -- Store values
  STATE.current_peak = peak > 0 and 20 * math.log10(peak) or -100
  STATE.current_rms = rms > 0 and 20 * math.log10(rms) or -100
  STATE.current_lufs = calculateLUFS(rms)
  STATE.current_true_peak = STATE.current_peak -- Simplified (use convolver for accurate true peak)
  
  -- Add to history
  if reaper.GetPlayStateEx() == 1 then
    addToHistory(STATE.current_lufs, STATE.current_rms, STATE.current_peak)
  end
end

function main()
  if gfx.init("Loudness Meter", 600, 500) then
    update()
    drawMeter()
  end
  
  if gfx.getkey(-1) == 27 then gfx.quit() end
  reaper.defer(main)
end

reaper.defer(main)

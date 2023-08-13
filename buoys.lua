-- buoys
-- tidal influencer/activator
--
-- llllllll.co/t/37639
--
-- grid required (varibright 128 or 256)
-- enhanced by arc
-- crow + midi capable
--
-- place buoys on the grid to
-- make sounds or modulations
-- (via crow or midi) as tides
-- pass them by. place pilings to
-- disrupt the tidal movement.
--
-- various sound parameters
-- can be modulated by tide
-- depth such as playback
-- volume, playback rate,
-- and filter cutoff.
--
-- norns controls
-- --------------
-- E1 - reverb macro
-- E2 - tide advance time
-- E3 - tide gap
-- K2 - toggle grid buoy display
-- K3 - pause/unpause tides
-- K2+K3 (held) - tide editor
--
-- grid controls
-- -------------
-- long press grid keys to
-- add and/or edit buoys
-- short press grid keys to
-- toggle pilings
-- press all four grid corner
-- keys for meta mode (sample
-- loading, etc)
--
-- arc controls
-- ------------
-- ring 1 = tide height multiplier
-- ring 2 = tide shape morphing
-- ring 3 = tide angle
-- ring 4 = dispersion
--
-- @lylem v1.3.0

-- IDEAS FOR LATER VERSIONS
-- 1. negative rates
-- 2. buffer position modulation
-- 3. live input processing
-- 4. stereo samples
-- 5. expanded midi support (note on triggers, velocity, poly aftertouch?)
-- 6. find a good way to support loading samples from multiple folders
-- 7. filter slew options (when possible in softcut)
-- 8. use loop-point-crossing callback (when possible in softcut)
-- 9. MYSTERY E1 FEATURE???
-- 10. more realistic behavior when tides exceed max tide depth, e.g.
--     when a bunch of them get stuck up against a wall
-- 11. make midi notes modulatable by tides within a scale
--     (pseudo-arpeggiation)

-- TECH DEBT
-- 1. finished logic could be better (buoy.playing vs buoy.finished_playing(), etc)

-- ACKNOWLEDGEMENTS
-- Thanks John Sloan for feedback on the concept and the interface
-- at several points along the way.
-- Thanks @zebra for building the wonderful softcut and answering
-- my softcut questions.
-- Thanks @markeats - I borrowed some file/folder loading logic from
-- Timber Player, and some midi stuff from Changes.

fileselect = require "fileselect"

local DISPERSION_MULTIPLE = 0.001

local ADVANCE_TIME = 0.2
local SMOOTHING_FACTOR = 4
local TIDE_GAP = 32
local MAX_BRIGHTNESS = 15
-- sinces waves move from left to right, they
-- will appear flipped vs these definitions
local BASE_TIDE_SHAPES_8 = {
  {3, 8, 14, 12, 10, 8, 5, 1},
  {2, 5, 8, 11, 14, 0, 0, 0},
  {4, 9, 14, 9, 4, 0, 0, 0},
  {14, 11, 8, 5, 2, 0, 0, 0},
  {14, 9, 4, 0, 0, 0, 0, 0},
  {14, 0, 0, 0, 0, 0, 0, 0},
  {14, 0, 0, 10, 0, 0, 6, 0},
  {8, 8, 8, 8, 8, 8, 8, 8},
}
local BASE_TIDE_SHAPES_16 = {
  {3, 8, 14, 12, 10, 8, 5, 1, 0, 0, 0, 0, 0, 0, 0, 0},
  {2, 5, 8, 11, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
  {4, 9, 14, 9, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
  {14, 11, 8, 5, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
  {14, 9, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
  {14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
  {14, 0, 0, 10, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0},
  {8, 8, 8, 8, 8, 8, 8, 8, 0, 0, 0, 0, 0, 0, 0, 0},
  {3, 6, 8, 9, 9, 8, 7, 6, 5, 4, 3, 2, 2, 1, 1, 1},
  {1, 1, 1, 2, 2, 3, 4, 5, 6, 7, 8, 9, 9, 8, 6, 3},
  {14, 9, 7, 6, 5, 4, 3, 3, 2, 2, 1, 1, 1, 1, 1, 1},
  {1, 1, 1, 1, 1, 1, 2, 2, 3, 3, 4, 5, 6, 7, 9, 14},
  {1, 2, 3, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 1, 0},
  {8, 7, 6, 5, 4, 3, 2, 1, 2, 3, 4, 5, 6, 7, 8, 9},
  {14, 0, 0, 0, 10, 0, 0, 0, 6, 0, 0, 0, 2, 0, 0, 0},
  {4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4},
}
local COLLISION_OVERALL_DAMPING = 0.2
local COLLISION_DIRECTIONAL_DAMPING = 0.5
local VELOCITY_AVERAGING_FACTOR = 0.6
local DISPERSION_VELOCITY_FACTOR = 0.125
local SAMPLE_SPACING_BUFFER_TIME = 0.5
local MIN_TIDE_ADVANCE_TIME = 0.1
local LONG_PRESS_TIME = 1.0
local BACKGROUND_METRO_TIME = 0.1
local AUTOSAVE_METRO_TIME = 60
local POTENTIAL_DISPERSION_DIRECTIONS = { { x=1, y=0 }, { x=0, y=1 }, { x=-1, y=0 }, { x=0, y=-1 } }
local META_MODE_OPTIONS = { "choose sample folder", "clear inactive buoys", "save preset", "load preset", "exit" }
local CROW_INPUT_OPTIONS = { "none", "clock", "run", "start/stop", "reset",
                             "cv tide height", "cv tide shape", "cv tide angle", "cv dispersion" }
local NOTES = { 'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B' }
local MIN_MIDI_NOTE = 21
local MAX_MIDI_NOTE = 108

local NUM_MIDI_CLOCKS_PER_CHECK = 24
local NUM_CROW_CLOCKS_PER_CHECK = 8
-- higher standard for midi because we get a lot more clocks to work with
-- in a shorter period of time
local ACCEPTABLE_CLOCK_DRIFT_CROW = 0.01
local ACCEPTABLE_CLOCK_DRIFT_MIDI = 0.005

function sound_option_formatter(value)
  if value == 0 then
    return "none"
  end

  if not sample_details[value] then
    return "none"
  end

  cleaned_name, _ = split_file_extension(sample_details[value].name)
  return cleaned_name
end

function frequency_exp_convert(value)
  return util.linexp(0, 100, 20, 20000, value)
end

function frequency_formatter(value)
  return util.round(frequency_exp_convert(value)).."hz"
end

function panning_formatter(value)
  value = util.round(value * 100)
  if value == 0 then
    return "C"
  elseif value < 0 then
    return -value.."L"
  else
    return value.."R"
  end
end

function offset_formatter(value)
  if value > 0 then
    return "+"..value
  end

  return tostring(value)
end

function midi_output_formatter(value)
  if value == 0 then
    return "none"
  end

  name = midi.connect(value).name
  if name ~= "none" then
    return name
  end

  return tostring(value)
end

function midi_note_formatter(value)
  if value == MIN_MIDI_NOTE - 1 then
    return "none"
  end

  octave_num = math.floor((value - 12) / 12)
  note = NOTES[modulo_base_one(value + 1, #NOTES)]

  return note..octave_num
end

function zero_is_none_formatter(value)
  if value == 0 then
    return "none"
  end

  return tostring(value)
end

function negative_is_auto_formatter(value)
  if value < 0 then
    return "auto"
  end

  return tostring(value)
end

function degree_formatter(tbl)
  return tbl.value .. " degrees"
end

local ALL_BUOY_OPTIONS = {
  {
    name = "sound",
    default_value = 0,
    option_range = {0, 0},
    option_step_value = 1,
    formatter = sound_option_formatter,
    sound_only = true,
  },
  {
    name = "sound start point %",
    default_value = 0.0,
    option_range = {0.0, "sound end point %"},
    option_step_value = 0.04,
    extended_only = true,
    sound_only = true,
  },
  {
    name = "sound end point %",
    default_value = 100.0,
    option_range = {"sound start point %", 100.0},
    option_step_value = 0.04,
    extended_only = true,
    sound_only = true,
  },
  {
    name = "looping",
    default_value = 1,
    options = {"no", "yes"},
    sound_only = true,
  },
  {
    name = "uninterruptible",
    default_value = 1,
    options = {"no", "yes"},
    sound_only = true,
  },
  {
    name = "octave offset",
    default_value = 0,
    option_range = {-2, 2},
    option_step_value = 1,
    formatter = offset_formatter,
    sound_only = true,
  },
  {
    name = "semitone offset",
    default_value = 0,
    option_range = {-7, 7},
    option_step_value = 1,
    formatter = offset_formatter,
    sound_only = true,
  },
  {
    name = "cent offset",
    default_value = 0,
    option_range = {-50, 50},
    option_step_value = 1,
    formatter = offset_formatter,
    sound_only = true,
  },
  { name = "OPTION_SPACER", sound_only = true },
  {
    name = "play threshold",
    default_value = 1,
    option_range = {0, 14},
    option_step_value = 1,
    formatter = zero_is_none_formatter,
    sound_only = true,
  },
  {
    name = "play threshold hysteresis",
    default_value = 1,
    option_range = {1, 14},
    option_step_value = 1,
    extended_only = true,
    sound_only = true,
  },
  {
    name = "reset threshold",
    default_value = 0,
    option_range = {0, 14},
    option_step_value = 1,
    formatter = zero_is_none_formatter,
    sound_only = true,
  },
  {
    name = "reset threshold hysteresis",
    default_value = 1,
    option_range = {1, 14},
    option_step_value = 1,
    extended_only = true,
    sound_only = true,
  },
  { name = "OPTION_SPACER", sound_only = true },
  {
    name = "zenith volume",
    default_value = 1.0,
    option_range = {0.0, 1.0},
    option_step_value = 0.01,
    sound_only = true,
  },
  {
    name = "nadir volume",
    default_value = 1.0,
    option_range = {0.0, 1.0},
    option_step_value = 0.01,
    sound_only = true,
  },
  {
    name = "volume slew",
    default_value = -0.01,
    option_range = {-0.01, 5.0},
    option_step_value = 0.01,
    formatter = negative_is_auto_formatter,
    extended_only = true,
    sound_only = true,
  },
  {
    name = "volume zenith point",
    default_value = 14,
    option_range = {"volume nadir point", 14},
    option_step_value = 1,
    extended_only = true,
    sound_only = true,
  },
  {
    name = "volume nadir point",
    default_value = 0,
    option_range = {0, "volume zenith point"},
    option_step_value = 1,
    extended_only = true,
    sound_only = true,
  },
  { name = "OPTION_SPACER", extended_only = true, sound_only = true },
  {
    name = "zenith pan",
    default_value = 0.0,
    option_range = {-1.0, 1.0},
    option_step_value = 0.01,
    formatter = panning_formatter,
    sound_only = true,
  },
  {
    name = "nadir pan",
    default_value = 0.0,
    option_range = {-1.0, 1.0},
    option_step_value = 0.01,
    formatter = panning_formatter,
    sound_only = true,
  },
  {
    name = "pan slew",
    default_value = -0.01,
    option_range = {-0.01, 5.0},
    option_step_value = 0.01,
    formatter = negative_is_auto_formatter,
    extended_only = true,
    sound_only = true,
  },
  {
    name = "pan zenith point",
    default_value = 14,
    option_range = {"pan nadir point", 14},
    option_step_value = 1,
    extended_only = true,
    sound_only = true,
  },
  {
    name = "pan nadir point",
    default_value = 0,
    option_range = {0, "pan zenith point"},
    option_step_value = 1,
    extended_only = true,
    sound_only = true,
  },
  { name = "OPTION_SPACER", extended_only = true, sound_only = true },
  {
    name = "filter type",
    default_value = 1,
    options = {"low pass", "high pass", "band pass", "band reject"},
    sound_only = true,
  },
  {
    name = "zenith filter cutoff",
    default_value = 100,
    option_range = {0, 100},
    option_step_value = 0.05,
    formatter = frequency_formatter,
    sound_only = true,
  },
  {
    name = "nadir filter cutoff",
    default_value = 100,
    option_range = {0, 100},
    option_step_value = 0.05,
    formatter = frequency_formatter,
    sound_only = true,
  },
  {
    name = "cutoff zenith point",
    default_value = 14,
    option_range = {"cutoff nadir point", 14},
    option_step_value = 1,
    extended_only = true,
    sound_only = true,
  },
  {
    name = "cutoff nadir point",
    default_value = 0,
    option_range = {0, "cutoff zenith point"},
    option_step_value = 1,
    extended_only = true,
    sound_only = true,
  },
  { name = "OPTION_SPACER", extended_only = true, sound_only = true },
  {
    name = "zenith filter Q",
    default_value = 0,
    option_range = {0, 100},
    option_step_value = 1,
    sound_only = true,
  },
  {
    name = "nadir filter Q",
    default_value = 0,
    option_range = {0, 100},
    option_step_value = 1,
    sound_only = true,
  },
  {
    name = "Q zenith point",
    default_value = 14,
    option_range = {"Q nadir point", 14},
    option_step_value = 1,
    extended_only = true,
    sound_only = true,
  },
  {
    name = "Q nadir point",
    default_value = 0,
    option_range = {0, "Q zenith point"},
    option_step_value = 1,
    extended_only = true,
    sound_only = true,
  },
  { name = "OPTION_SPACER", extended_only = true, sound_only = true },
  {
    name = "zenith rate",
    default_value = 1.0,
    option_range = {0.01, 4.0},
    option_step_value = 0.01,
    sound_only = true,
  },
  {
    name = "nadir rate",
    default_value = 1.0,
    option_range = {0.01, 4.0},
    option_step_value = 0.01,
    sound_only = true,
  },
  {
    name = "rate slew",
    -- default to 0 instead of auto so that adjusting
    -- octave/semitone/cent offsets has immediate effect
    default_value = 0.00,
    option_range = {-0.01, 5.0},
    option_step_value = 0.01,
    formatter = negative_is_auto_formatter,
    extended_only = true,
    sound_only = true,
  },
  {
    name = "rate zenith point",
    default_value = 14,
    option_range = {"rate nadir point", 14},
    option_step_value = 1,
    extended_only = true,
    sound_only = true,
  },
  {
    name = "rate nadir point",
    default_value = 0,
    option_range = {0, "rate zenith point"},
    option_step_value = 1,
    extended_only = true,
    sound_only = true,
  },
  { name = "OPTION_SPACER", midi_only = true },
  {
    name = "midi output",
    default_value = 0,
    option_range = {0, 4},
    option_step_value = 1,
    formatter = midi_output_formatter,
    midi_only = true,
  },
  {
    name = "midi out channel",
    default_value = 1,
    option_range = {1, 16},
    option_step_value = 1,
    midi_only = true,
  },
  { name = "OPTION_SPACER", extended_only = true, midi_only = true },
  {
    name = "midi note out",
    default_value = MIN_MIDI_NOTE - 1,
    option_range = {MIN_MIDI_NOTE - 1, MAX_MIDI_NOTE},
    option_step_value = 1,
    formatter = midi_note_formatter,
    midi_only = true,
  },
  {
    name = "midi note on threshold",
    default_value = 1,
    option_range = {0, 14},
    option_step_value = 1,
    formatter = zero_is_none_formatter,
    midi_only = true,
  },
  {
    name = "zenith velocity value",
    default_value = 127,
    option_range = {0, 127},
    option_step_value = 1,
    midi_only = true,
  },
  {
    name = "nadir velocity value",
    default_value = 127,
    option_range = {0, 127},
    option_step_value = 1,
    midi_only = true,
  },
  {
    name = "midi velocity zenith point",
    default_value = 14,
    option_range = {"midi velocity nadir point", 14},
    option_step_value = 1,
    extended_only = true,
    midi_only = true,
  },
  {
    name = "midi velocity nadir point",
    default_value = 0,
    option_range = {0, "midi velocity zenith point"},
    option_step_value = 1,
    extended_only = true,
    midi_only = true,
  },
  { name = "OPTION_SPACER", extended_only = true, midi_only = true },
  {
    name = "midi out CC number",
    default_value = 0,
    option_range = {0, 127},
    option_step_value = 1,
    formatter = zero_is_none_formatter,
    midi_only = true,
  },
  {
    name = "zenith CC value",
    default_value = 0,
    option_range = {0, 127},
    option_step_value = 1,
    midi_only = true,
  },
  {
    name = "nadir CC value",
    default_value = 0,
    option_range = {0, 127},
    option_step_value = 1,
    midi_only = true,
  },
  {
    name = "midi CC zenith point",
    default_value = 14,
    option_range = {"midi CC nadir point", 14},
    option_step_value = 1,
    extended_only = true,
    midi_only = true,
  },
  {
    name = "midi CC nadir point",
    default_value = 0,
    option_range = {0, "midi CC zenith point"},
    option_step_value = 1,
    extended_only = true,
    midi_only = true,
  },
  { name = "OPTION_SPACER", crow_only = true },
  {
    name = "crow output",
    default_value = 0,
    option_range = {0, 4},
    option_step_value = 1,
    formatter = zero_is_none_formatter,
    crow_only = true,
  },
  {
    name = "crow output mode",
    default_value = 1,
    options = {"voltage", "trigger", "gate"},
    crow_only = true,
  },
  {
    name = "zenith crow voltage",
    default_value = 8.0,
    option_range = {-5.0, 10.0},
    option_step_value = 0.01,
    crow_only = true,
  },
  {
    name = "nadir crow voltage",
    default_value = 0.0,
    option_range = {-5.0, 10.0},
    option_step_value = 0.01,
    crow_only = true,
  },
  {
    name = "crow voltage slew",
    default_value = -0.01,
    option_range = {-0.01, 5.0},
    option_step_value = 0.01,
    formatter = negative_is_auto_formatter,
    extended_only = true,
    crow_only = true,
  },
  {
    name = "crow zenith point",
    default_value = 14,
    option_range = {"crow nadir point", 14},
    option_step_value = 1,
    extended_only = true,
    crow_only = true,
  },
  {
    name = "crow nadir point",
    default_value = 0,
    option_range = {0, "crow zenith point"},
    option_step_value = 1,
    extended_only = true,
    crow_only = true,
  },
  {
    name = "crow t/g threshold",
    default_value = 1,
    option_range = {0, 14},
    option_step_value = 1,
    formatter = zero_is_none_formatter,
    crow_only = true,
  },
}


function file_select_finished_callback(full_file_path)
  file_select_active = false
  if full_file_path ~= "cancel" then
    load_sound_folder(full_file_path)
  end

  exit_meta_mode()
end

function load_sound_folder(full_file_path)
  softcut.buffer_clear_channel(1)
  sample_details = {}
  next_sample_start_location = 1.0

  folder, _ = split_file_path(full_file_path)
  last_folder_loaded = folder

  for _, filename in pairs(util.scandir(folder)) do
    filename_lower = filename:lower()

    if string.find(filename_lower, ".wav") or string.find(filename_lower, ".aif") or string.find(filename_lower, ".aiff") then
      load_sound(folder .. filename)
    end
  end

  update_sound_options()
  refresh_buoy_sounds()
end

function refresh_buoy_sounds()
  for x = 1, g.cols do
    for y = 1, g.rows do
      if buoys[y][x] then
        buoys[y][x]:update_sound()
      end
    end
  end
end

function load_sound(full_file_path)
  local _, samples, sample_rate = audio.file_info(full_file_path)
  local sample_duration = samples / sample_rate
  if sample_rate ~= 48000 then
    sample_rate_warning_countdown = 30
    return
  end

  if (next_sample_start_location + sample_duration) > softcut.BUFFER_SIZE then
    return
  end

  softcut.buffer_read_mono(full_file_path, 0, next_sample_start_location, -1, 1, 1)
  _, filename = split_file_path(full_file_path)
  details = {
    name = filename,
    duration = sample_duration,
    start_location = next_sample_start_location,
  }
  table.insert(sample_details, details)

  next_sample_start_location = util.round_up(
    next_sample_start_location + sample_duration + SAMPLE_SPACING_BUFFER_TIME)
end

function split_file_path(full_file_path)
  local split_at = string.match(full_file_path, "^.*()/")
  local folder = string.sub(full_file_path, 1, split_at)
  local file = string.sub(full_file_path, split_at + 1)
  return folder, file
end

function split_file_extension(filename)
  local split_at = string.match(filename, "^.*()%.")
  local name_without_extension = string.sub(filename, 1, split_at - 1)
  local extension = string.sub(filename, split_at + 1)
  return name_without_extension, extension
end

function update_sound_options()
  all_buoy_options[1].option_range = {0, #sample_details}
end

function any_sounds_loaded()
  return #sample_details > 0
end

function buoy_options()
  show_extended_params = params:get("extended_buoy_params") == 2
  show_sound_params = any_sounds_loaded()
  show_midi_params = params:get("midi_buoy_params") == 2
  show_crow_params = norns.crow.connected()

  result = {}

  for i = 1, #all_buoy_options do
    include_option = true

    if all_buoy_options[i].extended_only then
      include_option = include_option and show_extended_params
    end

    if all_buoy_options[i].sound_only then
      include_option = include_option and show_sound_params
    end

    if all_buoy_options[i].midi_only then
      include_option = include_option and show_midi_params
    end

    if all_buoy_options[i].crow_only then
      include_option = include_option and show_crow_params
    end

    if include_option then
      table.insert(result, all_buoy_options[i])
    end
  end

  return result
end

a = arc.connect()
for i = 1, 4 do
  g = grid.connect(i)
  if g.cols > 0 then
    break
  end
end

function init()
  init_all(true)

end

function init_all(full)
  if full then
    init_params()
  end

  -- set an initial value for dispersion_shadow_param
  dispersion_updated_action(params:get("dispersion"))

  particles = {}
  pilings = fresh_grid(0)
  buoys = fresh_grid(nil)

  held_grid_keys = fresh_grid(0)

  run = true
  displaying_buoys = false
  advance_time_dirty = false
  num_tide_shapes_in_sequence = 1
  init_tide_shapes()
  tide_gap = TIDE_GAP
  tide_advance_time = ADVANCE_TIME
  smoothing_factor = SMOOTHING_FACTOR
  current_tide_delta = tide_advance_time / smoothing_factor
  all_buoy_options = ALL_BUOY_OPTIONS
  sample_details = {}
  buoy_editing_option_scroll_index = first_buoy_option_index()

  old_grid_lighting = fresh_grid(params:get("min_bright"))
  new_grid_lighting = fresh_grid(params:get("min_bright"))
  tide_depths = fresh_grid(0)
  current_angle_gaps = nil
  update_angle_gaps()
  tide_interval_counter = 0
  smoothing_counter = 0
  tide_info_overlay_countdown = 0
  sample_rate_warning_countdown = 0
  external_clock_warning_countdown = 0
  external_clock_warning_details = {}
  key_states = {0, 0, 0}
  was_editing_tides = false
  meta_mode = false
  meta_mode_option_index = 1
  file_select_active = false
  insanity_mode = false
  crow_known_to_be_connected = norns.crow.connected()
  external_clock_multiplier = 1
  dispersion_ui_brightnesses = {}

  for i = 1, 64 do
    dispersion_ui_brightnesses[i] = 0
  end
  -- respect initial reverb settings if already set
  rev_cut_input = params:get("rev_cut_input")
  rev_return_level = params:get("rev_return_level")

  init_softcut()
  init_crow()
  init_midi_in()
  init_preset_selections()

  autosave_metro_first_run = true
  if full then
    tide_maker = metro.init(smoothly_make_tides, current_tide_delta)
    tide_maker:start()
    background_metro = metro.init(background_metro_tasks, BACKGROUND_METRO_TIME)
    background_metro:start()
    autosave_metro = metro.init(autosave_tasks, AUTOSAVE_METRO_TIME)
    autosave_metro:start()
  end
end

function init_tide_shapes()
  tide_shapes = BASE_TIDE_SHAPES_8
  if g.rows == 16 then
    tide_shapes = BASE_TIDE_SHAPES_16
  end
end

function init_preset_selections()
  current_preset_selection = { x=1, y=1 }
  existing_saved_presets = fresh_grid(nil)

  for _, data_file in pairs(util.scandir(norns.state.data)) do
    _, _, x, y = string.find(data_file, "^preset_(%d+)_(%d+).txt$")
    if x and y and tonumber(y) <= g.rows then
      existing_saved_presets[tonumber(y)][tonumber(x)] = true
    end
  end
end

function modulo_base_one(num, modulus)
  return ((num - 1) % modulus) + 1
end

function tide_shape()
  result = {}

  for shape_index = 1, num_tide_shapes_in_sequence do
    first_shape_index, interpolation_fraction = math.modf(params:get("tide_shape_index") + shape_index - 1)
    first_shape_index = modulo_base_one(first_shape_index, g.rows)
    second_shape_index = modulo_base_one(first_shape_index + 1, g.rows)
    first_shape = tide_shapes[first_shape_index]
    second_shape = tide_shapes[second_shape_index]

    for i = 1, g.rows do
      result_index = i + ((shape_index - 1) * g.rows)
      first_shape_part = first_shape[i] * (1 - interpolation_fraction)
      second_shape_part = second_shape[i] * interpolation_fraction
      result[result_index] = util.round(first_shape_part + second_shape_part)
    end
  end

  return result
end

function update_dispersion_param()
  -- dead zone
  if math.abs(dispersion_shadow_param) < 250 then
    new_dispersion = 0
  elseif dispersion_shadow_param > 0 then
    new_dispersion = (dispersion_shadow_param - 250) / 100
  else
    new_dispersion = (dispersion_shadow_param + 250) / 100
  end

  if params:get("dispersion") ~= new_dispersion then
    params:set("dispersion", new_dispersion)
  end
end

function buoy_params_changed_action(_val)
  buoy_editing_option_scroll_index = first_buoy_option_index()
end

function dispersion_updated_action(dispersion)
  if dispersion == 0 then
    dispersion_shadow_param = 0
  elseif dispersion > 0 then
    dispersion_shadow_param = (dispersion * 100) + 250
  else
    dispersion_shadow_param = (dispersion * 100) - 250
  end
end

function crow_input_1_updated_action(mode_index)
  input_2_mode = params:get("crow_input_2")

  -- don't allow both crow inputs to be set to the same mode, except "none"
  if (mode_index ~= 1) and (mode_index == input_2_mode) then
    if mode_index < crow_input_1_previous_mode then
      -- going down
      if mode_index - 1 >= 1 then
        mode_index = mode_index - 1
      else
        mode_index = mode_index + 1
      end
    else
      -- going up
      if mode_index + 1 <= #CROW_INPUT_OPTIONS then
        mode_index = mode_index + 1
      else
        mode_index = mode_index - 1
      end
    end

    params:set("crow_input_1", mode_index)
  end

  if mode_index <= 5 then
    crow.input[1].mode("change", 4.5, 0.25, "both")
  else
    crow.input[1].mode("stream", 0.1)
  end

  crow_input_1_previous_mode = mode_index
end

function crow_input_2_updated_action(mode_index)
  input_1_mode = params:get("crow_input_1")

  -- don't allow both crow inputs to be set to the same mode, except "none"
  if (mode_index ~= 1) and (mode_index == input_1_mode) then
    if mode_index < crow_input_2_previous_mode then
      -- going down
      if mode_index - 1 >= 1 then
        mode_index = mode_index - 1
      else
        mode_index = mode_index + 1
      end
    else
      -- going up
      if mode_index + 1 <= #CROW_INPUT_OPTIONS then
        mode_index = mode_index + 1
      else
        mode_index = mode_index - 1
      end
    end

    params:set("crow_input_2", mode_index)
  end

  if mode_index <= 5 then
    crow.input[2].mode("change", 4.5, 0.25, "both")
  else
    crow.input[2].mode("stream", 0.1)
  end

  crow_input_2_previous_mode = mode_index
end

function max_depth_updated_action(max_depth)
  -- as a side effect of recomputing depths, particles_to_tide_depths will clear excess particles
  particles_to_tide_depths()

  for i = 1, g.rows do
    for j = 1, g.rows do
      tide_shapes[i][j] = math.min(tide_shapes[i][j], max_depth)
    end
  end

  for i = 1, #all_buoy_options do
    buoy_option = all_buoy_options[i]
    if string.find(buoy_option.name, "zenith point") then
      buoy_option.option_range[2] = max_depth
    end
  end

  for x = 1, g.cols do
    for y = 1, g.rows do
      if buoys[y][x] then
        for option_name, option_value in pairs(buoys[y][x].options) do
          if string.find(option_name, "zenith point") then
            new_zenith_point = math.min(option_value, max_depth)
            buoys[y][x]:update_option(option_name, new_zenith_point)
          elseif string.find(option_name, "nadir point") then
            new_nadir_point = math.min(option_value, max_depth - 1)
            buoys[y][x]:update_option(option_name, new_nadir_point)
          end
        end
      end
    end
  end
end

function add_channel_style_param(pset)
  pset:add{ type = "option", id = "channel_style", name = "channel style", options = { "open", "flume" } }
end

function init_params()
  params:add_group("BUOYS", 18)

  add_channel_style_param(params)
  params:add{ type = "option", id = "extended_buoy_params", name = "extended buoy params", options = { "off", "on" },
              action = buoy_params_changed_action }
  params:add{ type = "option", id = "midi_buoy_params", name = "midi buoy params", options = { "off", "on" },
              default = 2, action = buoy_params_changed_action }
  params:add{ type = "option", id = "smoothing", name = "visual smoothing", options = { "off", "on" }, default = 2 }
  params:add{ type = "option", id = "pausing", name = "tides paused", options = { "pause buoys", "continue" } }
  params:add{ type = "option", id = "unpausing", name = "tides unpaused", options = { "resume", "reset buoys" } }
  params:add_separator("arc_params", "arc params")
  params:add_control("tide_height_multiplier", "tide height multiplier", controlspec.new(0.0, 1.0, "lin", 0.01, 1.0, nil))
  params:add_control("tide_shape_index", "tide shape index", controlspec.new(1.0, g.rows + 0.99, "lin", 0.01, 1.0, nil))
  params:add{ type = "number", id = "angle", name = "wave angle", min = -60, max = 60, default = 0, formatter = degree_formatter }
  params:add{ type = "number", id = "dispersion", name = "dispersion", min = -25, max = 25, default = 10, action = dispersion_updated_action }
  params:add_separator("crow_params", "crow")
  params:add{ type = "option", id = "crow_input_1", name = "crow input 1", options = CROW_INPUT_OPTIONS,
              action = crow_input_1_updated_action, default = 2 }
  params:add{ type = "option", id = "crow_input_2", name = "crow input 2", options = CROW_INPUT_OPTIONS,
              action = crow_input_2_updated_action }
  params:add_separator("other_params", "other")
  params:add{ type = "number", id = "min_bright", name = "background brightness", min = 1, max = 3, default = 1 }
  params:add{ type = "number", id = "max_depth", name = "max depth", min = 8, max = 14, default = 14, action = max_depth_updated_action }
  params:add{ type = "option", id = "arc_orientation", name = "arc orientation", options = { "horizontal", "vertical" } }

  crow_input_1_previous_mode = params:get("crow_input_1")
  crow_input_2_previous_mode = params:get("crow_input_2")
end



function force_tide_update_next_tick()
  smoothing_counter = smoothing_factor - 1
end

function toggle_tides_paused()
  if run then
    pause_tides()
  else
    unpause_tides()
  end
end

function pause_tides()
  if not run then
    return
  end

  run = false

  for i = 1, softcut.VOICE_COUNT do
    if params:get("pausing") == 1 then  -- pause buoys
      buoy = buffer_buoy_map[i]
      if buoy and buoy.active and buoy:currently_playing() then
        softcut.play(i, 0)
        paused_buffers[i] = true
      end
    end
    -- if the pausing option is set to "continue", do nothing.
    -- voices will continue playing until they reach their endpoints,
    -- or continue indefinitely if they are set to loop.
  end
end

function unpause_tides()
  if run then
    return
  end

  recently_unpaused = true
  run = true

  for i = 1, softcut.VOICE_COUNT do
    -- if the unpausing option is set to "resume", do nothing.
    -- voices that were paused will resume where they were and voices that
    -- were still playing will continue playing, unaffected.
    if params:get("unpausing") == 2 then  -- reset buoys
      buoy = buffer_buoy_map[i]
      if buoy and buoy.active and buoy:currently_playing() then
        buoy:reset_playhead()
      end
    end

    if paused_buffers[i] then
      softcut.play(i, 1)
      paused_buffers[i] = false
    end
  end
end

function process_midi_input(data)
  -- crow sync takes priority over midi sync, since it's generally easier
  -- to unpatch the crow clock input than disable midi clock
  if crow_clock_received_recently() then
    return
  end

  midi_msg = midi.to_msg(data)
  if midi_msg.type == "clock" then
    process_midi_clock()
  elseif midi_msg.type == "start" or midi_msg.type == "continue" then
    midi_clock_era_counter = 0
    last_midi_clock_era_began = util.time()
    unpause_tides()
  elseif midi_msg.type == "stop" then
    init_midi_in()
    pause_tides()
  end
end

function process_midi_clock()
  current_time = util.time()
  last_midi_clock_received = current_time

  if not last_midi_clock_era_began then
    last_midi_clock_era_began = current_time
    return
  end

  midi_clock_era_counter = midi_clock_era_counter + 1
  if midi_clock_era_counter % NUM_MIDI_CLOCKS_PER_CHECK ~= 0 then
    return
  end

  -- restore maximum synchronicity after unpausing, but only once
  -- we have a relatively stable clock
  if recently_unpaused and midi_clock_era_counter > 100 then
    recently_unpaused = false
    force_tide_update_next_tick()
  end

  -- we assume midi clocks are all using 24 PPQN
  expected_tick_time = (tide_advance_time * external_clock_multiplier) / 24
  expected_time = last_midi_clock_era_began + (expected_tick_time * midi_clock_era_counter)
  drift = current_time - expected_time

  -- clock timing can be imprecise - tracking drift strikes a compromise between quickly
  -- adapting to changes in clock rate and making too many updates to the tide_maker metro,
  -- which has it's own disadvantages
  if math.abs(drift) < ACCEPTABLE_CLOCK_DRIFT_MIDI then
    if force_advance_time_update then
      set_advance_time_with_external_clocks()
    end

    return
  end

  clock_era_elapsed_time = current_time - last_midi_clock_era_began
  clock_delta = (clock_era_elapsed_time * 24) / midi_clock_era_counter

  midi_clock_era_counter = 0
  last_midi_clock_era_began = current_time

  set_advance_time_with_external_clocks()
end

function process_crow_first_input_change(v)
  process_crow_input_change(1, v)
end

function process_crow_second_input_change(v)
  process_crow_input_change(2, v)
end

function process_crow_input_change(idx, v)
  input_mode = params:get("crow_input_"..idx)

  if input_mode == 2 and v == 1 then  -- clock
    process_crow_clock()
  elseif input_mode == 3 then  -- run
    if v == 0 then
      pause_tides()
    else
      unpause_tides()
    end
  elseif input_mode == 4 and v == 1 then  -- start/stop
    toggle_tides_paused()
  elseif input_mode == 5 and v == 1 then  -- reset
    reset_tides()
  end
end

function process_crow_first_input_stream(v)
  process_crow_input_stream(1, v)
end

function process_crow_second_input_stream(v)
  process_crow_input_stream(2, v)
end

function process_crow_input_stream(idx, v)
  input_mode = params:get("crow_input_"..idx)

  if input_mode == 6 then  -- cv tide height
    params:set("tide_height_multiplier", util.linlin(0.0, 5.0, 0.0, 1.0, v))
  elseif input_mode == 7 then  -- cv tide shape
    params:set("tide_shape_index", util.linlin(0.0, 5.0, 1.0, g.rows + 0.99, v))
  elseif input_mode == 8 then  -- cv tide tide angle
    params:set("angle", util.linlin(-5.0, 5.0, -60, 60, v))
  elseif input_mode == 9 then  -- cv dispersion
    params:set("dispersion", util.linlin(-5.0, 5.0, -25, 25, v))
  end
end

function process_crow_clock()
  -- restore maximum synchronicity after unpausing
  if recently_unpaused and crow_clock_era_counter > 100 then
    recently_unpaused = false
    force_tide_update_next_tick()
  end

  current_time = util.time()
  last_crow_clock_received = current_time

  if not last_crow_clock_era_began then
    last_crow_clock_era_began = current_time
    return
  end

  crow_clock_era_counter = crow_clock_era_counter + 1

  if crow_clock_era_counter % NUM_CROW_CLOCKS_PER_CHECK ~= 0 then
    return
  end

  expected_tick_time = tide_advance_time * external_clock_multiplier
  expected_time = last_crow_clock_era_began + (expected_tick_time * crow_clock_era_counter)
  drift = current_time - expected_time

  -- clock timing can be imprecise - tracking drift strikes a compromise between quickly
  -- adapting to changes in clock rate and making too many updates to the tide_maker metro,
  -- which has it's own disadvantages
  if math.abs(drift) < ACCEPTABLE_CLOCK_DRIFT_CROW then
    if force_advance_time_update then
      set_advance_time_with_external_clocks()
    end

    return
  end

  clock_era_elapsed_time = current_time - last_crow_clock_era_began
  clock_delta = clock_era_elapsed_time / crow_clock_era_counter

  crow_clock_era_counter = 0
  last_crow_clock_era_began = current_time

  set_advance_time_with_external_clocks()
end

function set_advance_time_with_external_clocks()
  force_advance_time_update = false
  new_tide_advance_time = clock_delta / external_clock_multiplier
  if new_tide_advance_time < MIN_TIDE_ADVANCE_TIME then
    max_allowable_clock_multiplier = math.floor(clock_delta / MIN_TIDE_ADVANCE_TIME)
    if max_allowable_clock_multiplier >= 1 then
      external_clock_multiplier = max_allowable_clock_multiplier
    end

    external_clock_warning_countdown = 50
    external_clock_warning_details = {
      new_tide_advance_time = new_tide_advance_time,
      max_allowable_clock_multiplier = max_allowable_clock_multiplier,
    }
  else
    external_clock_warning_countdown = math.min(external_clock_warning_countdown, 20)
    force_tide_update_next_tick()
    tide_advance_time = new_tide_advance_time
    update_tide_maker_metro()
  end

  redraw()
end

function init_midi_in()
  force_advance_time_update = false
  last_midi_clock_received = nil
  last_midi_clock_era_began = nil
  midi_clock_era_counter = 0
  midi_object = midi.connect()
  midi_object.event = process_midi_input
end

function init_crow()
  force_advance_time_update = false
  last_crow_clock_received = nil
  last_crow_clock_era_began = nil
  crow_clock_era_counter = 0
  crow.input[1].change = process_crow_first_input_change
  crow.input[2].change = process_crow_second_input_change
  crow.input[1].stream = process_crow_first_input_stream
  crow.input[2].stream = process_crow_second_input_stream

  if params:get("crow_input_1") <= 5 then
    crow.input[1].mode("change", 4.5, 0.25, "both")
  else
    crow.input[1].mode("stream", 0.1)
  end

  if params:get("crow_input_2") <= 5 then
    crow.input[2].mode("change", 4.5, 0.25, "both")
  else
    crow.input[2].mode("stream", 0.1)
  end
end

function softcut_event_phase_callback(voice, phase)
  buoy = buffer_buoy_map[voice]

  -- this generally shouldn't happen but could under certain
  -- circumstances such as right after switching apps
  if not buoy then
    return
  end

  if buoy:is_looping() then
    return
  end

  if buoy.loop_end_time - phase < 0.02 then
    buoy.playing = false
  end
end

function init_softcut()
  softcut.buffer_clear()
  buffer_buoy_map = {}
  paused_buffers = {}

  for i = 1, softcut.VOICE_COUNT do
    softcut.enable(i, 1)
    softcut.play(i, 0)
    softcut.buffer(i, 1)
    softcut.level(i, 1.0)
    softcut.loop(i, 0)
    softcut.rate(i, 1.0)
    softcut.post_filter_dry(i, 0.0)
    softcut.post_filter_lp(i, 1.0)
    softcut.post_filter_fc(i, 20000.0)
    buffer_buoy_map[i] = nil
    paused_buffers[i] = false

    softcut.rate_slew_time(i, 0.0)
    softcut.level_slew_time(i, ADVANCE_TIME)
    softcut.pan_slew_time(i, ADVANCE_TIME)
    softcut.phase_quant(i, 0.01)
  end

  softcut.event_phase(softcut_event_phase_callback)
  softcut.poll_start_phase()
end

function crow_clock_received_recently()
  if not last_crow_clock_received then
    return false
  end

  return (util.time() - last_crow_clock_received) < 3.0
end

function midi_clock_received_recently()
  if not last_midi_clock_received then
    return false
  end

  return (util.time() - last_midi_clock_received) < 3.0
end

function external_clock_received_recently()
  return crow_clock_received_recently() or midi_clock_received_recently()
end

function autosave_tasks()
  -- don't autosave on the first run. that way when you initially load the app
  -- we don't overwrite the autosave from before (which would defeat the purpose)
  if autosave_metro_first_run then
    autosave_metro_first_run = false
    return
  end

  save_autosave_preset()
end

function background_metro_tasks()
  update_held_grid_keys()
  update_dispersion_ui()
  tide_info_overlay_expiring = tide_info_overlay_countdown == 1
  tide_info_overlay_countdown = math.max(tide_info_overlay_countdown - 1, 0)

  sample_rate_warning_expiring = sample_rate_warning_countdown == 1
  sample_rate_warning_countdown = math.max(sample_rate_warning_countdown - 1, 0)

  external_clock_warning_expiring = external_clock_warning_countdown == 1
  external_clock_warning_countdown = math.max(external_clock_warning_countdown - 1, 0)

  -- if a crow has just recently been connected, we need to manually set its
  -- callbacks. if it has just been disconnected, we should reset our timers
  -- and counters.
  if crow_known_to_be_connected ~= norns.crow.connected() then
    crow_known_to_be_connected = norns.crow.connected()
    init_crow()
  end

  -- besides disconnections, if we haven't received clocks from crow (or midi)
  -- for a while, we should throw out any old data we were keeping on them so
  -- nothing weird happens if we start getting them again.
  if last_crow_clock_received and not crow_clock_received_recently() then
    init_crow()
  end
  if last_midi_clock_received and not midi_clock_received_recently() then
    init_midi_in()
  end

  if advance_time_dirty then
    -- updating this synchronously instead of in a background process makes
    -- the waves appear to slow/stop while the rate is being changed because
    -- each update resets the metro
    update_tide_maker_metro()
  end

  if tide_info_overlay_expiring or sample_rate_warning_expiring or external_clock_warning_expiring then
    redraw()
  end
end

function mark_buoy_being_edited(x, y)
  if not buoys[y][x] then
    buoys[y][x] = Buoy:new()

    -- if newly creating a buoy, and there is another buoy also being edited which
    -- serves as the prototype (i.e. its key was pressed first), copy the attributes
    -- of the original to this new buoy
    if buoy_editing_prototype then
      for k, v in pairs(buoy_editing_prototype.options) do
        buoys[y][x]:update_option(k, v)
      end
    end
  end

  buoys[y][x].being_edited = true
  if not is_piling(x, y) then
    buoys[y][x]:activate()
  end
end

function update_held_grid_keys()
  -- if we're editing tide shapes we don't want to trigger buoy editing
  if editing_tide_shapes() then
    return
  end

  keys_held = grid_keys_held()
  newly_editing_buoys = false
  clear_grid = false

  for _, key_held in pairs(keys_held) do
    x, y = key_held[1], key_held[2]
    if editing_buoys() then
      mark_buoy_being_edited(x, y)
      clear_grid = true
    else
      held_grid_keys[y][x] = held_grid_keys[y][x] + 1
      if held_grid_keys[y][x] > (LONG_PRESS_TIME / BACKGROUND_METRO_TIME) then
        newly_editing_buoys = true
        longest_held_key = {x, y}
        clear_grid = true
        break
      end
    end
  end

  if clear_grid then
    held_grid_keys = fresh_grid(0)
  end

  if newly_editing_buoys then
    -- we attempt to load buoy_editing_prototype twice so that it can be used for copying
    -- in mark_buoy_being_edited (when there may or may not already be a prototype to copy),
    -- and also elsewhere (when there *must* be a prototype)
    buoy_editing_prototype = buoys[longest_held_key[2]][longest_held_key[1]]
    for _, key_held in pairs(keys_held) do
      x, y = key_held[1], key_held[2]
      mark_buoy_being_edited(x, y)
    end
    buoy_editing_prototype = buoys[longest_held_key[2]][longest_held_key[1]]

    redraw()
  end
end

function update_dispersion_ui()
  for i = 1, 64 do
    if flip_coin(dispersion_factor()) then
      dispersion_ui_brightnesses[i] = negative_dispersion() and 1 or MAX_BRIGHTNESS
    else
      current_brightness = dispersion_ui_brightnesses[i]

      if negative_dispersion() then
        if current_brightness == 0 or current_brightness == MAX_BRIGHTNESS then
          new_brightness = 0
        else
          new_brightness = current_brightness + 1
        end
      else
        new_brightness = math.max(current_brightness - 1, 0)
      end

      dispersion_ui_brightnesses[i] = new_brightness
    end
  end
end

function editing_buoys()
  for x = 1, g.cols do
    for y = 1, g.rows do
      if buoys[y][x] and buoys[y][x].being_edited then
        return true
      end
    end
  end

  return false
end

function editing_tide_shapes()
  return key_states[2] == 1 and key_states[3] == 1
end

function grid_keys_held()
  result = {}
  for x = 1, g.cols do
    for y = 1, g.rows do
      if held_grid_keys[y][x] > 0 then
        table.insert(result, {x, y})
      end
    end
  end

  return result
end

function update_tide_maker_metro()
  for x = 1, g.cols do
    for y = 1, g.rows do
      if buoys[y][x] then
        buoys[y][x]:update_volume_slew()
        buoys[y][x]:update_pan_slew()
        buoys[y][x]:update_rate_slew()
      end
    end
  end

  smoothing_factor = util.clamp(util.round(tide_advance_time * 20), 2, 8)
  smoothing_counter = math.min(smoothing_counter, smoothing_factor - 1)
  current_tide_delta = tide_advance_time / smoothing_factor
  tide_maker:start(current_tide_delta)
  advance_time_dirty = false
end

function clear_inactive_buoys()
  for x = 1, g.cols do
    for y = 1, g.rows do
      if buoys[y][x] and (not buoys[y][x].active) then
        buoys[y][x] = nil
      end
    end
  end
end

function key(n, z)
  key_states[n] = z
  if save_preset_mode then
    if n == 2 and z == 0 then
      save_preset_mode = false
    end
    if n == 3 and z == 0 then
      save_preset()
      save_preset_mode = false
      meta_mode = false
    end
  elseif load_preset_mode then
    if n == 2 and z == 0 then
      load_preset_mode = false
    end
    if n == 3 and z == 0 then
      load_preset()
      load_preset_mode = false
      meta_mode = false
    end
  elseif meta_mode then
    if n == 1 and z == 1 then
      exit_meta_mode()
      return
    end

    if z == 1 or n ~= 3 then
      return
    end

    meta_mode_option = META_MODE_OPTIONS[meta_mode_option_index]

    if meta_mode_option == "choose sample folder" then
      file_select_active = true
      fileselect.enter(_path.audio, file_select_finished_callback)
    elseif meta_mode_option == "clear inactive buoys" then
      clear_inactive_buoys()
      exit_meta_mode()
    elseif meta_mode_option == "save preset" then
      load_preview_data()
      save_preset_mode = true
    elseif meta_mode_option == "load preset" then
      load_preview_data()
      load_preset_mode = true
    elseif meta_mode_option == "exit" then
      exit_meta_mode()
    end
  else
    if n == 1 and z == 1 then
      meta_mode = true
      redraw()
    end

    if z == 0 and not was_editing_tides then
      if n == 2 then
        displaying_buoys = not displaying_buoys
      elseif n == 3 then
        toggle_tides_paused()
      end
    end

    if key_states[2] == 0 and key_states[3] == 0 then
      was_editing_tides = false
    end

    redraw_lights()
  end
end

function preset_filename()
  return "preset_"..current_preset_selection.x.."_"..current_preset_selection.y..".txt"
end

function save_autosave_preset()
  pset_number = 144  -- 8 * 16 + 16
  params:write(pset_number, "autosave")

  tab.save(save_data(), norns.state.data.."preset_16_8.txt")
  existing_saved_presets[8][16] = true
end

function save_preset()
  pset_number = current_preset_selection.y * 16 + current_preset_selection.x
  params:write(pset_number, preset_name())

  tab.save(save_data(), norns.state.data..preset_filename())
  existing_saved_presets[current_preset_selection.y][current_preset_selection.x] = true
end

function save_data()
  return {
    buoys=buoys,
    pilings=pilings,
    tide_gap=tide_gap,
    tide_advance_time=tide_advance_time,
    external_clock_multiplier=external_clock_multiplier,
    tide_shapes=tide_shapes,
    num_tide_shapes_in_sequence=num_tide_shapes_in_sequence,
    last_folder_loaded=last_folder_loaded,
  }
end

function load_preset()
  preset_exists = util.file_exists(norns.state.data..preset_filename())
  if preset_exists then
    load_data = tab.load(norns.state.data..preset_filename())
    pset_number = current_preset_selection.y * 16 + current_preset_selection.x
    params:read(pset_number)
  end

  cps = current_preset_selection
  init_all(false)
  current_preset_selection = cps

  if not preset_exists then
    return
  end

  pilings = fresh_grid(0)
  for x = 1, g.cols do
    for y = 1, g.rows do
      if load_data.pilings[y] then
        pilings[y][x] = load_data.pilings[y][x]
      end
    end
  end
  tide_gap = load_data.tide_gap
  tide_advance_time = load_data.tide_advance_time
  external_clock_multiplier = load_data.external_clock_multiplier
  init_tide_shapes()
  for i = 1, g.rows do
    for j = 1, g.rows do
      if load_data.tide_shapes[i] and load_data.tide_shapes[i][j] then
        tide_shapes[i][j] = load_data.tide_shapes[i][j]
      end
    end
  end
  num_tide_shapes_in_sequence = math.min(load_data.num_tide_shapes_in_sequence, g.rows)
  if load_data.last_folder_loaded then
    load_sound_folder(load_data.last_folder_loaded)
  end

  for x = 1, g.cols do
    for y = 1, g.rows do
      buoy_data = nil
      if load_data.buoys[y] then
        buoy_data = load_data.buoys[y][x]
      end

      if buoy_data then
        buoys[y][x] = Buoy:new()
        buoys[y][x].active = buoy_data.active
        for k, v in pairs(buoy_data.options) do
          -- sound index could change or go away if the folder is edited
          if k == "sound" then
            sound_index = 0
            for i, detail in pairs(sample_details) do
              if detail.name == buoy_data.sample_name then
                sound_index = i
                break
              end
            end
            v = sound_index
          end

          buoys[y][x]:update_option(k, v)
        end
      end
    end
  end
end

function exit_meta_mode()
  meta_mode = false
  meta_mode_option_index = 1
  redraw()
end

function displaying_tide_info_overlay()
  return tide_info_overlay_countdown > 0
end

function displaying_sample_rate_warning()
  return sample_rate_warning_countdown > 0
end

function displaying_external_clock_warning()
  return external_clock_warning_countdown > 0
end

function process_reverb_enc(d)
  if (params:get("rev_cut_input") == -9.0) and d < 0 then
    params:set("reverb", 1)
  else
    params:set("reverb", 2)
    params:set("rev_cut_input", util.clamp(params:get("rev_cut_input"), -9.0, 3.0) + d * 0.1)
  end
end

function first_buoy_option_index()
  first_option = buoy_options()[1]
  if first_option and (first_option.name == "OPTION_SPACER") then
    return 2
  end

  return 1
end

function enc(n, d)
  if n == 1 then
    process_reverb_enc(d)
    return
  end

  if selecting_preset() then
    return
  end

  if meta_mode then
    if n == 2 then
      meta_mode_option_index = util.clamp(meta_mode_option_index + d, 1, #META_MODE_OPTIONS)
    end
  elseif editing_buoys() then
    if n == 2 then
      buoy_editing_option_scroll_index = util.clamp(buoy_editing_option_scroll_index + d, first_buoy_option_index(), #buoy_options())
    end

    if n == 3 then
      edit_buoys(d)
    end
  else
    if n == 2 then
      tide_info_overlay_countdown = 10

      if external_clock_received_recently() then
        external_clock_multiplier = util.clamp(external_clock_multiplier + d, 1, 8)
        -- rather than updating right away, wait until the next clock tick so that
        -- the metro is synced to the clock signal as well as possible
        force_advance_time_update = true
      else
        tide_advance_time = util.round(math.max(tide_advance_time + d * 0.001, MIN_TIDE_ADVANCE_TIME), 0.001)
        advance_time_dirty = true
      end
    end
    if n == 3 then
      tide_info_overlay_countdown = 10
      tide_gap = math.max(tide_gap + d, 1)
    end
  end

  redraw()
end

function edit_buoys(d)
  option_config = buoy_options()[buoy_editing_option_scroll_index]
  if (not option_config) or (option_config.name == "OPTION_SPACER") then
    return
  end

  old_value = buoy_editing_prototype.options[option_config.name]
  if option_config.option_range then
    range_min = option_config.option_range[1]
    range_max = option_config.option_range[2]
    step_value = option_config.option_step_value or 1

    -- ranges can be defined in terms of other option values, this is useful
    -- for setting zenith/nadir points and other applications
    if type(range_min) == "string" then
      range_min = buoy_editing_prototype.options[range_min] + step_value
    end
    if type(range_max) == "string" then
      range_max = buoy_editing_prototype.options[range_max] - step_value
    end

    new_value = util.clamp(old_value + (d * option_config.option_step_value), range_min, range_max)
  else
    new_value = util.clamp(old_value + d, 1, #option_config.options)
  end

  for x = 1, g.cols do
    for y = 1, g.rows do
      if buoys[y][x] and buoys[y][x].being_edited then
        buoys[y][x]:update_option(option_config.name, new_value)
      end
    end
  end
end

function smoothly_make_tides()
  if run then
    smoothing_counter = (smoothing_counter + 1) % smoothing_factor
    -- splitting make_tides() into two parts helps the appearance of
    -- smoothness by splitting up the most time-intensive steps.
    -- we could split it further but currently smoothing_factor
    -- bottoms out at 2.
    if smoothing_counter == 0 then
      make_tides_part_1()
      update_buoy_depths()
    end

    if smoothing_counter == util.round(smoothing_factor / 2) then
      make_tides_part_2()
    end

    if params:get("smoothing") == 2 or smoothing_counter == 0 then
      redraw_lights()
    end
  else
    if meta_mode then
      redraw_lights()
    end
  end

  redraw()
end

function selecting_preset()
  return save_preset_mode or load_preset_mode
end

function reset_tides()
  particles = {}
  tide_interval_counter = 0
  force_tide_update_next_tick()
end

function update_buoy_depths()
  for x = 1, g.cols do
    for y = 1, g.rows do
      if buoys[y][x] then
        buoys[y][x]:update_depth(tide_depths[y][x])
      end
    end
  end
end

function make_tides_part_1()
  roll_forward()
  update_angle_gaps()

  if tide_interval_counter >= tide_gap then
    tide_interval_counter = 1
  else
    tide_interval_counter = tide_interval_counter + 1
  end

  new_tide(tide_interval_counter)

  velocity_averaging()
  particles_to_tide_depths()
  old_grid_lighting = deep_copy(new_grid_lighting)
  tide_depths_to_lighting()
end

function make_tides_part_2()
  disperse()
end

function choose_clumping_factor()
  num_particles = #particles

  if num_particles > 500 then
    return 4
  elseif num_particles > 400 then
    return 3
  elseif num_particles > 300 then
    return 2
  end

  return 1
end

function new_tide(position)
  -- to avoid overloading the processor when a very high number of particles are
  -- being produced, start to "clump" particles together to reduce the number of
  -- calculations needing to be performed later on
  clumping_factor = choose_clumping_factor()

  for y = 1, g.rows do
    tide_index = modulo_base_one(position - current_angle_gaps[y], tide_gap)
    if insanity_mode then
      num_new_particles = tide_shapes[y][tide_index] or 0
    else
      num_new_particles = tide_shape()[tide_index] or 0
    end
    num_new_particles = util.round(num_new_particles * params:get("tide_height_multiplier"))

    if not is_piling(1, y) then
      while num_new_particles > 0 do
        particle = {}
        particle.x_pos = 1
        particle.x_vel = 1.0
        particle.y_pos = y
        particle.y_vel = 0.0
        particle.clump_size = math.min(num_new_particles, clumping_factor)
        num_new_particles = num_new_particles - particle.clump_size

        table.insert(particles, particle)
      end
    end
  end
end

function update_angle_gaps()
  distance = math.tan(degrees_to_radians(params:get("angle")))
  offset = math.abs(math.min(0, util.round((g.rows - 1) * distance)))

  current_angle_gaps = {}
  for i = 0, g.rows - 1 do
    table.insert(current_angle_gaps, util.round(i * distance) + offset)
  end
end

function degrees_to_radians(degrees)
  return degrees * math.pi / 180
end

-- move particles from areas of higher density to lower
-- (not allowing dispersion outside the grid)
function disperse()
  -- avoid artefacts from dispersing in any particular order
  list_shuffle(particles)
  particle_counts = fresh_grid(0)
  for _, particle in ipairs(particles) do
    x, y = particle.x_pos, particle.y_pos
    particle_counts[y][x] = particle_counts[y][x] + particle.clump_size
  end

  for _, particle in ipairs(particles) do
    x, y = particle.x_pos, particle.y_pos
    density = particle_counts[y][x]
    narrowed_dispersion_directions = {}

    for _, direction in pairs(POTENTIAL_DISPERSION_DIRECTIONS) do
      if not is_piling(x + direction.x, y + direction.y) then
        other_density = find_in_grid(x + direction.x, y + direction.y, particle_counts, density)
        density_diff = density - other_density

        -- TODO: what if instead we kept track of all the changes that were going to happen before we applied them,
        -- so that we avoided the pointillism problem
        if negative_dispersion() then
          density_diff = -density_diff
          -- since particles above the max tide depth get thrown out, we wouldn't want to allow negative
          -- dispersion towards those because it would lead to the waves simply disappearing
          too_high = (other_density + particle.clump_size) > params:get("max_depth")
          if density_diff >= 1 and (not too_high) and flip_coin(dispersion_factor(), density_diff) then
            table.insert(narrowed_dispersion_directions, direction)
          end
        else
          if (density_diff >= (particle.clump_size * 2)) and flip_coin(dispersion_factor(), density_diff) then
            table.insert(narrowed_dispersion_directions, direction)
          end
        end
      end
    end

    if #narrowed_dispersion_directions > 0 then
      list_shuffle(narrowed_dispersion_directions)
      disperse_direction = narrowed_dispersion_directions[1]
      new_x = x + disperse_direction.x
      new_y = y + disperse_direction.y
      particle.x_pos = new_x
      particle.y_pos = new_y

      density = particle_counts[y][x]
      -- take absolute value to support negative dispersion use cases
      density_diff = math.abs(density - find_in_grid(new_x, new_y, particle_counts, density - 1))
      particle.x_vel = particle.x_vel + (disperse_direction.x * DISPERSION_VELOCITY_FACTOR * density_diff)
      particle.y_vel = particle.y_vel + (disperse_direction.y * DISPERSION_VELOCITY_FACTOR * density_diff)

      particle_counts[y][x] = particle_counts[y][x] - particle.clump_size
      particle_counts[new_y][new_x] = particle_counts[new_y][new_x] + particle.clump_size
    end
  end
end

-- advance particles based on starting velocities and collisions with pilings
function roll_forward()
  new_particles = {}
  for _, particle in ipairs(particles) do
    x, y = particle.x_pos, particle.y_pos
    x_vel, y_vel = particle.x_vel, particle.y_vel
    x_delta, y_delta = 0, 0
    x_vel_delta, y_vel_delta = 0, 0

    if flip_coin(math.abs(x_vel)) then
      x_delta = x_vel > 0 and 1 or -1

      -- x collision
      if is_piling(x + x_delta, y) then
        x_delta = 0
        xv_delta = x_vel * COLLISION_DIRECTIONAL_DAMPING * -1
        yv_delta = math.abs(xv_delta) * (1 - COLLISION_OVERALL_DAMPING)

        if flip_coin() then
          yv_delta = yv_delta * -1
        end

        x_vel_delta = x_vel_delta + xv_delta
        y_vel_delta = y_vel_delta + yv_delta
      end
    end

    if flip_coin(math.abs(y_vel)) then
      y_delta = y_vel > 0 and 1 or -1

      -- y collision
      if is_piling(x, y + y_delta) then
        y_delta = 0
        yv_delta = y_vel * COLLISION_DIRECTIONAL_DAMPING * -1
        xv_delta = math.abs(yv_delta) * (1 - COLLISION_OVERALL_DAMPING)

        if flip_coin() then
          xv_delta = xv_delta * -1
        end

        x_vel_delta = x_vel_delta + xv_delta
        y_vel_delta = y_vel_delta + yv_delta
      end
    end

    particle.x_pos = x + x_delta
    particle.y_pos = y + y_delta
    particle.x_vel = x_vel + x_vel_delta
    particle.y_vel = y_vel + y_vel_delta

    -- discard particles outside the grid
    if particle.x_pos >= 1 and particle.x_pos <= g.cols then
      if particle.y_pos >= 1 and particle.y_pos <= g.rows then
        table.insert(new_particles, particle)
      end
    end
  end

  particles = new_particles
end

function velocity_averaging()
  x_vel_sums = fresh_grid(0)
  y_vel_sums = fresh_grid(0)
  particle_counts = fresh_grid(0)
  for _, particle in ipairs(particles) do
    x, y = particle.x_pos, particle.y_pos
    x_vel_sums[y][x] = x_vel_sums[y][x] + (particle.x_vel * particle.clump_size)
    y_vel_sums[y][x] = y_vel_sums[y][x] + (particle.y_vel * particle.clump_size)
    particle_counts[y][x] = particle_counts[y][x] + particle.clump_size
  end

  for _, particle in ipairs(particles) do
    x, y = particle.x_pos, particle.y_pos
    x_vel_avg = x_vel_sums[y][x] / particle_counts[y][x]
    y_vel_avg = y_vel_sums[y][x] / particle_counts[y][x]
    x_vel_diff = x_vel_avg - particle.x_vel
    y_vel_diff = y_vel_avg - particle.y_vel

    particle.x_vel = particle.x_vel + (x_vel_diff * VELOCITY_AVERAGING_FACTOR)
    particle.y_vel = particle.y_vel + (y_vel_diff * VELOCITY_AVERAGING_FACTOR)
  end
end

function clear_particles(x, y)
  new_particles = {}

  for _, particle in ipairs(particles) do
    if particle.x_pos ~= x or particle.y_pos ~= y then
      table.insert(new_particles, particle)
    end
  end

  particles = new_particles
end

function particles_to_tide_depths()
  new_particles = {}
  tide_depths = fresh_grid(0)

  for _, particle in ipairs(particles) do
    x, y = particle.x_pos, particle.y_pos

    if tide_depths[y][x] < params:get("max_depth") then
      tide_depths[y][x] = tide_depths[y][x] + particle.clump_size
      table.insert(new_particles, particle)
    else
      -- discard excess particles
    end
  end

  particles = new_particles
end

function tide_depths_to_lighting()
  for x = 1, g.cols do
    for y = 1, g.rows do
      new_grid_lighting[y][x] = math.min(tide_depths[y][x] + params:get("min_bright"), MAX_BRIGHTNESS)
    end
  end
end

function is_piling(x, y)
  if params:get("channel_style") == 2 and (y < 1 or y > g.rows) then
    return true
  end
  return find_in_grid(x, y, pilings, 0) ~= 0
end

function add_piling(x, y)
  pilings[y][x] = 1
  clear_particles(x, y)
end

function remove_piling(x, y)
  pilings[y][x] = 0
  clear_particles(x, y)
end

function find_in_grid(x, y, grid, default)
  if not grid then
    return default
  end

  if x < 1 or x > g.cols or y < 1 or y > g.rows then
    return default
  end

  return grid[y][x]
end

function grid_transition(proportion)
  result = fresh_grid(0)

  for x = 1, g.cols do
    for y = 1, g.rows do
      lighting_difference = new_grid_lighting[y][x] - old_grid_lighting[y][x]
      result[y][x] = util.round(old_grid_lighting[y][x] + (lighting_difference * proportion))
    end
  end

  return result
end

function redraw()
  if file_select_active then
    fileselect.redraw()
    return
  end

  screen.clear()
  screen.aa(1)
  screen.font_face(1)
  screen.font_size(8)
  screen.level(MAX_BRIGHTNESS)

  if save_preset_mode then
    redraw_save_preset_mode_screen()
  elseif load_preset_mode then
    redraw_load_preset_mode_screen()
  elseif meta_mode then
    redraw_meta_mode_screen()
  elseif editing_buoys() then
    redraw_edit_buoy_screen()
  elseif displaying_tide_info_overlay() then
    redraw_tide_info_overlay()
  elseif displaying_sample_rate_warning() then
    redraw_sample_rate_warning()
  elseif displaying_external_clock_warning() then
    redraw_external_clock_warning()
  else
    redraw_regular_screen()
  end

  screen.update()
end

function draw_preset_select_background()
  if util.file_exists(norns.state.data..preset_filename()) and preview_data then
    -- draw flume edges
    if preview_params:get("channel_style") == 2 then
      redraw_flume_edges(1)
    end

    -- draw buoys and pilings
    draw_small = g.rows == 16
    for x = 1, g.cols do
      for y = 1, g.rows do
        if preview_data.pilings[y] then
          buoy_data = preview_data.buoys[y][x]
          if preview_data.pilings[y][x] == 1 then
            screen.level(1)
            if draw_small then
              draw_piling_small(x, y)
            else
              draw_piling(x, y)
            end
          elseif buoy_data and buoy_data.active then
            screen.level(2)
            if draw_small then
              draw_buoy_small(x, y, false, 2)
            else
              draw_buoy(x, y, false, 2)
            end
          end
        end
      end
    end
  end
end

function redraw_save_preset_mode_screen()
  draw_preset_select_background()
  screen.level(MAX_BRIGHTNESS)

  screen.move(64, 25)
  screen.text_center("save preset "..preset_name().."?")
  screen.move(64, 35)
  screen.text_center("K2 to cancel, K3 to confirm")
end

function redraw_load_preset_mode_screen()
  draw_preset_select_background()
  screen.level(MAX_BRIGHTNESS)

  screen.move(64, 25)
  screen.text_center("load preset "..preset_name().."?")
  screen.move(64, 35)
  screen.text_center("K2 to cancel, K3 to confirm")
end

function preset_name()
  if current_preset_selection.x == 16 and current_preset_selection.y == 8 then
    return "autosave"
  end

  return string.char(string.byte("A") + current_preset_selection.y - 1)..current_preset_selection.x
end

function redraw_meta_mode_screen()
  for option_index, option in pairs(META_MODE_OPTIONS) do
    if option_index == meta_mode_option_index then
      screen.level(MAX_BRIGHTNESS)
    else
      screen.level(5)
    end

    screen.move(15, 5 + 10 * option_index)
    screen.text(option)
  end
end

function redraw_external_clock_warning()
  if crow_clock_received_recently() then
    first_line = "crow clock received too fast"
  else
    first_line = "midi clock received too fast"
  end

  if external_clock_warning_details.max_allowable_clock_multiplier >= 1 then
    second_line = "for current clock multiplier"
    third_line = "multiplier shifted to "..external_clock_warning_details.max_allowable_clock_multiplier
  else
    second_line = "tide advance time would be"
    third_line = util.round(external_clock_warning_details.new_tide_advance_time, 0.001)..", min is ".. MIN_TIDE_ADVANCE_TIME
  end

  redraw_warning_screen(first_line, second_line, third_line)
end

function redraw_sample_rate_warning()
  first_line = "found non-48k files"
  second_line = "these files cannot"
  third_line = "be loaded"
  redraw_warning_screen(first_line, second_line, third_line)
end

function redraw_warning_screen(first_line, second_line, third_line)
  screen.font_face(7)
  screen.font_size(20)

  screen.move(64, 20)
  screen.text_center("WARNING")

  screen.font_face(1)
  screen.font_size(8)

  screen.move(64, 35)
  screen.text_center(first_line)
  screen.move(64, 50)
  screen.text_center(second_line)
  screen.move(64, 60)
  screen.text_center(third_line)
end

function redraw_tide_info_overlay()
  using_external_clock = external_clock_received_recently()
  screen.move(0, 30)
  screen.text(using_external_clock and "external clock multiplier" or "tide advance time")
  screen.move(128, 30)
  screen.text_right(using_external_clock and external_clock_multiplier or tide_advance_time)

  screen.move(0, 40)
  screen.text("tide gap")
  screen.move(128, 40)
  screen.text_right(tide_gap)
end

function redraw_edit_buoy_screen()
  height = 40 - (buoy_editing_option_scroll_index * 10)

  for option_index, option_config in pairs(buoy_options()) do
    if option_index == buoy_editing_option_scroll_index then
      screen.level(MAX_BRIGHTNESS)
    else
      screen.level(5)
    end

    screen.move(0, height)
    if option_config.name ~= "OPTION_SPACER" then
      screen.text(option_config.name)

      buoy_value = buoy_editing_prototype.options[option_config.name]
      screen.move(128, height)

      -- attempt to avoid floating point display issues
      if type(buoy_value) == "number" and (buoy_value % 1 ~= 0) then
        buoy_value = util.round(buoy_value, 0.001)
      end

      if option_config.formatter then
        option_value_text = option_config.formatter(buoy_value)
      elseif option_config.options then
        option_value_text = option_config.options[buoy_value]
      else
        option_value_text = tostring(buoy_value)
      end
      screen.text_right(option_value_text)
    end

    height = height + 10
  end
end

function redraw_regular_screen()
  if params:get("channel_style") == 2 then
    redraw_flume_edges()
  end
  screen.level(MAX_BRIGHTNESS)

  if g.rows == 8 then
    redraw_regular_screen_128()
  elseif g.rows == 16 then
    redraw_regular_screen_256()
  end
end

function redraw_regular_screen_128()
  for x = 1, g.cols do
    for y = 1, g.rows do
      if is_piling(x, y) then
        draw_piling(x, y)
      elseif buoys[y][x] and buoys[y][x].active then
        draw_buoy(x, y, buoys[y][x]:light_up())
      end
    end
  end
end

function redraw_regular_screen_256()
  for x = 1, g.cols do
    for y = 1, g.rows do
      if is_piling(x, y) then
        draw_piling_small(x, y)
      elseif buoys[y][x] and buoys[y][x].active then
        draw_buoy_small(x, y, buoys[y][x]:light_up())
      end
    end
  end
end

function draw_piling(x, y)
  screen.circle(x * 8 - 4, y * 8 - 4, 3.4)
  screen.fill()
end

function draw_piling_small(x, y)
  screen.circle(x * 4 + 30, y * 4 - 2, 1.7)
  screen.fill()
end

function draw_buoy(x, y, lit_up, dim_brightness)
  dim_brightness = dim_brightness or 5
  screen.rect(x * 8 - 7.1, y * 8 - 7.1, 6.4, 6.4)
  screen.fill()
  screen.level(0)
  screen.rect(x * 8 - 5.9, y * 8 - 5.9, 4.0, 4.0)
  screen.fill()

  level = lit_up and MAX_BRIGHTNESS or dim_brightness
  screen.level(level)
  screen.rect(x * 8 - 4.9, y * 8 - 4.9, 2.0, 2.0)
  screen.fill()

  screen.level(MAX_BRIGHTNESS)
end

function draw_buoy_small(x, y, lit_up, dim_brightness)
  dim_brightness = dim_brightness or 5
  screen.rect(x * 4 + 28.5, y * 4 - 3.5, 3.2, 3.2)
  screen.fill()
  screen.level(0)
  screen.rect(x * 4 + 29.1, y * 4 - 2.9, 2.0, 2.0)
  screen.fill()

  level = lit_up and MAX_BRIGHTNESS or dim_brightness
  screen.level(level)
  screen.rect(x * 4 + 29.6, y * 4 - 2.4, 1.0, 1.0)
  screen.fill()

  screen.level(MAX_BRIGHTNESS)
end

function redraw_flume_edges(brightness)
  brightness = brightness or MAX_BRIGHTNESS
  screen.level(brightness)
  screen.rect(0, 0, 128, 1)
  screen.fill()
  screen.rect(0, 63, 128, 1)
  screen.fill()
  screen.level(util.round(brightness / 2))
  screen.rect(0, 1, 128, 1)
  screen.fill()
  screen.rect(0, 62, 128, 1)
  screen.fill()
end

function redraw_lights()
  if editing_tide_shapes() then
    was_editing_tides = true
    redraw_grid_tide_shape_editor()
  elseif selecting_preset() then
    redraw_grid_preset_select_view()
  else
    redraw_grid_main_view()
  end

  redraw_arc_lights()
end

function redraw_arc_lights()
  a:all(0)

  orientation_offset = params:get("arc_orientation") == 1 and 0 or -16

  -- tide height multiplier
  for i = 1, 32 do
    if (params:get("tide_height_multiplier") * 32) >= i then
      a:led(1, i + 32 + orientation_offset, MAX_BRIGHTNESS)
      a:led(1, 33 - i + orientation_offset, MAX_BRIGHTNESS)
    end
  end

  -- wave shapes + interpolation
  shape = tide_shape()
  -- TODO: update this for bigger tide shapes possible on 256 grids
  for i = 1, 8 do
    for j = 1, 4 do
      a:led(2, 12 + j + (i * 4) + orientation_offset, shape[i])
      a:led(2, 16 + j - (i * 4) + orientation_offset, shape[i])
    end
  end

  -- wave angle
  led_offset = util.round((params:get("angle") / 90) * 16) + 1
  a:led(3, led_offset - 1 + orientation_offset, 5)
  a:led(3, led_offset + orientation_offset, MAX_BRIGHTNESS)
  a:led(3, led_offset + 1 + orientation_offset, 5)

  a:led(3, led_offset + 31 + orientation_offset, 5)
  a:led(3, led_offset + 32 + orientation_offset, MAX_BRIGHTNESS)
  a:led(3, led_offset + 33 + orientation_offset, 5)

  -- dispersion
  dead_zone = dispersion_factor() == 0.0
  for i = 1, 64 do
    if dead_zone then
      a:led(4, i, 1)
    else
      a:led(4, i, dispersion_ui_brightnesses[i])
    end
  end
  a:refresh()
end

function edited_shape_index()
  result = util.round(params:get("tide_shape_index"))
  return result == (g.rows + 1) and 1 or result
end

function phase_in_wrapped_range(target_index, low_index, high_index, wrap_point)
  if high_index > low_index then
    if (target_index >= low_index) and (target_index <= high_index) then
      range_size = high_index - low_index + 1
      return (target_index - low_index) / range_size
    end
  else
    if (target_index >= low_index) or (target_index <= high_index) then
      range_size = wrap_point - (low_index - high_index) + 1
      return ((target_index - low_index) % wrap_point) / range_size
    end
  end

  return nil
end

function blink_brightness()
  return util.round(math.abs(1 - util.time() % 2) * MAX_BRIGHTNESS)
end

function redraw_grid_tide_shape_editor()
  current_index = edited_shape_index()
  current_shape = tide_shapes[current_index]
  rotated = g.rows == 16

  if insanity_mode then
    brightness = blink_brightness()
    for y = 1, g.rows do
      g:led(1, y, brightness)
    end
  elseif num_tide_shapes_in_sequence == 1 then
    if rotated then
      for x = 1, g.cols do
        brightness = x == (17 - current_index) and MAX_BRIGHTNESS or 0
        g:led(x, 1, brightness)
        g:led(x, 16, 0)
      end
    else
      for y = 1, g.rows do
        brightness = y == current_index and MAX_BRIGHTNESS or 0
        g:led(1, y, brightness)
        g:led(16, y, 0)
      end
    end
  else
    first_in_sequence = util.round(params:get("tide_shape_index"))
    last_in_sequence = modulo_base_one(first_in_sequence + num_tide_shapes_in_sequence - 1, g.rows)
    reference_time = util.time() % 2

    if rotated then
      for x = 1, g.cols do
        brightness_phase = phase_in_wrapped_range(x, 17 - last_in_sequence, 17 - first_in_sequence, g.cols)
        if brightness_phase then
          brightness_phase = 1 - brightness_phase
          brightness = util.round(MAX_BRIGHTNESS * (1 - reference_time + brightness_phase))
          brightness = (brightness >= 0 and brightness <= MAX_BRIGHTNESS) and brightness or 0
        else
          brightness = 0
        end

        g:led(x, 1, brightness)
      end
    else
      for y = 1, g.rows do
        brightness_phase = phase_in_wrapped_range(y, first_in_sequence, last_in_sequence, g.rows)
        if brightness_phase then
          brightness = util.round(MAX_BRIGHTNESS * (1 - reference_time + brightness_phase))
          brightness = (brightness >= 0 and brightness <= MAX_BRIGHTNESS) and brightness or 0
        else
          brightness = 0
        end

        g:led(1, y, brightness)
      end
    end
  end

  if rotated then
    for y = 2, g.rows - 1 do
      for x = 1, g.cols do
        brightness = (y + current_shape[17 - x]) >= 16 and 8 or 0
        g:led(x, y, brightness)
      end
    end
  else
    for x = 2, g.cols - 1 do
      for y = 1, g.rows do
        brightness = (x + current_shape[y]) >= 16 and 8 or 0
        g:led(x, y, brightness)
      end
    end
  end

  g:refresh()
end

function redraw_grid_preset_select_view()
  grid_lighting = grid_transition(smoothing_counter / smoothing_factor)

  for x = 1, g.cols do
    for y = 1, g.rows do
      brightness = is_piling(x, y) and 0 or grid_lighting[y][x]
      if displaying_buoys and buoys[y][x] and buoys[y][x].active then
        brightness = MAX_BRIGHTNESS
      end

      -- normal grid activity is dimmed and in the background while preset
      -- selection is occuring
      brightness = util.round(brightness / 2)

      if current_preset_selection.x == x and current_preset_selection.y == y then
        brightness = blink_brightness()
      elseif existing_saved_presets[y][x] then
        brightness = MAX_BRIGHTNESS
      end

      g:led(x, y, brightness)
    end
  end
  g:refresh()
end

function redraw_grid_main_view()
  grid_lighting = grid_transition(smoothing_counter / smoothing_factor)

  for x = 1, g.cols do
    for y = 1, g.rows do
      brightness = is_piling(x, y) and 0 or grid_lighting[y][x]
      if displaying_buoys and buoys[y][x] and buoys[y][x].active then
        brightness = MAX_BRIGHTNESS
      end
      g:led(x, y, brightness)
    end
  end
  g:refresh()
end

function fresh_grid(b)
  local gr = {}
  for y = 1, g.rows do
    gr[y] = {}
    for x = 1, g.cols do
      gr[y][x] = b
    end
  end
  return gr
end

-- probability a fair coin flip is heads
-- "probability" - biases coin to return heads with given probability
-- "times" - with this many flips, the coin came up at least once
function flip_coin(probability, times)
  p = probability or 0.5
  times = times or 1
  adjusted_p = 1 - (1 - p) ^ times
  return math.random() < adjusted_p
end

function list_shuffle(tbl)
  local size = #tbl
  for i = size, 1, -1 do
    local rand = math.random(i)
    tbl[i], tbl[rand] = tbl[rand], tbl[i]
  end
  return tbl
end

function negative_dispersion()
  return params:get("dispersion") < 0
end

function dispersion_factor()
  return math.abs(DISPERSION_MULTIPLE * params:get("dispersion"))
end

function deep_copy(obj)
  if type(obj) ~= 'table' then return obj end
  local res = {}
  for k, v in pairs(obj) do res[deep_copy(k)] = deep_copy(v) end
  return res
end

-- buoys

Buoy = {
  active = false,
  playing = false,
  being_edited = false,
  previous_depth = 0,
  depth = 0,
  softcut_buffer = -1,
  active_start_time = -1,
  midi_or_crow_triggered_time = -1,
  play_triggerable = true,
  reset_triggerable = true,
  sample_start_time = -1,
  sample_end_time = -1,
  loop_start_time = -1,
  loop_end_time = -1,
  last_midi_note_played_channel = nil,
  midi_note = nil,
  crow_high = false,
}

function Buoy:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self

  o.options = {}
  for _, option_config in pairs(all_buoy_options) do
    o.options[option_config.name] = option_config.default_value
  end

  return o
end

function Buoy:activate()
  self.active = true
end

function Buoy:deactivate()
  self.active = false
  self:release_softcut_buffer()
end

function Buoy:release_softcut_buffer()
  self.playing = false

  if self:has_softcut_buffer() then
    softcut.play(self.softcut_buffer, 0)
    buffer_buoy_map[self.softcut_buffer] = nil
    self.softcut_buffer = -1
  end
end

function Buoy:update_depth(new_depth)
  self.previous_depth = self.depth
  self.depth = new_depth

  if not self.active then
    return
  end

  if self.depth == self.previous_depth then
    return
  end

  self:update_volume()
  self:update_panning()
  self:update_filtering()
  self:update_rate()
  self:update_crow()
  self:update_midi()

  if self.play_triggerable and self:newly_exceeds_play_threshold() then
    self.play_triggerable = false
    self:start_playing()
  elseif (not self.play_triggerable) and self:newly_below_play_threshold_with_hysteresis() then
    self.play_triggerable = true
  end

  if self.reset_triggerable and self:newly_exceeds_reset_threshold() then
    self.reset_triggerable = false
    self:reset_playhead()
  elseif (not self.reset_triggerable) and self:newly_below_reset_threshold_with_hysteresis() then
    self.reset_triggerable = true
  end
end

function Buoy:reset_playhead()
  if not self:has_softcut_buffer() then
    return
  end

  -- update_sound will reset playhead position
  self:update_sound()
  self.active_start_time = util.time()
  self.playing = true
end

function Buoy:start_playing()
  if self:has_softcut_buffer() then
    if (not self.playing) or self:finished_playing() then
      self:reset_playhead()
    end

    return
  end

  self:grab_softcut_buffer()
  -- if there are a lot of active uninterruptible buffers
  -- it's possible we might not be able to grab one
  if not self:has_softcut_buffer() then
    return
  end

  self:setup_softcut_params()
  self.active_start_time = util.time()
  self.playing = true
  softcut.play(self.softcut_buffer, 1)
end

function Buoy:setup_softcut_params()
  self:update_sound()
  self:update_volume_immediately()
  self:update_panning_immediately()
  self:update_rate_immediately()
  self:update_filtering()
  self:update_looping()
end

function Buoy:has_softcut_buffer()
  return self.softcut_buffer > 0
end

function Buoy:grab_softcut_buffer()
  if self:has_softcut_buffer() then
    return
  end

  if not self:sound_details() then
    return
  end

  self.softcut_buffer = next_softcut_buffer()
  if not self:has_softcut_buffer() then
    return
  end

  old_buffer_buoy = buffer_buoy_map[self.softcut_buffer]
  if old_buffer_buoy then
    old_buffer_buoy:release_softcut_buffer()
  end

  buffer_buoy_map[self.softcut_buffer] = self
end

function Buoy:newly_exceeds_reset_threshold()
  reset_threshold = self.options["reset threshold"]
  if reset_threshold < 1 then
    return false
  end

  return (self.previous_depth < reset_threshold) and (self.depth >= reset_threshold)
end

function Buoy:newly_below_reset_threshold_with_hysteresis()
  threshold_with_hysteresis = self.options["reset threshold"] - self.options["reset threshold hysteresis"]
  if threshold_with_hysteresis < 0 then
    return false
  end

  return (self.previous_depth > threshold_with_hysteresis) and (self.depth <= threshold_with_hysteresis)
end

function Buoy:newly_exceeds_play_threshold()
  play_threshold = self.options["play threshold"]
  if play_threshold < 1 then
    return false
  end

  return (self.previous_depth < play_threshold) and (self.depth >= play_threshold)
end

function Buoy:newly_below_play_threshold_with_hysteresis()
  threshold_with_hysteresis = self.options["play threshold"] - self.options["play threshold hysteresis"]
  if threshold_with_hysteresis < 0 then
    return false
  end

  return (self.previous_depth > threshold_with_hysteresis) and (self.depth <= threshold_with_hysteresis)
end

-- oldest voices are stolen first unless marked uninterruptible, in which case
-- they'll only be stolen if they are finished playing
function next_softcut_buffer()
  oldest_active_start_time = math.huge
  best_candidate = nil

  for i = 1, softcut.VOICE_COUNT do
    buoy = buffer_buoy_map[i]
    if not buoy then
      return i
    end

    is_interruptible = buoy.options["uninterruptible"] ~= 2

    if buoy:finished_playing() or is_interruptible then
      if buoy.active_start_time < oldest_active_start_time then
        best_candidate = i
        oldest_active_start_time = buoy.active_start_time
      end
    end
  end

  return best_candidate
end

function Buoy:currently_playing()
  -- this is kind of redundant but nbd
  return self.playing and not self:finished_playing()
end

function Buoy:light_up()
  -- we count not just currently playing/triggered but also very recently
  -- played/triggered so it will be clear that short samples/triggers have played
  return self:played_recently() or self:midi_or_crow_triggered_recently()
end

function Buoy:midi_or_crow_triggered_recently()
  if self.midi_note or self.crow_high then
    return true
  end

  return (util.time() - self.midi_or_crow_triggered_time) < 0.1
end

function Buoy:played_recently()
  if self:currently_playing() then
    return true
  end

  return (util.time() - self.active_start_time) < 0.1
end

function Buoy:finished_playing()
  if not self:has_softcut_buffer() then
    return true
  end

  if self:is_looping() then
    return false
  end

  return not self.playing
end

function Buoy:update_option(name, value)
  self.options[name] = value

  if name == "sound" then
    self:update_sound()
  elseif name == "sound start point %" then
    self:update_sound_loop_points()
  elseif name == "sound end point %" then
    self:update_sound_loop_points()
  elseif name == "octave offset" then
    self:update_rate_immediately()
  elseif name == "semitone offset" then
    self:update_rate_immediately()
  elseif name == "cent offset" then
    self:update_rate_immediately()
  elseif name == "looping" then
    self:update_looping()
  elseif name == "zenith volume" then
    self:update_volume()
  elseif name == "nadir volume" then
    self:update_volume()
  elseif name == "volume zenith point" then
    self:update_volume()
  elseif name == "volume nadir point" then
    self:update_volume()
  elseif name == "volume slew" then
    self:update_volume_slew()
  elseif name == "zenith pan" then
    self:update_panning()
  elseif name == "nadir pan" then
    self:update_panning()
  elseif name == "pan zenith point" then
    self:update_panning()
  elseif name == "pan nadir point" then
    self:update_panning()
  elseif name == "pan slew" then
    self:update_pan_slew()
  elseif name == "filter type" then
    self:update_filtering()
  elseif name == "zenith filter cutoff" then
    self:update_filtering()
  elseif name == "nadir filter cutoff" then
    self:update_filtering()
  elseif name == "cutoff zenith point" then
    self:update_filtering()
  elseif name == "cutoff nadir point" then
    self:update_filtering()
  elseif name == "zenith filter Q" then
    self:update_filter_q()
  elseif name == "nadir filter Q" then
    self:update_filter_q()
  elseif name == "Q zenith point" then
    self:update_filter_q()
  elseif name == "Q nadir point" then
    self:update_filter_q()
  elseif name == "zenith rate" then
    self:update_rate()
  elseif name == "nadir rate" then
    self:update_rate()
  elseif name == "rate zenith point" then
    self:update_rate()
  elseif name == "rate nadir point" then
    self:update_rate()
  elseif name == "rate slew" then
    self:update_rate_slew()
  elseif name == "midi output" then
    self:update_midi_output_index()
  elseif name == "zenith CC value" then
    self:update_midi_cc_output()
  elseif name == "nadir CC value" then
    self:update_midi_cc_output()
  elseif name == "midi CC zenith point" then
    self:update_midi_cc_output()
  elseif name == "midi CC nadir point" then
    self:update_midi_cc_output()
  elseif name == "crow output mode" then
    self:update_crow()
  elseif name == "zenith crow voltage" then
    self:update_crow()
  elseif name == "nadir crow voltage" then
    self:update_crow()
  elseif name == "crow voltage slew" then
    self:update_crow()
  elseif name == "crow zenith point" then
    self:update_crow()
  elseif name == "crow nadir point" then
    self:update_crow()
  elseif name == "crow t/g threshold" then
    self:update_crow()
  end
end

function Buoy:update_midi()
  self:update_midi_cc_output()
  self:update_midi_note_output()
end

function Buoy:update_midi_note_output()
  if (not self.midi_out_device) or (self.options["midi note out"] == MIN_MIDI_NOTE - 1) then
    return
  end

  depth_meets_note_on_threshold = self.depth >= self.options["midi note on threshold"]

  if self.midi_note and (not depth_meets_note_on_threshold) then
    self.midi_out_device:note_off(self.midi_note, 0, self.last_midi_note_played_channel)
    self.midi_note = nil
    self.last_midi_note_played_channel = nil
  elseif (not self.midi_note) and depth_meets_note_on_threshold then
    self.midi_or_crow_triggered_time = util.time()

    nvv = self.options["nadir velocity value"]
    zvv = self.options["zenith velocity value"]
    velocity = util.round(nvv + ((zvv - nvv) * self:tide_ratio("midi velocity")))

    midi_channel = self.options["midi out channel"]
    self.midi_note = self.options["midi note out"]
    self.last_midi_note_played_channel = midi_channel
    self.midi_out_device:note_on(self.midi_note, velocity, midi_channel)
  end
end

function Buoy:update_midi_cc_output()
  if (not self.midi_out_device) or (self.options["midi out CC number"] == 0) then
    return
  end

  ncc = self.options["nadir CC value"]
  zcc = self.options["zenith CC value"]
  new_cc = util.round(ncc + ((zcc - ncc) * self:tide_ratio("midi CC")))

  midi_channel = self.options["midi out channel"]
  cc_num = self.options["midi out CC number"]
  self.midi_out_device:cc(cc_num, new_cc, midi_channel)
end

function Buoy:update_midi_output_index()
  self.midi_out_device = midi.connect(self.options["midi output"])
end

function Buoy:update_sound()
  if not self:has_softcut_buffer() then
    return
  end

  details = self:sound_details()
  if not details then
    self:release_softcut_buffer()
    self.options["sound"] = 0
    return
  end

  start_loc = details.start_location
  end_loc = start_loc + details.duration
  self.sample_name = details.name
  self.sample_start_time = start_loc
  self.sample_end_time = end_loc
  self:update_sound_loop_points()
  start_pos = self:effective_rate() >= 0 and self.loop_start_time or self.loop_end_time
  softcut.loop_start(self.softcut_buffer, self.loop_start_time)
  softcut.loop_end(self.softcut_buffer, self.loop_end_time)
  softcut.position(self.softcut_buffer, start_pos)
end

function Buoy:update_sound_loop_points()
  sample_length = self.sample_end_time - self.sample_start_time
  self.loop_start_time = self.sample_start_time + sample_length * (self.options["sound start point %"] / 100)
  self.loop_end_time = self.sample_start_time + sample_length * (self.options["sound end point %"] / 100)
  softcut.loop_start(self.softcut_buffer, self.loop_start_time)
  softcut.loop_end(self.softcut_buffer, self.loop_end_time)
  softcut.position(self.softcut_buffer, self.loop_start_time)
end

function Buoy:sound_details()
  sound_index = self.options["sound"]
  return sample_details[sound_index]
end

function Buoy:update_panning_immediately()
  if not self:has_softcut_buffer() then
    return
  end

  softcut.pan_slew_time(self.softcut_buffer, 0.0)
  self:update_panning()
  self:update_pan_slew()
end

function Buoy:update_panning()
  if not self:has_softcut_buffer() then
    return
  end

  np = self.options["nadir pan"]
  zp = self.options["zenith pan"]
  new_pan = np + ((zp - np) * self:tide_ratio("pan"))
  softcut.pan(self.softcut_buffer, new_pan)
end

function Buoy:update_crow()
  output_index = self.options["crow output"]
  if output_index < 1 then
    return
  end

  if self.options["crow output mode"] == 1 then
    self:update_crow_voltage()
  elseif self.options["crow output mode"] == 2 then
    self:update_crow_trigger()
  else
    self:update_crow_gate()
  end
end

function Buoy:update_crow_trigger()
  output_index = self.options["crow output"]
  trigger_threshold = self.options["crow t/g threshold"]
  if trigger_threshold < 1 then
    return
  end

  if (self.previous_depth < trigger_threshold) and (self.depth >= trigger_threshold) then
    self.midi_or_crow_triggered_time = util.time()
    crow.output[output_index].action = "pulse(0.05, 8.0)"
    crow.output[output_index]()
  end
end

function Buoy:update_crow_gate()
  output_index = self.options["crow output"]
  gate_threshold = self.options["crow t/g threshold"]
  if gate_threshold < 1 then
    return
  end

  if (self.depth >= gate_threshold) then
    self.midi_or_crow_triggered_time = util.time()
    self.crow_high = true
    new_voltage = 8
  else
    self.crow_high = false
    new_voltage = 0
  end

  crow.output[output_index].slew = 0
  crow.output[output_index].volts = new_voltage
end

function Buoy:update_crow_voltage()
  output_index = self.options["crow output"]
  slew_time = self.options["crow voltage slew"]

  -- "auto" slew
  if slew_time < 0 then
    slew_time = tide_advance_time
  end

  crow.output[output_index].slew = slew_time

  ncv = self.options["nadir crow voltage"]
  zcv = self.options["zenith crow voltage"]
  new_voltage = ncv + ((zcv - ncv) * self:tide_ratio("crow"))

  crow.output[output_index].volts = new_voltage
end

function Buoy:update_filtering()
  if not self:has_softcut_buffer() then
    return
  end

  nfc = self.options["nadir filter cutoff"]
  zfc = self.options["zenith filter cutoff"]
  filter_type = self.options["filter type"]
  new_cutoff = nfc + ((zfc - nfc) * self:tide_ratio("cutoff"))

  softcut.post_filter_lp(self.softcut_buffer, 0)
  softcut.post_filter_hp(self.softcut_buffer, 0)
  softcut.post_filter_bp(self.softcut_buffer, 0)
  softcut.post_filter_br(self.softcut_buffer, 0)

  if filter_type == 1 then
    softcut.post_filter_lp(self.softcut_buffer, 1)
  elseif filter_type == 2 then
    softcut.post_filter_hp(self.softcut_buffer, 1)
  elseif filter_type == 3 then
    softcut.post_filter_bp(self.softcut_buffer, 1)
  elseif filter_type == 4 then
    softcut.post_filter_br(self.softcut_buffer, 1)
  end

  softcut.post_filter_fc(self.softcut_buffer, frequency_exp_convert(new_cutoff))
end

function Buoy:update_filter_q()
  if not self:has_softcut_buffer() then
    return
  end

  nfq = self.options["nadir filter Q"]
  zfq = self.options["zenith filter Q"]
  new_q = nfq + ((zfq - nfq) * self:tide_ratio("Q"))

  if new_q == 0 then
    new_rq = 4.0
  else
    new_rq = 1 / new_q
  end

  softcut.post_filter_rq(self.softcut_buffer, new_rq)
end

function Buoy:update_volume_immediately()
  if not self:has_softcut_buffer() then
    return
  end

  softcut.level_slew_time(self.softcut_buffer, 0.0)
  self:update_volume()
  self:update_volume_slew()
end

function Buoy:update_volume()
  if not self:has_softcut_buffer() then
    return
  end

  nv = self.options["nadir volume"]
  zv = self.options["zenith volume"]
  new_level = nv + ((zv - nv) * self:tide_ratio("volume"))
  softcut.level(self.softcut_buffer, new_level)
end

function Buoy:tide_ratio(param)
  zp = self.options[param.." zenith point"]
  np = self.options[param.." nadir point"]
  range_size = zp - np
  effective_depth = util.clamp(self.depth, np, zp) - np
  return effective_depth / range_size
end

function Buoy:update_looping()
  if not self:has_softcut_buffer() then
    return
  end

  softcut.loop(self.softcut_buffer, self:is_looping() and 1 or 0)
end

function Buoy:update_volume_slew()
  if not self:has_softcut_buffer() then
    return
  end

  slew_time = self.options["volume slew"]
  -- "auto" slew
  if slew_time < 0 then
    slew_time = tide_advance_time
  end

  softcut.level_slew_time(self.softcut_buffer, slew_time)
end

function Buoy:update_pan_slew()
  if not self:has_softcut_buffer() then
    return
  end

  slew_time = self.options["pan slew"]
  -- "auto" slew
  if slew_time < 0 then
    slew_time = tide_advance_time
  end

  softcut.pan_slew_time(self.softcut_buffer, slew_time)
end

function Buoy:is_looping()
  return self.options["looping"] == 2
end

function Buoy:update_rate_immediately()
  if not self:has_softcut_buffer() then
    return
  end

  softcut.rate_slew_time(self.softcut_buffer, 0.0)
  self:update_rate()
  self:update_rate_slew()
end

function Buoy:update_rate()
  if not self:has_softcut_buffer() then
    return
  end

  softcut.rate(self.softcut_buffer, self:effective_rate())
end

function Buoy:update_rate_slew()
  if not self:has_softcut_buffer() then
    return
  end

  slew_time = self.options["rate slew"]
  -- "auto" slew
  if slew_time < 0 then
    slew_time = tide_advance_time
  end

  softcut.rate_slew_time(self.softcut_buffer, slew_time)
end

function Buoy:effective_rate()
  octave_offset = self.options["octave offset"]
  semitone_offset = self.options["semitone offset"]
  cent_offset = self.options["cent offset"]

  unmodulated_rate = 2.0 ^ (octave_offset + (semitone_offset / 12) + (cent_offset / 1200))

  nr = self.options["nadir rate"]
  zr = self.options["zenith rate"]
  new_rate_multiplier = nr + ((zr - nr) * self:tide_ratio("rate"))

  return unmodulated_rate * new_rate_multiplier
end

-- if there's already a buoy, pressing a grid key switches between
-- [buoy, piling, nothing], otherwise it just switches between
-- [buoy, nothing] until a piling is explicitly placed there by
-- a longpress
function toggle_buoy_piling_nothing(x, y)
  if buoys[y][x] then
    if buoys[y][x].active then
      buoys[y][x]:deactivate()
      add_piling(x, y)
    elseif is_piling(x, y) then
      remove_piling(x, y)
    else
      buoys[y][x]:activate()
    end
  else
    if is_piling(x, y) then
      remove_piling(x, y)
    else
      add_piling(x, y)
    end
  end
end

function load_preview_data()
  preview_data = tab.load(norns.state.data..preset_filename())

  preview_params = paramset.new()
  add_channel_style_param(preview_params)
  pset_number = current_preset_selection.y * 16 + current_preset_selection.x
  preview_params:read(pset_number)
end

-- grid

g.key = function(x, y, z)
  if selecting_preset() and z == 1 then
    current_preset_selection = { x=x, y=y }

    if util.file_exists(norns.state.data..preset_filename()) then
      load_preview_data()
    end

    return
  end

  if meta_mode then
    return
  end

  held_grid_keys[y][x] = z

  if editing_tide_shapes() then
    if g.rows == 16 and z == 1 then
      if y == 1 then
        new_wave_sequence = false
        for x_held = 1, g.rows do
          if x ~= x_held then
            if held_grid_keys[1][x_held] == 1 then
              new_wave_sequence = true
              params:set("tide_shape_index", (17 - x_held))
              num_tide_shapes_in_sequence = ((x_held - x) % g.cols) + 1
            end
          end
        end

        if not new_wave_sequence then
          params:set("tide_shape_index", 17 - x)
          num_tide_shapes_in_sequence = 1
        end
      else
        tide_shapes[edited_shape_index()][17 - x] = math.min(16 - y, params:get("max_depth"))
      end
    elseif z == 1 then
      if x == 1 then
        new_wave_sequence = false
        toggling_insanity_mode = true
        for y_held = 1, g.rows do
          if held_grid_keys[y_held][1] ~= 1 then
            toggling_insanity_mode = false
          end

          if y ~= y_held then
            if held_grid_keys[y_held][1] == 1 then
              new_wave_sequence = true
              params:set("tide_shape_index", y_held)
              num_tide_shapes_in_sequence = ((y - y_held) % g.rows) + 1
            end
          end
        end

        if toggling_insanity_mode then
          insanity_mode = not insanity_mode
        end

        if not new_wave_sequence then
          params:set("tide_shape_index", y)
          num_tide_shapes_in_sequence = 1
        end
      else
        tide_shapes[edited_shape_index()][y] = math.min(16 - x, params:get("max_depth"))
      end
    end
  else
    if z == 0 then
      if buoys[y][x] and buoys[y][x].being_edited then
        buoys[y][x].being_edited = false
      else
        toggle_buoy_piling_nothing(x, y)
      end
    end
  end

  redraw_lights()
  redraw()
end

-- arc

function a.delta(n, d)
  if n == 1 then
    params:delta("tide_height_multiplier", d * 0.1)
  elseif n == 2 then
    -- we circumvent the simpler params:delta approach in order to support
    -- circular transitions between the 8 tide shapes (8->1 and 1->8)
    -- (or 16 tide shapes for a 256 grid)
    tide_shape_index = params:get("tide_shape_index") + (d * 0.01)
    if tide_shape_index >= g.rows + 1 then
      params:set("tide_shape_index", tide_shape_index - g.rows)
    elseif tide_shape_index < 1 then
      params:set("tide_shape_index", tide_shape_index + g.rows)
    else
      params:set("tide_shape_index", tide_shape_index)
    end
  elseif n == 3 then
    params:delta("angle", d * 0.1)
  elseif n == 4 then
    -- we use a shadow param instead of setting dispersion directly to create a dead zone
    dispersion_shadow_param = util.clamp(dispersion_shadow_param + d, -2750, 2750)
    update_dispersion_param()
  end

  redraw_arc_lights()
end
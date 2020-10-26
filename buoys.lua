-- pilings_v21.lua
-- sample folder loading

-- TODO LIST
-- use local variables
-- tune defaults
---- especially collisions
-- allow diagonal movement (option)?
---- POTENTIAL_DISPERSION_DIRECTIONS?
---- also roll_forward()?
-- do something about disappearing density when you hit a wall?
---- excessive density could lead to faster speeds, much like IRL
---- optional overflow mode?
-- could dispersion look better if it were more concentric instead of UDLR?
-- smoothing could/should be proportional to advance time
-- some kind of estimation to make it faster when there are a lot of particles?
-- use E1 as a macro control?
-- wave sequencing?
-- sample loading
-- if wave depth can affect playhead position, that could be used for granular stuff
-- in addition to height, you could have wave velocity play a role in sound parameters
---- or simpler version, just have the sample start playing backward when the net velocity is backward
-- max depth should really be 14 not 15...
-- figure out how we're going to do slews - will they sound right for things like filtering?
-- midi CC outputs, midi sync. midi note outputs - how would that work with velocity and such?
-- crow support
---- 4 cv outs (could also have triggers for crossing thresholds)
---- 1 clock in, 1 assignable CV param?
-- use util methods where possible
---- many places we use math.floor we could use util.round
-- meta mode
---- sample loading
---- global state saving/loading?
---- 3 voice stereo mode? variable?

-- ACKNOWLEDGEMENTS
-- I borrowed some file/folder loading logic from Timber Player, thanks @markeats.

fileselect = require "fileselect"
tabutil = require "tabutil"
-- TODO - explicit require necessary?

RUN = true

DISPERSION_MULTIPLE = 0.001

ADVANCE_TIME = 0.2
TIDE_GAP = 32
-- sinces waves move from left to right, they 
-- will appear flipped vs these definitions
BASE_TIDE_SHAPES = {
  {4, 9, 15, 13, 11, 9, 6, 2},
  {3, 6, 9, 12, 15, 0, 0, 0},
  {5, 10, 15, 10, 5, 0, 0, 0},
  {15, 12, 9, 6, 3, 0, 0, 0},
  {15, 10, 5, 0, 0, 0, 0, 0},
  {15, 0, 0, 0, 0, 0, 0, 0},
  {15, 0, 0, 15, 0, 0, 15, 0},
  {8, 8, 8, 8, 8, 8, 8, 8},
}
COLLISION_OVERALL_DAMPING = 0.2
COLLISION_DIRECTIONAL_DAMPING = 0.5
VELOCITY_AVERAGING_FACTOR = 0.6
DISPERSION_VELOCITY_FACTOR = 0.1
SAMPLE_SPACING_BUFFER_TIME = 0.5
LONG_PRESS_TIME = 1.0
BACKGROUND_METRO_TIME = 0.1
POTENTIAL_DISPERSION_DIRECTIONS = { { x=1, y=0 }, { x=0, y=1 }, { x=-1, y=0 }, { x=0, y=-1 } }
SMOOTHING_FACTOR = 4
META_MODE_KEYS = { { x=1, y=1 }, { x=1, y=8 }, { x=16, y=1 }, { x=16, y=8 } }
META_MODE_OPTIONS = { "choose sample folder", "save state", "load state", "exit" }

-- TODO - could these be tied to the rate at which waves are moving? ("auto" option)
RATE_SLEW = 0.1
-- LEVEL_SLEW = 0.2
LEVEL_SLEW = 0.02
-- AUDIO_FILE = _path.dust.."audio/tehn/mancini1.wav"
AUDIO_FILE = _path.dust.."audio/tehn/mancini2.wav"
-- AUDIO_FILE = _path.dust.."audio/tehn/drumlite.wav"
-- AUDIO_FILE = _path.dust.."audio/hermit-leaves.wav"
AUDIO_DIRECTORY = _path.dust.."audio/tehn"

function offset_formatter(value)
  if value > 0 then
    return "+"..value
  end
  
  return tostring(value)
end

function zero_is_none_formatter(value)
  if value == 0 then
    return "none"
  end
  
  return tostring(value)
end

function file_select_finished_callback(full_file_path)
  file_select_active = false
  if file ~= "cancel" then
    load_sample_folder(full_file_path)
  end
  
  exit_meta_mode()
end

-- TODO - is there any way to just terminate at the folder view in fileselect
-- TODONOW - test this is all working
function load_sample_folder(full_file_path)
  softcut.buffer_clear_channel(1)
  sample_details = {}
  next_sample_start_location = 1.0
  
  folder, _ = split_file_path(full_file_path)
  
  for _, filename in ipairs(fileselect.list) do
    filename_lower = filename:lower()
    
    if string.find(filename_lower, ".wav") or string.find(filename_lower, ".aif") or string.find(filename_lower, ".aiff") then
      load_sample(folder .. filename)
    end
  end
end

function load_sample(full_file_path)
  local _, samples, sample_rate = audio.file_info(full_file_path)
  local sample_duration = samples / sample_rate
  -- TODO - does sample rate have to be 48000?
  -- https://llllllll.co/t/norns-2-0-softcut/20550/176?u=lylem
  if sample_rate ~= 48000 then
    return
  end
  
  if (next_sample_start_location + sample_duration) > softcut.BUFFER_SIZE then
    return
  end
  
  softcut.buffer_read_mono(full_file_path, 0, next_sample_start_location, -1, 1, 1)
  _, filename = split_file_path(full_file_path)
  details = {
    name = filename,  -- TODO - process filename to remove suffixes
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

BUOY_OPTIONS = {
  -- TODO
  -- attack/decay (auto vs controlled)
  -- thresholds (hysteresis?)
  -- sample
  -- depth envelope response
  ---- filter?
  ---- min/max values
  ---- volume
  ---- pan?
  ---- other options?
  {
    name = "looping",
    default_value = 1,
    options = {"no", "yes"},
  }, 
  {
    name = "uninterruptible",
    default_value = 1,
    options = {"no", "yes"},
  },
  {
    name = "octave offset",
    default_value = 0,
    option_range = {-2, 2},
    option_step_value = 1,
    formatter = offset_formatter,
  }, 
  {
    name = "semitone offset",
    default_value = 0,
    option_range = {-7, 7},
    option_step_value = 1,
    formatter = offset_formatter,
  }, 
  {
    name = "cent offset",
    default_value = 0,
    option_range = {-50, 50},
    option_step_value = 1,
    formatter = offset_formatter,
  },
  -- TODO - maybe high/low tide volume ranges should extend beyond [0.0, 1.0]
  -- so that you could e.g. have volume max out before reaching absolute max depth?
  {
    name = "high tide volume",
    default_value = 1.0,
    option_range = {0.0, 1.0},
    option_step_value = 0.01,
  },
  {
    name = "low tide volume",
    default_value = 0.0,
    option_range = {0.0, 1.0},
    option_step_value = 0.01,
  },
  -- TODO - separate play/reset thresholds?
  {
    name = "reset threshold",
    default_value = 1,
    option_range = {0, 15},
    option_step_value = 1,
    formatter = zero_is_none_formatter,
  },
}

a = arc.connect()
g = grid.connect()

function init()
  init_params()
  
  particles = {}
  pilings = fresh_grid(0)
  buoys = fresh_grid(nil)

  held_grid_keys = fresh_grid(0)
  
  run = true
  displaying_buoys = false
  buoy_editing_option_scroll_index = 1
  -- tide_shape_index can be fractional, indicating interpolation between shapes
  tide_shape_index = 1
  tide_shapes = BASE_TIDE_SHAPES
  tide_gap = TIDE_GAP
  tide_advance_time = ADVANCE_TIME

  old_grid_lighting = fresh_grid(params:get("min_bright"))
  new_grid_lighting = fresh_grid(params:get("min_bright"))
  tide_depths = fresh_grid(0)
  current_angle_gaps = angle_gaps()
  tide_interval_counter = 0
  smoothing_counter = 0
  tide_info_overlay_countdown = 0
  key_states = {0, 0, 0}
  was_editing_tides = false
  meta_mode = false
  meta_mode_option_index = 1
  file_select_active = false
  tide_height_multiplier = 1.0
  dispersion_ui_brightnesses = {}
  sample_details = {}
  for i = 1, 64 do
    dispersion_ui_brightnesses[i] = 0
  end

  init_softcut()
  
  if RUN then
    tide_maker = metro.init(smoothly_make_tides, tide_advance_time / SMOOTHING_FACTOR)
    tide_maker:start()
    background_metro = metro.init(background_metro_tasks, BACKGROUND_METRO_TIME)
    background_metro:start()
  end
end

function tide_shape()
  result = {}
  first_shape_index, interpolation_fraction = math.modf(tide_shape_index)
  second_shape_index = first_shape_index == #tide_shapes and 1 or first_shape_index + 1
  first_shape = tide_shapes[first_shape_index]
  second_shape = tide_shapes[second_shape_index]

  for i = 1, 8 do
    result[i] = math.floor(first_shape[i] * (1 - interpolation_fraction) + second_shape[i] * interpolation_fraction + 0.5)
  end
  
  return result
end

function init_params()
  params = paramset.new()
  
  params:add{ type = "option", id = "channel_style", name = "channel style", options = { "open", "flume" } }
  params:add_separator()
  params:add{ type = "number", id = "angle", name = "wave angle", min = -60, max = 60, default = 0, formatter = degree_formatter }
  params:add_separator()
  params:add{ type = "number", id = "dispersion", name = "dispersion", min = 0, max = 25, default = 10 }
  params:add_separator()
  params:add{ type = "number", id = "min_bright", name = "min brightness", min = 1, max = 3, default = 1 }
  -- TODO - when "max_depth" updates, we should clear excess particles
  params:add{ type = "number", id = "max_depth", name = "max depth", min = 8, max = 14, default = 14 }
  params:add{ type = "option", id = "smoothing", name = "visual smoothing", options = { "on", "off" } }
end

function init_softcut()
  softcut.buffer_clear()
  softcut.buffer_read_mono(AUDIO_FILE, 0, 1, -1, 1, 1)
  
  buffer_buoy_map = {}

  for i = 1, softcut.VOICE_COUNT do
    softcut.enable(i, 1)
    softcut.buffer(i, 1)
    softcut.level(i, 1.0)
    softcut.loop(i, 0)
    softcut.loop_start(i, 1.0)
    softcut.loop_end(i, 6.0)
    softcut.position(i, 1.0)
    softcut.rate(i, 1.0)
    buffer_buoy_map[i] = nil

    softcut.rate_slew_time(i, RATE_SLEW)
    softcut.level_slew_time(i, LEVEL_SLEW)
  end
end

function background_metro_tasks()
  update_held_grid_keys()
  update_dispersion_ui()
  tide_info_overlay_expiring = tide_info_overlay_countdown == 1
  tide_info_overlay_countdown = math.max(tide_info_overlay_countdown - 1, 0)
  
  if tide_info_overlay_expiring then
    redraw_screen()
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
  buoys[y][x]:activate()
end

function update_held_grid_keys()
  -- special case for if the exact set of keys are held to enter meta mode
  if meta_mode_keys_held() then
    held_grid_keys = fresh_grid(0)
    meta_mode = true
    redraw()
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

    redraw_screen()
  end
end

function meta_mode_keys_held()
  keys_held = grid_keys_held()
  
  if #keys_held ~= #META_MODE_KEYS then
    return false
  end
  
  for _, key_held in pairs(keys_held) do
    x, y = key_held[1], key_held[2]
    is_meta_mode_key = false
    for _, meta_mode_key in pairs(META_MODE_KEYS) do
      if x == meta_mode_key.x and y == meta_mode_key.y then
        is_meta_mode_key = true
      end
    end
    
    if not is_meta_mode_key then
      return false
    end
  end
  
  return true
end

function update_dispersion_ui()
  for i = 1, 64 do
    if flip_coin(dispersion_factor()) then
      dispersion_ui_brightnesses[i] = 15
    else
      dispersion_ui_brightnesses[i] = util.clamp(dispersion_ui_brightnesses[i] - 1, 0, 15)
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

function update_advance_time()
  tide_maker:start(tide_advance_time / SMOOTHING_FACTOR)
end

function key(n, z)
  key_states[n] = z
  if meta_mode then
    if z == 1 then
      return
    end
    
    meta_mode_option = META_MODE_OPTIONS[meta_mode_option_index]

    if meta_mode_option == "choose sample folder" then
      file_select_active = true
      fileselect.enter(_path.audio, file_select_finished_callback)
    elseif meta_mode_option == "save state" then
      -- TODO - save/load state logic
    elseif meta_mode_option == "load state" then
    elseif meta_mode_option == "exit" then
      exit_meta_mode()
    end
  else
    if z == 0 and not was_editing_tides then
      if n == 2 then
        displaying_buoys = not displaying_buoys
      elseif n == 3 then
        run = not run
      end
    end
    
    if key_states[2] == 0 and key_states[3] == 0 then
      was_editing_tides = false
    end
    
    redraw_lights()
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

function enc(n, d)
  if meta_mode then
    meta_mode_option_index = util.clamp(meta_mode_option_index + d, 1, #META_MODE_OPTIONS)
  elseif not editing_buoys() then
    if n == 2 then
      tide_info_overlay_countdown = 10
      tide_advance_time = util.clamp(tide_advance_time + d * 0.001, 0.1, 1.0)
      update_advance_time()
    end
    -- TODO - make less sensitive?
    if n == 3 then
      tide_info_overlay_countdown = 10
      tide_gap = math.max(tide_gap + d, 1)
    end
  else
    if n == 2 then
      -- TODO - this scrolls too fast
      buoy_editing_option_scroll_index = util.clamp(buoy_editing_option_scroll_index + d, 1, #BUOY_OPTIONS)
    end
    
    if n == 3 then
      option_config = BUOY_OPTIONS[buoy_editing_option_scroll_index]
      
      old_value = buoy_editing_prototype.options[option_config.name]
      if option_config.option_range then
        new_value = util.clamp(
          old_value + (d * option_config.option_step_value),
          option_config.option_range[1],
          option_config.option_range[2])
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
  end
  
  redraw_screen()
end

function degree_formatter(tbl)
  return tbl.value .. " degrees"
end

function smoothly_make_tides()
  if run then
    smoothing_counter = (smoothing_counter + 1) % SMOOTHING_FACTOR
    if smoothing_counter == 0 then
      make_tides()
      update_buoy_depths()
    end
    
    if params:get("smoothing") == 1 or smoothing_counter == 0 then
      redraw_lights()
    end
  end
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

function make_tides()
  old_grid_lighting = deep_copy(new_grid_lighting)
  disperse()
  roll_forward()
  
  tide_interval_counter = (tide_interval_counter % (tide_gap)) + 1

  if tide_interval_counter == 1 then
    current_angle_gaps = angle_gaps()
  end
  
  total_tide_width = 8 + math.max(table.unpack(current_angle_gaps))
  if tide_interval_counter <= total_tide_width then
    new_tide(tide_interval_counter)
  end
  
  velocity_averaging()
  particles_to_tide_depths()
  tide_depths_to_lighting()
end

function new_tide(position)
  for y = 1, g.rows do
    -- TODO - figure out wave sequencing here
    tide_index = ((position - current_angle_gaps[y]) % tide_gap) + 1
    num_new_particles = tide_shape()[tide_index] or 0
    num_new_particles = util.round(num_new_particles * tide_height_multiplier)

    for _ = 1, num_new_particles do
      if not is_piling(1, y) then
        particle = {}
        particle.x_pos = 1
        particle.x_vel = 1.0
        particle.y_pos = y
        particle.y_vel = 0.0
      
        table.insert(particles, particle)
      end
    end
  end
end

function angle_gaps()
  distance = math.tan(degrees_to_radians(params:get("angle")))
  offset = math.abs(math.min(0, util.round((g.rows - 1) * distance)))
  
  result = {}
  for i = 0, g.rows - 1 do
    table.insert(result, util.round(i * distance) + offset)
  end
  
  return result
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
    particle_counts[y][x] = particle_counts[y][x] + 1
  end
  
  for _, particle in ipairs(particles) do
    x, y = particle.x_pos, particle.y_pos
    density = particle_counts[y][x]
    narrowed_dispersion_directions = {}
    
    for _, direction in pairs(POTENTIAL_DISPERSION_DIRECTIONS) do
      if not is_piling(x + direction.x, y + direction.y) then
        density_diff = density - find_in_grid(x + direction.x, y + direction.y, particle_counts, density)
        
        if density_diff > 1 and flip_coin(dispersion_factor(), density_diff) then
          table.insert(narrowed_dispersion_directions, direction)
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
      density_diff = density - find_in_grid(new_x, new_y, particle_counts, density - 1)
      particle.x_vel = particle.x_vel + (disperse_direction.x * DISPERSION_VELOCITY_FACTOR * density_diff)
      particle.y_vel = particle.y_vel + (disperse_direction.y * DISPERSION_VELOCITY_FACTOR * density_diff)

      particle_counts[y][x] = particle_counts[y][x] - 1
      particle_counts[new_y][new_x] = particle_counts[new_y][new_x] + 1
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
        
        -- TODO - flip coin probabalistically to favor existing vel direction?
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
        
        -- TODO - flip coin probabalistically to favor existing vel direction?
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
    x_vel_sums[y][x] = x_vel_sums[y][x] + particle.x_vel
    y_vel_sums[y][x] = y_vel_sums[y][x] + particle.y_vel
    particle_counts[y][x] = particle_counts[y][x] + 1
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
      tide_depths[y][x] = tide_depths[y][x] + 1
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
      new_grid_lighting[y][x] = math.min(tide_depths[y][x] + params:get("min_bright"), 15)
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
  
  redraw_screen()
end

function redraw_screen()
  screen.clear()
  screen.aa(1)
  screen.font_face(1)
  screen.font_size(8)
  screen.level(15)
  
  if meta_mode then
    redraw_meta_mode_screen()
  elseif editing_buoys() then
    redraw_edit_buoy_screen()
  elseif displaying_tide_info_overlay() then
    redraw_tide_info_overlay()
  else
    redraw_regular_screen()
  end
  
  screen.update()
end

-- TODO - maybe say K3 to enter somewhere?
function redraw_meta_mode_screen()
  -- META_MODE_OPTIONS = { "choose sample folder", "save state", "load state", "exit" }
  for option_index, option in pairs(META_MODE_OPTIONS) do
    if option_index == meta_mode_option_index then
      screen.level(15)
    else
      screen.level(5)
    end
    
    screen.move(15, 10 + 10 * option_index)
    screen.text(option)
  end
end

function redraw_tide_info_overlay()
  screen.move(0, 30)
  screen.text("tide advance time")
  screen.move(128, 30)
  screen.text_right(tide_advance_time)
  
  screen.move(0, 40)
  screen.text("tide gap")
  screen.move(128, 40)
  screen.text_right(tide_gap)
end

function redraw_edit_buoy_screen()
  height = 40 - (buoy_editing_option_scroll_index * 10)

  for option_index, option_config in pairs(BUOY_OPTIONS) do
    if option_index == buoy_editing_option_scroll_index then
      screen.level(15)
    else
      screen.level(5)
    end
    
    screen.move(0, height)
    screen.text(option_config.name)
    
    buoy_value = buoy_editing_prototype.options[option_config.name]
    screen.move(128, height)

    if option_config.formatter then
      option_value_text = option_config.formatter(buoy_value)
    elseif option_config.options then
      option_value_text = option_config.options[buoy_value]
    else
      option_value_text = tostring(buoy_value)
    end
    screen.text_right(option_value_text)
    
    height = height + 10
  end
end

function redraw_regular_screen()
  redraw_flume_edges()
  
  screen.level(15)
  for x = 1, g.cols do
    for y = 1, g.rows do
      if is_piling(x, y) then
        screen.circle(x * 8 - 4, y * 8 - 4, 3.4)
        screen.fill()
      elseif buoys[y][x] and buoys[y][x].active then
        screen.circle(x * 8 - 4, y * 8 - 4, 3.4)
        screen.fill()
        screen.level(0)
        screen.circle(x * 8 - 4, y * 8 - 4, 2.7)
        screen.fill()
        screen.level(15)
      end
    end
  end
end

function redraw_flume_edges()
  if params:get("channel_style") == 2 then
    screen.level(15)
    screen.rect(0, 0, 128, 1)
    screen.fill()
    screen.rect(0, 63, 128, 1)
    screen.fill()
    screen.level(7)
    screen.rect(0, 1, 128, 1)
    screen.fill()
    screen.rect(0, 62, 128, 1)
    screen.fill()
  end
end

function redraw_lights()
  if editing_tide_shapes() then
    was_editing_tides = true
    redraw_grid_lights_tide_shape_editor()
  else
    redraw_grid_lights_main_view()
  end
  
  redraw_arc_lights()
end

function redraw_arc_lights()
  a:all(0)
  
  -- tide height multiplier
  for i = 1, 32 do
    if (tide_height_multiplier * 32) >= i then
      a:led(1, i + 32, 15)
      a:led(1, 33 - i, 15)
    end
  end
  
  -- wave shapes + interpolation
  shape = tide_shape()
  for i = 1, 8 do
    for j = 1, 4 do
      a:led(2, 12 + j + (i * 4), shape[i])
      a:led(2, 16 + j - (i * 4), shape[i])
    end
  end
  
  -- wave angle
  led_offset = util.round((params:get("angle") / 90) * 16) + 1
  a:led(3, led_offset - 1, 5)
  a:led(3, led_offset, 15)
  a:led(3, led_offset + 1, 5)

  a:led(3, led_offset + 31, 5)
  a:led(3, led_offset + 32, 15)
  a:led(3, led_offset + 33, 5)

  -- dispersion
  for i = 1, 64 do
    a:led(4, i, dispersion_ui_brightnesses[i])
  end
  a:refresh()
end

function edited_shape_index()
  result = util.round(tide_shape_index)
  return result == 9 and 1 or result
end

function redraw_grid_lights_tide_shape_editor()
  current_index = edited_shape_index()
  current_shape = tide_shapes[current_index]
  
  for y = 1, g.rows do
    brightness = y == current_index and 15 or 0
    g:led(1, y, brightness)
  end

  for x = 2, g.cols do
    for y = 1, g.rows do
      brightness = (x + current_shape[y]) >= 17 and 8 or 0
      g:led(x, y, brightness)
    end
  end
  g:refresh()
end

function redraw_grid_lights_main_view()
  grid_lighting = grid_transition(smoothing_counter / SMOOTHING_FACTOR)
  
  for x = 1, g.cols do
    for y = 1, g.rows do
      brightness = is_piling(x, y) and 0 or grid_lighting[y][x]
      if displaying_buoys and buoys[y][x] and buoys[y][x].active then
        brightness = 15
      end
      g:led(x, y, brightness)
    end
  end
  g:refresh()
end

function fresh_grid(b)
  return {
    {b, b, b, b, b, b, b, b, b, b, b, b, b, b, b, b},
    {b, b, b, b, b, b, b, b, b, b, b, b, b, b, b, b},
    {b, b, b, b, b, b, b, b, b, b, b, b, b, b, b, b},
    {b, b, b, b, b, b, b, b, b, b, b, b, b, b, b, b},
    {b, b, b, b, b, b, b, b, b, b, b, b, b, b, b, b},
    {b, b, b, b, b, b, b, b, b, b, b, b, b, b, b, b},
    {b, b, b, b, b, b, b, b, b, b, b, b, b, b, b, b},
    {b, b, b, b, b, b, b, b, b, b, b, b, b, b, b, b},
  }
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

function dispersion_factor()
  return DISPERSION_MULTIPLE * params:get("dispersion")
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
  being_edited = false,
  previous_depth = 0,
  depth = 0,
  softcut_buffer = -1,
  active_start_time = -1,
}

function Buoy:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  
  o.options = {}
  for _, option_config in pairs(BUOY_OPTIONS) do
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
  if self.softcut_buffer > 0 then
    softcut.play(self.softcut_buffer, 0)
    buffer_buoy_map[self.softcut_buffer] = nil
    self.softcut_buffer = -1
  end
end

-- TODO - work on parameterization like multiple samples, etc
function Buoy:update_depth(new_depth)
  self.previous_depth = self.depth
  self.depth = new_depth
  
  -- TODO - if you disable a buoy while it's still playing, it
  -- just keeps playing, i.e. this doesn't take immediate effect
  if not self.active then
    return
  end
  
  if self.depth == self.previous_depth then
    return
  end
  
  self:update_volume()
  
  if self:newly_exceeds_threshold() then
    -- TODO - what if there were no buffers available?
    self:grab_softcut_buffer()
    self:setup_softcut_params()
    self.active_start_time = util.time()
    softcut.position(self.softcut_buffer, 1.0)
    softcut.play(self.softcut_buffer, 1)
  end
end

function Buoy:setup_softcut_params()
  self:update_volume()
  self:update_rate()
  self:update_looping()
end

function Buoy:grab_softcut_buffer()
  if self.softcut_buffer > 0 then
    return
  end
  
  self.softcut_buffer = next_softcut_buffer()
  
  -- if there are a lot of active uninterruptible buffers
  -- it's possible we might not be able to grab one
  if not (self.softcut_buffer > 0) then
    return
  end
  
  old_buffer_buoy = buffer_buoy_map[self.softcut_buffer]
  if old_buffer_buoy then
    old_buffer_buoy:release_softcut_buffer()
  end
  
  buffer_buoy_map[self.softcut_buffer] = self
end

function Buoy:newly_exceeds_threshold()
  reset_threshold = self.options["reset threshold"]
  if reset_threshold < 1 then
    return false
  end
  
  return (self.previous_depth < reset_threshold) and (self.depth >= reset_threshold)
end

-- oldest voices are stolen first, unless marked uninterruptible
function next_softcut_buffer()
  oldest_active_start_time = math.huge
  best_candidate = nil
  
  for i = 1, softcut.VOICE_COUNT do
    buoy = buffer_buoy_map[i]
    if not buoy then
      return i
    end
    
    -- TODO - interruptibles that are non-looping should still be interruptible if
    -- they are done playing, i.e. if util.time() - active_start_time > sample length
    is_uninterruptible = buoy.options["uninterruptible"] == 2
    
    if not is_uninterruptible then
      if buoy.active_start_time < oldest_active_start_time then
        best_candidate = i
        oldest_active_start_time = buoy.active_start_time
      end
    end
  end
  
  return best_candidate
end

function Buoy:update_option(name, value)
  self.options[name] = value
  
  if name == "octave offset" then
    self:update_rate()
  elseif name == "semitone offset" then
    self:update_rate()
  elseif name == "cent offset" then
    self:update_rate()
  elseif name == "looping" then
    self:update_looping()
  end
end

function Buoy:update_volume()
  if self.softcut_buffer < 0 then
    return
  end
  
  ltv = self.options["low tide volume"]
  htv = self.options["high tide volume"]
  new_level = ltv + ((htv - ltv) * self:tide_ratio())
  softcut.level(self.softcut_buffer, new_level)
end

function Buoy:tide_ratio()
  return self.depth / params:get("max_depth")
end

function Buoy:update_looping()
  if self.softcut_buffer < 1 then
    return
  end
  
  is_looping = self.options["looping"] == 2
  softcut.loop(self.softcut_buffer, is_looping and 1 or 0)
end

function Buoy:update_rate()
  if self.softcut_buffer < 1 then
    return
  end
  
  octave_offset = self.options["octave offset"]
  semitone_offset = self.options["semitone offset"]
  cent_offset = self.options["cent offset"]
  
  rate = 2.0 ^ (octave_offset + (semitone_offset / 12) + (cent_offset / 1200))
  softcut.rate(self.softcut_buffer, rate)
end

-- grid

g.key = function(x, y, z)
  if meta_mode then
    return
  end
  
  if editing_tide_shapes() then
    if z == 1 then
      if x == 1 then
        tide_shape_index = y
      else
        shape_being_edited = tide_shapes[edited_shape_index()]
        old_tide_depth = shape_being_edited[y]
        new_tide_depth = 17 - x
        shape_being_edited[y] = old_tide_depth == new_tide_depth and 0 or new_tide_depth
      end
    end
  else
    if z == 0 then
      if buoys[y][x] and buoys[y][x].being_edited then
        buoys[y][x].being_edited = false
      else
        -- if there's already a buoy, pressing a grid key switches between
        -- [buoy, piling, nothing], otherwise it just switches between
        -- [buoy, nothing] until a piling is explicitly placed there by
        -- a longpress
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
    end
    
    held_grid_keys[y][x] = z
  end
  
  redraw_lights()
  redraw_screen()
end

-- arc

-- TODO - everything here should also be a param so that you could do
-- midi mapping instead of using arc
function a.delta(n, d)
  if n == 1 then
    tide_height_multiplier = util.clamp(tide_height_multiplier + (d * 0.001), 0.0, 1.0)
  elseif n == 2 then
    tide_shape_index = tide_shape_index + (d * 0.01)
    if tide_shape_index >= 9 then
      tide_shape_index = tide_shape_index - 8
    end
    if tide_shape_index < 1 then
      tide_shape_index = tide_shape_index + 8
    end
  elseif n == 3 then
    params:delta("angle", d * 0.1)
  elseif n == 4 then
    params:delta("dispersion", d * 0.01)
  end
  
  redraw_arc_lights()
end

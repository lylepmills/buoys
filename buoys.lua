-- pilings_v13.lua
-- wave shape editing view

-- TODO LIST
-- more tide shapes
-- use local variables
-- tune defaults
---- especially collisions
-- arc control? (common params, configurable?)
---- wave speed, wave height, wave interval, filter cutoff?
-- randomize waves somewhat?
-- waveshapes with initial Y differences?
---- more wave shaping control, attack/decay type thing?
-- threshold option for sounding on last row (must be > min)?
-- allow diagonal movement (option)?
---- POTENTIAL_DISPERSION_DIRECTIONS?
---- also roll_forward()?
-- do something about disappearing density when you hit a wall?
-- excessive density could lead to faster speeds, much like IRL
---- optional overflow mode?
-- could dispersion look better if it were more concentric instead of UDLR?
-- wave designer page?
---- hold both buttons to enter?
-- smoothing could/should be proportional to advance time
-- midi CC outputs? midi sync?

-- encoder params
---- wave speed
---- wave gap

-- arc params
---- wave height
---- wave shape
---- wave angle
---- wave dispersion

RUN = true

DISPERSION_MULTIPLE = 0.001

TIDE_GAP = 25
TIDE_HEIGHT = 5
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
TIDE_SHAPE_INDEX = 1
COLLISION_OVERALL_DAMPING = 0.2
COLLISION_DIRECTIONAL_DAMPING = 0.5
VELOCITY_AVERAGING_FACTOR = 0.6
DISPERSION_VELOCITY_FACTOR = 0.1
LONG_PRESS_TIME = 1.0
GRID_KEY_PRESS_METRO_TIME = 0.1
POTENTIAL_DISPERSION_DIRECTIONS = { { x=1, y=0 }, { x=0, y=1 }, { x=-1, y=0 }, { x=0, y=-1 } }

-- TODO - could these be tied to the rate at which waves are moving?
RATE_SLEW = 0.1
LEVEL_SLEW = 0.2
-- AUDIO_FILE = _path.dust.."audio/tehn/mancini1.wav"
-- AUDIO_FILE = _path.dust.."audio/tehn/mancini2.wav"
AUDIO_FILE = _path.dust.."audio/tehn/drumlite.wav"
-- AUDIO_FILE = _path.dust.."audio/hermit-leaves.wav"
NUM_SOFTCUT_BUFFERS = 6

function offset_formatter(value)
  if value > 0 then
    return "+"..value
  end
  
  return tostring(value)
end

BUOY_OPTIONS = {
  -- sample
  -- looping?
  -- uninterruptible?
  -- depth envelope response
  ---- min threshold
  ---- min/max values
  ---- volume
  ---- other options?
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
}


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
  tide_shape_index = TIDE_SHAPE_INDEX
  tide_shapes = BASE_TIDE_SHAPES

  old_grid_lighting = fresh_grid(params:get("min_bright"))
  new_grid_lighting = fresh_grid(params:get("min_bright"))
  current_angle_gaps = angle_gaps()
  tide_interval_counter = 0
  smoothing_counter = 0
  held_grid_keys_counter = 0
  key_states = {0, 0, 0}
  was_editing_tides = false

  init_softcut()
  
  if RUN then
    tide_maker = metro.init(smoothly_make_tides, params:get("advance_time") / params:get("smoothing"))
    tide_maker:start()
    held_grid_keys_tracker = metro.init(update_held_grid_keys, GRID_KEY_PRESS_METRO_TIME)
    held_grid_keys_tracker:start()
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
  -- TODO = rename to wave speed
  cs_advance_time = controlspec.new(0.05, 1.0, "lin", 0, 0.2, "seconds")
  params:add{ type = "control", id = "advance_time", name = "advance time", controlspec = cs_advance_time, action = update_advance_time }
  params:add_separator()
  params:add{ type = "number", id = "dispersion", name = "dispersion", min = 0, max = 25, default = 10 }
  params:add_separator()
  params:add{ type = "number", id = "min_bright", name = "min brightness", min = 1, max = 3, default = 1 }
  params:add{ type = "number", id = "max_bright", name = "max brightness", min = 10, max = 15, default = 15 }
  -- TODO - smoothing should not be a param, and it should not affect the perceived scroll speed
  params:add{ type = "number", id = "smoothing", name = "smoothing", min = 3, max = 6, default = 4 }
end

function init_softcut()
  softcut.buffer_clear()
  -- softcut.buffer_read_mono(AUDIO_FILE, 0, 0, -1, 0, 0)
  
  -- buffer_read_mono (file, start_src, start_dst, dur, ch_src, ch_dst)
  softcut.buffer_read_mono(AUDIO_FILE, 0, 1, -1, 1, 1)
  -- -- enable voice 1
  -- softcut.enable(1,1)
  -- -- set voice 1 to buffer 1
  -- softcut.buffer(1,1)
  -- -- set voice 1 level to 1.0
  -- softcut.level(1,1.0)
  -- -- voice 1 enable loop
  -- softcut.loop(1,0)
  -- -- set voice 1 loop start to 1
  -- softcut.loop_start(1,1)
  -- -- set voice 1 loop end to 2
  -- softcut.loop_end(1,7)
  -- -- set voice 1 position to 1
  -- softcut.position(1,1)
  -- -- set voice 1 rate to 1.0
  -- softcut.rate(1,1.0)
  -- -- enable voice 1 play
  -- softcut.play(1,1)
  
  buffer_buoy_map = {}

  for i = 1, NUM_SOFTCUT_BUFFERS do
    softcut.enable(i, 1)
    softcut.buffer(i, 1)
    softcut.level(i, 1.0)
    softcut.loop(i, 0)
    softcut.loop_start(i, 1.0)
    softcut.loop_end(i, 7.0)
    softcut.position(i, 1.0)
    softcut.rate(i, 1.0)
    buffer_buoy_map[i] = nil

    softcut.rate_slew_time(i, RATE_SLEW)
    softcut.level_slew_time(i, LEVEL_SLEW)
  end
end

function update_held_grid_keys()
  held_grid_keys_counter = held_grid_keys_counter + 1
  keys_held = grid_keys_held()
  newly_editing_buoys = false
  
  for _, key_held in pairs(keys_held) do
    x, y = key_held[1], key_held[2]
    -- TODO - should only increment counters if we're not already editing buoys
    held_grid_keys[y][x] = held_grid_keys[y][x] + 1
    if held_grid_keys[y][x] > (LONG_PRESS_TIME / GRID_KEY_PRESS_METRO_TIME) then
      newly_editing_buoys = true
      longest_held_key = {x, y}
      held_grid_keys = fresh_grid(0)
      break
    end
  end
  
  if newly_editing_buoys then
    for _, key_held in pairs(keys_held) do
      x, y = key_held[1], key_held[2]
      buoys[y][x] = buoys[y][x] or Buoy:new()
      buoys[y][x].being_edited = true
      buoys[y][x].active = true
    end
    
    buoy_editing_prototype = buoys[longest_held_key[2]][longest_held_key[1]]

    redraw_screen()
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
  tide_maker:start(params:get("advance_time") / params:get("smoothing"))
end

function key(n, z)
  key_states[n] = z
  
  if n == 3 and z == 0 and not was_editing_tides then
    run = not run
  end
  
  if key_states[2] == 0 and key_states[3] == 0 then
    was_editing_tides = false
  end
  
  if n == 2 then
    displaying_buoys = z == 1
  end
  
  redraw_lights()
end

function enc(n, d)
  if editing_buoys() then
    if n == 2 then
      buoy_editing_option_scroll_index = util.clamp(buoy_editing_option_scroll_index + d, 1, #BUOY_OPTIONS)
    end
    
    if n == 3 then
      option_config = BUOY_OPTIONS[buoy_editing_option_scroll_index]
      
      old_value = buoy_editing_prototype.options[option_config.name]
      new_value = util.clamp(
        old_value + (d * option_config.option_step_value),
        option_config.option_range[1],
        option_config.option_range[2])
      
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
    smoothing_counter = (smoothing_counter + 1) % params:get("smoothing")
    if smoothing_counter == 0 then
      make_tides()
      update_buoy_depths()
    end
    
    redraw_lights()
  end
end

-- TODO - a bit ugly to use the min_bright value here
-- as the baseline - could probably refactor
function update_buoy_depths()
  for x = 1, g.cols do
    for y = 1, g.rows do
      if buoys[y][x] then
        depth = new_grid_lighting[y][x] - params:get("min_bright")
        buoys[y][x]:update_depth(depth)
      end
    end
  end
end

function make_tides()
  old_grid_lighting = deep_copy(new_grid_lighting)
  disperse()
  roll_forward()
  
  -- TODO - should this just use TIDE_GAP so you can set lower gaps than shape size?
  tide_interval_counter = (tide_interval_counter % (TIDE_GAP + 8)) + 1
  if tide_interval_counter == 1 then
    current_angle_gaps = angle_gaps()
  end
  
  total_tide_width = 8 + math.max(table.unpack(current_angle_gaps))
  if tide_interval_counter <= total_tide_width then
    new_tide(tide_interval_counter)
  end
  
  velocity_averaging()
  particles_to_lighting()
end

function new_tide(position)
  for y = 1, g.rows do
    num_new_particles = tide_shape()[position - current_angle_gaps[y]] or 0
    
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
  offset = math.abs(math.min(0, round((g.rows - 1) * distance)))
  
  result = {}
  for i = 0, g.rows - 1 do
    table.insert(result, round(i * distance) + offset)
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

function particles_to_lighting()
  new_particles = {}
  new_grid_lighting = fresh_grid(params:get("min_bright"))
  
  for _, particle in ipairs(particles) do
    x, y = particle.x_pos, particle.y_pos

    if new_grid_lighting[y][x] < params:get("max_bright") then
      new_grid_lighting[y][x] = new_grid_lighting[y][x] + 1
      table.insert(new_particles, particle)
    else
      -- discard excess particles
    end
  end
  
  particles = new_particles
end

function is_piling(x, y)
  if params:get("channel_style") == 2 and (y < 1 or y > g.rows) then
    return true
  end
  return find_in_grid(x, y, pilings, 0) ~= 0
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
      result[y][x] = round(old_grid_lighting[y][x] + (lighting_difference * proportion))
    end
  end
  
  return result
end

-- TODO - standard seems to be to just call this redraw()
function redraw_screen()
  screen.clear()
  screen.aa(1)
  screen.font_face(1)
  screen.font_size(8)
  screen.level(15)
  
  if editing_buoys() then
    redraw_edit_buoy_screen()
  else
    redraw_regular_screen()
  end
  
  screen.update()
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
    screen.text_right(option_config.formatter(buoy_value))
    
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
    redraw_lights_tide_shape_editor()
  else
    redraw_lights_main_view()
  end
end

function redraw_lights_tide_shape_editor()
  current_index = math.floor(tide_shape_index)
  current_shape = tide_shapes[current_index]
  
  for y = 1, g.rows do
    brightness = y == current_index and 15 or 0
    g:led(1, y, brightness)
  end

  for x = 2, g.cols do
    for y = 1, g.rows do
      -- if y = 3, show the light iff brightness is >=14, etc
      brightness = (x + current_shape[y]) >= 17 and 8 or 0
      g:led(x, y, brightness)
    end
  end
  g:refresh()
end

function redraw_lights_main_view()
  grid_lighting = grid_transition(smoothing_counter / params:get("smoothing"))
  
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

function max_depth()
  return params:get("max_bright") - params:get("min_bright")
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

function round(num)
  return math.floor(num + 0.5)
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
  active_start_counter = -1,  -- held_grid_keys_counter
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

-- TODO - work on parameterization like multiple samples, etc
function Buoy:update_depth(new_depth)
  self.previous_depth = self.depth
  self.depth = new_depth
  
  if self.depth == self.previous_depth then
    return
  end
  
  if self.softcut_buffer > 0 then
    new_level = self.depth / max_depth()
    softcut.level(self.softcut_buffer, new_level)
  end
  
  if self.previous_depth == 0 then
    self.softcut_buffer = next_softcut_buffer()
    self.active_start_counter = held_grid_keys_counter
    old_buffer_buoy = buffer_buoy_map[self.softcut_buffer]
    if old_buffer_buoy then
      old_buffer_buoy.softcut_buffer = -1
    end
    buffer_buoy_map[self.softcut_buffer] = self
    
    softcut.level(self.softcut_buffer, 1.0 * self.depth / max_depth())
    softcut.position(self.softcut_buffer, 1)
    self:update_rate()
    softcut.play(self.softcut_buffer, 1)
  elseif self.depth == 0 then
    softcut.play(self.softcut_buffer, 0)
    buffer_buoy_map[self.softcut_buffer] = nil
    self.softcut_buffer = -1
  end
end

-- voice stealing by round robin
-- TODO - should round robin ejection be the only option, or
-- should there be other modes like no voice stealing?
function next_softcut_buffer()
  oldest_active_start_counter = math.huge
  best_candidate = 1
  
  for i = 1, NUM_SOFTCUT_BUFFERS do
    buoy = buffer_buoy_map[i]
    if not buoy then
      return i
    end
    
    if buoy.active_start_counter < oldest_active_start_counter then
      best_candidate = i
      oldest_active_start_counter = buoy.active_start_counter
    end
  end
  
  return best_candidate
end

function Buoy:update_option(name, value)
  self.options[name] = value
  
  -- TODO - update with more option types
  if name == "octave offset" then
    self:update_rate()
  elseif name == "semitone offset" then
    self:update_rate()
  elseif name == "cent offset" then
    self:update_rate()
  end
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
  if editing_tide_shapes() then
    if z == 1 then
      if x == 1 then
        tide_shape_index = y
      else
        shape_being_edited = tide_shapes[math.floor(tide_shape_index)]
        old_tide_depth = shape_being_edited[y]
        new_tide_depth = 17 - x
        shape_being_edited[y] = old_tide_depth == new_tide_depth and 0 or new_tide_depth
      end
    end
  else
    if z == 0 then
      if buoys[y][x] and (buoys[y][x].being_edited or buoys[y][x].active) then
        if buoys[y][x].being_edited then
          buoys[y][x].being_edited = false
        elseif buoys[y][x].active then
          buoys[y][x].active = false
        end
      else
        pilings[y][x] = is_piling(x, y) and 0 or 1
        clear_particles(x, y)
      end
      
      held_grid_keys[y][x] = 0
    end
    
    if z == 1 then
      held_grid_keys[y][x] = 1
    end
  end
  
  redraw_lights()
  redraw_screen()
end

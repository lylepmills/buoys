-- pilings_v9.lua
-- added v0 audio/softcut functionality

RUN = true
SHOW_GRID = true

DISPERSION_MULTIPLE = 0.001

TIDE_GAP = 25
TIDE_HEIGHT = 5
-- shape is defined right to left
TIDE_SHAPE = {1, 3, 6, 10, 9, 8, 6, 4, 1}
-- TIDE_SHAPE = {6, 3, 2}
COLLISION_OVERALL_DAMPING = 0.2
COLLISION_DIRECTIONAL_DAMPING = 0.5
VELOCITY_AVERAGING_FACTOR = 0.6
DISPERSION_VELOCITY_FACTOR = 0.1
LONG_PRESS_TIME = 1.0
GRID_KEY_PRESS_METRO_TIME = 0.1
POTENTIAL_DISPERSION_DIRECTIONS = { { x=1, y=0 }, { x=0, y=1 }, { x=-1, y=0 }, { x=0, y=-1 } }
TEST_RATES = {0.5, 1.0, 2.0, 0.5, 1.0, 2.0}

-- TODO - could these be tied to the rate at which waves are moving?
RATE_SLEW = 0.1
LEVEL_SLEW = 0.2
-- AUDIO_FILE = _path.dust.."audio/tehn/mancini1.wav"
-- AUDIO_FILE = _path.dust.."audio/tehn/mancini2.wav"
AUDIO_FILE = _path.dust.."audio/tehn/drumlite.wav"
-- AUDIO_FILE = _path.dust.."audio/hermit-leaves.wav"
NUM_SOFTCUT_BUFFERS = 6

BUOY_OPTIONS = {
  -- sample
  -- looping?
  -- depth envelope response
  ---- min threshold
  ---- min/max values
  ---- volume
  ---- other options?
  ["octave offset"] = {
    default_value = 0,
    option_range = {-2, 2},
    option_step_value = 1,
    formatter = offset_formatter,
  },
  ["semitone offset"] = {
    default_value = 0,
    option_range = {-7, 7},
    option_step_value = 1,
    formatter = offset_formatter,
  },
  ["cent offset"] = {
    default_value = 0,
    option_range = {-50, 50},
    option_step_value = 1,
    formatter = offset_formatter,
  },
}


g = grid.connect()

function init()
  init_params()
  
  pilings = fresh_grid(0)
  particles = {}
  held_grid_keys = fresh_grid(0)
  buoys = fresh_grid(nil)
  
  displaying_buoys = false

  run = true
  
  old_grid_lighting = fresh_grid(params:get("min_bright"))
  new_grid_lighting = fresh_grid(params:get("min_bright"))
  current_angle_gaps = angle_gaps()
  tide_interval_counter = 0
  smoothing_counter = 0
  next_softcut_buffer = 1
  
  init_softcut()
  
  if RUN then
    tide_maker = metro.init(smoothly_make_tides, params:get("advance_time") / params:get("smoothing"))
    tide_maker:start()
    held_grid_keys_tracker = metro.init(update_held_grid_keys, GRID_KEY_PRESS_METRO_TIME)
    held_grid_keys_tracker:start()
  end
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
    -- softcut.rate(i, 1.0)
    softcut.rate(i, TEST_RATES[i])
    buffer_buoy_map[i] = nil

    softcut.rate_slew_time(i, RATE_SLEW)
    softcut.level_slew_time(i, LEVEL_SLEW)
  end
end

function update_held_grid_keys()
  keys_held = grid_keys_held()
  newly_editing_buoys = false
  
  for _, key_held in ipairs(keys_held) do
    x, y = key_held[1], key_held[2]
    -- TODO - should only increment counters if we're not already editing buoys
    held_grid_keys[y][x] = held_grid_keys[y][x] + 1
    if held_grid_keys[y][x] > (LONG_PRESS_TIME / GRID_KEY_PRESS_METRO_TIME) then
      newly_editing_buoys = true
      held_grid_keys = fresh_grid(0)
      break
    end
  end
  
  if newly_editing_buoys then
    for _, key_held in ipairs(keys_held) do
      x, y = key_held[1], key_held[2]
      buoys[y][x] = buoys[y][x] or Buoy:new()
      buoys[y][x].being_edited = true
      buoys[y][x].active = true
    end
    
    redraw_screen()
  end
end

-- TODO - this gets called relatively often, maybe would be faster not to go through all of
-- them every time
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
  if n == 3 and z == 1 then
    run = not run
  end
  
  if n == 2 then
    displaying_buoys = z == 1
  end
  
  redraw_lights()
end

function degree_formatter(tbl)
  return tbl.value .. " degrees"
end

function offset_formatter(value)
  if value > 0 then
    return "+"..value
  end
  
  return tostring(value)
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
        Buoy.update_depth(buoys[y][x], depth)
        -- buoys[y][x].update_depth(depth)
      end
    end
  end
end

function make_tides()
  old_grid_lighting = deep_copy(new_grid_lighting)
  disperse()
  roll_forward()
  
  -- TODO - should this just use TIDE_GAP so you can set lower gaps than shape size?
  tide_interval_counter = (tide_interval_counter % (TIDE_GAP + #TIDE_SHAPE)) + 1
  if tide_interval_counter == 1 then
    current_angle_gaps = angle_gaps()
  end
  
  total_tide_width = #TIDE_SHAPE + math.max(table.unpack(current_angle_gaps))
  if tide_interval_counter <= total_tide_width then
    new_tide(tide_interval_counter)
  end
  
  velocity_averaging()
  particles_to_lighting()
end

function new_tide(position)
  for y = 1, g.rows do
    num_new_particles = TIDE_SHAPE[position - current_angle_gaps[y]] or 0
    
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
    
    for _, direction in ipairs(POTENTIAL_DISPERSION_DIRECTIONS) do
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
        -- TODO - handle backwards momentum?
        -- currently no way for a particle to actually change direction
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

function redraw_screen()
  screen.clear()
  screen.aa(1)
  screen.font_face(24)
  
  if editing_buoys() then
    redraw_edit_buoy_screen()
  else
    redraw_regular_screen()
  end
  
  screen.update()
end

-- TODO - a buoy line drawing would be cool here
function redraw_edit_buoy_screen()
  height = 0
  screen.level(15)
  screen.font_size(10)
  
  screen.move(64, 28)
  screen.text_center("EDITING BUOYS")
  
  -- TODO - for some reason, not seeing anything on the screen from this
  for option_name, option_config in ipairs(BUOY_OPTIONS) do
    print("processing options")
    -- self.options[option_name] = option_config.default_value
    screen.move(64, height)
    -- screen.text(option_name)
    screen.text_center("EDITING BUOYS")
    
    height = height + 10
  end
  
  
  
  -- BUOY_OPTIONS = {
  -- -- sample
  -- -- looping?
  -- -- depth envelope response
  -- ---- min threshold
  -- ---- min/max values
  -- ---- volume
  -- ---- other options?
  -- ["octave offset"] = {
  --   default_value = 0,
  --   option_range = {-2, 2},
  --   option_step_value = 1,
  --   formatter = offset_formatter,
  -- },
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
  if SHOW_GRID then
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
  options = {},
}

function Buoy:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  
  for option_name, option_config in ipairs(BUOY_OPTIONS) do
    self.options[option_name] = option_config.default_value
  end
  
  return o
end

-- TODO - work on parameterization like multiple samples, etc
-- TODO - should have a map from buffer indexes to buoys so we
----  can stop having the old one play if it gets replaced
----  by the round robin
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
    self.softcut_buffer = next_softcut_buffer
    -- voice stealing by round robin
    old_buffer_buoy = buffer_buoy_map[self.softcut_buffer]
    -- TODO - should round robin ejection be the only option, or
    -- should there be other modes like no voice stealing?
    if old_buffer_buoy then
      old_buffer_buoy.softcut_buffer = -1
    end
    buffer_buoy_map[self.softcut_buffer] = self
    next_softcut_buffer = ((next_softcut_buffer + 1) % NUM_SOFTCUT_BUFFERS) + 1
    softcut.level(self.softcut_buffer, 1.0 * self.depth / max_depth())
    softcut.position(self.softcut_buffer, 1)
    softcut.play(self.softcut_buffer, 1)
  elseif self.depth == 0 then
    softcut.play(self.softcut_buffer, 0)
    buffer_buoy_map[self.softcut_buffer] = nil
    self.softcut_buffer = -1
  end
end

-- grid

g.key = function(x, y, z)
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
  
  redraw_lights()
  redraw_screen()
end

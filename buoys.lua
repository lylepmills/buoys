-- pilings
-- flume mode added
-- wave angles added

RUN = true

WAVE_ANGLE = -45  -- range -60, 60, default 0
FLUME_MODE = false

MIN_LIGHTING = 2      -- range 1..3, default 2
GRID_HEIGHT = 8
GRID_WIDTH = 16
TIDE_GAP = 25
TIDE_HEIGHT = 5
MAX_BRIGHTNESS = 15
-- shape is defined right to left
TIDE_SHAPE = {1, 3, 6, 10, 9, 8, 6, 4, 1}
ADVANCE_TIME = 0.15
SMOOTHING_FACTOR = 4
COLLISION_OVERALL_DAMPING = 0.2
COLLISION_DIRECTIONAL_DAMPING = 0.5
VELOCITY_AVERAGING_FACTOR = 0.6
DISPERSION_FACTOR = 0.005
POTENTIAL_DISPERSION_DIRECTIONS = { { x=1, y=0 }, { x=0, y=1 }, { x=-1, y=0 }, { x=0, y=-1 } }

g = grid.connect()

function init()
  pilings = fresh_grid()
  particles = {}
  
  old_grid_lighting = fresh_grid(MIN_LIGHTING)
  new_grid_lighting = fresh_grid(MIN_LIGHTING)
  current_angle_gaps = angle_gaps()
  tide_interval_counter = 0
  smoothing_counter = 0
  
  if RUN then 
    tide_maker = metro.init(smoothly_make_tides, ADVANCE_TIME / SMOOTHING_FACTOR)
    tide_maker:start()
  end
end

g.key = function(x, y, z)
  if z == 1 then
    pilings[y][x] = is_piling(x, y) and 0 or 1
    clear_particles(x, y)
  end
end

function smoothly_make_tides()
  smoothing_counter = (smoothing_counter + 1) % SMOOTHING_FACTOR
  if smoothing_counter == 0 then
    make_tides()
  end
  
  redraw_screen()
  redraw_lights()
end

function make_tides()
  old_grid_lighting = deep_copy(new_grid_lighting)
  disperse()
  roll_forward()
  
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
  for y = 1, GRID_HEIGHT do
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
  distance = math.tan(degrees_to_radians(WAVE_ANGLE))
  offset = math.abs(math.min(0, round((GRID_HEIGHT - 1) * distance)))
  
  result = {}
  for i = 0, GRID_HEIGHT - 1 do
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
  particle_counts = fresh_grid()
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
        
        if density_diff > 1 and flip_coin(DISPERSION_FACTOR, density_diff) then
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
    if particle.x_pos >= 1 and particle.x_pos <= GRID_WIDTH then
      if particle.y_pos >= 1 and particle.y_pos <= GRID_HEIGHT then
        table.insert(new_particles, particle)
      end
    end
  end
  
  particles = new_particles
end

function velocity_averaging()
  x_vel_sums = fresh_grid()
  y_vel_sums = fresh_grid()
  particle_counts = fresh_grid()
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
  new_grid_lighting = fresh_grid(MIN_LIGHTING)
  
  for _, particle in ipairs(particles) do
    x, y = particle.x_pos, particle.y_pos

    if new_grid_lighting[y][x] < MAX_BRIGHTNESS then
      new_grid_lighting[y][x] = new_grid_lighting[y][x] + 1
      table.insert(new_particles, particle)
    else
      -- discard excess particles
    end
  end
  
  particles = new_particles
end

function is_piling(x, y)
  if FLUME_MODE and (y < 1 or y > GRID_HEIGHT) then
    return true
  end
  return find_in_grid(x, y, pilings, 0) ~= 0
end

function find_in_grid(x, y, grid, default)
  if x < 1 or x > GRID_WIDTH or y < 1 or y > GRID_HEIGHT then
    return default
  end
  
  return grid[y][x]
end

function grid_transition(proportion)
  result = fresh_grid()
  
  for x = 1, GRID_WIDTH do
    for y = 1, GRID_HEIGHT do
      lighting_difference = new_grid_lighting[y][x] - old_grid_lighting[y][x]
      result[y][x] = round(old_grid_lighting[y][x] + (lighting_difference * proportion))
    end
  end
  
  return result
end

function redraw_screen()
  screen.clear()
  screen.aa(1)
  
  if FLUME_MODE then
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
  
  screen.level(15)
  for x = 1, GRID_WIDTH do
    for y = 1, GRID_HEIGHT do
      if is_piling(x, y) then
        screen.circle(x * 8 - 4, y * 8 - 4, 3.4)
        screen.fill()
      end
    end
  end
  
  screen.update()
end

function redraw_lights()
  grid_lighting = grid_transition(smoothing_counter / SMOOTHING_FACTOR)
  
  for x = 1, GRID_WIDTH do
    for y = 1, GRID_HEIGHT do
      brightness = is_piling(x, y) and 0 or grid_lighting[y][x]
      g:led(x, y, brightness)
    end
  end
  g:refresh()
end

function fresh_grid(b)
  b = b or 0
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

function deep_copy(obj)
  if type(obj) ~= 'table' then return obj end
  local res = {}
  for k, v in pairs(obj) do res[deep_copy(k)] = deep_copy(v) end
  return res
end


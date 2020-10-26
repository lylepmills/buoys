-- pilings v2
-- first version of piling collisions modeling

RUN = true

MIN_LIGHTING = 1
GRID_HEIGHT = 8
GRID_WIDTH = 16
TIDE_GAP = 10
TIDE_HEIGHT = 5
MAX_BRIGHTNESS = 15
-- shape is defined right to left
TIDE_SHAPE = {1, 3, 6, 10, 9, 8, 6, 4, 1}
ADVANCE_TIME = 0.15
SMOOTHING_FACTOR = 4
COLLISION_OVERALL_DAMPING = 0.2
COLLISION_DIRECTIONAL_DAMPING = 0.5

g = grid.connect()

function init()
  pilings = fresh_grid()
  particles = {}
  
  old_grid_lighting = fresh_grid(MIN_LIGHTING)
  new_grid_lighting = fresh_grid(MIN_LIGHTING)
  tide_interval_counter = 0
  smoothing_counter = 0
  
  tide_maker = metro.init(smoothly_make_tides, ADVANCE_TIME / SMOOTHING_FACTOR)
  if RUN then tide_maker:start() end
end

g.key = function(x, y, z)
  if z == 1 then
    pilings[y][x] = 1 - pilings[y][x]
  end
end

function smoothly_make_tides()
  smoothing_counter = (smoothing_counter + 1) % SMOOTHING_FACTOR
  if smoothing_counter == 0 then
    make_tides()
  end
  
  redraw_lights()
end

function make_tides()
  old_grid_lighting = deep_copy(new_grid_lighting)
  roll_forward()
  
  tide_interval_counter = tide_interval_counter % (TIDE_GAP + #TIDE_SHAPE) + 1
  if tide_interval_counter <= #TIDE_SHAPE then
    new_tide(tide_interval_counter)
  end
  
  particles_to_lighting()
end

function new_tide(position)
  for i = 1, GRID_HEIGHT do
    for j = 1, TIDE_SHAPE[position] do
      particle = {}
      particle.x_pos = 1
      particle.x_vel = 1.0
      particle.y_pos = i
      particle.y_vel = 0.0
      
      if not is_piling(1, i) then
        table.insert(particles, particle)
      end
    end
  end
end

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
  if x < 1 or x > GRID_WIDTH or y < 1 or y > GRID_HEIGHT then
    return false
  end
  
  return pilings[y][x] ~= 0
end

function grid_transition(proportion)
  result = fresh_grid()

  for i = 1, GRID_HEIGHT do
    for j = 1, GRID_WIDTH do
      lighting_difference = new_grid_lighting[i][j] - old_grid_lighting[i][j]
      result[i][j] = round(old_grid_lighting[i][j] + (lighting_difference * proportion))
    end
  end
  
  return result
end

function redraw_lights()
  grid_lighting = grid_transition(smoothing_counter / SMOOTHING_FACTOR)
  
  for i = 1, GRID_HEIGHT do
    for j = 1, GRID_WIDTH do
      brightness = is_piling(j, i) and 0 or grid_lighting[i][j]
      g:led(j, i, brightness)
    end
  end
  g:refresh()
end

function fresh_grid(brightness)
  b = brightness or 0
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

function flip_coin(probability)
  p = probability or 0.5
  return math.random() < p
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

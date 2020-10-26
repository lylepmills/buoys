-- pilings v1
-- tides are modeled as particles
-- pilings can be toggled but have no effect

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

g = grid.connect()

function init()
  particles = {}
  old_grid_lighting = fresh_grid(MIN_LIGHTING)
  new_grid_lighting = fresh_grid(MIN_LIGHTING)
  pilings = fresh_grid(0)

  tide_interval_counter = 0
  smoothing_counter = 0
  tide_maker = metro.init(smoothly_make_tides, ADVANCE_TIME / SMOOTHING_FACTOR)
  if RUN then
    tide_maker:start()
  end
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
      table.insert(particles, particle)
    end
  end
end

function roll_forward()
  new_particles = {}
  for _, particle in ipairs(particles) do
    if math.random() < math.abs(particle.x_vel) then
      delta = particle.x_vel > 0 and 1 or -1
      particle.x_pos = particle.x_pos + delta
    end
    if math.random() < math.abs(particle.y_vel) then
      delta = particle.y_vel > 0 and 1 or -1
      particle.y_pos = particle.y_pos + delta
    end
    
    if particle.x_pos >= 1 and particle.x_pos <= GRID_WIDTH then
      if particle.y_pos >= 1 and particle.y_pos <= GRID_HEIGHT then
        table.insert(new_particles, particle)
      end
    end
  end
  
  particles = new_particles
end

function particles_to_lighting()
  new_grid_lighting = fresh_grid(MIN_LIGHTING)
  for _, particle in ipairs(particles) do
    x = particle.x_pos
    y = particle.y_pos
    new_grid_lighting[y][x] = math.min(new_grid_lighting[y][x] + 1, MAX_BRIGHTNESS)
  end
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

function round(num)
  return math.floor(num + 0.5)
end

function deep_copy(obj)
  if type(obj) ~= 'table' then return obj end
  local res = {}
  for k, v in pairs(obj) do res[deep_copy(k)] = deep_copy(v) end
  return res
end
  
function redraw_lights()
  grid_lighting = grid_transition(smoothing_counter / SMOOTHING_FACTOR)
  
  for i = 1, GRID_HEIGHT do
    for j = 1, GRID_WIDTH do
      brightness = pilings[i][j] == 0 and grid_lighting[i][j] or 0
      g:led(j, i, brightness)
    end
  end
  g:refresh()
end


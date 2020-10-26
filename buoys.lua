-- pilings v0
-- lights flow smoothly left to right like tides

engine.name = "PolyPerc"

RUN = true

MIN_LIGHTING = 1
GRID_HEIGHT = 8
GRID_WIDTH = 16
TIDE_GAP = 10
TIDE_HEIGHT = 5
MAX_BRIGHTNESS = 15
-- shape is defined right to left
TIDE_SHAPE = {1, 3, 6, 10, 9, 8, 6, 4, 1}
ADVANCE_TIME = 0.1
SMOOTHING_FACTOR = 4

g = grid.connect()

function init()
  old_grid_lighting = fresh_grid(MIN_LIGHTING)
  new_grid_lighting = fresh_grid(MIN_LIGHTING)
  posts = fresh_grid(0)

  tide_interval_counter = 0
  smoothing_counter = 0
  tide_maker = metro.init(smoothly_make_tides, ADVANCE_TIME / SMOOTHING_FACTOR)
  if RUN then
    tide_maker:start()
  end
end

g.key = function(x, y, z)
  if z == 1 then
    posts[y][x] = 1 - posts[y][x]
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
end

function new_tide(position)
  for i = 1, GRID_HEIGHT do
    new_grid_lighting[i][1] = math.min(new_grid_lighting[i][1] + TIDE_SHAPE[position], MAX_BRIGHTNESS)
  end
end

function roll_forward()
  for i = GRID_HEIGHT, 1, -1 do
    for j = GRID_WIDTH, 1, -1 do
      new_grid_lighting[i][j] = old_grid_lighting[i][j-1] or MIN_LIGHTING
    end
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
      brightness = posts[i][j] == 0 and grid_lighting[i][j] or 0
      g:led(j, i, brightness)
    end
  end
  g:refresh()
end

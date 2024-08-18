-- converted to lua/seamstress from daniel shiffman's nature of code (new edition)
-- version0.1 @jaseknighter
--
-- https://thecodingtrain.com/challenges/184-elastic-collisions
-- https://editor.p5js.org/codingtrain/sketches/z8n19RFz9


-- point class
local point = {}
point.__index = point

function point:new(x,y, user_data)
  local p = {}
  p.x = x
  p.y = y
  p.user_data = user_data
  setmetatable(p, point)
  return p
end

-- rectangle class
local rectangle = {}
rectangle.__index = rectangle
function rectangle:new(x, y, w, h)
  local r = {}
  r.x = x
  r.y = y
  r.w = w
  r.h = h
  setmetatable(r, rectangle)
  return r
end

function rectangle:contains(pt)
  return (
    pt.x >= self.x - self.w and
    pt.x <= self.x + self.w and
    pt.y >= self.y - self.h and
    pt.y <= self.y + self.h
  )
end

function rectangle:intersects(range)
  return not(
    range.x - range.w > self.x + self.w or
    range.x + range.w < self.x - self.w or
    range.y - range.h > self.y + self.h or
    range.y + range.h < self.y - self.h
  )
end

-- circle class
local circle = {}
circle.__index = circle

function circle:new(x, y, r)
  local c = {}
  c.x = x
  c.y = y
  c.r = r
  c.r_squared = c.r * c.r
  setmetatable(c, circle)
  return c
end

function circle:contains(pt)
  -- check if the point is in the circle by checking if the euclidean distance of
  -- the point and the center of the circle if smaller or equal to the radius of
  -- the circle
  local d = ((pt.x - self.x) * 2) + ((pt.y - self.y) ^ 2)
  return d <= self.r_squared
end

function circle:intersects(range)
  local x_dist = math.abs(range.x - self.x)
  local y_dist = math.abs(range.y - self.y)

  -- radius of the circle
  local r = self.r

  local w = range.w 
  local h = range.h

  local edges = ((x_dist - w) ^ 2) + ((y_dist - h) ^ 2)

  -- no intersection
  if (x_dist > r + w or y_dist > r + h) then return false end

  -- intersection within the circle
  if (x_dist <= w or y_dist <= h) then return true end

  -- intersection within the circle
  if (x_dist <= w or y_dist <= h) then return true end

  -- intersection on the edge of the circle
  return edges <= self.r_squared
end

-- quadtree class
local quadtree = {}
quadtree.__index = quadtree

function quadtree:new(boundary, capacity)
  local q = {}
  if boundary == nil then
    print("Error: boundary is nil or undefined")
  end

  --  todo: add type checking (see p5js code) 

  q.boundary = boundary
  q.capacity = capacity
  q.points = {}
  q.divided = false
  setmetatable(q, quadtree)

  return q
end

function quadtree:subdivide()
  local x = self.boundary.x
  local y = self.boundary.y
  local w = self.boundary.w / 2
  local h = self.boundary.h / 2

  local ne = rectangle:new(x + w, y - h, w, h)
  self.northeast = quadtree:new(ne, self.capacity)
  local nw = rectangle:new(x - w, y - h, w, h)
  self.northwest = quadtree:new(nw, self.capacity)
  local se = rectangle:new(x + w, y + h, w, h)
  self.southeast = quadtree:new(se, self.capacity)
  local sw = rectangle:new(x - w, y + h, w, h)
  self.southwest = quadtree:new(sw, self.capacity)

  self.divided = true
end

function quadtree:insert(pt)
  if not self.boundary:contains(pt) then
    return false
  end

  if #self.points < self.capacity then
    table.insert(self.points, pt)
    return true
  end

  if not self.divided then
    self:subdivide()
  end

  local northeast = self.northeast:insert(pt)
  local northwest = self.northwest:insert(pt)
  local southeast = self.southeast:insert(pt)
  local southwest = self.southwest:insert(pt)
  if (
    northeast or
    northwest or
    southeast or
    southwest
  ) then
    return true
  end
end

function quadtree:query(range, found)
  local found = found or nil
  if found == nil then 
    found = {}
  end
  if not range:intersects(self.boundary) then
    return found
  end
  
  for i=1, #self.points do
    local p = self.points[i]
    if range:contains(p) then
      table.insert(found,p)
    end
  end

  if self.divided == true then
    self.northwest:query(range, found)
    self.northeast:query(range, found)
    self.southwest:query(range, found)
    self.southeast:query(range, found)
  end
  return found
end

return point, rectangle, circle, quadtree
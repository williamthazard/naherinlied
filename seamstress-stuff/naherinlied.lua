--näherinlied

vector = include('lib/vector')
particle = include('lib/particle')
point,rectangle,circle,quadtree = include('lib/quadtree')

My_String = " "
Displayed_String = ""
History = {} -- table to track previously entered words
toggled = {} -- table to track the state of the grid keys
checked_pairs = {} -- Making sure pairs of particles are not checked twice
particles = {}
rand_palette = {}
mover = 0
History_Index = 0
New_Line = false
keycodes = require 'keycodes'
Sequins = require 'sequins'
_lfos = require 'lfo'

width = 303
height = 184
zoom = 5

local function remap(ascii)
    return ascii % 32 + 36
end

local function process_string(c)
    local tmp = {}
    for i = 1, #c do
      table.insert(tmp, remap(c:byte(i)))
    end
    return tmp
end

G = grid.connect()

G.key = function(x,y,z)
    Momentary[x][y] = z == 1
    if y == 1 then
        if x + 16 * (y  - 1) > #History then return end
        if z == 1 then -- if a grid key is pressed...
            My_String = Displayed_String .. History[x + 16 * (y - 1)]
            print("'" .. My_String .. "'" .. " selected")
            Displayed_String = My_String
            redraw()
            Grid_Dirty = true
        else
            Grid_Dirty = true
            local flag = false
            for j = 1, 8 do
                for k = 1, 16 do
                    if Momentary[k][j] then
                        flag = true
                        break
                    end
                end
            end
            if flag then return end
            if My_String == "" then return end
            --My_String = ""
            Displayed_String = ""
            New_Line = true
            redraw()
        end
    elseif y%2 == 0 then
        if z == 1 then -- if a grid key is pressed...
            press(x,y)
            Grid_Dirty = true
            if toggled[x][y] then
                print("[" .. x .. "]" .. "[" .. y .. "] on")
                if y == 8 then
                    if x > 13 then
                        if x == 16 then
                            osc.send({"localhost","57120"},"/secret_osc",{x,1})
                        else
                            osc.send({"localhost","57120"},"/secret_osc",{x,1.5})
                        end
                    end
                end
            else
                print("[" .. x .. "]" .. "[" .. y .. "] off")
                if y == 8 then
                    if x > 13 then
                        osc.send({"localhost","57120"},"/secret_osc",{x,0})
                    end
                end
            end
        end
    elseif y%2 == 1 then
        if z == 1 then
            set(x,(y-1))
            print("'" .. My_String .. "'" .. " assigned to " .. "[" .. x .. "]" .. "[" .. y-1 .. "]")
            redraw()
            Grid_Dirty = true
        else
            Grid_Dirty = true
            redraw()
        end
    end
end

function press(x,y) -- define a press
    if not toggled[x][y] then -- if the coordinate isn't toggled...
        toggled[x][y] = true -- toggle it on,
    elseif toggled[x][y] then -- otherwise
        toggled[x][y] = false -- toggle it off.
    end
end

function grid_redraw()
    G:all(0)
    -- i will be 1 for #History between 1 and 16, 2 for #History betwen 17 and 32...
    local i = (#History - 1) // 16 + 1
    -- j will be the leftover amount
    local j = (#History - 1) % 16 + 1
    for y = 1, 1 do
      local k = y == i and j or 16
        for x = 1, k do
            if #History > 0 then
                G:led(x,y,4)
            end
            if Momentary[x][y] then
                G:led(x,y,15)
            end
        end
    end
    for x = 1, 16 do
        for y = 2,8 do
            if y%2 == 0 then
                if toggled[x][y] then
                    G:led(x,y,15)
                elseif toggled[x][y] == false then
                    G:led(x,y,0)
                end
            elseif y%2 == 1 then
                G:led(x,y,4)
                if Momentary[x][y] then
                    G:led(x,y,15)
                end
                if toggled[x][y] then
                    toggled[x][y] = false
                end
            end
        end
    end
    G:refresh()
end

local function color_pick()
    for i = 1,#particles do
        for j = 1,3 do
          if rand_palette[i][j] > 1 and rand_palette[i][j] < 255 then
            rand_palette[i][j] = rand_palette[i][j] + math.random(-1,1)
          elseif rand_palette[i][j] == 1 then
            rand_palette[i][j] = rand_palette[i][j] + 1
          elseif rand_palette[i][j] == 255 then
            rand_palette[i][j] = rand_palette[i][j] - 1
          end
        end
    end
end

local function grid_redraw_clock()
    while true do
      clock.sleep(1/30)
      if Grid_Dirty then
        grid_redraw()
        Grid_Dirty = false
      end
    end
end

screen.key = function (code, modifiers, is_repeat, val)
    if val == 0 then return end
    if type(code) == "string" then
        if tab.contains(modifiers, "shift") then
            local new_code = keycodes.shifted[code]
            Displayed_String = Displayed_String .. new_code
        else
            Displayed_String = Displayed_String .. code
        end
        redraw()
    elseif code.name == "backspace" then
        Displayed_String = Displayed_String:sub(1, -2)
    elseif code.name == "up" then
        if #History == 0 then return end
        if New_Line then
            History_Index = #History - 1
            New_Line = false
        else
            History_Index = util.clamp(History_Index - 1, 0, #History)
        end
        Displayed_String = History[History_Index + 1]
    elseif code.name == "down" then
        if #History == 0 or History_Index == nil then return end
        History_Index = util.clamp(History_Index + 1, 0, #History)
        if History_Index == #History then
            Displayed_String = ""
            New_Line = true
        else
            Displayed_String = History[History_Index + 1]
        end
    elseif code.name == "return" and #Displayed_String > 0 then
        table.insert(History, Displayed_String)
        print("'" .. Displayed_String .. "'" .. " added to history")
        x = 10
        y = 165
        mass = screen.get_text_size(Displayed_String)
        rand_palette[#History] = {}
        for j = 1,3 do
            rand_palette[#History][j] = 255
        end
        table.insert(particles,particle.new(x,y,mass,#History))
        My_String = Displayed_String
        Displayed_String = ""
        History_Index = #History
        New_Line = true
    elseif code.name == "lctrl" then
        if #History > 0 then
            print("'" .. History[#History] .. "'" .. " removed from history")
        end
        table.remove(History,#History)
        table.remove(particles,#particles)
        History_Index = #History
        Displayed_String = ""
    end
    redraw()
    grid_redraw()
end

function redraw()
    screen.clear()
    screen.level(10)
    screen.move(5, 175)
    screen.text("> " .. Displayed_String)
    color_pick()

    --create a quadtree
    local boundary = rectangle:new(width / 2, height / 2, width, height)
    local qtree = quadtree:new(boundary, 4)
    checked_pairs = {}

    -- insert all particles
    for i=1, #particles do
        local particle = particles[i]
        if type (particle.position.x) ~= "table" then
            local pt = point:new(particle.position.x, particle.position.y, particle)
            qtree:insert(pt)
        else
            print("ERROR: pos is table", particle.position.x,particle.position.y)
        end
    end

    for i=1, #particles do
        local particle_a = particles[i]
        local range = circle:new(
          particle_a.position.x,
          particle_a.position.y,
          particle_a.r * 2
        )
        -- check only nearby particles based on quadtree
        local points = qtree:query(range)
    
        for j=1, #points do
          local pt = points[j]
          local particle_b = pt.user_data
    
          -- here is where we divert from the p5js script
          -- because lua can't directly check for the equality of two tables
          -- (i think...)
            if particle_b.id ~= particle_a.id then
                local id_a = particle_a.id
                local id_b = particle_b.id
                local pair 
                if id_a < id_b then
                    pair = {id_a,id_b}
                else
                    pair = {id_b,id_a}
                end
                local checked_pairs_has_pair = false
                for k=j, #checked_pairs do
                    local pair_to_check = checked_pairs[k] 
                    if pair_to_check[1] == pair[1] and pair_to_check[2] == pair[2] then
                        checked_pairs_has_pair = true
                    end
                end
                if not checked_pairs_has_pair then
                    particle_a:collide(particle_b)
                    table.insert(checked_pairs,pair)
                end
            end
        end
    end
    for i=1, #particles do
        local particle = particles[i]
        particle:update()
        particle:edges()
        local cr = rand_palette[i][1]
        local cg = rand_palette[i][2]
        local cb = rand_palette[i][3]
        screen.color(cr,cg,cb)
        particle:show(History[i])
    end
    screen.update()
end

function scquit()
    osc.send({"localhost","57120"},"/quitter",{0})
end

function add_parameters() -- helper function to add all of our parameters
    params:add_separator("naherinlied")
    params:add_group("synths",377)
    params:add {
        type = "trigger",
        id = "synths_all_rand",
        name = "        randomize all",
        action = function()
            for i = 1,16 do
                params:set("synth_" .. i .. "_amp",math.random(1,10)*0.1)
                params:set("synth_" .. i .. "_pan",math.random(-10,10)*0.1)
                params:set("synth_".. i .."_poly",math.random(1,8))
                params:set("synth_".. i .."_bus_routing",math.random(1,#buses))
                if i < 5 or (i > 8 and i < 13) then
                    params:set("synth_" .. i .. "_attack",math.random(0,150)*0.1)
                    params:set("synth_" .. i .. "_release",math.random(0,150)*0.1)
                    params:set("synth_" .. i .. "_carrier_ratio",math.random(1,250)*0.1)
                    params:set("synth_" .. i .. "_modulator_ratio",math.random(1,250)*0.1)
                    params:set("synth_" .. i .. "_index",math.random(-1000,1000)*0.1)
                    params:set("synth_" .. i .. "_iScale",math.random(-100,100)*0.1)
                    params:set("synth_" .. i .. "_cutoff",math.random(0,20000))
                    params:set("synth_" .. i .. "_res",math.random(0,30)*0.1)
                    params:set("synth_" .. i .. "_freq_slew",math.random(0,100)*0.01)
                    params:set("synth_" .. i .. "_pan_slew",math.random(0,200)*0.1+0.1)
                else
                    params:set("synth_".. i .."_index",math.random(0,100)*0.1+0.1)
                end
            end
        end
    }
    for i = 1,16 do
        params:add_separator("synth " .. i)
        params:add {
            type = "trigger",
            id = "synth_" .. i .. "_all_rand",
            name = "        randomize all",
            action = function()
                params:set("synth_" .. i .. "_amp",math.random(1,10)*0.1)
                params:set("synth_" .. i .. "_pan",math.random(-10,10)*0.1)
                params:set("synth_".. i .."_poly",math.random(1,8))
                params:set("synth_".. i .."_bus_routing",math.random(1,#buses))
                if i < 5 or (i > 8 and i < 13) then
                    params:set("synth_" .. i .. "_attack",math.random(0,150)*0.1)
                    params:set("synth_" .. i .. "_index_attack",math.random(0,150)*0.1)
                    params:set("synth_" .. i .. "_release",math.random(0,150)*0.1)
                    params:set("synth_" .. i .. "_index_release",math.random(0,150)*0.1)
                    params:set("synth_" .. i .. "_carrier_ratio",math.random(1,250)*0.1)
                    params:set("synth_" .. i .. "_modulator_ratio",math.random(1,250)*0.1)
                    params:set("synth_" .. i .. "_index",math.random(-1000,1000)*0.1)
                    params:set("synth_" .. i .. "_cutoff",math.random(0,20000))
                    params:set("synth_" .. i .. "_res",math.random(0,30)*0.1)
                    params:set("synth_" .. i .. "_freq_slew",math.random(0,100)*0.01)
                    params:set("synth_" .. i .. "_pan_slew",math.random(0,200)*0.1+0.1)
                else
                    params:set("synth_".. i .."_index",math.random(0,100)*0.1+0.1)
                end
            end
        }
        params:add_control("synth_" .. i .. "_amp","amp",controlspec.AMP)
        params:set_action("synth_" .. i .. "_amp",function(value)
            osc.send({"localhost","57120"},"/synth_params",{i,"amp",value})
        end
        )
        params:set("synth_" .. i .. "_amp",0.5)
        params:add {
            type = "trigger",
            id = "synth_" .. i .. "_amp_rand",
            name = "   randomize",
            action = function()
                params:set("synth_" .. i .. "_amp",math.random(1,10)*0.1)
            end
        }
        params:add_control("synth_" .. i .. "_pan","pan",controlspec.PAN)
        params:set_action("synth_" .. i .. "_pan",function(value)
            osc.send({"localhost","57120"},"/synth_params",{i,"pan",value})
        end
        )
        params:add {
            type = "trigger",
            id = "synth_" .. i .. "_pan_rand",
            name = "   randomize",
            action = function()
                params:set("synth_" .. i .. "_pan",math.random(-10,10)*0.1)
            end
        }
        if i < 5 or (i > 8 and i < 13) then
            params:add {
                type = "control",
                id = "synth_"..i.."_attack",
                name = "attack",
                controlspec = controlspec.new(
                    0, -- min
                    15, -- max
                    "lin", -- warp
                    0.1, -- step (output will be rounded to a multiple of step)
                    14-(i+2), -- default
                    'seconds', -- units (an indicator for the unit of measure the data represents)
                    1 / 127 -- quantum (input quantization value. adjustments are made by this fraction of the range)
                ),
                formatter = nil,
                action = function(value)
                    osc.send({"localhost","57120"},"/synth_params",{i,"attack",value})
                end,
            }
            params:add {
                type = "trigger",
                id = "synth_" .. i .. "_attack_rand",
                name = "   randomize",
                action = function()
                    params:set("synth_" .. i .. "_attack",math.random(0,150)*0.1)
                end
            }
            params:add {
                type = "control",
                id = "synth_"..i.."_release",
                name = "release",
                controlspec = controlspec.new(
                    0, -- min
                    15, -- max
                    "lin", -- warp
                    0.1, -- step (output will be rounded to a multiple of step)
                    14-(i+1), -- default
                    'seconds', -- units (an indicator for the unit of measure the data represents)
                    1 / 127 -- quantum (input quantization value. adjustments are made by this fraction of the range)
                ),
                formatter = nil,
                action = function(value)
                    osc.send({"localhost","57120"},"/synth_params",{i,"release",value})
                end,
            }
            params:add {
                type = "trigger",
                id = "synth_" .. i .. "_release_rand",
                name = "   randomize",
                action = function()
                    params:set("synth_" .. i .. "_release",math.random(0,150)*0.1)
                end
            }
            params:add {
                type = "control",
                id = "synth_"..i.."_carrier_ratio",
                name = "fm numerator",
                controlspec = controlspec.new(
                    1, -- min
                    100, -- max
                    "lin", -- warp
                    0.1, -- step (output will be rounded to a multiple of step)
                    1, -- default
                    nil, -- units (an indicator for the unit of measure the data represents)
                    1 / 1000 -- quantum (input quantization value. adjustments are made by this fraction of the range)
                ),
                formatter = nil,
                action = function(value)
                    osc.send({"localhost","57120"},"/synth_params",{i,"carrier-ratio",value})
                end,
            }
            params:add {
                type = "trigger",
                id = "synth_" .. i .. "_carrier_ratio_rand",
                name = "   randomize",
                action = function()
                    params:set("synth_" .. i .. "_carrier_ratio",math.random(1,250)*0.1)
                end
            }
            params:add {
                type = "control",
                id = "synth_"..i.."_modulator_ratio",
                name = "fm denominator",
                controlspec = controlspec.new(
                    1, -- min
                    100, -- max
                    "lin", -- warp
                    0.1, -- step (output will be rounded to a multiple of step)
                    1, -- default
                    nil, -- units (an indicator for the unit of measure the data represents)
                    1 / 1000 -- quantum (input quantization value. adjustments are made by this fraction of the range)
                ),
                formatter = nil,
                action = function(value)
                    osc.send({"localhost","57120"},"/synth_params",{i,"modulator-ratio",value})
                end,
            }
            params:add {
                type = "trigger",
                id = "synth_" .. i .. "_modulator_ratio_rand",
                name = "   randomize",
                action = function()
                    params:set("synth_" .. i .. "_modulator_ratio",math.random(1,250)*0.1)
                end
            }
            params:add {
                type = "control",
                id = "synth_"..i.."_index",
                name = "fm index",
                controlspec = controlspec.new(
                    -100, -- min
                    100, -- max
                    "lin", -- warp
                    0.1, -- step (output will be rounded to a multiple of step)
                    1, -- default
                    nil, -- units (an indicator for the unit of measure the data represents)
                    1 / 1000 -- quantum (input quantization value. adjustments are made by this fraction of the range)
                ),
                formatter = nil,
                action = function(value)
                    osc.send({"localhost","57120"},"/synth_params",{i,"index",value})
                end,
            }
            params:add {
                type = "trigger",
                id = "synth_" .. i .. "_index_rand",
                name = "   randomize",
                action = function()
                    params:set("synth_" .. i .. "_index",math.random(-100,100)*0.1)
                end
            }
            params:add {
                type = "control",
                id = "synth_"..i.."_iScale",
                name = "fm scale",
                controlspec = controlspec.new(
                    -10, -- min
                    10, -- max
                    "lin", -- warp
                    0.05, -- step (output will be rounded to a multiple of step)
                    1, -- default
                    nil, -- units (an indicator for the unit of measure the data represents)
                    1 / 400 -- quantum (input quantization value. adjustments are made by this fraction of the range)
                ),
                formatter = nil,
                action = function(value)
                    osc.send({"localhost","57120"},"/synth_params",{i,"iScale",value})
                end,
            }
            params:add {
                type = "trigger",
                id = "synth_" .. i .. "_iScale_rand",
                name = "   randomize",
                action = function()
                    params:set("synth_" .. i .. "_iScale",math.random(-10,10)*0.1)
                end
            }
            params:add {
                type = "control",
                id = "synth_"..i.."_index_attack",
                name = "fm env attack",
                controlspec = controlspec.new(
                    0, -- min
                    15, -- max
                    "lin", -- warp
                    0.1, -- step (output will be rounded to a multiple of step)
                    14-(i+2), -- default
                    'seconds', -- units (an indicator for the unit of measure the data represents)
                    1 / 127 -- quantum (input quantization value. adjustments are made by this fraction of the range)
                ),
                formatter = nil,
                action = function(value)
                    osc.send({"localhost","57120"},"/synth_params",{i,"index-attack",value})
                end,
            }
            params:add {
                type = "trigger",
                id = "synth_" .. i .. "_index_attack_rand",
                name = "   randomize",
                action = function()
                    params:set("synth_" .. i .. "_index_attack",math.random(0,150)*0.1)
                end
            }
            params:add {
                type = "control",
                id = "synth_"..i.."_index_release",
                name = "fm env release",
                controlspec = controlspec.new(
                    0, -- min
                    15, -- max
                    "lin", -- warp
                    0.1, -- step (output will be rounded to a multiple of step)
                    14-(i+1), -- default
                    'seconds', -- units (an indicator for the unit of measure the data represents)
                    1 / 127 -- quantum (input quantization value. adjustments are made by this fraction of the range)
                ),
                formatter = nil,
                action = function(value)
                    osc.send({"localhost","57120"},"/synth_params",{i,"index-release",value})
                end,
            }
            params:add {
                type = "trigger",
                id = "synth_" .. i .. "_index_release_rand",
                name = "   randomize",
                action = function()
                    params:set("synth_" .. i .. "_index_release",math.random(0,150)*0.1)
                end
            }
            params:add_control("synth_" .. i .. "_cutoff","filter cutoff",controlspec.FREQ)
            params:set_action("synth_" .. i .. "_cutoff",function(value)
                osc.send({"localhost","57120"},"/synth_params",{i,"cutoff",value})
            end
            )
            params:add {
                type = "trigger",
                id = "synth_" .. i .. "_cutoff_rand",
                name = "   randomize",
                action = function()
                    params:set("synth_" .. i .. "_cutoff",math.random(0,20000))
                end
            }
            params:set("synth_" .. i .. "_cutoff",15000)
            params:add_binary("synth_" .. i .. "_cutoff_env","filter cutoff envelope","toggle",0)
            params:set_action("synth_" .. i .. "_cutoff_env",function(value)
                osc.send({"localhost","57120"},"/synth_params",{i,"cutoff_env",value})
            end
            )
            params:add {
                type = "control",
                id = "synth_"..i.."_res",
                name = "filter resonance",
                controlspec = controlspec.new(
                    0, -- min
                    3, -- max
                    "lin", -- warp
                    0.1, -- step (output will be rounded to a multiple of step)
                    1, -- default
                    nil, -- units (an indicator for the unit of measure the data represents)
                    1 / 127 -- quantum (input quantization value. adjustments are made by this fraction of the range)
                ),
                formatter = nil,
                action = function(value)
                    osc.send({"localhost","57120"},"/synth_params",{i,"res",value})
                end,
            }
            params:add {
                type = "trigger",
                id = "synth_" .. i .. "_res_rand",
                name = "   randomize",
                action = function()
                    params:set("synth_" .. i .. "_res",math.random(0,30)*0.1)
                end
            }
            params:add {
                type = "control",
                id = "synth_"..i.."_freq_slew",
                name = "freq slew",
                controlspec = controlspec.new(
                    0, -- min
                    1, -- max
                    "lin", -- warp
                    0.01, -- step (output will be rounded to a multiple of step)
                    0, -- default
                    nil, -- units (an indicator for the unit of measure the data represents)
                    1 / 100 -- quantum (input quantization value. adjustments are made by this fraction of the range)
                ),
                formatter = nil,
                action = function(value)
                    osc.send({"localhost","57120"},"/synth_params",{i,"freq_slew",value})
                end,
            }
            params:add {
                type = "trigger",
                id = "synth_" .. i .. "_freq_slew_rand",
                name = "   randomize",
                action = function()
                    params:set("synth_" .. i .. "_freq_slew",math.random(0,100)*0.01)
                end
            }
            params:add {
                type = "control",
                id = "synth_"..i.."_pan_slew",
                name = "pan slew",
                controlspec = controlspec.new(
                    0.1, -- min
                    20, -- max
                    "lin", -- warp
                    0.1, -- step (output will be rounded to a multiple of step)
                    1, -- default
                    nil, -- units (an indicator for the unit of measure the data represents)
                    1 / 200 -- quantum (input quantization value. adjustments are made by this fraction of the range)
                ),
                formatter = nil,
                action = function(value)
                    osc.send({"localhost","57120"},"/synth_params",{i,"pan_slew",value})
                end,
            }
            params:add {
                type = "trigger",
                id = "synth_" .. i .. "_pan_slew_rand",
                name = "   randomize",
                action = function()
                    params:set("synth_" .. i .. "_pan_slew",math.random(0,200)*0.1+0.1)
                end
            }
        else
            params:add {
                type = "control",
                id = "synth_"..i.."_index",
                name = "decay",
                controlspec = controlspec.new(
                    0.1, -- min
                    10, -- max
                    "lin", -- warp
                    0.1, -- step (output will be rounded to a multiple of step)
                    math.random(0,100)*0.1, -- default
                    nil, -- units (an indicator for the unit of measure the data represents)
                    1 / 127 -- quantum (input quantization value. adjustments are made by this fraction of the range)
                ),
                formatter = nil,
                action = function(value)
                    osc.send({"localhost","57120"},"/synth_params",{i,"index",value})
                end,
            }
            params:add {
                type = "trigger",
                id = "synth_" .. i .. "_index_rand",
                name = "   randomize",
                action = function()
                    params:set("synth_".. i .."_index",math.random(0,100)*0.1+0.1)
                end
            }
        end
        params:add {
            type = "control",
            id = "synth_"..i.."_poly",
            name = "polyphony",
            controlspec = controlspec.new(
                1, -- min
                8, -- max
                "lin", -- warp
                1, -- step (output will be rounded to a multiple of step)
                8, -- default
                nil, -- units (an indicator for the unit of measure the data represents)
                1/8 -- quantum (input quantization value. adjustments are made by this fraction of the range)
            ),
            formatter = nil,
            action = function(value)
                osc.send({"localhost","57120"},"/synth_params",{i,"poly",value})
            end,
        }
        params:add {
            type = "trigger",
            id = "synth_" .. i .. "_poly_rand",
            name = "   randomize",
            action = function()
                params:set("synth_".. i .."_poly",math.random(1,8))
            end
        }
        buses = {}
        for i = 0, 64 do
            buses[i] = i
        end
        params:add_option("synth_" .. i .. "_bus_routing", "bus routing", buses, 1)
        params:set_action("synth_" .. i .. "_bus_routing",function(value)
            osc.send({"localhost","57120"},"/synth_params",{i-1,"bus",value-1})
        end
        )
        params:add {
            type = "trigger",
            id = "synth_" .. i .. "_bus_rand",
            name = "   randomize",
            action = function()
                params:set("synth_".. i .."_bus_routing",math.random(1,#buses))
            end
        }
    end
    params:add_group("samplers",80)
    local j = 1
    for i = 1,32 do
        if i % 2 == 0 then
            params:add_separator("sampler " .. j)
            params:add_control("sampler_" .. j .. "_amp","amp",controlspec.AMP)
            params:set_action("sampler_" .. j .. "_amp",function(value)
                osc.send({"localhost","57120"},"/samp_params",{i+14,"amp",value})
            end
            )
            params:set("sampler_" .. j .. "_amp",1,1)
            params:add_control("sampler_" .. j .. "_cutoff","filter cutoff",controlspec.FREQ)
            params:set_action("sampler_" .. j .. "_cutoff",function(value)
                osc.send({"localhost","57120"},"/samp_params",{i+14,"cutoff",value})
            end
            )
            params:set("sampler_" .. j .. "_cutoff",15000)
            params:add {
                type = "control",
                id = "sampler_"..j.."_res",
                name = "filter resonance",
                controlspec = controlspec.new(
                    0, -- min
                    3, -- max
                    "lin", -- warp
                    0.1, -- step (output will be rounded to a multiple of step)
                    1, -- default
                    nil, -- units (an indicator for the unit of measure the data represents)
                    1 / 127 -- quantum (input quantization value. adjustments are made by this fraction of the range)
                ),
                formatter = nil,
                action = function(value)
                    osc.send({"localhost","57120"},"/samp_params",{i+14,"res",value})
                end,
            }
            params:add_option("sampler_" .. i .. "_bus_routing", "bus routing", buses, 1)
            params:set_action("sampler_" .. i .. "_bus_routing",function(value)
            osc.send({"localhost","57120"},"/samp_params",{i+14,"bus",value-1})
        end
        )
            j = j + 1
        end
    end
    params:add_group("drums",65)
    for i = 1,13 do
        params:add_separator("drum " .. i)
        params:add_control("drum_" .. i .. "_amp","amp",controlspec.AMP)
        params:set_action("drum_" .. i .. "_amp",function(value)
            osc.send({"localhost","57120"},"/drum_params",{i+47,"amp",value})
        end
        )
        params:set("drum_" .. i .. "_amp",1,1)
        params:add_control("drum_" .. i .. "_cutoff","filter cutoff",controlspec.FREQ)
        params:set_action("drum_" .. i .. "_cutoff",function(value)
            osc.send({"localhost","57120"},"/drum_params",{i+47,"cutoff",value})
        end
        )
        params:set("drum_" .. i .. "_cutoff",15000)
        params:add {
            type = "control",
            id = "drum_"..i.."_res",
            name = "filter resonance",
            controlspec = controlspec.new(
                    0, -- min
                    3, -- max
                    "lin", -- warp
                    0.1, -- step (output will be rounded to a multiple of step)
                    1, -- default
                    nil, -- units (an indicator for the unit of measure the data represents)
                    1 / 127 -- quantum (input quantization value. adjustments are made by this fraction of the range)
                ),
                formatter = nil,
                action = function(value)
                    osc.send({"localhost","57120"},"/drum_params",{i+47,"res",value})
                end,
            }
        params:add_option("drum_" .. i .. "_bus_routing", "bus routing", buses, 1)
            params:set_action("drum_" .. i .. "_bus_routing",function(value)
            osc.send({"localhost","57120"},"/drum_params",{i+47,"bus",value-1})
        end
        )
    end
    pan_lfo = {}
    ind_lfo = {}
    cut_lfo = {}
    res_lfo = {}
    lfo_periods = {1/2,3/4,1,1.5,2,3,4,6,8,16,32,64,128,256,512,1024}
    for i = 1,16 do
        pan_lfo[i] = _lfos:add{min = -1, max = 1, depth = 1, mode = 'clocked', period = lfo_periods[math.random(5,10)]}
        ind_lfo[i] = _lfos:add{min = -100, max = 100, depth = 1, mode = 'clocked', period = lfo_periods[math.random(5,10)]}
    end
    for i = 1,32 do
        cut_lfo[i] = _lfos:add{min = 500, max = 15000, depth = 1, mode = 'clocked', period = lfo_periods[math.random(5,10)]}
        res_lfo[i] = _lfos:add{min = 0, max = 2, depth = 1, mode = 'clocked', period = lfo_periods[math.random(5,10)]}
    end
    params:add_group('lfos',1536)
    for i = 1,16 do
        pan_lfo[i]:add_params('synth_' .. i .. '_pan_lfo','synth ' .. i .. ' pan')
        pan_lfo[i]:set('action', function(scaled, raw) 
          params:set("synth_".. i .."_pan",scaled)
        end)
        pan_lfo[i]:start()
        ind_lfo[i]:add_params('synth_' .. i .. '_ind_lfo','synth ' .. i .. ' fm index')
        ind_lfo[i]:set('action', function(scaled, raw) 
          params:set("synth_".. i .."_index",scaled)
        end)
        ind_lfo[i]:start()
        cut_lfo[i]:add_params('synth_' .. i .. '_cut_lfo','synth ' .. i .. ' filter cutoff')
        cut_lfo[i]:set('action', function(scaled, raw) 
          params:set("synth_".. i .."_cutoff",scaled)
        end)
        cut_lfo[i]:start()
        res_lfo[i]:add_params('synth_' .. i .. '_res_lfo','synth ' .. i .. ' filter resonance')
        res_lfo[i]:set('action', function(scaled, raw) 
          params:set("synth_".. i .."_res",scaled)
        end)
        res_lfo[i]:start()
        cut_lfo[i+16]:add_params('sampler_' .. i .. '_cut_lfo','sampler ' .. i .. ' filter cutoff')
        cut_lfo[i+16]:set('action', function(scaled, raw) 
          params:set("sampler_".. i .."_cutoff",scaled)
        end)
        cut_lfo[i+16]:start()
        res_lfo[i+16]:add_params('sampler_' .. i .. '_res_lfo','sampler ' .. i .. ' filter resonance')
        res_lfo[i+16]:set('action', function(scaled, raw) 
          params:set("sampler_".. i .."_res",scaled)
        end)
        res_lfo[i+16]:start()
    end
    params:bang()
end

function init()
    -- print('initializing supercollider')
    -- util.os_capture('sclang desktop/other/sc-docs/naherinlied.scd')
    -- print('supercollider initialized')
    refresh_metro = metro.init(
    redraw, -- function to execute
    1/60, -- how often (here, 60 fps)
    -1 -- how many times (here, forever)
    )
    refresh_metro:start() -- start the timer
    Step = {} -- table to store our sequencers
    Grid_Dirty = true
    Momentary = {}
    for x = 1, 16 do
        Momentary[x] = {}
        for y = 1, 8 do
            Momentary[x][y] = false
        end
    end
    for x = 1,16 do -- for each x-column (16 on a 128-sized grid)...
        toggled[x] = {} -- create an x state tracker
        for y = 1,8 do -- for each y-row (8 on a 128-sized grid)...
            toggled[x][y] = false -- create a y state tracker
        end
    end
    S = {}
    for x = 1,16 do
        S[x] = {}
        for y = 1,8 do
            S[x][y] = Sequins(process_string(My_String))
        end
    end
    function set(x,y)
        S[x][y]:settable(process_string(My_String))
    end
    print('näherinlied')
    screen.set_fullscreen(false)
    screen.set_size(width,height,zoom)
    clock.run(grid_redraw_clock)
    add_parameters()
    --some sequences
    seqs = {}
    seqs[1] = Sequins({0.25,0.25,15.5})
    seqs[2] = Sequins({0.5,15,0.5})
    seqs[3] = Sequins({0.25,15.25,0.25,0.25})
    seqs[4] = Sequins({0.5,0.5,14.5,0.5})
    for i = 1, 16 do
        Step[i] = {}
        for j = 2, 8 do
            if j % 2 == 0 then
                Step[i][j] = function()
                    while true do
                        if j == 2 then
                            if i == 1 then
                            --if i < 3 then
                                clock.sync(math.random(40,120)*0.1)
                                --clock.sync(8)
                            elseif i == 2 then
                                clock.sync(math.random(40,120)*0.1)
                                --clock.sync(8)
                            elseif i > 2 and i < 9 then
                                clock.sync(((S[i][j]()-35)/(S[i][j]()-35))*8)
                            elseif i == 9 then
                                clock.sync(seqs[1]())
                            elseif i == 10 then
                                clock.sync(seqs[2]())
                            elseif i == 11 then
                                clock.sync(seqs[3]())
                            elseif i == 12 then
                                clock.sync(seqs[4]())
                            elseif i == 13 then
                                clock.sync(3)
                            elseif i == 14 then
                                clock.sync(3/2)
                            elseif i == 15 then
                                clock.sync(1)
                            elseif i == 16 then
                                clock.sync(1/2)
                            end
                        elseif j == 4 or j == 6 then
                            clock.sync((S[i][j]()-35)/(S[i][j]()-35)*2)
                        elseif j == 8 then
                            if i == 1 then
                                clock.sync(4)
                            elseif i == 6 then
                                clock.sync(16)
                            else
                                clock.sync(4)
                            end
                        end 
                        if toggled[i][j] then
                            local note_num = S[i][j]()
                            if j == 2 then
                                if i < 3 then
                                    osc.send({"localhost","57120"},"/synth_osc",{i,note_num-12})
                                elseif (i > 2 and i < 5) or (i > 8 and i < 13) then
                                    osc.send({"localhost","57120"},"/synth_osc",{i,note_num})
                                elseif (i > 4 and i < 9) or (i > 13 and i < 17) then
                                    osc.send({"localhost","57120"},"/synth_osc",{i,note_num+12})
                                else
                                    osc.send({"localhost","57120"},"/synth_osc",{i,note_num}) 
                                end
                                print("[" .. i .. "][" .. j .. "] playing midi note " .. note_num)
                            elseif j == 4 then
                                if i % 2 == 1 then
                                    local play_pos = util.linlin(36,62,0,0.9,S[i][j]())
                                    local play_dur = util.linlin(36,62,0.001,0.1,S[i][j]())
                                    osc.send({"localhost","57120"},"/samp_osc",{i+15,1,play_pos,play_pos+play_dur,1})
                                    print("[" .. i .. "][" .. j .. "] triggering sample")
                                else
                                    local rate = (S[i][j]()-35)/(S[i][j]()-35)
                                    osc.send({"localhost","57120"},"/samp_osc",{i+15,rate})
                                    print("[" .. i .. "][" .. j .. "] sampler playback rate set to " .. rate)
                                end
                            elseif j == 6 then
                                if i % 2 == 1 then
                                    local play_pos = util.linlin(36,62,0,0.9,S[i][j]())
                                    local play_dur = util.linlin(36,62,0.001,0.1,S[i][j]())
                                    osc.send({"localhost","57120"},"/samp_osc",{i+31,1,play_pos,play_pos+play_dur,1})
                                    print("[" .. i .. "][" .. j .. "] triggering sample")
                                else
                                    local rate = (S[i][j]()-35)/(S[i][j]()-35)
                                    osc.send({"localhost","57120"},"/samp_osc",{i+31,rate})
                                    print("[" .. i .. "][" .. j .. "] sampler playback rate set to " .. rate)
                                end
                            elseif j == 8 then
                                if i < 14 then
                                    if i > 5 then
                                        osc.send({"localhost","57120"},"/drum_osc",{i+47,math.random(1,8),1})
                                    else
                                        osc.send({"localhost","57120"},"/drum_osc",{i+47,i,1})
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    for i = 1, 16 do
        for j = 2, 8 do
            if j%2 == 0 then
                clock.run(Step[i][j])
            end
        end
    end
end
function cleanup()
    G:all(0)
    G:refresh()
end

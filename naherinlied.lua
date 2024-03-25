--näherinlied

My_String = " "
Displayed_String = ""
History = {} -- table to track previously entered words
toggled = {} -- table to track the state of the grid keys
History_Index = 0
New_Line = false
keycodes = require 'keycodes'
Sequins = require 'sequins'

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
        My_String = Displayed_String
        Displayed_String = ""
        History_Index = #History
        New_Line = true
    elseif code.name == "lctrl" then
        if #History > 0 then
            print("'" .. History[#History] .. "'" .. " removed from history")
        end
        table.remove(History,#History)
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
    for i = 1, 22 do
        if not (History_Index - i >= 0) then break end
        screen.move(5, 175 - 10 * i)
        screen.text(History[History_Index - i + 1])
    end
    screen.update()
end

function add_parameters() -- helper function to add all of our parameters (208)
    params:add_separator("naherinlied")
    params:add_group("synths",32)
    for i = 1,16 do
        params:add_separator("synth " .. i)
        params:add_control("synth_" .. i .. "_amp","amp",controlspec.AMP)
        params:set_action("synth_" .. i .. "_amp",function(value)
            osc.send({"localhost","57120"},"/synth_params",{i,"amp",value})
        end
        )
        params:set("synth_" .. i .. "_amp",0.5,1)
        
        -- if i < 5 or (i > 8 and i < 13) then
        --     params:add {
        --         type = "control",
        --         id = "synth_"..i.."_attack",
        --         name = "attack",
        --         controlspec = controlspec.new(
        --             0, -- min
        --             10, -- max
        --             "lin", -- warp
        --             0.1, -- step (output will be rounded to a multiple of step)
        --             math.random(0,100)*0.1, -- default
        --             'seconds', -- units (an indicator for the unit of measure the data represents)
        --             1 / 127 -- quantum (input quantization value. adjustments are made by this fraction of the range)
        --         ),
        --         formatter = nil,
        --         action = function(value)
        --             osc.send({"localhost","57120"},"/synth_params",{i,"attack",value})
        --         end,
        --     }
        --     params:add {
        --         type = "control",
        --         id = "synth_"..i.."_release",
        --         name = "release",
        --         controlspec = controlspec.new(
        --             0, -- min
        --             10, -- max
        --             "lin", -- warp
        --             0.1, -- step (output will be rounded to a multiple of step)
        --             math.random(1,100)*0.1, -- default
        --             'seconds', -- units (an indicator for the unit of measure the data represents)
        --             1 / 127 -- quantum (input quantization value. adjustments are made by this fraction of the range)
        --         ),
        --         formatter = nil,
        --         action = function(value)
        --             osc.send({"localhost","57120"},"/synth_params",{i,"release",value})
        --         end,
        --     }
        --     params:add {
        --         type = "control",
        --         id = "synth_"..i.."_modnum",
        --         name = "fm numerator",
        --         controlspec = controlspec.new(
        --             1, -- min
        --             4, -- max
        --             "lin", -- warp
        --             1, -- step (output will be rounded to a multiple of step)
        --             math.random(1,4), -- default
        --             nil, -- units (an indicator for the unit of measure the data represents)
        --             1 / 4 -- quantum (input quantization value. adjustments are made by this fraction of the range)
        --         ),
        --         formatter = nil,
        --         action = function(value)
        --             osc.send({"localhost","57120"},"/synth_params",{i,"modnum",value})
        --         end,
        --     }
        --     params:add {
        --         type = "control",
        --         id = "synth_"..i.."_modeno",
        --         name = "fm denominator",
        --         controlspec = controlspec.new(
        --             1, -- min
        --             4, -- max
        --             "lin", -- warp
        --             1, -- step (output will be rounded to a multiple of step)
        --             math.random(1,4), -- default
        --             nil, -- units (an indicator for the unit of measure the data represents)
        --             1 / 4 -- quantum (input quantization value. adjustments are made by this fraction of the range)
        --         ),
        --         formatter = nil,
        --         action = function(value)
        --             osc.send({"localhost","57120"},"/synth_params",{i,"modeno",value})
        --         end,
        --     }
        --     params:add_binary("synth_" .. i .. "_cutoff_env","filter cutoff envelope","toggle",0)
        --     params:set_action("synth_" .. i .. "_cutoff_env",function(value)
        --         osc.send({"localhost","57120"},"/synth_params",{i,"cutoff_env",value})
        --     end
        --     )
        --     params:add {
        --         type = "control",
        --         id = "synth_"..i.."_freq_slew",
        --         name = "freq slew",
        --         controlspec = controlspec.new(
        --             0, -- min
        --             1, -- max
        --             "lin", -- warp
        --             0.01, -- step (output will be rounded to a multiple of step)
        --             0, -- default
        --             nil, -- units (an indicator for the unit of measure the data represents)
        --             1 / 100 -- quantum (input quantization value. adjustments are made by this fraction of the range)
        --         ),
        --         formatter = nil,
        --         action = function(value)
        --             osc.send({"localhost","57120"},"/synth_params",{i,"freq_slew",value})
        --         end,
        --     }
        --     params:add {
        --         type = "control",
        --         id = "synth_"..i.."_pan_slew",
        --         name = "pan slew",
        --         controlspec = controlspec.new(
        --             0.1, -- min
        --             20, -- max
        --             "lin", -- warp
        --             0.1, -- step (output will be rounded to a multiple of step)
        --             1, -- default
        --             nil, -- units (an indicator for the unit of measure the data represents)
        --             1 / 127 -- quantum (input quantization value. adjustments are made by this fraction of the range)
        --         ),
        --         formatter = nil,
        --         action = function(value)
        --             osc.send({"localhost","57120"},"/synth_params",{i,"pan_slew",value})
        --         end,
        --     }
        --     -- buses = {"delay + reverb", "reverb only", "Carter's Delay", "dry"}
        --     -- params:add_option("synth_" .. i .. "_bus_routing", "bus routing", buses, 2)
        --     -- params:set_action("synth_" .. i .. "_bus_routing",function(value)
        --     --     osc.send({"localhost","57120"},"/synth_params",{i-1,"bus",value})
        --     -- end
        --     -- )
        -- end
    end
    params:add_group("samplers",32)
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
            j = j + 1
        end
    end
    params:add_group("drums",26)
    for i = 1,13 do
        params:add_separator("drum" .. i)
        params:add_control("drum_" .. i .. "_amp","amp",controlspec.AMP)
        params:set_action("drum_" .. i .. "_amp",function(value)
            osc.send({"localhost","57120"},"/drum_params",{i+47,"amp",value})
        end
        )
        params:set("drum_" .. i .. "_amp",1,1)
    end
    params:bang()
end

function init()
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
    screen.set_size(303,184,5)
    clock.run(grid_redraw_clock)
    add_parameters()
    for i = 1, 16 do
        Step[i] = {}
        for j = 2, 8 do
            if j % 2 == 0 then
                Step[i][j] = function()
                    while true do
                        if j == 2 then
                            if i < 3 then
                                clock.sync(math.random(4,12))
                            elseif i > 2 and i < 9 then
                                clock.sync(S[i][j]()/S[i][j]())
                            elseif i == 9 then
                                clock.sync(8)
                            elseif i == 10 then
                                clock.sync(5)
                            elseif i == 11 then
                                clock.sync(4)
                            elseif i == 12 then
                                clock.sync(2)
                            elseif i == 13 then
                                clock.sync(1)
                            elseif i == 14 then
                                clock.sync(3/4)
                            elseif i == 15 then
                                clock.sync(1/2)
                            elseif i == 16 then
                                clock.sync(1/4)
                            end
                        elseif j == 4 or j == 6 then
                            clock.sync(S[i][j]()/S[i][j]())
                        elseif j == 8 then
                            clock.sync(1)
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
                                    osc.send({"localhost","57120"},"/samp_osc",{i+15,1,0,1,1})
                                    print("[" .. i .. "][" .. j .. "] triggering sample")
                                else
                                    local rate = S[i][j]()/S[i][j]()
                                    osc.send({"localhost","57120"},"/samp_osc",{i+15,rate})
                                    print("[" .. i .. "][" .. j .. "] sampler playback rate set to " .. rate)
                                end
                            elseif j == 6 then
                                if i % 2 == 1 then
                                    osc.send({"localhost","57120"},"/samp_osc",{i+31,1,0,1,1})
                                    print("[" .. i .. "][" .. j .. "] triggering sample")
                                else
                                    local rate = S[i][j]()/S[i][j]()
                                    osc.send({"localhost","57120"},"/samp_osc",{i+31,rate})
                                    print("[" .. i .. "][" .. j .. "] sampler playback rate set to " .. rate)
                                end
                            elseif j == 8 then
                                if i < 14 then
                                    osc.send({"localhost","57120"},"/drum_osc",{i+47,i,1})
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
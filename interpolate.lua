-- https://yougame.biz/00/ ~ uwukson4800

_G._DEBUG = false
local c_entity = require 'gamesense/entity'

local animation_fix = { }
animation_fix.data = {
    layers = { },
    server_anim_states = { },
    history = 64,
    initialized = false
}

function animation_fix:initialize_layers()
    self.data.layers = { }
    
    for i = 0, 12 do
        self.data.layers[i] = {
            cycle = 0,
            weight = 0,
            playback_rate = 0,
            sequence = 0
        }
    end
    
    self.data.initialized = true
end

function animation_fix:debug_print(...)
    if _DEBUG then
        print('[ANIMS] ', ...)
    end
end

function animation_fix:capture_state()
    local me = entity.get_local_player()
    if not me then
        return nil
    end
    
    local self_index = c_entity(me)
    local anim_state = self_index:get_anim_state()
    if not anim_state then
        return nil
    end

    local state = {
        time = globals.curtime(),
        layers = { }
    }
    
    for layer_idx, _ in pairs(self.data.layers) do
        local layer = self_index:get_anim_overlay(layer_idx)
        if layer then
            state.layers[layer_idx] = {
                cycle = layer.cycle,
                weight = layer.weight,
                playback_rate = layer.playback_rate,
                sequence = layer.sequence
            }
        end
    end

    return state
end

function animation_fix:setup_command()
    if not self.data.initialized then
        self:initialize_layers()
    end
    
    local state = self:capture_state()
    if not state then
        return
    end
    
    table.insert(self.data.server_anim_states, state)
    
    if #self.data.server_anim_states > self.data.history then
        table.remove(self.data.server_anim_states, 1)
    end
end

function animation_fix:find_interpolation_states(time)
    local server_states = self.data.server_anim_states
    
    -- if we don't have information for interpolate our states we can't interpolate
    if #server_states < 2 then
        return nil, nil
    end
    
    for i = #server_states - 1, 1, -1 do
        if server_states[i].time <= time and server_states[i+1].time >= time then
            return server_states[i], server_states[i+1]
        end
    end
    
    return server_states[#server_states - 1], server_states[#server_states]
end

function animation_fix:lerp(v1, v2, t)
    return v1 + (v2 - v1) * t
end

function animation_fix:apply_interpolated_state(state1, state2, t)
    local me = entity.get_local_player()
    if not me then
        return
    end
    
    local self_index = c_entity(me)

    for layer_idx, _ in pairs(self.data.layers) do
        local layer = self_index:get_anim_overlay(layer_idx)
        if layer and state1.layers[layer_idx] and state2.layers[layer_idx] then
            local layer1 = state1.layers[layer_idx]
            local layer2 = state2.layers[layer_idx]
            
            -- if the layer is the same as the previous one, don't interpolate
            layer.cycle = (layer1.cycle == layer2.cycle) and layer2.cycle or self:lerp(layer1.cycle, layer2.cycle, t)
            layer.weight = (layer1.weight == layer2.weight) and layer2.weight or self:lerp(layer1.weight, layer2.weight, t)
            layer.playback_rate = (layer1.playback_rate == layer2.playback_rate) and layer2.playback_rate or self:lerp(layer1.playback_rate, layer2.playback_rate, t)
            layer.sequence = (layer1.sequence == layer2.sequence) and layer2.sequence or self:lerp(layer1.sequence, layer2.sequence, t)
        end
    end
end

function animation_fix:interpolate()
    if not self.data.initialized then
        return
    end
    
    local me = entity.get_local_player()
    if not me then
        return
    end
    
    local current_time = globals.curtime()
    
    local state1, state2 = self:find_interpolation_states(current_time)
    if not state1 or not state2 then
        return
    end
    
    local time_diff = state2.time - state1.time
    if time_diff <= 0 then
        return
    end
    
    local t = (current_time - state1.time) / time_diff
    t = math.min(1, math.max(0, t))

    self:apply_interpolated_state(state1, state2, t)
    
    if _DEBUG then
        self:debug_print(string.format(
            'Interpolating: t=%.2f, states: %.2f -> %.2f', 
            t, state1.time, state2.time
        ))
    end
end

function animation_fix:reset()
    self.data.server_anim_states = { }
    self:initialize_layers()
    self:debug_print('reset')
end

--@author: Hack3r_jopi ~ https://yougame.biz/j/
--@description: https://yougame.biz/threads/345134/
local event_list = {
    on_setup_command = function(ctx)
        animation_fix:setup_command()
    end,
    on_pre_render = function()
        animation_fix:interpolate()
    end,
    on_round_start = function()
        animation_fix:reset()
    end,
    on_player_death = function(ctx)
        if not (ctx.userid and ctx.attacker) then
            return
        end

        local me = entity.get_local_player()
        if me ~= client.userid_to_entindex(ctx.userid) then
            return
        end

        animation_fix:reset()
    end,
    on_level_init = function()
        animation_fix:reset()
    end,
    on_shutdown = function()
        local v1 = collectgarbage('count')
    
        if animation_fix then
            if animation_fix.data then
                animation_fix.data.layers = { }
                animation_fix.data.server_anim_states = { }
                animation_fix.data = { }
            end
            
            for k, _ in pairs(animation_fix) do
                animation_fix[k] = nil
            end
            
            animation_fix = nil
        end
    
        if _G._DEBUG then
            _G._DEBUG = nil
        end
    
        collectgarbage('collect')
        collectgarbage('collect') -- =)
    
        local v2 = collectgarbage('count')
        local v3 = v1 - v2
        
        print('[ANIMS] Memory cleared: ' .. string.format('%.2f', v3) .. ' KB')
    end
}

for k, v in next, event_list do
    client.set_event_callback(k:sub(4), function(ctx)
        v(ctx)
    end)
end

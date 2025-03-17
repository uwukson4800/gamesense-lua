-- https://yougame.biz/00/ ~ uwukson4800
-- https://t.me/debugoverlay ~ visit =)

_G._DEBUG = false
local c_entity = require 'gamesense/entity'

local animations = { }
animations.data = {
    layers = { },
    server_anim_states = { },
    history = 64,
    extrapolation_time = 0.05,
    initialized = false,
}

function animations:initialize_layers()
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

function animations:debug_print(...)
    if _DEBUG then
        print('[ANIMS] ', ...)
    end
end

function animations:capture_state()
    local me = entity.get_local_player()
    if not me then return nil end

    local self_index = c_entity(me)
    local anim_state = self_index:get_anim_state()
    if not anim_state then return nil end

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

function animations:setup_command()
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

function animations:get_extrapolation_states()
    local server_states = self.data.server_anim_states

    if #server_states < 2 then
        return nil, nil
    end
    
    return server_states[#server_states - 1], server_states[#server_states]
end

function animations:extrapolate_value(v1, v2, rate, time)
    local rate_of_change = (v2 - v1) / rate
    return v2 + rate_of_change * time
end

function animations:apply_extrapolated_state(state1, state2)
    local me = entity.get_local_player()
    if not me then
        return
    end

    local self_index = c_entity(me)
    local time_diff = state2.time - state1.time

    if time_diff < 0.001 then
        return
    end
    
    for layer_idx, _ in pairs(self.data.layers) do
        local layer = self_index:get_anim_overlay(layer_idx)
        if layer and state1.layers[layer_idx] and state2.layers[layer_idx] then
            local layer1 = state1.layers[layer_idx]
            local layer2 = state2.layers[layer_idx]

            if layer1.cycle ~= layer2.cycle then
                layer.cycle = layer.cycle > 1 and 1 or self:extrapolate_value(layer1.cycle, layer2.cycle, time_diff, self.data.extrapolation_time)
            end
            
            if layer1.weight ~= layer2.weight then
                layer.weight = layer.weight > 1 and 1 or self:extrapolate_value(layer1.weight, layer2.weight, time_diff, self.data.extrapolation_time)
            end
            
            if layer1.playback_rate ~= layer2.playback_rate then
                layer.playback_rate = self:extrapolate_value(layer1.playback_rate, layer2.playback_rate, time_diff, self.data.extrapolation_time)
            end
            
            if layer1.sequence ~= layer2.sequence then
                layer.sequence = self:extrapolate_value(layer1.sequence, layer2.sequence, time_diff, self.data.extrapolation_time)
            end
        end
    end
end

function animations:extrapolate()
    if not self.data.initialized then
        return
    end

    local me = entity.get_local_player()
    if not me then
        return
    end

    local state1, state2 = self:get_extrapolation_states()
    if not state1 or not state2 then
        return
    end

    self:apply_extrapolated_state(state1, state2)
    
    if _DEBUG then
        self:debug_print(string.format('Extrapolating animations by %.2f seconds', self.data.extrapolation_time))
    end
end

function animations:reset()
    self.data.server_anim_states = { }
    self:initialize_layers()
    self:debug_print('reset')
end

--@author: Hack3r_jopi ~ https://yougame.biz/lua/
--@description: https://yougame.biz/threads/345134/
local event_list = {
    on_setup_command = function(ctx)
        animations:setup_command()
    end,
    on_pre_render = function()
        animations:extrapolate()
    end,
    on_round_start = function()
        animations:reset()
    end,
    on_player_death = function(ctx)
        if not (ctx.userid and ctx.attacker) then
            return
        end

        local me = entity.get_local_player()
        if me ~= client.userid_to_entindex(ctx.userid) then
            return
        end
        animations:reset()
    end,
    on_level_init = function()
        animations:reset()
    end,
    on_shutdown = function()
        local v1 = collectgarbage('count')
        if animations then
            if animations.data then
                animations.data.layers = { }
                animations.data.server_anim_states = { }
                animations.data = { }
            end
            for k, _ in pairs(animations) do
                animations[k] = nil
            end
            animations = nil
        end
        if _G._DEBUG then
            _G._DEBUG = nil
        end
        collectgarbage('collect')
        collectgarbage('collect')
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

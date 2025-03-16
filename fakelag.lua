-- https://yougame.biz/00/ ~ uwukson4800
-- https://t.me/debugoverlay ~ visit =)

_G._DEBUG = false
local c_entity = require 'gamesense/entity'

local animation_fix = { }
animation_fix.data = {
    layers = { },
    fakelag_states = { },
    switch_time = 0,
    choke_state = false,
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
        layers = { }
    }
    
    for layer_idx = 0, 12 do
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
    
    local current_time = globals.oldcommandack()
    local fl_limit = ui.reference('AA', 'Fake lag', 'Limit')

    if current_time - self.data.switch_time > ui.get(fl_limit) then
        self.data.choke_state = not self.data.choke_state
        self.data.switch_time = current_time
    end

    local fakelag_state = {
        layers = state.layers,
        choked = self.data.choke_state
    }
    
    table.insert(self.data.fakelag_states, fakelag_state)
    if #self.data.fakelag_states > ui.get(fl_limit) + 1 then
        table.remove(self.data.fakelag_states, 1)
    end
end

function animation_fix:apply_state(target_state)
    local me = entity.get_local_player()
    if not me then
        return
    end
    
    local self_index = c_entity(me)
    for layer_idx = 0, 12 do
        local layer = self_index:get_anim_overlay(layer_idx)
        if layer and target_state.layers[layer_idx] then
            if layer_idx == 12 then -- TODO
                layer.cycle = target_state.layers[layer_idx].cycle
                layer.weight = 0
                layer.playback_rate = 0
                layer.sequence = target_state.layers[layer_idx].sequence
            else
                layer.cycle = target_state.layers[layer_idx].cycle
                layer.weight = target_state.layers[layer_idx].weight
                layer.playback_rate = target_state.layers[layer_idx].playback_rate
                layer.sequence = target_state.layers[layer_idx].sequence
            end
        end
    end
end

function animation_fix:pre_render()
    if not self.data.initialized then
        return
    end
    
    local me = entity.get_local_player()
    if not me then
        return
    end
    
    local self_index = c_entity(me)
    if not self_index:get_anim_state() then
        return
    end
    
    local states = self.data.fakelag_states
    if #states < 2 then
        return
    end
    
    local reference_state = nil
    for i = #states, 1, -1 do
        if not states[i].choked then
            if not reference_state then
                reference_state = states[i]
            end
        end
    end
    
    if reference_state and self.data.choke_state then
        self:apply_state(reference_state)
    end
end

function animation_fix:reset()
    self.data.fakelag_states = { }
    self.data.switch_time = 0
    self.data.choke_state = false
    self:initialize_layers()
    self:debug_print('reset')
end

--@author: Hack3r_jopi ~ https://yougame.biz/j/
--@description: https://yougame.biz/threads/345134/
local event_list = {
    on_setup_command = function(ctx)
        animation_fix:setup_command(ctx)
    end,
    on_pre_render = function()
        animation_fix:pre_render()
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
                animation_fix.data.fakelag_states = { }
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

-- t.me/debugoverlay ~ visit =)
local ffi = require 'ffi'

local extended_events = require 'extended_events' -- https://github.com/uwukson4800/gamesense-lua/blob/main/extended_events.lua
local exploits = require 'extended_exploits' -- https://yougame.biz/threads/345134/

ffi.cdef[[ typedef void*(__thiscall* get_client_entity_t)(void*, int); ]]

local function this_call(call_function, parameters) 
    return 
    function(...) 
        return call_function(parameters, ...) 
    end 
end

local entity_list_003 = ffi.cast(ffi.typeof('uintptr_t**'), client.create_interface('client.dll', 'VClientEntityList003'))
local get_entity_address = this_call(ffi.cast('get_client_entity_t', entity_list_003[0][3]), entity_list_003)
function get_localplayer()
    local local_player_index = entity.get_local_player()
    local local_player_address = get_entity_address(local_player_index)

    return local_player_address
end

extended_events.pre_should_skip_anim_frame:set(function(ecx, edx)
    local player = ffi.cast('uintptr_t', ecx);
    local me = ffi.cast('uintptr_t', get_localplayer());

    if player == me then
        return exploits:in_defensive();
    end

    return false;
end)

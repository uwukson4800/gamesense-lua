-- t.me/debugoverlay ~ visit =)
local ffi = require 'ffi'

local events = { }

local Event = { }
Event.__index = Event

function Event.new()
    return setmetatable({
        callbacks = { }
    }, Event)
end

function Event:set(callback)
    if type(callback) ~= 'function' then
        error('callback must be a function')
    end
    
    table.insert(self.callbacks, callback)
    return #self.callbacks
end

function Event:remove(handle)
    if self.callbacks[handle] then
        self.callbacks[handle] = nil
    end
end

function Event:call(...)
    local results = { }
    for _, callback in pairs(self.callbacks) do
        local result = callback(...)
        if result ~= nil then
            table.insert(results, result)
        end
    end
    
    if #results > 0 then
        return results[1]
    end
    return nil
end

events.pre_update_clientside_animations = Event.new()
events.post_update_clientside_animations = Event.new()
events.pre_should_skip_anim_frame = Event.new()
events.post_should_skip_anim_frame = Event.new()
events.pre_interpolate_server_entities = Event.new()
events.post_interpolate_server_entities = Event.new()
events.pre_setup_bones = Event.new()
events.post_setup_bones = Event.new()
events.pre_perform_screen_overlay = Event.new()
events.post_perform_screen_overlay = Event.new()

local detour = (function()
    local detour_lib = {}

    local cast = ffi.cast
    local copy = ffi.copy
    local new = ffi.new
    local typeof = ffi.typeof
    local tonumber = tonumber
    local insert = table.insert
    
    local function opcode_scan(module, pattern, offset)
        local sig = client.find_signature(module, pattern) 
        if not sig then
            error(string.format('failed to find signature: %s', module))
        end
        return cast('uintptr_t', sig) + (offset or 0)
    end
    
    local jmp_ecx = opcode_scan('engine.dll', '\xFF\xE1')
    local get_proc_addr = cast('uint32_t**', cast('uint32_t', opcode_scan('engine.dll', '\xFF\x15\xCC\xCC\xCC\xCC\xA3\xCC\xCC\xCC\xCC\xEB\x05')) + 2)[0][0]
    local fn_get_proc_addr = cast('uint32_t(__fastcall*)(unsigned int, unsigned int, uint32_t, const char*)', jmp_ecx)
    local get_module_handle = cast('uint32_t**', cast('uint32_t', opcode_scan('engine.dll', '\xFF\x15\xCC\xCC\xCC\xCC\x85\xC0\x74\x0B')) + 2)[0][0]
    local fn_get_module_handle = cast('uint32_t(__fastcall*)(unsigned int, unsigned int, const char*)', jmp_ecx)
    
    local proc_cache = {}
    local function proc_bind(module_name, function_name, typedef)
        local cache_key = module_name .. function_name
        if proc_cache[cache_key] then
            return proc_cache[cache_key]
        end
    
        local ctype = typeof(typedef)
        local module_handle = fn_get_module_handle(get_module_handle, 0, module_name)
        local proc_address = fn_get_proc_addr(get_proc_addr, 0, module_handle, function_name)
        local call_fn = cast(ctype, jmp_ecx)
    
        local fn = function(...)
            return call_fn(proc_address, 0, ...)
        end
        proc_cache[cache_key] = fn
        return fn
    end
    
    local native_virtualprotect = proc_bind(
        'kernel32.dll',
        'VirtualProtect',
        'int(__fastcall*)(unsigned int, unsigned int, void* lpAddress, unsigned long dwSize, unsigned long flNewProtect, unsigned long* lpflOldProtect)'
    )

    local function virtualprotect(lpAddress, dwSize, flNewProtect, lpflOldProtect)
        return native_virtualprotect(cast('void*', lpAddress), dwSize, flNewProtect, lpflOldProtect)
    end
    
    detour_lib.hooks = {}
    function detour_lib.new(typedef, callback, hook_addr, size)
        size = size or 5
        local hook = {}
        local mt = {}
        
        local old_prot = new('unsigned long[1]')
        local org_bytes = new('uint8_t[?]', size)
        copy(org_bytes, hook_addr, size)
        
        local detour_addr = tonumber(cast('intptr_t', cast('void*', cast(typedef, callback))))
        hook.call = cast(typedef, hook_addr)
        
        mt.__call = function(self, ...)
            self.stop()
            local res = self.call(...)
            self.start()
            return res
        end
    
        local hook_bytes = new('uint8_t[?]', size, 0x90)
        hook_bytes[0] = 0xE9
        cast('int32_t*', hook_bytes + 1)[0] = (detour_addr - tonumber(cast('intptr_t', hook_addr)) - 5)
        hook.status = false
    
        local function set_status(bool)
            hook.status = bool
            virtualprotect(hook_addr, size, 0x40, old_prot)
            copy(hook_addr, bool and hook_bytes or org_bytes, size)
            virtualprotect(hook_addr, size, old_prot[0], old_prot)
        end
    
        hook.stop = function() set_status(false) end
        hook.start = function() set_status(true) end
        hook.start()
        
        insert(detour_lib.hooks, hook)
        return setmetatable(hook, mt)
    end
    
    function detour_lib.unhook_all()
        for _, hook in pairs(detour_lib.hooks) do
            if hook.status then
                hook.stop()
            end
        end
    
        proc_cache = {}
        collectgarbage('collect')
    end
    
    client.set_event_callback('shutdown', detour_lib.unhook_all)
    
    return detour_lib
end)()

local g_ctx = {
    patterns = {
        updateclientside = client.find_signature('client.dll', '\x55\x8B\xEC\x51\x56\x8B\xF1\x80\xBE\xCC\xCC\x00\x00\x00\x74\x36\x8B\x06\xFF\x90\xCC\xCC\x00\x00'),
        skipanimframe = client.find_signature('client.dll', '\x57\x8B\xF9\x8B\x07\x8B\x80\xCC\xCC\xCC\xCC\xFF\xD0\x84\xC0\x75\x02'),
        interpolate_server_entities = client.find_signature('client.dll', '\x55\x8B\xEC\x83\xEC\x1C\x8B\x0D\xCC\xCC\xCC\xCC\x53\x56'),
        setupbones = client.find_signature('client.dll', '\x55\x8B\xEC\x83\xE4\xF0\xB8\xD8'),
        perform_screen_overlay = client.find_signature('client.dll', '\x55\x8B\xEC\x51\xA1\xCC\xCC\xCC\xCC\x53\x56\x8B\xD9')
    }
}

function hk_updateclientside(ecx, edx)
    if ecx == nil then
        return o_updateclientside(ecx, edx)
    end

    local override = events.pre_update_clientside_animations:call(ecx, edx)
    if override ~= nil then
        return override
    end
        
    local result = o_updateclientside(ecx, edx)
        
    local post_override = events.post_update_clientside_animations:call(ecx, edx, result)
    if post_override ~= nil then
        return post_override
    end

    return result
end

function hk_skipanimframe(ecx, edx)
    if ecx == nil then
        return o_skipanimframe(ecx, edx)
    end

    local override = events.pre_should_skip_anim_frame:call(ecx, edx)
    if override ~= nil then
        return override
    end
    
    local result = o_skipanimframe(ecx, edx)
    
    local post_override = events.post_should_skip_anim_frame:call(ecx, edx, result)
    if post_override ~= nil then
        return post_override
    end
    
    return result
end

function hk_interpolate_server_entities(ecx, edx)
    if ecx == nil then
        return o_interpolate_server_entities(ecx, edx)
    end

    local override = events.pre_interpolate_server_entities:call(ecx, edx)
    if override ~= nil then
        return override
    end
    
    local result = o_interpolate_server_entities(ecx, edx)
    
    local post_override = events.post_interpolate_server_entities:call(ecx, edx, result)
    if post_override ~= nil then
        return post_override
    end
    
    return result
end

function hk_setupbones(ecx, edx, bone_to_world, max_bones, mask, time)
    local player = ffi.cast("void***", ffi.cast("uintptr_t", ecx) - 4)
    if player == nil then
        return o_setupbones(ecx, edx, bone_to_world, max_bones, mask, time)
    end

    local override = events.pre_setup_bones:call(ecx, edx, bone_to_world, max_bones, mask, time)
    if override ~= nil then
        return override
    end
        
    local result = o_setupbones(ecx, edx, bone_to_world, max_bones, mask, time)
        
    local post_override = events.post_setup_bones:call(ecx, edx, bone_to_world, max_bones, mask, time, result)
    if post_override ~= nil then
        return post_override
    end

    return result
end

function hk_perform_screen_overlay(_this, edx, x, y, w, h)
    if _this == nil then
        return o_setupbones(_this, edx, x, y, w, h)
    end

    local override = events.pre_perform_screen_overlay:call(_this, edx, x, y, w, h)
    if override ~= nil then
        return override
    end
        
    local result = o_perform_screen_overlay(_this, edx, x, y, w, h)
        
    local post_override = events.post_perform_screen_overlay:call(_this, edx, x, y, w, h, result)
    if post_override ~= nil then
        return post_override
    end

    return result
end

o_updateclientside = detour.new('void(__fastcall*)(void*, void*)', hk_updateclientside, g_ctx.patterns.updateclientside)
o_skipanimframe = detour.new('bool(__fastcall*)(void*, void*)', hk_skipanimframe, g_ctx.patterns.skipanimframe)
o_interpolate_server_entities = detour.new('void(__fastcall*)(void*, void*)', hk_interpolate_server_entities, g_ctx.patterns.interpolate_server_entities)
o_setupbones = detour.new('bool(__fastcall*)(void*, void*, int, int, int, int)', hk_setupbones, g_ctx.patterns.setupbones)
o_perform_screen_overlay = detour.new('void(__fastcall*)(void*, void*, int, int, int, int)', hk_perform_screen_overlay, g_ctx.patterns.perform_screen_overlay)

client.set_event_callback('shutdown', function()
    for _, event in pairs({
        events.pre_update_clientside_animations,
        events.post_update_clientside_animations,
        events.pre_should_skip_anim_frame,
        events.post_should_skip_anim_frame,
        events.pre_interpolate_server_entities,
        events.post_interpolate_server_entities,
        events.pre_setup_bones,
        events.post_setup_bones,
        events.pre_perform_screen_overlay,
        events.post_perform_screen_overlay
    }) do
        event.callbacks = { }
    end
        
    if g_ctx then      
        g_ctx = nil
    end

    collectgarbage('collect')
    collectgarbage('collect')
end)

return events

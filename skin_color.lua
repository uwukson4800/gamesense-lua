-- https://t.me/debugoverlay ~ visit =)

_G._DEBUG = false
local ffi = require 'ffi'

-- https://github.com/Freaut/Detour-Hooking-Library/
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

ffi.cdef[[
    typedef struct {
        char pad_0[0x77C];
        char weapon_path[260];
        char pad_1[0x10C];

        float color1_b;
        float color1_r;
        float color1_g;
        float color2_b;
        float color2_r;
        float color2_g;
        float color3_b;
        float color3_r;
        float color3_g;
        float color4_b;
        float color4_r;
        float color4_g;

        int phong_albedo_boost;
        int phong_exponent;
        int phong_intensity;
        float phong_albedo_factor;

        float wear_progress;

        float pattern_scale;
        float pattern_offset_x;
        float pattern_offset_y;
        float pattern_rot;

        float wear_scale;
        float wear_offset_x;
        float wear_offset_y;
        float wear_rot;

        float grunge_scale;
        float grunge_offset_x;
        float grunge_offset_y;
        float grunge_rot;
    } wpn_visual_data_t;
]]

local ctx do
    ctx = { }

    ctx.patterns = {
        setvisualdata = client.find_signature('client.dll', '\x55\x8B\xEC\x81\xEC\xCC\xCC\xCC\xCC\x53\x8B\xD9\x56\x57\x8B\x53\x5C')
    }
end

local menu do
    menu = { }

    menu.items = {
        label = ui.new_label('SKINS', 'Weapon skin', 'skin color'),
        color = ui.new_color_picker('SKINS', 'Weapon skin', 'color', 255, 255, 255, 255)
    }
end

--- @param ecx void*
--- @param edx void*
--- @param shader_name const char*
function hk_setvisualdata(ecx, edx, shader_name)
    o_setvisualdata(ecx, edx, shader_name)

    local m_visuals_data = ffi.cast('wpn_visual_data_t*', ffi.cast('uintptr_t', ecx) - 0x4)
    if m_visuals_data == nil then
        return
    end

    -- TODO: force update

    local r, g, b, a = ui.get(menu.items.color)

    m_visuals_data.color1_r = r
    m_visuals_data.color1_g = g
    m_visuals_data.color1_b = b

    m_visuals_data.color2_r = r
    m_visuals_data.color2_g = g
    m_visuals_data.color2_b = b

    m_visuals_data.color3_r = r
    m_visuals_data.color3_g = g
    m_visuals_data.color3_b = b

    m_visuals_data.color4_r = r
    m_visuals_data.color4_g = g
    m_visuals_data.color4_b = b
end
o_setvisualdata = detour.new('void(__fastcall*)(void*, void*, const char*)', hk_setvisualdata, ctx.patterns.setvisualdata)

client.set_event_callback('shutdown', function()
    local v1 = collectgarbage('count')

    if _G._DEBUG then
        _G._DEBUG = nil
    end

    if ctx then      
        ctx = nil
    end

    if menu then
        menu = nil
    end

    collectgarbage('collect')
    collectgarbage('collect') -- =)
    
    local v2 = collectgarbage('count')
    local v3 = v1 - v2
        
    print('[t.me/debugoverlay] memory cleared: ' .. string.format('%.2f', v3) .. ' KB')
end)

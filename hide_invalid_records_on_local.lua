-- t.me/debugoverlay ~ visit =)
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

-- https://yougame.biz/threads/345134/
local exploits = (function()
    local clases = {}
    function class(name)
        return function(tab)
            if not tab then return clases[name] end
            tab.__index, tab.__classname = tab, name
            if tab.call then tab.__call = tab.call end
            setmetatable(tab, tab)
            clases[name], _G[name] = tab, tab
            return tab
        end
    end
    local g_ctx = {
        local_player = nil, weapon = nil,
        aimbot = ui.reference("RAGE", "Aimbot", "Enabled"), doubletap = {ui.reference("RAGE", "Aimbot", 'Double tap')}, hideshots = {ui.reference("AA", 'Other', 'On shot anti-aim')}, fakeduck = ui.reference("RAGE", "Other", "Duck peek assist")
    }
    local clamp = function(value, min, max) return math.min(math.max(value, min), max) end
    class "exploits" {
        max_process_ticks = math.abs(client.get_cvar("sv_maxusrcmdprocessticks")) - 1, -- we lost 1 tick due to createmove processing
        tickbase_difference = 0, ticks_processed = 0, command_number = 0, choked_commands = 0, need_force_defensive = false, current_shift_amount = 0,
        reset_vars = function(self) self.ticks_processed = 0 self.tickbase_difference = 0 self.choked_commands = 0 self.command_number = 0 end,
        store_vars = function(self, ctx) self.command_number = ctx.command_number self.choked_commands = ctx.chokedcommands end,
        store_tickbase_difference = function(self, ctx)
            if ctx.command_number == self.command_number then
                self.ticks_processed = clamp(math.abs(entity.get_prop(g_ctx.local_player, "m_nTickBase") - self.tickbase_difference), 0, self.max_process_ticks - self.choked_commands)
                self.tickbase_difference = math.max(entity.get_prop(g_ctx.local_player, "m_nTickBase"), self.tickbase_difference or 0)
                self.command_number = 0
            end
        end,
        is_doubletap = function(self) return ui.get(g_ctx.doubletap[2]) end,
        is_hideshots = function(self) return ui.get(g_ctx.hideshots[2]) end,
        is_active = function(self) return self:is_doubletap() or self:is_hideshots() end,
        in_defensive = function(self) return self:is_active() and (self.ticks_processed > 1 and self.ticks_processed < self.max_process_ticks) end,
        is_defensive_ended = function(self) return not self:in_defensive() or (self.ticks_processed >= 0 and self.ticks_processed <= 5) and self.tickbase_difference > 0 end,
        is_lagcomp_broken = function(self) return not self:is_defensive_ended() or self.tickbase_difference < entity.get_prop(g_ctx.local_player, "m_nTickBase") end,
        can_recharge = function(self)
            if not self:is_active() then return false end
            local curtime = globals.tickinterval() * (entity.get_prop(g_ctx.local_player, "m_nTickBase") - 16)
            if curtime < entity.get_prop(g_ctx.local_player, "m_flNextAttack") then return false end
            if curtime < entity.get_prop(g_ctx.weapon, "m_flNextPrimaryAttack") then return false end
            return true
        end,
        in_recharge = function(self)
            if not (self:is_active() and self:can_recharge()) or self:in_defensive() then return false end
            local latency_shift = math.ceil(toticks(client.latency()) * 1.25)
            local current_shift_amount = ((self.tickbase_difference - globals.tickcount()) * -1) + latency_shift
            local max_shift_amount, min_shift_amount = (self.max_process_ticks - 1) - latency_shift, -(self.max_process_ticks - 1) + latency_shift
            if latency_shift ~= 0 then
                return current_shift_amount > min_shift_amount and current_shift_amount < max_shift_amount
            else
                return current_shift_amount > (min_shift_amount / 2) and current_shift_amount < (max_shift_amount / 2)
            end
        end,
        should_force_defensive = function(self, state)
            if not self:is_active() then return false end
            self.need_force_defensive = state and self:is_defensive_ended()
        end,
        allow_unsafe_charge = function(self, state)
            if not (self:is_active() and self:can_recharge()) then ui.set(g_ctx.aimbot, true) return end
            if not state then ui.set(g_ctx.aimbot, true) return end
            if ui.get(g_ctx.fakeduck) then ui.set(g_ctx.aimbot, true) return end
            ui.set(g_ctx.aimbot, not self:in_recharge())
        end,
        force_reload_exploits = function(self, state)
            if not state then
                ui.set(g_ctx.doubletap[1], true) ui.set(g_ctx.hideshots[1], true)
                return
            end
            if self:is_doubletap() and not self:in_recharge() then
                ui.set(g_ctx.doubletap[1], false)
            else
                ui.set(g_ctx.doubletap[1], true)
            end
            if self:is_hideshots() and not self:in_recharge() then
                ui.set(g_ctx.hideshots[1], false)
            else
                ui.set(g_ctx.hideshots[1], true)
            end
        end
    }
    local event_list = {
        on_setup_command = function(ctx)
            if not (entity.get_local_player() and entity.is_alive(entity.get_local_player()) and entity.get_player_weapon(entity.get_local_player())) then return end
            g_ctx.local_player = entity.get_local_player()
            g_ctx.weapon = entity.get_player_weapon(g_ctx.local_player)
            if exploits.need_force_defensive then ctx.force_defensive = true end
        end,
        on_run_command = function(ctx) exploits:store_vars(ctx) end,
        on_predict_command = function(ctx) exploits:store_tickbase_difference(ctx) end,
        on_player_death = function(ctx)
            if not (ctx.userid and ctx.attacker) then return end
            if g_ctx.local_player ~= client.userid_to_entindex(ctx.userid) then return end
            exploits:reset_vars()
        end,
        on_level_init = function() exploits:reset_vars() end,
        on_round_start = function() exploits:reset_vars() end,
        on_round_end = function() exploits:reset_vars() end,
        on_shutdown = function() collectgarbage("collect") end
    }
    for k, v in next, event_list do client.set_event_callback(k:sub(4), function(ctx) v(ctx) end) end
    return exploits
end)()

local ctx do
    ctx = { }

    ctx.patterns = {
        shouldskipanimframe = client.find_signature('client.dll', '\x57\x8B\xF9\x8B\x07\x8B\x80\xCC\xCC\xCC\xCC\xFF\xD0\x84\xC0\x75\x02')
    }
end

local interfaces do
    interfaces = { }

    interfaces.entity_list = { }
    do
        ffi.cdef[[
            typedef void*(__thiscall* get_client_entity_t)(void*, int);
        ]]

        local function this_call(call_function, parameters) 
            return 
            function(...) 
                return call_function(parameters, ...) 
            end 
        end

        local entity_list_003 = ffi.cast(ffi.typeof('uintptr_t**'), client.create_interface('client.dll', 'VClientEntityList003'))
        local get_entity_address = this_call(ffi.cast('get_client_entity_t', entity_list_003[0][3]), entity_list_003)

        function interfaces.entity_list:localplayer()
            local local_player_index = entity.get_local_player()
            local local_player_address = get_entity_address(local_player_index)

            return local_player_address
        end
    end
end

function hk_shouldskipanimframe(ecx, edx)
    if ffi.cast('uintptr_t', ecx) == ffi.cast('uintptr_t', interfaces.entity_list:localplayer()) then
        return exploits:is_lagcomp_broken() and true or false
    end

    return false
end
o_shouldskipanimframe = detour.new('bool(__fastcall*)(void*, void*)', hk_shouldskipanimframe, ctx.patterns.shouldskipanimframe)

client.set_event_callback('shutdown', function()
    local v1 = collectgarbage('count')

    if ctx then      
        ctx = nil
    end

    if interfaces then
        interfaces = nil
    end

    collectgarbage('collect')
    collectgarbage('collect') -- =)
    
    local v2 = collectgarbage('count')
    local v3 = v1 - v2
        
    print('[t.me/debugoverlay] memory cleared: ' .. string.format('%.2f', v3) .. ' KB')
end)

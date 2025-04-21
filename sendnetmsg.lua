-- t.me/debugoverlay ~ uwukson4800

-- @ debug
_G._DEBUG = false
local safe do
    safe = { }

    function safe:print(...)
        if _DEBUG then
            print('[DEBUG] ', ...)
        end
    end

    function safe:require(module_name)
        local status, module = pcall(require, module_name)
        
        if status then
            return module
        else
            safe:print('error loading module "' .. module_name .. '": ' .. module)
            return nil
        end
    end

    client.set_event_callback('shutdown', function()
        if safe then
            safe = nil
        end

        if _DEBUG then
            _DEBUG = false
        end
    end)
end

-- @ requires
local ffi      = safe:require 'ffi'
local bit      = safe:require 'bit'

ffi.cdef[[
    typedef struct { } i_net_channel_info;
    typedef struct { } c_net_message;

    typedef bool( __fastcall *send_net_msg_t )( i_net_channel_info *, void *, c_net_message *, bool, bool );

    typedef struct
    {
        uint32_t i_net_message_vtable;         // 0x0000
        char pad_0004[ 4 ];                  // 0x0004
        uint32_t c_clc_msg_voice_data_vtable;   // 0x0008
        char pad_000C[ 8 ];                  // 0x000C
        void* data;                          // 0x0014
        uint64_t xuid;                       // 0x0018
        int32_t format;                      // 0x0020
        int32_t sequence_bytes;              // 0x0024
        uint32_t section_number;             // 0x0028
        uint32_t uncompressed_sample_offset; // 0x002C
        int32_t cached_size;                 // 0x0030
        uint32_t flags;                      // 0x0034
        char pad_0038[ 255 ];                // 0x0038
    } c_clc_msg_voice_data;

    typedef struct
    {
        int32_t vtable;                        // 0x0000 
        void* msgbinder1;                      // 0x0004 
        void* msgbinder2;
        void* msgbinder3;
        void* msgbinder4;
        unsigned char m_bProcessingMessages;
        unsigned char m_bShouldDelete;
        char pad_0x0016[ 0x2 ];
        int32_t m_nOutSequenceNr;
        int32_t m_nInSequenceNr;
        int32_t m_nOutSequenceNrAck;
        int32_t m_nOutReliableState;
        int32_t m_nInReliableState;
        int32_t m_nChokedPackets;
        char pad_0030[ 112 ];                  // 0x0030
        int32_t m_Socket;                      // 0x009C
        int32_t m_StreamSocket;                // 0x00A0
        int32_t m_MaxReliablePayloadSize;      // 0x00A4
        char remote_address[ 32 ];             // 0x00A8
        char m_szRemoteAddressName[ 64 ];      // 0x00A8
        float last_received;                   // 0x010C
        float connect_time;                    // 0x0110
        char pad_0114[ 4 ];                    // 0x0114
        int32_t m_Rate;                        // 0x0118
        char pad_011C[ 4 ];                    // 0x011C
        float m_fClearTime;                    // 0x0120
        char pad_0124[ 16688 ];                // 0x0124
        char m_Name[ 32 ];                     // 0x4254
        unsigned int m_ChallengeNr;            // 0x4274
        float m_flTimeout;                     // 0x4278
        char pad_427C[ 32 ];                   // 0x427C
        float m_flInterpolationAmount;         // 0x429C
        float m_flRemoteFrameTime;             // 0x42A0
        float m_flRemoteFrameTimeStdDeviation; // 0x42A4
        int32_t m_nMaxRoutablePayloadSize;     // 0x42A8
        int32_t m_nSplitPacketSequence;        // 0x42AC
        char pad_42B0[ 40 ];                   // 0x42B0
        bool m_bIsValveDS;                     // 0x42D8
        char pad_42D9[ 65 ];                   // 0x42D9
    } CNetChannel;

    typedef struct
    {
        char pad_0000[ 0x9C ];         // 0x0000
        CNetChannel* m_NetChannel;     // 0x009C
        uint32_t m_nChallengeNr;       // 0x00A0
        char pad_00A4[ 0x64 ];         // 0x00A4
        uint32_t m_nSignonState;       // 0x0108
        char pad_010C[ 0x8 ];          // 0x010C
        float m_flNextCmdTime;         // 0x0114
        uint32_t m_nServerCount;       // 0x0118
        uint32_t m_nCurrentSequence;   // 0x011C
        char pad_0120[ 4 ];            // 0x0120
        char m_ClockDriftMgr[ 0x50 ];  // 0x0124
        int32_t m_nDeltaTick;          // 0x0174
        bool m_bPaused;                // 0x0178
        char pad_0179[ 7 ];            // 0x0179
        uint32_t m_nViewEntity;        // 0x0180
        uint32_t m_nPlayerSlot;        // 0x0184
        char m_szLevelName[ 260 ];     // 0x0188
        char m_szLevelNameShort[ 40 ]; // 0x028C
        char m_szGroupName[ 40 ];      // 0x02B4
        char pad_02DC[ 52 ];           // 0x02DC
        uint32_t m_nMaxClients;        // 0x0310
        char pad_0314[ 18820 ];        // 0x0314
        float m_flLastServerTickTime;  // 0x4C98
        bool insimulation;             // 0x4C9C
        char pad_4C9D[ 3 ];            // 0x4C9D
        uint32_t oldtickcount;         // 0x4CA0
        float m_tickRemainder;         // 0x4CA4
        float m_frameTime;             // 0x4CA8
        char pad_4CAC[ 0x78 ];         // 0x4CAC
        char temp[ 0x8 ];              // 0x4CAC
        int32_t lastoutgoingcommand;   // 0x4CAC
        int32_t chokedcommands;        // 0x4CB0
        int32_t last_command_ack;      // 0x4CB4
        int32_t last_server_tick;      // 0x4CB8
        int32_t command_ack;           // 0x4CBC
        char pad_4CC0[ 80 ];           // 0x4CC0
        char viewangles[ 0xC ];        // 0x4D10
        char pad_4D14[ 0xD0 ];         // 0x4D1C
        void* m_Events;                // 0x4DEC
    } IClientState;

    typedef struct
    {
        char data[ 16 ];
        uint32_t current_len;
        uint32_t max_len;
    } communication_string_t;

    typedef struct
    {
        uint64_t xuid;
        int32_t sequence_bytes;
        uint32_t section_number;
        uint32_t uncompressed_sample_offset;
    } c_voice_communication_data;

    typedef uint32_t( __fastcall *construct_voicedata_message )( c_clc_msg_voice_data *, void * ); // ( void*, void* )
    typedef uint32_t( __fastcall *destruct_voicedata_message )( c_clc_msg_voice_data * ); // ( void* )
]]

local memory do
    memory = { }

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

    function memory:virtual_protect(lpAddress, dwSize, flNewProtect, lpflOldProtect)
        return native_virtualprotect(cast('void*', lpAddress), dwSize, flNewProtect, lpflOldProtect)
    end

    function memory:write_raw(dest, rawbuf, len)
        local old_prot = ffi.new('uint32_t[1]')
        self:virtual_protect(ffi.cast('uintptr_t', dest), len, 0x40, old_prot)
        ffi.copy(ffi.cast('void*', dest), rawbuf, len)
        self:virtual_protect(ffi.cast('uintptr_t', dest), len, old_prot[0], old_prot)
    end
end

local utils = { }
local signatures = { }
local INetChannel = { }

function utils.rel32(address, offset)
    if address == 0 or address == nil then
        return 0
    end
    
    local target_addr = address + offset
    local rel_offset = ffi.cast('uint32_t*', target_addr)[0]
    
    if rel_offset == 0 then
        return 0
    end
    
    return target_addr + 4 + rel_offset
end

signatures.client_state = client.find_signature('engine.dll', '\xA1\xCC\xCC\xCC\xCC\x8B\x80\xCC\xCC\xCC\xCC\xC3') or error('clientstate error')
signatures.client_state = ffi.cast('IClientState ***', ffi.cast('uint32_t', signatures.client_state) + 1)[0][0]

signatures.send_net_msg = client.find_signature('engine.dll', '\x55\x8B\xEC\x83\xEC\x08\x56\x8B\xF1\x8B\x4D\x04') or error('sendnetmsg error')
    
signatures.voicedata_constructor = client.find_signature('engine.dll', '\xC6\x46\xCC\xCC\x5E\xC3\x56\x57\x8B\xF9\x8D\x4F\xCC\xC7\x07\xCC\xCC\xCC\xCC\xE8')
signatures.voicedata_constructor = ffi.cast('uint32_t', signatures.voicedata_constructor) + 6

signatures.voicedata_destructor = client.find_signature('engine.dll', '\xE8\xCC\xCC\xCC\xCC\x5E\x8B\xE5\x5D\xC3\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\x51')
signatures.voicedata_destructor = utils.rel32(ffi.cast('uint32_t', signatures.voicedata_destructor), 1)

function INetChannel:SendNetMsg(custom_xuid_low, custom_xuid_high)
    custom_xuid_high = custom_xuid_high or 0xFFEA9F9A

    local communication_string_t = ffi.new('communication_string_t[1]')
    communication_string_t[0].current_len = 0
    communication_string_t[0].max_len = 15
    
    local msg = ffi.new('c_clc_msg_voice_data[1]')
    ffi.cast('construct_voicedata_message', signatures.voicedata_constructor)(msg, ffi.cast('void *', 0)) -- ffi.cast('void *', 0) -> nullptr
    
    safe:print(string.format('xuid_low: [0x%X] ~ xuid_high: [0x%X]', custom_xuid_low, custom_xuid_high))

    memory:write_raw(ffi.cast('uint32_t', msg) + 0x18, ffi.new('uint32_t[1]', custom_xuid_low), 4)
    memory:write_raw(ffi.cast('uint32_t', msg) + 0x1C, ffi.new('uint32_t[1]', custom_xuid_high), 4)
    
    msg[0].sequence_bytes = math.random(0, 0xFFFFFFF)
    msg[0].section_number = math.random(0, 0xFFFFFFF)
    msg[0].uncompressed_sample_offset = math.random(0, 0xFFFFFFF)

    msg[0].data = communication_string_t
    msg[0].format = 0 -- VoiceFormat_Steam
    msg[0].flags = 63 -- all flags
    
    -- @note: send_net_msg -> signature or vtable
    ffi.cast('send_net_msg_t', signatures.send_net_msg) -- sendnetmsg
    (ffi.cast('i_net_channel_info *', signatures.client_state[0].m_NetChannel), -- thisptr [inetchannel]
    ffi.cast('void *', 0), -- edx
    ffi.cast('c_net_message *', msg), -- msg
    false, -- force_reliable
    true) -- voice

    ffi.cast('destruct_voicedata_message', signatures.voicedata_destructor)(msg)
end

client.set_event_callback('shutdown', function()
    if ffi then
        ffi = nil
    end

    if bit then
        bit = nil
    end

    if memory then
        memory = nil
    end

    if signatures then
        signatures = nil
    end

    if INetChannel then
        INetChannel = nil
    end

    collectgarbage('collect')
end)

return INetChannel

--[[
    how to use:
    
    local INetChannel = require 'INetChannel'
    INetChannel:SendNetMsg(0x7FFA) -> fatality
]]

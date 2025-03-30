-- t.me/debugoverlay ~ visit =)
local ffi = require 'ffi'
local extended_events = require 'extended_events' -- https://github.com/uwukson4800/gamesense-lua/blob/main/extended_events.lua

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

local menu do
    menu = { }

    menu.items = {
        label = ui.new_label('SKINS', 'Weapon skin', 'skin color'),
        color = ui.new_color_picker('SKINS', 'Weapon skin', 'color', 255, 255, 255, 255)
    }
end

extended_events.post_setvisualdata:set(function(ecx, edx, shader_name)
    local m_visuals_data = ffi.cast('wpn_visual_data_t*', ffi.cast('uintptr_t', ecx) - 0x4)
    if m_visuals_data == nil then
        return
    end
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
end)

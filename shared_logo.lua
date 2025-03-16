-- https://yougame.biz/00/ ~ uwukson4800
-- https://t.me/debugoverlay ~ visit =)

_G._DEBUG = true
local http = require 'gamesense/http'
local base64 = require 'gamesense/base64'

local shared = { }
shared.tab = {
    'MISC',
    'Miscellaneous',
    'shared icon in scoreboard'
}

shared.data = {
    GITHUB_TOKEN = '',
    REPO_OWNER = '',
    REPO_NAME = '',
    FILE_PATH = 'players.json'
}

shared.time = {
    last_update = 0,
    last_github_check = 0
}

local scoreboard = ui.new_checkbox(unpack(shared.tab))

local scoreboard_images = panorama.loadstring([[
    var panel = null;
    var name_panels = {};
    var target_players = {};

    var _Update = function(players) {
        _Destroy();
        target_players = players || { };
        let scoreboard = $.GetContextPanel().FindChildTraverse("ScoreboardContainer").FindChildTraverse("Scoreboard");
        
        if (!scoreboard) return;

        scoreboard.FindChildrenWithClassTraverse("sb-row").forEach(function(row) {
            if (target_players[row.m_xuid]) {
                row.style.backgroundColor = "rgb(0, 0, 0)";
                row.style.border = "1px solid rgb(94, 94, 94)";
                
                row.Children().forEach(function(child) {
                    let nameLabel = child.FindChildTraverse("name");
                    if (nameLabel) {
                        nameLabel.style.color = "rgb(155, 155, 155)";
                        nameLabel.style.fontFamily = "Stratum2 Bold Monodigit";
                        nameLabel.style.fontWeight = "bold";
                    }

                    if (nameLabel) {
                        let parent = nameLabel.GetParent();
                        parent.style.flowChildren = "left";

                        let image_panel = $.CreatePanel("Panel", parent, "custom_image_panel_" + row.m_xuid);
                        let layout = `
                        <root>
                            <Panel style="flow-children: left; margin-right: 5px;">
                                <Image textureheight="24" texturewidth="24" src="https://yougame.biz/data/avatars/m/279/279781.jpg?1739982439" />
                            </Panel>
                        </root>
                        `;

                        image_panel.BLoadLayoutFromString(layout, false, false);
                        parent.MoveChildBefore(image_panel, nameLabel);
                        name_panels[row.m_xuid] = image_panel;
                    }
                });
            }
        });
    };


    var _Destroy = function() {
        let scoreboard = $.GetContextPanel().FindChildTraverse("ScoreboardContainer").FindChildTraverse("Scoreboard");
        
        if (scoreboard) {
            scoreboard.FindChildrenWithClassTraverse("sb-row").forEach(function(row) {
                row.style.backgroundColor = null;
                row.style.border = null;
                
                row.Children().forEach(function(child) {
                    let nameLabel = child.FindChildTraverse("name");
                    if (nameLabel) {
                        nameLabel.style.color = null;
                        nameLabel.style.fontFamily = "Stratum2";
                        nameLabel.style.fontWeight = "normal";
                    }
                });
            });
        }

        for (let xuid in name_panels) {
            if (name_panels[xuid] && name_panels[xuid].IsValid()) {
                name_panels[xuid].DeleteAsync(0.0);
            }
        }
        
        name_panels = {};
        target_players = {};
    };

    return {
        update: _Update,
        remove: _Destroy
    };
]], "CSGOHud")()

function shared:debug_print(...)
    if _DEBUG then
        print('[SHARED] ', ...)
    end
end

function shared:get_local_steamid()
    return tostring(panorama.open().MyPersonaAPI.GetXuid())
end

function shared:update_github(steamid, action)
    local headers = {
        ['Authorization'] = 'token ' .. self.data.GITHUB_TOKEN,
        ['Accept'] = 'application/vnd.github.v3+json'
    }
    
    local api_url = string.format(
        'https://api.github.com/repos/%s/%s/contents/%s',
        self.data.REPO_OWNER, self.data.REPO_NAME, self.data.FILE_PATH
    )

    http.get(api_url, {headers = headers}, function(success, response)
        if not success then return end
        
        local current_data = { }
        local sha = nil
        
        if response.status == 200 then
            local content = json.parse(response.body)
            sha = content.sha
            current_data = json.parse(base64.decode(content.content))
        end
        
        current_data[tostring(steamid)] = action == 'add' and true or nil
        
        local update_data = {
            message = string.format('%s %s', action, steamid),
            content = base64.encode(json.stringify(current_data)),
            sha = sha
        }
        
        http.put(api_url, {
            headers = headers,
            body = json.stringify(update_data)
        }, function(success, response)
            if success then
                if _DEBUG then
                    self:debug_print('successfully fully updated')
                end
            end
        end)
    end)
end

function shared:update_players(github_data)
    target_players = { }
    for steamid, _ in pairs(github_data) do
        target_players[steamid] = true
    end
    scoreboard_images.update(target_players)
end

function shared:check_and_update()
    local headers = {
        ['Authorization'] = 'token ' .. self.data.GITHUB_TOKEN,
        ['Accept'] = 'application/vnd.github.v3+json'
    }
    
    local api_url = string.format(
        'https://api.github.com/repos/%s/%s/contents/%s',
        self.data.REPO_OWNER, self.data.REPO_NAME, self.data.FILE_PATH
    )

    http.get(api_url, {headers = headers}, function(success, response)
        if success and response.status == 200 then
            local content = json.parse(response.body)
            local current_data = json.parse(base64.decode(content.content))
            shared:update_players(current_data)
            if _DEBUG then
                self:debug_print('successfully updated')
            end
        end
    end)
end

shared:check_and_update()
scoreboard_images.update(target_players)

--@author: Hack3r_jopi ~ https://yougame.biz/j/
--@description: https://yougame.biz/threads/345134/
local event_list = {
    on_player_connect_full = function(e)
        local steamid = shared:get_local_steamid()
        if steamid then
            shared:update_github(steamid, 'add')
    
            local target = client.userid_to_entindex(e.userid)
            local me = entity.get_local_player()
            if (target == me) or (target ~= me) then
                scoreboard_images.remove()
                client.delay_call(0.5, function()
                    scoreboard_images.update(target_players)
                end)
            end
        end
    end,
    on_paint = function()
        local current_time = globals.realtime()
        if current_time - shared.time.last_update >= 3.0 then
            scoreboard_images.update(target_players)
            shared.time.last_update = current_time
        end
    
        if current_time - shared.time.last_github_check >= 1.5 then
            shared:check_and_update()
            shared.time.last_github_check = current_time
        end
    
        ui.set_callback(scoreboard, function()
            local steamid = shared:get_local_steamid()
            if not ui.get(scoreboard) then
                scoreboard_images.remove()
                shared:update_github(steamid, 'remove')
            else
                shared:update_github(steamid, 'add')
                shared:check_and_update()
            end
        end)
    end,
    on_shutdown = function()
        local steamid = shared:get_local_steamid()
        if steamid then
            scoreboard_images.remove()
            shared:update_github(steamid, 'remove')
        end

        local v1 = collectgarbage('count')

        if http then
            http = nil
        end

        if base64 then
            base64 = nil
        end

        if scoreboard then
            scoreboard = nil
        end

        if scoreboard_images then
            scoreboard_images = nil
        end

        if shared then
            if shared.data then
                shared.data.GITHUB_TOKEN = nil
                shared.data.REPO_OWNER = nil
                shared.data.REPO_NAME = nil
                shared.data.FILE_PATH = nil
            end

            if shared.tab then
                shared.tab = nil
            end

            if shared.time then
                shared.time.last_update = nil
                shared.time.last_github_check = nil
            end

            for k, _ in pairs(shared) do
                shared[k] = nil
            end

            shared = nil
        end

        if _G._DEBUG then
            _G._DEBUG = nil
        end

        collectgarbage('collect')
        collectgarbage('collect') -- =)
    
        local v2 = collectgarbage('count')
        local v3 = v1 - v2
        
        print('[SHARED] Memory cleared: ' .. string.format('%.2f', v3) .. ' KB')
    end
}

for k, v in next, event_list do
    client.set_event_callback(k:sub(4), function(ctx)
        v(ctx)
    end)
end

--BASE URL: https://api.modworkshop.net

--NOTES FOR MYSELF:
--SEEMS LIKE I GET ACCESS VIOLATIONS FOR NO REASON WITH THIS MOD, DON'T KNOW IF IT'S DUE TO COMPATIBILITY ISSUES OR NOT. INVESTIGATE FURTHER

--TODO:
--ADD MOD IMAGES INTO NOTIF PANEL + MAYBE MOD OWNER AVATAR
--MAYBE MOD OPTIONS TO EDIT LIMIT AND MOD SWAP LENGTH
--UPDATE THE NOTIF PANEL DIRECTLY INSTEAD OF REMOVING AND CREATING A NEW ONE EACH TIME TO PREVENT NOTIF MOVING TO ANOTHER

if not HttpRequest then
    return
end

local notifications = BLT.Notifications --Got a bit annoying having to type BLT., so I did this.
local save_path = SavePath .. "LatestMods.txt"
local url = "https://api.modworkshop.net/games/payday-2/mods"
local key = Idstring("LatestMods"):key()

local mods = {}
local index = 1
local limit = 5 --by https://api.modworkshop.net
--[[
limit (integer)
Must be at least 1. Must not be greater than 50.
]]
local id
local swap = 10

local function makeNotif()
    if id then
        notifications:remove_notification(id)
        id = nil
    end

    local text = string.format("%s \nBy %s", mods[index].name, mods[index].user.name)
    local params = {
        title = string.format("%i LATEST MODS", limit),
        text = text,
        callback = function(notif_id) --On clicked event.
            managers.network.account:overlay_activate("url", "https://modworkshop.net/mod/" .. mods[index].id)

            --[[
                Apparently epic also has overlay? At least that's what I'm understanding here.

                function NetworkAccountEPIC:overlay_activate(...)
                	if self._overlay_opened then
                		return
                	end
                
                	if self:is_overlay_enabled() and EpicOverlayHandler:overlay_activate(...) then
                		self._overlay_opened = true
                    
                		self:_call_listeners("overlay_open")
                		managers.menu:show_epic_separate_window_opened({
                			ok_func = callback(self, self, "_on_close_overlay")
                		})
                	end
                end
            ]]
        end
    }

    id = notifications:add_notification(params)
end

local function makeModsList(data)
    for i, v in ipairs(data) do
        if not (i > limit) then
            mods[i] = v
        else
            break --No need to keep parsing, if we got what we need.
        end
    end
end

local function next()
    index = index + 1
    if index > limit then
        index = 1
    end
    makeNotif()
end

local function previous() --Incase I wanna do something in the future.
    index = index - 1
    if index < 1 then
        index = limit
    end
end

local clbk = function(result, body) --Returns as result false, if it failed, with body as nil. OR result is true and body has content.
    if (not result) or (not body) then
        log("FAILED TO GET LATEST MODS RESULT")
        return
    end

    body = json.decode(body)
    local data = body.data

    if not data then
        return
    end

    makeModsList(data)
    makeNotif()

    local file = io.open(save_path, "w+")
    if file then
        local save = {
            time = os.time(),
            mods = mods
        }
        file:write(json.encode(save))
        file:close()
    end
end

--[[
    NOTE:
    I have no fucking idea how do headers work so have fun looking at this.. as it is really hideous.
]]

local headers = {
    ["Accept"] = "application/json"
}

local body = { --Doesn't seem to work so imma stick with a workaround meanwhile
    ["limit"] = 5
}

local update = true --To avoid some mass spamming and since mods dont get released/updated that often, there's no point in constantly checking.
local file = io.open(save_path, "r")
if file then
    local value = json.decode(file:read("*all"))
    file:close()

    local delay = 60 * 5 --I'd say 5 minutes delay is good enough.
    if value then
        local time_since = os.time() - value["time"]
        if time_since < delay then
            update = false
            mods = value["mods"]
        end
    end
end

if update then
    HttpRequest:get(url, clbk, headers, key)
else
    makeNotif()
end

--[[
Why should I use this if body doesn't seem to work.
function HttpGet() --Just incase I wanna use it later
    HttpRequest:create_request("get", url, clbk, "application/json", json.encode(body), headers, key) --Wanted to use "HttpRequest:get" but it sets body to nil so was forced to "HttpRequest:create_request".
end

HttpGet()
]]

local time = 0
Hooks:PostHook(MenuManager, "update", "update_latest_mods", function(self, t, dt, ...)
    time = time + dt
    if time > swap then
        next()
        time = 0
    end
end)
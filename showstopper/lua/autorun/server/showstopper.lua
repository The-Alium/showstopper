---@type dreamwork
local dreamwork = _G.dreamwork
if dreamwork == nil then return end

---@type dreamwork.std
local std = dreamwork.std

local prefix = "showstopper@0.1.0"

local logger = std.console.Logger( {
    title = prefix,
    color = Color( 255, 180, 0 ),
    interpolation = false
} )

local string = std.string

local futures = std.futures
local futures_run = futures.run

local http_get = std.http.get

local SteamID = std.steam.Identifier

local group_name = "unknown"

---@type table<string, boolean>
local steamids = {}

---@param url string
---@async
local function fetch( url )
    logger:info( "Fetching SteamIDs from '%s'", url )

    local result = http_get( url )

    if result.status ~= 200 then
        logger:error( "Failed to fetch from '%s': %s", url, result.status )
        return
    end

    local data = std.encoding.json.deserialize( result.body )
    if data == nil then
        logger:error( "Failed to deserialize JSON from %s", url )
        return
    end

    local root = data.memberList

    local group_data = root.groupDetails
    group_name = group_data.groupName

    local member_count = group_data.memberCount
    logger:info( "Received %s members from '%s'.", member_count, group_name )

    local members = root.members.steamID64
    for i = 1, member_count, 1 do
        steamids[ members[ i ] ] = true
    end
end

local function update( url )
    if string.isEmpty( url ) then
        logger:warn( "SteamIDs not updated, 'showstopper_url' is empty!" )
        return
    end

    futures_run( fetch, function( ok, msg )
        if not ok then
            logger:error( "Failed to update SteamIDs from '%s': '%s'", url, msg )
        end
    end, url )
end

local showstopper_url = CreateConVar( "showstopper_url", "https://raw.githubusercontent.com/The-Alium/satellite/refs/heads/main/members.json", FCVAR_ARCHIVE, "The URL to fetch steamid's from." )

update( showstopper_url:GetString() )

cvars.AddChangeCallback( "showstopper_url", function( _, __, value )
    update( value )
end, "ShowStopper" )

hook.Add( "CheckPassword", "ShowStopper", function( player_steamid64, player_ip, server_password, client_password, player_name )
    if steamids[ player_steamid64 ] then
        logger:info( "Access granted to %s (%s) connected by IPv4: %s", SteamID.from64( player_steamid64 ):toSteam3(), player_name, player_ip )
        return
    end

    logger:info( "Access denied to %s (%s) connected by IPv4: %s", SteamID.from64( player_steamid64 ):toSteam3(), player_name, player_ip )
    return false, string.format( "-/-> Access Denied -/->\n\nSorry '%s' but in order to connect to '%s' you must be a member of the Steam Group '%s'.\n\n%s", player_name, cvars.String( "hostname", "unknown" ), group_name, prefix )
end )

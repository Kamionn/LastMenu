local RESOURCE = GetCurrentResourceName()
local RAW_URL  = 'https://raw.githubusercontent.com/Kamionn/LastMenu/main/version'

local function trim(s)
    return (s or ''):match('^%s*(.-)%s*$')
end

local function parseVersionFile(content)
    local data  = {}
    local lines = {}
    for line in (content or ''):gmatch('[^\n]+') do
        lines[#lines + 1] = line
    end

    local i = 1
    while i <= #lines do
        local key, val = lines[i]:match('^%s*(%w+)%s*=%s*(.-)%s*$')
        if key and val == '[' then
            local block = {}
            i = i + 1
            while i <= #lines and trim(lines[i]) ~= ']' do
                block[#block + 1] = lines[i]
                i = i + 1
            end
            data[key] = block
        elseif key then
            data[key] = val
        end
        i = i + 1
    end

    return data
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= RESOURCE then return end

    local localData = parseVersionFile(LoadResourceFile(RESOURCE, 'version') or '')
    local localV    = localData.version or '?'

    PerformHttpRequest(RAW_URL, function(code, body)
        if code ~= 200 or not body then
            print('^3  [LastMenu] v' .. localV .. ' — unable to reach update server^0')
            return
        end 

        local d = parseVersionFile(body)

        print('')
        print('')
        if type(d.ascii) == 'table' then
            for _, line in ipairs(d.ascii) do
                print('^4' .. line .. '^0')
            end
        end
       
        print('')
        print('^4  [LastMenu]^0 Version  ^4' .. (d.version or '?') .. '^0')
        print('^4  [LastMenu]^0 Docs     ^4' .. (d.docs    or '?') .. '^0')
        print('^4  [LastMenu]^0 Author   ^4' .. (d.author  or '?') .. '^0')
        if d.author and d.author ~= localData.author then
            print('^3  [LastMenu] v' .. localV .. ' by ' .. (localData.author or '?') .. '^0')
        end
        print('')
        if d.version and d.version ~= localV then
            print('^4  [LastMenu]^0 Update available: ^4' .. d.version .. '^0')
            print('^4  [LastMenu]^0 Patchnote ^4' .. (d.updates or '?') .. '^0')
        end
        print('')
    end, 'GET', '', {})
end)

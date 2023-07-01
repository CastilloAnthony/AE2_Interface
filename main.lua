if fs.exists('remote.lua') then
    local remote = require('remote')
    remote.initialize()
elseif fs.exists('server.lua') then
    local server = require('server')
    server.initialize()
else
	print('Cannot find remote.lua or server.lua.')
end
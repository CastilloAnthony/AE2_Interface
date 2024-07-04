if fs.exists('/AE2_Interface/remote.lua') then
    local remote = require('remote')
    remote.initialize()
elseif fs.exists('/AE2_Interface/server.lua') then
    local server = require('server')
    server.initialize()
else
	print('Cannot find remote.lua or server.lua.')
end

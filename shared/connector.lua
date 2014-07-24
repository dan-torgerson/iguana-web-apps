fasthttp = require 'fasthttp2'

local connector = {}

local method={}

local connection_meta = {__index = method }

function method.safeSocketCall(C, F)
   local Success, A, B = pcall(F, C)
   if C.crash_test then
      if math.random(C.crash_test) == 1 then
         Success = false
         A = 'Crash testing in place'
      end
   end
   if not Success then
      C:destroySocket()
      error(A)
   end
   return A, B
end

function method.destroySocket(C)
   -- Unconditionally close the socket
   pcall(net.tcp.close, C.socket)
   C.socket = 'notcreated'
   iguana.logInfo("Destroyed socket")
end

function method.sendPayload(C, Message)
   if C.socket == 'notcreated' then
      C:createSocket()
   end
   local PostRequest = fasthttp.makePost(C.host, C.path, Message) 
   local Success, ErrMsg = pcall(C.socket.send, C.socket, PostRequest)
   --C.socket:send(PostRequest)
   if not Success then
      C:destroySocket()
      error(ErrMsg)
   end
   
   return PostRequest
end

function method.fetchResponse(C)
   return C:safeSocketCall(fasthttp.readResponse)
end

function method.createSocket(C)
   C.socket = net.tcp.connect{host=C.host, port=C.port, timeout=6.1}
end

function method.setDestination(C, host, path)
--   local R = fasthttp.parseUrl(Url)
   C.host = host
   C.path = path
   C.port = 80
   return C
end

function connector.new()
   local Con = {host='host', path='/path', socket='notcreated', port=80, buffer=''}
   setmetatable(Con, connection_meta)

   return Con
end


return connector
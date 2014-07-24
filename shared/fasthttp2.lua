fasthttp ={}

--[[
GET / HTTP/1.1
Host: www.interfaceware.com
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_3) AppleWebKit/536.28.10 (KHTML, like Gecko) Version/6.0.3 Safari/536.28.10
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Language: en-us
Accept-Encoding: gzip, deflate
Connection: keep-alive
]]

function trace(M) end

local function TotalLength(HeaderLength, ContentLength) 
   return HeaderLength + ContentLength
end

-- Assume that Buff holds buffer to receive socket data
function fasthttp.readResponse(C)
   local Packet=''
   while (Packet and not C.buffer:find('\r\n\r\n')) do
      local Packet = C.socket:recv()
      if (Packet) then 
         trace(Packet)
         C.buffer = C.buffer..Packet
      else
         trace('Connection closed')
         C:destroySocket()
         return
      end
   end
   local _, HeaderLength = C.buffer:find('\r\n\r\n') 
   local ContentLength = C.buffer:match("Content%-Length:%s(%d+)\r\n")
   if (not ContentLength or not HeaderLength) then
      C:destroySocket()
      error('Badly formed HTTP response.\r\n'..Buff.buffer)
   end
   local ExpectedLength = TotalLength(HeaderLength, ContentLength)
   trace(#C.buffer)
   if (#C.buffer < ExpectedLength) then
      repeat
         Packet = C.socket:recv()
         if (Packet) then
            C.buffer = C.buffer..Packet
         end
      until ((Packet == nil) or (#C.buffer == ExpectedLength))
   end
   
   local Header = C.buffer:sub(1, HeaderLength)
   if (Header:find("Content%-Encoding:%s+gzip")) then
      Body = filter.gzip.inflate(Buff.buffer:sub(HeaderLength+1,
              HeaderLength+ContentLength))
   else
      Body = C.buffer:sub(HeaderLength+1, HeaderLength+ContentLength)
   end
   C.buffer = C.buffer:sub(ExpectedLength+1)
   if Header:match("Connection: close") then
      C:destroySocket()
   end
   return Header, Body
end

function fasthttp.parseUrl(Url)
   local R = {}
   R.host, R.port, R.path = Url:match('http://([^:]+):?(%d*)(/.*)')
   trace(R.host)
   trace(R.path)
   if R.port == '' then
      R.port = 80
   else
      R.port = tonumber(R.port)
   end
   trace(R.port)
   return R
end

function fasthttp.makePost(Host, Path, Body)
   local R
   R =     'POST '..Path..' HTTP/1.1\r\n'
        .. 'Host: '..Host..'\r\n'
        .. 'Connection: Keep-Alive\r\n'
        .. 'Content-Type: application/x-www-form-urlencoded\r\n'
        .. 'Content-Length: '..#Body..'\r\n'
   ..'\r\n'
        .. Body
   return R
end

return fasthttp
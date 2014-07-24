connector = require 'connector'
retry = require 'retry'

local function sleep(S)
   --if not iguana.isTest() then
      util.sleep(S*1000)
   --end
end

function main(Data)
   local message = "Unable to recover. Stopping channel. Operation timed out after 1014 milliseconds with 0 bytes received"
   local start, finish = string.find(message, "Unable to recover. Stopping channel. Operation timed out after ")
   
   TestMain(Data)
   --retry.call{func=SendToTyphon, retry=3, pause=os.getenv('RetryPause'), arg1=Data}
end

local Connection = connector.new()

-- We return true when have successfully processed the message
-- If we return false this will stop the channel.
-- For anything that we want to retry use the lua error() command.

function TestMain(Data)
   local success, errormsg = pcall(retry.call, {func=SendToTyphon_Fake, retry=2, pause=os.getenv('RetryPause'), arg1=Data})
   
   trace(success)
   
   if not success then
      return errormsg
   end
end

function SendToTyphon_Fake(Data)
   net.http.get{url="http://localhost:6544/timeoutsim/", timeout=1, live=true}
end



function SendToTyphon(Data)
   local Host = os.getenv('MessageProcessorServerName')
   local channelGuid = iguana.project.guid()
   local messageId = iguana.messageId() 
   if (iguana.isTest()) then
      messageId = math.random(100000000)
   end
   local urlString = '/Typhon.MessageParser/'.. channelGuid 
            ..'/'.. tostring(messageId) ..'/'..'Messaging/Process'  
   Connection:setDestination(Host, urlString)  
    if(os.getenv('CanCrash') == '1') then
      local f = io.open('CrashTest.txt',"rb")
      local content = f:read("*all")
      Connection.crash_test = content
   end
   
      
   local urlEncodedMessage = filter.uri.enc(Data)
  
   local Payload = Connection:sendPayload(urlEncodedMessage)
   iguana.logInfo(Payload)
   local Header, Body =  Connection:fetchResponse()
   
   if not Header then
      error("No response received from Typhon.")
   else
      iguana.logInfo(Header..Body)
      local JsonResponse = json.parse{data=Body}
      if (not JsonResponse.Successful) then
         iguana.logError("Typhon returned not successful.  Shut down the channel.")
         return false
      end
   end
   return true
end
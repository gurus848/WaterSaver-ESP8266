SSID = "gotcha"
PASS = "dontlookatthis"
RASBPI_ADDRESS = "http://10.0.0.3"

waterSensorPin = 2;
gpio.mode(waterSensorPin, gpio.INT);
numPulses = 1;
firstPulseTimeMicros = 0;
lastPulseTimeMicros = 0;


wifi.setmode(wifi.STATION);
wifi.sta.config(SSID, PASS);
wifi.sta.connect();
wifi.eventmon.register(wifi.eventmon.STA_CONNECTED, function(T)
 print("\n\tSTA - CONNECTED".."\n\tSSID: "..T.SSID.."\n\tBSSID: "..
 T.BSSID.."\n\tChannel: "..T.channel);
 end);

 wifi.eventmon.register(wifi.eventmon.STA_DISCONNECTED, function(T)
 print("\n\tSTA - DISCONNECTED".."\n\tSSID: "..T.SSID.."\n\tBSSID: "..
 T.BSSID.."\n\treason: "..T.reason)
 end);

 wifi.eventmon.register(wifi.eventmon.STA_AUTHMODE_CHANGE, function(T)
 print("\n\tSTA - AUTHMODE CHANGE".."\n\told_auth_mode: "..
 T.old_auth_mode.."\n\tnew_auth_mode: "..T.new_auth_mode)
 end);

 wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function(T)
 print("\n\tSTA - GOT IP".."\n\tStation IP: "..T.IP.."\n\tSubnet mask: "..
 T.netmask.."\n\tGateway IP: "..T.gateway);
 afterConnectionToWiFi();
 end);

 wifi.eventmon.register(wifi.eventmon.STA_DHCP_TIMEOUT, function()
 print("\n\tSTA - DHCP TIMEOUT")
 end);

 function afterConnectionToWiFi ()
    --print("Hello");
    syncTime();
    tmr.alarm(0, 600000, tmr.ALARM_AUTO, function ()   --for syncing the time to the module every ten minutes
        syncTime()
    end);

    gpio.trig(waterSensorPin, "up", function(level)
        --print("Yay interrupt function called.")
        if numPulses == 1
        then
            firstPulseTimeMicros = tmr.now();
        else
            lastPulseTimeMicros = tmr.now();
        end
        numPulses = numPulses + 1;
    end);

    tmr.alarm(1, 2000, tmr.ALARM_AUTO, function()
        sendDataToServer();
    end);



 end

 function syncTime()

    http.get(RASBPI_ADDRESS .. "/api/v1.0/getCurrentTime", nil, function(code, data)
    if (code < 0) then
      print("HTTP request failed")
    else
      rtctime.set(tonumber(data),0);
      print("Current time epoch: "..rtctime.get());
    end
  end)
 end

 function sendDataToServer()

    --print("Number of pulses: "..numPulses);

    frequency = 0;
    if numPulses < 3
    then
        frequency = 0;
    else
        if (lastPulseTimeMicros - firstPulseTimeMicros) ~= 0
        then
            frequency = 1000000.0 * ((numPulses - 2)/(lastPulseTimeMicros - firstPulseTimeMicros));
        end
    end

    print("Frequency: "..frequency.." Hz");

    flowRate = (frequency*60)/5.5

    print("Average Flow Rate(L/hour): "..flowRate)

    if frequency ~= 0
    then
        time = rtctime.get();
        http.get(RASBPI_ADDRESS .. "/api/v1.0/addWaterRecord?time="..time.."&flow="..flowRate, nil, function(code, data)
        if (code < 0) then
            print("HTTP request failed")
        else
            print("Sent data to server successfully.");
        end
        end)
    end

    numPulses = 1;
 end

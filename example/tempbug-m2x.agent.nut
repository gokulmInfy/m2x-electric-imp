class M2XFeed {
    _apiKey = null;
    _feedId = null;
    
    _baseUrl = null;
    _headers = null;
    
    constructor(apiKey, feedId) {
        _apiKey = apiKey;
        _feedId = feedId;
        
        _baseUrl = format("http://api-m2x.att.com/v1/feeds/%s", _feedId);
        _headers = {
            "X-M2X-KEY": _apiKey,
            "Content-Type": "application/json"
        };
    }
  
    function put(feedName, value, callback = null) {
        if (callback == null) callback = _defaultCallback.bindenv(this);
        
        local streamUrl = format("%s/streams/%s", _baseUrl, feedName);
        local body = http.jsonencode({ "value": value });
        http.put(streamUrl, _headers, body).sendasync(callback);
    }

    function get() {
        local requestUrl = format("%s/streams", _baseUrl);
        local resp = http.get(requestUrl, _headers).sendsync();
        
        local streams = {};
        
        if (resp.statuscode != 200) {
            server.log(format("Error getting feed(s) - %i: %s", resp.statuscode, resp.body));
            return;
        }
        
        try {
            local data = http.jsondecode(resp.body);
            if ("streams" in data) {
                return data.streams;
            } else {
                server.log("Error getting feed(s) - 'streams' not in response body.")
                return;
            }
        } catch(ex) {
            server.log(format("Error getting feed(s) - %s", ex));
            return;
        }
    }
  
    /********** Private Functions - don't call these **********/
    function _defaultCallback(resp) {
        server.log(format("HTTP Response - %i: %s", resp.statuscode, resp.body)); 
    }
}

API_KEY <- "_Master Key_";
FEED_ID <- "_Feed ID_";

officeFeed <- M2XFeed(API_KEY, FEED_ID);

device.on("temp", function(data) {
    officeFeed.put("temp", data.temp);
});

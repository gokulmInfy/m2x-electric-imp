class M2XClient {
    _apiBase = null;
    _headers = null;

    constructor(apiKey, apiBase) {
        _apiBase = apiBase;
        _headers = {
            "X-M2X-KEY": apiKey,
            "Content-Type": "application/json",
            "User-Agent": "M2X Electric Imp Client/3.0.0"
        };
    }

    function get(path, params = null, cb = null) {
        local request = http.get(_createUrl(path, params), _headers);
        return _sendRequest(request, cb);
    }

    function post(path, body, cb = null) {
        local req = http.post(_createUrl(path), _headers, _encodeBody(body));
        return _sendRequest(req, cb);
    }

    function put(path, body, cb = null) {
        local request = http.put(_createUrl(path), _headers, _encodeBody(body));
        return _sendRequest(request, cb);
    }

    function httpdelete(path, cb = null) {
        local request = http.httpdelete(_createUrl(path), _headers);
        return _sendRequest(request, cb);
    }

    function httpdeleteWithData(path, body, cb = null) {
        local request = http.request("DELETE", _createUrl(path), _headers, _encodeBody(body));
        return _sendRequest(request, cb);
    }

    function _createUrl(path, params = null) {
        local url = _apiBase + path;
        if (params) {
            url += "?" + http.urlencode(params);
        }
        server.log("URL to use: " + url);
        return url;
    }

    function _encodeBody(body) {
        if ((typeof body) != "string") {
            body = http.jsonencode(body);
        }
        return body;
    }

    function _sendRequest(req, cb) {
        if (cb) {
            req.sendasync(function(resp) {
                    cb(_parseJsonResponse(resp));
                });
        } else {
            return _parseJsonResponse(req.sendsync());
        }
    }

    function _parseJsonResponse(resp) {
        local parsed_body;
        try {
            parsed_body = http.jsondecode(resp.body);
        } catch(ex) {
            parsed_body = resp.body;
        }
        return {"code": resp.statuscode, "body": parsed_body};
    }
}

class M2XDevices {
    _client = null;

    constructor(client) {
        _client = client;
    }

    function catalog(params = null, callback = null) {
        return _client.get("/devices/catalog", params, callback);
    }

    function list(params = null, callback = null) {
        return _client.get("/devices", params, callback);
    }

    function tags(callback = null) {
        return _client.get("/devices/tags", null, callback);
    }

    function create(body, callback = null) {
        return _client.post("/devices", body, callback);
    }

    function update(deviceId, body, callback = null) {
        local url = format("/devices/%s", deviceId);
        return _client.put(url, body, callback);
    }

    function view(deviceId, callback = null) {
        local url = format("/devices/%s", deviceId);
        return _client.get(url, null, callback);
    }

    function readLocation(deviceId, callback = null) {
        local url = format("/devices/%s/location", deviceId);
        return _client.get(url, null, callback);
    }

    function updateLocation(deviceId, body, callback = null) {
        local url = format("/devices/%s/location", deviceId);
        return _client.put(url, body, callback);
    }

    function listStreams(deviceId, callback = null) {
        local url = format("/devices/%s/streams", deviceId);
        return _client.get(url, null, callback);
    }

    function createStream(deviceId, streamName, body, callback = null) {
        local url = format("/devices/%s/streams/%s", deviceId, streamName);
        return _client.put(url, body, callback);
    }

    function updateStream(deviceId, streamName, body, callback = null) {
        return createStream(deviceId, streamName, body, callback);
    }

    function updateStreamValue(deviceId, streamName, body, callback = null) {
        local url = format("/devices/%s/streams/%s/value", deviceId, streamName);
        return _client.put(url, body, callback);
    }

    function viewStream(deviceId, streamName, callback = null) {
        local url = format("/devices/%s/streams/%s", deviceId, streamName);
        return _client.get(url, null, callback);
    }

    function listStreamValues(deviceId, streamName, params = null, callback = null) {
        local url = format("/devices/%s/streams/%s/values.json", deviceId, streamName);
        return _client.get(url, params, callback);
    }

    function samplingStreamValues(deviceId, streamName, params = null, callback = null) {
        local url = format("/devices/%s/streams/%s/sampling.json", deviceId, streamName);
        return _client.get(url, params, callback);
    }

    function streamStats(deviceId, streamName, params = null, callback = null) {
        local url = format("/devices/%s/streams/%s/stats", deviceId, streamName);
        return _client.get(url, params, callback);
    }

    function postStreamValues(deviceId, streamName, body, callback = null) {
        local url = format("/devices/%s/streams/%s/values", deviceId, streamName);
        return _client.post(url, body, callback);
    }

    function deleteStreamValues(deviceId, streamName, body, callback = null) {
        local url = format("/devices/%s/streams/%s/values", deviceId, streamName);
        return _client.httpdeleteWithData(url, body, callback);
    }

    function deleteStream(deviceId, streamName, callback = null) {
        local url = format("/devices/%s/streams/%s", deviceId, streamName);
        return _client.httpdelete(url, callback);
    }

    function postDeviceUpdates(deviceId, body, callback = null) {
        local url = format("/devices/%s/updates", deviceId);
        return _client.post(url, body, callback);
    }

    // Link: https://m2x.att.com/developer/documentation/v2/device#Post-Device-Update--Single-Values-to-Multiple-Streams-
    function postDeviceUpdate(deviceId, body, callback = null) {
        local url = format("/devices/%s/update", deviceId);
        return _client.post(url, body, callback);
    }

    function viewLog(deviceId, callback = null) {
        local url = format("/devices/%s/log", deviceId);
        return _client.get(url, null, callback);
    }

    function deleteDevice(deviceId, callback = null) {
        local url = format("/devices/%s", deviceId);
        return _client.httpdelete(url, callback);
    }
}

class M2X {
    _apiKey = null;
    _apiBase = null;
    _client = null;
    _devices = null;

    constructor(apiKey, apiBase = "http://api-m2x.att.com/v2") {
        _apiKey = apiKey;
        _apiBase = apiBase;
    }

    function client() {
        if (!_client) {
            _client = M2XClient(_apiKey, _apiBase);
        }
        return _client;
    }

    function devices() {
        if (!_devices) {
            _devices = M2XDevices(client());
        }
        return _devices;
    }
}

/********** Example usage of M2XDevices class **********/

// set api key and device to use
API_KEY <- "_Master Key_";
DEVICE_ID <- "_Device ID_";

// create a device:
m2x <- M2X(API_KEY);
devices <- m2x.devices();

// push data to temperature stream:
body <- http.jsonencode({ "value": 24.3 });
resp <- devices.updateStreamValue(DEVICE_ID, "aabbcc", body);

// get (and log) data from device:
function logStreams(data) {
    if (!(data && ("streams" in data))) {
        server.log("Error getting device(s) - 'streams' not in response body.");
        return;
    }
    local streams = data.streams;

    // loop through every stream
    foreach(stream in streams) {
        server.log("*************************");
        // loop through each property in the stream
        foreach(k, value in stream) {
            server.log(k + ": " + value);
        }
    }
}

logStreams(devices.listStreams(DEVICE_ID).body);

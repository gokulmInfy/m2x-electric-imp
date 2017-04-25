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

    function getRaw(path, params = null, cb = null) {
        local request = http.get(_createUrl(path, params), _headers);
        return _sendRequestRaw(request, cb);
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

    function _sendRequestRaw(req, cb) {
        if (cb) {
            req.sendasync(function(resp) {
                    cb(resp);
                });
        } else {
            return req.sendsync();
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
    /**
     * @description Method for [List/search Public Devices Catalog]{@link https://m2x.att.com/developer/documentation/v2/device#List-Public-Devices-Catalog} endpoint.
     * This allows unauthenticated users to search Devices from other users that have been marked as public, allowing them to read public Device metadata, locations, streams list, and view each Devices' stream metadata and its values.
     * @param params {object} Query parameters passed as keyword arguments. View M2X API Docs for listing of available parameters.
     * @param callback {function} Response callback
     * @returns Devices list
     */
    function catalog(params = null, callback = null) {
        return _client.get("/devices/catalog", params, callback);
    }
    /**
     * @description Method for [List Devices]{@link https://m2x.att.com/developer/documentation/v2/device#List-Devices} endpoint.
     * @param params {object} Query parameters passed as keyword arguments. View M2X API Docs for listing of available parameters.
     * @param callback {function} Response callback
     * @returns Devices list
     */
    function list(params = null, callback = null) {
        return _client.get("/devices", params, callback);
    }
    /**
     * @description Method for [List Devices Tags]{@link https://m2x.att.com/developer/documentation/v2/device#List-Device-Tags} endpoint.
     * @param callback {function} Response callback
     * @returns Devices list
     */
    function tags(callback = null) {
        return _client.get("/devices/tags", null, callback);
    }
    /**
     * @description Method for [Create Device]{@link https://m2x.att.com/developer/documentation/v2/device#Create-Device} endpoint.
     * @param body {object} View M2X API Docs for listing of available parameters.
     * @param callback {function} Response callback
     * @returns Device details
     */
    function create(body, callback = null) {
        return _client.post("/devices", body, callback);
    }
    /**
     * @description Method for [Update Device Details]{@link https://m2x.att.com/developer/documentation/v2/device#Update-Device-Details} endpoint.
     * @param deviceId {str} ID of the Device to update
     * @param body {object} Query parameters passed as keyword arguments. View M2X API Docs for listing of available parameters.
     * @param callback {function} Response callback
     * @returns HttpResponse The API response, see M2X API docs for details
     */
    function update(deviceId, body, callback = null) {
        local url = format("/devices/%s", deviceId);
        return _client.put(url, body, callback);
    }
    /**
     * @description Method for [View Device Details]{@link https://m2x.att.com/developer/documentation/v2/device#View-Device-Details} endpoint.
     * @param deviceId {str} ID of the Device to retrieve
     * @param callback {function} Response callback
     * @returns Device details
     */
    function view(deviceId, callback = null) {
        local url = format("/devices/%s", deviceId);
        return _client.get(url, null, callback);
    }
    /**
     * @description Method for [Read Device Location]{@link https://m2x.att.com/developer/documentation/v2/device#Read-Device-Location} endpoint.
     * Note that this method can return an empty value (response status of 204) if the device has no location defined.
     * @param deviceId {str} ID of the Device to retrieve location details
     * @param callback {function} Response callback
     * @returns Location details
     */
    function readLocation(deviceId, callback = null) {
        local url = format("/devices/%s/location", deviceId);
        return _client.get(url, null, callback);
    }
    /**
     * @description Method for [Update Device Location]{@link https://m2x.att.com/developer/documentation/v2/device#Update-Device-Location} endpoint.
     * @param deviceId {str} ID of the Device to update location details
     * @param body {object} Query parameters passed as keyword arguments. View M2X API Docs for listing of available parameters.
     * @param callback {function} Response callback
     * @returns HttpResponse The API response, see M2X API docs for details
     */
    function updateLocation(deviceId, body, callback = null) {
        local url = format("/devices/%s/location", deviceId);
        return _client.put(url, body, callback);
    }
    /**
     * @description Method for [List Data Streams]{@link https://m2x.att.com/developer/documentation/v2/device#List-Data-Streams} endpoint.
     * @param deviceId {str} ID of the Device to retrieve list of the associated streams
     * @param callback {function} Response callback
     * @returns Data streams list
     */
    function listStreams(deviceId, callback = null) {
        local url = format("/devices/%s/streams", deviceId);
        return _client.get(url, null, callback);
    }
    /**
     * @description Method for [Create Update Data Stream]{@link https://m2x.att.com/developer/documentation/v2/device#Create-Update-Data-Stream} endpoint.
     * If the stream doesn't exist it will create it.
     * @param deviceId {str} ID of the Device to update stream's properties
     * @param streamName {str} Name of the stream to be updated
     * @param body {object} Query parameters passed as keyword arguments. View M2X API Docs for listing of available parameters.
     * @param callback {function} Response callback
     * @returns HttpResponse The API response, see M2X API docs for details
     */
    function createStream(deviceId, streamName, body, callback = null) {
        local url = format("/devices/%s/streams/%s", deviceId, streamName);
        return _client.put(url, body, callback);
    }

    function updateStream(deviceId, streamName, body, callback = null) {
        return createStream(deviceId, streamName, body, callback);
    }
    /**
     * @description Method for [Update Data Stream Value]{@link https://m2x.att.com/developer/documentation/v2/device#Update-Data-Stream-Value} endpoint.
     * @param deviceId {str} ID of the Device to set the stream value
     * @param streamName {str} Name of the stream to be set
     * @param body {object} Query parameters passed as keyword arguments. View M2X API Docs for listing of available parameters.
     * @param callback {function} Response callback
     * @returns HttpResponse The API response, see M2X API docs for details
     */
    function updateStreamValue(deviceId, streamName, body, callback = null) {
        local url = format("/devices/%s/streams/%s/value", deviceId, streamName);
        return _client.put(url, body, callback);
    }
    /**
     * @description Method for [View Data Stream]{@link https://m2x.att.com/developer/documentation/v2/device#View-Data-Stream} endpoint.
     * @param deviceId {str} ID of the Device to get the stream details
     * @param streamName {str} Name of the stream to retrieve
     * @param callback {function} Response callback
     * @returns Data Stream details
     */
    function viewStream(deviceId, streamName, callback = null) {
        local url = format("/devices/%s/streams/%s", deviceId, streamName);
        return _client.get(url, null, callback);
    }
    /**
     * @description Method for [List Data Stream Values]{@link https://m2x.att.com/developer/documentation/v2/device#List-Data-Stream-Values} endpoint.
     * @param deviceId {str} ID of the Device
     * @param streamName {str} Name of the stream to retrieve
     * @param params {object} Query parameters passed as keyword arguments. View M2X API Docs for listing of available parameters.
     * @param callback {function} Response callback
     * @returns Data Stream list
     */
    function listStreamValues(deviceId, streamName, params = null, callback = null) {
        local url = format("/devices/%s/streams/%s/values.json", deviceId, streamName);
        return _client.get(url, params, callback);
    }
    /**
     * @description Method for [Data Stream Sampling]{@link https://m2x.att.com/developer/documentation/v2/device#Data-Stream-Sampling} endpoint.
     * @param deviceId {str} ID of the Device
     * @param streamName {str} Name of the stream to retrieve
     * @param params {object} Query parameters passed as keyword arguments. View M2X API Docs for listing of available parameters.
     * @param callback {function} Response callback
     * @returns HttpResponse The API response, see M2X API docs for details
     */
    function samplingStreamValues(deviceId, streamName, params = null, callback = null) {
        local url = format("/devices/%s/streams/%s/sampling.json", deviceId, streamName);
        return _client.get(url, params, callback);
    }
    /**
     * @description Method for [Data Stream Stats]{@link https://m2x.att.com/developer/documentation/v2/device#Data-Stream-Stats} endpoint.
     * @param deviceId {str} ID of the Device
     * @param streamName {str} Name of the stream to retrieve
     * @param params {object} Query parameters passed as keyword arguments. View M2X API Docs for listing of available parameters.
     * @param callback {function} Response callback
     * @returns Data Stream list
     */
    function streamStats(deviceId, streamName, params = null, callback = null) {
        local url = format("/devices/%s/streams/%s/stats", deviceId, streamName);
        return _client.get(url, params, callback);
    }
    /**
     * @description Method for [Post Data Stream Values]{@link https://m2x.att.com/developer/documentation/v2/device#Post-Data-Stream-Values} endpoint.
     * @param deviceId {str} ID of the Device
     * @param streamName {str} Name of the existing stream
     * @param body The value to update
     * @param callback {function} Response callback
     * @returns HttpResponse The API response, see M2X API docs for details
     */
    function postStreamValues(deviceId, streamName, body, callback = null) {
        local url = format("/devices/%s/streams/%s/values", deviceId, streamName);
        return _client.post(url, body, callback);
    }
    /**
     * @description Method for [Delete Data Stream Values]{@link https://m2x.att.com/developer/documentation/v2/device#Delete-Data-Stream-Values} endpoint.
     * @param deviceId {str} ID of the Device
     * @param streamName {str} Name of the existing stream to delete values
     * @param body {object} Query parameters passed as keyword arguments. View M2X API Docs for listing of available parameters.
     * @param callback {function} Response callback
     * @returns HttpResponse The API response, see M2X API docs for details
     */
    function deleteStreamValues(deviceId, streamName, body, callback = null) {
        local url = format("/devices/%s/streams/%s/values", deviceId, streamName);
        return _client.httpdeleteWithData(url, body, callback);
    }
    /**
     * @description Method for [Delete Data Stream]{@link https://m2x.att.com/developer/documentation/v2/device#Delete-Data-Stream} endpoint.
     * @param deviceId {str} ID of the Device
     * @param streamName {str} Name of the existing stream to be deleted
     * @param callback {function} Response callback
     * @returns HttpResponse The API response, see M2X API docs for details
     */
    function deleteStream(deviceId, streamName, callback = null) {
        local url = format("/devices/%s/streams/%s", deviceId, streamName);
        return _client.httpdelete(url, callback);
    }
    /**
     * @description Method for [Post Device Updates(Multiple Values to Multiple Streams)]{@link https://m2x.att.com/developer/documentation/v2/device#Post-Device-Updates--Multiple-Values-to-Multiple-Streams-} endpoint.
     * @param deviceId {str} ID of the Device
     * @param body {object} Query parameters passed as keyword arguments. View M2X API Docs for listing of available parameters.
     * @param callback {function} Response callback
     * @returns HttpResponse The API response, see M2X API docs for details
     */
    function postDeviceUpdates(deviceId, body, callback = null) {
        local url = format("/devices/%s/updates", deviceId);
        return _client.post(url, body, callback);
    }
    /**
     * @memberOf Devices
     * @description Method for [Post Device Update(Single Value to Multiple Streams)]{@link https://m2x.att.com/developer/documentation/v2/device#Post-Device-Update--Single-Values-to-Multiple-Streams-} endpoint.
     * @param id {str} ID of the Device
     * @param params {object} Query parameters passed as keyword arguments. View M2X API Docs for listing of available parameters.
     * @param callback {function} Response callback
     * @returns HttpResponse The API response, see M2X API docs for details
     */
    function postDeviceUpdate(deviceId, body, callback = null) {
        local url = format("/devices/%s/update", deviceId);
        return _client.post(url, body, callback);
    }
    /**
     * @description Method for [View Request Log]{@link https://m2x.att.com/developer/documentation/v2/device#View-Request-Log} endpoint.
     * @param deviceId {str} ID of the Device
     * @param callback {function} Response callback
     * @returns HttpResponse The API response, see M2X API docs for details
     */
    function viewLog(deviceId, callback = null) {
        local url = format("/devices/%s/log", deviceId);
        return _client.get(url, null, callback);
    }
    /**
     * @description Method for [Delete Device]{@link https://m2x.att.com/developer/documentation/v2/device#Delete-Device} endpoint.
     * @param id {str} ID of the Device to be deleted
     * @param callback {function} Response callback
     * @returns HttpResponse The API response, see M2X API docs for details
     */
    function deleteDevice(deviceId, callback = null) {
        local url = format("/devices/%s", deviceId);
        return _client.httpdelete(url, callback);
    }
    /**
    * @description Method for [Device's List of Received Commands]{@link https://m2x.att.com/developer/documentation/v2/commands#Device-s-List-of-Received-Commands} endpoint.
    * @param deviceId {str} ID of the Device to get list of received commands
    * @param callback {function} Response callback
    * @returns Commands list
    */
    function listCommands(deviceId, callback = null) {
        local url = format("/devices/%s/commands", deviceId);
        return _client.get(url, null, callback);
    }
    /**
     * @description Method for [Device Marks a Command as Processed]{@link https://m2x.att.com/developer/documentation/v2/commands#Device-Marks-a-Command-as-Processed} endpoint.
     * @param deviceId {str} ID of the Device
     * @param commandId {str} ID of the Command to retrieve
     * @param body {object} Query parameters passed as keyword arguments. View M2X API Docs for listing of available parameters.
     * @param callback {function} Response callback
     * @returns HttpResponse The API response, see M2X API docs for details
     */
    function processCommand(deviceId, commandId, body, callback = null) {
        local url = format("/devices/%s/commands/%s/process", deviceId, commandId);
        return _client.put(url, body, callback);
    }
    /**
     * @description Method for [Device Marks a Command as Rejected]{@link https://m2x.att.com/developer/documentation/v2/commands#Device-Marks-a-Command-as-Rejected} endpoint.
     * @param deviceId {str} ID of the Device
     * @param commandId {str} ID of the Command to retrieve
     * @param body {object} Query parameters passed as keyword arguments. View M2X API Docs for listing of available parameters.
     * @param callback {function} Response callback
     * @returns HttpResponse The API response, see M2X API docs for details
     */
    function rejectCommand(deviceId, commandId, body, callback = null) {
        local url = format("/devices/%s/commands/%s/reject", deviceId, commandId);
        return _client.put(url, body, callback);
    }
}

class M2XTimestamps {
    _client = null;

    constructor(client) {
        _client = client;
    }

    function getTime(callback = null) {
        return _client.get("/time", null, callback);
    }

    function getSeconds(callback = null) {
        return _client.getRaw("/time/seconds", null, callback);
    }

    function getMillis(callback = null) {
        return _client.getRaw("/time/millis", null, callback);
    }

    function getISO8601(callback = null) {
        return _client.getRaw("/time/iso8601", null, callback);
    }
}

class M2X {
    _apiKey = null;
    _apiBase = null;
    _client = null;
    _devices = null;
    _timestamps = null;

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

    function timestamps() {
        if (!_timestamps) {
            _timestamps = M2XTimestamps(client());
        }
        return _timestamps;
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

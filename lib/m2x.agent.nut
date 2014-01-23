class M2XClient {
    _apiBase = null;
    _headers = null;

    constructor(apiKey, apiBase) {
        _apiBase = apiBase;
        _headers = {
            "X-M2X-KEY": apiKey,
            "Content-Type": "application/json"
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
            req.sendasync(cb);
        } else {
            return req.sendsync();
        }
    }
}

class M2XFeeds {
    _client = null;

    constructor(client) {
        _client = client;
    }

    function list(params = null, callback = null) {
        return _client.get("/feeds", params, callback);
    }

    function view(feedId, callback = null) {
        local url = format("/feeds/%s", feedId);
        return _client.get(url, null, callback);
    }

    function log(feedId, callback = null) {
        local url = format("/feeds/%s/log", feedId);
        return _client.get(url, null, callback);
    }

    function location(feedId, callback = null) {
        local url = format("/feeds/%s/location", feedId);
        return _client.get(url, null, callback);
    }

    function updateLocation(feedId, body, callback = null) {
        local url = format("/feeds/%s/location", feedId);
        return _client.put(url, body, callback);
    }

    function streams(feedId, callback = null) {
        local url = format("/feeds/%s/streams", feedId);
        return _client.get(url, null, callback);
    }

    function stream(feedId, streamName, callback = null) {
        local url = format("/feeds/%s/streams/%s", feedId, streamName);
        return _client.get(url, null, callback);
    }

    function streamValues(feedId, streamName, params, callback = null) {
        local url = format("feeds/%s/streams/%s/values", feedId, streamName);
        return _client.get(url, params, callback);
    }

    function updateStream(feedId, streamName, value, callback = null) {
        local url = format("/feeds/%s/streams/%s", feedId, streamName);
        return _client.put(url, {"value": value}, callback);
    }

    function deleteStream(feedId, streamName, callback = null) {
        local url = format("/feeds/%s/streams/%s", feedId, streamName);
        return _client.httpdelete(url, callback);
    }

    function postMultiple(feedId, values, callback = null) {
        local url = format("/feeds/%s", feedId);
        return _client.post(url, {"values": values}, callback);
    }
}

class M2X {
    _apiKey = null;
    _apiBase = null;
    _client = null;
    _feeds = null;

    constructor(apiKey, apiBase = "http://api-m2x.att.com/v1") {
        _apiKey = apiKey;
        _apiBase = apiBase;
    }

    function client() {
        if (!_client) {
            _client = M2XClient(_apiKey, _apiBase);
        }
        return _client;
    }

    function feeds() {
        if (!_feeds) {
            _feeds = M2XFeeds(client());
        }
        return _feeds;
    }
}

function parseJsonResponse(resp) {
    if (resp.statuscode != 200) {
        server.log(format("Error getting feed(s) - %i: %s", resp.statuscode, resp.body));
        return;
    }

    try {
        return http.jsondecode(resp.body);
    } catch(ex) {
        server.log(format("Error getting feed(s) - %s", ex));
        return;
    }
}

/********** Example usage of M2XFeeds class **********/

// set api key and feed to use
API_KEY <- "_Master Key_";
FEED_ID <- "_Feed ID_";

// create a feed:
m2x <- M2X(API_KEY);
feeds <- m2x.feeds();

// push data to temperature stream:
feeds.updateStream(FEED_ID, "temperature", 24.3);

// get (and log) data from feed:
function logStreams(data) {
    if (!(data && ("streams" in data))) {
        server.log("Error getting feed(s) - 'streams' not in response body.");
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

logStreams(parseJsonResponse(feeds.streams(FEED_ID)));

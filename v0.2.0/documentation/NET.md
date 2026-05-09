# NET (Network Stack)

The **NET** module is KRNL's HTTP client built on top of the Retro Gadgets Wifi component. It provides a full-featured networking API with request queuing, automatic retries, response caching, interceptors, and audio streaming support.

---

## Overview

NET turns the basic Wifi chip into a production-ready HTTP client. All requests are asynchronous and callback-based, fitting naturally into Retro Gadgets' event-driven architecture.

**Key features:**

* **HTTP methods** — Full support for GET, POST, PUT, DELETE, PATCH, plus JSON and form helpers.
* **Request queuing** — Configurable concurrency limit prevents overwhelming the Wifi hardware.
* **Automatic retries** — Failed requests are automatically retried with configurable count and delay.
* **Response caching** — Cache GET responses with configurable TTL to reduce redundant network calls.
* **Interceptors** — Request and response middleware for logging, auth headers, error handling, etc.
* **Audio streaming** — Stream audio directly from URLs via the Wifi chip.
* **Progress tracking** — Monitor download/upload progress for active requests.
* **Cookie management** — Clear cookies globally or per-domain.

---

## Accessing NET

```lua
local KRNL = require("/KRNL/OS")

-- By name
local NET = KRNL.GetNET("Wifi0")

-- Primary instance (first Wifi detected at boot)
local NET = KRNL.GetPrimaryNET()
```

---

## Configuration

NET is configured during kernel boot via `Config.NETConfig`. The following settings are available:

| Option | Type | Default | Description |
|---|---|---|---|
| `base_url` | string | `""` | Base URL prepended to relative paths. |
| `timeout` | number | `30` | Default request timeout in seconds. |
| `retries` | number | `0` | Default number of automatic retries on failure. |
| `retry_delay` | number | `1` | Delay between retries in seconds. |
| `max_concurrent` | number | `4` | Maximum number of simultaneous requests. |
| `default_headers` | table | `{}` | Headers applied to every request. |
| `cache_enabled` | boolean | `false` | Whether response caching is enabled globally. |
| `cache_ttl` | number | `60` | Cache time-to-live in seconds. |

Configuration can be changed at runtime using setter methods (see below).

---

## HTTP Methods

All HTTP methods are asynchronous and accept a callback function that receives a response object.

### `NET:Get(url: string, callback: function, options: table?)`

Performs an HTTP GET request.

```lua
NET:Get("https://api.example.com/users", function(response)
    if response.ok then
        print("Status: " .. response.status)
        print("Body: " .. response.text)
    else
        print("Error: " .. response.error.message)
    end
end, {
    headers = { ["Authorization"] = "Bearer token123" },
    timeout = 10,
    cache = true
})
```

### `NET:Post(url: string, body: string, callback: function, options: table?)`

Performs an HTTP POST request with a raw body.

```lua
NET:Post("https://api.example.com/data", "Hello World", function(response)
    print(response.status)
end, { contentType = "text/plain" })
```

### `NET:PostJSON(url: string, data: table, callback: function, options: table?)`

Performs an HTTP POST with automatic JSON serialization. Sets `Content-Type: application/json` and `Accept: application/json` headers.

```lua
NET:PostJSON("https://api.example.com/users", {
    name = "Player1",
    score = 100
}, function(response)
    if response.ok then
        print("Created user: " .. response.json.id)
    end
end)
```

### `NET:PostForm(url: string, form: table, callback: function, options: table?)`

Performs an HTTP POST with form-encoded data.

```lua
NET:PostForm("https://api.example.com/login", {
    username = "admin",
    password = "secret"
}, function(response)
    print(response.text)
end)
```

### `NET:Put(url: string, body: string, callback: function, options: table?)`

Performs an HTTP PUT request.

### `NET:PutJSON(url: string, data: table, callback: function, options: table?)`

Performs an HTTP PUT with automatic JSON serialization.

### `NET:Delete(url: string, callback: function, options: table?)`

Performs an HTTP DELETE request.

### `NET:Patch(url: string, body: string, callback: function, options: table?)`

Performs an HTTP PATCH request.

### `NET:PatchJSON(url: string, data: table, callback: function, options: table?)`

Performs an HTTP PATCH with automatic JSON serialization.

### `NET:Request(options: table)`

Generic request method for any HTTP method. Useful for dynamic or custom requests.

```lua
NET:Request({
    method = "GET",
    url = "https://api.example.com/data",
    headers = { ["X-Custom"] = "value" },
    timeout = 15,
    callback = function(response)
        print(response.text)
    end
})
```

---

## Response Object

All callbacks receive a **response object** with the following fields:

| Field | Type | Description |
|---|---|---|
| `ok` | boolean | Whether the request succeeded. |
| `status` | number | HTTP status code (200, 404, etc.). |
| `url` | string | The final URL after redirects. |
| `method` | string | HTTP method used. |
| `text` | string? | Response body as text. |
| `data` | any? | Raw response data. |
| `pixelData` | any? | Pixel data (for image responses). |
| `audioSample` | any? | Audio sample data. |
| `contentType` | string | Content-Type header value. |
| `handle` | number? | Internal request handle. |
| `error` | table? | Error info `{ type: string, message: string }`. |
| `cached` | boolean | Whether the response was served from cache. |
| `elapsed` | number | Request duration in seconds. |
| `json` | any? | Auto-parsed JSON body (if Content-Type is JSON). |

---

## Request Options

All HTTP methods accept an optional `options` table:

| Option | Type | Description |
|---|---|---|
| `headers` | table | Additional headers for this request. |
| `timeout` | number | Override the default timeout for this request. |
| `retries` | number | Override the default retry count for this request. |
| `cache` | boolean | `false` to skip cache for this request. |
| `contentType` | string | Content-Type header (for body requests). |

---

## Audio Streaming

### `NET:StreamAudio(url: string, callback: function): handle?`

Streams audio from a URL directly through the Wifi chip. Returns a handle for tracking, or `nil` if the Wifi is unavailable.

```lua
local handle = NET:StreamAudio("https://example.com/audio.mp3", function(sample)
    -- Process audio sample
end)
```

---

## Progress Tracking

### `NET:GetDownloadProgress(handle: number): number`

Returns the download progress (0.0 to 1.0) for the given request handle.

### `NET:GetUploadProgress(handle: number): number`

Returns the upload progress (0.0 to 1.0) for the given request handle.

### `NET:IsPending(handle: number): boolean`

Returns `true` if a request with the given handle is still active.

```lua
local handle = NET:Get("https://example.com/large-file.zip", function(response)
    print("Download complete!")
end)

-- In a task update loop:
function update()
    if handle and NET:IsPending(handle) then
        local progress = NET:GetDownloadProgress(handle)
        print("Progress: " .. math.floor(progress * 100) .. "%")
    end
end
```

---

## Request Management

### `NET:Abort(handle: number): boolean`

Aborts a specific in-flight request. Removes it from the active set and triggers dequeue of queued requests.

### `NET:AbortAll()`

Aborts all active requests and clears the request queue.

```lua
NET:AbortAll()
```

---

## Caching

NET supports response caching for GET requests. When enabled, identical GET requests within the TTL window are served from cache without hitting the network.

### `NET:ClearCache()`

Clears all cached responses.

### `NET:ClearCacheFor(url: string, method: string?)`

Clears the cached response for a specific URL and method. Defaults to `"GET"`.

### `NET:SetCacheEnabled(enabled: boolean)`

Enables or disables response caching globally.

### `NET:SetCacheTTL(seconds: number)`

Sets the global cache time-to-live in seconds.

```lua
NET:SetCacheEnabled(true)
NET:SetCacheTTL(120)  -- Cache for 2 minutes

NET:Get("https://api.example.com/data", function(response)
    print("Cached: " .. tostring(response.cached))
end)
```

---

## Interceptors

Interceptors are middleware functions that can modify requests before they are sent and responses before they reach callbacks.

### `NET:UseRequestInterceptor(fn: function): NET`

Registers a request interceptor. The function receives the request object and must return a (possibly modified) request, or `nil` to cancel the request.

```lua
NET:UseRequestInterceptor(function(request)
    -- Add auth header to all requests
    request.headers = request.headers or {}
    request.headers["Authorization"] = "Bearer " .. authToken
    return request
end)

NET:UseRequestInterceptor(function(request)
    -- Block requests to certain domains
    if request.url:find("blocked.com") then
        return nil  -- Cancels the request
    end
    return request
end)
```

### `NET:UseResponseInterceptor(fn: function): NET`

Registers a response interceptor. The function receives the response object and must return a (possibly modified) response. Returning `nil` is treated as returning the original response.

```lua
NET:UseResponseInterceptor(function(response)
    -- Log all responses
    print(response.method .. " " .. response.url .. " → " .. response.status)
    return response
end)

NET:UseResponseInterceptor(function(response)
    -- Convert error responses to a standard format
    if not response.ok then
        response.error_message = "Request failed: " .. (response.error.message or "unknown")
    end
    return response
end)
```

---

## Cookie Management

### `NET:ClearCookies()`

Clears all cookies stored by the Wifi chip.

### `NET:ClearCookiesFor(url: string)`

Clears cookies for a specific domain/URL.

---

## Runtime Configuration

### `NET:SetBaseURL(url: string)`

Sets the base URL that is prepended to relative paths.

```lua
NET:SetBaseURL("https://api.example.com/v1")
NET:Get("/users", callback)  -- → https://api.example.com/v1/users
```

### `NET:SetDefaultHeader(key: string, value: string)`

Sets a header that is included in every request.

```lua
NET:SetDefaultHeader("Authorization", "Bearer token123")
NET:SetDefaultHeader("Accept", "application/json")
```

### `NET:SetTimeout(seconds: number)`

Sets the default request timeout.

### `NET:SetRetries(count: number, delay: number?)`

Sets the default retry count and optional delay between retries.

```lua
NET:SetRetries(3, 2)  -- Retry up to 3 times, 2 second delay
```

### `NET:SetMaxConcurrent(count: number)`

Sets the maximum number of simultaneous requests. Requests exceeding this limit are queued.

```lua
NET:SetMaxConcurrent(2)  -- Only 2 requests at a time
```

---

## JSON Utilities

### `NET.Encode(data: any): (boolean, string)`

Encodes a Lua table to a JSON string.

### `NET.Decode(text: string): (boolean, any)`

Decodes a JSON string to a Lua table.

```lua
local ok, json = NET.Encode({ name = "test", value = 42 })
local ok, data = NET.Decode('{"name": "test", "value": 42}')
```

---

## Diagnostics

### `NET:GetStats(): table`

Returns diagnostic information about the NET instance.

* **Returns**: Table with fields:
    * `active` *(number)* — Currently in-flight requests.
    * `queued` *(number)* — Requests waiting in the queue.
    * `cached` *(number)* — Cached responses in store.
    * `available` *(boolean)* — Whether the Wifi chip is available.
    * `runtime` *(number)* — Current CPU runtime.

```lua
local stats = NET:GetStats()
print(string.format("Active: %d | Queued: %d | Cached: %d",
    stats.active, stats.queued, stats.cached))
```

---

## Error Handling

When a request fails, the response object contains an `error` table:

```lua
{
    ok = false,
    status = 0,
    error = {
        type = "Timeout" | "Unavailable" | "EncodeError",
        message = "Request timed out"
    }
}
```

**Error types:**

| Type | Cause |
|---|---|
| `Timeout` | Request exceeded the configured timeout. |
| `Unavailable` | Wifi chip is not available or access was denied. |
| `EncodeError` | JSON encoding failed (in PostJSON/PutJSON/PatchJSON). |

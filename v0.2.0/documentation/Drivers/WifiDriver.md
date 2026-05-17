# Wifi Driver

> ##  Deprecated for Direct Use — Use NET Instead
>
> **The Wifi Driver is a low-level hardware wrapper.** It is used internally by the **NET module** and should not be called directly in application code. The NET module (`KRNL.GetPrimaryNET()`) provides a significantly better API with request queuing, automatic retries, response caching, interceptors, JSON helpers, and structured error handling.
>
> **Use NET for all HTTP operations:**
> ```lua
> local NET = KRNL.GetPrimaryNET()
> NET:Get("https://api.example.com/data", function(response)
>     if response.ok then
>         print(response.json.name)
>     end
> end)
> ```
>
> The documentation below is provided for **reference only** — for understanding the internal architecture, debugging, or advanced scenarios where direct hardware access is absolutely necessary.

---

## Overview

The Wifi Driver wraps a Retro Gadgets `Wifi` component and exposes raw HTTP methods, audio streaming, cookie management, and request lifecycle signals. It is the hardware-level layer that the NET module builds upon. Every HTTP call in NET ultimately delegates to one of the Wifi Driver's methods.

**Why you should use NET instead:**

| Feature | Wifi Driver | NET Module |
|---|---|---|
| Request queuing | No | Yes (configurable concurrency) |
| Automatic retries | No | Yes (configurable count + delay) |
| Response caching | No | Yes (configurable TTL) |
| JSON helpers | `PostJSON` only | `Encode`, `Decode`, `PostJSON`, `PutJSON`, `PatchJSON` |
| Interceptors | No | Yes (request + response middleware) |
| Structured errors | Raw signals | `response.error` table with type + message |
| Base URL | No | Yes (`SetBaseURL`) |
| Default headers | No | Yes (`SetDefaultHeader`) |
| Timeout management | No | Yes (per-request + global) |
| Diagnostics | Basic (`GetPendingCount`) | Full (`GetStats` with active/queued/cached) |
| PATCH method | No | Yes |
| Abort all | No | Yes (`AbortAll`) |
| Cache control | No | Yes (`ClearCache`, `ClearCacheFor`) |

---

## Accessing the Wifi Driver

```lua
local KRNL = require("/KRNL/OS")

-- Direct access (not recommended for app code)
local wifi = KRNL.GetDriver("Wifi0")

-- Recommended: use NET instead
local NET = KRNL.GetPrimaryNET()
```

---

## Internal Constants & Defaults

| Constant | Value | Description |
|---|---|---|
| `Prefix` | `"[WIFI DRIVER]:"` | Log message prefix for warnings and info. |

---

## Event Signals

The Wifi Driver exposes three signals created via `BetterEvents`:

| Signal | Fired When | Arguments |
|---|---|---|
| `OnResponse` | An HTTP response is received from the server. | Hardware-dependent response data. |
| `OnError` | A request fails (timeout, network error, etc.). | Hardware-dependent error data. |
| `OnProgress` | Upload or download progress is reported. | Hardware-dependent progress data. |

> **Note:** Signal argument types are determined by the Retro Gadgets hardware API and are not normalized. The NET module wraps these into a structured `response` object.

---

## API Reference

### Static Methods

#### `wifi.AddDriver(instance: WifiChip, name: string, registry: DriverRegistry): WifiDriver?`

Static factory method. Creates a new Wifi driver and registers it. Called internally by the kernel during boot.

* **instance**: The Retro Gadgets `WifiChip` component instance.
* **name**: The driver instance name.
* **registry**: The kernel's driver registry table.
* **Returns**: A new `WifiDriver` instance, or `nil` if the component type is invalid.

---

#### `wifi.GetDriver(name: string, registry: DriverRegistry): WifiDriver?`

Static lookup method. Retrieves a previously registered Wifi driver.

---

### Availability

#### `wifi:IsAvailable(): boolean`

Returns whether the Wifi chip is accessible and ready for requests.

* **Returns**: `true` if the Wifi chip is available.

---

### Event Channel Hooking

#### `wifi:HookEventChannel(): (sender: any, event: any) -> ()`

Returns the internal event handler function for direct hardware event channel attachment. Used internally by the kernel.

---

### HTTP Methods

All HTTP methods are asynchronous and optionally accept a callback. They return a request handle for tracking, or `nil` if the Wifi is unavailable.

#### `wifi:Get(url: string, callback?): number?`

Performs an HTTP GET request.

* **url**: The request URL.
* **callback**: *(Optional)* Callback invoked when the response arrives.
* **Returns**: Request handle, or `nil`.

#### `wifi:Post(url: string, body: string, callback?): number?`

Performs an HTTP POST with a raw string body.

* **url**: The request URL.
* **body**: The request body as a string.
* **callback**: *(Optional)* Response callback.
* **Returns**: Request handle, or `nil`.

#### `wifi:PostJSON(url: string, data: {any}, callback?): number?`

Performs an HTTP POST with automatic JSON serialization.

* **url**: The request URL.
* **data**: A Lua table to serialize as JSON.
* **callback**: *(Optional)* Response callback.
* **Returns**: Request handle, or `nil`.

#### `wifi:PostForm(url: string, form: {[string]: string}, callback?): number?`

Performs an HTTP POST with form-encoded data.

* **url**: The request URL.
* **form**: A key-value table of form fields.
* **callback**: *(Optional)* Response callback.
* **Returns**: Request handle, or `nil`.

#### `wifi:Put(url: string, body: string, callback?): number?`

Performs an HTTP PUT request with a raw body.

#### `wifi:Delete(url: string, callback?): number?`

Performs an HTTP DELETE request.

#### `wifi:Request(url, method, headers, contentType, body, callback?): number?`

Generic HTTP request method for any method with full control over headers and content type.

#### `wifi:StreamAudio(url: string, callback?): number?`

Streams audio from a URL directly through the Wifi chip.

* **url**: The audio stream URL.
* **callback**: *(Optional)* Callback invoked with the audio sample.
* **Returns**: Request handle, or `nil`.

---

### Request Management

#### `wifi:Abort(handle: number): boolean`

Aborts a specific in-flight request by its handle.

* **handle**: The request handle returned by an HTTP method.
* **Returns**: `true` if aborted, `false` if the handle is invalid.

#### `wifi:GetUploadProgress(handle: number): number`

Returns the upload progress for a request.

* **handle**: The request handle.
* **Returns**: Progress as a value between `0` and `1`.

#### `wifi:GetDownloadProgress(handle: number): number`

Returns the download progress for a request.

* **handle**: The request handle.
* **Returns**: Progress as a value between `0` and `1`.

#### `wifi:IsPending(handle: number): boolean`

Returns whether a request is still in-flight.

* **handle**: The request handle.
* **Returns**: `true` if the request is active.

#### `wifi:GetPendingCount(): number`

Returns the total number of currently pending (in-flight) requests.

* **Returns**: Pending request count.

---

### Cookies

#### `wifi:ClearCookies(): ()`

Clears all cookies stored by the Wifi chip.

#### `wifi:ClearCookiesFor(url: string): ()`

Clears cookies for a specific URL/domain.

* **url**: The URL whose cookies should be cleared.

---

## Internal Data Structures

### WifiDriverUserdata

| Field | Type | Description |
|---|---|---|
| `send_buffer` | `{ any }` | Outgoing data buffer for the Wifi chip. |
| `receive_buffer` | `{ any }` | Incoming data buffer from the Wifi chip. |
| `send_buffer_size` | `number` | Send buffer capacity. |
| `receive_buffer_size` | `number` | Receive buffer capacity. |
| `event_function` | `(sender: any, event: any) -> ()` | Internal event handler for hardware event channel. |
| `pending` | `{ [number]: any }` | Map of pending request handles to their data. |

---

## Wifi Driver vs NET Module — Migration Guide

If you have existing code that uses the Wifi Driver directly, here is how to migrate to NET:

### GET Request

```lua
-- ❌ Wifi Driver (raw)
local wifi = KRNL.GetDriver("Wifi0")
wifi:Get("https://api.example.com/users", function(data)
    print(data)
end)

-- ✅ NET Module
local NET = KRNL.GetPrimaryNET()
NET:Get("https://api.example.com/users", function(response)
    if response.ok then
        print(response.json)
    else
        print("Error: " .. response.error.message)
    end
end)
```

### POST JSON

```lua
-- ❌ Wifi Driver
wifi:PostJSON("https://api.example.com/users", { name = "test" }, function(data)
    print(data)
end)

-- ✅ NET Module
NET:PostJSON("https://api.example.com/users", { name = "test" }, function(response)
    if response.ok then
        print("Created: " .. response.json.id)
    end
end)
```

### Progress Tracking

```lua
-- ❌ Wifi Driver
local handle = wifi:Get("https://example.com/large.zip")
-- Poll manually with wifi:GetDownloadProgress(handle)

-- ✅ NET Module
local handle = NET:Get("https://example.com/large.zip", function(response)
    print("Done!")
end)
-- Same polling API, but wrapped with queuing and timeout support
if NET:IsPending(handle) then
    print("Progress: " .. math.floor(NET:GetDownloadProgress(handle) * 100) .. "%")
end
```

### Cookies

```lua
-- Both use the same API
wifi:ClearCookies()
NET:ClearCookies()  -- NET delegates to the same hardware method
```

---

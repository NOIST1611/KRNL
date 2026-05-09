```text                      
 ▄▄   ▄▄▄  ▄▄▄▄▄▄    ▄▄▄   ▄▄  ▄▄       
 ██  ██▀   ██▀▀▀▀██  ███   ██  ██       
 ██▄██     ██    ██  ██▀█  ██  ██       
 █████     ███████   ██ ██ ██  ██       
 ██  ██▄   ██  ▀██▄  ██  █▄██  ██       
 ██   ██▄  ██    ██  ██   ███  ██▄▄▄▄▄▄ 
 ▀▀    ▀▀  ▀▀    ▀▀▀ ▀▀   ▀▀▀  ▀▀▀▀▀▀▀▀                                    
       SDK V0.2.0
```
![Version](https://img.shields.io/badge/version-V0.2.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Retro%20Gadgets-orange)

**KRNL** is a modular micro-kernel and SDK for **Retro Gadgets** designed to make development of OS inside **Retro Gadgets** a lot more easier. It provides a standardized foundation for building custom operating systems, and everything what you would need to make an OS.

---

## Overview

**KRNL** is a comprehensive **SDK** for building custom operating systems within **Retro Gadgets** providing a robust foundation so you can focus on high-level features instead of writing a kernel from scratch.

### Key Pillars

* **Virtual File System (VFS):** File management support inspired by file systems inside real operating systems. Full read/write operations with automatic FlashMemory persistence, directory hierarchy, and built-in file execution.
* **Task Scheduler:** A lightweight module to run tasks inside OS. Create, launch, and manage processes with PID tracking, state management, and automatic crash recovery.
* **Inter-Process Communication (IPC):** A pub/sub event system for communication between tasks. Supports wildcard patterns, priority-based dispatch, and per-task cleanup.
* **Execution Handler:** A modular file execution system that allows registering custom format handlers. Supports both synchronous and asynchronous execution modes.
* **NET (Network Stack):** A full-featured HTTP client built on top of the Wifi driver. Supports GET/POST/PUT/DELETE/PATCH, JSON serialization, request queuing with concurrency control, automatic retries, response caching, interceptors, and audio streaming.
* **Unified Driver API:** A Hardware Abstraction Layer (HAL) that decouples RG components from the kernel core, ensuring maximum modularity and stability. Now includes AudioChip and Wifi drivers.
* **Modular Architecture:** A future-proof, modular design that allows for seamless modifications and effortless scaling of kernel capabilities.

---

## Repository Structure

The project follows a version-controlled directory structure to ensure stability for developers:

* **`/v0.2.0/`** — Legacy stable release.
    * **`/source/`** — The core logic (Process management, VFS, Drivers).
    * **`/OSGadget/`** — **KRNL NANO**, the default reference OS implementation.
    * **`/documentation/`** — Technical guides and API references for this version.
* **`LICENSE`** — MIT License.

---

## KRNL NANO (Reference OS)

Included in the repository is **KRNL NANO**, a minimalist terminal-based operating system built on top of the KRNL engine.

**Features included in KRNL NANO:**
* Interactive Shell with command history and scrolling.
* File manipulation commands (`ls`, `cd`, `mkdir`, `cat`, `write`, `rm`).
* System monitoring (`usage`, `ram`, `tps`, `sysinfo`).

---

## Getting Started

1. **Setup** copy and paste everything from **source** folder of your version (e.g., `/v0.2.0/`) into RG.
2. **Include** the library in your main script:
    ```lua
    local KRNL = require("/KRNL/OS")
    -- Your OS logic starts here!
    ```
3. **Boot** the kernel. The `Boot()` function is called automatically on `require`. It will:
    * Load all hardware drivers from the gadget's motherboard.
    * Initialize VFS for every FlashMemory component found.
    * Initialize NET for every Wifi component found.
4. **Update** — Don't forget to call `KRNL.Update()` in the global `update()` function:
    ```lua
    function update()
        KRNL.Update()
    end
    ```

---

## Quick Example

```lua
local KRNL = require("/KRNL/OS")

-- Get primary file system
local fs = KRNL.GetPrimaryVFS()

-- Write a file
fs:Write("/home/greeting.txt", "Hello from KRNL v0.2.0!")

-- Execute a script file
KRNL.Execute(fs, "/bin/my_script.lua", false)

-- Use IPC for inter-task communication
local IPC = KRNL.GetIPC()
IPC.Listen("user.login", function(data)
    print("User logged in: " .. data.name)
end)

-- Make an HTTP request
local NET = KRNL.GetPrimaryNET()
NET:Get("https://example.com/api", function(response)
    if response.ok then
        print("Status: " .. response.status)
        print("Body: " .. response.text)
    end
end)
```

---

## Documentation

For detailed information on how to build your own OS using KRNL, please refer to the documentation:

### v0.2.0
- [Syscall API Reference](./v0.2.0/documentation/API.md)
- [IPC Guide](./v0.2.0/documentation/IPC.md)
- [NET Guide](./v0.2.0/documentation/NET.md)
- [Execution Handler Guide](./v0.2.0/documentation/ExecutionHandler.md)
- [VFS Guide](./v0.2.0/documentation/VFS.md)

### v0.1.0 (Legacy)
- [API Reference](./v0.1.0/documentation/API.md)
- [VFS Guide](./v0.1.0/documentation/VFS.md)
- [Get Started](./v0.1.0/source/Note.md)

---

## License

This project is licensed under the **MIT License**. You are free to use, modify, and distribute it, even for commercial purposes, as long as the original copyright notice is included.

---

> Created by **NOIST**

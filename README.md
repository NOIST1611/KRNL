
```text
  _  _______  _   _ _      
 | |/ /  __ \| \ | | |     
 | ' /| |__) |  \| | |     
 |  < |  _  /| . ` | |     
 | . \| | \ \| |\  | |____ 
 |_|\_\_|  \_\_| \_|______|
       SDK V0.2.0
```


![Version](https://img.shields.io/badge/version-V0.2.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Retro%20Gadgets-orange)

**KRNL** is a modular micro-kernel and SDK for **Retro Gadgets** designed to make delelopment of OS inside **Retro Gadgets** a lot more easier. It provides a standardized foundation for building custom operating systems, and everything what you would need to make an OS.

---

## Overview

**KRNL** is a comprehensive **SDK** for building custom operating systems within **Retro Gadgets** providing a robust foundation so you can 
focus on high-level features instead of writing a kernel from scratch.

### Key Pillars:
* **Virtual File System (VFS):** File management support inspired by file systems inside real operating systems.
* **Task Scheduler:** A lightweight module to run tasks inside OS.
* **Unified Driver API:** A Hardware Abstraction Layer (HAL) that decouples RG components from the kernel core, ensuring maximum modularity and stability.
* **Modular Architecture:** A future-proof, modular design that allows for seamless modifications and effortless scaling of kernel capabilities..

---

##  Repository Structure

The project follows a version-controlled directory structure to ensure stability for developers:

* **`/v0.1.0/`** — Current stable release.
    * **`/source/`** — The core logic (Process management, VFS, Drivers).
    * **`/OSGadget/`** — **KRNL NANO**, the default reference OS implementation.
    * **`/documentation/`** — Technical guides and API references for this version.
* **`LICENSE`** — MIT License.

---

##  KRNL NANO (Reference OS)

Included in the repository is **KRNL NANO**, a minimalist terminal-based operating system built on top of the KRNL engine. 

**Features included in NANO:**
* Interactive Shell with command history and scrolling.
* File manipulation commands (`ls`, `cd`, `mkdir`, `cat`, `write`, `rm`).
* System monitoring (`usage`, `ram`, `tps`, `sysinfo`).

---

##  Getting Started

1.  **Setup** copy and paste everything from **source** folder of your version (e.g., `/v0.1.0/`) into RG.
2.  **Include** the library in your main script:
    ```lua
    local KRNL = require("/KRNL/OS")
    -- Your OS logic starts here!
    ```
---

## Documentation

For detailed information on how to build your own OS using KRNL, please refer to the documentation inside the version folders:
- [API Reference](./v0.1.0/documentation/API.md)
- [VFS Guide](./v0.1.0/documentation/VFS.md)
- [Get Started](./v0.1.0/source/Note.md)
---

##  License

This project is licensed under the **MIT License**. You are free to use, modify, and distribute it, even for commercial purposes, as long as the original copyright notice is included.

---

> Created by **NOIST**

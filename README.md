```text
  _  _______  _   _ _      
 | |/ /  __ \| \ | | |     
 | ' /| |__) |  \| | |     
 |  < |  _  /| . ` | |     
 | . \| | \ \| |\  | |____ 
 |_|\_\_|  \_\_| \_|______|
      CORE SDK v0.1.0
```

![Version](https://img.shields.io/badge/version-V0.1.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Retro%20Gadgets-orange)

**KRNL** is a modular micro-kernel and SDK designed for the **Retro Gadgets** environment. It provides a standardized foundation for building custom operating systems, handling low-level hardware communication, task management, and file systems.

---

## 🚀 Overview

KRNL isn't just an OS; it's a **platform**. It abstracts the complexity of Retro Gadgets hardware, allowing developers to focus on building interfaces and applications instead of building kernel from scratch.

### Key Pillars:
* **Virtual File System (VFS):** Advanced file management with support for directories, config serialization, and virtual paths.
* **Task Scheduler:** A lightweight engine to run multiple system tasks concurrently.
* **Unified Driver API:** A consistent way to interact with CPU, LCD, Keyboard, and Reality chips.
* **Modular Architecture:** The kernel is separated from the shell, making it easy to swap the UI entirely.

---

## 📂 Repository Structure

The project follows a version-controlled directory structure to ensure stability for developers:

* **`/v0.1.0/`** — Current stable release.
    * **`/source/`** — The core logic (Process management, VFS, Drivers).
    * **`/OSGadget/`** — **KRNL NANO**, the default reference OS implementation.
    * **`/documentation/`** — Technical guides and API references for this version.
* **`LICENSE`** — MIT License.

---

## 🖥️ KRNL NANO (Reference OS)

Included in the repository is **KRNL NANO**, a minimalist terminal-based operating system built on top of the KRNL engine. 

**Features included in NANO:**
* Interactive Shell with command history and scrolling.
* Theme system (load/save from VFS).
* File manipulation commands (`ls`, `cd`, `mkdir`, `cat`, `write`, `rm`).
* System monitoring (`usage`, `ram`, `tps`, `sysinfo`).

---

## 🛠️ Getting Started

1.  **Download** the latest version folder (e.g., `/v0.1.0/`).
2.  **Copy** the files to your Retro Gadgets workspace.
3.  **Include** the library in your main script:
    ```lua
    local KRNL = require("/KRNL/OS")
    -- Your OS logic starts here!
    ```

---

## 📖 Documentation

For detailed information on how to build your own OS or apps using KRNL, please refer to the documentation inside the version folders:
- [API Reference](./v0.1.0/documentation/API.md)
- [VFS Guide](./v0.1.0/documentation/VFS.md)
- [Get Started](./v0.1.0/source/Note.md)
---

## 📜 License

This project is licensed under the **MIT License**. You are free to use, modify, and distribute it, even for commercial purposes, as long as the original copyright notice is included.

---

> Created by **NOIST**

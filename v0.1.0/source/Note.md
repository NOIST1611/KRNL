
-----

# 🚀 Quick Start Guide

Welcome to the **KRNL** ecosystem. To begin using the kernel and its advanced drivers on your gadget, follow these installation steps.

-----

### 📥 Installation

To integrate the kernel into your project, you need to move the source files into the Retro Gadgets environment.

1.  **Copy Files:** Copy the entire contents of this folder (the `/KRNL` directory) into your gadget's root file directory.
2.  **Bootstrap:** In your main script (usually `CPU0`), add the following line to initialize the system:

<!-- end list -->

```lua
local KRNL = require("/KRNL/OS")

-- Your application logic starts here
```

-----

### 📂 Directory Structure

Once copied, your project should look like this:

  * `/KRNL/kernel/` — The core system logic and task manager.
  * `/KRNL/kernel/Drivers/` — Hardware abstraction layers (Video, ROM, VFS, etc.).
  * `/KRNL/kernel/Utils/` — Math3D, Codec, and Color utilities.
  * `/KRNL/OS` — The primary entry point for the API.

-----

### ⚠️ Important Notes

  * **VFS Initialization:** On the first run, KRNL will automatically format your Flash Memory and create a default directory structure (`/bin`, `/system`, `/home`).
  * **Hardware Requirements:** Ensure your gadget has the necessary components (CPU, VideoChip, etc.) connected to the motherboard for the drivers to load successfully.

-----

### 📖 Documentation Links

If you are looking for specific API references, please visit the documentation folder:

  * [VideoDriver Reference](/v0.1.0/documentation/drivers/VideoDriver.md)
  * [VFS (Virtual File System)](/v0.1.0/documentation/VFS.md)
  * [RealityChip Driver](/v0.1.0/documentation/drivers/RealityChipDriver.md)

-----

**Happy Coding\!** *KRNL Framework v0.1.0*

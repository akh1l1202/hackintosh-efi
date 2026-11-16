# Lenovo LOQ 15IRX9 - OpenCore EFI for macOS 26 Tahoe

A fully tuned, clean, and optimized OpenCore EFI configuration for the **Lenovo LOQ 15IRX9 (Type 83DV)** running **macOS 26 Tahoe (Build 25G342)** and **macOS Sequoia (15.x)**.

---

## 💻 Hardware Specifications

| Component | Specification |
| :--- | :--- |
| **Model** | Lenovo LOQ 15IRX9 (Type 83DV) |
| **Processor** | 13th Gen Intel® Core™ i5-13450HX (6 P-Cores, 4 E-Cores, 16 Threads, up to 4.60 GHz) |
| **Chipset** | Intel HM770 (Raptor Lake PCH) |
| **Memory** | 24 GB DDR5 4800 MHz (Dual Channel) |
| **Dedicated GPU** | NVIDIA GeForce RTX 4050 Laptop GPU (6 GB GDDR6) via NullMoth v2.9 (Metal 4 compute & graphics) |
| **Integrated GPU** | Intel UHD Graphics (Disabled via `disable-gpu = true` DeviceProperty) |
| **Display** | 15.6" FHD (1920x1080) IPS, 144Hz |
| **Audio Codec** | Realtek ALC257 (`DeviceProperties -> layout-id = 63000000` + `SimpleHDA.kext` for Tahoe) |
| **Ethernet** | Realtek RTL8111 Gigabit Ethernet |
| **Wi-Fi** | Intel® Wi-Fi 6 AX201 160MHz (PCIe `8086:0274`) via AirportItlwm (Tahoe build, 802.11ax HE enabled) |
| **Bluetooth** | Intel AX201 Bluetooth (USB `8087:0026`, Internal Port `HS07`) |
| **Touchpad** | ELAN06FA I2C Precision Touchpad (`PNP0C50` on `_SB.PC00.I2C0`) via VoodooI2C + modular `SSDT-TPAD.aml` |
| **Keyboard** | Lenovo White-Backlit PS/2 Keyboard with Fn Shortcuts |
| **SMBIOS** | `MacBookPro16,1` (Mobile 6P/12T power vector, 800 MHz LFM floor) |
| **Bootloader** | OpenCore 1.0.x (Debug / Release) |
| **macOS Version** | macOS 26 Tahoe (Build 25G342) / macOS Sequoia (15.x) |

---

## 📊 Status Matrix

| Feature | Status | Notes |
| :--- | :---: | :--- |
| **macOS Boot** | ✅ Working | Fast, stable boot via OpenCore (`MacBookPro16,1`) |
| **Display Output** | ✅ Working | Driven via NullMoth 2.9 (RTX 4050, Metal 4, ~74k compute score) |
| **Native Brightness** | ✅ Working | ACPI-routed via `nvrmacpibl` boot argument (no third-party apps required) |
| **Brightness Hotkeys** | ✅ Working | Fn keys handled by `BrightnessKeys.kext` + `YogaSMC.kext` |
| **Audio (Speakers/Mic)** | ✅ Working | Realtek ALC257 (`layout-id = 99`) restored in Tahoe via `SimpleHDA.kext` |
| **Battery Percentage** | ✅ Working | `ECEnabler.kext` + `SMCBatteryManager.kext` |
| **Processor Name** | ✅ Working | Correctly displays `13th Gen Intel Core i5-13450HX` in About This Mac |
| **Trackpad & Gestures** | ✅ Working | ELAN06FA I2C-HID precision multitouch via modular `SSDT-TPAD.aml` |
| **Keyboard & Backlight** | ✅ Working | `VoodooPS2Keyboard.kext` + `YogaSMC.kext` |
| **Wi-Fi** | ✅ Working | Native Wi-Fi menu via `AirportItlwm.kext` (laobamac Tahoe build, `itlwm_he=1`) |
| **Bluetooth** | ✅ Working | Intel AX201 via `BlueToolFixup` + `IntelBluetoothFirmware` + `IntelBTPatcher` + `-ibtcompatbeta` |
| **Ethernet** | ✅ Working | Realtek RTL8111 Gigabit LAN via `RealtekRTL8111.kext` |
| **Sleep / Wake** | ✅ Working | Stabilized via `acpi-wake-type = 01000000` DeviceProperty |
| **USB Ports** | ✅ Working | Full speed USB 3.x and internal ports mapped via `USBToolBox` + `UTBMap.kext` |
| **Windows Dual-Boot** | ✅ Working | Instant 1-click reboot to macOS via custom desktop utility `macOS.exe` |

---

## 🛠️ Complete Technical Fixes & Troubleshooting History

### 1. Processor Name Fix ("Unknown CPU" Resolution)
#### The Problem
macOS reported the CPU as **"2.6 GHz Unknown"** under *System Settings → General → About*, even after using CorpNewt's `CPU-Name` tool.

#### Root Cause Analysis
1. **SMBIOS Core-Count Mismatch:** The macOS kernel on this hybrid Raptor Lake CPU detects and reports **6 active cores** (`machdep.cpu.core_count: 6`). In OpenCore's `config.plist`, `PlatformInfo -> Generic -> ProcessorType` was originally configured as `3841` (`0x0F01`).
   * `0x0F01` is strictly reserved in Apple's SMBIOS tables for **8 or more cores** (Xeon / i9 / MacPro).
   * For **1, 2, 4, or 6 cores**, Apple requires `1537` (`0x0601`).
   * When macOS detected a 6-core processor declared with an 8+ core SMBIOS type ID, it flagged the table as invalid and fell back to displaying **"Unknown"**.
2. **RestrictEvents Default Behavior on Intel:** By default, `RestrictEvents.kext` disables CPU brand string patching on Intel processors (`revcpu=0`) unless forced via `revcpu=1` and `revpatch=cpuname`.

#### The Fix
* **OpenCore Generic Configuration:** Changed `PlatformInfo -> Generic -> ProcessorType` to `1537` (`0x0601`).
* **Forced RestrictEvents Patching:**
  * Added `revcpu=1` and `revpatch=cpuname,sbvmm` to boot-args.
  * Added the target CPU name string and typed values under `NVRAM -> Add -> 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102`:
    * `revcpu` = `1` (Integer)
    * `revcpuname` = `"13th Gen Intel Core i5-13450HX"` (String)
    * `revpatch` = `"cpuname,sbvmm"` (String)
* **NVRAM Reset:** Executed a one-time NVRAM reset at the OpenCore picker to purge macOS's cached CPU strings.

---

### 2. Trackpad Fix & Modular Architecture (ELAN06FA I2C Precision Touchpad)
#### The Problem
The ELAN06FA trackpad was unresponsive out of the box because Lenovo's factory DSDT:
1. Gated `_CRS` with an OS check (`OSYS < 0x07DC`) returning only a legacy APIC interrupt without any `I2cSerialBusV2` descriptor.
2. Returned `0x0000` for `_DSM` Function 1 instead of the hardware register address `0x0001` (`HID2`), causing `VoodooI2CHID` to fail descriptor retrieval.

#### Modularization (Milestone A)
Rather than maintaining a monolithic DSDT with hardcoded edits, trackpad initialization was modularized into **`SSDT-TPAD.aml`**:
1. **Dynamic Initialization (`_INI`):**
   ```asl
   Scope (\_SB.PC00.I2C0.TPAD)
   {
       Method (_INI, 0, NotSerialized)
       {
           If (_OSI ("Darwin"))
           {
               ADR0 = 0x15
               HID2 = One
           }
       }
   }
   ```
2. **400KHz High-Speed I2C Bus Descriptor (`SBFB`):**
   Supplies a dedicated `I2cSerialBusV2` descriptor configured for 400 KHz addressing (`0x00061A80`) to eliminate cursor lag.
3. **OS-Filtered `_CRS`:**
   Renamed stock `_CRS` to `XCRS` in ACPI, with `SSDT-TPAD` routing:
   ```asl
   Method (_CRS, 0, Serialized)
   {
       If (_OSI ("Darwin"))
       {
           Return (ConcatenateResTemplate (SBFB, SBFG))
       }
       Return (XCRS ())
   }
   ```
4. **Full Functionality Verified:** Cursor movement, tap-to-click, physical clicks, smooth two-finger scrolling, and native macOS multitouch gestures work seamlessly.

#### Architectural Finding: Why `DSDT-Lenovo-RHUB.aml` is Mandatory
* We tested booting without custom DSDT tables (Milestone B). The system immediately kernel-panicked with `AE_NOT_FOUND` in `AppleACPIPlatform`.
* **Root Cause:** In Lenovo's OEM firmware, `Scope (_SB.PC00.XHCI.RHUB)` is nested inside conditional blocks `If (CondRefOf (PU2C))` and `If (CondRefOf (PU3C))`. Apple's ACPICA parser does not support module-level conditional scopes during Pass 1 symbol registration.
* **Resolution:** `DSDT-Lenovo-RHUB.aml` (659 KB) is kept as a dedicated table specifically to un-nest RHUB. OpenCore replaces the OEM DSDT with zero patch overhead.

---

### 3. Display, Graphics & Native Brightness
#### Display Pipeline & NullMoth Driver
* **NullMoth Driver Version:** **`2.9`**, specifically built for macOS 26 Tahoe and macOS 15 Sequoia.
* **Graphics & Compute APIs:** Full hardware acceleration with **Metal 4** compute and rendering support via Mesa NVK / Vulkan backend (~74,000 Metal Geekbench compute score).
* **Kernel Components (Installed in System Extensions):**
  * `com.nullmoth.NVRMFB` – NVRM Framebuffer driver
  * `com.nullmoth.NVRMAGDC` – Apple Graphics Device Control hook
  * `com.nullmoth.NVRM` – NVIDIA Resource Manager core kernel interface
  * `com.nullmoth.NVAccel` – Hardware 2D/3D acceleration backend
* **OpenCore Integration:**
  * `NullMothSafe.efi` (in `EFI/OC/Tools/`): Recovery / safe-mode fallback tool.
* **iGPU Disabled:** `disable-gpu = true` injected under `DeviceProperties -> PciRoot(0x0)/Pci(0x2,0x0)` to completely disable the Intel UHD iGPU and prevent display routing conflicts.
* **PCIe Wake Fix:** `acpi-wake-type = 01000000` injected under `PciRoot(0x0)/Pci(0x1,0x0)/Pci(0x0,0x0)` to fix sleep/wake on the dedicated GPU.

#### Native Brightness Without Third-Party Apps
* Added **`nvrmacpibl`** to OpenCore boot arguments. This instructs NullMoth's framebuffer driver (`NVRMFB`) to route backlight control through standard ACPI brightness methods rather than relying on unsupported NVKMS display channels.
* Works directly with the native macOS brightness slider in Control Center without needing MonitorControl.
* Integrated `BrightnessKeys.kext` and `YogaSMC.kext` to translate Lenovo Fn brightness key presses into native macOS display brightness events.

---

### 4. Audio (Realtek ALC257 & macOS Tahoe Restoration)
* **Realtek ALC257:** Codec path `PciRoot(0x0)/Pci(0x1f,0x3)` injected with `layout-id = 63000000` (Layout 99).
* **Single Source of Truth:** Redundant `alcid=99` boot argument removed in favor of explicit `DeviceProperties` injection.
* **macOS 26 Tahoe Support via `SimpleHDA.kext` (v1.0.1):**
  * In macOS 26 Tahoe, Apple completely removed legacy `AppleHDA.kext` from `/System/Library/Extensions/`.
  * `SimpleHDA.kext` (by laobamac) is injected right after `AppleALC.kext` as a Lilu child plugin. It restores the native AppleHDA architecture on Tahoe, enabling layout-id 99 to drive built-in stereo speakers, the 3.5mm combo headphone/mic jack, and internal microphones seamlessly.

---

### 5. Battery Status & Power Management
* **`ECEnabler.kext` (v1.0.6):** Enabled directly after `VirtualSMC.kext` to allow macOS to read Embedded Controller (EC) fields larger than 8 bits without complex manual DSDT register splitting.
* **`SMCBatteryManager.kext`:** Exposes battery charge state, percentage, wattage, and cycle health to the macOS menu bar.
* **`CPUFriend.kext` + `CPUFriendDataProvider.kext`:** Injects a customized frequency vector matched to `MacBookPro16,1` with an 800 MHz Low Frequency Mode (LFM) floor for smooth thermal behavior.

---

### 6. Wi-Fi & Bluetooth (Intel AX201)
#### Wi-Fi
* Driven by `AirportItlwm.kext` (laobamac v2.4.0-alpha for macOS 26 Tahoe).
* Injected with `itlwm_he=1` in `boot-args` for full 802.11ax (Wi-Fi 6) high-efficiency throughput.
* Provides native Apple Wi-Fi status bar menu integration, automatic reconnection, and WPA2/WPA3 support without requiring helper applications like HeliPort.

#### Bluetooth
* **Hardware:** Intel AX201 Bluetooth controller on the internal USB bus (`Vendor: 0x8087`, `Product: 0x0026`).
* **Port Mapping:** USB port `HS07` is mapped as **Internal (`UsbConnector = 255`)** in `UTBMap.kext`.
* **Boot Argument:** `-ibtcompatbeta` injected to ensure stable Tahoe subsystem initialization.
* **Strict Driver Loading Order:**
  1. `BlueToolFixup.kext` (v2.7.3) – Patches `bluetoothd` on macOS Monterey and newer (must load **first**).
  2. `IntelBluetoothFirmware.kext` (v2.5.0) – Injects the required firmware into the controller.
  3. `IntelBTPatcher.kext` (v2.5.0) – Applies kernel-level Bluetooth subsystem patches.

---

### 7. SPI Flash Wear Optimization (NVRAM Cleanup)
* **Flash Erase/Write Elimination:** `NVRAM -> Delete` was completely emptied (`{}`).
* **Why this matters:** On every boot, OpenCore iterates through all keys in `NVRAM -> Delete` and performs hardware block erases and rewrites on the laptop's SPI flash chip. Emptying this block prevents physical chip degradation and shortens boot time.
* **`ForceOcWriteFlash`:** Set to `false` in `UEFI -> Quirks` to prevent unnecessary forced NVRAM commits.

---

### 8. Complete Boot Arguments Reference

The active `boot-args` in `config.plist` are:
```text
-v debug=0x100 keepsyms=1 nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth amfi_get_out_of_my_way=0x1 amfi=0x80 ps2rst=0 ipc_control_port_options=0 nvrmacpibl revcpu=1 revpatch=cpuname,sbvmm gfxrst=4 itlwm_he=1 -ibtcompatbeta
```

| Argument | Purpose |
| :--- | :--- |
| `-v debug=0x100 keepsyms=1` | Verbose boot mode and kernel panic debugging |
| `nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth` | NullMoth NVRMFB display engine configuration for NVIDIA RTX 4050 |
| `nvrmacpibl` | Routes display backlight brightness through ACPI instead of NVKMS |
| `amfi_get_out_of_my_way=0x1 amfi=0x80` | AMFI compatibility flags for NullMoth v2.9 driver signing on macOS Tahoe |
| `ipc_control_port_options=0` | IPC control port compatibility flag |
| `ps2rst=0` | Prevents PS/2 keyboard controller reset loops during boot |
| `revcpu=1 revpatch=cpuname,sbvmm` | RestrictEvents: Forces CPU brand string patch (`cpuname`) and VMM OTA update spoof (`sbvmm`) |
| `gfxrst=4` | WhateverGreen display engine reset policy |
| `itlwm_he=1` | Enables 802.11ax High Efficiency (Wi-Fi 6) mode on AirportItlwm |
| `-ibtcompatbeta` | Enables Intel Bluetooth compatibility mode on macOS 26 Tahoe |

---

### 9. DeviceProperties Configuration

| PCI Path | Key | Value | Purpose |
| :--- | :--- | :--- | :--- |
| `PciRoot(0x0)/Pci(0x1,0x0)/Pci(0x0,0x0)` | `acpi-wake-type` | `01000000` (Data) | Fixes deep sleep/wake issues on PCIe dGPU |
| `PciRoot(0x0)/Pci(0x1f,0x3)` | `layout-id` | `63000000` (Data) | Realtek ALC257 layout-id 99 (single source of truth) |
| `PciRoot(0x0)/Pci(0x2,0x0)` | `disable-gpu` | `True` (Boolean) | Disables Intel UHD iGPU to prevent framebuffer clashes |

---

### 10. Cleaned EFI & Source Structure

```text
hackintosh-efi/
├── ACPI_Sources/               # Human-readable DSL sources for all active tables
│   ├── DSDT-Lenovo-RHUB.dsl    # RHUB un-nesting source
│   ├── SSDT-EC.dsl             # Embedded Controller dummy device
│   ├── SSDT-MCHC.dsl           # Memory controller hub fix
│   ├── SSDT-PLUG-ALT.dsl       # Dynamic power management definition
│   ├── SSDT-RTCAWAC.dsl        # Real Time Clock enabler
│   ├── SSDT-SBUS.dsl           # System Management Bus fix
│   ├── SSDT-TPAD.dsl           # Modular trackpad source (ADR0, HID2, SBFB, _CRS)
│   └── SSDT-USBX.dsl           # USB power properties
├── EFI/
│   ├── BOOT/
│   │   └── BOOTx64.efi
│   └── OC/
│       ├── ACPI/
│       │   ├── DSDT-Lenovo-RHUB.aml  # Essential RHUB ACPICA un-nesting
│       │   ├── SSDT-EC.aml
│       │   ├── SSDT-MCHC.aml
│       │   ├── SSDT-PLUG-ALT.aml
│       │   ├── SSDT-RTCAWAC.aml
│       │   ├── SSDT-SBUS.aml
│       │   ├── SSDT-TPAD.aml         # Standalone trackpad table
│       │   └── SSDT-USBX.aml
│       ├── Drivers/
│       │   ├── HfsPlus.efi
│       │   ├── OpenRuntime.efi
│       │   └── ResetNvramEntry.efi
│       ├── Kexts/
│       │   ├── AirportItlwm.kext
│       │   ├── AMFIPass.kext
│       │   ├── AppleALC.kext
│       │   ├── BlueToolFixup.kext
│       │   ├── BrightnessKeys.kext
│       │   ├── CPUFriend.kext
│       │   ├── CPUFriendDataProvider.kext
│       │   ├── CpuTscSync.kext
│       │   ├── ECEnabler.kext
│       │   ├── IntelBluetoothFirmware.kext
│       │   ├── IntelBTPatcher.kext
│       │   ├── Lilu.kext
│       │   ├── RealtekRTL8111.kext
│       │   ├── RestrictEvents.kext
│       │   ├── SimpleHDA.kext
│       │   ├── SMCBatteryManager.kext
│       │   ├── USBToolBox.kext
│       │   ├── UTBMap.kext
│       │   ├── VirtualSMC.kext
│       │   ├── VoodooI2C.kext
│       │   ├── VoodooI2CHID.kext
│       │   ├── VoodooPS2Controller.kext
│       │   ├── WhateverGreen.kext
│       │   ├── XHCI-unsupported.kext
│       │   └── YogaSMC.kext
│       ├── OpenCore.efi
│       └── config.plist
└── EFI_ISSUES_TRACKER.md       # Comprehensive step-by-step issue & optimization tracker
```

---

### 11. 🚀 Native Windows Dual-Boot Utility (`macOS.exe`)

To make dual-booting instantaneous and friction-free from Windows, a standalone C# application (`macOS.exe`) is placed directly on the Desktop:
* **Custom App Icon:** Compiled with an embedded high-resolution macOS wallpaper wave icon.
* **Instant Reboot:** Sets the next UEFI boot target to OpenCore and reboots immediately with 0 delay.
* **Zero UAC Prompts:** Utilizes a secure, pre-registered Windows Task Scheduler elevation bridge (`SwitchToMacOS`) so double-clicking `macOS.exe` executes immediately with no User Account Control interruptions.

---

## ⚙️ Recommended BIOS Settings

* **Disable:**
  * Secure Boot
  * Fast Boot
  * Intel VMD / RAID (Set storage controller to AHCI)
  * Intel SGX
  * CFG Lock (if accessible)
* **Enable:**
  * UEFI Boot Mode
  * VT-x / Virtualization Technology
  * Above 4G Decoding

---

## 👏 Credits & Acknowledgments
* [NullMoth](https://github.com/nullmoth) for the NullMoth driver suite (`com.nullmoth.NVRM`, `NVRMFB`, `NVAccel`, `NVRMAGDC`), enabling hardware acceleration, Metal 4 compute, and display driving on modern NVIDIA RTX GPUs in macOS.
* [Acidanthera](https://github.com/acidanthera) for OpenCore, Lilu, VirtualSMC, AppleALC, RestrictEvents, WhateverGreen, and BrcmPatchRAM (`BlueToolFixup`).
* [laobamac](https://github.com/laobamac) for `SimpleHDA` (restoring native AppleHDA audio on macOS Tahoe) and Tahoe `AirportItlwm` builds.
* [OpenIntelWireless](https://github.com/OpenIntelWireless) for `AirportItlwm` and `IntelBluetoothFirmware`.
* [Alexandre Da Silva](https://github.com/VoodooI2C) and the VoodooI2C team for `VoodooI2C` and `VoodooI2CHID`.
* [1Revenger1](https://github.com/1Revenger1) for `ECEnabler`.
* [Zhen-Hoong](https://github.com/Zhen-Hoong) for `YogaSMC`.
* [DhinakG](https://github.com/dhinakg) for `USBToolBox`.

# Lenovo LOQ 15IRX9 - OpenCore EFI for macOS Sequoia

A fully tuned, clean, and optimized OpenCore EFI configuration for the **Lenovo LOQ 15IRX9 (Type 83DV)** running **macOS Sequoia (15.x)**.

---

## 💻 Hardware Specifications

| Component | Specification |
| :--- | :--- |
| **Model** | Lenovo LOQ 15IRX9 (Type 83DV) |
| **Processor** | 13th Gen Intel® Core™ i5-13450HX (6 P-Cores, 4 E-Cores, 16 Threads, up to 4.60 GHz) |
| **Chipset** | Intel HM770 (Raptor Lake PCH) |
| **Memory** | 24 GB DDR5 4800 MHz (Dual Channel) |
| **Dedicated GPU** | NVIDIA GeForce RTX 4050 Laptop GPU (6 GB GDDR6) via NullMoth v1.14.2 (NVRMFB) |
| **Integrated GPU** | Intel UHD Graphics (Disabled via `disable-gpu = true` DeviceProperty) |
| **Display** | 15.6" FHD (1920x1080) IPS, 144Hz |
| **Audio Codec** | Realtek ALC257 (AppleALC Layout ID: `99`) |
| **Ethernet** | Realtek RTL8111 Gigabit Ethernet |
| **Wi-Fi** | Intel® Wi-Fi 6 AX201 160MHz (PCIe `8086:0274`) |
| **Bluetooth** | Intel AX201 Bluetooth (USB `8087:0026`, Internal Port `HS07`) |
| **Touchpad** | ELAN06FA I2C Precision Touchpad (`PNP0C50` / `MSFT0001` on `_SB.PC00.I2C0`, Address `0x15`) |
| **Keyboard** | Lenovo White-Backlit PS/2 Keyboard with Fn Shortcuts |
| **Bootloader** | OpenCore 1.0.x |
| **macOS Version** | macOS Sequoia 15.8.1 |

---

## 📊 Status Matrix

| Feature | Status | Notes |
| :--- | :---: | :--- |
| **macOS Boot** | ✅ Working | Fast, stable boot via OpenCore |
| **Display Output** | ✅ Working | Driven via NullMoth framebuffer (RTX 4050) |
| **Native Brightness** | ✅ Working | ACPI-routed via `nvrmacpibl` boot argument (no MonitorControl app needed) |
| **Brightness Hotkeys** | ✅ Working | Fn keys handled by `BrightnessKeys.kext` + `YogaSMC.kext` |
| **Audio (Speakers/Mic)** | ✅ Working | Realtek ALC257 with AppleALC layout-id `99` (`alcid=99`) |
| **Battery Percentage** | ✅ Working | `ECEnabler.kext` + `SMCBatteryManager.kext` |
| **Processor Name** | ✅ Working | Correctly displays `13th Gen Intel Core i5-13450HX` in About This Mac |
| **Trackpad & Gestures** | ✅ Working | ELAN06FA I2C-HID precision multitouch via patched `DSDT.aml` + forced polling |
| **Keyboard & Backlight** | ✅ Working | `VoodooPS2Keyboard.kext` + `YogaSMC.kext` |
| **Wi-Fi** | ✅ Working | Native macOS status bar menu via `AirportItlwm.kext` |
| **Bluetooth** | ✅ Working | Intel AX201 via `BlueToolFixup` + `IntelBluetoothFirmware` + `IntelBTPatcher` |
| **Ethernet** | ✅ Working | Realtek RTL8111 Gigabit LAN via `RealtekRTL8111.kext` |
| **Sleep / Wake** | ✅ Working | Stabilized via `acpi-wake-type = 1` DeviceProperty |
| **USB Ports** | ✅ Working | Full speed USB 3.x and internal ports mapped via `USBToolBox` + `UTBDefault` |

---

## 🛠️ Complete Technical Fixes & Troubleshooting History

### 1. Processor Name Fix ("Unknown CPU" Resolution)
#### The Problem
macOS reported the CPU as **"2.6 GHz Unknown"** under *System Settings → General → About*, even after using CorpNewt's `CPU-Name` tool.

#### Root Cause Analysis
1. **SMBIOS Core-Count Mismatch:** The macOS kernel on this hybrid Raptor Lake CPU detects and reports **6 active cores** (`machdep.cpu.core_count: 6`). In OpenCore's `config.plist`, `PlatformInfo -> Generic -> ProcessorType` was configured as `3841` (`0x0F01`).
   * `0x0F01` is strictly reserved in Apple's SMBIOS tables for **8 or more cores** (Xeon / i9 / MacPro).
   * For **1, 2, 4, or 6 cores**, Apple requires `1537` (`0x0601`).
   * When macOS detected a 6-core processor declared with an 8+ core SMBIOS type ID, it flagged the table as invalid and fell back to displaying **"Unknown"**.
2. **RestrictEvents Default Behavior on Intel:** By default, `RestrictEvents.kext` disables CPU brand string patching on Intel processors (`revcpu=0`) unless forced via `revcpu=1` and `revpatch=cpuname`.

#### The Fix
* **OpenCore Generic Configuration:** Changed `PlatformInfo -> Generic -> ProcessorType` to `1537` (`0x0601`).
* **Forced RestrictEvents Patching:**
  * Added `revcpu=1` and `revpatch=cpuname` to boot-args.
  * Added the target CPU name string and typed values under `NVRAM -> Add -> 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102`:
    * `revcpu` = `1` (Integer)
    * `revcpuname` = `"13th Gen Intel Core i5-13450HX"` (String)
    * `revpatch` = `"cpuname"` (String)
  * Added `revcpu`, `revcpuname`, and `revpatch` to `NVRAM -> Delete -> 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102` so OpenCore reapplies clean values on every boot.
* **NVRAM Reset:** Executed a one-time NVRAM reset at the OpenCore picker to purge macOS's cached CPU strings.

---

### 2. Trackpad Fix (ELAN06FA I2C Precision Touchpad)
#### The Problem
The trackpad was completely unresponsive. Although the controller loaded, the device nub under ACPI (`_SB.PC00.I2C0.TPAD`) was marked `!registered, !matched`, and `VoodooI2CHID.kext` refused to attach.

#### Root Causes & Multi-Step Fixes
1. **DSDT OS-Version Gate (`_CRS`):**
   In Lenovo's factory `DSDT.aml`, `TPAD._CRS` had:
   ```asl
   If ((OSYS < 0x07DC))
   {
       Return (SBFI) // APIC legacy interrupt only — NO I2C connection!
   }
   ```
   Because macOS does not initialize Windows BIOS variables, `OSYS` remained at `0x03E8` (`< 0x07DC`). Consequently, `_CRS` returned **only** a legacy APIC interrupt without any `I2cSerialBusV2` descriptor. `VoodooI2C` logged: `"Could not find an I2C Serial Bus declaration"` and refused to publish the device nub.
2. **Missing HID Descriptor Register Address (`_DSM` Function 1):**
   Under Microsoft's *HID over I2C Protocol Specification*, the driver queries ACPI `_DSM` (Function 1) to retrieve the 16-bit register address of the HID descriptor (`wHIDDescRegister`):
   ```asl
   Name (HID2, Zero)
   ...
   Method (_DSM, 4, NotSerialized)
   {
       ...
       If ((Arg2 == One))
       {
           Return (HID2) // Returns the HID descriptor register address
       }
   }
   ```
   In Lenovo's original DSDT, `HID2` was dynamically assigned inside an OSYS-gated loop that was bypassed. Because `HID2` defaulted to `Zero`, `_DSM` returned `0x0000`. `VoodooI2CHID` read register `0x0000` over the I2C bus instead of register `0x0001` (the hardware descriptor register for `ELAN06FA`), failed with `Request for HID descriptor failed`, and detached.
3. **Kext Info.plist Patches:**
   * **`VoodooI2C.kext`:** Injected PCI ID `0x7a4c8086` into `VoodooI2CControllerDriver` personalities so the driver binds to Intel Raptor Lake LP I2C controllers (`8086:7a4c`).
   * **`VoodooGPIO.kext`:** Fixed a crash caused by a missing class (`VoodooGPIOTigerLakeLP`). Removed that broken personality and routed the LOQ's ACPI HID `INTC1085` to `VoodooGPIOIceLakeLP`.
4. **SSDT-XOSI Recursion Fix:**
   The original `SSDT-XOSI.dsl` had an infinite recursion bug where calling `_OSI` invoked `XOSI`, which called `_OSI` again, causing ACPI interpreter hangs. It was replaced with the clean Dortania `SSDT-XOSI.aml`.
5. **Applied ACPI Patches in `DSDT.aml`:**
   * **Declared `SBFB`:**
     ```asl
     Name (SBFB, ResourceTemplate ()
     {
         I2cSerialBusV2 (0x0015, ControllerInitiated, 0x00061A80,
             AddressingMode7Bit, "\\_SB.PC00.I2C0",
             0x00, ResourceConsumer, , Exclusive,
             )
     })
     ```
   * **Simplified `_CRS`:**
     ```asl
     Method (_CRS, 0, Serialized)
     {
         Return (ConcatenateResTemplate (SBFB, SBFG))
     }
     ```
   * **Assigned Hardware Register Addresses:**
     ```asl
     Name (ADR0, 0x15)
     Name (HID2, One)  // 0x0001 = ELAN06FA HID Descriptor Register
     ```
6. **Forced Polling Mode for 13th Gen:**
   Intel 13th Gen Raptor Lake PCH GPIO interrupt lines cannot be routed stably by macOS. Added `-vi2c-force-polling` to boot-args and `force-polling = <01 00 00 00>` to `DeviceProperties -> PciRoot(0x0)/Pci(0x15,0x0)`.
7. **Secondary Click (Right-Click) Configuration:**
   In macOS, Precision Trackpad gestures are managed in **System Settings → Trackpad**. By default, macOS sets **Secondary Click** to **"Click or tap with two fingers"**. To use physical corner clicks, change Secondary Click to **"Click in bottom right corner"**.

---

### 3. Display, Graphics & Native Brightness
#### Display Pipeline & NullMoth Driver
* **NullMoth Driver Version:** **`1.14.2`** (`nullmoth-nvidia-1.14.2.tar.gz` / `1401-Mac-1.14.2`), specifically built for macOS 15 Sequoia.
* **Kernel Components (Installed in System Extensions):**
  * `com.nullmoth.NVRMFB` (0.1) – NVRM Framebuffer driver
  * `com.nullmoth.NVRMAGDC` (0.1) – Apple Graphics Device Control hook
  * `com.nullmoth.NVRM` (0.1) – NVIDIA Resource Manager core kernel interface
  * `com.nullmoth.NVAccel` (0.1) – Hardware 2D/3D acceleration backend
* **OpenCore Integration:**
  * `NullMothLogo.efi` (in `EFI/OC/Drivers/`): Injects the companion custom boot logo during OpenCore boot.
  * `NullMothSafe.efi` (in `EFI/OC/Tools/`): Recovery / safe-mode fallback tool.
* **iGPU Disabled:** `disable-gpu = true` injected under `DeviceProperties -> PciRoot(0x0)/Pci(0x2,0x0)` to completely disable the Intel UHD iGPU and prevent display routing conflicts.
* **PCIe Wake Fix:** `acpi-wake-type = 1` injected under `PciRoot(0x0)/Pci(0x1,0x0)/Pci(0x0,0x0)` to fix sleep/wake on the dedicated GPU.

#### Native Brightness Without Third-Party Apps
* Added **`nvrmacpibl`** to OpenCore boot arguments. This instructs NullMoth's framebuffer driver (`NVRMFB`) to route backlight control through standard ACPI brightness methods rather than relying on unsupported NVKMS display channels.
* Works directly with the native macOS brightness slider in Control Center without needing MonitorControl.
* Integrated `BrightnessKeys.kext` and `YogaSMC.kext` to translate Lenovo Fn brightness key presses into native macOS display brightness events.

---

### 4. Audio (Realtek ALC257)
* Integrated `AppleALC.kext`.
* Injected layout-id `99` (`0x63`) via:
  * Boot argument: `alcid=99`
  * DeviceProperties: `PciRoot(0x0)/Pci(0x1f,0x3)` with `layout-id` = `<63 00 00 00>`.
* Fully enables built-in speakers, headphone output jack, and internal microphone.

---

### 5. Battery Status
* **`ECEnabler.kext` (v1.0.6):** Enabled directly after `VirtualSMC.kext` to allow macOS to read Embedded Controller (EC) fields larger than 8 bits without complex manual DSDT register splitting.
* **`SMCBatteryManager.kext`:** Exposes battery charge state, percentage, wattage, and cycle health to the macOS menu bar.

---

### 6. Wi-Fi & Bluetooth (Intel AX201)
#### Wi-Fi
* Driven by `AirportItlwm.kext` (v2.4.0 for macOS Sequoia).
* Provides native Apple Wi-Fi status bar menu integration, automatic reconnection, and WPA2/WPA3 support without requiring helper applications like HeliPort.

#### Bluetooth
* **Hardware:** Intel AX201 Bluetooth controller on the internal USB bus (`Vendor: 0x8087`, `Product: 0x0026`).
* **Port Mapping:** USB port `HS07` is mapped as **Internal (`UsbConnector = 255`)** in `UTBDefault.kext` / `USBToolBox.kext`.
* **Strict Driver Loading Order:**
  1. `BlueToolFixup.kext` (v2.7.3) – Patches `bluetoothd` on macOS Monterey and newer (must load **first**).
  2. `IntelBluetoothFirmware.kext` (v2.5.0) – Injects the required firmware into the controller.
  3. `IntelBTPatcher.kext` (v2.5.0) – Applies kernel-level Bluetooth subsystem patches.

---

### 7. Complete Boot Arguments Reference

The active `boot-args` in `config.plist` are:
```text
-v debug=0x100 keepsyms=1 nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth amfi_get_out_of_my_way=0x1 amfi=0x80 ps2rst=0 ipc_control_port_options=0 nvrmacpibl -vi2c-force-polling alcid=99 revcpu=1 revpatch=cpuname
```

| Argument | Purpose |
| :--- | :--- |
| `-v debug=0x100 keepsyms=1` | Verbose boot mode and kernel panic debugging |
| `nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth` | NullMoth NVRMFB display engine configuration for NVIDIA RTX 4050 |
| `nvrmacpibl` | Routes display backlight brightness through ACPI instead of NVKMS |
| `amfi_get_out_of_my_way=0x1 amfi=0x80` | AMFI compatibility flags for macOS Sequoia driver signing |
| `ipc_control_port_options=0` | IPC control port compatibility flag |
| `ps2rst=0` | Prevents PS/2 keyboard controller reset loops during boot |
| `-vi2c-force-polling` | Forces VoodooI2C into timer polling mode for 13th Gen Raptor Lake |
| `alcid=99` | AppleALC audio layout ID for Realtek ALC257 |
| `revcpu=1 revpatch=cpuname` | Instructs RestrictEvents to force Intel CPU brand string patching |

---

### 8. DeviceProperties Configuration

| PCI Path | Key | Value | Purpose |
| :--- | :--- | :--- | :--- |
| `PciRoot(0x0)/Pci(0x1,0x0)/Pci(0x0,0x0)` | `acpi-wake-type` | `01000000` (Number) | Fixes deep sleep/wake issues on PCIe dGPU |
| `PciRoot(0x0)/Pci(0x15,0x0)` | `force-polling` | `01000000` (Data) | Enables polling on Intel I2C0 controller |
| `PciRoot(0x0)/Pci(0x1f,0x3)` | `layout-id` | `63000000` (Data) | Realtek ALC257 layout-id 99 |
| `PciRoot(0x0)/Pci(0x2,0x0)` | `disable-gpu` | `True` (Boolean) | Disables Intel UHD iGPU to prevent framebuffer clashes |

---

### 9. Cleaned EFI Structure

All obsolete files have been purged:
* **Removed redundant/disabled kexts:** `itlwm.kext` (15 MB duplicate), `CpuTopologyRebuild.kext`, `NVMeFix.kext`, `SMCLightSensor.kext`, `SMCProcessor.kext`, `SMCSuperIO.kext`, `UTBMap.kext`.
* **Removed unused ACPI tables:** `SSDT-PNLF.aml`, `SSDT-RTC0.aml`, all 12 `.dsl` source files, and `DSDT.aml.bak`.
* **Removed orphaned ACPI patches:** Cleaned out 3 disabled/unnamed binary patches from `config.plist`.
* **Removed legacy configs:** Removed 10 outdated backup plist files from the `OC` root directory.

```text
EFI/
├── BOOT/
│   └── BOOTx64.efi
└── OC/
    ├── ACPI/
    │   ├── DSDT.aml           # Patched: ELAN06FA I2C descriptor & HID2 register address
    │   ├── SSDT-EC.aml         # Embedded Controller dummy device
    │   ├── SSDT-GPI0.aml       # Exposes GPI0 controller status
    │   ├── SSDT-MCHC.aml       # Memory controller hub fix
    │   ├── SSDT-PLUG-ALT.aml   # CPU power management for Alder/Raptor Lake
    │   ├── SSDT-RTCAWAC.aml    # Disables AWAC, enables RTC
    │   ├── SSDT-SBUS.aml       # System Management Bus fix
    │   ├── SSDT-USB-Reset.aml  # Resets USB RHUB for port injection
    │   ├── SSDT-USBX.aml       # USB power properties
    │   └── SSDT-XOSI.aml       # Windows 11 ACPI OS identification
    ├── Drivers/
    │   ├── HfsPlus.efi
    │   ├── NullMothLogo.efi
    │   ├── OpenRuntime.efi
    │   └── ResetNvramEntry.efi
    ├── Kexts/
    │   ├── AMFIPass.kext
    │   ├── AirportItlwm.kext
    │   ├── AppleALC.kext
    │   ├── BlueToolFixup.kext
    │   ├── BrightnessKeys.kext
    │   ├── CpuTscSync.kext
    │   ├── ECEnabler.kext
    │   ├── IntelBTPatcher.kext
    │   ├── IntelBluetoothFirmware.kext
    │   ├── Lilu.kext
    │   ├── RealtekRTL8111.kext
    │   ├── RestrictEvents.kext
    │   ├── SMCBatteryManager.kext
    │   ├── USBToolBox.kext
    │   ├── UTBDefault.kext
    │   ├── VirtualSMC.kext
    │   ├── VoodooI2C.kext
    │   ├── VoodooI2CHID.kext
    │   ├── VoodooPS2Controller.kext
    │   ├── WhateverGreen.kext
    │   ├── XHCI-unsupported.kext
    │   └── YogaSMC.kext
    ├── OpenCore.efi
    └── config.plist
```

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
* [Acidanthera](https://github.com/acidanthera) for OpenCore, Lilu, VirtualSMC, AppleALC, RestrictEvents, WhateverGreen, and BrcmPatchRAM (`BlueToolFixup`).
* [OpenIntelWireless](https://github.com/OpenIntelWireless) for `AirportItlwm` and `IntelBluetoothFirmware`.
* [Alexandre Da Silva](https://github.com/VoodooI2C) and the VoodooI2C team for `VoodooI2C` and `VoodooI2CHID`.
* [1Revenger1](https://github.com/1Revenger1) for `ECEnabler`.
* [Zhen-Hoong](https://github.com/Zhen-Hoong) for `YogaSMC`.
* [DhinakG](https://github.com/dhinakg) for `USBToolBox`.
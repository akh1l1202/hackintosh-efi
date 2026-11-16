# OpenCore EFI Issues & Optimization Tracker
**Target Hardware:** Lenovo LOQ 15IRX9 (Type 83DV)  
**Target OS:** macOS 26 Tahoe (Build 25G342) / macOS Sequoia (15.x)  
**Active Baseline:** `MacBookPro16,1` (6P / 12T baseline, Atom E-cores disabled)  
**Last Updated:** 2026-11-13  

---

## 🚦 Status Legend
* ✅ **RESOLVED:** Verified, tested, and resolved on active EFI.
* ⏳ **PENDING TEST:** Documented issue ready to be tested one-by-one.
* ℹ️ **INFORMATIONAL / HARMLESS:** Non-critical redundancy or harmless quirk.

---

## 1. OEM ACPI Drops (`ACPI -> Delete`)

*Status: ✅ RESOLVED (Correctly configured)*

Your `config.plist` safely drops two broken tables from Lenovo's OEM firmware ACPI:

1. **`SSDT.aml` (908 bytes, Table ID `CB-01   `):**
   * **Definition:** Defines `Device (PMAX)` with invalid references to non-existent variables (`PXDC`).
   * **Verdict:** ✅ **Correctly Dropped** — Prevents the 0.08s early ACPI boot freeze.
2. **`SSDT16.aml` (92 bytes, Table ID `CB-01   `):**
   * **Definition:** Legacy SATA table that references `\_SB.PCI0` (which does not exist on 13th/14th Gen Raptor Lake platforms; Raptor Lake uses `\_SB.PC00`).
   * **Verdict:** ✅ **Correctly Dropped** — Prevents early ACPI namespace lookup panic (`AE_NOT_FOUND`).

---

## 2. ACPI Tables & Overrides (`ACPI -> Add`)

### 2.1 SSDT-GPI0.aml vs DSDT.aml Collision
* **Status:** ✅ **RESOLVED**
* **Issue:** `SSDT-GPI0.aml` defined `Method (\_SB.GPI0._STA)` without a rename patch, colliding with `Device (GPI0) { Method (_STA) }` in `DSDT.aml` (`AE_ALREADY_EXISTS`).
* **Root Cause & Fix:** In `DSDT.aml`, `GPI0._STA` already returns `0x0F` (enabled) natively because `GPHD == 0`. Per Dortania guide rules, `SSDT-GPI0` is unneeded. It was already completely removed from the active baseline config in commit `7f5b0dc`.

### 2.2 SSDT-USB-Reset.aml (Redundant Discovery Tool)
* **Status:** ✅ **RESOLVED**
* **Issue:** `SSDT-USB-Reset.aml` forces `\_SB.PC00.XHCI.RHUB._STA = 0` under macOS. It is only meant as a temporary port-discovery aid for USBToolBox. Leaving it permanently active on a laptop risks breaking ACPI power methods (`_PS0`, `_PS3`), Type-C orientation/hotplug notifications, and sleep/wake power states.
* **Resolution:** Set to `Enabled: false` and tested in macOS. Verified that all USB 3.0, USB 2.0, Type-C, webcam, and internal Bluetooth (`HS07`) ports operate normally via `UTBMap.kext`. Entry removed from `config.plist` and file deleted from `E:\EFI\OC\ACPI\`.

### 2.3 Milestone A: Trackpad Modularization (SSDT-TPAD.aml)
* **Status:** ✅ **RESOLVED**
* **Issue:** The original `DSDT.aml` hardcoded I2C trackpad registers (`ADR0 = 0x15`, `HID2 = 1`, static `SBFB`, and modified `_CRS`). If Lenovo releases a BIOS update in the future, these hardcoded overrides inside a static DSDT would either need manual re-patching or cause instability.
* **Resolution:** 
  1. Restored `Device (TPAD)` in `DSDT.aml` to stock OEM structure, with `_CRS` renamed natively to `XCRS` inside `DSDT.aml` (checksum verified).
  2. Created standalone, modular `SSDT-TPAD.aml` (320 bytes) that dynamically sets `ADR0 = 0x15` and `HID2 = One` via `_INI` under `_OSI ("Darwin")` and supplies `ConcatenateResTemplate (SBFB, SBFG)` in `_CRS`.
  3. Verified working in macOS: full cursor movement, physical/tap clicks, two-finger scroll, and native precision gestures functional.

### 2.4 Milestone B: Complete Elimination of DSDT.aml (Feasibility Tested)
* **Status:** 🛑 **REVERTED (DSDT.aml IS REQUIRED)**
* **Finding:** When `DSDT.aml` is disabled, the system attempts to boot using Lenovo's factory OEM DSDT. AppleACPIPlatform immediately halts with `AE_NOT_FOUND` during ACPI table load.
* **Root Cause:** In the OEM DSDT, Lenovo wraps the root USB hub (`Scope (_SB.PC00.XHCI.RHUB)`) inside module-level `If (CondRefOf (PU2C))` and `If (CondRefOf (PU3C))` blocks. Apple's ACPICA parser does not support module-level conditional scopes at table load time, causing `RHUB` and child USB device paths to fail namespace lookup (`AE_NOT_FOUND`).
* **Conclusion:** `DSDT.aml` is strictly mandatory for Lenovo LOQ 15IRX9 to fix the OEM RHUB ACPICA crash. Milestone A (modular `SSDT-TPAD.aml` for trackpad + cleaned `DSDT.aml` for RHUB) is the optimal, production-stable architecture. Reverted to Milestone A configuration.
* **Table Renaming:** To make its specific architectural purpose crystal clear, `DSDT.aml` has been renamed to `DSDT-Lenovo-RHUB.aml` (659 KB). OpenCore replaces the system DSDT based on the internal binary `DSDT` header signature.

---

## 3. SMBIOS Identifiers (`PlatformInfo -> Generic`)

* **Status:** ✅ **RESOLVED**
* **Verdict:** Real SMBIOS identifiers active on USB.
* **Details:** Blank/placeholder identifiers (`M0000000000000001`, `W00000000001`, `00000000-...`) only existed in sanitized export files. The active USB `config.plist` has full, genuine `MacBookPro16,1` hardware identifiers:
  * **MLB:** `C02117301GUN9PR1F`
  * **ROM:** `YKN9BSRZ` (`60:A3:7D:05:24:59`)
  * **SystemSerialNumber:** `C02FM8ZWMD6N`
  * **SystemUUID:** `2302D852-0B0C-4417-A3E6-7B524058F299`
  * **ProcessorType:** `1537` (`0x0601` for 6 Performance Cores)

---

## 4. Functional Bugs & macOS 26 Tahoe Issues

| # | Item | Current State | Status | Impact & Recommended Action |
| :-: | :--- | :--- | :-: | :--- |
| **4.1** | **`AllowRelocationBlock`** | `<true/>` in `Booter -> Quirks` | ✅ **RESOLVED** | Retained as `<true/>` as explicitly required by 1401 / NullMoth macOS Tahoe environment. Validated with `ocvalidate` (0 issues). |
| **4.2** | **`-ibtcompatbeta` in boot-args** | Present in `boot-args` | ✅ **RESOLVED** | Intel Bluetooth connects and functions properly on macOS 26 Tahoe with `-ibtcompatbeta`. |
| **4.3** | **Bluetooth Kext Load Order** | `IntelBluetoothFirmware` → `IntelBTPatcher` → `BlueToolFixup` | ✅ **RESOLVED** | Verified working in OpenIntelWireless recommended sequence. |
| **4.4** | **SimpleHDA Audio Language** | `prev-lang:kbd` set to `en-US:0` (`ZW4tVVM6MA==`) | ✅ **RESOLVED** | Audio output/input device names successfully show in English system-wide. |
| **4.5** | **`acpi-wake-type` Format & Path** | `<data>AQ==</data>` under `Pci(0x1,0x0)/Pci(0x0,0x0)` | ⚠️ **APPLIED (TESTING)** | Corrected data type from integer `1` to `<data>AQ==</data>` (`01`). |
| **4.6** | **NVRAM Delete Flash Wear Cleanup (`boot-args`, `csr-active-config`, etc.)** | `prev-lang:kbd` and `csr-active-config` removed; others pending finalization | ⏳ **PENDING (FINAL STAGE)** | Keeping variables in `NVRAM -> Delete` causes erase/rewrite cycles to physical SPI flash on every boot. `prev-lang:kbd` and `csr-active-config` removed from `Delete`; `boot-args`, `nullmoth-remove`, etc., will be cleaned at the very end once all testing is verified stable. |
| **4.7** | **`ForceOcWriteFlash`** | `<false/>` in `UEFI -> Quirks` | ⚠️ **APPLIED (TESTING)** | Previously set to `<true/>`. Acidanthera explicitly warns that forcing flash writes causes SPI flash wear. Disabled to protect SPI flash. |
| **4.8** | **`LegacyOverwrite`** | `<false/>` in `NVRAM` | ⚠️ **APPLIED (TESTING)** | Intended only for legacy systems with emulated `nvram.plist`. Changed from `<true/>` to failsafe `<false/>`. |

---

## 5. Redundancies & Dead Config Entries

| # | Item | Current State | Status | Impact & Notes |
| :-: | :--- | :--- | :-: | :--- |
| **5.1** | **Unused RestrictEvents GUIDs** | Removed `4D1FDA02-3869-...`; cleaned `4D1EDE05-...` | ⚠️ **APPLIED (TESTING)** | RestrictEvents only reads `4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102`. Dead typo GUID removed and `DefaultBackgroundColor` retained in `4D1EDE05-...`. |
| **5.2** | **AMFIPass.kext vs AMFI Boot-Args** | `AMFIPass.kext` enabled + `amfi_get_out_of_my_way=0x1 amfi=0x80` in `boot-args` | ℹ️ **INTENTIONAL** | `amfi_get_out_of_my_way=0x1` is kept intentionally for NullMoth v2.9 unsigned RTX 4050 display drivers. Harmless redundancy. |
| **5.3** | **Debug Target `65` vs `67`** | `Target: 65` | ℹ️ **HARMLESS** | `65` writes log file to EFI root; `67` also mirrors output to on-screen text console. |
| **5.4** | **Duplicate `alcid=99` vs `layout-id`** | Present in both `boot-args` and `DeviceProperties` | ℹ️ **HARMLESS** | Harmless duplicate setting Realtek ALC257 layout to 99 (`0x63`). |

---

## 6. Execution & Step-by-Step Testing Log

* **Test 1 (Baseline Verification):** Reverted to git baseline `87f05ae` / `aa1807b` with `DSDT.aml` enabled and 6P cores active (`ProcessorType: 1537`). macOS booted successfully.
* **Test 2 (SSDT-USB-Reset Removal):** Set `SSDT-USB-Reset.aml` to `Enabled: false`. Booted into macOS; all USB ports, internal Bluetooth `HS07`, and webcam verified functional. Removed entry from `config.plist` and deleted `.aml` file.
* **Test 3 (Bluetooth & Audio Language Tuning):** Added `-ibtcompatbeta` to `boot-args`; set `prev-lang:kbd` to `en-US:0` (`ZW4tVVM6MA==`); reordered Bluetooth kexts to `IntelBluetoothFirmware` → `IntelBTPatcher` → `BlueToolFixup`. Verified working: Bluetooth discovers devices and audio devices show in English.
* **Test 4 (acpi-wake-type, NVRAM Wear & GUID Cleanup):** Retained `AllowRelocationBlock: true` per 1401 requirements; changed `acpi-wake-type` to `<data>AQ==</data>`; cleaned dead NVRAM GUID `4D1FDA02-3869-...` and duplicate CPU keys; turned off `ForceOcWriteFlash` and `LegacyOverwrite`; removed `prev-lang:kbd` and `csr-active-config` from `NVRAM -> Delete`. Validated via `ocvalidate` (0 issues). Ready for reboot test.
* **Test 5 (Milestone A - Modular Trackpad Initial Run):** Booted with unpatched `DSDT.aml` + `SSDT-TPAD.aml` + OpenCore ACPI patch. System booted cleanly to desktop, but trackpad did not respond. Log inspection revealed OpenCore patched the in-memory OEM DSDT, then replaced it with the unpatched `DSDT.aml` from disk, leading to ACPICA duplicate `_CRS` rejection.
* **Test 5b (Milestone A - Native XCRS DSDT):** Applied `_CRS` → `XCRS` rename directly in `DSDT.aml` (checksum sum mod 256 = 0). Disabled redundant OpenCore ACPI patch. `SSDT-TPAD.aml` loaded at index 40. Booted successfully into macOS Tahoe; full precision trackpad gestures, scrolling, tap, and click verified functional. ✅ **MILESTONE A RESOLVED**.
* **Test 6 (Milestone B - Dropping DSDT.aml):** Tested booting with `DSDT.aml` disabled. Motherboard factory DSDT caused early boot panic `AE_NOT_FOUND` in AppleACPIPlatform due to conditional `Scope (_SB.PC00.XHCI.RHUB)` inside `If (CondRefOf (PU2C))`. Proved empirically that `DSDT.aml` is strictly required. Reverted config to Milestone A baseline (`DSDT.aml: true`, `SSDT-TPAD.aml: true`). System is restored to working state.
* **Test 7 (DSDT Semantic Rename):** Renamed `DSDT.aml` to `DSDT-Lenovo-RHUB.aml` (659 KB) on USB and repo. Updated `config.plist` `ACPI -> Add` path to `DSDT-Lenovo-RHUB.aml`. Validated via `ocvalidate` (0 issues). Matches Milestone A functionality.
* **ACPI Patch Purge:** Completely deleted the disabled `TPAD: _CRS to XCRS Rename` from `ACPI -> Patch`. `ACPI -> Patch` is now clean and empty (`[]`).

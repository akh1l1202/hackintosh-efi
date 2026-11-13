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
| **4.1** | **`AllowRelocationBlock`** | `<true/>` in `Booter -> Quirks` | ⏳ **PENDING** | Defaults to `<false/>`. Unnecessary on modern UEFI systems alongside `ProvideCustomSlide` and `RebuildAppleMemoryMap`. Can cause boot instability. **Action:** Change to `<false/>`. |
| **4.2** | **`-ibtcompatbeta` in boot-args** | Missing from `boot-args` | ⏳ **PENDING** | Intel Bluetooth on macOS 26 Tahoe often fails firmware patching without `-ibtcompatbeta`. **Action:** Add `-ibtcompatbeta` to `boot-args`. |
| **4.3** | **Bluetooth Kext Load Order** | `BlueToolFixup` → `IntelBluetoothFirmware` → `IntelBTPatcher` | ⏳ **PENDING** | OpenIntelWireless recommends `IntelBluetoothFirmware` → `IntelBTPatcher` → `BlueToolFixup`. **Action:** Adjust order in `Kernel -> Add`. |
| **4.4** | **SimpleHDA Audio Language** | `prev-lang:kbd` is `<data></data>` (empty) | ⏳ **PENDING** | SimpleHDA 1.0.1 can default audio output names to Chinese (`zh-CN`) when `prev-lang:kbd` is unset. **Action:** Add `shda-lang=en` to `boot-args`. |
| **4.5** | **`acpi-wake-type` Format & Path** | `<integer>1</integer>` under dGPU bridge (`Pci(0x1,0x0)`) | ⏳ **PENDING** | Expected type is `<data>AQ==</data>` (`01`). Also belongs under USB XHCI (`Pci(0x14,0x0)`) rather than dGPU bridge. **Action:** Correct type and target path. |
| **4.6** | **NVRAM Delete Wiping `boot-args` & `nullmoth-remove`** | Present in `NVRAM -> Delete -> 7C436110-...` | ⏳ **PENDING** | Wipes dynamic NVRAM flags set by `NullMothSafe.efi` across reboots. **Action:** Remove `boot-args` and `nullmoth-remove` from `NVRAM -> Delete` once stable. |
| **4.7** | **`ForceOcWriteFlash`** | Not present | ℹ️ **N/A** | Does not exist in OpenCore 1.0.x schema; only standard `NVRAM -> WriteFlash: true` exists. |

---

## 5. Redundancies & Dead Config Entries

| # | Item | Current State | Status | Impact & Notes |
| :-: | :--- | :--- | :-: | :--- |
| **5.1** | **Unused RestrictEvents GUIDs** | `4D1EDE05-...` and `4D1FDA02-3869-...` present in NVRAM Add/Delete | ⏳ **PENDING** | RestrictEvents only reads `4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102`. The other two GUID blocks are dead clutter. **Action:** Delete both unused GUID blocks. |
| **5.2** | **AMFIPass.kext vs AMFI Boot-Args** | `AMFIPass.kext` enabled + `amfi_get_out_of_my_way=0x1 amfi=0x80` in `boot-args` | ℹ️ **INTENTIONAL** | `amfi_get_out_of_my_way=0x1` is kept intentionally for NullMoth v2.9 unsigned RTX 4050 display drivers. Harmless redundancy. |
| **5.3** | **Debug Target `65` vs `67`** | `Target: 65` | ℹ️ **HARMLESS** | `65` writes log file to EFI root; `67` also mirrors output to on-screen text console. |
| **5.4** | **Duplicate `alcid=99` vs `layout-id`** | Present in both `boot-args` and `DeviceProperties` | ℹ️ **HARMLESS** | Harmless duplicate setting Realtek ALC257 layout to 99 (`0x63`). |

---

## 6. Execution & Step-by-Step Testing Log

* **Test 1 (Baseline Verification):** Reverted to git baseline `87f05ae` / `aa1807b` with `DSDT.aml` enabled and 6P cores active (`ProcessorType: 1537`). macOS booted successfully.
* **Test 2 (SSDT-USB-Reset Removal):** Set `SSDT-USB-Reset.aml` to `Enabled: false`. Booted into macOS; all USB ports, internal Bluetooth `HS07`, and webcam verified functional. Removed entry from `config.plist` and deleted `.aml` file.

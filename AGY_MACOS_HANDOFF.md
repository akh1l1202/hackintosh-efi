# AGY Handoff & Briefing Note: Lenovo LOQ Hackintosh (macOS Sequoia)

**From:** Antigravity (Windows Session)  
**To:** Antigravity (macOS Session)  
**Hardware:** Lenovo LOQ 15IRX9 (HM770, i5-13450HX [6P+4E = 16 threads], RTX 4050 Laptop dGPU, SK Hynix BC901 NVMe SSD)  
**Current Boot Media:** USB Drive (`/Volumes/1401/EFI/OC/`)  
**Git Repository:** `D:\GitHub\hackintosh-efi` (synchronized with commit `0bae21b` + schema fix, commit `1818768` reverted)

---

## 1. Complete Troubleshooting & Post-Mortem

### Analysis of the Two Distinct Failures:

1. **Failure Type A: The 0.08-Second Early ACPI Freeze (Happened with commit `7f5b0dc`)**
   - **Symptom:** Stopped immediately at:
     ```text
     ACPI: SSDT 0x00000000754C7000 00007C (v02 ZPSS ...
     ```
   - **Cause:** Commit `7f5b0dc` had `UpdateSMBIOSMode: Create` with `CustomSMBIOSGuid: false`, `MmioWhitelist[0]: true` (`0xFF000000`), and `ResizeGpuBars: 13`. On this InsydeH2O BIOS laptop, replacing standard SMBIOS memory with `Create` mode corrupts ACPI memory tables at timestamp 0.08s.
   - **Fix:** Restored commit `0bae21b`'s settings: `UpdateSMBIOSMode: Custom`, `CustomSMBIOSGuid: true`, `MmioWhitelist[0]: false`, `ResizeAppleGpuBars: 0`, and `ResizeGpuBars: -1`. With these settings, ACPI table traversal succeeds cleanly.

2. **Failure Type B: The Prohibited Sign (🚫 `support.apple.com/mac/startup` / "Waiting for root device")**
   - **Symptom:** System booted through ACPI and drivers, then failed with:
     ```text
     AppleNVMe Assert failed: fIOMapRegs ErrorExit
     AppleNVMe Assert failed: resultDeleteWorkloop
     ```
     followed by AHCI enumeration and the 🚫 prohibited symbol.
   - **Root Cause:**
     1. **Corrupted frequency data in `CPUFriendDataProvider.kext` (from commit `1818768`):** Contained an entire 21 KB unparsed ASCII XML document in `<data>`, which crashed kernel power states.
     2. **Windows 11 Fast Startup Lock:** Windows 11 has `HiberbootEnabled: 1` active. When Windows restarts or shuts down with Fast Startup enabled, the SK Hynix BC901 NVMe SSD is left in an ACPI D3hot suspended state with pending locks in `hiberfil.sys`. When macOS boots, `AppleNVMe` cannot map the PCIe BAR0 registers (`fIOMapRegs ErrorExit`), detaches the drive, and macOS displays the prohibited symbol because the APFS root volume cannot be found.
   - **Fix:**
     - Removed `CPUFriend.kext`, `CPUFriendDataProvider.kext`, and `CpuTopologyRebuild.kext`.
     - Disable Windows Fast Startup (or perform a cold boot by holding Shift while clicking Shut Down in Windows).

---

## 2. Boot Procedure for the User

1. In Windows:
   - Run `powercfg /h off` from an **Administrator Command Prompt / PowerShell** (or hold **Shift** while clicking **Shut Down** in the Start Menu for a full cold shutdown).
2. Turn the laptop back on and boot from the USB drive (`1401`).
3. Boot into macOS cleanly.

---

## 3. Instructions for macOS Antigravity (Unlocking CPU Performance)

When the user asks to resume optimizing CPU performance:

1. **Verify Live Clocks with `powermetrics`:**
   - Remember that macOS System Information / About This Mac statically reports `38.4 MHz x 68 = 2.61 GHz` (nominal crystal ratio) regardless of Turbo Boost.
   - Check actual dynamic core frequencies under load:
     ```bash
     sudo powermetrics -n 1 -i 1000 --samplers cpu_power
     ```

2. **Migrate SMBIOS to `MacBookPro16,1` Safely:**
   - Keep `UpdateSMBIOSMode: Custom` and `CustomSMBIOSGuid: true` intact.
   - Use `macserial -m MacBookPro16,1 -g` to generate matching Serial, MLB, and UUID.
   - Update `PlatformInfo -> Generic` in `config.plist`.

3. **Compile Valid Binary Frequency Vectors (If CPUFriend is Used):**
   - Use `CPUFriendFriend.py` to compile pure binary `FrequencyVectors`.
   - Never inject raw XML text into `<data>` tags. Validate with Python before rebooting.

---
*End of handoff note.*


---

## 4. macOS Session Update: Successful `MacBookPro16,1` Migration & Live Power Metrics

**Date/Time:** 2026-11-04 14:32 IST  
**Active SMBIOS:** `MacBookPro16,1`  
**Boot Status:** ✅ Clean boot via OpenCore USB (`/dev/disk0s1`) without errors.

### Applied Configuration:
* **Product Name:** `MacBookPro16,1`
* **Serial Number:** `C02FM8ZWMD6N`
* **Board Serial (MLB):** `C02117301GUN9PR1F`
* **SmUUID:** `2302D852-0B0C-4417-A3E6-7B524058F299`
* **Apple ROM:** `60A37D052459`
* **Boot Args:** `-v debug=0x100 keepsyms=1 nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth amfi_get_out_of_my_way=0x1 amfi=0x80 ps2rst=0 ipc_control_port_options=0 nvrmacpibl -vi2c-force-polling alcid=99 revcpu=1 revpatch=cpuname`

### Live CPU & Wattage Diagnostics Under Load (MacBookPro16,1):
* **Sampling Tool:** `sudo powermetrics -n 2 -i 1000 --samplers cpu_power` under sustained single-core saturation (`yes > /dev/null`).
* **Package Power (CPUs + GT + SA):** **23.33 W** (drawing from AC Power, battery at 100%).
* **Active Dynamic Frequencies Under Load:**
  * CPU 0: **3,413.87 MHz (~3.41 GHz)**
  * CPU 1: **3,333.47 MHz (~3.33 GHz)**
  * CPU 6: **3,089.14 MHz (~3.09 GHz)**
  * CPU 11: **3,040.09 MHz (~3.04 GHz)**
* **Topology:** Currently operating on 6 Performance Cores / 12 Threads (Efficient Cores currently disabled in BIOS).

### Next Milestones for Full Performance:
1. **Unlock Atom / E-cores (10 Cores, 16 Threads):**
   - Inject `CpuTopologyRebuild.kext` (v2.0.2) cleanly.
   - Re-enable Efficient Cores in Lenovo BIOS.
2. **Frequency Ceiling & EPP (4.60 GHz Boost):**
   - Inject clean binary `CPUFriendDataProvider.kext` with EPP set to `0x00` (Max Performance) on AC power.
3. **Windows 11 Dual-Boot Note:**
   - Keep Windows Fast Startup disabled (`powercfg /h off`) so the SK Hynix NVMe controller does not enter suspended D3hot state when pivoting back to macOS.


---


---

## 5. macOS Session Update: CPU Frequency Unlocking (Phase 2 Completed)

**Date/Time:** 2026-11-10 17:58 IST
**Status:** Injected valid binary CPUFriend and CPUFriendDataProvider into USB EFI.

### Applied Changes:
1. CPUFriend.kext: Acidanthera v1.3.0 Mach-O binary bundle placed in EFI/OC/Kexts/.
2. CPUFriendDataProvider.kext:
   - Generated from native macOS MacBookPro16,1 profile (Mac-E7203C0F68AA0004.plist).
   - Pure binary frequency vector (7,668 raw bytes, verified zero XML text corruption).
   - lpm_ratio adjusted to 0x08 (800 MHz factory idle floor).
   - epp adjusted to 0x00 (Max Performance / aggressive boost under load).
   - perf-bias adjusted to 0x01 (High Performance).
3. OpenCore Injection:
   - Registered at index 2 (CPUFriend.kext) and index 3 (CPUFriendDataProvider.kext) directly after CpuTscSync.kext.
   - Verified valid schema with plutil -lint (OK).
   - Preserved CustomSMBIOSGuid: true, UpdateSMBIOSMode: Custom, and ResizeGpuBars: 13.
   - Baseline backup saved at /Volumes/1401/EFI/OC/config.plist.working-baseline.

/*
 * Intel ACPI Component Architecture
 * AML/ASL+ Disassembler version 20241212 (32-bit version)
 * Copyright (c) 2000 - 2023 Intel Corporation
 * 
 * Disassembling to symbolic ASL+ operators
 *
 * Disassembly of E:/EFI/OC/ACPI/SSDT-USB-Reset.aml
 *
 * Original Table Header:
 *     Signature        "SSDT"
 *     Length           0x0000006E (110)
 *     Revision         0x02
 *     Checksum         0xC8
 *     OEM ID           "ZPSS"
 *     OEM Table ID     "UsbReset"
 *     OEM Revision     0x00001000 (4096)
 *     Compiler ID      "INTL"
 *     Compiler Version 0x20241212 (539234834)
 */
DefinitionBlock ("", "SSDT", 2, "ZPSS", "UsbReset", 0x00001000)
{
    External (_SB_.PC00.XHCI.RHUB, DeviceObj)

    Scope (\_SB.PC00.XHCI.RHUB)
    {
        Method (_STA, 0, NotSerialized)  // _STA: Status
        {
            If (_OSI ("Darwin"))
            {
                Return (Zero)
            }
            Else
            {
                Return (0x0F)
            }
        }
    }
}


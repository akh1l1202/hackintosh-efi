/*
 * Intel ACPI Component Architecture
 * AML/ASL+ Disassembler version 20241212 (32-bit version)
 * Copyright (c) 2000 - 2023 Intel Corporation
 * 
 * Disassembling to symbolic ASL+ operators
 *
 * Disassembly of E:/EFI/OC/ACPI/SSDT-SBUS.aml
 *
 * Original Table Header:
 *     Signature        "SSDT"
 *     Length           0x00000080 (128)
 *     Revision         0x02
 *     Checksum         0x0C
 *     OEM ID           "ZPSS"
 *     OEM Table ID     "SBUS"
 *     OEM Revision     0x00000000 (0)
 *     Compiler ID      "INTL"
 *     Compiler Version 0x20241212 (539234834)
 */
DefinitionBlock ("", "SSDT", 2, "ZPSS", "SBUS", 0x00000000)
{
    External (_SB_.PC00.SBUS, DeviceObj)

    Scope (\_SB.PC00.SBUS)
    {
        Device (BUS0)
        {
            Name (_CID, "smbus")  // _CID: Compatible ID
            Name (_ADR, Zero)  // _ADR: Address
            Method (_STA, 0, NotSerialized)  // _STA: Status
            {
                If (_OSI ("Darwin"))
                {
                    Return (0x0F)
                }
                Else
                {
                    Return (Zero)
                }
            }
        }
    }
}


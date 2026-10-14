/*
 * Intel ACPI Component Architecture
 * AML/ASL+ Disassembler version 20241212 (32-bit version)
 * Copyright (c) 2000 - 2023 Intel Corporation
 * 
 * Disassembling to symbolic ASL+ operators
 *
 * Disassembly of E:/EFI/OC/ACPI/SSDT-RTCAWAC.aml
 *
 * Original Table Header:
 *     Signature        "SSDT"
 *     Length           0x0000004E (78)
 *     Revision         0x02
 *     Checksum         0x16
 *     OEM ID           "CORP"
 *     OEM Table ID     "AWAC"
 *     OEM Revision     0x00000000 (0)
 *     Compiler ID      "INTL"
 *     Compiler Version 0x20241212 (539234834)
 */
DefinitionBlock ("", "SSDT", 2, "CORP", "AWAC", 0x00000000)
{
    External (STAS, FieldUnitObj)

    Scope (\)
    {
        Method (_INI, 0, NotSerialized)  // _INI: Initialize
        {
            If (_OSI ("Darwin"))
            {
                STAS = One
            }
        }
    }
}


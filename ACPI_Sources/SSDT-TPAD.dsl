DefinitionBlock ("", "SSDT", 2, "HACK", "TPAD", 0x00000000)
{
    External (_SB.PC00.I2C0, DeviceObj)
    External (_SB.PC00.I2C0.TPAD, DeviceObj)
    External (_SB.PC00.I2C0.TPAD.ADR0, IntObj)
    External (_SB.PC00.I2C0.TPAD.HID2, IntObj)
    External (_SB.PC00.I2C0.TPAD.SBFG, BuffObj)
    External (_SB.PC00.I2C0.TPAD.XCRS, MethodObj)

    Scope (_SB.PC00.I2C0.TPAD)
    {
        Name (SBFB, ResourceTemplate ()
        {
            I2cSerialBusV2 (0x0015, ControllerInitiated, 0x00061A80,
                AddressingMode7Bit, "\\_SB.PC00.I2C0",
                0x00, ResourceConsumer, , Exclusive,
                )
        })

        Method (_INI, 0, NotSerialized)
        {
            If (_OSI ("Darwin"))
            {
                ADR0 = 0x15
                HID2 = One
            }
        }

        Method (_CRS, 0, Serialized)
        {
            If (_OSI ("Darwin"))
            {
                Return (ConcatenateResTemplate (SBFB, SBFG))
            }

            Return (XCRS ())
        }
    }
}

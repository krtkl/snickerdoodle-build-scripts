# snickerdoodle Platform Controller User Guide: Push Buttons and SPI Commands

## Push Buttons

### Reset

Holding re/set button (SW2) for at least 3 seconds while booted resets Zynq.  

### Change Boot Mode

*Note: Requires snickerdoodle firmware r2p0 or later.*  

Holding select button (SW1) for at least 1 second while powering on (e.g. while inserting microUSB cable) enters "boot select" mode; green LED will blink rapidly.

Subsequently pressing select button once cycles through boot options (SD card / Quad-SPI flash / JTAG). Red and white LEDs indicate currently selected boot mode:  

| Red LED | White LED | Boot Mode      |
| :-----: | :-------: | :------------: |
|   ON    |    OFF    |    SD Card     |
|   OFF   |    ON     | Quad-SPI flash |
|   ON    |    ON     |    JTAG mode   |

Pressing re/set button (SW2) exits 'boot select' mode and Zynq is powered (green LED will be solid).

*Note: Default boot mode is SD card. Board will use selected boot mode until changed.*

### Device Firmware Upgrade

Holding both buttons (SW1 and SW2) for at least 1 second while powering on enters Device Firmware Upgrade ("DFU") mode. See end for instructions.

## SPI Commands

*Note: The following SPI commands snickerdoodle firmware r2p0 or later, device tree with SPI node (/dev/spidev1.0), and spi-ctrl program.*

### Antenna Selection

Select between chip antenna and external antenna (via u.FL).

#### Syntax

$ sudo ./spi-ctrl -c A -n <antenna> /dev/spidev1.0

<antenna> is the antenna number:

| Value | Ref. Des. | Description      |
| :---: | :-------: | :--------------- |
|   0   |    E1     | Chip antenna     |
|   1   |    J4     | External antenna |

#### Examples

Select external antenna:

$ sudo ./spi-ctrl -c A -n 1 /dev/spidev1.0

Monitor Wi-Fi (wlan0) signal strength in 'real time':

$ watch -n 1 iw wlan0 link

*Note: J5 is permanently connected to the dual-band radio on snickerdoodle black and is not under software control.*

### LED Override

Override and customize LED behavior.  

#### Syntax

$ sudo ./spi-ctrl -c L -l <led> -s <state> [-o <on time>] [-t <total time>] [-b <brightness>] /dev/spidev1.0

<led> is the LED number:

| Value | Ref. Des. | Color  | Description |
| :---: | :-------: | :----: | :---------- |
|   1   |    D1     | Green  | Power       |
|   2   |    D2     | Orange | Link        |
|   3   |    D3     |  Blue  | Bluetooth   |
|   4   |    D4     | White  | App         |
|   5   |    D5     |  Red   | Fault       |

<state> is the desired LED state:

| Value |    State     |
| :---: | :----------: |
|   0   |     Off      |
|   1   |     On       |
|   2   |  One blink   |
|   3   |  Slow blink  |
|   4   |  Fast blink  |
|   5   | Custom blink |
|   6   |    Strobe    |
|   7   |   Breathe    |
|   8   |   Default    |

<on time> is the LED 'on time' in increments of 100ms. **Note: "Custom blink" only.**

<total time> is the LED 'blink period' in increments of 100ms. **Note: "Custom blink" only.**

<brightness> is the LED brightness in (approx.) linear integer increments from 1 to 10. **Note: Ignored for "Breathe."**

#### Examples

Turn blue LED on in 'breathing' state:  

$ sudo ./spi-ctrl -c L -l 3 -s 7 /dev/spidev1.0

Return blue LED to default state (per production firmware):  

$ sudo ./spi-test -c L -l 3 -s 8 /dev/spidev1.0

### Low-Power Mode

Enter low-power/standby mode (approx. 6mA current draw). This mode disables the Zynq and radio while reducing the STM32 clock frequency to minimize power consumption.  

#### Syntax

$ sudo ./spi-ctrl -c P -d <delay> -w <wake>

<delay> is the countdown timer to enter low-power mode in seconds.

<wake> is the wake up timer in seconds. A value of '0' disables the wake up timer (i.e. only an external interrupt or board reset will exit low-power mode).

*Note: There are two low-power-mode external interrupts (rising edge) that are always enabled: JA2.2, JB1.2*

#### Examples

Power down (low-power/standby) after 5 seconds, wake up 15 seconds later:

$ sudo ./spi-ctrl -c P -d 5 -w 15 /dev/spidev1.0

### "Hard" Zynq Reset

Set timer for STM32 to perform "hard" Zynq reset.

#### Syntax

$ sudo /spi-ctrl -c R -d <delay> /dev/spidev1.0

<delay> is the countdown timer to reset the Zynq in seconds. A value of '0' (before the countdown timer expires) will reset/cancel the timer.  

#### Examples

Set timer to perform "hard" Zynq reset after 30 seconds:

$ sudo ./spi-crtl -c R -d 30 /dev/spidev1.0

Reset/cancel timer (before countdown timer expires):  

$ sudo ./spi-crtl -c R -d 0 /dev/spidev1.0

## Upgrading STM32 Firmware (via DFU)

snickerdoodle's platform controller firmware can be updated via the USB interface by using the Device Firmware Upgrade ("DFU") utility.  

snickerdoodle STM32 DFU files can be obtained from the krtkl Download Center: https://krtkl.com/resources/downloads/  

An overview of the DFU utility can be found at: http://dfu-util.sourceforge.net  

### Windows Instructions

1. Download 'DfuSeDemo' (https://www.st.com/en/development-tools/stsw-stm32080.html) from STMicroelectronics and install on host.

2. Boot snickerdoodle in DFU mode.  
    *Option 1*  
    Hold both buttons (SW1 and SW2) for at least 1 second* while powering on.  
    *Option 2*  
    Short R55 pads (right of "-22" silkscreen) for at least 1 second* while powering on.  

    **Important note:**  
    **For firmware versions prior to r2p0 (e.g. original firmware for boards manufactured prior to January 2020), increase hold time to ~5 seconds. All LEDs will remain illuminated; when red LED turns off, board is in DFU mode.**  
    **For firmware versions r2p0 and later, no LEDs will illuminate when entering DFU mode.**

3. Run **DfuSeDemo** (ensure snickerdoodle is connected to host via USB).  
    a. "STM Device in DFU Mode" should appear and be selected in "Available DFU Devices" dropdown.  
    b. Under "Upgrade or Verify Action", click "Choose..." and select .dfu file.  
    c. [Optional] Select "Verify after upload".  
    d. Click "Upgrade", "Yes", and await "Verify successful!" message.  
    e. Close **DfuSeDemo**.

4. Disconnect snickerdoodle USB/cycle power and boot!

### Linux / Mac Instructions

1. Download **dfu-util** and install on host.  
    *Linux*  
    $ apt-get install dfu-util (use appropriate package installer)  
    *Mac*  
    $ brew install dfu-util

2. Boot snickerdoodle in DFU mode.  
    *Option 1*  
    Hold both buttons (SW1 and SW2) for at least 1 second* while powering on.  
    *Option 2*  
    Short R55 pads (right of "-22" silkscreen) for at least 1 second* while powering on.  

    **_Important note:_**  
* **_For firmware versions prior to r2p0 (e.g. original firmware for boards manufactured prior to January 2020), increase hold time to 3 seconds. All LEDs will remain illuminated; when red LED turns off, board is in DFU mode._**  
* **_For firmware versions r2p0 and later, no LEDs will illuminate when entering DFU mode._**

3. List DFU devices to confirm STM32 is in DFU mode (ensure snickerdoodle is connected to host via USB).

    $ dfu-util -l  
    dfu-util 0.9  
    ...  
    Found DFU: [0483:df11] ver=2200, devnum=27, cfg=1, intf=0, path="20-2", alt=1, name="@Option Bytes  /0x1FFFF800/01*016 e"...  
    Found DFU: [0483:df11] ver=2200, devnum=27, cfg=1, intf=0, path="20-2", alt=0, name="@Internal Flash  /0x08000000/064*0002Kg"...  

4. Download .dfu file to STM32.  

    $ dfu-util -a 0 -D new-firmware.dfu

5. Disconnect snickerdoodle USB/cycle power and boot!  

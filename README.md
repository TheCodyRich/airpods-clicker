# AirPod Clicker

A macOS menu bar app that advances Google Slides when you open your AirPods case. It works with any app that moves forward on the right arrow key, including Keynote and PowerPoint.

## How it works

When an AirPods case opens or closes, it sends a Bluetooth LE "proximity pairing" advertisement. That is the same broadcast that makes the battery card pop up on a nearby iPhone. The app reads those broadcasts with CoreBluetooth and checks the lid byte. Bit `0x08` is set while the lid is closed, and the low three bits count opens. A change from closed to open sends a right-arrow key press to whatever app is in front.

Byte layout after Apple's `4C 00` company ID, confirmed on AirPods Pro 2 (USB-C). `xx` bytes vary by device and battery level:

```
07 19 01 24 20 xx xx xx 11 xx ...
|  |  |  model  |  |  |  lid (0x11 open, 0x19 closed)
|  |  prefix    |  batteries
|  length       status
type (proximity pairing)
```

No pairing, private frameworks, or network access are involved.

## Supported devices

Every AirPods model with a charging case sends this packet, and so do Beats earbuds that come in a case, so the app accepts all of them. It has been tested on AirPods Pro 2 (USB-C). Other models should work the same way, since the lid byte is in the same place. If yours doesn't, run the `--scan` mode below and open an issue with the output. AirPods Max have no case lid, so they won't trigger anything.

## Build

Needs the Xcode command line tools (`swift` 5.9+), macOS 13+.

```bash
./build.sh
```

That produces `build/AirPodClicker.app`, ad-hoc signed. Copy it to `/Applications` if you want it to stick around.

## Use

```bash
open build/AirPodClicker.app
```

On first launch macOS asks for two permissions:

1. Bluetooth, to read the case's broadcasts.
2. Accessibility (System Settings > Privacy & Security > Accessibility), to press the arrow keys. Turn on AirPod Clicker there.

Rebuilding changes the ad-hoc signature, so macOS may ask again after each build.

Then start your Google Slides presentation, click into the slide window so it has focus, and open the case to advance.

The menu bar icon is an AirPods case. It fills in briefly each time a lid event fires. The menu shows the last packet seen and the last event, and has these settings:

- Enabled on or off.
- What lid open and lid close each do: next slide, previous slide, or nothing. Default is open goes forward and close does nothing.
- Range, a signal-strength cutoff that keeps other people's AirPods in the room from clicking your slides. Normal is -65 dBm. Use "Close" in a crowded room and hold the case near the laptop.

There is a 0.8 second debounce, so one flip is one click.

## Debugging

To print every AirPods broadcast nearby with its decoded lid state:

```bash
open -n --stdout /tmp/airpods.log --stderr /tmp/airpods.log -a "$PWD/build/AirPodClicker.app" --args --scan
tail -f /tmp/airpods.log
```

`--watch` does the same but prints only lid events and presses the keys, without the menu bar. Launch through `open` like above. Running the binary straight from a terminal makes macOS check the terminal's Bluetooth permission instead of the app's, and it kills the process if the terminal doesn't have it.

## Limits

- Closing the case reports quickly, but if the case sits closed for a while it stops broadcasting. The app forgets the lid state after 6 seconds of silence, so the next open still counts.
- If the case is already open when the app starts, that first open is ignored.
- Key presses go to the front app, so keep the presentation window focused.

## License

MIT. See [LICENSE](LICENSE).

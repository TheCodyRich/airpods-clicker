# AirPod Clicker

A macOS menu bar app that turns your AirPods case into a presentation clicker. Open the lid and Google Slides moves to the next slide. It also works with Keynote, PowerPoint, and anything else that advances on the right arrow key.

Works with AirPods and Beats earbuds that come in a charging case, on Apple Silicon and Intel Macs running macOS 13 (Ventura) or later.

## Install

Setup takes about two minutes. You only do it once.

### 1. Download

Go to the [latest release](https://github.com/TheCodyRich/airpods-clicker/releases/latest) and download **AirPodClicker.dmg**.

### 2. Move it to Applications

1. Double-click **AirPodClicker.dmg** in your Downloads folder. A window opens with the app and an Applications folder.
2. Drag **AirPodClicker** onto the **Applications** folder.
3. Eject the disk image. In Finder's sidebar, click the eject button next to **AirPod Clicker**.

### 3. Open it the first time

AirPod Clicker is free and isn't signed with a paid Apple developer certificate, so macOS blocks it the first time. You only need to allow it once.

**On macOS 15 (Sequoia) or later:**

1. Open **Applications** and double-click **AirPodClicker**.
2. macOS says it "could not verify AirPodClicker is free of malware." Click **Done**. Don't click Move to Trash.
3. Open **System Settings** and click **Privacy & Security** in the sidebar.
4. Scroll down to the **Security** section. You'll see a line saying AirPodClicker was blocked. Click **Open Anyway**.
5. Enter your Mac password or use Touch ID.
6. In the dialog that pops up, click **Open Anyway** again.

**On macOS 13 (Ventura) or 14 (Sonoma):**

1. Open **Applications**, then right-click (or Control-click) **AirPodClicker** and choose **Open**.
2. In the warning dialog, click **Open**.

### 4. Allow Bluetooth

macOS asks whether AirPod Clicker can use Bluetooth. Click **Allow**. The app uses it to see your case opening and closing. It doesn't connect to or change your AirPods.

### 5. Allow Accessibility

The app needs Accessibility access to press the arrow keys for you.

1. When macOS shows the Accessibility prompt, click **Open System Settings**. If you missed the prompt, click the AirPods case icon in the menu bar and choose **Grant Accessibility access…**, or go to **System Settings > Privacy & Security > Accessibility**.
2. Turn on the switch next to **AirPodClicker**.
3. Enter your password or use Touch ID if asked.

Click the menu bar icon to check. If the **Grant Accessibility access…** line is gone, setup is done.

### 6. Present

1. Open your deck in Google Slides and click **Slideshow**.
2. Click once on the slide so the browser window is in front.
3. Open your AirPods case to go to the next slide. Close it, then open it again for the slide after that.

The menu bar icon fills in briefly every time the app sees the lid open.

### Optional: start at login

Go to **System Settings > General > Login Items**, click **+** under "Open at Login," and choose **AirPodClicker** from Applications.

## Settings

Click the AirPods case icon in the menu bar.

| Setting | What it does |
| --- | --- |
| Enabled | Turns clicking on or off without quitting the app. |
| When lid opens | Next slide (default), previous slide, or nothing. |
| When lid closes | Nothing (default), next slide, or previous slide. Set this to Previous slide if you want open to go forward and close to go back. |
| Range | How strong the signal has to be. Use **Close** in a room full of other AirPods so only the case in your hand counts. Use **Far** if you're walking around a stage. |

The top of the menu shows the last case it saw, its lid state, and the signal strength, which helps when picking a range.

## Troubleshooting

**The icon flashes but the slide doesn't move.** Accessibility isn't on, or the slideshow isn't the front window. Click once on the slide and try again. Then check step 5.

**Accessibility is switched on, but the menu still says to grant it.** macOS is holding on to an old copy of the permission, which happens after you replace the app with a newer version. Open Terminal and run:

```bash
tccutil reset Accessibility com.example.AirPodClicker
```

Then quit AirPod Clicker from its menu, open it again, and redo step 5. If an old AirPodClicker entry is still in the Accessibility list, remove it with the **–** button first.

**Nothing happens at all.** Open the menu. If it says "No AirPods seen yet," hold the case closer to your Mac, set Range to **Far**, and make sure Bluetooth is on. If it says Bluetooth permission was denied, turn AirPodClicker on in **System Settings > Privacy & Security > Bluetooth**.

**Someone else's AirPods are changing my slides.** Set Range to **Close** and hold your case near the laptop.

## How it works

When an AirPods case opens or closes, it sends a Bluetooth LE "proximity pairing" advertisement. That's the broadcast that makes the battery card pop up on a nearby iPhone. The app reads those broadcasts with CoreBluetooth and checks the lid byte. Bit `0x08` is set while the lid is closed, and the low three bits count opens. A change from closed to open sends a right-arrow key press to the front app. There's a 0.8 second debounce, so one flip is one click.

Byte layout after Apple's `4C 00` company ID, confirmed on AirPods Pro 2 (USB-C). `xx` bytes vary by device and battery level:

```
07 19 01 24 20 xx xx xx 11 xx ...
|  |  |  model  |  |  |  lid (0x11 open, 0x19 closed)
|  |  prefix    |  batteries
|  length       status
type (proximity pairing)
```

The app doesn't pair with anything, doesn't use private frameworks, and never touches the network.

### Supported devices

Every AirPods model with a charging case sends this packet, and so do Beats earbuds that come in a case, so the app accepts all of them. It has been tested on AirPods Pro 2 (USB-C). Other models should work the same way, since the lid byte is in the same place. If yours doesn't, run the scan mode below and open an issue with the output. AirPods Max have no case lid, so they won't trigger anything.

## Build from source

Needs the Xcode command line tools (`xcode-select --install`) with Swift 5.9 or later.

```bash
./build.sh
```

That builds a universal `build/AirPodClicker.app`, ad-hoc signed. `./build.sh --dmg` also packages `build/AirPodClicker.dmg`.

Each rebuild changes the ad-hoc signature, so macOS asks for Accessibility again. Use the `tccutil` command from Troubleshooting if the old permission gets stuck.

### Releases

Pushing a tag like `v1.0.1` runs `.github/workflows/release.yml`, which builds the DMG on a GitHub macOS runner and publishes it as a release.

### Debugging

To print every AirPods broadcast nearby with its decoded lid state:

```bash
open -n --stdout /tmp/airpods.log --stderr /tmp/airpods.log -a "$PWD/build/AirPodClicker.app" --args --scan
tail -f /tmp/airpods.log
```

`--watch` prints only lid events and presses the keys, without the menu bar. Launch through `open` like above. Running the binary straight from a terminal makes macOS check the terminal's Bluetooth permission instead of the app's, and it kills the process if the terminal doesn't have it.

## Limits

- A closed case stops broadcasting after a while. The app forgets the lid state after 6 seconds of silence, so the next open still counts.
- If the case is already open when the app starts, that first open is ignored.
- Key presses go to the front app, so keep the presentation window focused.

## License

MIT. See [LICENSE](LICENSE).

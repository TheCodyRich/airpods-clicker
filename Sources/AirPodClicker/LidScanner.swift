import CoreBluetooth
import Foundation

/// One decoded Apple Continuity "proximity pairing" advertisement (type 0x07).
///
/// Layout after the 0x4C 0x00 company ID:
///   [0] 0x07 type  [1] length  [2] prefix  [3..4] model (LE)  [5] status
///   [6] pod batteries  [7] charging flags + case battery  [8] lid  [9] color ...
/// Lid byte: low 3 bits are an open counter that ticks on every open,
/// bit 3 (0x08) is set while the lid is closed.
struct ProximityPacket {
    let model: UInt16
    let lidByte: UInt8
    let rssi: Int
    let raw: Data

    var lidClosed: Bool { lidByte & 0x08 != 0 }
    var lidCounter: UInt8 { lidByte & 0x07 }

    var modelName: String {
        switch model {
        case 0x2014: return "AirPods Pro 2"
        case 0x2024: return "AirPods Pro 2 (USB-C)"
        case 0x200E: return "AirPods Pro"
        case 0x2027: return "AirPods Pro 3"
        case 0x2002: return "AirPods"
        case 0x200F: return "AirPods 2"
        case 0x2013: return "AirPods 3"
        case 0x2019: return "AirPods 4"
        case 0x201B: return "AirPods 4 (ANC)"
        case 0x200A: return "AirPods Max"
        default: return String(format: "AirPods/Beats 0x%04X", model)
        }
    }

    init?(manufacturerData d: Data, rssi: Int) {
        let b = [UInt8](d)
        // 4C 00 = Apple, 07 = proximity pairing; need through the lid byte.
        guard b.count >= 11, b[0] == 0x4C, b[1] == 0x00, b[2] == 0x07 else { return nil }
        let p = Array(b[2...])
        model = UInt16(p[3]) | UInt16(p[4]) << 8
        lidByte = p[8]
        self.rssi = rssi
        raw = d
    }
}

enum LidEvent: String {
    case opened, closed
}

struct ScannerSettings {
    var minRSSI = -65
}

/// Watches BLE advertisements and turns lid state changes into events.
final class LidScanner: NSObject, CBCentralManagerDelegate {
    var settings = ScannerSettings()
    var onEvent: ((LidEvent, ProximityPacket) -> Void)?
    var onPacket: ((ProximityPacket) -> Void)?
    var onStateChange: ((String) -> Void)?

    private var central: CBCentralManager!
    private var lastClosed: Bool?
    private var lastCounter: UInt8?
    private var lastSeen = Date.distantPast
    private(set) var lastPacket: ProximityPacket?

    /// After this much silence we forget the lid state, so the next "open"
    /// packet counts as a fresh open (a closed case stops advertising).
    private let staleAfter: TimeInterval = 6

    private var startedAt = Date()

    func start() {
        startedAt = Date()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            onStateChange?("Scanning")
            central.scanForPeripherals(withServices: nil,
                                       options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        case .unauthorized:
            onStateChange?("Bluetooth permission denied")
        case .poweredOff:
            onStateChange?("Bluetooth is off")
        case .unsupported:
            onStateChange?("Bluetooth LE unsupported")
        default:
            onStateChange?("Bluetooth starting…")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard let data = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
              let packet = ProximityPacket(manufacturerData: data, rssi: RSSI.intValue)
        else { return }

        onPacket?(packet)

        // Every AirPods and Beats model uses the same packet, so any model counts;
        // signal strength is what keeps other people's cases out.
        guard packet.rssi != 127, packet.rssi >= settings.minRSSI else { return }

        handle(packet)
    }

    private func handle(_ packet: ProximityPacket) {
        let now = Date()
        // A case already open at launch is a baseline, not a click.
        if lastPacket == nil, now.timeIntervalSince(startedAt) < 3 {
            lastSeen = now
            lastPacket = packet
            lastClosed = packet.lidClosed
            lastCounter = packet.lidCounter
            return
        }
        if now.timeIntervalSince(lastSeen) > staleAfter {
            lastClosed = nil
            lastCounter = nil
        }
        lastSeen = now
        lastPacket = packet

        defer {
            lastClosed = packet.lidClosed
            lastCounter = packet.lidCounter
        }

        if packet.lidClosed {
            if lastClosed == false { onEvent?(.closed, packet) }
            return
        }
        // Lid is open: either it was closed/unknown before, or the counter
        // ticked because it was closed and reopened between packets.
        if lastClosed != false || (lastCounter != nil && lastCounter != packet.lidCounter) {
            onEvent?(.opened, packet)
        }
    }
}

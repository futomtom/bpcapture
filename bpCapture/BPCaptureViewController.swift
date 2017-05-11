import UIKit
import CoreBluetooth

class BloodPressure {
    var timestamp = Date ()
    var SYS = 0
    var DIA = 0
}

class BPCaptureViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {

    let SENDING_CHARACTERISTIC = "FFF2"
    let RECEIVING_CHARACTERISTIC = "FFF1"


    var captureMode = true

    @IBOutlet weak var ScanPage: UIView!
    @IBOutlet weak var view_capturing: UIView!
//    @IBOutlet weak var AnimateImageView: GIFImageView!

    @IBOutlet weak var SYS_value: UILabel!
    @IBOutlet weak var DIA_value: UILabel!

    @IBOutlet weak var HeartView: UIImageView!
    var manager: CBCentralManager!
    var peripherals = NSMutableArray(capacity: 0)

    var calibrateStart = false
    var BPinfo = BloodPressure ()
    fileprivate var progress = 0
    //capture page
    var BPCircularProgress: KYCircularProgress!
    fileprivate var durationTimer: Timer?
    @IBOutlet weak var PercentLabel: UILabel!
    var percent = 0.0
    var bp: CBPeripheral!
    var BPfound = false

    @IBOutlet weak var Button: UIButton! {
        didSet {
            Button.layer.borderColor = UIColor (red: 0.24, green: 0.49, blue: 0.84, alpha: 1.0).cgColor
            Button.layer.borderWidth = 1
            Button.layer.cornerRadius = 4
        }
    }
//    var alertViewNoBluetooth = AlertViewNoBluetooth ()
    @IBAction func CancelButtonTap(_ sender: Any) {
        closeConnection()

        _ = navigationController?.popViewController (animated: false)
    }

    func doScan() {
        BPfound = false
        if manager == nil {
            manager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
            // if self.manager.isScanning == false
        }
    }

    func closeConnection () {
        guard peripherals.count > 0 else {
            return
        }
        for peripheral in peripherals {
            manager.cancelPeripheralConnection (peripheral as! CBPeripheral)
        }
        manager = nil

    }


    func endScan () {
        durationTimer?.invalidate ()
        if peripherals.count < 1 {
            if manager.isScanning {
                manager.stopScan ()
            }
        }
    }



    override func viewDidLoad () {
        super.viewDidLoad ()
        manager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
        ScanPage.isHidden = false
    }

    override func viewDidAppear(_ animated: Bool) {
        doScan()
    }


    func centralManagerDidUpdateState (_ central: CBCentralManager) {
        //[CBUUID(string: "070EEB12-42C9-4875-A841-589ECF8A2CE6")]
        print ("centralManagerDidUpdateState")
        switch central.state {
        case .poweredOn:
            print (">>>CBCentralManagerState.PoweredOn")
            //            let uuid :CBUUID = CBUUID.init(string: TARGET_UUID)
            central.scanForPeripherals (withServices: nil, options: [ CBConnectPeripheralOptionNotifyOnConnectionKey: true])
            durationTimer = Timer.scheduledTimer (timeInterval: 20, target: self, selector: #selector (BPCaptureViewController.endScan), userInfo: nil, repeats: false)
        default: break
        }
    }

    func centralManager (_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [ String: Any], rssi RSSI: NSNumber) {
        if let deviceName = peripheral.name {
            print (">>>\( peripheral.name)")
            if deviceName == "Bluetooth BP" {
                guard BPfound == false else { return }
                BPfound = true
                central.stopScan ()
                peripherals.add (peripheral)
                peripheral.delegate = self
                central.connect (peripheral, options: nil)
            }

        }

    }

    func centralManager (_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print ("BP connected")

        peripheral.discoverServices ([ CBUUID(string: "FFF0")])
    }

    func centralManager (_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print (">>>connect \( peripheral.name) fail！")
    }

    func centralManager (_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        peripherals.removeAllObjects ()
    }

    func peripheral (_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print ("Error discovering services: \( error!.localizedDescription)")
            return
        }

        for service in peripheral.services! {
            peripheral.discoverCharacteristics ([ CBUUID(string: RECEIVING_CHARACTERISTIC), CBUUID(string: SENDING_CHARACTERISTIC)], for: service)
        }
        //  print("\(peripheral.services!.count) service")
    }

    func peripheral (_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print ("Error discovering services: \( error!.localizedDescription)")
            return
        }

        for characteristic in service.characteristics! {
            //   print(characteristic.uuid)
            if characteristic.uuid == CBUUID(string: SENDING_CHARACTERISTIC) { //send
                SendStartCmd (peripheral, characteristic: characteristic)


            }
            if characteristic.uuid == CBUUID(string: RECEIVING_CHARACTERISTIC) { //recieve
                peripheral.setNotifyValue (true, for: characteristic)
            }
        }
    }

    func SendStartCmd (_ peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        print("send satrt")
        bp = peripheral
        let cmd = Data(bytes: [0xFD, 0xFD, 0xFA, 0x05, 0x0D, 0x0A])
        peripheral.writeValue (cmd, for: characteristic, type: .withResponse)
    }

    //send packet to BLE device
    func peripheral (_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            print ("didUpdateNotificationStateForCharacteristic error: \( characteristic.uuid) -  \( error!.localizedDescription)")
            return
        }

    }
    
    //recieve packet from BLE device
    func peripheral (_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            print ("didUpdateValueForCharacteristic error: \( characteristic.uuid) -  \( error!.localizedDescription)")
            return
        }

        if characteristic.uuid == CBUUID (string: RECEIVING_CHARACTERISTIC) {
            processBPData (characteristic.value!, peripheral: peripheral)

        }
    }

    func processBPData (_ data: Data, peripheral: CBPeripheral) {
        print(data.count)
        if data.count < 6 { //如果packet 數目小於6 bytes
            return
        }

        if data[ 0] != 0xFD || data[ 1] != 0xFD {
            print ("not command")
            return
        }
        if data[ 2] == 0xFB {

            if ( ScanPage.isHidden == false) {
                ScanPage.isHidden = true
                view_capturing.isHidden = false
                drawCapturingBar ()
            }

            //Pressure packet
            let pressure = Int(data[3]) * 256 + Int(data[4])
            progress = pressure
            if pressure > 280 {
                return
            }
            updateProgress ()

        } else if data[ 2] == 0xFC {
            //Result packet
            //
            if percent == 100 {
                self.NextStep ()

                return
            }
            PercentLabel.text = "100%"
            percent = 100
            BPinfo.timestamp = Date ()
            BPinfo.SYS = Int (data[ 3])
            BPinfo.DIA = Int (data[ 4])
            SYS_value.text = ( "\( BPinfo.SYS)")
            DIA_value.text = ( "\( BPinfo.DIA)")
            print ("next")
            calibrateStart = false
            // BPMDoneAlert(BPinfo.SYS,BPM: BPinfo.DIA)

            print ("SYS: \( BPinfo.SYS) DIA: \( BPinfo.DIA) Heart:\( data[ 5])") // u16: 513
        } else if data[ 2] == 0xFD {
            calibrateStart = false
        }

    }

    func NextStep () {
        //update UI
        HeartView.isHidden = true
        self.navigationItem.setRightBarButton (nil, animated: false)
        closeConnection ()

        if captureMode {
            sendbp (BPinfo.SYS, dpm: BPinfo.DIA)
            //    delegate?.bpDone = true
            navigationController?.popViewController(animated: true)
        } else {
            let userDefaults = UserDefaults.standard
            userDefaults.set (BPinfo.SYS, forKey: "SYS")
            userDefaults.set (BPinfo.DIA, forKey: "DIA")
            DispatchQueue.main.asyncAfter (deadline: .now() + 1) { //1秒後
                //  self.performSegue(withIdentifier: "backToCali", sender: nil)
            }
        }
    }

    func sendbp (_ spm: Int, dpm: Int) {
        let url = "https://hi.com"
        let param = [ "systolic": spm, "diastolic": dpm]
    }



    func drawCapturingBar () {
        let Frame = CGRect (x: 0, y: 0, width: view.frame.width, height: view.frame.height - 100)
        BPCircularProgress = KYCircularProgress (frame: Frame, showProgressGuide: true)

        let radius = ( Frame.height / 2) - 100
        let center = CGPoint (x: Frame.width, y: Frame.height / 2)
        BPCircularProgress.path = UIBezierPath (arcCenter: center, radius: radius, startAngle: CGFloat (M_PI * 100 / 180), endAngle: CGFloat (-M_PI * 100 / 180), clockwise: true)
        BPCircularProgress.progress = 0
        BPCircularProgress.colors = [ UIColor(red: 62 / 255.0, green: 124 / 255.0, blue: 214 / 255.0, alpha: 1.0)]
        BPCircularProgress.progressGuideColor = UIColor (red: 0.82, green: 0.83, blue: 0.83, alpha: 1.0)
        //       BPCircularProgress.progressGuideColor = UIColor(red:0.1, green:0.1, blue:0.1, alpha:0.6)
        BPCircularProgress.guideLineWidth = 17
        BPCircularProgress.lineWidth = 17
        BPCircularProgress.progress = 0

        //    view_capturing.addSubview (BPCircularProgress)
        view_capturing.insertSubview (BPCircularProgress, belowSubview: PercentLabel)
        view_capturing.bringSubview (toFront: PercentLabel)
        //   self.ScanPage.addSubview(BPCircularProgress)

    }
    func updateProgress () {
        print("\(progress)")
        let normalizedProgress = Double (Float (progress) / Float (280))
        HeartView.isHidden = Int(progress) % 2 == 0 ? true : false
        if BPCircularProgress != nil {
            BPCircularProgress.progress = normalizedProgress
            print("\(normalizedProgress)%")
        }
        percent += 0.6
        percent = min (90, percent)
        PercentLabel.text = ( "\(Int (percent))%")
    }

}



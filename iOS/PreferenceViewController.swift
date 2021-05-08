import UIKit
import ARKit
final class PreferenceViewController: UIViewController {
    @IBOutlet private weak var urlField: UITextField?
    @IBOutlet private weak var streamNameField: UITextField?
    @IBOutlet private weak var formatFiled: UITextField?
    @IBOutlet private weak var scaleField: UITextField?

    @IBOutlet weak var optionsLabel: UILabel!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // read configrations
        let fileURL = NSHomeDirectory() + Preference.defaultInstance.configFileDir
        //reading from config file, if any
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fileURL) {
            let configs = NSArray(contentsOfFile: fileURL) as! [String]
            Preference.defaultInstance.uri = configs[0]
            Preference.defaultInstance.streamName = configs[1]
            Preference.defaultInstance.captureMode = configs[2]
            Preference.defaultInstance.encodeScale = configs[3]
        }
        
        urlField?.text = Preference.defaultInstance.uri
        streamNameField?.text = Preference.defaultInstance.streamName
        formatFiled?.text = Preference.defaultInstance.captureMode
        scaleField?.text = Preference.defaultInstance.encodeScale
        optionsLabel.text = "(\(ARWorldTrackingConfiguration.supportedVideoFormats.count) options availble)"
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // save configrations

        // make dictinary
        let configs = NSArray(objects: Preference.defaultInstance.uri!,Preference.defaultInstance.streamName!,Preference.defaultInstance.captureMode!,Preference.defaultInstance.encodeScale!)

        let fileURL = NSHomeDirectory() + Preference.defaultInstance.configFileDir
        //writing
        configs.write(toFile: fileURL, atomically: false)

    }
}

extension PreferenceViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if urlField == textField {
            Preference.defaultInstance.uri = textField.text
        }
        if streamNameField == textField {
            Preference.defaultInstance.streamName = textField.text
        }
        if formatFiled == textField {
            Preference.defaultInstance.captureMode = textField.text
        }
        if scaleField == textField {
            Preference.defaultInstance.encodeScale = textField.text
        }
        textField.resignFirstResponder()
        return true
    }
}

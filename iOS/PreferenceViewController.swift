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
        urlField?.text = Preference.defaultInstance.uri
        streamNameField?.text = Preference.defaultInstance.streamName
        formatFiled?.text = Preference.defaultInstance.captureMode
        scaleField?.text = Preference.defaultInstance.encodeScale
        optionsLabel.text = "(\(ARWorldTrackingConfiguration.supportedVideoFormats.count) options availble)"
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

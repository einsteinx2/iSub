//
//  SubsonicServerEditViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

protocol ServerEditDelegate {
    func serverEdited(_ server: Server)
}

class SubsonicServerEditViewController: UIViewController, UITextFieldDelegate {
    var delegate: ServerEditDelegate?
    
    var server: Server?
    
    fileprivate var statusLoader: StatusLoader?
    var redirectUrl: String? {
        return statusLoader?.redirectUrlString
    }
    
    fileprivate var retriedStatusLoader = false
    
    @IBOutlet weak var urlField: UITextField!
    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var legacyAuthField: UISwitch!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    init(server: Server?) {
        self.server = server
        super.init(nibName: "SubsonicServerEditViewController", bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        urlField.keyboardType = .URL
        
        self.view.frame.origin.y = 20
        
        if let server = server {
            self.urlField.text = server.url
            self.usernameField.text = server.username
            self.passwordField.text = server.password
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if server == nil {
            urlField.becomeFirstResponder()
        }
    }
    
    func checkUrl(url: String?) -> Bool {
        guard let url = url else {
            return false
        }
        
        let length = url.count
        if length == 0 {
            return false
        }
        
        if url.substring(from: length - 1) == "/" {
            urlField.text = url.substring(to: length - 1)
            return true
        }
        
        var addHttp = false
        if length < 7 {
            addHttp = true
        } else if url.substring(to: 7) != "http://" {
            if length >= 8 {
                if url.substring(to: 8) != "https://" {
                    addHttp = true
                }
            } else {
                addHttp = true
            }
        }
        
        if addHttp {
            urlField.text = "http://" + url
        }
        
        return true
    }
    
    func checkUsername(username: String?) -> Bool {
        return username != nil && username!.count > 0
    }
    
    func checkPassword(password: String?) -> Bool {
        return password != nil && password!.count > 0
    }
    
    @IBAction func cancelButtonPressed(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func saveButtonPressed(_ sender: UIButton) {
        if (!checkUrl(url: urlField.text)) {
            let alert = UIAlertController(title: "Error", message: "The URL must be in the format: http://mywebsite.com:port/folder\n\nBoth the :port and /folder are optional", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                self.urlField.becomeFirstResponder()
                self.urlField.selectAll(nil)
            }))
            self.present(alert, animated: true, completion: nil)
            return
        }
        
        if (!checkUsername(username: usernameField.text)) {
            let alert = UIAlertController(title: "Error", message: "Please enter a username", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                self.usernameField.becomeFirstResponder()
                self.usernameField.selectAll(nil)
            }))
            self.present(alert, animated: true, completion: nil)
            return
        }
        
        if (!checkPassword(password: passwordField.text)) {
            let alert = UIAlertController(title: "Error", message: "Please enter a password", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                self.passwordField.becomeFirstResponder()
                self.passwordField.selectAll(nil)
            }))
            self.present(alert, animated: true, completion: nil)
            return
        }
        
        LoadingScreen.show(withMessage: "Checking Server")
        statusLoader = StatusLoader(url: urlField.text!, username: usernameField.text!, password: passwordField.text!, legacyAuth: legacyAuthField.isOn)
        statusLoader!.completionHandler = loadingCompletionHandler
        statusLoader!.start()
    }
    
    func loadingCompletionHandler(success: Bool, error: Error?, loader: ApiLoader) {
        guard let statusLoader = statusLoader else {
            return
        }
        
        if success {
            LoadingScreen.hide()
            if let server = server {
                // Update existing server
                server.url = statusLoader.url;
                server.username = statusLoader.username;
                server.password = statusLoader.password;
                server.basicAuth = statusLoader.basicAuth;
                server.replace()
            } else {
                // Create new server
                server = ServerRepository.si.server(type: .subsonic, url: statusLoader.url, username: statusLoader.username, password: statusLoader.password, basicAuth: statusLoader.basicAuth, legacyAuth: statusLoader.legacyAuth)
            }
            
            delegate?.serverEdited(server!)
            self.dismiss(animated: true, completion: nil)
            AppDelegate.si.switchServer(to: server!, redirectUrl: redirectUrl)
        } else {
            if !retriedStatusLoader, let error = error, error.domain == iSubErrorDomain && error.code == iSubErrorCode.requiresBasicAuth.rawValue {
                var basicAuth = true
                if let server = server {
                    basicAuth = !server.basicAuth
                }
                
                // Try again with basic auth (or without if the server already had it)
                self.statusLoader = StatusLoader(url: urlField.text!, username: usernameField.text!, password: passwordField.text!, legacyAuth: false, basicAuth: basicAuth)
                self.statusLoader!.completionHandler = loadingCompletionHandler
                self.statusLoader!.start()
                retriedStatusLoader = true
                return
            }
            
            LoadingScreen.hide()
            var message = ""
            var textField: UITextField?
            if let error = error, error.domain == iSubErrorDomain, error.code == iSubErrorCode.invalidCredentials.rawValue {
                message = "Either your username or password is incorrect. Please try again"
                textField = usernameField
            } else {
                message = "Either the Subsonic URL is incorrect, the Subsonic server is down, or you may be connected to Wifi but do not have access to the outside Internet.\n\nError: \(String(describing: error))"
                textField = urlField
            }
            
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                textField?.becomeFirstResponder()
                textField?.selectAll(nil)
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        _ = urlField.resignFirstResponder()
        _ = usernameField.resignFirstResponder()
        _ = passwordField.resignFirstResponder()
        
        if textField == urlField {
            usernameField.becomeFirstResponder()
        } else if textField == usernameField {
            passwordField.becomeFirstResponder()
        } else if textField == passwordField {
            saveButtonPressed(saveButton)
        }
        
        return true
    }
    
    // This dismisses the keyboard when any area outside the keyboard is touched
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        _ = urlField.resignFirstResponder()
        _ = usernameField.resignFirstResponder()
        _ = passwordField.resignFirstResponder()
        super.touchesBegan(touches, with: event)
    }
}

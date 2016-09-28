//
//  WebViewController.swift
//  ImpressToConnection
//
//  Created by James Rhodes on 9/28/16.
//  Copyright © 2016 James Rhodes. All rights reserved.
//

import UIKit
import WebKit
import SnapKit

final class WebViewController: UIViewController {
    
    private var siteTitle: String
    private var urlString: String
    private var cookies: [NSHTTPCookie]?
    
    private let kEstimatedProgressKey = "estimatedProgress"
    private let kBackKey = "canGoBack"
    private let kForwardKey = "canGoForward"
    private let kLoadingKey = "loading"
    
    lazy var webView: WKWebView = {
        let _webView = WKWebView(frame: .zero, configuration: self.webConfiguration)
 
        _webView.navigationDelegate = self
        _webView.UIDelegate = self
        
        self.view.addSubview(_webView)
        return _webView
    }()
    
    lazy var webConfiguration: WKWebViewConfiguration = {
        let _webViewConfiguration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        
        var scriptString = ""
        if let cookies = self.cookies {
            for cookie in cookies {
                let name = cookie.name
                let value = cookie.value
                scriptString = scriptString + "document.cookie = '\(name)=\(value)';"
            }
        }
        
        let cookiesScript = WKUserScript(source: scriptString, injectionTime: .AtDocumentStart, forMainFrameOnly: false)
        userContentController.addUserScript(cookiesScript)
        _webViewConfiguration.userContentController = userContentController
        
        return _webViewConfiguration
    }()
    
    private var webViewContext = UnsafePointer<Void>(bitPattern: 0x10)
    
    private lazy var doneButton: UIBarButtonItem = {
        let _button = UIBarButtonItem(title: "Done", style: .Done, target: self, action: #selector(WebViewController.dismiss))
        _button.setTitleTextAttributes([NSForegroundColorAttributeName : UIColor.blueColor()], forState: .Normal)
        
        return _button
    }()
    
    private lazy var refreshButton: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .Refresh, target: self, action: #selector(WebViewController.reload))
    }()
    
    private lazy var stopButton: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .Stop, target: self, action: #selector(WebViewController.stop))
    }()
    
    private lazy var backButton: UIBarButtonItem = {
//        let _button = UIBarButtonItem(title: String.fontAwesomeIconWithName(.ChevronLeft), style: .Plain, target: self, action: #selector(WebViewController.back))
//        _button.setTitleTextAttributes([NSFontAttributeName : UIFont.fontAwesomeOfSize(UIFontTheme.FontSize.Default.rawValue)], forState: .Normal)
        
        let _button = UIBarButtonItem(title: "<", style: .Plain, target: self, action: #selector(WebViewController.back))
        
        return _button
    }()
    
    private lazy var forwardButton: UIBarButtonItem = {
//        let _button = UIBarButtonItem(title: String.fontAwesomeIconWithName(.ChevronRight), style: .Plain, target: self, action: #selector(WebViewController.forward))
//        _button.setTitleTextAttributes([NSFontAttributeName : UIFont.fontAwesomeOfSize(UIFontTheme.FontSize.Default.rawValue)], forState: .Normal)
        let _button = UIBarButtonItem(title: ">", style: .Plain, target: self, action: #selector(WebViewController.forward))
        
        return _button
    }()
    
    lazy var progressBar: UIProgressView = {
        let _progressBar = UIProgressView(progressViewStyle: .Bar)
        _progressBar.hidden = true
        _progressBar.alpha = 0.0
        _progressBar.tintColor = UIColor.blueColor()
        _progressBar.trackTintColor = UIColor.lightGrayColor()
        self.navigationController?.navigationBar.addSubview(_progressBar)
        
        return _progressBar
    }()
    
    init(urlString: String, siteTitle: String, cookies: [NSHTTPCookie]? = nil) {
        self.urlString = urlString
        self.siteTitle = siteTitle
        self.cookies = cookies
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = siteTitle
        navigationController?.toolbar.tintColor = UIColor.blueColor()
        navigationController?.toolbar.barTintColor = UIColor.lightGrayColor()
        navigationController?.toolbarHidden = false
        //navigationItem.leftBarButtonItem = doneButton
        updateToolbarButtons(false)
        
        backButton.enabled = false
        forwardButton.enabled = false
        
        webView.addObserver(self, forKeyPath: kEstimatedProgressKey, options: .New, context: &webViewContext)
        webView.addObserver(self, forKeyPath: kBackKey, options: .New, context: &webViewContext)
        webView.addObserver(self, forKeyPath: kForwardKey, options: .New, context: &webViewContext)
        webView.addObserver(self, forKeyPath: kLoadingKey, options: .New, context: &webViewContext)
        
        loadRequest()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        progressBar.alpha = 0.0
        progressBar.hidden = false
        animateProgressBarHiddenState(false)
    }
    
    func loadRequest() {
        guard let url = NSURL(string: urlString) else { return }
        let mRequest = NSMutableURLRequest(URL: url)
        mRequest.setValue("http://m.ishopaway.com", forHTTPHeaderField: "Referer")
        
        if let cookies = cookies {
            for cookie in cookies {
                let header = NSHTTPCookie.requestHeaderFieldsWithCookies([cookie])
                if let cookieHeader = header["Cookie"] {
                    mRequest.addValue(cookieHeader, forHTTPHeaderField: "Cookie")
                }
            }
        }
        webView.loadRequest(mRequest)
    }
    
    deinit {
        webView.navigationDelegate = nil
        
        webView.removeObserver(self, forKeyPath: kEstimatedProgressKey)
        webView.removeObserver(self, forKeyPath: kBackKey)
        webView.removeObserver(self, forKeyPath: kForwardKey)
        webView.removeObserver(self, forKeyPath: kLoadingKey)
    }
    
    override func viewDidLayoutSubviews() {
        webView.snp_updateConstraints { (make) in
            make.top.equalTo(topLayoutGuide)
            make.leading.trailing.bottom.equalTo(view)
        }
        
        progressBar.snp_updateConstraints { (make) in
            if let navBar = navigationController?.navigationBar {
                make.top.equalTo(navBar.snp_bottom)
            }
            make.leading.trailing.equalTo(view)
        }
        
        super.viewDidLayoutSubviews()
    }
    
    func dismiss() {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if context == &webViewContext {
            if keyPath == kEstimatedProgressKey {
                let progress = webView.estimatedProgress
                
                if progress <= 0 || progress >= 1 {
                    animateProgressBarHiddenState(true)
                    progressBar.setProgress(Float(progress), animated: false)
                } else {
                    animateProgressBarHiddenState(false)
                    progressBar.setProgress(Float(progress), animated: true)
                }
            } else if keyPath == kBackKey {
                backButton.enabled = webView.canGoBack
            } else if keyPath == kForwardKey {
                forwardButton.enabled = webView.canGoForward
            } else if keyPath == kLoadingKey {
                updateToolbarButtons(true)
            }
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
    
    func animateProgressBarHiddenState(hidden: Bool) {
        UIView.animateWithDuration(0.2) {
            self.progressBar.alpha = (hidden) ? 0.0 : 1.0
        }
    }
    
    // MARK: - Target Action
    
    func back() {
        webView.goBack()
    }
    
    func forward() {
        webView.goForward()
    }
    
    func reload() {
        guard webView.loading == false else {
            return
        }
        
        if let url = webView.URL {
            webView.loadRequest(NSURLRequest(URL: url))
            updateToolbarButtons(false)
        }
    }
    
    func stop() {
        guard webView.loading == true else {
            return
        }
        
        webView.stopLoading()
    }
}

final class WebsiteSquelcher {
    static let blockedURLSuffixes: [String] = []
    
    private static func isBlacklisted(urlString: String) -> Bool {
        for blockedURLSuffix in blockedURLSuffixes {
            if urlString.hasSuffix(blockedURLSuffix) {
                return true
            }
        }
        return false
    }
    
    static func shouldSquelchURL(request: NSURLRequest) -> WKNavigationActionPolicy {
        if let urlString = request.URL?.absoluteString {
            if isBlacklisted(urlString) {
                return WKNavigationActionPolicy.Cancel
            } else {
                return WKNavigationActionPolicy.Allow
            }
        } else {
            return WKNavigationActionPolicy.Allow
        }
    }
}

extension WebViewController: WKNavigationDelegate {
    
    func webView(webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: NSError) {
        if error.code != NSURLErrorCancelled {
            //let errorToPresent = Error(title: "We’re sorry!", message: error.localizedDescription, actions: nil)
            //let errorView = ErrorView(error: errorToPresent)
            //let modalController = ModalController(modalContentView: errorView)
            //presentViewController(modalController, animated: true, completion: nil)
        }
    }
    
    func webView(webView: WKWebView, decidePolicyForNavigationAction navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) {
        let request = navigationAction.request
        let policy = WebsiteSquelcher.shouldSquelchURL(request)
        decisionHandler(policy)
    }
}

extension WebViewController: WKUIDelegate {
    
    func webView(webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: () -> Void) {
        let controller = UIAlertController(title: message, message: nil, preferredStyle: .Alert)
        
        controller.addAction(UIAlertAction(title: "Ok", style: .Cancel) { _ in
            completionHandler()
            })
        
        presentViewController(controller, animated: true, completion: nil)
    }
    
    func webView(webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: (Bool) -> Void) {
        let controller = UIAlertController(title: message, message: nil, preferredStyle: .Alert)
        
        controller.addAction(UIAlertAction(title: "Cancel", style: .Cancel) { _ in
            completionHandler(false)
            })
        
        controller.addAction(UIAlertAction(title: "Ok", style: .Default) { _ in
            completionHandler(true)
            })
        
        presentViewController(controller, animated: true, completion: nil)
    }
    
    func webView(webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: (String?) -> Void) {
        let controller = UIAlertController(title: prompt, message: nil, preferredStyle: .Alert)
        
        controller.addAction(UIAlertAction(title: "Submit", style: .Default) { _ in
            let text = controller.textFields?.first?.text
            
            completionHandler(text)
            })
        
        controller.addAction(UIAlertAction(title: "Cancel", style: .Cancel) { _ in
            completionHandler(nil)
            })
        
        controller.addTextFieldWithConfigurationHandler { textField in
            textField.text = defaultText
        }
        
        presentViewController(controller, animated: true, completion: nil)
    }
}

private extension WebViewController {
    
    func updateToolbarButtons(animated: Bool) {
        let fixedSpace = UIBarButtonItem(barButtonSystemItem: .FixedSpace, target: nil, action: nil)
        fixedSpace.width = 40
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil)
        
        var items = [backButton, fixedSpace, forwardButton, flexSpace]
        
        if webView.loading {
            items.append(stopButton)
        } else {
            items.append(refreshButton)
        }
        
        setToolbarItems(items, animated: animated)
    }
}
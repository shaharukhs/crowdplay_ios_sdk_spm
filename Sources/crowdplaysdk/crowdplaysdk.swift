import UIKit
import Flutter
// Used to connect plugins (only if you have plugins with iOS platform code).
import FlutterPluginRegistrant

private extension UIDevice {
    enum PushEnvironment: String {
        case unknown
        case development
        case production
    }

    var pushEnvironment: PushEnvironment {
        guard let provisioningProfile = try? provisioningProfile(),
              let entitlements = provisioningProfile["Entitlements"] as? [String: Any],
              let environment = entitlements["aps-environment"] as? String
        else {
            return .unknown
        }

        return PushEnvironment(rawValue: environment) ?? .unknown
    }

    // MARK: - Private

    private func provisioningProfile() throws -> [String: Any]? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") else {
            return nil
        }

        let binaryString = try String(contentsOf: url, encoding: .isoLatin1)

        let scanner = Scanner(string: binaryString)
        guard scanner.scanUpToString("<plist") != nil, let plistString = scanner.scanUpToString("</plist>"),
              let data = (plistString + "</plist>").data(using: .isoLatin1)
        else {
            return nil
        }

        return try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
    }
}

public class CrowdplaySdk {
    public static let shared = CrowdplaySdk()
    lazy var flutterEngine = FlutterEngine(name: "CrowdPlay Flutter engine")
    private var apiKeyChannel: FlutterMethodChannel?
    var flutterViewController: FlutterViewController?
    private var apiKey = ""
    private var notificationToken = "";
    private var authToken = "";
    private var appUrlScheme = "";

    private init() {}

    public func initialize(apiKey: String, appUrlScheme: String) {
        if (self.apiKey != "") {
            print("CrowdPlay has already been initialized")
            return;
        }

        self.apiKey = apiKey;
        self.appUrlScheme = appUrlScheme;
        
        flutterEngine.run();
        
        apiKeyChannel = FlutterMethodChannel(name: "crowdplay.flutter", binaryMessenger: flutterEngine.binaryMessenger)
        apiKeyChannel!.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            if call.method == "initialization" {
              result(self.apiKey)
            } else if call.method == "CLOSE_CROWDPLAY" {
                self.flutterViewController?.dismiss(animated: true);
            } else if call.method == "getNativeNotificationToken" {
                result(self.notificationToken);
            } else if call.method == "getApnsMode" {
                result(UIDevice.current.pushEnvironment == .development ? "development" : "production");
            } else if call.method == "getAuthToken" {
                result(self.authToken);
            } else if call.method == "getUrlScheme" {
                result(self.appUrlScheme);
            }
        }
        // Used to connect plugins (only if you have plugins with iOS platform code).
        GeneratedPluginRegistrant.register(with: self.flutterEngine);
    }
    
    public func viewController() -> FlutterViewController {
        if (flutterViewController != nil) {
            return flutterViewController!;
        }

        flutterViewController = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
        flutterViewController?.modalPresentationStyle = .fullScreen
        return flutterViewController!
    }

    public func presentCrowdplay(vc: UIViewController) {
        vc.present(viewController(), animated: true, completion: nil)
    }

    public func handleNotification(userInfo: [AnyHashable : Any]?, vc: UIViewController) -> Bool {
        print("handleNotification" + (userInfo?.description ?? ""));
        if userInfo == nil || apiKeyChannel == nil {
            print("No userInfo or apiKeyChannel");
            return false
        }
        if userInfo!["custom"] == nil {
            print("Source is not crowdplay 1");
            return false
        }

        if userInfo!["custom"] as? Dictionary<AnyHashable, Any> == nil {
            print("Source is not crowdplay 2");
            return false
        }
        
        let custom = userInfo!["custom"] as! Dictionary<AnyHashable, Any>;
        
        if custom["a"] as? Dictionary<AnyHashable, Any> == nil {
            print("Source is not crowdplay 3");
            return false
        }
        
        let customApns = custom["a"] as! Dictionary<AnyHashable, Any>;
        
        if customApns["source"] as? String == nil {
            print("Source is not crowdplay 4");
            return false
        }
        
        let source = customApns["source"] as! String;
        
        if source != "crowdplay" {
            print("Source is not crowdplay 5");
            return false
        }

        self.presentCrowdplay(vc: vc);
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.apiKeyChannel!.invokeMethod("handleNotification", arguments: customApns);
        }

        return true
    }

    public func setNotificationToken(deviceToken: Data) {
        let tokenString = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})

        self.notificationToken = tokenString;
        print("Device Token: " + tokenString);

        apiKeyChannel!.invokeMethod("setNotificationToken", arguments: tokenString);
    }

    public func setAuthToken(authToken: String) {
        self.authToken = authToken;

        if (flutterViewController != nil) {
            apiKeyChannel!.invokeMethod("performTokenLogin", arguments: authToken);
        }
    }
}


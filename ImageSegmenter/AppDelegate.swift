import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // Configure and enable console logging - using multiple methods to ensure it works
    setenv("OS_ACTIVITY_MODE", "disable", 1)
    setenv("OS_ACTIVITY_DT_MODE", "YES", 1)
    setenv("CFLOG_LEVEL", "DEBUG", 1)

    // Force stderr to be unbuffered
    setvbuf(stderr, nil, _IONBF, 0)

    // Critical log messages to try to break through any filtering
    fputs("DIRECT CONSOLE OUTPUT: App starting via fputs\n", stderr)
    NSLog("=========== APP STARTING - NSLOG ===========")
    print("=========== APP STARTING - PRINT ===========")

    // Log app launch via our logger
    DebugLogger.info("Application launched with options: \(String(describing: launchOptions))")

    // Add a sync point that ensures logs are flushed
    fflush(stdout)
    fflush(stderr)

    // Override point for customization after application launch.
    return true
  }

  // MARK: UISceneSession Lifecycle

  func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
  }

  func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
  }

}

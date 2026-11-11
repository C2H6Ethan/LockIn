# All rules live in one framework-free core package

Every rule (which Tasks are due, whether to Shield, streak math) lives in a local Swift package, `LockInCore`. It has no UIKit, SwiftUI, FamilyControls or WidgetKit dependency, and every target links it: the app, all extensions and the widget. In v1/v2 the app and the DeviceActivityMonitor extension each kept their own copy of the shield logic. A category-blocking change landed in the app copy only, so blocking at midnight broke, and the ~500 tests never caught it because they covered only the app copy. Thin adapters over Apple frameworks (ManagedSettings, DeviceActivity, notifications, App Group persistence) live in a second library, `LockInPlatform`, in the same package. They are shared by every target that needs them and hold no rules.

## Considered Options

- Sharing source files via Xcode target membership (the v1/v2 approach) was rejected because it hides dependencies and drags framework imports into extensions.

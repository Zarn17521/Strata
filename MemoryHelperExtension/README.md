# ZN Experimental Memory Helper

This ExtensionKit target requires iOS 26 or later and uses an app extension point with XPC sessions. The diagnostic is opt-in and requests one 128 MiB shared-memory region. It verifies a marker written by the helper, checks that the helper PID differs from the host PID, and releases the mapping and helper allocation when the test ends or its session is invalidated. Requests time out after five seconds. The test stops if host process headroom is below 768 MiB or the reported thermal state is serious or critical.

The shared region is diagnostic only. Existing NxNative executables have no integration with this allocator and cannot use the region without changes to their own memory management. This helper does not change iOS memory limits. SideStore installation must preserve and sign the embedded ExtensionKit extension, which needs on-device confirmation.

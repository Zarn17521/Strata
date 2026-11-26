import ExtensionFoundation

/// Mirrors the host app's extension-point definition so this framework can
/// pass the declared point directly to ExtensionFoundation instead of asking
/// Launch Services to look it up by name at runtime.
@available(iOS 26.0, *)
extension AppExtensionPoint {
    @Definition
    static var znMemoryHelperForRuntime: AppExtensionPoint {
        Name("ZNMemoryHelper")
        EnhancedSecurity()
    }
}

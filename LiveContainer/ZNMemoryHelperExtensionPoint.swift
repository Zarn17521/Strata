import ExtensionFoundation

@available(iOS 26.0, *)
extension AppExtensionPoint {
    @Definition
    static var znMemoryHelper: AppExtensionPoint {
        Name("ZNMemoryHelper")
        EnhancedSecurity()
    }
}

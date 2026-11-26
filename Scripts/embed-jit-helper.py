#!/usr/bin/env python3
"""Assemble a headless JIT extension from the shared helper binary and resources."""
from pathlib import Path
import os, plistlib, shutil, subprocess, sys
if len(sys.argv) != 3:
    raise SystemExit('Usage: embed-jit-helper.py APP_BUNDLE PRODUCT_BUNDLE_IDENTIFIER')
app = Path(sys.argv[1])
bundle_identifier = sys.argv[2].strip()
if not bundle_identifier or any(part == '' for part in bundle_identifier.split('.')):
    raise SystemExit('PRODUCT_BUNDLE_IDENTIFIER is empty or invalid.')
source = app / 'PlugIns/ShareExtension.appex'
if not source.is_dir():
    raise SystemExit('ShareExtension must be built before assembling JITHelper.')
target = app / 'PlugIns/JITHelper.appex'
if target.exists(): shutil.rmtree(target)
shutil.copytree(source, target, symlinks=True)
p = target / 'Info.plist'
info = plistlib.loads(p.read_bytes())
info['CFBundleIdentifier'] = bundle_identifier + '.JITHelper'
info['CFBundleDisplayName'] = 'Strata JIT Helper'
info['NSLocalNetworkUsageDescription'] = 'Connect to your local development tunnel to enable JIT.'
info['NSExtension'] = {
    'NSExtensionPointIdentifier': 'com.apple.ar.viewer',
    'NSExtensionPrincipalClass': 'StrataJITRequestHandler',
    'NSExtensionAttributes': {'NSExtensionActivationRule': 'FALSEPREDICATE'},
    'NSExtensionContextClass': 'NSExtensionContext',
    'NSExtensionContextHostClass': 'NSExtensionContext',
}
p.write_bytes(plistlib.dumps(info))
identity = os.environ.get('EXPANDED_CODE_SIGN_IDENTITY', '-')
if os.environ.get('CODE_SIGNING_ALLOWED') != 'NO':
    subprocess.run(['codesign', '--force', '--sign', identity or '-', '--preserve-metadata=entitlements', str(target)], check=True)
runtime_source = Path(__file__).resolve().parents[1] / 'Resources/BundledRuntime'
runtime_target = app / 'BundledRuntime'
if runtime_target.exists(): shutil.rmtree(runtime_target)
shutil.copytree(runtime_source, runtime_target)
print('Assembled headless Strata JIT helper and bundled LiveExec32 runtime.')

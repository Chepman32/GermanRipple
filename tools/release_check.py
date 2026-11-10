#!/usr/bin/env python3
"""Fail closed on unconfigured integrations and missing editorial release evidence."""
from pathlib import Path
import json,re,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
def main():
    failures=[]
    config=(ROOT/'project.yml').read_text()
    firebase=ROOT/'App/Resources/GoogleService-Info.plist'
    if not firebase.exists():failures.append('Real matching Firebase configuration is missing.')
    else:
        try:
            if sys.platform=='darwin':
                data=json.loads(subprocess.check_output(['/usr/bin/plutil','-convert','json','-o','-',str(firebase)],stderr=subprocess.PIPE))
            else:
                import plistlib
                data=plistlib.loads(firebase.read_bytes())
            if data.get('BUNDLE_ID')!='app.ripple.grammar' or not data.get('GOOGLE_APP_ID') or not data.get('PROJECT_ID'):
                failures.append('Firebase configuration does not match the Ripple app.')
        except (ValueError,ImportError,subprocess.CalledProcessError):failures.append('Firebase configuration could not be parsed as a valid plist.')
    for key in ['RippleContentBaseURL','RipplePrivacyURL','RippleSupportURL']:
        if not re.search(rf'{key}:\s*[\"\x27]?https://[^\s\"\x27]+',config):failures.append(key+' must be a real HTTPS URL in project.yml.')
    if not re.search(r'DEVELOPMENT_TEAM:\s*[A-Z0-9]{10}\s',config):failures.append('Apple signing team has not been configured.')
    result=subprocess.run([sys.executable,str(ROOT/'tools/ripplec.py'),'--check','--release'],cwd=ROOT)
    if result.returncode:failures.append('Content requires current native-speaker and audio sign-offs.')
    pack=json.loads((ROOT/'content/source/pack.json').read_text())
    if len(pack['lexicon'])<850:failures.append(f'Vocabulary breadth is {len(pack["lexicon"])} lemmas; expand toward the PDS target of about 900.')
    evidence=ROOT/'content/review/release-evidence.json'
    checks=['realAppleSignInAndDeletion','firestoreAppCheckEnforced','sandboxPurchases','privacyPolicyPublished','privacyLegalReviewed','physicalDeviceVoiceOver','physicalDevicePerformance','nativeContentReviewed','betaCrashFreeTarget','signedDistributionArchive','diagnosticsDeliveryVerified']
    data=json.loads(evidence.read_text()) if evidence.exists() else {}
    for key in checks:
        if data.get(key) is not True:failures.append('Release evidence required: '+key)
    if failures:
        print('\n'.join('BLOCKED: '+item for item in failures));return 1
    print('Repository release requirements are satisfied. Confirm App Store metadata and manual release checks.');return 0
if __name__=='__main__':sys.exit(main())

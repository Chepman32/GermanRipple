#!/usr/bin/env python3
"""Generate a bounded allowlist for the authored rule map. Never deploys."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
def main():
    ids=[r['id'] for r in json.loads((ROOT/'content/source/pack.json').read_text())['rules']]
    content='''rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function owner(uid) { return request.auth != null && request.auth.uid == uid; }
    function validProfile(data) {
      return data.keys().hasAll(['createdAt','updatedAt','uiLanguage','schemaVersion'])
        && data.keys().hasOnly(['createdAt','updatedAt','uiLanguage','schemaVersion'])
        && data.createdAt is timestamp && data.updatedAt == request.time
        && data.uiLanguage == 'en' && data.schemaVersion == 1;
    }
    // A complete document must fit Firestore's 1,000-expression limit.
    // The server enforces ownership, schema and the authored rule allowlist.
    // All per-rule values are strictly decoded and validated by SyncKit on
    // upload and before import. Learning data never grants Pro entitlements.
    function validRules(data) {
      return data is map && data.size() <= 51 && data.keys().hasOnly(RULE_IDS);
    }
    function validStreak(data) {
      return data is map && data.keys().hasAll(['recent','archived'])
        && data.keys().hasOnly(['recent','archived'])
        && data.recent is map && data.recent.size() <= 400
        && data.archived is map && data.archived.size() <= 256;
    }
    match /users/{uid} {
      allow read, delete: if owner(uid);
      allow create: if owner(uid) && validProfile(request.resource.data) && request.resource.data.createdAt == request.time;
      allow update: if owner(uid) && validProfile(request.resource.data) && request.resource.data.createdAt == resource.data.createdAt;
      match /progress/{packId} {
        allow read, delete: if owner(uid);
        allow create, update: if owner(uid) && packId == 'de-en'
          && request.resource.data.keys().hasAll(['schemaVersion','updatedAt','rules','chains','streak'])
          && request.resource.data.keys().hasOnly(['schemaVersion','updatedAt','rules','chains','streak'])
          && request.resource.data.schemaVersion == 2 && request.resource.data.updatedAt == request.time
          && validRules(request.resource.data.rules)
          && request.resource.data.chains is map && request.resource.data.chains.size() <= 1024
          && validStreak(request.resource.data.streak);
      }
    }
    match /reports/{reportId} {
      allow create: if request.auth != null
        && request.resource.data.keys().hasAll(['uid','chainId','step','packVersion','reason','note','createdAt'])
        && request.resource.data.keys().hasOnly(['uid','chainId','step','packVersion','reason','note','createdAt'])
        && request.resource.data.uid == request.auth.uid
        && request.resource.data.createdAt == request.time
        && request.resource.data.chainId is string && request.resource.data.chainId.size() <= 64
        && request.resource.data.step is int && request.resource.data.step >= 0 && request.resource.data.step <= 11
        && request.resource.data.packVersion is int && request.resource.data.packVersion > 0
        && request.resource.data.reason in ['other_answer_ok','answer_wrong','bad_translation','audio','other']
        && request.resource.data.note is string && request.resource.data.note.size() <= 500;
      allow read, update, delete: if false;
    }
  }
}
'''.replace('RULE_IDS',json.dumps(ids))
    (ROOT/'firebase/firestore.rules').write_text(content)
    print('Generated rules with validation for',len(ids),'authored rule IDs')
if __name__=='__main__':main()

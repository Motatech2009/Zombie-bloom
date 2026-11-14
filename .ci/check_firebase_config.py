"""Read-only production setup diagnostics. Never creates accounts or writes Firestore."""
import configparser
import json
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

cfg = configparser.ConfigParser()
cfg.read('online.cfg')
project = cfg.get('firebase', 'project_id', fallback='').strip('"')
key = cfg.get('firebase', 'api_key', fallback='').strip('"')
if not project or not key:
    print('LIVE FIREBASE: not configured; skipped')
    raise SystemExit(0)

def request(url, payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    try:
        with urlopen(Request(url, data=data, headers={'Content-Type': 'application/json'}), timeout=15) as response:
            return response.status, json.load(response)
    except HTTPError as exc:
        try: body = json.loads(exc.read())
        except ValueError: body = {}
        return exc.code, body
    except (URLError, TimeoutError):
        return 0, {'error': {'message': 'Network unavailable'}}

code, body = request('https://identitytoolkit.googleapis.com/v1/accounts:createAuthUri?key='+key,
                     {'identifier': 'setup-check@example.invalid', 'continueUri': 'https://'+project+'.firebaseapp.com'})
print('LIVE FIREBASE AUTH:', code, 'configuration reachable' if code == 200 else body.get('error', {}).get('message', 'unavailable'))
code, body = request('https://firestore.googleapis.com/v1/projects/'+project+'/databases/(default)/documents/players?pageSize=1')
if code == 200:
    print('LIVE FIRESTORE: WARNING public collection readable without login; publish the game rules')
else:
    print('LIVE FIRESTORE:', code, body.get('error', {}).get('message', 'unavailable'))
print('LIVE FIREBASE: read-only probe; email/password enablement and authenticated game rules still require end-to-end validation')

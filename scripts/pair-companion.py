#!/usr/bin/env python3
"""Claim an mx-core Companion pairing code; keep the device token off stdout."""
import argparse
import datetime
import getpass
import json
import os
from pathlib import Path
import shutil
import sys
import urllib.error
import urllib.parse
import urllib.request


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--api-base', required=True, help='https://your-api.example.com/api/v3')
    parser.add_argument('--device-name', default='chirp on Mac')
    args = parser.parse_args()
    base = args.api_base.rstrip('/')
    url = urllib.parse.urlsplit(base)
    if url.scheme != 'https' or not url.hostname or url.username or url.password or url.query or url.fragment:
        parser.error('--api-base must be a complete HTTPS URL without credentials or query parameters')
    name = args.device_name.strip()
    if not name or len(name) > 120:
        parser.error('--device-name must contain 1–120 characters')
    code = getpass.getpass('Companion 配对码（不回显）: ') if sys.stdin.isatty() else sys.stdin.readline().strip()
    body = json.dumps({'pairingCode': code.strip(), 'deviceName': name}).encode()
    request = urllib.request.Request(base + '/companion/pairings/claim', data=body,
        headers={'Content-Type': 'application/json', 'User-Agent': 'chirp/1.2.0'})
    opener = urllib.request.build_opener(NoRedirect)
    try:
        with opener.open(request, timeout=15) as response:
            device = json.load(response)['data']
        if 'companion:presence:write' not in device['scopes']:
            raise ValueError('Pairing has no presence write scope')
        config = Path.home() / '.config/chirp/config.json'
        config.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        os.chmod(config.parent, 0o700)
        previous = {}
        if config.exists():
            # Parse before touching the original; malformed files are preserved.
            previous = json.loads(config.read_text())
            suffix = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
            backup = config.with_name('config.json.backup-' + suffix)
            shutil.copy2(config, backup)
            os.chmod(backup, 0o600)
        allowed = {k: v for k, v in previous.items() if k in ('debounceSeconds', 'iconManifestUrl', 'iconBase')}
        allowed.update(endpoint=base + '/companion/presence', deviceId=device['deviceId'],
                       deviceToken=device['deviceToken'], heartbeatSeconds=30)
        temporary = config.with_name('config.json.tmp-' + str(os.getpid()))
        fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, 'w') as output:
            json.dump(allowed, output, ensure_ascii=False, indent=2)
            output.write('\n')
        os.replace(temporary, config)
        print('已配对，仅将设备令牌写入 ~/.config/chirp/config.json（0600）。点小鸟 → 立即刷新。')
    except urllib.error.HTTPError as error:
        print('配对失败：HTTP ' + str(error.code) + '，请确认配对码未过期且未使用。', file=sys.stderr)
        return 1
    except (OSError, ValueError, KeyError):
        print('配对或配置保存失败；请检查网络、响应与原配置文件。', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

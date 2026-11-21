#!/usr/bin/env python3
"""Cache planned species accounts with robots rules and host pacing respected.

This downloads public HTML only. It never installs app data, media or prose.
"""
import argparse
import json
import pathlib
import time
import urllib.error
import urllib.parse
import urllib.request
import urllib.robotparser

from collect_wikipedia_spans import ROOT
from fetch_wikimedia_wingspan_sources import AGENT, write_json

PROVIDERS = {'adw': ('animaldiversity.org', '/accounts/', 8),
             'oiseaux': ('www.oiseaux.net', '/oiseaux/', 10)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('cache', type=pathlib.Path)
    parser.add_argument('--provider', choices=list(PROVIDERS))
    parser.add_argument('--max-pages', type=int, default=0)
    args = parser.parse_args()
    if args.max_pages < 0:
        parser.error('--max-pages cannot be negative')
    plan = json.loads((ROOT / 'Docs/RegionalWingspanTargets.json').read_text())
    robots, last_request, count = {}, {}, 0
    for row in plan['targets']:
        provider = row.get('provider', 'adw')
        if args.provider and provider != args.provider:
            continue
        host, prefix, minimum_delay = PROVIDERS[provider]
        url = urllib.parse.urlparse(row['sourceURL'])
        if url.scheme != 'https' or url.hostname != host or not url.path.startswith(prefix):
            raise ValueError('Unexpected provider URL')
        directory = args.cache / provider
        directory.mkdir(parents=True, exist_ok=True)
        path = directory / (row['scientificName'].replace(' ', '_') + '.html')
        if path.exists() or path.with_suffix('.error.json').exists():
            continue
        if provider not in robots:
            request = urllib.request.Request(f'https://{host}/robots.txt', headers={'User-Agent': AGENT})
            with urllib.request.urlopen(request, timeout=40) as response:
                text = response.read().decode('utf-8')
            (directory / 'robots.txt').write_text(text)
            rules = urllib.robotparser.RobotFileParser()
            rules.parse(text.splitlines())
            robots[provider] = rules
            last_request[provider] = time.monotonic()
        rules = robots[provider]
        if not rules.can_fetch(AGENT, row['sourceURL']):
            raise ValueError('Provider robots rules disallow the planned URL')
        delay = max(minimum_delay, rules.crawl_delay(AGENT) or 0, rules.crawl_delay('*') or 0)
        time.sleep(max(0, delay - (time.monotonic() - last_request.get(provider, 0))))
        request = urllib.request.Request(row['sourceURL'], headers={'User-Agent': AGENT})
        last_request[provider] = time.monotonic()
        try:
            with urllib.request.urlopen(request, timeout=40) as response:
                body = response.read()
            temporary = path.with_suffix('.partial')
            temporary.write_bytes(body)
            temporary.replace(path)
        except urllib.error.HTTPError as error:
            # Stop on rate limiting/service failure. Never switch hosts or
            # User-Agent to evade a limit; successfully cached pages remain.
            if error.code not in [404, 410]:
                raise
            write_json(path.with_suffix('.error.json'), dict(sourceURL=row['sourceURL'],
                status=error.code, checked=time.strftime('%Y-%m-%d', time.gmtime())))
        count += 1
        print(provider, count, row['scientificName'], flush=True)
        if args.max_pages and count >= args.max_pages:
            break


if __name__ == '__main__':
    main()

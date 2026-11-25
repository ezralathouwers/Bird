#!/usr/bin/env python3
"""Small, resumable API pilot. Offline planning by default; never auto-installs.
Only explicit --execute sends images/prompts to OpenAI. No automatic retries.
"""
import argparse
import base64
import contextlib
import datetime
import fcntl
import getpass
import hashlib
import html
import io
import json
import math
import os
import re
import ssl
from pathlib import Path
import tempfile
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PLAN = ROOT / 'Docs/ArtworkAPIPilot.json'
ENDPOINT = 'https://api.openai.com/v1/images/edits'
COMPOSITION_RULES = (
    'Composition update 2026-11-25, superseding older crop/bleed or one-wing instructions: keep the ENTIRE bird and every scene element inside the canvas, '
    'with at least 6 percent transparent clearance on the RIGHT and breathing room on the other edges. '
    'Never crop a bill, tail, wingtip, foot, branch or plant at the right edge. '
    'Props must end naturally or fade to fully transparent before the canvas border. '
    'Choose either BOTH wings correctly folded or BOTH wings naturally open in a balanced pose; '
    'never spread only the far wing while the near wing stays folded. Exactly two wings total. '
    'When open, both wings must attach at homologous shoulder joints on the left and right sides of the upper torso, '
    'never on the belly, back or above/below the body. Show believable species-specific wing shape and span. '
    'Prefer an uncomplicated folded-wing posture if a dynamic scene makes the anatomy ambiguous.'
)


def sha(blob):
    return hashlib.sha256(blob).hexdigest()


def write_json(path, value):
    """Atomic local checkpoint, including before a possibly billable request."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix='.checkpoint-')
    try:
        with os.fdopen(fd, 'w') as handle:
            json.dump(value, handle, ensure_ascii=False, indent=2)
            handle.write('\n')
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def jobs(plan, root=ROOT):
    if plan['schemaVersion'] != 1 or plan['model'] != 'gpt-image-2.5-sunburst-2026-09-08':
        raise ValueError('Unsupported recipe/model: review API capabilities and prices first.')
    if plan['quality'] != 'medium' or set(plan['roles']) != {'primary', 'dynamic'}:
        raise ValueError('Pilot recipe must keep the controlled medium/two-role baseline.')
    catalog = {r['id']: r for r in json.loads((root / 'BirdingCompanion/Resources/WorldSpeciesCatalog.json').read_text())}
    manifest = json.loads((root / 'BirdingCompanion/Resources/ArtworkManifest.json').read_text())
    installed = {(r['speciesID'], r['view']) for r in manifest}
    scope = plan.get('scope', 'pilot')
    if scope == 'belgium':
        import csv
        inventory = root / plan['inventoryCSV']
        if sha(inventory.read_bytes()) != plan['inventorySHA256']:
            raise ValueError('Belgian inventory changed: rebuild and review the recipe first.')
        with inventory.open() as handle:
            allowed = {r['catalogID'] for r in csv.DictReader(handle) if r['decision'] == 'queued'}
        if {r['id'] for r in plan['species']} != allowed:
            raise ValueError('Belgian recipe does not match its audited production list.')
    elif scope == 'logbook':
        ids = plan.get('scopeSpeciesIDs', [])
        if not isinstance(ids, list) or any(not isinstance(i, str) for i in ids) or len(ids) != len(set(ids)) or set(ids) != {r['id'] for r in plan['species']} or sha(json.dumps(sorted(ids), separators=(',', ':')).encode()) != plan.get('scopeIDsSHA256'):
            raise ValueError('Logbook scope does not match its fixed species inventory.')
    elif scope != 'pilot':
        raise ValueError('Unknown production scope.')
    seen = set()
    result = []
    for species in plan['species']:
        record = catalog[species['id']]
        if record['scientificName'] != species['scientificName'] or species['id'] in seen:
            raise ValueError('Duplicate or mismatched catalog species.')
        seen.add(species['id'])
        for role, config in plan['roles'].items():
            key = species['id'].replace(':', '-') + '-' + role
            if (species['id'], role) in installed or (root / 'BirdingCompanion/Resources/Assets.xcassets' / (key + '.imageset')).exists():
                # A previously installed role is never replaced, even on reruns.
                continue
            reference = root / plan['referenceAssets'][role]
            prompt = '\n\n'.join([plan['style'],
                f"Species: {species['englishName']} ({species['scientificName']}); {species['representativePlumage']}.",
                'Diagnostic features: ' + species['fieldMarks'], config['direction'],
                'Scene: ' + species['dynamicScene'] if role == 'dynamic' else 'No props of any kind.', COMPOSITION_RULES])
            result.append(dict(key=key, id=species['id'], role=role, prompt=prompt, size=config['size'],
                reference=str(reference), referenceSHA256=sha(reference.read_bytes()),
                representativePlumage=species['representativePlumage'], referenceURL=species['referenceURL'],
                dutchName=species['dutchName']))
    if (scope == 'pilot' and len(seen) != 10) or (scope == 'belgium' and not 1 <= len(seen) <= 500) or (scope == 'logbook' and not 1 <= len(seen) <= len(catalog)):
        raise ValueError('Species count is outside the approved recipe scope.')
    return result


def payload(plan, job):
    reference = Path(job['reference']).read_bytes()
    if sha(reference) != job['referenceSHA256']:
        raise ValueError('Style reference changed after planning; no request sent.')
    return dict(model=plan['model'], quality=plan['quality'], size=job['size'], n=1,
                output_format='png', background='transparent', prompt=job['prompt'],
                images=[{'image_url': 'data:image/png;base64,' + base64.b64encode(reference).decode('ascii')}])


def usage_cost(usage, rates):
    """Conservative estimate: ignores input cache discounts; USD excluding tax."""
    details = usage.get('input_tokens_details', {})
    text, image, output = details.get('text_tokens'), details.get('image_tokens'), usage.get('output_tokens')
    if any(type(n) is not int or n < 0 for n in [text, image, output]):
        return None
    return (text * rates['textInput'] + image * rates['imageInput'] + output * rates['imageOutput']) / 1_000_000


def validate_png(blob, expected_size):
    from PIL import Image
    with Image.open(io.BytesIO(blob)) as image:
        image.load()
        if image.format != 'PNG' or image.mode != 'RGBA' or image.size != tuple(map(int, expected_size.split('x'))):
            raise ValueError('Output must be an original RGBA PNG at the requested dimensions.')
        low, high = image.getchannel('A').getextrema()
        if low != 0 or high < 220:
            raise ValueError('Output lacks usable transparent/opaque alpha.')
    # This is file QA only, NEVER anatomy, plumage, facing or no-props approval.


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None  # Never forward an API bearer token to another endpoint.


def https_opener():
    context = ssl.create_default_context()
    try:
        import certifi
    except ImportError:
        pass
    else:
        # Extend the default trust store, never disable certificate verification.
        context.load_verify_locations(certifi.where())
    return urllib.request.build_opener(NoRedirect(), urllib.request.HTTPSHandler(context=context))


def safe_failure(error):
    """Controlled diagnostic fields only: no keys, prompts or arbitrary errors."""
    result = {'exceptionType': type(error).__name__}
    if isinstance(error, urllib.error.HTTPError):
        result.update(kind='http', httpStatus=error.code,
            hint='De API heeft de aanvraag geweigerd. Controleer status, accountrechten en API-tegoed.')
        try:
            info = json.loads(error.read(32768)).get('error', {})
            for source, target in [('code', 'apiCode'), ('type', 'apiType'), ('param', 'apiParam')]:
                value = info.get(source)
                if isinstance(value, str) and re.fullmatch(r'[A-Za-z0-9_.\[\]-]{1,100}', value):
                    result[target] = value
        except (ValueError, AttributeError, OSError):
            pass
    else:
        reason = error.reason if isinstance(error, urllib.error.URLError) else error
        result['reasonType'] = type(reason).__name__
        if isinstance(reason, ssl.SSLCertVerificationError):
            result.update(kind='tls_certificate',
                hint='Python kan het HTTPS-certificaat niet verifiëren. Er is geen geldig API-antwoord ontvangen.')
        elif isinstance(reason, TimeoutError):
            result.update(kind='timeout', hint='De verbinding liep in een timeout. Controleer API Usage voordat je een beeld opnieuw aanvraagt.')
        elif isinstance(error, urllib.error.URLError) or isinstance(reason, ConnectionError):
            result.update(kind='network', hint='De HTTPS-verbinding is mislukt. De uitkomst van de aanvraag is niet bevestigd.')
        elif isinstance(error, json.JSONDecodeError):
            result.update(kind='response_json', hint='Het antwoord was geen leesbare JSON. Controleer API Usage.')
        else:
            result.update(kind='local_or_output', hint='De aanvraag of verwerking is afgebroken; controleer fase en checkpoint.')
    return result


def connection_diagnostic(opener=None):
    # Unauthenticated GET: no API key, prompt, image or paid generation request.
    request = urllib.request.Request('https://api.openai.com/v1/models', method='GET')
    try:
        with (opener or https_opener()).open(request, timeout=20) as response:
            return {'ok': True, 'httpStatus': response.status,
                'message': 'HTTPS werkt. Er is geen beeld gegenereerd en geen API-sleutel gebruikt.'}
    except urllib.error.HTTPError as error:
        if error.code == 401:
            return {'ok': True, 'httpStatus': 401,
                'message': 'HTTPS werkt. HTTP 401 is hier verwacht: deze controle gebruikt bewust geen API-sleutel.'}
        return dict(ok=False, **safe_failure(error))
    except (OSError, ValueError) as error:
        return dict(ok=False, **safe_failure(error))


def send(body, api_key):
    request = urllib.request.Request(ENDPOINT, data=body, method='POST', headers={
        'Authorization': 'Bearer ' + api_key, 'Content-Type': 'application/json'})
    with https_opener().open(request, timeout=300) as response:
        return json.load(response), response.headers.get('x-request-id')


@contextlib.contextmanager
def production_lock():
    # Same lock as the paused illustration producer, shared across pilot outputs.
    with open(Path(tempfile.gettempdir()) / 'birder-illustrations.lock', 'a') as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError('Another illustration run is active; no API request sent.') from None
        try:
            yield
        finally:
            fcntl.flock(handle, fcntl.LOCK_UN)


def validate_run_limits(plan, max_requests, spend_stop_usd):
    # Both production scopes have a fixed, validated primary/dynamic inventory.
    # The calibration pilot retains its original 20-request ceiling.
    if plan.get('scope') == 'repair':
        limit = len(plan['targets'])
    else:
        limit = 2 * len(plan['species']) if plan.get('scope') in ('belgium', 'logbook') else 20
    if not 1 <= max_requests <= limit or not math.isfinite(spend_stop_usd) or spend_stop_usd <= 0:
        raise ValueError(f'Use 1–{limit} requests and a positive spend stop threshold.')


def run(plan, planned, output, api_key, max_requests, spend_stop_usd, sender=send, after_save=None):
    """Stop threshold is NOT a provider billing cap; one call can exceed it."""
    validate_run_limits(plan, max_requests, spend_stop_usd)
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    state_path = output / 'state.json'
    state = json.loads(state_path.read_text()) if state_path.exists() else {'recipeSHA256': sha(json.dumps(plan, sort_keys=True).encode()), 'jobs': {}}
    if state['recipeSHA256'] != sha(json.dumps(plan, sort_keys=True).encode()):
        raise ValueError('Recipe changed: use a separate output directory for a separate experiment.')
    charged = 0.0
    for status in state['jobs'].values():
        if status['status'] == 'request_rejected':
            if (output / status['file']).exists():
                raise ValueError('Rejected request unexpectedly has an image; reconcile before retrying.')
            continue
        if status['status'] != 'generated_unreviewed' or status.get('costEstimateUSD') is None:
            raise ValueError('Previous request needs manual reconciliation; it will not be retried automatically.')
        path = output / status['file']
        if not path.is_file() or sha(path.read_bytes()) != status['outputSHA256']:
            raise ValueError('Checkpoint image is missing/changed; refusing to regenerate and charge again.')
        charged += status['costEstimateUSD']
    sent = 0
    for job in planned:
        previous = state['jobs'].get(job['key'])
        if previous and previous['status'] != 'request_rejected':
            continue
        if sent >= max_requests or charged >= spend_stop_usd:
            break
        blob = json.dumps(payload(plan, job)).encode()
        path = output / (job['key'] + '.png')
        if path.exists():
            raise ValueError('Untracked output exists; refusing overwrite or duplicate API charge.')
        status = dict(status='request_pending', file=path.name, model=plan['model'], quality=plan['quality'],
            size=job['size'], promptSHA256=sha(job['prompt'].encode()), payloadSHA256=sha(blob),
            referenceSHA256=job['referenceSHA256'], startedAt=datetime.datetime.now(datetime.timezone.utc).isoformat())
        if previous:
            state.setdefault('rejectedAttempts', []).append(dict(job=job['key'], **previous))
        state['jobs'][job['key']] = status
        write_json(state_path, state)
        started = time.monotonic()
        phase = 'transport'
        print(f"API {sent + 1}/{max_requests}: {job['dutchName']} — {job['role']}", flush=True)
        try:
            response, request_id = sender(blob, api_key)
            phase = 'response_processing'
            # Save usage even if the returned image later fails validation.
            status.update(requestID=request_id, elapsedSeconds=round(time.monotonic() - started, 3),
                          usage=response.get('usage', {}), apiCreated=response.get('created'))
            status['costEstimateUSD'] = usage_cost(status['usage'], plan['tokenRatesUSDPerMillion'])
            images = response.get('data', [])
            if len(images) != 1:
                raise ValueError('Expected exactly one API output image.')
            image = base64.b64decode(images[0]['b64_json'], validate=True)
            # Exclusive create and preserve raw originals; no image editing.
            with path.open('xb') as handle:
                handle.write(image)
            status['outputSHA256'] = sha(image)
            phase = 'output_validation'
            validate_png(image, job['size'])
            status['status'] = 'generated_unreviewed'
            write_json(state_path, state)
            sent += 1
            if after_save is not None:
                after_save(state)
            if status['costEstimateUSD'] is None:
                raise ValueError('Usage details missing: check API billing before continuing.')
            charged += status['costEstimateUSD']
        except BaseException as error:
            if status['status'] != 'generated_unreviewed':
                status['status'] = 'needs_reconciliation'
            status['failure'] = safe_failure(error)
            status['failure']['phase'] = phase
            # Only an explicit API rejection with a recognized non-generation
            # code can be retried on a later, user-initiated run. Never retry
            # timeouts, TLS/transport failures or uncertain outcomes this way.
            rejected_codes = {'rate_limit_exceeded', 'insufficient_quota', 'credit_balance_exhausted',
                              'billing_hard_limit_reached', 'invalid_api_key', 'model_not_found'}
            if (phase == 'transport' and isinstance(error, urllib.error.HTTPError)
                    and error.code in {400, 401, 403, 404, 429}
                    and status['failure'].get('apiCode') in rejected_codes):
                status['status'] = 'request_rejected'
            if isinstance(error, urllib.error.HTTPError):
                status['httpStatus'] = error.code
            write_json(state_path, state)
            summary = status['failure'].get('apiCode') or status['failure'].get('httpStatus') or status['failure']['kind']
            raise RuntimeError(f"API-proef gestopt ({summary}). {status['failure']['hint']} Checkpoint: {state_path}. Geen automatische retry.") from None
    return state


def review_files(planned, state, output):
    output = Path(output)
    reviews, cards = [], []
    for job in planned:
        status = state.get('jobs', {}).get(job['key'], {})
        if status.get('status') != 'generated_unreviewed':
            continue
        reviews.append(dict(id=job['id'], role=job['role'], path=str((output / status['file']).resolve()),
            composition='bird-only' if job['role'] == 'primary' else 'species-scene',
            referenceURL=job['referenceURL'], representativePlumage=job['representativePlumage'],
            anatomyReview=dict(sha256=status['outputSHA256'], twoWings=False, singleHeadAndBill=False,
                               poseAndFraming=False, noProps=False),
            visualReview=dict(speciesPlumage=False, styleMatch=False, transparency=False, notes=''),
            generationProvenance=dict(provider='OpenAI Images API', model=status['model'],
                requestID=status.get('requestID'), promptSHA256=status['promptSHA256'],
                referenceSHA256=status['referenceSHA256'], outputSHA256=status['outputSHA256'],
                usage=status.get('usage'), estimatedCostUSD=status.get('costEstimateUSD'),
                elapsedSeconds=status.get('elapsedSeconds'))))
        cards.append(f'<article><h2>{html.escape(job["dutchName"])} — {job["role"]}</h2>'
                     f'<a href="{status["file"]}"><img loading="lazy" decoding="async" src="{status["file"]}" alt="{html.escape(job["dutchName"], quote=True)}"></a></article>')
    # Never overwrite a review the user has already started filling in.
    template = output / 'review-template.json'
    existing = json.loads(template.read_text()) if template.exists() else []
    known = {(row['id'], row['role']) for row in existing}
    write_json(template, existing + [row for row in reviews if (row['id'], row['role']) not in known])
    (output / 'review.html').write_text('<!doctype html><meta charset="utf-8"><title>Birder API-proef</title>'
        '<style>body{background:#f5f2eb;color:#4c4b46;font:16px system-ui}main{display:flex;flex-wrap:wrap;gap:24px}'
        'article{width:340px}h2{font-size:17px}img{width:100%;height:440px;object-fit:contain}</style>'
        f'<h1>API-illustraties — nog niet goedgekeurd</h1><p>{len(cards)} van {len(planned)} kandidaten beschikbaar.</p><p>Open elk origineel op volle grootte. Controleer soort, stijl, twee vleugels, één kop/snavel, poten, houding, transparantie en randruimte. Standaardbeelden: uitsluitend de vogel, naar rechts.</p><main>' + ''.join(cards) + '</main>')


def export_reviewed(reviews_path, state, output):
    rows = json.loads(Path(reviews_path).read_text())
    accepted = []
    for row in rows:
        key = row['id'].replace(':', '-') + '-' + row['role']
        status = state['jobs'].get(key, {})
        if row['role'] not in ['primary', 'dynamic'] or status.get('status') != 'generated_unreviewed':
            raise ValueError('Review does not match a generated pilot job.')
        image = Path(output) / status['file']
        digest = sha(image.read_bytes())
        review = row['anatomyReview']
        if digest != status['outputSHA256'] or review['sha256'] != digest or Path(row['path']).resolve() != image.resolve():
            raise ValueError('Review hash/path must match the exact generated original.')
        flags = ['twoWings', 'singleHeadAndBill', 'poseAndFraming'] + (['noProps'] if row['role'] == 'primary' else [])
        if any(review.get(k) is not True for k in flags) or any(row['visualReview'].get(k) is not True for k in ['speciesPlumage', 'styleMatch', 'transparency']):
            raise ValueError('Individual visual approval is required; file QA cannot approve anatomy.')
        accepted.append(row)
    if not accepted:
        raise ValueError('No individually reviewed images selected.')
    write_json(Path(output) / 'reviewed-import.json', accepted)
    return accepted


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--diagnose', action='store_true', help='Check HTTPS without an API key or billable generation')
    parser.add_argument('--plan', type=Path, default=DEFAULT_PLAN)
    parser.add_argument('--project-root', type=Path, default=ROOT, help='Local app project supplying catalog and approved reference assets')
    parser.add_argument('--output', type=Path, default=ROOT / '.artwork-api/pilot-medium')
    parser.add_argument('--execute', action='store_true', help='Explicitly send billable API requests')
    parser.add_argument('--review-only', action='store_true', help='Refresh local review files without generating anything')
    parser.add_argument('--max-requests', type=int, default=2, help='Two-image calibration by default; at most the approved recipe job count')
    parser.add_argument('--spend-stop-usd', type=float, default=2, help='Stop before next call once estimated accumulated spend reaches this value; NOT a billing cap')
    parser.add_argument('--export-reviewed', type=Path)
    args = parser.parse_args()
    if args.diagnose:
        if args.execute or args.export_reviewed or args.review_only:
            raise ValueError('De verbindingscontrole mag niet gecombineerd worden met generatie of export.')
        print(json.dumps(connection_diagnostic(), ensure_ascii=False, indent=2))
        return
    plan = json.loads(args.plan.read_text())
    planned = jobs(plan, root=args.project_root)
    print(f"{len(planned)} missing role jobs; {plan['model']}; {plan['quality']}; transparent PNG.")
    if not args.execute and not args.export_reviewed and not args.review_only:
        print('OFFLINE PLAN: no API calls, no credits used. First execute run defaults to two images.')
        for job in planned:
            print(f"  {job['dutchName']}: {job['role']} {job['size']}")
        return
    with production_lock():
        if args.review_only:
            if args.execute or args.export_reviewed:
                raise ValueError('Review-only cannot generate or export.')
            state = json.loads((args.output / 'state.json').read_text())
            review_files(planned, state, args.output)
            print(args.output / 'review.html')
            return
        if args.export_reviewed:
            if args.execute:
                raise ValueError('Review export cannot generate images.')
            state = json.loads((args.output / 'state.json').read_text())
            accepted = export_reviewed(args.export_reviewed, state, args.output)
            print(f'{len(accepted)} approved mappings exported. Nothing installed automatically.')
            return
        try:
            from PIL import Image  # Preflight BEFORE any billable request.
        except ImportError:
            raise ValueError('Install Pillow in a local virtual environment before executing.') from None
        validate_run_limits(plan, args.max_requests, args.spend_stop_usd)
        key = os.environ.get('OPENAI_API_KEY') or getpass.getpass('OpenAI API-sleutel (verborgen, wordt niet bewaard): ')
        if not key.strip():
            raise ValueError('No API key: no request sent.')
        state = run(plan, planned, args.output, key.strip(), args.max_requests, args.spend_stop_usd,
                    after_save=lambda checkpoint: review_files(planned, checkpoint, args.output))
        review_files(planned, state, args.output)
        print(f'Review: {args.output / "review.html"}. Nothing is automatically anatomically approved or installed.')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, RuntimeError, OSError) as error:
        raise SystemExit(str(error))

import base64
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import ssl
import urllib.error
from unittest.mock import patch
from PIL import Image
import artwork_api_pilot as pilot
import install_artwork_batch as installer


class ArtworkAPIPilotTests(unittest.TestCase):
    def setUp(self):
        self.plan = json.loads(pilot.DEFAULT_PLAN.read_text())
        self.jobs = pilot.jobs(self.plan)
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.output = Path(self.directory.name)
        self.calls = []

    def sender(self, body, key):
        request = json.loads(body)
        self.calls.append(request)
        image = Image.new('RGBA', tuple(map(int, request['size'].split('x'))))
        image.putpixel((20, 20), (0, 0, 0, 255))
        data = io.BytesIO()
        image.save(data, format='PNG')
        return {'data': [{'b64_json': base64.b64encode(data.getvalue()).decode()}],
                'created': 1, 'usage': {'input_tokens_details': {'text_tokens': 100, 'image_tokens': 200},
                                       'output_tokens': 3000}}, 'fixture-request'

    def execute(self, count=2, stop=2, sender=None):
        return pilot.run(self.plan, self.jobs, self.output, 'synthetic-test-key', count, stop, sender or self.sender)

    def test_exact_ten_species_twenty_distinct_roles_and_correct_style_payload(self):
        self.assertEqual(len(self.jobs), 20)
        self.assertEqual(len({(r['id'], r['role']) for r in self.jobs}), 20)
        self.assertEqual({r['role'] for r in self.jobs}, {'primary', 'dynamic'})
        self.assertEqual(self.jobs[-1]['id'], 'birdnet-v3:BN01708')
        body = pilot.payload(self.plan, self.jobs[0])
        self.assertEqual(body['background'], 'transparent')
        self.assertEqual(body['n'], 1)
        self.assertIn('facing RIGHT', body['prompt'])
        self.assertTrue(body['images'][0]['image_url'].startswith('data:image/png;base64,'))

    def test_default_cli_is_offline(self):
        result = subprocess.run([sys.executable, str(pilot.ROOT / 'Scripts/artwork_api_pilot.py')], capture_output=True, text=True, check=True)
        self.assertIn('OFFLINE PLAN: no API calls', result.stdout)

    def test_resume_preserves_originals_and_makes_only_requested_new_calls(self):
        state = self.execute()
        self.assertEqual(len(self.calls), 2)
        first = (self.output / state['jobs'][self.jobs[0]['key']]['file']).read_bytes()
        state = self.execute(count=1)
        self.assertEqual(len(self.calls), 3)
        self.assertEqual(len(state['jobs']), 3)
        self.assertEqual((self.output / state['jobs'][self.jobs[0]['key']]['file']).read_bytes(), first)
        self.assertNotIn('synthetic-test-key', (self.output / 'state.json').read_text())
        self.assertEqual(state['jobs'][self.jobs[0]['key']]['status'], 'generated_unreviewed')

    def test_unknown_request_outcome_never_retries_on_resume(self):
        def interrupted(body, key):
            self.calls.append(body)
            raise TimeoutError('synthetic-test-key must not enter checkpoint')
        with self.assertRaises(RuntimeError):
            self.execute(sender=interrupted)
        with self.assertRaises(ValueError):
            self.execute(sender=interrupted)
        self.assertEqual(len(self.calls), 1)
        self.assertNotIn('synthetic-test-key', (self.output / 'state.json').read_text())

    def test_certificate_failure_is_saved_without_saving_exception_secrets(self):
        def certificate_failure(body, key):
            raise urllib.error.URLError(ssl.SSLCertVerificationError(1, 'synthetic-test-key'))
        with self.assertRaisesRegex(RuntimeError, 'tls_certificate'):
            self.execute(sender=certificate_failure)
        checkpoint = (self.output / 'state.json').read_text()
        failure = next(iter(json.loads(checkpoint)['jobs'].values()))['failure']
        self.assertEqual(failure['kind'], 'tls_certificate')
        self.assertEqual(failure['phase'], 'transport')
        self.assertNotIn('synthetic-test-key', checkpoint)

    def test_http_error_code_is_retained_but_raw_body_is_not(self):
        error = urllib.error.HTTPError('https://api.openai.com/v1/images/edits', 400, 'bad', {},
            io.BytesIO(b'{"error":{"code":"model_not_found","message":"synthetic-test-key","type":"invalid_request_error"}}'))
        failure = pilot.safe_failure(error)
        self.assertEqual(failure['apiCode'], 'model_not_found')
        self.assertEqual(failure['httpStatus'], 400)
        self.assertNotIn('synthetic-test-key', json.dumps(failure))

    def test_connection_diagnostic_uses_only_unauthenticated_get(self):
        class ModelsProbe:
            def open(inner, request, timeout):
                self.assertEqual(request.full_url, 'https://api.openai.com/v1/models')
                self.assertEqual(request.get_method(), 'GET')
                self.assertIsNone(request.data)
                self.assertIsNone(request.get_header('Authorization'))
                raise urllib.error.HTTPError(request.full_url, 401, 'unauthorized', {}, io.BytesIO(b'{}'))
        result = pilot.connection_diagnostic(opener=ModelsProbe())
        self.assertTrue(result['ok'])
        self.assertEqual(result['httpStatus'], 401)

    def test_diagnose_and_generate_cannot_be_combined(self):
        result = subprocess.run([sys.executable, str(pilot.ROOT / 'Scripts/artwork_api_pilot.py'),
                                 '--diagnose', '--execute'], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('mag niet gecombineerd', result.stderr)

    def test_spend_stop_halts_before_next_request_and_reports_usage(self):
        state = self.execute(count=20, stop=0.01)
        self.assertEqual(len(self.calls), 1)  # One call may exceed the local stop threshold.
        cost = next(iter(state['jobs'].values()))['costEstimateUSD']
        self.assertAlmostEqual(cost, 0.0921)

    def test_explicit_quota_rejection_can_resume_without_repeating_completed_images(self):
        def quota(body, key):
            raise urllib.error.HTTPError(pilot.ENDPOINT, 429, 'quota', {},
                io.BytesIO(b'{"error":{"code":"insufficient_quota","type":"insufficient_quota"}}'))
        with self.assertRaises(RuntimeError):
            self.execute(count=1, sender=quota)
        state = json.loads((self.output / 'state.json').read_text())
        self.assertEqual(next(iter(state['jobs'].values()))['status'], 'request_rejected')
        state = self.execute(count=1)
        self.assertEqual(len(self.calls), 1)
        self.assertEqual(len(state['rejectedAttempts']), 1)
        self.assertEqual(next(iter(state['jobs'].values()))['status'], 'generated_unreviewed')

    def test_belgian_recipe_matches_audited_scope_and_skips_existing_and_pilot_images(self):
        plan = json.loads((pilot.ROOT / 'Docs/BelgiumArtworkAPIPlan.json').read_text())
        jobs = pilot.jobs(plan)
        self.assertEqual(len(plan['species']), 335)
        self.assertEqual(len(jobs), 670)
        old_pilot = {r['id'] for r in self.plan['species']}
        self.assertFalse(old_pilot & {r['id'] for r in jobs})
        self.assertEqual({r['role'] for r in jobs}, {'primary', 'dynamic'})
        self.plan, self.jobs = plan, jobs
        # A 670-image recipe is allowed, but spend stop still limits paid calls.
        self.execute(count=670, stop=0.01)
        self.assertEqual(len(self.calls), 1)
        plan['species'].pop()
        with self.assertRaises(ValueError):
            pilot.jobs(plan)

    def test_missing_usage_stops_before_more_billing(self):
        def missing(body, key):
            response, request = self.sender(body, key)
            response.pop('usage')
            return response, request
        with self.assertRaises(RuntimeError):
            self.execute(sender=missing)
        self.assertEqual(len(self.calls), 1)
        with self.assertRaises(ValueError):
            self.execute()

    def test_review_template_cannot_approve_itself_and_retains_manual_work(self):
        state = self.execute(count=1)
        pilot.review_files(self.jobs, state, self.output)
        self.assertIn('loading="lazy"', (self.output / 'review.html').read_text())
        path = self.output / 'review-template.json'
        rows = json.loads(path.read_text())
        with self.assertRaises(ValueError):
            pilot.export_reviewed(path, state, self.output)
        rows[0]['visualReview']['notes'] = 'manual note retained'
        pilot.write_json(path, rows)
        state = self.execute(count=1)
        pilot.review_files(self.jobs, state, self.output)
        self.assertEqual(len(json.loads(path.read_text())), 2)
        self.assertEqual(json.loads(path.read_text())[0]['visualReview']['notes'], 'manual note retained')
        # Explicit dummy approvals test only the exporter, not real artwork QA.
        row = rows[0]
        for flag in ['twoWings', 'singleHeadAndBill', 'poseAndFraming', 'noProps']:
            row['anatomyReview'][flag] = True
        for flag in ['speciesPlumage', 'styleMatch', 'transparency']:
            row['visualReview'][flag] = True
        pilot.write_json(path, [row])
        self.assertEqual(len(pilot.export_reviewed(path, state, self.output)), 1)
        row['anatomyReview']['sha256'] = 'wrong hash'
        pilot.write_json(path, [row])
        with self.assertRaises(ValueError):
            pilot.export_reviewed(path, state, self.output)

    def test_changed_recipe_and_existing_installed_images_are_not_replaced(self):
        self.execute(count=1)
        self.plan['quality'] = 'high'
        with self.assertRaises(ValueError):
            self.execute()
        plan = json.loads(pilot.DEFAULT_PLAN.read_text())
        # Use a temporary catalog tree to verify installed roles are skipped.
        root = self.output / 'project'
        resources = root / 'BirdingCompanion/Resources'
        resources.mkdir(parents=True)
        (resources / 'WorldSpeciesCatalog.json').write_text((pilot.ROOT / 'BirdingCompanion/Resources/WorldSpeciesCatalog.json').read_text())
        (resources / 'ArtworkManifest.json').write_text(json.dumps([{'speciesID': plan['species'][0]['id'], 'view': 'primary'}]))
        for role, reference in plan['referenceAssets'].items():
            target = root / reference
            target.parent.mkdir(parents=True)
            target.write_bytes((pilot.ROOT / reference).read_bytes())
        result = pilot.jobs(plan, root=root)
        self.assertEqual(len(result), 19)
        self.assertFalse(any(r['id'] == plan['species'][0]['id'] and r['role'] == 'primary' for r in result))

    def test_importer_checks_and_preserves_generation_provenance(self):
        state = self.execute(count=1)
        pilot.review_files(self.jobs, state, self.output)
        row = json.loads((self.output / 'review-template.json').read_text())[0]
        for flag in ['twoWings', 'singleHeadAndBill', 'poseAndFraming', 'noProps']:
            row['anatomyReview'][flag] = True  # Synthetic fixture, never real artwork.
        resources = self.output / 'resources'
        (resources / 'Assets.xcassets').mkdir(parents=True)
        pilot.write_json(resources / 'WorldSpeciesCatalog.json', [{'id': row['id']}])
        pilot.write_json(resources / 'ArtworkManifest.json', [])
        mapping = self.output / 'mapping.json'
        correct = row['generationProvenance']['outputSHA256']
        row['generationProvenance']['outputSHA256'] = 'mismatch'
        pilot.write_json(mapping, [row])
        with patch.object(installer, 'RES', resources):
            with self.assertRaises(AssertionError):
                installer.install(mapping, 'synthetic-fixture')
            self.assertEqual(list((resources / 'Assets.xcassets').iterdir()), [])
            row['generationProvenance']['outputSHA256'] = correct
            pilot.write_json(mapping, [row])
            installer.install(mapping, 'synthetic-fixture')
        installed = json.loads((resources / 'ArtworkManifest.json').read_text())[0]
        self.assertEqual(installed['generationProvenance']['requestID'], 'fixture-request')
        self.assertEqual(installed['generationProvenance']['outputSHA256'], installed['sha256'])


if __name__ == '__main__':
    unittest.main()

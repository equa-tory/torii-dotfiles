import http.client
import json
from pathlib import Path
import runpy
import tempfile
import threading
import unittest
from unittest.mock import patch

API = runpy.run_path(str(Path(__file__).resolve().parents[1] / '.config/torii/bin/torii-remote-power'))


class RemotePowerTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        state = Path(self.directory.name)
        self.scope = patch.dict(API['settings'].__globals__, STATE=state, SETTINGS=state / 'settings.json')
        self.scope.start()
        self.addCleanup(self.scope.stop)

    def test_token_persists_and_regeneration_revokes_old_value(self):
        settings = API['settings']
        first = settings()['token']
        self.assertEqual(settings('enable')['token'], first)
        self.assertEqual(settings('disable')['token'], first)
        self.assertNotEqual(settings('regenerate')['token'], first)
        self.assertEqual((Path(self.directory.name) / 'settings.json').stat().st_mode & 0o777, 0o600)

    def test_http_auth_method_path_disable_and_rotation(self):
        settings = API['settings']
        token = settings('enable')['token']
        calls = []
        with patch.dict(API['Handler'].do_POST.__globals__, poweroff=lambda: calls.append('poweroff')):
            server = API['HTTPServer'](('127.0.0.1', 0), API['Handler'])
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                def request(method, path='/shutdown', secret=token):
                    connection = http.client.HTTPConnection('127.0.0.1', server.server_port, timeout=3)
                    connection.request(method, path, headers={'Authorization': 'Bearer ' + secret})
                    response = connection.getresponse()
                    status = response.status
                    response.read()
                    connection.close()
                    return status
                self.assertEqual(request('GET'), 405)
                self.assertEqual(request('POST', secret='wrong'), 401)
                self.assertEqual(request('POST', '/other'), 404)
                self.assertEqual(calls, [])
                self.assertEqual(request('POST'), 202)
                self.assertEqual(calls, ['poweroff'])
                settings('regenerate')
                self.assertEqual(request('POST'), 401)
                new_token = settings()['token']
                settings('disable')
                self.assertEqual(request('POST', secret=new_token), 503)
                self.assertEqual(calls, ['poweroff'])
            finally:
                server.shutdown()
                server.server_close()
                thread.join()


if __name__ == '__main__':
    unittest.main()

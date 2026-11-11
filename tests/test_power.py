from pathlib import Path
import runpy
import subprocess
import unittest
from unittest.mock import Mock, patch

API = runpy.run_path(str(Path(__file__).resolve().parents[1] / '.config/torii/bin/torii-power'))


class PowerTest(unittest.TestCase):
    def test_poweroff_is_queued_outside_graphical_session(self):
        with patch.object(API['subprocess'], 'run') as run:
            API['main']([])
        command = run.call_args.args[0]
        self.assertEqual(command[:2], ['systemd-run', '--user'])
        self.assertIn('--unit=torii-poweroff', command)
        self.assertEqual(command[-1], '--execute')

    def test_desktop_stops_before_poweroff(self):
        with patch.object(API['subprocess'], 'run', side_effect=[Mock(returncode=0), Mock(returncode=0), Mock(returncode=3), Mock(returncode=0)]) as run:
            with patch.object(API['shutil'], 'which', return_value='/usr/bin/uwsm'):
                API['execute']()
        commands = [call.args[0] for call in run.call_args_list]
        self.assertEqual(commands[1], ['uwsm', 'stop'])
        self.assertEqual(commands[-1], ['systemctl', 'poweroff'])

    def test_stop_timeout_still_requests_normal_shutdown(self):
        with patch.object(API['subprocess'], 'run', side_effect=[Mock(returncode=0), subprocess.TimeoutExpired('uwsm', 30), Mock(returncode=0)]) as run:
            with patch.object(API['shutil'], 'which', return_value='/usr/bin/uwsm'):
                API['execute']()
        self.assertEqual(run.call_args.args[0], ['systemctl', 'poweroff'])

    def test_without_desktop_powers_off_directly(self):
        with patch.object(API['subprocess'], 'run', side_effect=[Mock(returncode=3), Mock(returncode=0)]) as run:
            API['execute']()
        self.assertEqual(run.call_count, 2)
        self.assertEqual(run.call_args.args[0], ['systemctl', 'poweroff'])


if __name__ == '__main__':
    unittest.main()

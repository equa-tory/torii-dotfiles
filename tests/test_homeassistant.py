import runpy
import tempfile
import contextlib
import io
import unittest
from unittest.mock import patch
from pathlib import Path

API = runpy.run_path(str(Path(__file__).resolve().parents[1] / '.config/torii/bin/torii-homeassistant'))
SYNC = API['sync']


class LightingTest(unittest.TestCase):
    def setUp(self):
        self.settings = dict(enabled=True, lights=['light.rgb2'], brightness=67, url='http://test')
        self.runtime = {}
        self.color = patch.dict(SYNC.__globals__, read=lambda *args: {'accent': '#aabbcc'})
        self.color.start()
        self.addCleanup(self.color.stop)
        self.calls = []
        self.api = patch.dict(SYNC.__globals__, api=lambda *args: self.calls.append(args))
        self.api.start()
        self.addCleanup(self.api.stop)

    def test_color_brightness_and_unchanged_theme(self):
        SYNC(self.settings, self.runtime)
        self.assertEqual(self.calls[0][1:], ('services/light/turn_on', {
            'entity_id': ['light.rgb2'], 'rgb_color': [170, 187, 204], 'brightness_pct': 67}))
        SYNC(self.settings, self.runtime)
        self.assertEqual(len(self.calls), 1)
        with patch.dict(SYNC.__globals__, read=lambda *args: {'accent': '#112233'}):
            SYNC(self.settings, self.runtime)
        self.assertEqual(self.calls[-1][2]['rgb_color'], [17, 34, 51])

    def test_disabled_and_empty_selection_never_control_lights(self):
        self.settings['enabled'] = False
        SYNC(self.settings, self.runtime, force=True)
        self.settings.update(enabled=True, lights=[])
        SYNC(self.settings, self.runtime)
        self.assertEqual(self.calls, [])

    def test_zero_brightness_turns_off_only_selected_lights(self):
        self.settings['brightness'] = 0
        SYNC(self.settings, self.runtime)
        self.assertEqual(self.calls[0][1:], ('services/light/turn_off', {'entity_id': ['light.rgb2']}))

    def test_failure_does_not_mark_color_applied(self):
        def fail(*args):
            raise OSError('offline')
        with patch.dict(SYNC.__globals__, api=fail):
            with self.assertRaises(OSError):
                SYNC(self.settings, self.runtime)
        self.assertNotIn('applied', self.runtime)


class ControlsTest(unittest.TestCase):
    def test_toggle_targets_only_requested_entity(self):
        calls = []
        fn = API['toggle']
        with patch.dict(fn.__globals__, api=lambda *args: calls.append(args)):
            fn({}, 'switch.desk')
            with self.assertRaises(ValueError):
                fn({}, 'lock.front_door')
        self.assertEqual(calls, [({}, 'services/switch/toggle', {'entity_id': 'switch.desk'})])

    def test_controls_and_toggle_never_sync_wallpaper(self):
        main = API['main']
        for action in (['controls'], ['toggle', 'light.rgb2']):
            with tempfile.TemporaryDirectory() as directory:
                state = Path(directory)
                def fail_sync(*args, **kwargs):
                    raise AssertionError('Manual controls must not apply wallpaper colors')
                with patch.dict(main.__globals__, STATE=state, SETTINGS=state / 'settings.json',
                                RUNTIME=state / 'runtime.json', controls=lambda settings: [],
                                toggle=lambda *args: None, sync=fail_sync):
                    with contextlib.redirect_stdout(io.StringIO()):
                        self.assertFalse(main(action))


if __name__ == '__main__':
    unittest.main()

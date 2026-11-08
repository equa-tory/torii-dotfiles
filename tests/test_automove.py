import ctypes
import os
from pathlib import Path
import runpy
import select
import tempfile
import unittest
from unittest.mock import patch

API = runpy.run_path(str(Path(__file__).resolve().parents[1] / '.config/torii/bin/torii-automove'))


class AutoMoveTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        base = Path(self.temp.name)
        self.src, self.dst = base / 'Downloads', base / 'inbox'
        self.src.mkdir()
        self.dst.mkdir()
        self.scope = patch.dict(API['main'].__globals__,
                               STATE=base / 'automove.json',
                               cfg=lambda: (self.src, self.dst),
                               unit=lambda action: None,
                               notify=lambda *args: None)
        self.scope.start()
        self.addCleanup(self.scope.stop)
        self.sleep = patch.object(API['time'], 'sleep', lambda seconds: None)
        self.sleep.start()
        self.addCleanup(self.sleep.stop)

    def sweep(self, ignored):
        API['sweep'](self.src, self.dst, [False], ignored)

    def test_existing_files_stay_and_new_media_moves(self):
        old = self.src / 'old.jpg'
        old.write_bytes(b'old')
        ignored = API['snapshot'](self.src)
        old.write_bytes(b'edited')  # Existing files remain protected even if edited.
        (self.src / 'new.png').write_bytes(b'new')
        (self.src / 'notes.txt').write_text('document')
        self.sweep(ignored)
        self.assertTrue(old.exists())
        self.assertTrue((self.dst / 'new.png').exists())
        self.assertTrue((self.src / 'notes.txt').exists())

    def test_real_move_out_and_back_releases_same_inode(self):
        old = self.src / 'old.jpg'
        old.write_bytes(b'old')
        ignored = API['snapshot'](self.src)
        libc = ctypes.CDLL('libc.so.6', use_errno=True)
        fd = libc.inotify_init1(os.O_CLOEXEC)
        self.addCleanup(os.close, fd)
        mask = API['IN_MOVED_FROM'] | API['IN_MOVED_TO'] | API['IN_DELETE']
        self.assertGreaterEqual(libc.inotify_add_watch(fd, str(self.src).encode(), mask), 0)
        outside = self.src.parent / 'outside.jpg'
        old.rename(outside)
        outside.rename(old)
        self.assertEqual(API['identity'](old), ignored[old.name])
        self.assertTrue(select.select([fd], [], [], 1)[0])
        API['arrivals'](os.read(fd, 65536), ignored)
        self.sweep(ignored)
        self.assertFalse(old.exists())
        self.assertTrue((self.dst / old.name).exists())

    def test_each_activation_has_fresh_snapshot_and_off_discards_it(self):
        (self.src / 'first.jpg').write_bytes(b'first')
        API['main'](['on'])
        self.assertEqual(set(API['load']()['ignored']), {'first.jpg'})
        API['main'](['off'])
        self.assertNotIn('ignored', API['load']())
        (self.src / 'first.jpg').unlink()
        (self.src / 'second.jpg').write_bytes(b'second')
        API['main'](['on'])
        self.assertEqual(set(API['load']()['ignored']), {'second.jpg'})

    def test_missing_destination_retries_only_new_files(self):
        old = self.src / 'old.jpg'
        old.write_bytes(b'old')
        ignored = API['snapshot'](self.src)
        (self.src / 'new.jpg').write_bytes(b'new')
        unavailable = self.dst / 'offline' / 'inbox'
        API['sweep'](self.src, unavailable, [False], ignored)
        self.assertTrue((self.src / 'new.jpg').exists())
        unavailable.parent.mkdir()
        API['sweep'](self.src, unavailable, [False], ignored)
        self.assertTrue(old.exists())
        self.assertTrue((unavailable / 'new.jpg').exists())


if __name__ == '__main__':
    unittest.main()

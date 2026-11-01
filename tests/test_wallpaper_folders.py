import runpy
import tempfile
import unittest
from pathlib import Path

API = runpy.run_path(str(Path(__file__).resolve().parents[1] / '.config/torii/bin/torii-wallpaper-folders'))


class WallpaperFoldersTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'one').mkdir()
        (self.root / 'two').mkdir()
        self.a = self.root / 'one/same.png'
        self.b = self.root / 'two/same.png'
        self.video = self.root / 'motion.mp4'
        for p in (self.a, self.b, self.video):
            p.write_bytes(p.name.encode())
        self.sources = API['originals'](self.root)

    def mutate(self, action, *args):
        API['mutate'](self.root, action, list(map(str, args)), self.sources)

    def view(self, name='All', current=''):
        return API['snapshot'](self.root, name, str(current), API['originals'](self.root))

    def test_shared_picture_and_collision_do_not_copy_or_delete_originals(self):
        before = {p: p.read_bytes() for p in (self.a, self.b, self.video)}
        for name in ('Night', 'Calm'):
            self.mutate('create', name)
            self.mutate('toggle', name, self.a)
        self.mutate('toggle', 'Night', self.b)
        folder = self.root / '.torii-albums/Night'
        self.assertEqual(len(list(folder.iterdir())), 2)
        self.assertTrue(all(p.is_symlink() for p in folder.iterdir()))
        self.assertEqual(len(self.view('All')['items']), 3)
        self.assertEqual(self.view('Night', self.a)['memberships'], ['Calm', 'Night'])
        self.mutate('remove', 'Night', self.a)
        self.assertEqual(len(self.view('Night')['items']), 1)
        self.mutate('delete', 'Calm')
        self.mutate('delete', 'Night')
        self.assertEqual({p: p.read_bytes() for p in before}, before)

    def test_builtins_and_empty_folders(self):
        self.assertEqual([x['filePath'] for x in self.view('Animated')['items']], [str(self.video)])
        self.mutate('create', 'Empty')
        self.assertEqual(self.view('Empty')['items'], [])
        self.assertEqual(self.view('Missing')['folder'], 'All')
        for name in ('All', 'animated', '../escape', '.', ' bad', 'a/b'):
            with self.assertRaises(ValueError):
                self.mutate('create', name)

    def test_regular_files_prevent_folder_deletion(self):
        self.mutate('create', 'Keep')
        p = self.root / '.torii-albums/Keep/original.png'
        p.write_bytes(b'keep')
        with self.assertRaises(ValueError):
            self.mutate('delete', 'Keep')
        self.assertEqual(p.read_bytes(), b'keep')

    def test_external_source_and_symlink_collection_rejected(self):
        self.mutate('create', 'Keep')
        with self.assertRaises(ValueError):
            self.mutate('toggle', 'Keep', '/etc/passwd')
        (self.root / '.torii-albums/Outside').symlink_to(self.root / 'one', target_is_directory=True)
        with self.assertRaises(ValueError):
            self.mutate('delete', 'Outside')
        self.assertTrue(self.a.exists())

    def test_folder_order_persists_and_handles_changes(self):
        self.mutate('create', 'Night')
        self.mutate('reorder', 'Night', 'Animated', 'All')
        self.assertEqual(self.view()['folders'], ['Night', 'Animated', 'All'])
        self.mutate('create', 'Calm')
        self.assertEqual(self.view()['folders'], ['Night', 'Animated', 'All', 'Calm'])
        with self.assertRaises(ValueError):
            self.mutate('reorder', 'All', 'Night')
        self.mutate('delete', 'Night')
        self.assertEqual(self.view()['folders'], ['Animated', 'All', 'Calm'])

    def test_toggle_and_broken_links(self):
        self.mutate('create', 'Night')
        self.mutate('toggle', 'Night', self.a)
        self.mutate('toggle', 'Night', self.a)
        self.assertEqual(self.view('Night')['items'], [])
        self.mutate('toggle', 'Night', self.a)
        self.a.unlink()
        self.assertEqual(self.view('Night')['items'], [])
        self.mutate('delete', 'Night')
        self.assertTrue(self.b.exists())


if __name__ == '__main__':
    unittest.main()

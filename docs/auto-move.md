# Downloads auto mover

Turn **Trigger → File auto mover** on to watch for incoming images, videos and ZIP archives.

Every activation takes a fresh snapshot of the source directory. Files already there are left alone, even if edited. New media is moved to the configured destination; new ZIPs are extracted using the existing ZIP rules. Other file types remain untouched.

Moving a snapshot file out of Downloads removes its protection. Moving it back makes it a new arrival, even if it has the same filename and inode and both moves happen between scans. Deleting a file and replacing it also releases its protection.

Turning the feature off discards the snapshot. Turning it back on protects everything currently in Downloads, independently of the previous session. Restoring an enabled watcher after login also takes a fresh snapshot so files present at login are not processed.

Incoming files still being written or waiting for an unavailable destination are retried every ten seconds. The snapshot is checked during retries, so retries cannot sweep up protected files. If the filesystem event queue overflows, the watcher conservatively protects the currently present files again.

Test with `python tests/test_automove.py`.

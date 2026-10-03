import asyncio
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "manager"))
from codex_rpc import CodexRpc
from session_numbering import Numbering, apply_changes, read_threads


@unittest.skipUnless(os.environ.get("CODEX_NUMBERING_TEST_BINARY"), "requires a local Codex binary")
class NativeNumberingTests(unittest.TestCase):
    def test_native_names_persist_and_polling_numbers_new_threads(self):
        asyncio.run(self.verify_native_storage())

    async def verify_native_storage(self):
        binary = Path(os.environ["CODEX_NUMBERING_TEST_BINARY"])
        with tempfile.TemporaryDirectory(prefix="codex-numbering-test-") as temporary:
            root = Path(temporary)
            (root / "config.toml").write_text("check_for_update_on_startup = false\n")
            async with CodexRpc(binary, root) as server:
                original = await server.call("thread/start", {"cwd": str(root), "ephemeral": False})
                await server.call("thread/name/set", {"threadId": original["thread"]["id"], "name": "9. Existing"})
            numbering = Numbering(root / "numbers.sqlite")
            try:
                self.assertEqual(numbering.plan(read_threads(root), set()), [])
                async with CodexRpc(binary, root) as server:
                    fresh = await server.call("thread/start", {"cwd": str(root), "ephemeral": False})
                    await server.call("thread/name/set", {"threadId": fresh["thread"]["id"], "name": "Fresh conversation"})
                changes = numbering.plan(read_threads(root), set())
                self.assertEqual([name for _, name in changes], ["10. Fresh conversation"])
                self.assertEqual(await apply_changes(binary, root, changes), 0)
                async with CodexRpc(binary, root) as server:
                    latest = await server.call("thread/read", {"threadId": fresh["thread"]["id"], "includeTurns": False})
                    self.assertEqual(latest["thread"]["name"], "10. Fresh conversation")
                self.assertEqual(numbering.plan(read_threads(root), set()), [])
                daemon = await asyncio.create_subprocess_exec(
                    sys.executable, str(Path(__file__).resolve().parents[1] / "manager/session_numbering.py"),
                    "--root", str(root / "service"), "--codex-home", str(root),
                    "--binary", str(binary), "--interval", "1",
                    stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL,
                )
                try:
                    await asyncio.sleep(1)
                    async with CodexRpc(binary, root) as server:
                        new_thread = await server.call("thread/start", {"cwd": str(root), "ephemeral": False})
                        identity = new_thread["thread"]["id"]
                        await server.call("thread/name/set", {"threadId": identity, "name": "새 대화"})
                    for attempt in range(20):
                        await asyncio.sleep(1)
                        names = {thread.thread_id: thread.name for thread in read_threads(root)}
                        if names.get(identity) == "11. 새 대화":
                            break
                    self.assertEqual(names.get(identity), "11. 새 대화")
                finally:
                    daemon.terminate()
                    await asyncio.wait_for(daemon.wait(), 5)
            finally:
                numbering.close()


if __name__ == "__main__":
    unittest.main()

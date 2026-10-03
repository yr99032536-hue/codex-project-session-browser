import asyncio
import json
import os
from pathlib import Path


class CodexRpc:
    def __init__(self, binary: Path, codex_home: Path):
        self.binary = binary
        self.codex_home = codex_home
        self.process: asyncio.subprocess.Process | None = None
        self.request_id = 0

    async def __aenter__(self):
        environment = dict(os.environ, CODEX_HOME=str(self.codex_home))
        self.process = await asyncio.create_subprocess_exec(
            str(self.binary), "-c", "check_for_update_on_startup=false", "app-server",
            stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL, env=environment,
        )
        try:
            await self.call("initialize", {
                "clientInfo": {"name": "project_session_numbering", "version": "1"},
                "capabilities": {"experimentalApi": True},
            })
            await self.send({"method": "initialized"})
        except BaseException:
            await self.close()
            raise
        return self

    async def __aexit__(self, *_):
        await self.close()

    async def close(self):
        if self.process is None:
            return
        if self.process.stdin is not None:
            self.process.stdin.close()
        try:
            await asyncio.wait_for(self.process.wait(), 5)
        except asyncio.TimeoutError:
            self.process.terminate()
            try:
                await asyncio.wait_for(self.process.wait(), 5)
            except asyncio.TimeoutError:
                self.process.kill()
                await self.process.wait()

    async def send(self, message: dict):
        if self.process is None or self.process.stdin is None:
            raise RuntimeError("Codex app-server is not running")
        self.process.stdin.write((json.dumps(message) + "\n").encode())
        await self.process.stdin.drain()

    async def call(self, method: str, params: dict) -> dict:
        self.request_id += 1
        request_id = self.request_id
        await self.send({"id": request_id, "method": method, "params": params})
        async def response():
            if self.process is None or self.process.stdout is None:
                raise RuntimeError("Codex app-server is not running")
            while line := await self.process.stdout.readline():
                message = json.loads(line)
                if message.get("id") == request_id:
                    if "error" in message:
                        raise RuntimeError(str(message["error"]))
                    return message.get("result", {})
            raise RuntimeError("Codex app-server closed before replying")
        return await asyncio.wait_for(response(), 30)

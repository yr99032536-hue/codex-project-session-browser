import argparse
import asyncio
import json
import os
import re
import sqlite3
import time
from contextlib import closing
from dataclasses import dataclass
from pathlib import Path

from codex_rpc import CodexRpc

PREFIX = re.compile(r"^([0-9]+)\.\s+(.+)$", re.DOTALL)


def number_and_title(title: str) -> tuple[int | None, str]:
    match = PREFIX.match(title.strip())
    if match and 0 < int(match[1]) < 2**63 - 1:
        return int(match[1]), match[2].strip()
    return None, title.strip()


@dataclass(frozen=True)
class Thread:
    thread_id: str
    group: str
    name: str
    created_at: int
    archived: bool
    persisted_name: str | None = None
    explicit_name: bool = True


def read_state(codex_home: Path) -> dict:
    for suffix in ("", ".bak"):
        try:
            data = json.loads((codex_home / f".codex-global-state.json{suffix}").read_text())
            if isinstance(data, dict):
                return data
        except (OSError, ValueError):
            continue
    return {}


def project_group(thread: dict, state: dict) -> str:
    projects = state.get("local-projects", {})
    assignment = state.get("thread-project-assignments", {}).get(thread["id"])
    if isinstance(assignment, dict):
        project_id = assignment.get("projectId")
        if assignment.get("projectKind") == "local" and project_id in projects:
            return f"project:{project_id}"
        return f"cwd:{thread['cwd']}"
    matches = [project_id for project_id, project in projects.items()
               if thread["cwd"] in project.get("rootPaths", [])]
    if len(matches) == 1:
        return f"project:{matches[0]}"
    if thread.get("project_id"):
        return f"project:{thread['project_id']}"
    return f"cwd:{thread['cwd']}"


def read_threads(codex_home: Path) -> list[Thread]:
    databases = sorted(codex_home.glob("state_[0-9]*.sqlite"),
                       key=lambda candidate: int(candidate.stem.split("_")[-1]))
    if not databases:
        return []
    state = read_state(codex_home)
    with closing(sqlite3.connect(f"{databases[-1].as_uri()}?mode=ro", uri=True)) as database:
        database.row_factory = sqlite3.Row
        rows = database.execute("SELECT * FROM threads ORDER BY created_at, id").fetchall()
    result = []
    for row in rows:
        thread = dict(row)
        if thread["source"] not in ("cli", "vscode", "exec", "appServer", "unknown"):
            continue
        if not thread["cwd"]:
            continue
        name = thread.get("name") or thread.get("title") or thread.get("preview") or "새 대화"
        existing_number, existing_title = number_and_title(name)
        generated_title = thread.get("title") or thread.get("preview")
        if existing_number and existing_title == "새 대화" and generated_title:
            name = f"{existing_number}. {generated_title}"
        name = " ".join(name.split())[:160]
        if name:
            result.append(Thread(thread["id"], project_group(thread, state), name,
                                 thread["created_at"], bool(thread["archived"]), thread.get("name"), bool(thread.get("name"))))
    return result


class Numbering:
    def __init__(self, path: Path):
        path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.database = sqlite3.connect(path, timeout=30)
        os.chmod(path, 0o600)
        self.database.executescript("""
            CREATE TABLE IF NOT EXISTS groups (
                id TEXT PRIMARY KEY, maximum INTEGER NOT NULL, started_at INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS numbers (
                thread_id TEXT NOT NULL, group_id TEXT NOT NULL, number INTEGER NOT NULL,
                PRIMARY KEY (thread_id, group_id), UNIQUE (group_id, number)
            );
        """)

    def plan(self, threads: list[Thread], enabled: set[str], activated_at: int = 0,
             *, persist: bool = True) -> list[tuple[Thread, str]]:
        self.database.execute("BEGIN IMMEDIATE")
        try:
            changes = self.allocate(threads, enabled, activated_at)
            if persist:
                self.database.commit()
            else:
                self.database.rollback()
            return changes
        except BaseException:
            self.database.rollback()
            raise

    def allocate(self, threads: list[Thread], enabled: set[str], activated_at: int) -> list[tuple[Thread, str]]:
        numbered_groups = {thread.group for thread in threads if thread.explicit_name and number_and_title(thread.name)[0]}
        enabled = enabled | numbered_groups | {row[0] for row in self.database.execute("SELECT id FROM groups")}
        threads = sorted((thread for thread in threads if thread.group in enabled),
                         key=lambda thread: (thread.created_at, thread.thread_id))
        for thread in threads:
            number = number_and_title(thread.name)[0] if thread.explicit_name else None
            self.database.execute("INSERT OR IGNORE INTO groups VALUES (?, 0, ?)", (thread.group, activated_at))
            if number:
                self.database.execute("UPDATE groups SET maximum=MAX(maximum, ?) WHERE id=?",
                                      (number, thread.group))
                self.database.execute("INSERT OR IGNORE INTO numbers VALUES (?, ?, ?)",
                                      (thread.thread_id, thread.group, number))
        changes = []
        for thread in threads:
            if thread.archived:
                continue
            record = self.database.execute("SELECT number FROM numbers WHERE thread_id=? AND group_id=?",
                                           (thread.thread_id, thread.group)).fetchone()
            if record is None:
                started_at = self.database.execute("SELECT started_at FROM groups WHERE id=?", (thread.group,)).fetchone()[0]
                if thread.created_at < started_at:
                    continue
                self.database.execute("UPDATE groups SET maximum=maximum+1 WHERE id=?", (thread.group,))
                number = self.database.execute("SELECT maximum FROM groups WHERE id=?", (thread.group,)).fetchone()[0]
                self.database.execute("INSERT INTO numbers VALUES (?, ?, ?)",
                                      (thread.thread_id, thread.group, number))
            else:
                number = record[0]
            existing, title = number_and_title(thread.name) if thread.explicit_name else (None, thread.name)
            refreshed_placeholder = (thread.persisted_name is not None
                                     and number_and_title(thread.persisted_name)[1] == "새 대화"
                                     and thread.persisted_name != thread.name)
            if existing != number or refreshed_placeholder:
                changes.append((thread, f"{number}. {title}"))
        return changes

    def close(self):
        self.database.close()


async def apply_changes(binary: Path, codex_home: Path, changes: list[tuple[Thread, str]]) -> int:
    failures = 0
    async with CodexRpc(binary, codex_home) as server:
        for thread, name in changes:
            try:
                latest = await server.call("thread/read", {"threadId": thread.thread_id, "includeTurns": False})
                current = latest["thread"].get("name") or latest["thread"].get("preview") or ""
                if latest["thread"].get("archived"):
                    continue
                title = " ".join(current.split())[:160]
                if latest["thread"].get("name"):
                    _, title = number_and_title(title)
                if not title or title == "새 대화":
                    _, title = number_and_title(name)
                number, _ = number_and_title(name)
                renamed = f"{number}. {title}"
                if renamed == current:
                    continue
                await server.call("thread/name/set", {"threadId": thread.thread_id, "name": renamed})
                print(f"numbered {thread.thread_id}: {number}", flush=True)
            except (RuntimeError, KeyError, asyncio.TimeoutError) as error:
                failures += 1
                print(f"numbering deferred for {thread.thread_id}: {error}", flush=True)
    return failures


async def run(args):
    numbering = Numbering(args.root / "session-numbers.sqlite")
    try:
        while True:
            try:
                threads = read_threads(args.codex_home)
                changes = numbering.plan(threads, set(args.group), int(time.time()), persist=not args.dry_run)
                if args.dry_run:
                    for thread, name in changes:
                        print(f"{thread.thread_id}: {name}")
                elif changes:
                    failures = await apply_changes(args.binary, args.codex_home, changes)
                    if failures and args.once:
                        return 1
            except (OSError, ValueError, sqlite3.Error, RuntimeError, asyncio.TimeoutError) as error:
                print(f"session numbering error: {error}", flush=True)
                if args.once:
                    return 1
            if args.once or args.dry_run:
                return 0
            await asyncio.sleep(args.interval)
    finally:
        numbering.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Continue project session numbers using Codex's naming API")
    root = Path(__file__).resolve().parent.parent
    parser.add_argument("--root", type=Path, default=root)
    parser.add_argument("--codex-home", type=Path, default=Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex"))))
    parser.add_argument("--binary", type=Path, default=root / "bin/codex-current")
    parser.add_argument("--group", action="append", default=[])
    parser.add_argument("--interval", type=float, default=3)
    parser.add_argument("--once", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    arguments = parser.parse_args()
    if arguments.interval < 1:
        parser.error("interval must be at least one second")
    raise SystemExit(asyncio.run(run(arguments)))

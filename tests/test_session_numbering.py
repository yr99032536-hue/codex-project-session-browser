import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "manager"))
from session_numbering import Numbering, Thread, number_and_title, project_group, read_threads


class SessionNumberingTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        self.numbering = Numbering(self.root / "numbers.sqlite")

    def tearDown(self):
        self.numbering.close()
        self.directory.cleanup()

    def thread(self, identity, name, created=1, group="project:alpha", archived=False):
        return Thread(identity, group, name, created, archived)

    def test_continues_existing_numbers_without_renumbering(self):
        threads = [self.thread("one", "1. First"), self.thread("ten", "10. Tenth"),
                   self.thread("new", "New conversation", 5)]
        self.assertEqual(self.numbering.plan(threads, set()), [(threads[2], "11. New conversation")])
        renamed = [*threads[:2], self.thread("new", "11. New conversation", 5)]
        self.assertEqual(self.numbering.plan(renamed, set()), [])

    def test_numbers_are_not_reused_after_deletion_or_archival(self):
        self.numbering.plan([self.thread("old", "18. Old", archived=True)], set())
        fresh = self.thread("fresh", "Fresh", 2)
        self.assertEqual(self.numbering.plan([fresh], set()), [(fresh, "19. Fresh")])

    def test_fork_receives_its_own_number_and_retries_keep_it(self):
        original = self.thread("original", "9. Original")
        fork = self.thread("fork", "9. Original", 2)
        expected = [(fork, "10. Original")]
        self.assertEqual(self.numbering.plan([fork, original], set()), expected)
        self.assertEqual(self.numbering.plan([original, fork], set()), expected)

    def test_groups_have_independent_sequences_and_require_opt_in(self):
        alpha = self.thread("alpha", "New", group="project:alpha")
        beta = self.thread("beta", "New", group="cwd:/beta")
        self.assertEqual(self.numbering.plan([alpha, beta], {alpha.group}), [(alpha, "1. New")])
        self.assertEqual(self.numbering.plan([beta], {beta.group}), [(beta, "1. New")])

    def test_restart_and_two_allocators_do_not_duplicate_numbers(self):
        self.numbering.plan([self.thread("first", "2. First")], set())
        other = Numbering(self.root / "numbers.sqlite")
        try:
            first = self.thread("next", "Next", 2)
            second = self.thread("last", "Last", 3)
            self.assertEqual(other.plan([first], set()), [(first, "3. Next")])
            self.assertEqual(self.numbering.plan([second], set()), [(second, "4. Last")])
        finally:
            other.close()

    def test_number_parser_does_not_treat_versions_as_numbers(self):
        self.assertEqual([number_and_title(name)[0] for name in
                         ["2. Title", "0. Title", "2.5 version", "2.Title", "No number"]],
                         [2, None, None, None, None])

    def test_activation_leaves_old_unnumbered_sessions_and_catches_up_after_restart(self):
        existing = self.thread("existing", "8. Existing", 1)
        old = self.thread("old", "Old unnumbered", 2)
        self.assertEqual(self.numbering.plan([existing, old], set(), 100), [])
        fresh = self.thread("fresh", "Fresh", 150)
        self.assertEqual(self.numbering.plan([existing, old, fresh], set(), 200), [(fresh, "9. Fresh")])

    def test_numbered_first_prompt_does_not_enable_numbering(self):
        prompt = Thread("prompt", "cwd:/work", "1. First instruction", 1, False, None, False)
        self.assertEqual(self.numbering.plan([prompt], set()), [])

    def test_dry_run_does_not_reserve_numbers(self):
        first = self.thread("first", "Preview only")
        self.assertEqual(self.numbering.plan([first], {first.group}, persist=False), [(first, "1. Preview only")])
        second = self.thread("second", "Actual conversation", 2)
        self.assertEqual(self.numbering.plan([second], {second.group}), [(second, "1. Actual conversation")])

    def test_project_assignment_precedes_cwd_and_shared_roots_are_ambiguous(self):
        state = {"local-projects": {"alpha": {"rootPaths": ["/shared", "/alpha"]},
                                    "beta": {"rootPaths": ["/shared"]}},
                 "thread-project-assignments": {"assigned": {"projectKind": "local", "projectId": "alpha"}}}
        self.assertEqual(project_group({"id": "assigned", "cwd": "/elsewhere"}, state), "project:alpha")
        self.assertEqual(project_group({"id": "inferred", "cwd": "/alpha"}, state), "project:alpha")
        self.assertEqual(project_group({"id": "ambiguous", "cwd": "/shared"}, state), "cwd:/shared")

    def test_read_only_discovery_excludes_subagents_and_refreshes_placeholder(self):
        with sqlite3.connect(self.root / "state_5.sqlite") as database:
            database.execute("CREATE TABLE threads (id, name, title, source, cwd, created_at, archived)")
            database.executemany("INSERT INTO threads VALUES (?, ?, ?, ?, ?, ?, ?)", [
                ("main", "2. 새 대화", "Generated title", "cli", "/work", 1, 0),
                ("agent", None, "Review", '{"subagent":{}}', "/work", 2, 0),
                ("empty", None, "", "vscode", "/work", 3, 0),
            ])
        rows = read_threads(self.root)
        self.assertEqual([(row.thread_id, row.name) for row in rows],
                         [("main", "2. Generated title"), ("empty", "새 대화")])
        self.assertEqual([name for _, name in self.numbering.plan(rows, set())],
                         ["2. Generated title", "3. 새 대화"])


if __name__ == "__main__":
    unittest.main()

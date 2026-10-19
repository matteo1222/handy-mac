# Issue tracker: Backlog.md

Issues and specs for this repo live in [Backlog.md](https://github.com/MrLesk/Backlog.md) under `backlog/`. Always go through the `backlog` CLI — never edit files in `backlog/` by hand (see the Backlog.md block in `CLAUDE.md`). Run `backlog instructions task-creation` before creating tasks.

## Conventions

- One ticket = one task: `backlog task create "<title>" -d "<why>" --ac "<criterion>" ...`
- Specs / PRDs live in `docs/` and are attached to tasks with `--doc docs/prd.md` / `--doc docs/spec.md`
- A feature or release phase is a **milestone** (`-m <milestone>`); shared-goal sub-work uses `-p TASK-N`
- Blocking edges are native dependencies: `--dep TASK-1,TASK-2`
- Triage role = a task **label** (`-l ready-for-agent`); see `triage-labels.md`
- Status columns: `To Do`, `In Progress`, `Done`
- Comments / history go in implementation notes: `backlog task edit TASK-N --append-notes "..."`

## When a skill says "publish to the issue tracker"

Create tasks with `backlog task create`, in dependency order (blockers first) so `--dep` can cite real IDs. Report the created IDs.

## When a skill says "fetch the relevant ticket"

`backlog task view TASK-N --plain` (or `backlog search "<query>" --plain`).

## Wayfinding operations

Used by `/wayfinder`.

- **Map**: a Backlog doc — `backlog doc create "<effort> map"` — holding Notes / Decisions-so-far / Fog.
- **Child ticket**: a task with `-l wayfinder,<type>` (`research`/`prototype`/`grilling`/`task`) and the question in the description.
- **Blocking**: `--dep`. A ticket is unblocked when every dependency is `Done`.
- **Frontier**: `backlog task list --status "To Do" --labels wayfinder --plain`, filter to unblocked and unassigned; lowest ID wins.
- **Claim**: `backlog task edit TASK-N -s "In Progress" -a @claude` before any work.
- **Resolve**: `--append-notes` the answer, set `-s Done`, then append a gist + task ID to the map doc's Decisions-so-far.

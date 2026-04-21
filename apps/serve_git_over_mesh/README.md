# serve_git_over_mesh

Infrastructure slice of the daemon: materialises repo-lifecycle events
onto disk as bare git repositories and advertises them as mesh RPC
procedures so other Hecate nodes can `git fetch` / `git push` over the
mesh.

Part of the walking skeleton described in
[`PLAN_GIT_OVER_MESH.md`](../../../hecate-station/plans/PLAN_GIT_OVER_MESH.md)
Phase 2.

## Desks

- `initialize_repo_on_disk/` — reacts to `repo_initiated_v1`, runs
  `git init --bare --initial-branch=<branch> <repo>.git`, installs
  the post-receive hook produced by `announce_ref_updates`.
- `advertise_repo_procedures/` — registers
  `<realm>.git.<repo_id>.rpc` as a mesh advertisement; retracts on
  `repo_archived_v1`.
- `git_over_mesh_procedure/` — the actual RPC dispatcher. Three ops:
  - `describe` — metadata only, no git invocation.
  - `fetch`    — wraps `git upload-pack --stateless-rpc`.
  - `push`     — wraps `git receive-pack --stateless-rpc`.

## Storage layout

```
<hecate-home>/repos/
├── <repo_id_1>.git/           (bare)
│   ├── HEAD
│   ├── objects/
│   ├── refs/
│   └── hooks/post-receive     (written by initialize_repo_on_disk)
├── <repo_id_2>.git/
└── ...
```

Root resolution lives in `repo_paths.erl`. Override via:

- `{serve_git_over_mesh, [{repo_root, "/path"}]}` in `sys.config`, or
- default: `shared_paths:base_dir()/repos`.

## Phase 2 caveat — no streaming yet

The `macula` SDK (v1.4.30) exports `call/3,4` but no streaming primitive
(`call_stream`). `op_fetch` and `op_push` therefore return the **entire**
pack in a single RPC reply. That is fine for the current Phase 2
targets (config repos, persona repos, Martha — all small), but will be
replaced by a chunked variant in Phase 2.1 once `macula` ships the
streaming primitive.

If you need to serve big repos today, bump the RPC timeout generously
and expect O(pack size) memory pressure on both ends of the call.

## Port-I/O implementation

`port_io.erl` spawns `git upload-pack` / `git receive-pack` via
`sh -c '<git> <args> < <tmpfile>'`. Writing the request body to a
tempfile and redirecting it sidesteps Erlang's lack of a clean
stdin-EOF on `open_port/{spawn_executable,_}`. When streaming lands,
this helper is replaced by a `port`-based chunked pipe.

## Running git itself

Requires a `git` binary on `PATH`. Absence is logged and the op
returns `{error, no_git}` — no silent failure.

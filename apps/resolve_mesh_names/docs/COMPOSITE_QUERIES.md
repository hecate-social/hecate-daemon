# Composite queries — describe + backlinks

Placeholder pointer. See `PLAN_RESOLVE_MESH_NAMES_PART1` §4 for the canonical model.

`describe(Mri)` returns records + endorsements + backlinks + last_modified + consensus signal in a single call. Replaces what would be 4-6 separate DNS queries. Returns partial results with a `partial: true` flag when sub-queries fail; bounded latency.

`backlinks(Mri)` returns the reverse direction: "who endorsed this name", "who delegated to this station". Two sources: realm_directory.trust_delegates listing + RMEs whose path matches. Pagination via continuation tokens for large realms.

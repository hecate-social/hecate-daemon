# Push-driven cache

Placeholder pointer. See `PLAN_RESOLVE_MESH_NAMES_PART1` §6 for the canonical model.

Summary:
- Push invalidation primary (PMs subscribed to mesh push events)
- TTL fallback secondary (30 s sweep period default)
- 5 layers: L1 (realm pubkeys) → L2 (realm directories) → L3 (endorsements) → L4 (leaf records) → L5 (composite verified results)
- Tombstones supersede live cache for the same key
- Cascade invalidation: any upstream layer's invalidation cascades downward through dependent entries
- In-flight de-dup prevents thundering-herd cold-cache scenarios

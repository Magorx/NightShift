Perform a full performance review of the project codebase, then produce an actionable optimisation report.

## Phase 1: Review

Systematically read through ALL GDScript files in the project (use the `critic` agent for the heavy lifting, instructing it to focus on performance). Look for:

- **Per-frame waste**: expensive operations in `_process`/`_physics_process` that don't need to run every frame (lookups, allocations, string operations, node queries)
- **Unnecessary allocations**: creating Arrays, Dictionaries, Vectors, or objects every frame instead of caching/reusing
- **Node tree abuse**: `get_node()` / `find_child()` / `get_children()` called repeatedly instead of cached at `_ready`
- **Signal spam**: signals firing every frame when they should only fire on state changes
- **Draw call bloat**: too many separate meshes/sprites where batching, MultiMesh, or atlasing would work
- **Physics overhead**: collision shapes that are too complex, bodies that should be static, unnecessary raycasts
- **Shader/material waste**: duplicate materials that could be shared, unnecessary shader uniforms updated every frame
- **Algorithm issues**: O(n^2) loops, linear searches through large arrays, sorting every frame
- **Idle cost**: systems that tick even when they have nothing to do (empty loops, polling when nothing changed)
- **GDScript-specific pitfalls**: using `String +` concatenation in loops, `in` on large arrays, dynamic property access via strings

Be thorough. Read every `.gd` file. Don't skim. Focus only on things that actually hurt FPS — ignore style or architecture issues (those belong in `/activity_refactor`).

## Phase 2: Report

Run `date` to get today's date, then create a report file at:

```
docs/optimisation/YYYY-MM-DD.md
```

Format the report as a numbered list of findings. Each finding must include:

1. **Title** — short description of the bottleneck
2. **Location** — file path(s) and line numbers
3. **Problem** — what's expensive and roughly how much it costs (e.g. "runs every frame for all N conveyors" or "allocates a new Array per building per tick")
4. **Proposed fix** — concrete solution with expected improvement
5. **Impact** — low/medium/high FPS impact estimate
6. **Effort** — small/medium/large

Group findings by system (conveyor, building tick, rendering, physics, UI, etc.). Put the highest-impact items first within each group.

End the report with a summary: total findings, breakdown by impact and effort, and a recommended priority order (high impact + low effort first).

## Phase 3: Wait for user review

After creating the report, tell the user:
- The report path
- A brief summary (e.g. "Found 9 performance issues: 2 high-impact, 4 medium, 3 low")
- Ask them to review and tell you which items to fix

Do NOT start optimising until the user explicitly approves specific items.

## Phase 4: Optimise (after user approval)

When the user says which items to fix:
1. Fix them one at a time, committing after each
2. Run the parse check after each change
3. Run relevant simulations to verify nothing broke and performance improved
4. Update the report file: mark completed items with a checkmark

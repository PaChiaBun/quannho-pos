## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

Rules:
- Use Graphify first only for broad architecture, module boundaries, code–docs–schema relationships, onboarding, and cross-domain flows. Run `graphify query "<question>"` when `graphify-out/graph.json` exists; use `graphify path "<A>" "<B>"` or `graphify explain "<concept>"` only when the architecture question needs them.
- For bug diagnosis, root-cause analysis, symbol/source inspection, call paths, dynamic dispatch, impact analysis, and implementation work, use CodeGraph as the primary tool after at most one Graphify orientation query. Do not call both tools repeatedly for the same purpose.
- Treat Graphify as the architecture map and CodeGraph as the source-level investigator. Graphify `INFERRED` or `AMBIGUOUS` edges are hypotheses until current source, schema/migrations, and tests confirm them.
- Dirty graphify-out/ files are expected after hooks or incremental updates; dirty graph files are not a reason to skip graphify. Only skip graphify if the task is about stale or incorrect graph output, or the user explicitly says not to use it.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).

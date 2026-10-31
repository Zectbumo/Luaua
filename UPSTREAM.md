# Upstream provenance

Luaua is forked from the official Luau `0.745` release.

- Upstream repository: <https://github.com/luau-lang/luau.git>
- Upstream tag: `0.745`
- Upstream commit: `2a3d8937c19c8fd9f7b72b6ec9068c62760e6588`
- Luaua development branch: `luaua-zero-base`

The fork intentionally changes every Lua-visible sequence position to be
zero-based and every positional start/end range to use `[start, end)`
semantics. It is therefore source- and bytecode-incompatible with upstream
Luau. Existing Luau licensing and attribution are retained.

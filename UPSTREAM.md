# Upstream provenance

Luaua is forked from the official Luau `0.734` release.

- Upstream repository: <https://github.com/luau-lang/luau.git>
- Upstream tag: `0.734`
- Upstream commit: `3fc82b1071ab387531175869afc4fb528464afa4`
- Luaua development branch: `luaua-zero-base`

The fork intentionally changes every Lua-visible sequence position to be
zero-based and every positional start/end range to use `[start, end)`
semantics. It is therefore source- and bytecode-incompatible with upstream
Luau. Existing Luau licensing and attribution are retained.

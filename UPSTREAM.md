# Upstream provenance

Luaua is forked from the official Luau `0.744` release.

- Upstream repository: <https://github.com/luau-lang/luau.git>
- Upstream tag: `0.744`
- Upstream commit: `32c28089305f488f901aaf1dbf3fd1cb65fa3d11`
- Luaua development branch: `luaua-zero-base`

The fork intentionally changes every Lua-visible sequence position to be
zero-based and every positional start/end range to use `[start, end)`
semantics. It is therefore source- and bytecode-incompatible with upstream
Luau. Existing Luau licensing and attribution are retained.

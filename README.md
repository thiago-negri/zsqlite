# zsqlite

Ziggified wrapper around SQLite.

Goals:
- No extra stuff under the hood (e.g. no automatically parsing column names);
- Correlate with the C API;
- Provide a Zig-friendly interface;
- Provide more safety (e.g. automatically close/finalize if something goes wrong);
- Provide extras so it's easier to work with it in Zig (e.g. offer a way to allocate strings);

Offers a limited subset of SQLite.  As I'm only using this for a personal project, my current target
is only on some features that I use.

If you only want to use SQLite as a static library in Zig, check out
[zsqlite-c](https://github.com/thiago-negri/zsqlite-c/).

## Install

Add as a dependency:

```sh
zig fetch --save "https://github.com/thiago-negri/zsqlite/archive/refs/heads/master.zip"
```

Add to your build:

```zig
// Add SQLite
const zsqlite = b.dependency("zsqlite", .{
    .target = target,
    .optimize = optimize,
    // Tracks open statements and panics if a close is attempted on a connection that
    // still has unfinallized statements.  Defaults to true.
    // Setting it to false will strip that code from the executable, so no overhead.
    .track_open_statements = true,
});
const zsqlite_module = zsqlite.module("zsqlite");
exe.root_module.addImport("zsqlite", zsqlite_module);
```

## Use

See [zsqlite-demo](https://github.com/thiago-negri/zsqlite-demo) for an example on how to use.

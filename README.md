# zsqlite

API for using SQLite from Zig.

You can either do `@cImport("sqlite3.h")` and work directly with the C API.
Or `@import("zsqlite")` and use the wrapper API.

The wrapper API tries to ziggify the SQLite API but without doing extra stuff like
parsing column names.  It tries to correlate directly with the C API.

## Install

First add it as a dependency to your project:

```sh
zig fetch --save "https://github.com/thiago-negri/zsqlite/archive/refs/heads/master.zip"
```

Then add it to your build:

```zig
// Add SQLite
const zsqlite = b.dependency("zsqlite", .{ .target = target, .optimize = optimize });
const zsqlite_artifact = zsqlite.artifact("zsqlite");
const zsqlite_module = zsqlite.module("zsqlite");
exe.root_module.addImport("zsqlite", zsqlite_module);
exe.linkLibrary(zsqlite_artifact);
```

If you only want to import the C header, you can remove the module-related stuff form the previous
snippet.

## Use

See:

- [example-usage-c-import.zig](./example-usage-c-import.zig) for example using `@cImport`
- [example-usage-module.zig](./example-usage-module.zig) for example using `@import("zsqlite")`


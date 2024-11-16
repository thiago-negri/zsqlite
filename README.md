# zsqlite

The intention of this project is only to provide a hook for Zig projects that depend on SQLite.

The `version` of `build.zig.zon` is the same as the SQLite source included.

This will only allow your code to import the SQLite header file and will add the C sources
as part of your build process.

## Install

First add it as a dependency to your project:

```sh
zig fetch --save "https://github.com/thiago-negri/zsqlite/archive/refs/tags/v3.47.0.tar.gz"
```

Tag names are the same as the SQLite version that you're going to use.  In this case, 3.47.0.

Then add it to your build:

```zig
// Add SQLite
const zsqlite = b.dependency("zsqlite", .{ 
    .target = target,
    .optimize = optimize 
});
exe.linkLibrary(zsqlite.artifact("zsqlite"));
```

## Use

See [example-usage.zig](./example-usage.zig)


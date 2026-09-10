# Znow

A simple [snowflake](https://en.wikipedia.org/wiki/Snowflake_ID) generator.

## Installation

```bash
# for dev
zig fetch --save git+https://codeberg.org/Adwaith-Rajesh/znow.git
```
you can also pick one of the archives from the releases

---

## Usage

In `build.zig`
```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    ...

    const znow = b.dependency("znow", .{});

    const exe = b.addExecutable(.{
        .name = "test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("..."),
            ...,
            .imports = &.{
                .{
                    .name = "znow",
                    .module = znow.module("znow"),
                },
            },
        }),
    });

    ...
}
```

---

## Creating snowflakes

The below example create a 100 snowflakes

```zig
const std = @import("std");
const znow = @import("znow");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var flake: znow.Snowflake(.not_thread_safe) = .init(io, 12);

    // use .thread_safe for thread safe implementation
    // var flake: znow.Snowflake(.thread_safe) = .init(io, 12);

    for (0..100) |_| {
        std.debug.print("flake -> {d}\n", .{flake.next()});
    }
}
```
---

## Have any Issues??

Please create a new issue, or join my [Discord](https://discord.gg/BxMbWzZe2Z).

---

## Byeeee..

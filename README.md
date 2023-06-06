# Slap
> slugbyte lil arg parser

## About
I am just learning zig and wanted to build an arg parser to help myself better learn 
how to create data types with `comptime` :) This is my first zig lib and I don't
really recommend using it due to the fact that I don't really know zig yet :)

I made this public just because It might be useful as reference code to other
zig noobs like my self :)

## Warning
**This is a work in progress and should not be used for anything!**

## how it works?
```zig
const flag_spec_list = [_]Slap.Flag{
    .{
        .name = "directory"
        .short = 'd',
        .kind = Slap.StringList,
        .help = "trash a directory"
    },
    .{
        .name = "verbose"
        .short = 'v',
        .kind = Slap.Kind{ .Bool = true},// true by default
        .help = "log everything that happens"
    },
};
var slap = Slap(flag_spec_list[0..]).init(allocator)
// slap.data.directory (?[][]const u8]
// slap.data.verbose (?boolean)
```

## goals
* support for flags without hyphens
* support for `--` and short `-` 
    * flags should be parsable as strings and bools (someday ints, floats, or enums)
* support for auto generationg `--help` that describes the usage
* support for auto completion `--completion $@`
    * file system
    * enums
    * other options
* error diagnostics

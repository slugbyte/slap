# Slap
> slugbyte lil arg parser

$ program (--something) <1 arg> (-s) <no arg> something  <many args>


SlapData .{
  "argName": {
      "present": bool,
      "value": (bool, []const u8, [][]const u8),
  },
  "argName": (bool, []const u8, [][]const u8),
  "argName": (bool, []const u8, [][]const u8),
  "argName": (bool, []const u8, [][]const u8),
}

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

# ARG PARSER

## about
this arg parser is just a learning exersice for me to learn zig and not
neccerarly meant to be used by others

## goals
* support for `--` and short `-` 
    * flags should be parsable as strings, ints, floats, bools, or enums
* support for auto generationg `--help` that describes the usage
* support for auto completion `--completion $@`
    * file system
    * enums
    * other options
* error diagnostics

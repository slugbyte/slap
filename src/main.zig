const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;
const print = std.debug.print;
const StructField = std.builtin.Type.StructField;
const FLAG_NAME_MAX = 100;

const SlapErr = error{
    initError,
    outOfMemory,
    flagMissingValue,
    flagNameDuplicates,
    flagValueInvalid,
};

const Slipup = struct {
    message: []const u8,
    err: SlapErr,
};

const SlapKind = union(enum) {
    Bool: bool,
    String,
    StringList,
    // Filepath
    // Integer
    // Float
    // Enum
    fn ToType(comptime self: SlapKind) type {
        return switch (self) {
            .Bool => bool,
            .String => ?[]const u8,
            .StringList => ?[][]const u8,
        };
    }
};
const SlapFlag = struct {
    name: []const u8, // verbose aka --verbose
    short: ?u8 = null, // if 'v' aka -v
    help: []const u8, // turn on verbose loging
    kind: SlapKind = SlapKind{ .Bool = false }, // .Bool

    pub fn eql(self: *const SlapFlag, text: []const u8) bool {
        const hyphen_name_len = self.name.len + 2;
        var hyphen_name: [FLAG_NAME_MAX]u8 = undefined;
        hyphen_name[0] = '-';
        hyphen_name[1] = '-';

        @memcpy(hyphen_name[2..hyphen_name_len], self.name);

        if (std.mem.eql(u8, hyphen_name[0..hyphen_name_len], text)) {
            return true;
        }

        if (self.short) |short| {
            const short_flag = [_:0]u8{ '-', short };
            if (std.mem.startsWith(u8, text, &short_flag)) {
                return true;
            }
        }

        return false;
    }
};

pub fn Slap(comptime flag_list: []const SlapFlag) type {
    var fields: [flag_list.len]StructField = undefined;
    comptime var field_index = 0;

    inline while (field_index < fields.len) : (field_index += 1) {
        const flag = flag_list[field_index];

        const presence_field: StructField = .{
            .name = "presence",
            .type = bool,
            .is_comptime = false,
            .alignment = @alignOf(bool),
            .default_value = @ptrCast(*const anyopaque, &false),
        };

        if (flag.name.len >= FLAG_NAME_MAX) {
            @compileError("flag.name is too long");
        }
        const field_type = flag.kind.ToType();
        const default_value = switch (flag.kind) {
            .Bool => |value| value,
            .String => @as(field_type, null),
            .StringList => @as(field_type, null),
        };
        const alignment = @alignOf(field_type);
        const value_field: std.builtin.Type.StructField = .{
            .name = "value",
            .type = field_type,
            .is_comptime = false,
            .alignment = alignment,
            .default_value = @ptrCast(*const anyopaque, &default_value),
        };

        const slap_data_field_list = [2]StructField{ presence_field, value_field };

        //TODO create {presence, value struct}
        const SlapDataField = @Type(.{
            .Struct = .{
                .decls = &.{},
                .layout = .Auto,
                .fields = &slap_data_field_list,
                .is_tuple = false,
            },
        });

        fields[field_index] = .{
            .name = flag.name,
            .type = SlapDataField,
            .is_comptime = false,
            .alignment = @alignOf(SlapDataField),
            .default_value = @ptrCast(*const anyopaque, &@as(SlapDataField, .{})),
        };
    }

    const SlapData = @Type(.{
        .Struct = .{
            .decls = &.{},
            .layout = .Auto,
            .fields = &fields,
            .is_tuple = false,
        },
    });

    return struct {
        const Self = @This();
        flag_list: []const SlapFlag,
        allocator: Allocator,
        slipup_list: ArrayList(Slipup),
        arg_list: ArrayList([]const u8),
        data: SlapData,

        fn init(allocator: Allocator) SlapErr!Self {
            var slipup_list = ArrayList(Slipup).init(allocator);
            var arg_list = ArrayList([]const u8).init(allocator);
            var arg_iterator = std.process.argsWithAllocator(allocator) catch {
                return SlapErr.outOfMemory;
            };
            defer arg_iterator.deinit();
            errdefer arg_iterator.deinit();

            while (arg_iterator.next()) |arg| {
                arg_list.append(arg) catch {
                    return SlapErr.outOfMemory;
                };
            }

            var result: Self = .{
                .allocator = allocator,
                .flag_list = flag_list,
                .slipup_list = slipup_list,
                .arg_list = arg_list,
                .data = .{},
            };

            try result.parse();
            // try result.validate();
            return result;
        }

        // fn validate(self: *Self) SlapErr!void {
        //     // TODO: check that no duplicate flag
        //
        // }

        fn deinit(self: *Self) void {
            self.slipup_list.deinit();
            self.arg_list.deinit();
        }

        // TODO fn parse
        fn parse(self: *Self) !void {
            const data_field_list = std.meta.fields(@TypeOf(self.data));
            comptime var i = 0;

            inline while (i < data_field_list.len) : (i += 1) {
                const field = data_field_list[i];

                const flag: SlapFlag = for (self.flag_list) |flag| {
                    if (std.mem.eql(u8, field.name, flag.name)) {
                        break flag;
                    }
                    // print("wat, {s} \n", .{flag.name});
                } else unreachable;

                var j: usize = 0;
                while (j < self.arg_list.items.len) : (j += 1) {
                    const arg = self.arg_list.items[j];
                    if (flag.eql(arg)) {
                        var prop = @field(self.data, field.name);

                        const field_value = @field(prop, "value");
                        @field(prop, "value") = switch (@TypeOf(field_value)) {
                            bool => true,
                            ?[]const u8 => wat: {
                                if ((j + 1) >= self.arg_list.items.len) {
                                    // print("no more args after: {s}\n", .{arg});
                                    break :wat @as(?[]const u8, null);
                                }
                                j += 1;
                                const value = self.arg_list.items[j];
                                // print("value for arg {s}:{s}", .{ arg, value });
                                break :wat @as(?[]const u8, value);
                            },
                            ?[][]const u8 => @as(?[][]const u8, null),
                            else => unreachable,
                        };
                        // print("hiihihihi, {d} {s} {s}\n", .{ i, self.flag_list[i].name, field.name });
                        continue;
                    }
                }
            }
        }
    };
}

pub fn main() !void {
    var arena = ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var alley = arena.allocator();

    const flag_list = [_]SlapFlag{
        SlapFlag{
            .name = "lucky",
            .short = 'l',
            .kind = SlapKind{ .Bool = false },
            .help = "turn on more debug logs",
        },
        SlapFlag{
            .name = "hello",
            .short = 'h',
            .kind = .String,
            .help = "say hello to a string",
        },
        SlapFlag{
            .name = "goodbye",
            .short = 'g',
            .kind = .StringList,
            .help = "say goodbye to many strings",
        },
    };

    var slap = Slap(flag_list[0..]).init(alley) catch |err| switch (err) {
        SlapErr.initError => {
            print("sry bub, unable to init slap!", .{});
            std.process.exit(1);
        },
        else => {
            print("somting cazy just happend!", .{});
            std.process.exit(1);
        },
    };

    comptime var i = 0;
    inline for (std.meta.fields(@TypeOf(slap.data))) |field| {
        const field_value = @field(slap.data, field.name);
        print("slap.data[{d}]: {s} = {any} (type {any})\n", .{ i, field.name, field_value, field.type });
        i += 1;
    }
    defer slap.deinit();

    if (slap.data.lucky.value) {
        print("good luck!\n", .{});
    }

    if (slap.data.hello.value) |name| {
        print("hello {s}!\n", .{name});
    }
}

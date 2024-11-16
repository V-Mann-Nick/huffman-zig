const std = @import("std");
const Allocator = std.mem.Allocator;
const Encoder = @import("encode.zig");
const Decoder = @import("decode.zig");

const HuffmanError = error{InvalidArgs} || Decoder.DecodeError;

pub fn main() !void {
    const start = std.time.milliTimestamp();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len != 3) {
        return HuffmanError.InvalidArgs;
    }

    const Op = enum { encode, decode };
    const op: Op = std.meta.stringToEnum(Op, args[1]) orelse {
        return HuffmanError.InvalidArgs;
    };
    const input_path = args[2];

    switch (op) {
        .encode => try encode(allocator, input_path),
        .decode => try decode(allocator, input_path),
    }

    const end = std.time.milliTimestamp();
    const duration = end - start;
    std.debug.print("Execution time: {} ms\n", .{duration});
}

fn encode(allocator: Allocator, file_name: []const u8) !void {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile(file_name, .{});
    defer file.close();
    const input = try file.readToEndAlloc(allocator, 1e9);

    var encoder = Encoder.init(allocator, input);
    var encoded = try encoder.encode();
    defer encoded.deinit();

    const new_file_name = try std.fmt.allocPrint(allocator, "{s}.huf", .{file_name});
    const write_file = try cwd.createFile(new_file_name, .{});
    defer write_file.close();
    try write_file.writeAll(encoded.bytes.items);
}

fn decode(allocator: Allocator, file_name: []const u8) !void {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile(file_name, .{});
    defer file.close();
    const input = try file.readToEndAlloc(allocator, 1e9);

    var decoder = Decoder.init(allocator, input);
    var bytes = try decoder.decode();
    defer bytes.deinit();

    const new_file_name = try std.mem.replaceOwned(
        u8,
        allocator,
        file_name,
        ".huf",
        ".dec",
    );
    defer allocator.free(new_file_name);
    const write_file = try cwd.createFile(new_file_name, .{});
    defer write_file.close();
    try write_file.writeAll(bytes.items);
}

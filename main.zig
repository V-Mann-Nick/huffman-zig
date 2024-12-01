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
    if (args.len < 2) {
        return HuffmanError.InvalidArgs;
    }

    const Op = enum { encode, decode };
    const op: Op = std.meta.stringToEnum(Op, args[1]) orelse {
        return HuffmanError.InvalidArgs;
    };
    const input_path: ?[]u8 = if (args.len > 2) args[2] else null;

    const file = if (input_path == null or std.mem.eql(u8, input_path.?, "-"))
        std.io.getStdIn()
    else
        try std.fs.cwd().openFile(input_path.?, .{});
    defer file.close();

    const stdout = std.io.getStdOut();
    defer stdout.close();

    switch (op) {
        .encode => try encode(allocator, file, stdout),
        .decode => try decode(allocator, file, stdout),
    }

    const end = std.time.milliTimestamp();
    const duration = end - start;
    std.debug.print("Execution time: {} ms\n", .{duration});
}

fn encode(
    allocator: Allocator,
    file: std.fs.File,
    stdout: std.fs.File,
) !void {
    const input = try file.readToEndAlloc(allocator, 1e9);
    defer allocator.free(input);

    var encoder = Encoder.init(allocator, input);
    var encoded = try encoder.encode();
    defer encoded.deinit();

    try stdout.writeAll(encoded.bytes.items);
}

fn decode(
    allocator: Allocator,
    file: std.fs.File,
    stdout: std.fs.File,
) !void {
    const input = try file.readToEndAlloc(allocator, 1e9);
    defer allocator.free(input);

    var decoder = Decoder.init(allocator, input);
    var bytes = try decoder.decode();
    defer bytes.deinit();

    try stdout.writeAll(bytes.items);
}

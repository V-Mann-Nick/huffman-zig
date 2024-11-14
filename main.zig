const std = @import("std");
const Encoder = @import("encode.zig");

pub fn main() !void {
    const start = std.time.milliTimestamp();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    const file_name = args[1];

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

    const end = std.time.milliTimestamp();
    const duration = end - start;
    std.debug.print("Execution time: {} ms\n", .{duration});
}

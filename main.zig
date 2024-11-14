const std = @import("std");
const encode = @import("encode.zig").encode;

pub fn main() !void {
    @setRuntimeSafety(false);
    const start = std.time.milliTimestamp();
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = false }){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();
    // const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const name = args[1];
    const file = try std.fs.cwd().openFile(name, .{});
    defer file.close();

    const s = try file.readToEndAlloc(allocator, 1e9);
    var e = try encode(allocator, s);
    defer e.deinit();
    const new_name = try std.fmt.allocPrint(allocator, "{s}.huf", .{name});
    const write_file = try std.fs.cwd().createFile(new_name, .{});
    defer write_file.close();
    try write_file.writeAll(e.bytes.items);
    const end = std.time.milliTimestamp();
    const duration = end - start;
    std.debug.print("Execution time: {} ms\n", .{duration});
}

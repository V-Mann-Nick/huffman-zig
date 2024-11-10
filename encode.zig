const std = @import("std");
const Allocator = std.mem.Allocator;
const Node = @import("node.zig").Node(std.heap.page_allocator);

const Frequencies = std.StringHashMap(u32);

fn calculate_frequencies(allocator: Allocator, s: []const u8) !Frequencies {
    var frequencies = Frequencies.init(allocator);
    const view = try std.unicode.Utf8View.init(s);
    var iterator = view.iterator();
    while (iterator.nextCodepointSlice()) |slice| {
        const result = try frequencies.getOrPut(slice);
        if (!result.found_existing) {
            result.value_ptr.* = 0;
        }
        result.value_ptr.* += 1;
    }
    return frequencies;
}

test "test frequencies" {
    const expect = std.testing.expect;
    const allocator = std.testing.allocator;

    const s = "hello world";

    var frequencies = try calculate_frequencies(allocator, s);
    defer frequencies.deinit();

    try expect(frequencies.count() == 8);

    var total: u32 = 0;
    var iterator = frequencies.iterator();
    while (iterator.next()) |entry| {
        const count = entry.value_ptr.*;
        total += count;
    }

    try expect(total == s.len);
}

const math = std.math;
const PriorityQueue = std.PriorityQueue;

const CharAndPriority = struct { char: []const u8, priority: u32 };

fn greather_than(ctx: void, a: CharAndPriority, b: CharAndPriority) math.Order {
    _ = ctx;
    return math.order(b.priority, a.priority);
}

const PQgt = PriorityQueue(CharAndPriority, void, greather_than);

fn prioritize(allocator: Allocator, frequencies: *Frequencies) !PQgt {
    var queue = PQgt.init(allocator, {});
    var iter = frequencies.iterator();
    while (iter.next()) |entry| {
        try queue.add(.{
            .char = entry.key_ptr.*,
            .priority = entry.value_ptr.*,
        });
    }
    return queue;
}

test "test prioritize" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const s = "hello world";

    var frequencies = try calculate_frequencies(allocator, s);
    defer frequencies.deinit();

    var queue = try prioritize(allocator, &frequencies);
    defer queue.deinit();

    const stdout = std.io.getStdOut().writer();
    var it = queue.iterator();
    while (it.next()) |n| {
        try stdout.print("{s} - {d}\n", .{ n.char, n.priority });
    }

    try testing.expectEqual(frequencies.count(), queue.count());

    var char_and_priority = queue.remove();
    try testing.expectEqual(s.ptr + 2, char_and_priority.char.ptr);
    try testing.expectEqualStrings("l", char_and_priority.char);
    try testing.expectEqual(3, char_and_priority.priority);

    char_and_priority = queue.remove();
    try testing.expectEqualStrings("o", char_and_priority.char);
    try testing.expectEqual(s.ptr + 4, char_and_priority.char.ptr);
    try testing.expectEqual(2, char_and_priority.priority);

    // ...
}

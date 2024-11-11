const std = @import("std");
const Allocator = std.mem.Allocator;

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

const TreeBuilder = struct {
    allocator: Allocator,
    const Self = @This();

    fn init(allocator: Allocator) Self {
        return .{ .allocator = allocator };
    }

    const Node = @import("node.zig").Node;

    fn buildTree(self: *const Self, s: []const u8) !*const Node {
        var frequencies = try calculate_frequencies(self.allocator, s);
        defer frequencies.deinit();

        var queue = try self.prioritize(&frequencies);
        defer queue.deinit();

        while (queue.count() >= 2) {
            const left = queue.remove();
            const right = queue.remove();
            const internal_node = try Node.internal(
                self.allocator,
                left.node,
                right.node,
            );
            const priority = left.priority + right.priority;
            try queue.add(.{ .node = internal_node, .priority = priority });
        }

        const root = queue.remove().node;
        return root;
    }

    const NodeAndPriority = struct { node: *const Node, priority: u32 };

    const math = std.math;
    fn greather_than(ctx: void, a: NodeAndPriority, b: NodeAndPriority) math.Order {
        _ = ctx;
        return math.order(b.priority, a.priority);
    }

    const PQgt = std.PriorityQueue(NodeAndPriority, void, greather_than);

    fn prioritize(self: *const Self, frequencies: *const Frequencies) !PQgt {
        var queue = PQgt.init(self.allocator, {});
        var iter = frequencies.iterator();
        while (iter.next()) |entry| {
            try queue.add(.{
                .node = try Node.leaf(self.allocator, entry.key_ptr.*),
                .priority = entry.value_ptr.*,
            });
        }
        return queue;
    }
};

test "test prioritize" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const s = "hello world";

    var frequencies = try calculate_frequencies(allocator, s);
    defer frequencies.deinit();

    var queue = try TreeBuilder.init(allocator).prioritize(&frequencies);
    defer queue.deinit();
    defer while (queue.removeOrNull()) |nap| {
        nap.node.deinit(allocator);
    };

    const stdout = std.io.getStdOut().writer();
    var it = queue.iterator();
    while (it.next()) |n| {
        try stdout.print("{s} - {d}\n", .{ n.node, n.priority });
    }

    try testing.expectEqual(frequencies.count(), queue.count());

    var char_and_priority = queue.remove();
    try testing.expectEqual(s.ptr + 2, char_and_priority.node.leaf.char.ptr);
    try testing.expectEqualStrings("l", char_and_priority.node.leaf.char);
    try testing.expectEqual(3, char_and_priority.priority);
    char_and_priority.node.deinit(allocator);

    char_and_priority = queue.remove();
    try testing.expectEqual(s.ptr + 4, char_and_priority.node.leaf.char.ptr);
    try testing.expectEqualStrings("o", char_and_priority.node.leaf.char);
    try testing.expectEqual(2, char_and_priority.priority);
    char_and_priority.node.deinit(allocator);

    // ...
}

test "buildTree" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const s = "hello world";
    const root = try TreeBuilder.init(allocator).buildTree(s);
    defer root.deinit(allocator);

    const stdout = std.io.getStdOut().writer();
    try stdout.print("{s}", .{root});
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const Frequencies = std.AutoHashMap(u8, u32);

fn calculate_frequencies(allocator: Allocator, s: []const u8) !Frequencies {
    var frequencies = Frequencies.init(allocator);
    for (s) |byte| {
        const result = try frequencies.getOrPut(byte);
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

const Tree = struct {
    const Self = @This();

    allocator: Allocator,
    root: *const Node,

    fn build(allocator: Allocator, s: []const u8) !Self {
        const root = try buildTree(allocator, s);
        return .{ .allocator = allocator, .root = root };
    }

    fn deinit(self: *Self) void {
        self.root.deinit(self.allocator);
    }

    const Node = @import("node.zig").Node;

    fn buildTree(allocator: Allocator, s: []const u8) !*const Node {
        var frequencies = try calculate_frequencies(allocator, s);
        defer frequencies.deinit();

        var queue = try prioritize(allocator, &frequencies);
        defer queue.deinit();

        while (queue.count() >= 2) {
            const left = queue.remove();
            const right = queue.remove();
            const internal_node = try Node.internal(
                allocator,
                left.node,
                right.node,
            );
            const priority = left.priority + right.priority;
            try queue.add(.{ .node = internal_node, .priority = priority });
        }

        const root = queue.remove().node;
        return root;
    }

    const BitVec = @import("./bitvec.zig");
    const CodesByChar = std.AutoHashMap(u8, BitVec);

    fn walkPathsForCodes(self: *Self) !CodesByChar {
        var codes_by_char = CodesByChar.init(self.allocator);
        var bits = BitVec.init(self.allocator);
        defer bits.deinit();
        try self.walkNodeForCodes(
            self.root,
            &bits,
            &codes_by_char,
        );
        return codes_by_char;
    }

    fn walkNodeForCodes(
        self: *Self,
        node: *const Node,
        bits: *BitVec,
        codes_by_char: *CodesByChar,
    ) !void {
        switch (node.*) {
            .leaf => |leaf_node| {
                const bits_copy = try bits.copy(self.allocator);
                try codes_by_char.put(leaf_node.byte, bits_copy);
            },
            .internal => |internal_node| {
                try bits.push(0);
                try self.walkNodeForCodes(internal_node.left, bits, codes_by_char);
                _ = bits.pop();

                try bits.push(1);
                try self.walkNodeForCodes(internal_node.right, bits, codes_by_char);
                _ = bits.pop();
            },
        }
    }

    fn deinitCodesByChar(codes_by_char: *CodesByChar) void {
        var it = codes_by_char.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        codes_by_char.deinit();
    }

    const NodeAndPriority = struct { node: *const Node, priority: u32 };

    const math = std.math;
    fn greather_than(ctx: void, a: NodeAndPriority, b: NodeAndPriority) math.Order {
        _ = ctx;
        return math.order(a.priority, b.priority);
    }

    const PQgt = std.PriorityQueue(NodeAndPriority, void, greather_than);

    fn prioritize(allocator: Allocator, frequencies: *const Frequencies) !PQgt {
        var queue = PQgt.init(allocator, {});
        var iter = frequencies.iterator();
        while (iter.next()) |entry| {
            try queue.add(.{
                .node = try Node.leaf(allocator, entry.key_ptr.*),
                .priority = entry.value_ptr.*,
            });
        }
        return queue;
    }
};

const testing = std.testing;
test "test prioritize" {
    const allocator = testing.allocator;

    const s = "hello world";

    var frequencies = try calculate_frequencies(allocator, s);
    defer frequencies.deinit();

    var queue = try Tree.prioritize(allocator, &frequencies);
    defer queue.deinit();
    defer while (queue.removeOrNull()) |nap| {
        nap.node.deinit(allocator);
    };

    var it = queue.iterator();
    while (it.next()) |n| {
        std.debug.print("{s} - {d}\n", .{ n.node, n.priority });
    }

    try testing.expectEqual(frequencies.count(), queue.count());
}

test "buildTree" {
    const s = "hello world";
    var tree = try Tree.build(testing.allocator, s);
    defer tree.deinit();

    std.debug.print("{s}\n", .{tree.root});
}

test "walk tree" {
    const s = "hello world";
    var tree = try Tree.build(testing.allocator, s);
    defer tree.deinit();
    var codes_by_char = try tree.walkPathsForCodes();
    defer Tree.deinitCodesByChar(&codes_by_char);
    var codes_it = codes_by_char.iterator();
    while (codes_it.next()) |entry| {
        const c = entry.key_ptr.*;
        std.debug.print("{c} - ", .{c});

        const bits = entry.value_ptr.*;
        var bit = bits.iterator();
        while (bit.next()) |b| {
            std.debug.print("{d}", .{b});
        }
        std.debug.print("\n", .{});
    }
}

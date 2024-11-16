const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

const Node = @import("node.zig").Node;
const BitVec = @import("./bitvec.zig");

// The tree for the input "hello world" would look like this:
//
//                     [Internal]
//                   /           \
//          [Internal]           [Internal]
//          /        \           /         \
//     [Internal]   [Internal]  'l'       [Internal]
//     /      \      /     \              /       \
//   'd'     'h'   'e'    'w'          'o'       [Internal]
//                                               /       \
//       ===========================           ' '       'r'
//       |    "hello world" tree   |
//       ===========================
//
const test_input = "hello world";

const Self = @This();

input: []const u8,
allocator: Allocator,

pub fn init(allocator: Allocator, input: []const u8) Self {
    return .{ .allocator = allocator, .input = input };
}

pub fn encode(self: *Self) !BitVec {
    var root = try self.buildTree();
    defer root.deinit(self.allocator);

    var bits = BitVec.init(self.allocator);
    try self.addHeader(&bits);
    try serializeTree(root, &bits);
    try self.encodeBytes(root, &bits);

    return bits;
}

test "encode" {
    var encoder = Self.init(testing.allocator, test_input);
    var bits = try encoder.encode();
    defer bits.deinit();

    var it = bits.iterator();
    while (it.next()) |b| {
        std.debug.print("{d}", .{b});
    }
    std.debug.print("\n", .{});
}

fn addHeader(self: *Self, bits: *BitVec) !void {
    const length: u64 = self.input.len;
    try bits.pushU64(length);
}

fn buildTree(self: *Self) !*const Node {
    var frequencies = try self.calculate_frequencies();
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

test "buildTree" {
    var encoder = Self.init(testing.allocator, test_input);
    var root = try encoder.buildTree();
    defer root.deinit(testing.allocator);

    std.debug.print("{s}\n", .{root});
}

const Frequencies = std.AutoHashMap(u8, u32);

fn calculate_frequencies(self: *Self) !Frequencies {
    var frequencies = Frequencies.init(self.allocator);
    for (self.input) |byte| {
        const result = try frequencies.getOrPut(byte);
        if (!result.found_existing) {
            result.value_ptr.* = 0;
        }
        result.value_ptr.* += 1;
    }
    return frequencies;
}

test "test frequencies" {
    const allocator = std.testing.allocator;

    var encoder = Self.init(allocator, test_input);
    var frequencies = try encoder.calculate_frequencies();
    defer frequencies.deinit();

    try testing.expectEqual(8, frequencies.count());

    var total: u32 = 0;
    var iterator = frequencies.iterator();
    while (iterator.next()) |entry| {
        const count = entry.value_ptr.*;
        total += count;
    }

    try testing.expectEqual(total, test_input.len);
}

const NodeAndPriority = struct { node: *const Node, priority: u32 };

const math = std.math;
fn greather_than(ctx: void, a: NodeAndPriority, b: NodeAndPriority) math.Order {
    _ = ctx;
    return math.order(a.priority, b.priority);
}

const PQgt = std.PriorityQueue(NodeAndPriority, void, greather_than);

fn prioritize(self: *Self, frequencies: *const Frequencies) !PQgt {
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

test "test prioritize" {
    const allocator = testing.allocator;

    var encoder = Self.init(allocator, test_input);

    var frequencies = try encoder.calculate_frequencies();
    defer frequencies.deinit();

    var queue = try encoder.prioritize(&frequencies);
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

fn serializeTree(root: *const Node, bits: *BitVec) !void {
    try serializeNode(root, bits);
}

fn serializeNode(node: *const Node, bits: *BitVec) !void {
    switch (node.*) {
        .leaf => |leaf_node| {
            try bits.push(1);
            try bits.pushByte(leaf_node.byte);
        },
        .internal => |internal_node| {
            try bits.push(0);
            try serializeNode(internal_node.left, bits);
            try serializeNode(internal_node.right, bits);
        },
    }
}

test "serialize tree" {
    var encoder = Self.init(testing.allocator, test_input);
    var root = try encoder.buildTree();
    defer root.deinit(testing.allocator);

    var bits = BitVec.init(testing.allocator);
    try serializeTree(root, &bits);
    defer bits.deinit();

    std.debug.print("Serialized Tree: ", .{});
    var it = bits.iterator();
    while (it.next()) |b| {
        std.debug.print("{d}", .{b});
    }
    std.debug.print("\n", .{});
}

fn encodeBytes(self: *Self, root: *const Node, bits: *BitVec) !void {
    var codes_by_char = try self.walkPathsForCodes(root);
    defer deinitCodesByChar(&codes_by_char);

    for (self.input) |byte| {
        const char_bits = codes_by_char.get(byte).?;
        try bits.append(&char_bits);
    }
}

test "encode bytes" {
    var encoder = Self.init(testing.allocator, test_input);
    var root = try encoder.buildTree();
    defer root.deinit(testing.allocator);

    var bits = BitVec.init(testing.allocator);
    defer bits.deinit();
    try encoder.encodeBytes(root, &bits);
    var bit = bits.iterator();
    while (bit.next()) |b| {
        std.debug.print("{d}", .{b});
    }
    std.debug.print("\n", .{});
}

const CodesByChar = std.AutoHashMap(u8, BitVec);

fn walkPathsForCodes(self: *Self, root: *const Node) !CodesByChar {
    var codes_by_char = CodesByChar.init(self.allocator);
    var bits = BitVec.init(self.allocator);
    defer bits.deinit();
    try self.walkNodeForCodes(
        root,
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

test "walk tree" {
    var encoder = Self.init(testing.allocator, test_input);
    var root = try encoder.buildTree();
    defer root.deinit(testing.allocator);

    var codes_by_char = try encoder.walkPathsForCodes(root);
    defer deinitCodesByChar(&codes_by_char);

    var codes_it = codes_by_char.iterator();
    while (codes_it.next()) |entry| {
        const c = entry.key_ptr.*;
        var bv = BitVec.init(testing.allocator);
        defer bv.deinit();
        try bv.pushByte(c);
        var it = bv.iterator();
        while (it.next()) |bit| {
            std.debug.print("{d}", .{bit});
        }
        std.debug.print("- {c} ({0b})- ", .{c});

        const bits = entry.value_ptr.*;
        var bit = bits.iterator();
        while (bit.next()) |b| {
            std.debug.print("{d}", .{b});
        }
        std.debug.print("\n", .{});
    }
}

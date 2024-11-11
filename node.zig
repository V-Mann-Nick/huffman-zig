const std = @import("std");
const Allocator = std.mem.Allocator;

const LeafNode = struct { char: []const u8 };
const InternalNode = struct { left: *const Node, right: *const Node };
const NodeType = enum { leaf, internal };
pub const Node = union(NodeType) {
    leaf: LeafNode,
    internal: InternalNode,

    const Self = @This();

    pub fn leaf(allocator: Allocator, char: []const u8) !*const Self {
        const node = try allocator.create(Self);
        node.* = Self{ .leaf = LeafNode{ .char = char } };
        return node;
    }

    pub fn internal(
        allocator: Allocator,
        left: *const Self,
        right: *const Self,
    ) !*const Self {
        const node = try allocator.create(Self);
        node.* = Self{ .internal = InternalNode{ .left = left, .right = right } };
        return node;
    }

    pub fn deinit(self: *const Self, allocator: Allocator) void {
        switch (self.*) {
            .internal => |int| {
                int.left.deinit(allocator);
                int.right.deinit(allocator);
            },
            .leaf => {},
        }
        allocator.destroy(self);
    }

    pub fn format(
        self: Self,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .leaf => |leaf_node| {
                try writer.writeAll("Leaf { ");
                try writer.print("char: {s}", .{leaf_node.char});
                try writer.writeAll(" }");
            },
            .internal => |internal_node| {
                try writer.writeAll("Internal { ");
                try writer.print("left: {s}, ", .{internal_node.left});
                try writer.print("right: {s}", .{internal_node.right});
                try writer.writeAll(" }");
            },
        }
    }
};

test "Node" {
    const testing = std.testing;
    const eql = std.mem.eql;
    const allocator = std.testing.allocator;

    const c1 = "a";
    const c2 = "b";

    const left = try Node.leaf(allocator, c1);
    const right = try Node.leaf(allocator, c2);
    const node = try Node.internal(allocator, left, right);
    defer node.deinit(allocator);

    try testing.expect(eql(u8, node.internal.left.leaf.char, c1));
    try testing.expect(c1.ptr == node.internal.left.leaf.char.ptr);
    try testing.expect(eql(u8, node.internal.right.leaf.char, c2));
}

test "Node print" {
    const allocator = std.testing.allocator;
    const testing = std.testing;

    const n1 = try Node.leaf(allocator, "a");
    const n2 = try Node.leaf(allocator, "b");
    const n3 = try Node.internal(allocator, n1, n2);
    defer n3.deinit(allocator);

    // const stdout = std.io.getStdOut().writer();
    // try stdout.print("{s}\n", .{n3});

    const n3_string = try std.fmt.allocPrint(allocator, "{s}", .{n3});
    defer allocator.free(n3_string);
    try testing.expect(std.mem.eql(
        u8,
        n3_string,
        "Internal { left: Leaf { char: a }, right: Leaf { char: b } }",
    ));
}

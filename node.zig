const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn Node(comptime allocator: Allocator) type {
    const LeafNode = struct { char: []const u8 };
    const InternalNode = struct { left: *const Node(allocator), right: *const Node(allocator) };
    const NodeType = enum { leaf, internal };
    return union(NodeType) {
        leaf: LeafNode,
        internal: InternalNode,

        const Self = @This();

        pub fn leaf(char: []const u8) !*const Self {
            const node = try allocator.create(Self);
            node.* = Self{ .leaf = LeafNode{ .char = char } };
            return node;
        }

        pub fn internal(left: *const Self, right: *const Self) !*const Self {
            const node = try allocator.create(Self);
            node.* = Self{ .internal = InternalNode{ .left = left, .right = right } };
            return node;
        }

        pub fn deinit(self: *const Self) void {
            switch (self.*) {
                .internal => |int| {
                    int.left.deinit();
                    int.right.deinit();
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
}

test "Node" {
    const expect = std.testing.expect;
    const eql = std.mem.eql;

    const c1 = "a";
    const c2 = "b";

    const TestNode = Node(std.testing.allocator);

    const left = try TestNode.leaf(c1);
    const right = try TestNode.leaf(c2);
    const node = try TestNode.internal(left, right);
    defer node.deinit();

    try expect(eql(u8, node.internal.left.leaf.char, c1));
    try expect(c1.ptr == node.internal.left.leaf.char.ptr);
    try expect(eql(u8, node.internal.right.leaf.char, c2));
}

test "Node print" {
    const allocator = std.testing.allocator;
    const expect = std.testing.expect;

    const TestNode = Node(allocator);
    const n1 = try TestNode.leaf("a");
    const n2 = try TestNode.leaf("b");
    const n3 = try TestNode.internal(n1, n2);
    defer n3.deinit();

    // const stdout = std.io.getStdOut().writer();
    // try stdout.print("{s}\n", .{n3});

    const n3_string = try std.fmt.allocPrint(allocator, "{s}", .{n3});
    defer allocator.free(n3_string);
    try expect(std.mem.eql(
        u8,
        n3_string,
        "Internal { left: Leaf { char: a }, right: Leaf { char: b } }",
    ));
}

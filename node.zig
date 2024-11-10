const std = @import("std");
const Allocator = std.mem.Allocator;

const LeafNode = struct { char: []const u8 };
const InternalNode = struct { left: *const Node, right: *const Node };
const NodeType = enum { leaf, internal };
const Node = struct {
    allocator: Allocator,
    data: union(NodeType) {
        leaf: LeafNode,
        internal: InternalNode,
    },

    fn leaf(allocator: Allocator, char: []const u8) !*const Node {
        const node = try allocator.create(Node);
        node.* = Node{
            .allocator = allocator,
            .data = .{ .leaf = LeafNode{ .char = char } },
        };
        return node;
    }

    fn internal(allocator: Allocator, left: *const Node, right: *const Node) !*const Node {
        const node = try allocator.create(Node);
        node.* = Node{
            .allocator = allocator,
            .data = .{ .internal = InternalNode{ .left = left, .right = right } },
        };
        return node;
    }

    fn deinit(node: *const Node) void {
        switch (node.data) {
            .internal => |int| {
                int.left.deinit();
                int.right.deinit();
            },
            .leaf => {},
        }
        node.allocator.destroy(node);
    }
};

test "Node" {
    const expect = std.testing.expect;
    const eql = std.mem.eql;
    const getStdOut = std.io.getStdOut;
    const allocator = std.testing.allocator;

    const c1 = "a";
    const c2 = "b";

    const left = try Node.leaf(allocator, c1);
    const right = try Node.leaf(allocator, c2);
    const node = try Node.internal(allocator, left, right);
    defer node.deinit();

    const stdout = getStdOut().writer();
    try expect(eql(u8, node.data.internal.left.data.leaf.char, c1));
    try stdout.print("c1: {X} c2: {X}\n", .{ c1.ptr, c2.ptr });
    try expect(c1.ptr == node.data.internal.left.data.leaf.char.ptr);
    try expect(eql(u8, node.data.internal.right.data.leaf.char, c2));
}

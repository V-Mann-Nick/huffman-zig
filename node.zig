const LeafNode = struct { char: []const u8 };
const InternalNode = struct { left: *const Node, right: *const Node };
const NodeType = enum { leaf, internal };
const Node = union(NodeType) {
    leaf: LeafNode,
    internal: InternalNode,

    fn leaf(char: []const u8) Node {
        return Node{ .leaf = LeafNode{ .char = char } };
    }

    fn internal(left: *const Node, right: *const Node) Node {
        return Node{ .internal = InternalNode{ .left = left, .right = right } };
    }
};

test "Node" {
    const expect = @import("std").testing.expect;
    const eql = @import("std").mem.eql;
    const getStdOut = @import("std").io.getStdOut;

    const c1 = "a";
    const c2 = "b";

    const node = Node.internal(&Node.leaf(c1), &Node.leaf(c2));

    const stdout = getStdOut().writer();
    try expect(eql(u8, node.internal.left.leaf.char, c1));
    try stdout.print("c1: {X} c2: {X}\n", .{ c1.ptr, c2.ptr });
    try expect(c1.ptr == node.internal.left.leaf.char.ptr);
    try expect(eql(u8, node.internal.right.leaf.char, c2));
}

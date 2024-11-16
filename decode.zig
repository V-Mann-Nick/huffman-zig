const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

const Node = @import("node.zig").Node;
const BitVec = @import("./bitvec.zig");

const Self = @This();

input: []const u8,
allocator: Allocator,

pub const DecodeError = error{ UnexpectedEof, OutOfMemory, InvalidTreePath };

pub fn init(allocator: Allocator, input: []const u8) Self {
    return .{ .allocator = allocator, .input = input };
}

pub fn decode(self: *Self) DecodeError!ArrayList(u8) {
    var bits = BitVec.init(self.allocator);
    defer bits.deinit();
    bits.bit_len = self.input.len << 3;
    try bits.bytes.appendSlice(self.input);

    var bits_iter = bits.iterator();
    const byte_len: u64 = bits_iter.take(64) catch {
        return DecodeError.UnexpectedEof;
    };
    const root = try self.parseTree(&bits_iter);
    defer root.deinit(self.allocator);

    return self.decodeBytes(root, &bits_iter, byte_len);
}

fn parseTree(self: *Self, bits_iter: *BitVec.Iterator) DecodeError!*const Node {
    const bit = bits_iter.next() orelse {
        return DecodeError.UnexpectedEof;
    };
    switch (bit) {
        0b1 => {
            const byte: u8 = bits_iter.take(8) catch {
                return DecodeError.UnexpectedEof;
            };
            return Node.leaf(self.allocator, byte);
        },
        0b0 => {
            const left = try self.parseTree(bits_iter);
            const right = try self.parseTree(bits_iter);
            return Node.internal(self.allocator, left, right);
        },
    }
}

const ArrayList = std.ArrayList;

fn decodeBytes(
    self: *Self,
    root: *const Node,
    bits_iter: *BitVec.Iterator,
    length: u64,
) DecodeError!ArrayList(u8) {
    var bytes = try ArrayList(u8).initCapacity(
        self.allocator,
        @as(usize, @intCast(length)),
    );

    var bytes_left = length;
    var current_node = root;
    while (true) {
        switch (current_node.*) {
            .leaf => |leaf_node| {
                try bytes.append(leaf_node.byte);
                bytes_left -= 1;
                current_node = root;
                if (bytes_left == 0) {
                    break;
                }
            },
            .internal => |internal_node| {
                const bit = bits_iter.next() orelse {
                    return DecodeError.UnexpectedEof;
                };
                current_node = switch (bit) {
                    0b1 => internal_node.right,
                    0b0 => internal_node.left,
                };
            },
        }
    }

    return bytes;
}

test "parse tree" {
    const serialized_tree = [_]u8{
        0b01001000, 0b00010110, 0b11001101, 0b10110010,
        0b01110111, 0b10110010, 0b11111001, 0b00100110,
        0b01001000, 0b0111001,
    };

    var bitvec = BitVec.init(testing.allocator);
    defer bitvec.deinit();
    for (serialized_tree) |byte| {
        try bitvec.pushBits(8, byte);
    }
    var it = bitvec.iterator();

    var decoder = Self.init(testing.allocator, "any");
    var root = try decoder.parseTree(&it);
    defer root.deinit(testing.allocator);

    std.debug.print("{s}", .{root});
}

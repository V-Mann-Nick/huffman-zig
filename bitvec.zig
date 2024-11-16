const BitVec = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

bytes: ArrayList(u8),
bit_len: usize = 0,

pub fn init(allocator: Allocator) BitVec {
    return .{
        .bytes = std.ArrayList(u8).init(allocator),
    };
}

pub fn deinit(self: *BitVec) void {
    self.bytes.deinit();
    self.* = undefined;
}

pub fn copy(self: *const BitVec, allocator: Allocator) !BitVec {
    var new_bits = BitVec.init(allocator);
    new_bits.bit_len = self.bit_len;
    try new_bits.bytes.appendSlice(self.bytes.items);
    return new_bits;
}

test "copy" {
    var bits = try createTestBitVec();
    defer bits.deinit();

    var new = try bits.copy(testing.allocator);
    defer new.deinit();

    try new.push(0);
    try testing.expectEqual(0, new.peek());
    try testing.expectEqual(1, bits.peek());
}

pub fn push(self: *BitVec, b: u1) !void {
    const byte_idx = self.bit_len >> 3;
    if (self.bytes.items.len <= byte_idx) {
        try self.bytes.append(0);
    }

    const bit_idx = @as(u3, @intCast(self.bit_len & 7));

    self.bytes.items[byte_idx] &= ~(@as(u8, 1) << bit_idx);
    self.bytes.items[byte_idx] |= @as(u8, b) << bit_idx;

    self.bit_len += 1;
}

pub fn pushBits(self: *BitVec, comptime n: comptime_int, v: uint(n)) !void {
    const max_i: uint(n) = n - 1;
    const i_bits = n - @clz(max_i);
    var i: uint(i_bits) = 0;
    while (true) {
        const bit = @as(u1, @intCast((v >> i) & 1));
        try self.push(bit);
        if (i == max_i) {
            break;
        }
        i += 1;
    }
}

pub fn get(self: *const BitVec, idx: usize) ?u1 {
    const byte_idx = idx >> 3;

    if (byte_idx >= self.bytes.items.len) {
        return null;
    }

    if (idx >= self.bit_len) {
        return null;
    }

    const bit_idx = @as(u3, @intCast(idx & 7));
    return @as(u1, @intCast((self.bytes.items[byte_idx] >> bit_idx) & 1));
}

pub fn peek(self: *const BitVec) ?u1 {
    return self.get(self.bit_len - 1);
}

pub fn pop(self: *BitVec) ?u1 {
    if (self.peek()) |b| {
        self.bit_len -= 1;
        return b;
    }
    return null;
}

pub fn append(self: *BitVec, other: *const BitVec) !void {
    var it = other.iterator();
    while (it.next()) |b| {
        try self.push(b);
    }
}

pub fn iterator(self: *const BitVec) Iterator {
    return Iterator.init(self);
}

pub const Iterator = struct {
    bit_vec: *const BitVec,
    idx: usize,

    fn init(bitvec: *const BitVec) Iterator {
        return Iterator{
            .bit_vec = bitvec,
            .idx = 0,
        };
    }

    pub fn next(self: *Iterator) ?u1 {
        const b = self.bit_vec.get(self.idx);
        self.idx += 1;
        return b;
    }

    pub fn take(self: *Iterator, comptime n: comptime_int) error{OutOfBits}!uint(n) {
        const max_shift: uint(n) = n - 1;
        const shift_int_bits = n - @clz(max_shift);
        var shift: uint(shift_int_bits) = 0;
        var bits: uint(n) = 0;
        while (true) {
            const bit = self.next() orelse {
                return error.OutOfBits;
            };
            bits &= ~(@as(uint(n), 1) << shift);
            bits |= @as(uint(n), bit) << shift;
            if (shift == max_shift) {
                break;
            }
            shift += 1;
        }
        return bits;
    }

    pub fn reset(self: *Iterator) void {
        self.idx = 0;
    }
};

fn uint(comptime b: comptime_int) type {
    const Signedness = std.builtin.Signedness;
    return @Type(.{
        .Int = .{ .signedness = Signedness.unsigned, .bits = b },
    });
}

const testing = std.testing;

/// Layout "0 11110001"
fn createTestBitVec() !BitVec {
    var bits = BitVec.init(testing.allocator);

    try bits.push(1);
    try bits.push(0);
    try bits.push(0);
    try bits.push(1);

    return bits;
}

const stdout = std.io.getStdOut().writer();
test "push, peek & pop" {
    var bits = try createTestBitVec();
    defer bits.deinit();

    try testing.expectEqual(1, bits.peek());
    try testing.expectEqual(1, bits.pop());

    try testing.expectEqual(0, bits.peek());
    try testing.expectEqual(0, bits.pop());

    try testing.expectEqual(0, bits.peek());
    try testing.expectEqual(0, bits.pop());

    try testing.expectEqual(1, bits.peek());
    try testing.expectEqual(1, bits.pop());
}

test "push byte" {
    var bits = try createTestBitVec();
    defer bits.deinit();

    try bits.pushBits(8, 0b11_01_01_11);

    try testing.expectEqual(1, bits.pop());
    try testing.expectEqual(1, bits.pop());
    try testing.expectEqual(0, bits.pop());
    try testing.expectEqual(1, bits.pop());
    try testing.expectEqual(0, bits.pop());
    try testing.expectEqual(1, bits.pop());
    try testing.expectEqual(1, bits.pop());
    try testing.expectEqual(1, bits.pop());
    try testing.expectEqual(1, bits.pop());
}

test "iterator" {
    var bits = try createTestBitVec();
    defer bits.deinit();

    var it = bits.iterator();
    try testing.expectEqual(1, it.next());
    try testing.expectEqual(0, it.next());
    try testing.expectEqual(0, it.next());
    try testing.expectEqual(1, it.next());
    try testing.expectEqual(null, it.next());
}

test "iterator take" {
    var bits = try createTestBitVec();
    defer bits.deinit();

    var it = bits.iterator();
    const i = try it.take(4);
    std.debug.print("{b}", .{i});
}

test "append" {
    var bits = try createTestBitVec();
    defer bits.deinit();

    var other_bits = BitVec.init(testing.allocator);
    defer other_bits.deinit();

    try other_bits.push(1);
    try other_bits.push(1);
    try other_bits.push(0);

    try bits.append(&other_bits);

    try testing.expectEqual(0, bits.pop());
    try testing.expectEqual(1, bits.pop());
    try testing.expectEqual(1, bits.pop());
    try testing.expectEqual(1, bits.pop());
    try testing.expectEqual(0, bits.pop());
    try testing.expectEqual(0, bits.pop());
    try testing.expectEqual(1, bits.pop());
}

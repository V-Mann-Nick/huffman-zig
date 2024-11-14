const std = @import("std");
const testing = std.testing;

test "random" {
    const b: u8 = 0b101;
    try testing.expectEqual(b, 5);

    var bit = @as(u1, b & 1);
    try testing.expectEqual(bit, 1);

    bit = @as(u1, (b >> 1) & 1);
    try testing.expectEqual(bit, 0);

    bit = @as(u1, (b >> 2) & 1);
    try testing.expectEqual(bit, 1);
}

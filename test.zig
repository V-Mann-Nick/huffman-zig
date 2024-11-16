const std = @import("std");
const testing = std.testing;

test "shift" {
    const max_shift: u4 = 3;
    // const b: u32 = @bitSizeOf(u32);
    const n = 4 - @clz(max_shift);
    try testing.expectEqual(2, n);

    try testing.expectEqual(16, 2 << 3);
}

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

const FileOpenError = error{
    AccessDenied,
    // OutOfMemory,
    FileNotFound,
};

const expect = @import("std").testing.expect;

const AllocationError = error{OutOfMemory};

test "coerce error from a subset to a superset" {
    const err: FileOpenError = AllocationError.OutOfMemory;
    try expect(err == FileOpenError.OutOfMemory);
}

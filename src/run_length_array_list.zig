const std = @import("std");

pub fn RunLengthArrayList(comptime T: type) type {
    const byte_len = @divExact(@typeInfo(T).Int.bits, 8);
    return struct {
        const Self = @This();

        data: std.ArrayList(u8),

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .data = std.ArrayList(u8).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.data.deinit();
        }

        pub fn append(self: *Self, value: T) !void {
            if (self.data.items.len == 0 or self.readLastValue() != value) {
                var writer = self.data.writer();
                try writer.writeByte(1);
                errdefer _ = self.data.pop();

                try writer.writeIntNative(T, value);
                return;
            }

            self.data.items[self.data.items.len - byte_len - 1] += 1;
            return;
        }

        pub fn pop(self: *Self) T {
            const count = &self.data.items[self.data.items.len - byte_len - 1];
            const value = self.readLastValue();

            if (count.* == 1) {
                self.data.items.len -= byte_len + 1;
            } else {
                count.* -= 1;
            }

            return value.?;
        }

        pub fn getValue(self: *const Self, index: usize) ?T {
            var curr: usize = 0;
            var i: usize = 0;
            while (i < self.data.items.len) {
                const count = self.data.items[i];
                if (index < curr + count) {
                    return self.readValueAtRaw(i + 1);
                }
                curr += count;
                i += byte_len + 1;
            }
            return null;
        }

        fn readLastValue(self: *const Self) ?T {
            return self.readValueAtRaw(self.data.items.len - byte_len);
        }

        fn readValueAtRaw(self: *const Self, index: usize) ?T {
            std.debug.assert(index + byte_len <= self.data.items.len);
            const v = std.mem.readIntNative(T, @ptrCast(*const [byte_len]u8, self.data.items[index..]));
            return v;
        }
    };
}

var test_allocator = std.testing.allocator;

test "system is little endian" {
    // NOTE: These tests assume little endian because I'm lazy
    const endian = @import("builtin").target.cpu.arch.endian();
    try std.testing.expectEqual(endian, .Little);
}

test "byte order" {
    var arr = RunLengthArrayList(u32).init(test_allocator);
    defer arr.deinit();

    try arr.append(1);
    try arr.append(1);
    try arr.append(2);

    try std.testing.expectEqualSlices(u8, &.{ 2, 1, 0, 0, 0, 1, 2, 0, 0, 0 }, arr.data.items);
}

test "getValue" {
    var arr = RunLengthArrayList(u32).init(test_allocator);
    defer arr.deinit();

    try arr.append(1);
    try arr.append(1);
    try arr.append(2);
    try arr.append(3);

    try std.testing.expectEqual(arr.getValue(0), 1);
    try std.testing.expectEqual(arr.getValue(1), 1);
    try std.testing.expectEqual(arr.getValue(2), 2);
    try std.testing.expectEqual(arr.getValue(3), 3);
}

test "pop" {
    var arr = RunLengthArrayList(u32).init(test_allocator);
    defer arr.deinit();

    try arr.append(1);
    try arr.append(1);
    try arr.append(2);

    try std.testing.expectEqual(@as(u32, 2), arr.pop());
    try std.testing.expectEqual(@as(u32, 1), arr.pop());
    try std.testing.expectEqual(@as(u32, 1), arr.pop());
    try std.testing.expectEqual(@as(usize, 0), arr.data.items.len);
}

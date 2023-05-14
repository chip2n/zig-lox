const std = @import("std");

const stdout_file = std.io.getStdOut().writer();
var bw = std.io.bufferedWriter(stdout_file);
const stdout = bw.writer();

const OpCode = enum(u8) {
    ret,
    constant,
};

const Value = f64;

const Chunk = struct {
    const Self = @This();

    data: std.ArrayList(u8),
    constants: std.ArrayList(Value),

    lines: std.ArrayList(usize),

    fn init(allocator: std.mem.Allocator) Self {
        return .{
            .data = std.ArrayList(u8).init(allocator),
            .constants = std.ArrayList(Value).init(allocator),
            .lines = std.ArrayList(usize).init(allocator),
        };
    }

    fn deinit(self: *Self) void {
        self.data.deinit();
        self.constants.deinit();
        self.lines.deinit();
    }

    fn write(self: *Self, data: anytype, line: usize) !void {
        const T = @TypeOf(data);
        try self.lines.append(line);
        errdefer _ = self.lines.pop();
        switch (T) {
            u8 => try self.data.append(data),
            OpCode => try self.data.append(@enumToInt(data)),
            else => {
                // Allow plain enum literals if there's a matching OpCode
                if (@typeInfo(T) == .EnumLiteral) {
                    inline for (std.meta.fields(OpCode)) |tag| {
                        if (comptime std.mem.eql(u8, tag.name, @tagName(data))) {
                            return try self.data.append(tag.value);
                        }
                    }
                    @compileError("Enum literal ." ++ @tagName(data) ++ " is not a valid op code.");
                } else {
                    @compileError("Type " ++ @typeName(T) ++ " cannot be written to " ++ @typeName(Self));
                }
            },
        }
    }

    fn addConstant(self: *Self, constant: Value) !u8 {
        try self.constants.append(constant);
        return @intCast(u8, self.constants.items.len - 1);
    }
};

fn disassembleChunk(chunk: *const Chunk, name: []const u8) !void {
    try stdout.print("== {s} ==\n", .{name});

    var offset: usize = 0;
    while (offset < chunk.data.items.len) {
        offset = try disassembleInstruction(chunk, offset);
    }

    try bw.flush();
}

fn disassembleInstruction(chunk: *const Chunk, offset: usize) !usize {
    try stdout.print("{d:0>4} ", .{offset});

    if (offset > 0 and (chunk.lines.items[offset] == chunk.lines.items[offset - 1])) {
        try stdout.print("   | ", .{});
    } else {
        try stdout.print("{d:4} ", .{chunk.lines.items[offset]});
    }

    const byte = chunk.data.items[offset];
    const instruction = std.meta.intToEnum(OpCode, byte) catch {
        try stdout.print("Unknown opcode {}\n", .{byte});
        return offset + 1;
    };
    switch (instruction) {
        .ret => return try simpleInstruction("OP_RETURN", offset),
        .constant => return try constantInstruction("OP_CONSTANT", chunk, offset),
    }
}

fn simpleInstruction(name: []const u8, offset: usize) !usize {
    try stdout.print("{s}\n", .{name});
    return offset + 1;
}

fn constantInstruction(name: []const u8, chunk: *const Chunk, offset: usize) !usize {
    const c = chunk.data.items[offset + 1];
    try stdout.print("{s: <16} {d} '", .{ name, c });
    try printValue(chunk.constants.items[c]);
    try stdout.print("'\n", .{});
    return offset + 2;
}

fn printValue(value: Value) !void {
    try stdout.print("{d}", .{value});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var chunk = Chunk.init(allocator);
    defer chunk.deinit();

    const c = try chunk.addConstant(1.2);
    try chunk.write(.constant, 123);
    try chunk.write(c, 123);
    try chunk.write(.ret, 123);

    try disassembleChunk(&chunk, "test chunk");
}

test {
    std.testing.refAllDecls(@import("run_length_array_list.zig"));
}

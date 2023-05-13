const std = @import("std");

const stdout_file = std.io.getStdOut().writer();
var bw = std.io.bufferedWriter(stdout_file);
const stdout = bw.writer();

const OpCode = enum(u8) {
    ret,
};

const Chunk = std.ArrayList(u8);

fn disassembleChunk(chunk: *const Chunk, name: []const u8) !void {
    try stdout.print("== {s} ==\n", .{name});

    var offset: usize = 0;
    while (offset < chunk.items.len) {
        offset = try disassembleInstruction(chunk, offset);
    }

    try bw.flush();
}

fn disassembleInstruction(chunk: *const Chunk, offset: usize) !usize {
    try stdout.print("{d:0>4} ", .{offset});

    const byte = chunk.items[offset];
    const instruction = std.meta.intToEnum(OpCode, byte) catch {
        try stdout.print("Unknown opcode {}\n", .{byte});
        return offset + 1;
    };
    switch (instruction) {
        .ret => return try simpleInstruction("OP_RETURN", offset),
    }
}

fn simpleInstruction(name: []const u8, offset: usize) !usize {
    try stdout.print("{s}\n", .{name});
    return offset + 1;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var chunk = Chunk.init(allocator);
    defer chunk.deinit();

    try chunk.append(@enumToInt(OpCode.ret));

    try disassembleChunk(&chunk, "test chunk");
}

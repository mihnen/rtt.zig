const std = @import("std");

pub fn build(b: *std.Build) !void {
    _ = b.standardTargetOptions(.{});
    _ = b.standardOptimizeOption(.{});

    _ = b.addModule("rtt", .{
        .source_file = .{ .path = "rtt.zig" },
    });
}

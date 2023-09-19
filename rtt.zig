// The contents of this file is dual-licensed under the MIT or 0BSD license.

const std = @import("std");

const fmt = std.fmt;

/// The global control block.
export var _SEGGER_RTT: extern struct {
    magic: [16]u8,
    max_up_channels: usize,
    max_down_channels: usize,
    channel: Channel,
} = .{
    .magic = [_]u8{
        '_', 'S', 'E', 'G', 'G', 'E', 'R', '_', 'R', 'T', 'T', 0, 0, 0, 0, 0,
    },
    .max_up_channels = 1,
    .max_down_channels = 0,
    .channel = .{
        .name = "rtt.zig",
        .buf = undefined,
        .bufsz = 0,
        .write = 0,
        .read = 0,
        .flags = 0,
    },
};

/// Initialize and acquire a pointer to the RTT channel.
///
/// This function must be called exactly once at the start of your firmware.
pub fn init(comptime bufsz: usize, buf: *[bufsz]u8) *Channel {
    var ch = &_SEGGER_RTT.channel;
    ch.buf = buf;
    ch.bufsz = bufsz;
    return ch;
}

/// An RTT channel.
///
/// The `rtt.zig` library only provides writeable _up-channels_ for sending log
/// data to the host.
///
/// The channel is not reentrant. Any concurrent use of the channel must be
/// protected with a critical section.
///
/// Channel functions may block if the RTT buffer is full. If the host-side has
/// disconnected and is no longer reading from the channel the microcontroller
/// will lock up.
pub const Channel = extern struct {
    name: [*]const u8,
    buf: [*]u8,
    bufsz: usize,
    write: usize,
    read: usize,
    flags: usize,

    /// Print something to the RTT channel.
    pub fn print(
        self: *Channel,
        comptime fmt_str: []const u8,
        args: anytype,
    ) void {
        const writer = Writer{ .channel = self };
        fmt.format(writer, fmt_str, args) catch unreachable;
    }

    /// Write some bytes directly to the RTT channel.
    pub fn writeAll(self: *Channel, bytes: []const u8) void {
        const writer = Writer{ .channel = self };
        writer.writeAll(bytes) catch unreachable;
    }
};

const Writer = struct {
    channel: *Channel,

    /// The writer is infallible.
    pub const Error = error{};

    pub fn writeAll(self: Writer, bytes: []const u8) Writer.Error!void {
        _ = bytes;
        _ = self;
    }

    pub fn writeByteNTimes(
        self: Writer,
        byte: u8,
        n: usize,
    ) Writer.Error!void {
        for (0..n) |_| self.writeAll(&[_]u8{byte}) catch unreachable;
    }
};

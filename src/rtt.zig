// The contents of this file is dual-licensed under the MIT or 0BSD license.

//! A target-side implementation of the Real-Time Transfer protocol.
//!
//! The library provides a single writeable _up-channel_ for sending log data to
//! the host. The functions in this library are also not reentrant; concurrent
//! use must be protected with a critical section.
//!
//! Functions will block if the RTT buffer is full. If the host-side has
//! disconnected and is no longer reading from the channel the microcontroller
//! will lock up.
//!
//! # Examples
//!
//! ```zig
//! const rtt = @import("rtt");
//!
//! export fn main(void) callconv(.C) noreturn {
//!     rtt.println("Hello from {s}", .{"Zig!"});
//!     while (true) {}
//! }
//! ```

const std = @import("std");

const atomic = std.atomic;
const debug = std.debug;
const fmt = std.fmt;

/// Print something to the RTT channel.
///
/// Uses the `std.fmt` plumbing under the hood.
pub fn print(comptime fmt_str: []const u8, args: anytype) void {
    _SEGGER_RTT.channel.print(fmt_str, args);
}

/// Print something to the RTT channel, with a newline.
///
/// Uses the `std.fmt` plumbing under the hood.
pub fn println(comptime fmt_str: []const u8, args: anytype) void {
    _SEGGER_RTT.channel.print(fmt_str, args);
    _SEGGER_RTT.channel.writeAll("\n");
}

/// Write raw bytes directly to the RTT channel.
///
/// Does _not_ use the `std.fmt` plumbing.
pub fn writeAll(bytes: []const u8) void {
    _SEGGER_RTT.channel.writeAll(bytes);
}

const RTT_MODE_TRUNC = 1;
const RTT_MODE_BLOCK = 2;

const BUF_LEN = 256;
var BUF: [BUF_LEN]u8 = undefined;

export var _SEGGER_RTT: extern struct {
    magic: [16]u8,
    max_up_channels: usize,
    max_down_channels: usize,
    channel: Channel,
} = .{
    .magic = [_]u8{
        'S', 'E', 'G', 'G', 'E', 'R', ' ', 'R', 'T', 'T', 0, 0, 0, 0, 0, 0,
    },
    .max_up_channels = 1,
    .max_down_channels = 0,
    .channel = .{
        .name = "rtt.zig",
        .buf = &BUF,
        .bufsz = BUF_LEN,
        .write = 0,
        .read = 0,
        .flags = RTT_MODE_BLOCK,
    },
};

const Channel = extern struct {
    name: [*]const u8,
    buf: [*]u8,
    bufsz: usize,
    write: usize,
    read: usize,
    flags: usize,

    fn print(
        self: *Channel,
        comptime fmt_str: []const u8,
        args: anytype,
    ) void {
        const writer = Writer{ .chan = self };
        fmt.format(writer, fmt_str, args) catch unreachable;
    }

    fn writeAll(self: *Channel, bytes: []const u8) void {
        const writer = Writer{ .chan = self };
        writer.writeAll(bytes) catch unreachable;
    }
};

const Writer = struct {
    chan: *Channel,

    pub const Error = error{}; // infallible

    pub fn writeAll(self: Writer, bytes: []const u8) Writer.Error!void {
        var xs = bytes;

        while (xs.len != 0) {
            const write = readVolatile(&self.chan.write);
            const read = readVolatile(&self.chan.read);
            const avail = maxContiguous(read, write);

            const n = @min(xs.len, avail);
            if (n == 0) {
                // todo: add non-blocking impl with truncated writes
                debug.assert(readVolatile(&self.chan.flags) == RTT_MODE_BLOCK);
                continue;
            }

            @memcpy(self.chan.buf[write .. write + n], xs[0..n]);
            writeVolatile(&self.chan.write, (write + n) % BUF_LEN);
            xs = xs[n..];
        }
    }

    pub fn writeByteNTimes(
        self: Writer,
        byte: u8,
        n: usize,
    ) Writer.Error!void {
        for (0..n) |_| self.writeAll(&[_]u8{byte}) catch unreachable;
    }
};

inline fn readVolatile(ptr: *const volatile usize) usize {
    return ptr.*;
}

inline fn writeVolatile(ptr: *volatile usize, val: usize) void {
    ptr.* = val;
}

inline fn maxContiguous(read: usize, write: usize) usize {
    return if (read > write)
        read - write - 1
    else if (read == 0)
        BUF_LEN - write - 1
    else
        BUF_LEN - write;
}

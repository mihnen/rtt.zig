# _rtt.zig_

A Real-Time Transfer (target side) implementation in Zig.

Dual licensed under the 0BSD and MIT licenses.

## Usage

```zig
const rtt = @import("rtt");

export fn main(void) callconv(.C) noreturn {
    rtt.println("Hello from {s}", .{"Zig!"});
    while (true) {}
}
```

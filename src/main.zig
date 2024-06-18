const std = @import("std");
const print = std.debug.print;
const expect = std.testing.expect;
const process = std.process;

var bytes_width: u32 = 8;
var is_lsb: bool = true;
const defined_args = &[_][]const u8{
    "-m",
    "-l",
    "-g",
    "-w",
};

// *const [][:0]u8 = pointer to an array of zero terminated const u8 values
fn parseArgs(args_p: *const [][:0]u8) [:0]u8 {
    var str: [:0]u8 = undefined;
    //print("{p}\n", .{args_p});

    for (args_p.*) |arg| {
        if (std.mem.eql(u8, arg, "-g")) {
            bytes_width = 8;
        } else if (std.mem.eql(u8, arg, "-w")) {
            bytes_width = 4;
        } else if (std.mem.eql(u8, arg, "-l")) {
            is_lsb = true;
        } else if (std.mem.eql(u8, arg, "-m")) {
            is_lsb = false;
        } else {
            str = arg;
        }
    }

    return str;
}

// str_p should not be modified!!
fn toAscii(str: []u8) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) expect(false) catch @panic("TEST FAIL");
    }

    const str_p: [*]u8 = @ptrCast(@constCast(str));
    const str_len: u32 = @intCast(str.len);
    const dst_len: u32 = ((str_len + (bytes_width - 1)) / bytes_width) * bytes_width;
    const dst_buf = try allocator.alloc(u8, dst_len);
    @memset(dst_buf, 0);
    defer allocator.free(dst_buf);

    // reverse and copy the seq bytes str_p[i] to str_p[i+7]
    if (is_lsb) {
        for (0..dst_len) |i| {
            if (@mod(i + 1, bytes_width) == 0) {
                for (0..bytes_width) |j| {
                    if (i - j < str_len)
                        dst_buf[i - (bytes_width - 1) + j] = str_p[i - j];
                }
            }
        }
    } else {
        for (0..dst_len) |i| {
            dst_buf[i] = str_p[i];
        }
    }

    for (0..dst_len) |i| {
        if (@mod(i, bytes_width) == 0) {
            print("0x", .{});
            for (0..bytes_width) |j|
                print("{x:0<2}", .{dst_buf[i + j]});
            print(" ", .{});
        }
    }
    print("\n", .{});
}

pub fn main() !void {
    const args = try process.argsAlloc(std.heap.page_allocator);
    defer process.argsFree(std.heap.page_allocator, args);

    if (args.len < 2) {
        print("usage: str2ascii {{string}} |option|\n-l: least significant bit\n-m: most significant bit\n-g: 8 byte width\n-w: 4 byte width\n", .{});
        return;
    }

    const str: []u8 = parseArgs(&args);
    print("{s}\n", .{str});
    toAscii(str) catch unreachable;
}

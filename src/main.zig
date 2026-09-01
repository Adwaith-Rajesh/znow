/// znow - A simple snowflake generator
/// Copyright (c) 2026 Adwaith-Rajesh <me[at]adwaith[dot]dev>
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in all
/// copies or substantial portions of the Software.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
/// SOFTWARE.
///
const std = @import("std");

const WORKER_ID_BITS = 10;
const SEQUENCE_BITS = 12;
const MAX_SEQUENCE = ((1 << SEQUENCE_BITS) - 1);
const WORKER_ID_SHIFT = SEQUENCE_BITS;
const TIMESTAMP_SHIFT = WORKER_ID_BITS + SEQUENCE_BITS;

// The enums are called thread_safe and not_thread_safe because
// I wanted them to be as obvious as possible since these values are
// passed at comptime and anyone reading the type Snowflake(.thread_safe) can
// instantly say, "Yep, thread safe implementation of Snowflake"
pub const ThreadSafe = enum(u8) {
    thread_safe,
    not_thread_safe,
};

pub fn Snowflake(comptime thread_safe: ThreadSafe) type {
    return struct {
        io: std.Io,

        worker_id: u16,

        // Jan 2025 00:00:00 in ms
        custom_epoch: u64 = 1735689600000,

        sequence: u16 = 0,
        last_timestamp: u64 = 0,
        mutex: if (thread_safe == .thread_safe) std.Io.Mutex else void = if (thread_safe == .thread_safe) .init else {},

        const Self = @This();

        pub fn init(io: std.Io, worker_id: u16) Self {
            return .{
                .io = io,
                .worker_id = worker_id,
            };
        }

        inline fn nowMs(self: *const Self) u64 {
            return @intCast(std.Io.Clock.now(.real, self.io).toMilliseconds());
        }

        fn waitNextMS(self: *const Self) u64 {
            var curr_ts: u64 = self.nowMs();
            while (curr_ts <= self.last_timestamp) {
                curr_ts = self.nowMs();
            }
            return curr_ts;
        }

        pub fn next(self: *Self) !u64 {
            if (thread_safe == .thread_safe) try self.mutex.lock(self.io);
            defer if (thread_safe == .thread_safe) self.mutex.unlock(self.io);

            var ts: u64 = self.nowMs();

            if (ts == self.last_timestamp) {
                self.sequence = (self.sequence + 1) & MAX_SEQUENCE;

                if (self.sequence == 0) {
                    ts = self.waitNextMS();
                }
            } else {
                self.sequence = 0;
            }
            self.last_timestamp = ts;
            return ((ts - self.custom_epoch) << TIMESTAMP_SHIFT) | (self.worker_id << WORKER_ID_SHIFT) | self.sequence;
        }
    };
}

test "Snowflake_no_threads" {
    // is this test even necessary
    var flake: Snowflake(.not_thread_safe) = .init(std.testing.io, 12);

    var set: std.AutoHashMap(u64, void) = .init(std.testing.allocator);
    defer set.deinit();

    for (0..5000) |_| {
        const id = try flake.next();
        const res = try set.getOrPut(id);

        try std.testing.expect(!res.found_existing);
    }
}

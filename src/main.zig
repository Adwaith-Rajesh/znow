const std = @import("std");

const WORKER_ID_BITS = 10;
const SEQUENCE_BITS = 12;
const MAX_SEQUENCE = ((1 << SEQUENCE_BITS) - 1);
const WORKER_ID_SHIFT = SEQUENCE_BITS;
const TIMESTAMP_SHIFT = WORKER_ID_BITS + SEQUENCE_BITS;

fn Snowflake(comptime thread_safe: bool) type {
    return struct {
        io: std.Io,

        worker_id: u16,

        // Jan 2025 00:00:00 in ms
        custom_epoch: u64 = 1735689600000,

        sequence: u16 = 0,
        last_timestamp: u64 = 0,
        mutex: if (thread_safe) std.Io.Mutex else void = if (thread_safe) .init else {},

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
            if (thread_safe) try self.mutex.lock(self.io);
            defer if (thread_safe) self.mutex.unlock(self.io);

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
    var flake: Snowflake(false) = .init(std.testing.io, 12);

    var set: std.AutoHashMap(u64, void) = .init(std.testing.allocator);
    defer set.deinit();

    for (0..5000) |_| {
        const id = try flake.next();
        const res = try set.getOrPut(id);

        try std.testing.expect(!res.found_existing);
    }
}

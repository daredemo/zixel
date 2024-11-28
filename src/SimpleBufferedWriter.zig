const std = @import("std");

/// A simple custom writer with a buffer
pub const SimpleBufferedWriter = struct {
    /// maximum size of buffer
    size: usize = 4096,
    /// the buffer
    list: std.BoundedArray(u8, 4096) = .{},

    const Self = @This();

    /// The Writer
    const Writer = std.io.Writer(
        *Self,
        error{ EndOfBuffer, Overflow },
        appendWrite,
    );

    /// clear the buffer
    pub fn clear(
        self: *Self,
    ) !*Self {
        if (self.list.len > 0) {
            _ = try self.list.resize(0);
        }
        return self;
    }

    /// write the buffer to stdout and clear the buffer
    pub fn flush(
        self: *Self,
    ) !*Self {
        if (self.list.len > 0) {
            _ = try std.io.getStdOut().writer().print(
                "{s}",
                .{self.list.slice()},
            );
            _ = try self.clear();
        }
        return self;
    }

    /// writeFn (std.io.Writer)
    pub fn appendWrite(
        self: *Self,
        data: []const u8,
    ) error{ EndOfBuffer, Overflow }!usize {
        if (self.list.len + data.len > self.size) {
            return error.EndOfBuffer;
        }
        if (self.list.len + data.len > 2048) {
            _ = self.flush() catch unreachable;
        }
        _ = try self.list.appendSlice(data);
        return data.len;
    }

    /// writer (std.io.Writer)
    pub fn writer(
        self: *Self,
    ) Writer {
        return .{ .context = self };
    }
};

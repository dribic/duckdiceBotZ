// Copyright (C) 2025 Dejan Ribič
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

const std = @import("std");
const types = @import("types.zig");
const net = @import("net.zig");
const aritmethic = @import("arithmetic.zig");

pub fn placeABet(
    url: []const u8,
    currency: []const u8,
    amount_f: f128,
    faucet: bool,
    chance: []const u8,
    is_high: bool,
    allocator: std.mem.Allocator,
) !bool {
    var buf: [64]u8 = undefined;
    const amount = try std.fmt.bufPrint(&buf, "{d:.8}", .{amount_f});

    const bet = types.OriginalDicePlayRequest{ .amount = amount, .chance = chance, .symbol = currency, .isHigh = is_high, .faucet = faucet };

    var body_writter: std.io.Writer.Allocating = .init(allocator);
    defer body_writter.deinit();

    var s = std.json.Stringify{
        .writer = &body_writter.writer,
        .options = .{ .whitespace = .minified, .emit_null_optional_fields = false }, // or .indent_2 for pretty
    };
    try s.write(bet);

    const slice = try body_writter.toOwnedSlice();

    const response = try net.postUsingCurl(allocator, url, slice);
    var result = try std.json.parseFromSlice(types.DicePlayResponse, allocator, response, .{ .ignore_unknown_fields = true });
    defer result.deinit();

    return result.value.bet.?.result;
}

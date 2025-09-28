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
    client: *std.http.Client,
    allocator: std.mem.Allocator,
) !bool {
    var buf = try allocator.alloc(u8, 512);
    const amount = try std.fmt.bufPrint(&buf, "{d:.8}", .{amount_f});

    const bet = types.OriginalDicePlayRequest{ .amount = amount, .chance = chance, .symbol = currency, .isHigh = is_high, .faucet = faucet };

    var json_buf = std.ArrayList(u8){};
    defer json_buf.deinit(allocator);

    var stream = json_buf.writer(allocator);

    var stringify = std.json.Stringify(.{}, &stream);
    try stringify.print(bet);

    const response = try net.post(url, json_buf.items, client, allocator);
    var result = try std.json.parseFromSlice(types.DicePlayResponse, allocator, response, .{ .ignore_unknown_fields = true });
    defer result.deinit();

    return result.value.Bet.result;
}

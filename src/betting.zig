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

pub fn labouchere(
    url: []const u8,
    currency: []const u8,
    element_f: f128,
    faucet: bool,
    starting_balance: f128,
    goal_balance: f128,
    is_high: bool,
    allocator: std.mem.Allocator,
) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var betting_seq = std.ArrayList(f128){};
    defer betting_seq.deinit(allocator);

    try betting_seq.ensureTotalCapacity(allocator, 15); // Pre-allocating slightly larger capacity, because bet odds less than 50%
    try betting_seq.appendNTimes(allocator, element_f, 10);

    const factor: f128 = if (faucet) 1.2045 else 1.25;

    try stdout.print("Betting slip:\n[ ", .{});
    for (betting_seq.items) |ele| {
        try stdout.print("{d:.8} ", .{ele});
    }
    try stdout.print("]\n", .{});
    try stdout.flush();

    var current_balance: f128 = starting_balance;

    while (current_balance < goal_balance) {
        if (betting_seq.items.len == 0) {
            const msgs = [_][]const u8{ "🖖 Sequence collapsed... initiating Vulcan logic reboot.", "✨ The Force has balanced... resetting Jedi sequence.", "🌀 Wormhole unstable — recalibrating Stargate sequence.", "🚀 Sequence fell out of warp — reinitializing at starbase.", "💫 Hyperdrive misfire! Restoring sequence from backup crystals.", "⚡ Phaser overload detected — diverting power to new sequence.", "👽 Borg interference detected — sequence has been assimilated, regenerating...", "🌌 Death Star superlaser misfire — reconstructing sequence from debris.", "🔮 ZPM fluctuations detected — Stargate dialing new sequence.", "📡 Subspace anomaly detected — rematerializing betting sequence.", "🛰️ Shields at 10%! Diverting power to sequence restoration.", "🕳️ Sequence fell into a black hole... retrieving via temporal anomaly.", "🤖 R2-D2 rerouted power — rebooting sequence systems.", "🪐 Sequence lost in the Gamma Quadrant... calling USS Defiant for backup." };

            const idx = std.crypto.random.intRangeLessThan(usize, 0, msgs.len);

            try stdout.print("{s}\n", .{msgs[idx]});
            try stdout.flush();

            try betting_seq.appendNTimes(allocator, element_f, 10);
        }

        const final_idx = betting_seq.items.len - 1;
        const bet_amount = if (final_idx == 0) betting_seq.items[0] else aritmethic.add(betting_seq.items[0], betting_seq.items[final_idx], 1.0);

        if (bet_amount > current_balance) {
            try stdout.print("Balance too low!\n", .{});
            try stdout.flush();
            return;
        }

        const bet_result = try placeABet(url, currency, bet_amount, faucet, "44", is_high, allocator);

        if (bet_result) {
            current_balance = aritmethic.add(current_balance, bet_amount, factor);
            _ = betting_seq.pop();
            _ = betting_seq.orderedRemove(0);
            try stdout.writeAll("Success!✅\n");
            try stdout.flush();
        } else {
            current_balance = aritmethic.sub(current_balance, bet_amount);
            try betting_seq.append(allocator, bet_amount);
            try stdout.writeAll("Failure!☯ \n");
            try stdout.flush();
        }

        try stdout.print("Current betting slip:\n[ ", .{});
        for (betting_seq.items) |ele| {
            try stdout.print("{d:.8} ", .{ele});
        }
        try stdout.print("]\n", .{});
        try stdout.flush();
    }
}

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
    const writer = &body_writter.writer;
    defer body_writter.deinit();

    try std.json.Stringify.value(bet, .{ .emit_null_optional_fields = false, .whitespace = .minified }, writer);

    const slice = body_writter.written();

    const response = try net.postUsingCurl(allocator, url, slice);
    var result = try std.json.parseFromSlice(types.DicePlayResponse, allocator, response, .{ .ignore_unknown_fields = true });
    defer result.deinit();

    return result.value.bet.?.result;
}

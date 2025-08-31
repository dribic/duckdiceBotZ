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

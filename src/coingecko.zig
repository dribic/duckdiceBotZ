const std = @import("std");
const net = @import("net.zig");

const PricesMap = std.StringHashMap(f128);
const CoinsMap = std.StringHashMap(PricesMap);

fn addingCoinNames(names_map: *std.StringHashMap([]const u8)) !void {
    try names_map.put("ETH", "ethereum");
    try names_map.put("TRX", "tron");
    try names_map.put("USDT", "tether");
}

pub fn calculateMinimum(allocator: std.mem.Allocator, dd_coin_name: []const u8) !u128 {
    var coingecko_names = std.StringHashMap([]const u8).init(allocator);
    defer coingecko_names.deinit();

    try addingCoinNames(&coingecko_names);

    const coin = coingecko_names.get(dd_coin_name) orelse dd_coin_name;

    const url = if (std.mem.eql(u8, coin, "bitcoin"))
        try std.fmt.allocPrint(allocator, "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd", .{})
    else
        try std.fmt.allocPrint(allocator, "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,{s}&vs_currencies=usd", .{coin});
    defer allocator.free(url);

    var client = std.http.Client{
        .allocator = allocator,
    };
    defer client.deinit();

    const json_data = try net.getCoingecko(url, &client, allocator);

    // --- Parse into JSON Value ---
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_data, .{});
    defer parsed.deinit();
    const root = parsed.value;

    // --- Build CoinsMap ---
    var coins = CoinsMap.init(allocator);
    defer {
        var it = coins.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit(); // free inner PricesMap
        }
        coins.deinit();
    }

    if (root != .object) return error.InvalidJson;

    var coin_it = root.object.iterator();
    while (coin_it.next()) |coin_entry| {
        const coin_name = coin_entry.key_ptr.*;
        const coin_value = coin_entry.value_ptr.*;

        if (coin_value != .object) continue;

        var prices = PricesMap.init(allocator);

        var price_it = coin_value.object.iterator();
        while (price_it.next()) |price_entry| {
            const currency = price_entry.key_ptr.*;
            const price_value = price_entry.value_ptr.*;

            const as_f128 = switch (price_value) {
                .float => |x| x,
                .integer => |x| @as(f128, @floatFromInt(x)),
                else => continue, // ignore non-numbers
            };

            try prices.put(currency, as_f128);
        }

        try coins.put(coin_name, prices);
    }

    // --- Example usage ---
    if (coins.get("bitcoin")) |btc_prices| {
        if (btc_prices.get("usd")) |usd| {
            std.debug.print("Bitcoin price (USD): {d}\n", .{usd});
        }
    }

    if (coins.get(coin)) |coin_prices| {
        if (coin_prices.get("usd")) |usd| {
            std.debug.print("{s} price (USD): {d}\n", .{ coin, usd });
        }
    } else {
        std.debug.print("{s} is not a valid coin on CoinGecko!\n", .{coin});
    }
}

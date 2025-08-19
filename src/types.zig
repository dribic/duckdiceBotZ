const std = @import("std");

pub const Response = struct {
    hash: ?[]const u8,
    username: ?[]const u8,
    createdAt: ?i64,
    level: ?i64,
    campaign: ?[]const u8,
    affiliate: ?[]const u8,
    lastDeposit: ?LastDeposit,
    wagered: ?[]const WageredItem,
    balances: ?[]const BalanceItem,
    wageringBonuses: ?[]const WageringBonus,
    tle: ?[]const TleItem,
};

pub const LastDeposit = struct {
    createdAt: ?i64,
    currency: ?[]const u8,
    amount: ?[]const u8,
};

pub const WageredItem = struct {
    currency: ?[]const u8,
    amount: ?[]const u8,
};

pub const BalanceItem = struct {
    currency: ?[]const u8,
    main: ?[]const u8,
    faucet: ?[]const u8 = null,
};

pub const WageringBonus = struct {
    name: ?[]const u8,
    type: ?[]const u8,
    hash: ?[]const u8,
    status: ?[]const u8,
    symbol: ?[]const u8,
    margin: ?[]const u8,
};

pub const TleItem = struct {
    hash: ?[]const u8,
    name: ?[]const u8,
    status: ?[]const u8,
};

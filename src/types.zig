const std = @import("std");

/// User-related structs from the initial types.zig file.
pub const UserInfoResponse = struct {
    hash: ?[]const u8 = null,
    username: ?[]const u8 = null,
    createdAt: ?i64 = null,
    level: ?i64 = null,
    campaign: ?[]const u8 = null,
    affiliate: ?[]const u8 = null,
    lastDeposit: ?LastDeposit = null,
    wagered: ?[]const WageredItem = null,
    balances: ?[]const BalanceItem = null,
    wageringBonuses: ?[]const WageringBonus = null,
    tle: ?[]const TleItem = null,
};

pub const LastDeposit = struct {
    createdAt: ?i64 = null,
    currency: ?[]const u8 = null,
    amount: ?[]const u8 = null,
};

pub const WageredItem = struct {
    currency: ?[]const u8 = null,
    amount: ?[]const u8 = null,
};

pub const BalanceItem = struct {
    currency: ?[]const u8 = null,
    main: ?[]const u8 = null,
    faucet: ?[]const u8 = null,
};

pub const WageringBonus = struct {
    name: ?[]const u8 = null,
    type: ?[]const u8 = null,
    hash: ?[]const u8 = null,
    status: ?[]const u8 = null,
    symbol: ?[]const u8 = null,
    margin: ?[]const u8 = null,
};

pub const TleItem = struct {
    hash: ?[]const u8 = null,
    name: ?[]const u8 = null,
    status: ?[]const u8 = null,
};

//---
/// Structs for the Original Dice / Bet Make endpoint's request.
pub const OriginalDicePlayRequest = struct {
    /// The currency symbol for the bet, e.g., "BTC".
    symbol: ?[]const u8 = null,
    /// The bet chance as a string, e.g., "88.88".
    chance: ?[]const u8 = null,
    /// Whether the bet is on High (true) or Low (false).
    isHigh: ?bool = null,
    /// The bet amount as a string, e.g., "0.01".
    amount: ?[]const u8 = null,
    /// User's wagering bonus hash (optional).
    userWageringBonusHash: ?[]const u8 = null,
    /// Faucet mode toggle (optional).
    faucet: ?bool = null,
    /// TLE unique hash (optional).
    tleHash: ?[]const u8 = null,
};

/// Struct for the response from both Original Dice and Range Dice bet endpoints.
pub const DicePlayResponse = struct {
    /// The bet details.
    bet: ?Bet = null,
    /// True if the bet is a jackpot.
    isJackpot: ?bool = null,
    /// The jackpot status, which can be null.
    jackpotStatus: ?bool = null,
    /// Jackpot details, which can be null.
    jackpot: ?Jackpot = null,
    /// The updated user details.
    user: ?User = null,
};

/// Struct for a Bet object in the API response.
pub const Bet = struct {
    /// Unique bet hash.
    hash: ?[]const u8 = null,
    /// Currency symbol.
    symbol: ?[]const u8 = null,
    /// Win/Loss result.
    result: ?bool = null,
    /// The bet choice, e.g., ">4999".
    choice: ?[]const u8 = null,
    /// The bet choice option, e.g., "0,2222".
    choiceOption: ?[]const u8 = null,
    /// The bet result number.
    number: ?i64 = null,
    /// Bet chance percentage.
    chance: ?f64 = null,
    /// Bet payout multiplier.
    payout: ?f64 = null,
    /// Bet amount as a string.
    betAmount: ?[]const u8 = null,
    /// Win amount as a string.
    winAmount: ?[]const u8 = null,
    /// Win profit as a string.
    profit: ?[]const u8 = null,
    /// Decoy mined amount as a string.
    mined: ?[]const u8 = null,
    /// Bet nonce.
    nonce: ?i64 = null,
    /// Timestamp when the bet was created.
    created: ?i64 = null,
    /// Game mode, e.g., "main" or "faucet".
    gameMode: ?[]const u8 = null,
    /// Details about the game.
    game: ?Game = null,
};

/// Struct for a Game object.
pub const Game = struct {
    /// Name of the game.
    name: ?[]const u8 = null,
    /// Slug of the game.
    slug: ?[]const u8 = null,
};

/// Struct for a Jackpot object.
pub const Jackpot = struct {
    /// Jackpot amount as a string.
    amount: ?[]const u8 = null,
};

/// Struct for a User object.
pub const User = struct {
    /// Unique user hash.
    hash: ?[]const u8 = null,
    /// User level.
    level: ?i64 = null,
    /// Username.
    username: ?[]const u8 = null,
    /// Total count of user's bets.
    bets: ?i64 = null,
    /// User's current seed's nonce.
    nonce: ?i64 = null,
    /// User's win count.
    wins: ?i64 = null,
    /// User's luck score.
    luck: ?f64 = null,
    /// User's balance in currency as a string.
    balance: ?[]const u8 = null,
    /// User's profit in currency as a string.
    profit: ?[]const u8 = null,
    /// User's wagering volume in currency as a string.
    volume: ?[]const u8 = null,
    /// Absolute level data.
    absoluteLevel: ?AbsoluteLevel = null,
};

/// Struct for Absolute Level data.
pub const AbsoluteLevel = struct {
    /// Absolute level number.
    level: ?i64 = null,
    /// Absolute level XP.
    xp: ?i64 = null,
    /// XP needed for the next level.
    xpNext: ?i64 = null,
    /// XP on the previous level.
    xpPrev: ?i64 = null,
};

//---
/// Structs for the Range Dice / Bet Make endpoint's request.
pub const RangeDicePlayRequest = struct {
    /// The currency symbol for the bet, e.g., "BTC".
    symbol: ?[]const u8 = null,
    /// An array of numbers defining the range.
    range: ?[]const i64 = null,
    /// Whether the bet is "In" (true) or "Out" (false).
    isIn: ?bool = null,
    /// The bet amount as a string, e.g., "0.01".
    amount: ?[]const u8 = null,
    /// User's wagering bonus hash (optional).
    userWageringBonusHash: ?[]const u8 = null,
    /// Faucet mode toggle (optional).
    faucet: ?bool = null,
    /// TLE unique hash (optional).
    tleHash: ?[]const u8 = null,
};

/// Structs for the Currency Stats endpoint's response.
pub const CurrencyStatsResponse = struct {
    /// Total number of bets for the currency.
    bets: ?i64 = null,
    /// Total number of wins for the currency.
    wins: ?i64 = null,
    /// Total profit in the currency, as a string.
    profit: ?[]const u8 = null,
    /// Total volume wagered in the currency, as a string.
    volume: ?[]const u8 = null,
    /// User balances for the currency.
    balances: ?Balances = null,
};

/// Struct for the balances object.
pub const Balances = struct {
    /// User's main balance in the currency, as a string.
    main: ?[]const u8 = null,
    /// User's faucet balance in the currency, as a string.
    faucet: ?[]const u8 = null,
    /// User's bonus balance in the currency, as a string.
    bonus: ?[]const u8 = null,
};

<p align="center">
  <img src="https://ziglang.org/logo/zig-logo.svg" alt="Zig Programming Language Logo" width="200" height="200"/>
</p>

# duckdiceBotZ

duckdiceBotZ is a gambling bot for the website https://duckdice.io written in Zig. It is currently limited to implementing the
Labouchere betting strategy and Fibonacci betting strategy.

duckdiceBotZ currently needs curl installed on your system to work properly.

## Zig version

duckdiceBotZ uses Zig version 0.15.1

## cURL prerequisites

Check if cURL is already installed:

`curl --version`

If its not, install it, like this:
 - Windows

 `winget install curl`

 - Debian/Ubuntu

 `sudo apt install curl`

 - Arch

 `sudo pacman -S curl`

 - Fedora/RHEL(8+)/RHEL(8+)-clones

 `sudo dnf install curl`

 - Opensuse

 `sudo zypper install curl`

## Plans

For planned features look at [ToDo](ToDo.md) list.

## Features

- Currently only has CLI.
- Implements the Fibonacci betting strategy for automated gambling on duckdice.io.
- Implements the Labouchere betting strategy for automated gambling on duckdice.io.
- Easy to configure and deploy.
- Written in Zig for blazingly-fast performance and reliability.

## Usage

1. Clone the repository:
`git clone https://github.com/dribic/duckdiceBotZ.git`
2. Build the bot:
`zig build -Doptimize=ReleaseSmall`
3. Run the bot.
`./zig-out/bin/duckdiceBotZ` on **Linux** or `.\zig-out\bin\duckdiceBotZ.exe` on **Windows**.

## License

This project is licensed under the GNU General Public License v3.0. See the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! If you have suggestions for improvements, open an issue or create a pull request.

Your pull requests have to be based on ***devel*** branch, otherwise they will be ignored!!!

## Disclaimer

This project is in beta and may contain bugs or errors. Use it at your own risk.

**Always exercise caution when gambling and never bet more than you can afford to lose.**

This project is a gambling bot and its use involves financial risk. The creators and contributors of duckdiceBotZ are not responsible for any losses incurred through its usage. Users are advised to gamble responsibly and within their means. This project is provided as-is, without any warranties or guarantees.

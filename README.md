# dothinkerlab Homebrew Tap

Homebrew Casks maintained by [dothinkerlab](https://github.com/dothinkerlab).

## AgentMeter

Install the Developer ID-signed and Apple-notarized universal macOS build:

```sh
brew install --cask dothinkerlab/tap/agentmeter
```

Upgrade it with:

```sh
brew upgrade --cask agentmeter
```

Remove the app while keeping its local preferences and logs:

```sh
brew uninstall --cask agentmeter
```

For a complete removal of AgentMeter preferences and logs:

```sh
brew uninstall --zap --cask agentmeter
```

The `--zap` operation deliberately does not delete provider credentials from
the macOS Keychain.

Release binaries come directly from the upstream
[AgentMeter GitHub Releases](https://github.com/dothinkerlab/AgentMeter/releases)
and are independently checked by this Tap's ARM64 and Intel CI.

cask "agentmeter" do
  version "2.1"
  sha256 "73b03ed752478e4193f3dbfe4803651ef7ee356eac0f0085c39ad4db549a9867"

  url "https://github.com/dothinkerlab/AgentMeter/releases/download/v#{version}/AgentMeter.dmg"
  name "AgentMeter"
  desc "Monitor AI coding quotas and API usage from the menu bar"
  homepage "https://github.com/dothinkerlab/AgentMeter"

  depends_on macos: :ventura

  app "AgentMeter.app"

  zap trash: [
    "~/Library/Logs/AgentMeter",
    "~/Library/Preferences/com.dothinker.app.agentmeter.mac.plist",
  ]
end

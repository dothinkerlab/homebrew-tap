cask "agentmeter" do
  version "2.3"
  sha256 "964ee5657ad6a8228cfd5d3094c23df04fd74a8a825afcb871e4062f1b88b8a7"

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

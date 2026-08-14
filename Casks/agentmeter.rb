cask "agentmeter" do
  version "1.7"
  sha256 "b5fdc11abc57e6321960324391c03ea929bb4806b5b7f4694928ac1ef0d5504c"

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

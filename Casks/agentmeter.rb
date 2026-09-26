cask "agentmeter" do
  version "2.0.1"
  sha256 "5189e2b33b556098c263b72c899161a96e7c9a75d38a48f697e3d492f6aab78e"

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

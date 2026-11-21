cask "agentmeter" do
  version "2.4.0"
  sha256 "9a618096baa761a64bf2f68475f45b25d65093e3d8bf9cb3945a9eeba54d2dc5"

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

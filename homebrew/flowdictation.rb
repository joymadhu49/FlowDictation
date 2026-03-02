cask "flowdictation" do
  version :latest
  sha256 :no_check

  url "https://github.com/joymadhu49/FlowDictation/releases/latest/download/FlowDictation.dmg"
  name "FlowDictation"
  desc "Lightweight macOS menu bar app for voice-to-text dictation powered by Groq Whisper API"
  homepage "https://github.com/joymadhu49/FlowDictation"

  app "FlowDictation.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/FlowDictation.app"]
  end

  zap trash: [
    "~/Library/Preferences/com.flowdictation.app.plist",
  ]
end

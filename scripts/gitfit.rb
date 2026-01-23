# Homebrew Cask formula for GitFit
#
# To submit to homebrew-cask:
# 1. Fork https://github.com/Homebrew/homebrew-cask
# 2. Add this file to Casks/g/gitfit.rb
# 3. Submit PR
#
# To test locally before submitting:
#   brew install --cask ./scripts/gitfit.rb

cask "gitfit" do
  version "1.3.0"
  sha256 "d5ccd1fa2f2c7506baa343accef09010de662815b41f769a940e6e5aa224fb64"

  # For local testing, use: url "file:///path/to/GitFit-1.0.0.dmg"
  url "https://github.com/rebelchris/git-fit/releases/download/v#{version}/GitFit-#{version}.dmg",
      verified: "github.com/rebelchris/git-fit/"
  name "GitFit"
  desc "Micro-workouts while waiting for AI code generation"
  homepage "https://git-fit.app/"

  # Require macOS (Tahou) for SwiftUI features
  depends_on macos: ">= :tahoe"

  app "GitFit.app"

  zap trash: "~/Library/Containers/com.chrisbongers.GitFit"
end

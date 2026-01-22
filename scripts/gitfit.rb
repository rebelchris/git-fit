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
  version "1.2.0"
  sha256 "3ae76e4c475bf81c495d13ba19591f405a7c07c767364ce68022a04835cf8d26"

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

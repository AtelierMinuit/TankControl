cask "tankcontrol" do
  version "1.1.0"
  sha256 "f34f371a27cf35f4830875e938244b2c2907970ab9b52e2a0bd190b9a99bbc44"

  url "https://github.com/AtelierMinuit/TankControl/releases/download/v#{version}/HP_Smart_Tank_500_macOS_Instalador.dmg"
  name "TankControl"
  desc "Native macOS driver, CUPS raster filter & control suite for HP Smart Tank 500 series"
  homepage "https://github.com/AtelierMinuit/TankControl"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :monterey"
  depends_on arch: :arm64

  pkg "Instalador HP Smart Tank 500.pkg"
  app "TankControl.app"

  uninstall pkgutil: [
              "com.hp.smarttank500.driver.applesilicon",
            ],
            delete:  [
              "/Applications/TankControl.app",
              "/usr/libexec/cups/filter/rastertopcl3gui",
            ]

  zap trash: [
    "~/Library/Application Support/TankControl",
    "~/Library/Preferences/cl.atelierminuit.TankControl.plist",
    "~/Library/Preferences/com.hp.smarttank500.driver.plist",
  ]
end



hl.define_submap("passthru", function()
    hl.bind("SUPER + SHIFT + CTRL + ALT + F35", hl.dsp.exec_cmd("true"))
end)

require("colors")
require("config.monitors")
require("config.env")
require("config.autostart")
require("config.variables")
require("config.settings")
require("config.rules")
require("config.keybindings")

local plugin_name = ({...})[1]:match("^kong%.plugins%.([^%.]+)")
local access = require("kong.plugins." .. plugin_name .. ".access")

local plugin = {
  PRIORITY = 949,
  VERSION = "0.0.5-1",
}

function plugin:access(plugin_conf)
  access.execute(plugin_conf)
end

return plugin

-- Prototypes are derived from Space Age's solar-system-edge / aquilo prototypes
-- so icons, starmap sprites and asteroid streams stay valid across game updates.

local edge = data.raw["space-location"]["solar-system-edge"]
assert(edge, "Wormhole Warfare requires Space Age: space-location 'solar-system-edge' not found")

local wormhole = util.table.deepcopy(edge)
wormhole.name = "ww-wormhole"
wormhole.order = "e[ww-wormhole]"
wormhole.distance = edge.distance + 6
wormhole.orientation = (edge.orientation + 0.04) % 1
wormhole.magnitude = 1.5

local conn_base = data.raw["space-connection"]["aquilo-solar-system-edge"]
assert(conn_base, "Wormhole Warfare requires Space Age: space-connection 'aquilo-solar-system-edge' not found")

local connection = util.table.deepcopy(conn_base)
connection.name = "aquilo-ww-wormhole"
connection.from = "aquilo"
connection.to = "ww-wormhole"
connection.length = 30000

local discovery = data.raw.technology["planet-discovery-aquilo"]

local tech = {
  type = "technology",
  name = "ww-wormhole-stabilization",
  icon = discovery and discovery.icon,
  icon_size = discovery and discovery.icon_size,
  icons = discovery and util.table.deepcopy(discovery.icons),
  effects = {
    {
      type = "unlock-space-location",
      space_location = "ww-wormhole",
      use_icon_overlay_constant = false,
    },
  },
  prerequisites = {"cryogenic-science-pack"},
  unit = {
    count = 2000,
    time = 60,
    ingredients = {
      {"automation-science-pack", 1},
      {"logistic-science-pack", 1},
      {"chemical-science-pack", 1},
      {"production-science-pack", 1},
      {"utility-science-pack", 1},
      {"space-science-pack", 1},
      {"cryogenic-science-pack", 1},
    },
  },
}

local shortcuts = {
  {
    type = "shortcut",
    name = "ww-invade",
    action = "lua",
    order = "z[ww]-a",
    icon = "__base__/graphics/icons/artillery-targeting-remote.png",
    icon_size = 64,
    small_icon = "__base__/graphics/icons/artillery-targeting-remote.png",
    small_icon_size = 64,
  },
  {
    type = "shortcut",
    name = "ww-diplomacy",
    action = "lua",
    order = "z[ww]-b",
    icon = "__base__/graphics/icons/radar.png",
    icon_size = 64,
    small_icon = "__base__/graphics/icons/radar.png",
    small_icon_size = 64,
  },
}

data:extend({wormhole, connection, tech, shortcuts[1], shortcuts[2]})

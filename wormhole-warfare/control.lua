local state = require("scripts/state")
local worlds = require("scripts/worlds")
local invasion = require("scripts/invasion")
local diplomacy = require("scripts/diplomacy")
local gui = require("scripts/gui")

script.on_init(function()
  state.init()
end)

script.on_configuration_changed(function()
  state.init()
end)

script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  player.print({"ww-msg.welcome"})
  if settings.global["ww-auto-claim"].value then
    worlds.claim(player)
  end
end)

script.on_event(defines.events.on_lua_shortcut, function(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  if event.prototype_name == "ww-invade" then
    gui.open_invade(player)
  elseif event.prototype_name == "ww-diplomacy" then
    gui.open_diplomacy(player)
  end
end)

script.on_event(defines.events.on_gui_click, gui.on_click)

-- Announce arrival at the wormhole to everyone riding the platform.
script.on_event(defines.events.on_space_platform_changed_state, function(event)
  local platform = event.platform
  if not (platform and platform.valid) then return end
  local loc = platform.space_location
  local at_wormhole = loc ~= nil and loc.name == "ww-wormhole"
  local was_there = storage.platform_at_wormhole[platform.index]
  storage.platform_at_wormhole[platform.index] = at_wormhole or nil
  if at_wormhole and not was_there then
    for _, player in pairs(game.connected_players) do
      if player.surface == platform.surface then
        player.print({"ww-msg.arrived-at-wormhole"})
        player.play_sound{path = "utility/alert_destroyed"}
      end
    end
  end
end)

script.on_event(defines.events.on_entity_died, invasion.on_entity_died)
script.on_event(defines.events.on_player_died, invasion.on_player_died)
script.on_event(defines.events.on_pre_player_left_game, invasion.on_pre_player_left_game)
script.on_event(defines.events.on_player_removed, worlds.on_player_removed)

script.on_nth_tick(60, function()
  invasion.on_tick_check()
  diplomacy.on_tick_check()
end)

commands.add_command("ww-claim", {"ww-cmd.claim"}, function(cmd)
  local player = cmd.player_index and game.get_player(cmd.player_index)
  if player then worlds.claim(player) end
end)

commands.add_command("ww-retreat", {"ww-cmd.retreat"}, function(cmd)
  local player = cmd.player_index and game.get_player(cmd.player_index)
  if player then invasion.retreat(player) end
end)

local state = require("scripts/state")

local worlds = {}

-- New forces start with nothing researched; hand them the shared force's
-- progress so late joiners aren't stuck in the stone age.
local function copy_research(src, dst)
  for name, tech in pairs(src.technologies) do
    local target = dst.technologies[name]
    if target and tech.researched then
      target.researched = true
    end
  end
end

function worlds.get(player_index)
  return storage.worlds[player_index]
end

function worlds.claim(player)
  if storage.worlds[player.index] then
    player.print({"ww-msg.already-claimed"})
    return
  end
  -- Factorio hard-caps the game at 64 forces; leave headroom for vanilla ones.
  if table_size(game.forces) >= 60 then
    player.print({"ww-msg.force-cap"})
    return
  end

  local force_name = "ww-" .. player.name
  local force = game.forces[force_name] or game.create_force(force_name)
  copy_research(player.force, force)

  local surface_name = "ww-world-" .. player.name
  local surface = game.surfaces[surface_name]
  if not surface then
    local mgs = game.surfaces["nauvis"].map_gen_settings
    mgs.seed = math.random(0, 4294967295)
    surface = game.create_surface(surface_name, mgs)
  end
  surface.request_to_generate_chunks({0, 0}, 3)
  surface.force_generate_chunk_requests()

  local spawn = surface.find_non_colliding_position("character", {0, 0}, 200, 1) or {x = 0, y = 0}
  force.set_spawn_position(spawn, surface)

  storage.worlds[player.index] = {
    player_name = player.name,
    force_name = force_name,
    surface_name = surface_name,
  }
  storage.force_owners[force_name] = player.index

  player.force = force
  player.teleport(spawn, surface)
  game.print({"ww-msg.world-claimed", player.name})
end

-- Return a player to their own world's spawn (or Nauvis as a fallback).
function worlds.send_home(player)
  local w = storage.worlds[player.index]
  local surface = w and game.surfaces[w.surface_name]
  if surface then
    local spawn = player.force.get_spawn_position(surface)
    local pos = surface.find_non_colliding_position("character", spawn, 100, 1) or spawn
    player.teleport(pos, surface)
  else
    local nauvis = game.surfaces["nauvis"]
    local pos = nauvis.find_non_colliding_position("character", {0, 0}, 100, 1) or {x = 0, y = 0}
    player.teleport(pos, nauvis)
  end
end

-- Free the force slot and the surface when a player is permanently removed.
function worlds.on_player_removed(event)
  local w = storage.worlds[event.player_index]
  if not w then return end
  storage.worlds[event.player_index] = nil
  storage.force_owners[w.force_name] = nil
  for key, cf in pairs(storage.ceasefires) do
    if cf.forces[1] == w.force_name or cf.forces[2] == w.force_name then
      storage.ceasefires[key] = nil
    end
  end
  if game.surfaces[w.surface_name] then
    game.delete_surface(w.surface_name)
  end
  if game.forces[w.force_name] then
    game.merge_forces(w.force_name, "neutral")
  end
end

return worlds

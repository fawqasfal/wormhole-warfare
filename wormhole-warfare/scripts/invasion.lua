local state = require("scripts/state")
local worlds = require("scripts/worlds")

local invasion = {}

-- War-score value of destroying a defender entity, by prototype type.
local TYPE_SCORE = {
  ["rocket-silo"] = 100,
  ["artillery-turret"] = 30,
  ["reactor"] = 25,
  ["lab"] = 10,
  ["beacon"] = 10,
  ["roboport"] = 8,
  ["assembling-machine"] = 8,
  ["electric-turret"] = 6,
  ["furnace"] = 5,
  ["mining-drill"] = 5,
  ["radar"] = 5,
  ["ammo-turret"] = 4,
  ["generator"] = 3,
  ["boiler"] = 2,
  ["solar-panel"] = 2,
}
local DEFAULT_SCORE = 1
local KILL_SCORE = 50

function invasion.at_wormhole(player)
  local platform = player.surface.platform
  local loc = platform and platform.space_location
  return loc ~= nil and loc.name == "ww-wormhole"
end

function invasion.involving(force_name)
  for id, inv in pairs(storage.invasions) do
    if inv.invader_force == force_name or inv.defender_force == force_name then
      return id, inv
    end
  end
end

-- Returns true, or false plus a locale key explaining why not.
function invasion.can_invade(invader, defender)
  if invader.index == defender.index then
    return false, "ww-msg.cannot-self"
  end
  local iw = storage.worlds[invader.index]
  if not iw then
    return false, "ww-msg.claim-first"
  end
  local dw = storage.worlds[defender.index]
  if not dw then
    return false, "ww-msg.no-world"
  end
  if settings.global["ww-require-online"].value and not defender.connected then
    return false, "ww-msg.target-offline"
  end
  if state.ceasefire_active(iw.force_name, dw.force_name) then
    return false, "ww-msg.ceasefire-active"
  end
  if invasion.involving(dw.force_name) then
    return false, "ww-msg.already-at-war"
  end
  if invasion.involving(iw.force_name) then
    return false, "ww-msg.you-at-war"
  end
  return true
end

function invasion.start(invader, defender)
  local ok, err = invasion.can_invade(invader, defender)
  if not ok then
    invader.print({err})
    return
  end

  local iw = storage.worlds[invader.index]
  local dw = storage.worlds[defender.index]
  local surface = game.surfaces[dw.surface_name]
  local iforce = game.forces[iw.force_name]
  local dforce = game.forces[dw.force_name]
  if not (surface and iforce and dforce) then return end

  -- Beachhead: a random bearing at a fixed range from the defender's spawn,
  -- so the defender gets warning but not a scripted approach vector.
  local spawn = dforce.get_spawn_position(surface)
  local angle = math.random() * 2 * math.pi
  local dist = settings.global["ww-beachhead-distance"].value
  local target = {x = spawn.x + math.cos(angle) * dist, y = spawn.y + math.sin(angle) * dist}
  surface.request_to_generate_chunks(target, 3)
  surface.force_generate_chunk_requests()
  local beachhead = surface.find_non_colliding_position("character", target, 100, 1) or target

  iforce.set_cease_fire(dforce, false)
  dforce.set_cease_fire(iforce, false)
  iforce.chart(surface, {
    {beachhead.x - 96, beachhead.y - 96},
    {beachhead.x + 96, beachhead.y + 96},
  })

  invader.teleport(beachhead, surface)

  local id = state.new_id()
  storage.invasions[id] = {
    id = id,
    invader_index = invader.index,
    defender_index = defender.index,
    invader_force = iw.force_name,
    defender_force = dw.force_name,
    surface_name = dw.surface_name,
    start_tick = game.tick,
    end_tick = game.tick + settings.global["ww-invasion-duration"].value * 3600,
    score = 0,
    kills = 0,
  }

  game.print({"ww-msg.invasion-started", invader.name, defender.name})
  if defender.connected then
    defender.play_sound{path = "utility/alert_destroyed"}
  end
end

-- reason: "timeout" | "died" | "left" | "defender-left" | "retreat" | "treaty"
function invasion.finish(id, reason)
  local inv = storage.invasions[id]
  if not inv then return end
  storage.invasions[id] = nil

  local invader = game.get_player(inv.invader_index)
  local defender = game.get_player(inv.defender_index)
  local iforce = game.forces[inv.invader_force]
  local dforce = game.forces[inv.defender_force]

  -- The wormhole spits the raider back home (unless they died there;
  -- respawn already handles that via the force spawn position).
  if invader and invader.valid and invader.connected and reason ~= "died"
      and invader.surface.name == inv.surface_name then
    worlds.send_home(invader)
  end

  -- Built-in grace period after every raid; treaties bring their own terms.
  if reason ~= "treaty" and iforce and dforce then
    local truce = settings.global["ww-post-invasion-truce"].value
    if truce > 0 then
      storage.ceasefires[state.pair_key(inv.invader_force, inv.defender_force)] = {
        expiry = game.tick + truce * 3600,
        forces = {inv.invader_force, inv.defender_force},
      }
      iforce.set_cease_fire(dforce, true)
      dforce.set_cease_fire(iforce, true)
    end
  end

  game.print({"ww-msg.invasion-ended",
    invader and invader.name or inv.invader_force,
    defender and defender.name or inv.defender_force,
    {"ww-reason." .. reason},
    inv.score,
    inv.kills})
end

function invasion.retreat(player)
  for id, inv in pairs(storage.invasions) do
    if inv.invader_index == player.index then
      invasion.finish(id, "retreat")
      return
    end
  end
  player.print({"ww-msg.not-invading"})
end

function invasion.on_entity_died(event)
  if not next(storage.invasions) then return end
  local entity = event.entity
  if not (entity and entity.valid) then return end
  local attacker = event.force
  if not attacker then return end
  for _, inv in pairs(storage.invasions) do
    if entity.surface.name == inv.surface_name
        and entity.force.name == inv.defender_force
        and attacker.name == inv.invader_force then
      inv.score = inv.score + (TYPE_SCORE[entity.type] or DEFAULT_SCORE)
    end
  end
end

function invasion.on_player_died(event)
  for id, inv in pairs(storage.invasions) do
    if inv.invader_index == event.player_index then
      invasion.finish(id, "died")
    elseif inv.defender_index == event.player_index then
      inv.kills = inv.kills + 1
      inv.score = inv.score + KILL_SCORE
    end
  end
end

function invasion.on_pre_player_left_game(event)
  for id, inv in pairs(storage.invasions) do
    if inv.invader_index == event.player_index then
      invasion.finish(id, "left")
    elseif inv.defender_index == event.player_index then
      invasion.finish(id, "defender-left")
    end
  end
end

function invasion.on_tick_check()
  local tick = game.tick
  for id, inv in pairs(storage.invasions) do
    if tick >= inv.end_tick then
      invasion.finish(id, "timeout")
    end
  end
end

return invasion

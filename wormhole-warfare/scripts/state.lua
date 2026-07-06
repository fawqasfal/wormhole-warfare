local state = {}

-- storage layout:
--   storage.worlds        [player_index] = {player_name, force_name, surface_name}
--   storage.force_owners  [force_name]   = player_index
--   storage.invasions     [id] = {id, invader_index, defender_index, invader_force,
--                                 defender_force, surface_name, start_tick, end_tick,
--                                 score, kills}
--   storage.contracts     [id] = {id, from_index, to_index, payer ("from"|"to"),
--                                 item, count, minutes, created_tick}
--   storage.ceasefires    [pair_key] = {expiry, forces = {name_a, name_b}}
--   storage.gui_targets   [player_index] = array of player indices shown in the
--                                          diplomacy target dropdown, in display order
--   storage.platform_at_wormhole [platform_index] = true while parked at the wormhole

function state.init()
  storage.worlds = storage.worlds or {}
  storage.force_owners = storage.force_owners or {}
  storage.invasions = storage.invasions or {}
  storage.contracts = storage.contracts or {}
  storage.ceasefires = storage.ceasefires or {}
  storage.gui_targets = storage.gui_targets or {}
  storage.platform_at_wormhole = storage.platform_at_wormhole or {}
  storage.next_id = storage.next_id or 1
end

function state.new_id()
  local id = storage.next_id
  storage.next_id = id + 1
  return id
end

-- Canonical key for an unordered pair of force names.
function state.pair_key(a, b)
  if a < b then
    return a .. "|" .. b
  end
  return b .. "|" .. a
end

function state.ceasefire_active(force_a, force_b)
  local cf = storage.ceasefires[state.pair_key(force_a, force_b)]
  return cf ~= nil and cf.expiry > game.tick
end

-- Human-readable name for a mod-created force ("ww-Bob" -> "Bob").
function state.owner_name(force_name)
  local index = storage.force_owners[force_name]
  local player = index and game.get_player(index)
  return player and player.name or force_name
end

return state

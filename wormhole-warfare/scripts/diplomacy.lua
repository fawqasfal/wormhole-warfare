local state = require("scripts/state")
local invasion = require("scripts/invasion")

local diplomacy = {}

local MAX_CEASEFIRE_MINUTES = 24 * 60

-- payer is "from" (the proposer pays tribute) or "to" (the recipient pays).
-- A contract with no item is a white peace: ceasefire, no tribute.
function diplomacy.propose(proposer, target_index, payer, item, count, minutes)
  local target = game.get_player(target_index)
  if not target then return end
  if not (storage.worlds[proposer.index] and storage.worlds[target_index]) then
    proposer.print({"ww-msg.both-need-worlds"})
    return
  end
  if item and (not count or count <= 0) then
    proposer.print({"ww-msg.tribute-needs-count"})
    return
  end

  local id = state.new_id()
  storage.contracts[id] = {
    id = id,
    from_index = proposer.index,
    to_index = target_index,
    payer = payer,
    item = item,
    count = item and count or 0,
    minutes = math.max(1, math.min(minutes or 30, MAX_CEASEFIRE_MINUTES)),
    created_tick = game.tick,
  }

  proposer.print({"ww-msg.contract-sent", target.name})
  if target.connected then
    target.print({"ww-msg.contract-received", proposer.name})
  end
end

function diplomacy.accept(contract_id, accepter)
  local c = storage.contracts[contract_id]
  if not c or c.to_index ~= accepter.index then return end
  local proposer = game.get_player(c.from_index)
  if not (proposer and proposer.connected) then
    accepter.print({"ww-msg.proposer-offline"})
    return
  end

  -- Tribute must physically move: out of the payer's inventories, into the
  -- payee's (spilling any overflow at the payee's feet).
  if c.item and c.count > 0 then
    local payer = (c.payer == "from") and proposer or accepter
    local payee = (c.payer == "from") and accepter or proposer
    if payer.get_item_count(c.item) < c.count then
      accepter.print({"ww-msg.insufficient-tribute", payer.name, c.count, c.item})
      return
    end
    local removed = payer.remove_item({name = c.item, count = c.count})
    local inserted = payee.insert({name = c.item, count = removed})
    if inserted < removed then
      payee.surface.spill_item_stack{
        position = payee.position,
        stack = {name = c.item, count = removed - inserted},
      }
    end
  end

  local fw = storage.worlds[c.from_index]
  local tw = storage.worlds[c.to_index]
  if fw and tw then
    local fa = game.forces[fw.force_name]
    local fb = game.forces[tw.force_name]
    if fa and fb then
      fa.set_cease_fire(fb, true)
      fb.set_cease_fire(fa, true)
      storage.ceasefires[state.pair_key(fw.force_name, tw.force_name)] = {
        expiry = game.tick + c.minutes * 3600,
        forces = {fw.force_name, tw.force_name},
      }
    end
    -- Signing peace ends any raid in progress between the two parties.
    for id, inv in pairs(storage.invasions) do
      local pair = {[inv.invader_force] = true, [inv.defender_force] = true}
      if pair[fw.force_name] and pair[tw.force_name] then
        invasion.finish(id, "treaty")
      end
    end
  end

  storage.contracts[contract_id] = nil
  game.print({"ww-msg.contract-accepted", proposer.name, accepter.name, c.minutes})
end

function diplomacy.reject(contract_id, rejecter)
  local c = storage.contracts[contract_id]
  if not c or c.to_index ~= rejecter.index then return end
  storage.contracts[contract_id] = nil
  local proposer = game.get_player(c.from_index)
  if proposer and proposer.connected then
    proposer.print({"ww-msg.contract-rejected", rejecter.name})
  end
end

function diplomacy.cancel(contract_id, canceller)
  local c = storage.contracts[contract_id]
  if not c or c.from_index ~= canceller.index then return end
  storage.contracts[contract_id] = nil
  local target = game.get_player(c.to_index)
  if target and target.connected then
    target.print({"ww-msg.contract-cancelled", canceller.name})
  end
end

function diplomacy.on_tick_check()
  local tick = game.tick
  for key, cf in pairs(storage.ceasefires) do
    if tick >= cf.expiry then
      storage.ceasefires[key] = nil
      local a = game.forces[cf.forces[1]]
      local b = game.forces[cf.forces[2]]
      if a and b then
        a.set_cease_fire(b, false)
        b.set_cease_fire(a, false)
      end
      game.print({"ww-msg.ceasefire-expired",
        state.owner_name(cf.forces[1]), state.owner_name(cf.forces[2])})
    end
  end
end

return diplomacy

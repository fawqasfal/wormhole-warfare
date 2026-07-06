local state = require("scripts/state")
local invasion = require("scripts/invasion")
local diplomacy = require("scripts/diplomacy")

local gui = {}

local INVADE_FRAME = "ww_invade_frame"
local DIPLOMACY_FRAME = "ww_diplomacy_frame"

local function find_child(root, name)
  if root.name == name then return root end
  for _, child in pairs(root.children) do
    local hit = find_child(child, name)
    if hit then return hit end
  end
end

local function titlebar(frame, caption, close_action)
  local bar = frame.add{type = "flow", direction = "horizontal"}
  bar.drag_target = frame
  bar.add{type = "label", caption = caption, style = "frame_title", ignored_by_interaction = true}
  local filler = bar.add{type = "empty-widget", style = "draggable_space_header", ignored_by_interaction = true}
  filler.style.horizontally_stretchable = true
  filler.style.height = 24
  bar.add{
    type = "sprite-button",
    style = "frame_action_button",
    sprite = "utility/close",
    tags = {ww_action = close_action},
  }
end

local function stretch(row)
  local pad = row.add{type = "empty-widget"}
  pad.style.horizontally_stretchable = true
end

local function contract_line(c)
  local from = game.get_player(c.from_index)
  local to = game.get_player(c.to_index)
  local from_name = from and from.name or "?"
  local to_name = to and to.name or "?"
  local tribute
  if c.item and c.count > 0 then
    local payer_name = (c.payer == "from") and from_name or to_name
    tribute = string.format("%d × [item=%s] paid by %s", c.count, c.item, payer_name)
  else
    tribute = "white peace"
  end
  return string.format("%s → %s: %d min ceasefire, %s", from_name, to_name, c.minutes, tribute)
end

-- ---------------------------------------------------------------- invade GUI

function gui.close_invade(player)
  local frame = player.gui.screen[INVADE_FRAME]
  if frame then frame.destroy() end
end

function gui.open_invade(player)
  gui.close_invade(player)
  if not invasion.at_wormhole(player) then
    player.print({"ww-msg.not-at-wormhole"})
    return
  end
  local frame = player.gui.screen.add{type = "frame", name = INVADE_FRAME, direction = "vertical"}
  frame.auto_center = true
  titlebar(frame, {"ww-gui.invade-title"}, "close-invade")
  local inner = frame.add{type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical"}
  inner.style.minimal_width = 340

  local any = false
  for _, target in pairs(game.players) do
    if target.index ~= player.index and storage.worlds[target.index] then
      any = true
      local row = inner.add{type = "flow", direction = "horizontal"}
      row.style.vertical_align = "center"
      row.add{type = "label", caption = target.name .. (target.connected and "" or " (offline)")}
      stretch(row)
      local ok, err = invasion.can_invade(player, target)
      local button = row.add{
        type = "button",
        style = "red_button",
        caption = {"ww-gui.invade-button"},
        tags = {ww_action = "invade", target = target.index},
      }
      if not ok then
        button.enabled = false
        button.tooltip = {err}
      end
    end
  end
  if not any then
    inner.add{type = "label", caption = {"ww-gui.no-targets"}}
  end
end

-- ------------------------------------------------------------- diplomacy GUI

function gui.close_diplomacy(player)
  local frame = player.gui.screen[DIPLOMACY_FRAME]
  if frame then frame.destroy() end
end

function gui.open_diplomacy(player)
  gui.close_diplomacy(player)
  local frame = player.gui.screen.add{type = "frame", name = DIPLOMACY_FRAME, direction = "vertical"}
  frame.auto_center = true
  titlebar(frame, {"ww-gui.diplomacy-title"}, "close-diplomacy")
  local inner = frame.add{type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical"}
  inner.style.minimal_width = 440

  -- proposal form
  inner.add{type = "label", caption = {"ww-gui.propose-header"}, style = "heading_2_label"}
  local form = inner.add{type = "table", column_count = 2}

  form.add{type = "label", caption = {"ww-gui.target"}}
  local targets, names = {}, {}
  for _, p in pairs(game.players) do
    if p.index ~= player.index and storage.worlds[p.index] then
      targets[#targets + 1] = p.index
      names[#names + 1] = p.name
    end
  end
  storage.gui_targets[player.index] = targets
  local dropdown = form.add{type = "drop-down", name = "ww_target", items = names}
  if #names > 0 then dropdown.selected_index = 1 end

  form.add{type = "label", caption = {"ww-gui.payer"}}
  form.add{
    type = "switch",
    name = "ww_payer",
    left_label_caption = {"ww-gui.they-pay"},
    right_label_caption = {"ww-gui.i-pay"},
    switch_state = "left",
  }

  form.add{type = "label", caption = {"ww-gui.tribute"}}
  local tribute_flow = form.add{type = "flow", direction = "horizontal"}
  tribute_flow.style.vertical_align = "center"
  tribute_flow.add{type = "choose-elem-button", name = "ww_item", elem_type = "item"}
  local count_field = tribute_flow.add{type = "textfield", name = "ww_count", numeric = true, text = "100"}
  count_field.style.width = 70

  form.add{type = "label", caption = {"ww-gui.duration"}}
  local minutes_field = form.add{type = "textfield", name = "ww_minutes", numeric = true, text = "30"}
  minutes_field.style.width = 70

  inner.add{
    type = "button",
    caption = {"ww-gui.send"},
    style = "confirm_button",
    tags = {ww_action = "send-contract"},
  }

  -- incoming proposals
  inner.add{type = "line"}
  inner.add{type = "label", caption = {"ww-gui.incoming-header"}, style = "heading_2_label"}
  local any_incoming = false
  for id, c in pairs(storage.contracts) do
    if c.to_index == player.index then
      any_incoming = true
      local row = inner.add{type = "flow", direction = "horizontal"}
      row.style.vertical_align = "center"
      row.add{type = "label", caption = contract_line(c)}
      stretch(row)
      row.add{
        type = "button", caption = {"ww-gui.accept"}, style = "confirm_button",
        tags = {ww_action = "accept-contract", contract = id},
      }
      row.add{
        type = "button", caption = {"ww-gui.reject"}, style = "red_button",
        tags = {ww_action = "reject-contract", contract = id},
      }
    end
  end
  if not any_incoming then
    inner.add{type = "label", caption = {"ww-gui.none"}}
  end

  -- outgoing proposals
  inner.add{type = "line"}
  inner.add{type = "label", caption = {"ww-gui.outgoing-header"}, style = "heading_2_label"}
  local any_outgoing = false
  for id, c in pairs(storage.contracts) do
    if c.from_index == player.index then
      any_outgoing = true
      local row = inner.add{type = "flow", direction = "horizontal"}
      row.style.vertical_align = "center"
      row.add{type = "label", caption = contract_line(c)}
      stretch(row)
      row.add{
        type = "button", caption = {"ww-gui.cancel"},
        tags = {ww_action = "cancel-contract", contract = id},
      }
    end
  end
  if not any_outgoing then
    inner.add{type = "label", caption = {"ww-gui.none"}}
  end

  -- active ceasefires
  inner.add{type = "line"}
  inner.add{type = "label", caption = {"ww-gui.ceasefires-header"}, style = "heading_2_label"}
  local my_world = storage.worlds[player.index]
  local any_ceasefire = false
  if my_world then
    for _, cf in pairs(storage.ceasefires) do
      if cf.forces[1] == my_world.force_name or cf.forces[2] == my_world.force_name then
        any_ceasefire = true
        local other = (cf.forces[1] == my_world.force_name) and cf.forces[2] or cf.forces[1]
        local remaining = math.max(0, math.ceil((cf.expiry - game.tick) / 3600))
        inner.add{
          type = "label",
          caption = string.format("%s — %d min remaining", state.owner_name(other), remaining),
        }
      end
    end
  end
  if not any_ceasefire then
    inner.add{type = "label", caption = {"ww-gui.none"}}
  end
end

local function send_contract(player)
  local frame = player.gui.screen[DIPLOMACY_FRAME]
  if not frame then return end
  local targets = storage.gui_targets[player.index] or {}
  local dropdown = find_child(frame, "ww_target")
  local target_index = dropdown and targets[dropdown.selected_index]
  if not target_index then
    player.print({"ww-msg.no-target-selected"})
    return
  end
  local payer_switch = find_child(frame, "ww_payer")
  local payer = (payer_switch and payer_switch.switch_state == "right") and "from" or "to"
  local item_button = find_child(frame, "ww_item")
  local item = item_button and item_button.elem_value
  local count_field = find_child(frame, "ww_count")
  local count = count_field and tonumber(count_field.text) or 0
  local minutes_field = find_child(frame, "ww_minutes")
  local minutes = minutes_field and tonumber(minutes_field.text) or 30

  diplomacy.propose(player, target_index, payer, item, count, minutes)
  gui.open_diplomacy(player)
end

-- ------------------------------------------------------------------ dispatch

function gui.on_click(event)
  local element = event.element
  if not (element and element.valid) then return end
  local action = element.tags and element.tags.ww_action
  if not action then return end
  local player = game.get_player(event.player_index)
  if not player then return end

  if action == "close-invade" then
    gui.close_invade(player)
  elseif action == "close-diplomacy" then
    gui.close_diplomacy(player)
  elseif action == "invade" then
    local target = game.get_player(element.tags.target)
    gui.close_invade(player)
    if target then invasion.start(player, target) end
  elseif action == "send-contract" then
    send_contract(player)
  elseif action == "accept-contract" then
    diplomacy.accept(element.tags.contract, player)
    gui.open_diplomacy(player)
  elseif action == "reject-contract" then
    diplomacy.reject(element.tags.contract, player)
    gui.open_diplomacy(player)
  elseif action == "cancel-contract" then
    diplomacy.cancel(element.tags.contract, player)
    gui.open_diplomacy(player)
  end
end

return gui

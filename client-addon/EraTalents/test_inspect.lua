-- test_inspect.lua — headless: the ISYNC protocol (Comms.lua) and the pure view helpers (TalentUI.lua).
-- Run: lua5.1 client-addon/EraTalents/test_inspect.lua   (cwd = repo root)
dofile("client-addon/EraTalents/Comms.lua")
local ET = EraTalents

local G1, G2 = "0x0000000000000A01", "0x0000000000000B02"

-- single chunk
local cache = {}
assert(ET.ParseInspectSync(cache, "ISYNC " .. G1 .. " 0 1 8 18001:3,18002:1") == G1, "returns the guid")
local e = cache[G1]
assert(e.era == 0 and e.managed == true and e.classId == 8, "header parsed")
assert(e.ranks[18001] == 3 and e.ranks[18002] == 1, "ranks parsed")

-- not an ISYNC
assert(ET.ParseInspectSync(cache, "SYNC 0 1 47 18001:3") == nil, "SYNC is not ISYNC")
assert(ET.ParseInspectSync(cache, "GEN a1b2c3d4") == nil, "GEN is not ISYNC")

-- denial: managed=0, no list; another guid's entry untouched
assert(ET.ParseInspectSync(cache, "ISYNC " .. G2 .. " 0 0 0") == G2, "denial parsed")
assert(cache[G2].managed == false and next(cache[G2].ranks) == nil, "denial has no ranks")
assert(cache[G1].ranks[18001] == 3, "entries are per guid")

-- multi-chunk accumulate; seq 1 resets; sentinel-less resets
cache = {}
ET.ParseInspectSync(cache, "ISYNC " .. G1 .. " 1 1 2 1/2 946001:5")
ET.ParseInspectSync(cache, "ISYNC " .. G1 .. " 1 1 2 2/2 946002:2")
assert(cache[G1].ranks[946001] == 5 and cache[G1].ranks[946002] == 2, "chunk 2 accumulates")
ET.ParseInspectSync(cache, "ISYNC " .. G1 .. " 1 1 2 1/1 946003:1")
assert(cache[G1].ranks[946001] == nil and cache[G1].ranks[946003] == 1, "seq 1 resets")
ET.ParseInspectSync(cache, "ISYNC " .. G1 .. " 1 1 2 946004:1")
assert(cache[G1].ranks[946003] == nil and cache[G1].ranks[946004] == 1, "sentinel-less resets")
assert(cache[G1].era == 1 and cache[G1].classId == 2, "TBC paladin header")
print("ParseInspectSync OK")

-- OnAddonMsg: ISYNC goes to ET.inspect.cache + RefreshInspect, never to ParseSync/Refresh
ET.PREFIX = "ERATAL"
ET.state = { ranks = {} }
ET.inspect = { current = G1, cache = {} }
local refreshed, inspected = false, false
ET.Refresh = function() refreshed = true end
ET.RefreshInspect = function() inspected = true end
ET.OnAddonMsg("ERATAL", "ISYNC " .. G1 .. " 0 1 8 18001:3")
assert(inspected and not refreshed, "ISYNC routed to RefreshInspect only")
assert(ET.inspect.cache[G1].ranks[18001] == 3, "stored in ET.inspect.cache")
assert(ET.state.era == nil, "own state untouched by ISYNC")
-- a reply for a guid the frame is not showing (closed / moved on) is dropped, not cached
inspected = false
ET.OnAddonMsg("ERATAL", "ISYNC " .. G2 .. " 0 1 8 18001:3")
assert(ET.inspect.cache[G2] == nil and not inspected, "non-current ISYNC dropped")
ET.Refresh, ET.RefreshInspect = nil, nil
print("ISYNC routing OK")

-- an orphan continuation chunk (no chunk 1 seen) creates nothing; partial flag tracks arrival
cache = {}
ET.ParseInspectSync(cache, "ISYNC " .. G1 .. " 1 1 2 2/2 946002:2")
assert(cache[G1] == nil, "orphan chunk ignored")
ET.ParseInspectSync(cache, "ISYNC " .. G1 .. " 1 1 2 1/2 946001:5")
assert(cache[G1].partial == true, "chunk 1 of 2 is partial")
ET.ParseInspectSync(cache, "ISYNC " .. G1 .. " 1 1 2 2/2 946002:2")
assert(cache[G1].partial == false and cache[G1].ranks[946001] == 5, "complete after chunk 2")
print("chunk edge cases OK")

-- RequestInspect payload
local sent
_G.SendAddonMessage = function(prefix, msg) sent = prefix .. "|" .. msg end
_G.UnitName = function() return "Me" end
ET.RequestInspect(G1)
assert(sent == "ERATAL|INSPECT " .. G1, "INSPECT payload")
print("RequestInspect OK")

-- Pure view helpers (TalentUI.lua must load headless: no WoW API at file scope).
dofile("client-addon/EraTalents/TalentUI.lua")
local tree = { talents = { { id = 1, tab = 1 }, { id = 2, tab = 1 }, { id = 3, tab = 2 }, { id = 4, tab = 3 } } }
local pts = ET.SpecPoints(tree, { [1] = 5, [2] = 3, [3] = 2, [4] = 0 })
assert(pts[1] == 8 and pts[2] == 2 and pts[3] == 0, "per-tab sums")
assert(ET.SpecPoints(tree, nil)[1] == 0, "nil ranks = nothing spent")
assert(ET.PrimaryTab(tree, { [3] = 5, [4] = 5 }, 1) == 2, "tie -> lowest index")
assert(ET.PrimaryTab(tree, {}, 1) == 1, "nothing spent -> fallback")
assert(ET.PrimaryTab(tree, { [4] = 1 }, 1) == 3, "single tree")
assert(ET.NumTabs(tree) == 3 and #pts == 3, "3-tab tree (tab count from talents)")

-- Fourth branch: tab count from tree.tabs / talents, never more than 4.
local tree4 = { tabs = { [1] = {}, [2] = {}, [3] = {}, [4] = {} },
                talents = { { id = 1, tab = 1 }, { id = 2, tab = 2 }, { id = 3, tab = 3 }, { id = 4, tab = 4 } } }
assert(ET.NumTabs(tree4) == 4, "4-tab tree")
local pts4 = ET.SpecPoints(tree4, { [1] = 1, [4] = 7 })
assert(#pts4 == 4 and pts4[1] == 1 and pts4[2] == 0 and pts4[4] == 7, "per-tab sums incl. tab 4")
assert(table.concat(pts4, "/") == "1/0/0/7", "inspect footer a/b/c/d")
assert(ET.PrimaryTab(tree4, { [4] = 7 }, 1) == 4, "tab 4 can be primary")
assert(ET.PrimaryTab(tree4, { [1] = 5, [4] = 5 }, 1) == 1, "tie with tab 4 -> lowest index")
assert(ET.NumTabs({ tabs = { [1] = {}, [2] = {}, [3] = {} }, talents = {} }) == 3, "tab count from tree.tabs alone")
assert(ET.NumTabs({ talents = { { id = 9, tab = 5 } } }) == 4, "capped at MAX_TABS")

-- FitTabWidths (pure).
local function sum(t) local s = 0 for _, x in ipairs(t) do s = s + x end return s end
local same = ET.FitTabWidths({ 60, 70, 80 }, 280)
assert(same[1] == 60 and same[2] == 70 and same[3] == 80, "fits -> natural widths")
local eq = ET.FitTabWidths({ 200, 200, 200, 200 }, 278)
assert(eq[1] == 69 and eq[4] == 69 and sum(eq) <= 278, "all long -> one common floored cap")
local tiny = ET.FitTabWidths({ 200, 200, 200, 200 }, 40)
assert(tiny[1] == 33, "cap never below the two 16px caps + 1")

-- LayoutTabs with mock tab buttons. Mock font: 5.3px per character (estimate; the four real
-- hunter names then span 347.7px naturally, the 345-350px measured in game). The mock is
-- pessimistic: a capped text reports its CAPPED width, so a missing reset shows up as drift.
local CHAR_W = 5.3
local function chars(s) return (select(2, s:gsub("[^\128-\191]", ""))) end
local function MockTab(name)
  local text = { w = 0 }
  local tab = { name = name, shown = true, width = 0, str = "" }
  function text:SetWidth(w) self.w = w end
  function text:GetWidth()
    local full = chars(tab.str) * CHAR_W
    return (self.w > 0 and self.w < full) and self.w or full
  end
  _G[name .. "Text"] = text
  function tab:GetName() return self.name end
  function tab:SetText(s) self.str = s end
  function tab:GetTextWidth() return text:GetWidth() end
  function tab:Show() self.shown = true end
  function tab:Hide() self.shown = false end
  return tab
end
-- Blizzard's PanelTemplates_TabResize (UIPanelTemplates.lua, 3.3.5a), the two paths LayoutTabs uses.
_G.PanelTemplates_TabResize = function(tab, padding, absoluteSize)
  local text = _G[tab:GetName() .. "Text"]
  if absoluteSize then
    text:SetWidth(absoluteSize - 32); tab.width = absoluteSize
  else
    local tw = text:GetWidth()
    text:SetWidth(0); tab.width = tw + (padding or 24) + 32
  end
  tab.args = { padding, absoluteSize }
end
local function MockView(style)
  local tabs = {}
  for i = 1, 4 do tabs[i] = MockTab("MockView" .. style .. "Tab" .. i) end
  return { frame = { tabs = tabs }, tabStyle = style, tabPad = (style == "top") and -10 or 0 }
end
local function RightEdge(v)      -- tabs chain LEFT->RIGHT with no gap from x = 70
  local x = 70
  for _, tab in ipairs(v.frame.tabs) do if tab.shown then x = x + tab.width end end
  return x
end
local HUNTER4 = { tabs = { { name = "Bestias" }, { name = "Puntería" }, { name = "Supervivencia" },
                           { name = "Maestro de la cacería" } }, talents = {} }
local HUNTER3 = { tabs = { HUNTER4.tabs[1], HUNTER4.tabs[2], HUNTER4.tabs[3] }, talents = {} }

local iv = MockView("top")
local function CheckHunter4(label)
  ET.LayoutTabs(iv, HUNTER4, 4)
  local t = iv.frame.tabs
  assert(RightEdge(iv) + 2 <= 350, label .. ": last tab + highlight inside x <= 350")
  assert(t[1].args[1] == -10 and t[2].args[1] == -10, label .. ": short tabs keep the stock padding path")
  assert(t[1].etFullName == nil and t[2].etFullName == nil, label .. ": no tooltip on full tabs")
  assert(t[3].args[2] == 77 and t[4].args[2] == 77, label .. ": long tabs share the cap (77)")
  assert(t[3].etFullName == "Supervivencia" and t[4].etFullName == "Maestro de la cacería", label .. ": full names kept")
  return RightEdge(iv)
end
local function CheckHunter3(label)
  ET.LayoutTabs(iv, HUNTER3, 3)
  local t = iv.frame.tabs
  for k = 1, 3 do
    assert(t[k].args[1] == -10 and t[k].args[2] == nil and t[k].etFullName == nil, label .. ": stock resize " .. k)
    assert(math.abs(t[k].width - (chars(HUNTER3.tabs[k].name) * CHAR_W + 22)) < 1e-9, label .. ": natural width " .. k)
    assert(_G[t[k]:GetName() .. "Text"].w == 0, label .. ": text width reset " .. k)
  end
  assert(not t[4].shown, label .. ": 4th tab hidden")
end
local edge1 = CheckHunter4("4 tabs")
assert(CheckHunter4("4 -> 4 (second hunter)") == edge1, "4 -> 4 identical (measured from scratch)")
CheckHunter3("4 -> 3")
CheckHunter4("3 -> 4")

-- Own window ("bottom"): never fitted, even with 4 tabs.
local ov = MockView("bottom")
ET.LayoutTabs(ov, HUNTER4, 4)
for k = 1, 4 do
  assert(ov.frame.tabs[k].args[1] == 0 and ov.frame.tabs[k].args[2] == nil, "bottom tab " .. k .. " unchanged")
  assert(ov.frame.tabs[k].etFullName == nil, "bottom tab " .. k .. " no tooltip")
end
print(string.format("LayoutTabs OK (hunter 4 tabs: right edge %.1f, +2 highlight)", edge1))
print("test_inspect OK")

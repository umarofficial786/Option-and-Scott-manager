require "import"
import "android.widget.*"
import "android.content.*"
import "android.view.*"
import "android.graphics.drawable.*"
import "android.net.Uri"
import "android.text.*"
import "java.io.*"
import "android.database.sqlite.SQLiteDatabase"
import "java.net.URL"
import "java.lang.Thread"
import "java.lang.Runnable"
import "android.os.Handler"
import "android.os.Looper"
import "android.view.accessibility.AccessibilityEvent"
local RawDialog = LuaDialog
local dialogs, closingAll = {}, false
local function LuaDialog()
local d = RawDialog()
dialogs[#dialogs + 1] = d
return d
end
local function closeAll()
closingAll = true
for _, d in ipairs(dialogs) do pcall(function() d.dismiss() end) end
end
local dlg = LuaDialog()
local FLAG = "\240\159\135\181\240\159\135\176"
dlg.setTitle("Squad Manager & Auction Manager Pro  Developer Umar Jan " .. FLAG)
local ctx = activity or service or this
math.randomseed(os.time())
-- NOTES: Max players per team now counts only auction picks; favorites (Captain, Vice Captain, Owner, others) are not counted
-- NOTES: Every action gives a clear message that is also spoken a moment later, so the screen reader does not cut it off
-- NOTES: Paste from Clipboard button, Back / Home / Exit on every screen, new links, ready WhatsApp feedback message, detailed guide
local APP_VERSION = 12
local UPDATE_URL = "https://raw.githubusercontent.com/umarofficial786/Option-and-Scott-manager/refs/heads/main/main.lua"
local LINKS = {"https://wa.me/923089162797", "https://t.me/UmarjaanPro", "https://www.youtube.com/@UmarofficialPro"}
local roles = {"Player", "Batsman", "Bowler", "All-Rounder", "Wicket-Keeper", "Captain", "Vice Captain", "Reserve"}
local curLabel = { Coins = "Coins (Virtual)", PKR = "PKR - Pakistani Rupee", INR = "INR - Indian Rupee", BDT = "BDT - Bangladeshi Taka" }
local primaryCodes = {"Coins", "PKR", "INR", "BDT"}
local secondaryCodes = {"PKR", "INR", "BDT"}
local playerRoles = {"Batsman", "Bowler", "All-Rounder", "Wicket-Keeper"}
local function shape(c, r)
local s = GradientDrawable()
s.setColor(tonumber(c)); s.setCornerRadius(r or 20)
return s
end
local function btn(id, text, color, extra)
local t = { Button; id = id; text = text; textColor = "#FFFFFF"; background = shape(color); layout_width = "-1" }
for k, v in pairs(extra or {}) do t[k] = v end
return t
end
local function cell(id, text, color) return btn(id, text, color, { layout_weight = 1, layout_width = "0dp", textSize = "12sp" }) end
local function navBar()
return { LinearLayout; orientation = "horizontal"; layout_width = "-1";
cell("backB", "Back", "0xFF607D8B"); cell("homeB", "Home", "0xFF00796B"); cell("exitB", "Exit", "0xFFD32F2F");
}
end
local function goHome()
for _, d in ipairs(dialogs) do
if d ~= dlg then pcall(function() d.dismiss() end) end
end
end
local function wireNav(v, d)
v.backB.setOnClickListener(View.OnClickListener({ onClick = function() d.dismiss() end }))
v.homeB.setOnClickListener(View.OnClickListener({ onClick = goHome }))
v.exitB.setOnClickListener(View.OnClickListener({ onClick = closeAll }))
end
local function trim(s) return (tostring(s or ""):gsub("^%s*(.-)%s*$", "%1")) end
local function parseLines(text)
local out = {}
for line in tostring(text or ""):gmatch("[^\r\n]+") do
local t = trim(line)
if t ~= "" then out[#out + 1] = t end
end
return out
end
local toastCount = 0
local speakHandler = Handler(Looper.getMainLooper())
local function announce(m)
if pcall(function() service.speak(m) end) then return end
pcall(function()
local am = ctx.getSystemService(Context.ACCESSIBILITY_SERVICE)
if am.isEnabled() then
local ev = AccessibilityEvent.obtain(AccessibilityEvent.TYPE_ANNOUNCEMENT)
ev.getText().add(m)
ev.setPackageName(ctx.getPackageName())
am.sendAccessibilityEvent(ev)
end
end)
end
local function toast(m, long)
toastCount = toastCount + 1
Toast.makeText(ctx, m, (long or #m > 40) and 1 or 0).show()
pcall(function() speakHandler.postDelayed(Runnable({ run = function() announce(m) end }), 700) end)
end
local function copy(text)
local ok = pcall(function() ctx.getSystemService(Context.CLIPBOARD_SERVICE).setPrimaryClip(ClipData.newPlainText("text", text)) end)
if pcall(function() service.copy(text) end) then ok = true end
if not ok then ok = pcall(function() ctx.getSystemService(Context.CLIPBOARD_SERVICE).setText(text) end) end
toast(ok and "Copied!" or "Could not copy. Use Share instead.", not ok)
end
local function clipText()
local t
pcall(function()
local clip = ctx.getSystemService(Context.CLIPBOARD_SERVICE).getPrimaryClip()
if clip and clip.getItemCount() > 0 then t = tostring(clip.getItemAt(0).coerceToText(ctx)) end
end)
return t
end
local function share(text)
pcall(function()
local i = Intent(Intent.ACTION_SEND)
i.setType("text/plain"); i.putExtra(Intent.EXTRA_TEXT, text)
local ch = Intent.createChooser(i, "Share")
ch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
ctx.startActivity(ch)
end)
end
local function shareWA(pkg, text, close)
closeAll()
local ok = pcall(function()
local i = Intent(Intent.ACTION_SEND)
i.setType("text/plain"); i.putExtra(Intent.EXTRA_TEXT, text); i.setPackage(pkg)
i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
ctx.startActivity(i)
end)
if not ok then toast("That WhatsApp is not installed.") share(text) end
end
local function openUrl(u)
pcall(function()
local i = Intent(Intent.ACTION_VIEW, Uri.parse(u))
i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
ctx.startActivity(i)
end)
end
local function message(title, msg)
local d = LuaDialog()
d.setTitle(title); d.setMessage(msg); d.setButton("OK", nil); d.show()
end
local function confirmDialog(title, msg, label, onConfirm)
local d = LuaDialog()
d.setTitle(title); d.setMessage(msg)
d.setButton(label, DialogInterface.OnClickListener({ onClick = function()
local before = toastCount
onConfirm()
if toastCount == before then toast("Done.") end
end }))
d.setButton2("Cancel", DialogInterface.OnClickListener({ onClick = function() toast("Cancelled. Nothing was changed.") end }))
d.show()
end
local function formDialog(title, fields, onOk)
local d = LuaDialog()
d.setTitle(title)
local lay = { LinearLayout; orientation = "vertical"; padding = "16dp"; layout_width = "-1" }
for _, f in ipairs(fields) do
local e = { EditText; id = f.id; hint = f.hint; layout_width = "-1" }
if f.multi then e.inputType = "textMultiLine"; e.minLines = 5; e.maxLines = 8 end
if f.num then e.inputType = "number" end
lay[#lay + 1] = e
if f.paste then lay[#lay + 1] = btn("paste_" .. f.id, "Paste from Clipboard", "0xFF1976D2", { layout_marginBottom = "8dp" }) end
end
local v = {}
d.setView(loadlayout(lay, v))
for _, f in ipairs(fields) do
if f.text then v[f.id].setText(f.text) end
if f.paste then
v["paste_" .. f.id].setOnClickListener(View.OnClickListener({ onClick = function()
local t = clipText()
if not t or trim(t) == "" then toast("The clipboard is empty or cannot be read. Long press the box and choose Paste.", true) return end
local cur = trim(v[f.id].getText())
v[f.id].setText(cur ~= "" and (cur .. "\n" .. t) or t)
toast("Pasted.")
end }))
end
end
d.setButton("Save", DialogInterface.OnClickListener({ onClick = function()
local vals = {}
for _, f in ipairs(fields) do vals[f.id] = trim(v[f.id].getText()) end
onOk(vals)
end}))
d.setButton2("Cancel", nil)
d.show()
end
local function promptInput(title, initial, hint, onSave, num)
formDialog(title, {{ id = "v", hint = hint, text = initial, num = num }}, function(x)
if x.v ~= "" then onSave(x.v) else toast("Please enter a value.") end
end)
end
local function listDialog(title, items, onSelect, onLong)
local d = LuaDialog()
d.setTitle(title)
local lv = ListView(ctx)
lv.setAdapter(ArrayAdapter(ctx, android.R.layout.simple_list_item_1, items))
d.setView(lv)
local di = d.show()
lv.setOnItemClickListener(AdapterView.OnItemClickListener({ onItemClick = function(_, _, pos, _)
if di then di.dismiss() end
onSelect(pos)
end}))
if onLong then
lv.setOnItemLongClickListener(AdapterView.OnItemLongClickListener({ onItemLongClick = function(_, _, pos, _)
return onLong(pos, di)
end}))
end
end
local function shareMenu(text, close)
listDialog("Share via", { "WhatsApp Business", "WhatsApp Messenger", "Other Apps" }, function(p)
if p == 0 then shareWA("com.whatsapp.w4b", text, close)
elseif p == 1 then shareWA("com.whatsapp", text, close)
else
closeAll()
share(text)
end
end)
end
local function pickerStay(title, items, onPick)
local d = LuaDialog()
d.setTitle(title)
local v = {}
d.setView(loadlayout({ LinearLayout; orientation = "vertical"; padding = "12dp"; layout_width = "-1"; layout_height = "-1";
{ ListView; id = "list"; layout_width = "-1"; layout_height = "0dp"; layout_weight = 1; layout_marginBottom = "8dp" };
navBar() }, v))
d.show()
v.list.setAdapter(ArrayAdapter(ctx, android.R.layout.simple_list_item_1, items))
v.list.setOnItemClickListener(AdapterView.OnItemClickListener({ onItemClick = function(_, _, pos, _) onPick(pos + 1) end }))
wireNav(v, d)
end
local function listManager(title, newText, withSearch, extras, loadFn, onNew, onClick, onLong, onClose, shareText, infoFn)
local d = LuaDialog()
d.setTitle(title)
if shareText then
extras = extras or {}
extras[#extras + 1] = { text = "Share - WhatsApp Business", onClick = function(_, close) shareWA("com.whatsapp.w4b", shareText(), close) end }
extras[#extras + 1] = { text = "Share - WhatsApp Messenger", onClick = function(_, close) shareWA("com.whatsapp", shareText(), close) end }
extras[#extras + 1] = { text = "Share - Other Apps", onClick = function() closeAll(); share(shareText()) end }
end
local hasMore = extras and #extras > 0
local lay = { LinearLayout; orientation = "vertical"; padding = "16dp"; layout_width = "-1"; layout_height = "-1" }
if newText or hasMore then
local top = { LinearLayout; orientation = "horizontal"; layout_width = "-1"; layout_marginBottom = "8dp" }
if newText then top[#top + 1] = btn("newB", newText, "0xFF3F51B5", { layout_width = "0dp", layout_weight = 1 })
else top[#top + 1] = { TextView; layout_width = "0dp"; layout_weight = 1 } end
if hasMore then top[#top + 1] = btn("moreB", "More Options", "0xFF795548", { layout_width = "-2", layout_marginLeft = "6dp" }) end
lay[#lay + 1] = top
end
if infoFn then lay[#lay + 1] = { TextView; id = "infoT"; textSize = "12sp"; layout_width = "-1"; layout_marginBottom = "8dp" } end
if withSearch then lay[#lay + 1] = { EditText; id = "search"; hint = "Search..."; layout_marginBottom = "8dp"; layout_width = "-1" } end
lay[#lay + 1] = { ListView; id = "list"; layout_width = "-1"; layout_height = "0dp"; layout_weight = 1; layout_marginBottom = "8dp" }
lay[#lay + 1] = navBar()
local v = {}
d.setView(loadlayout(lay, v))
d.show()
if onClose then
pcall(function() d.setOnDismissListener(DialogInterface.OnDismissListener({ onDismiss = function() if not closingAll then onClose() end end })) end)
end
local recs, q = {}, ""
local function load()
local items
recs, items = loadFn(q)
v.list.setAdapter(ArrayAdapter(ctx, android.R.layout.simple_list_item_1, items))
if infoFn then v.infoT.setText(infoFn()) end
end
load()
if withSearch then
v.search.addTextChangedListener(TextWatcher({
beforeTextChanged = function() end,
onTextChanged = function(s) q = tostring(s or ""); load() end,
afterTextChanged = function() end
}))
end
if v.newB then v.newB.setOnClickListener(View.OnClickListener({ onClick = function() onNew(load) end })) end
if v.moreB then
v.moreB.setOnClickListener(View.OnClickListener({ onClick = function()
local labels = {}
for i, b in ipairs(extras) do labels[i] = b.text end
pickerStay("More Options", labels, function(i) extras[i].onClick(load, function() d.dismiss() end) end)
end}))
end
v.list.setOnItemClickListener(AdapterView.OnItemClickListener({ onItemClick = function(_, _, pos, _)
if recs[pos + 1] then onClick(recs[pos + 1], load) end
end}))
if onLong then
v.list.setOnItemLongClickListener(AdapterView.OnItemLongClickListener({ onItemLongClick = function(_, _, pos, _)
if recs[pos + 1] then onLong(recs[pos + 1], load) end
return true
end}))
end
wireNav(v, d)
end
local db
pcall(function()
db = SQLiteDatabase.openOrCreateDatabase(ctx.getFilesDir().getPath() .. "/squads.db", nil)
db.execSQL("CREATE TABLE IF NOT EXISTS squads (tournament TEXT, team TEXT, squad_text TEXT, opponents TEXT, owner TEXT);")
db.execSQL("CREATE TABLE IF NOT EXISTS squad_matches (id INTEGER PRIMARY KEY AUTOINCREMENT, tournament TEXT, match_date TEXT, match_time TEXT, team1 TEXT, team2 TEXT, venue TEXT, stage TEXT);")
db.execSQL("CREATE TABLE IF NOT EXISTS app_settings (k TEXT PRIMARY KEY, v TEXT);")
db.execSQL("CREATE TABLE IF NOT EXISTS backups (id INTEGER PRIMARY KEY AUTOINCREMENT, filename TEXT, filepath TEXT, created_at TEXT, restored_at TEXT);")
db.execSQL("CREATE TABLE IF NOT EXISTS auctions (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, coins_per_team INTEGER, default_base_price INTEGER, created_at TEXT, currency TEXT, currency2 TEXT, coins_per_team2 INTEGER, allow_fallback INTEGER, max_players_per_team INTEGER);")
db.execSQL("CREATE TABLE IF NOT EXISTS auction_teams (id INTEGER PRIMARY KEY AUTOINCREMENT, auction_id INTEGER, team_name TEXT, coins_remaining INTEGER, coins_remaining2 INTEGER);")
db.execSQL("CREATE TABLE IF NOT EXISTS auction_players (id INTEGER PRIMARY KEY AUTOINCREMENT, auction_id INTEGER, player_name TEXT, base_price INTEGER, status TEXT, sold_to_team TEXT, sold_price INTEGER, sold_price2 INTEGER);")
end)
if not db then toast("Database could not be opened.", true) return end
for _, s in ipairs({ "ALTER TABLE squads ADD COLUMN team TEXT;", "ALTER TABLE squads ADD COLUMN opponents TEXT;", "ALTER TABLE squads ADD COLUMN owner TEXT;", "ALTER TABLE backups ADD COLUMN restored_at TEXT;", "ALTER TABLE auctions ADD COLUMN currency TEXT;",
"ALTER TABLE auctions ADD COLUMN currency2 TEXT;", "ALTER TABLE auctions ADD COLUMN coins_per_team2 INTEGER;",
"ALTER TABLE auctions ADD COLUMN allow_fallback INTEGER;", "ALTER TABLE auctions ADD COLUMN max_players_per_team INTEGER;",
"ALTER TABLE auction_teams ADD COLUMN coins_remaining2 INTEGER;", "ALTER TABLE auction_players ADD COLUMN sold_price2 INTEGER;" }) do
pcall(function() db.execSQL(s) end)
end
local function run(sql, ...)
local args = { ... }
return pcall(function()
local st = db.compileStatement(sql)
for i, a in ipairs(args) do
if type(a) == "number" then st.bindLong(i, a) else st.bindString(i, tostring(a)) end
end
local id
if sql:sub(1, 6) == "INSERT" then id = st.executeInsert() else st.executeUpdateDelete() end
st.close()
return id
end)
end
local function query(sql)
local rows = {}
pcall(function()
local c = db.rawQuery(sql, nil)
local n = c.getColumnCount()
while c.moveToNext() do
local r = {}
for i = 0, n - 1 do r[i + 1] = c.getString(i) or "" end
rows[#rows + 1] = r
end
c.close()
end)
return rows
end
local function getSetting(k, fallbackValue)
local r = query("SELECT v FROM app_settings WHERE k='" .. k .. "'")
if r[1] and r[1][1] ~= "" then return r[1][1] end
return fallbackValue
end
local function setSetting(k, v) run("INSERT OR REPLACE INTO app_settings (k, v) VALUES (?,?)", k, v) end
local function esc(s)
s = tostring(s or "")
return (s:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("|", "\\p"))
end
local function unesc(s)
return (s:gsub("\\(.)", function(c)
if c == "p" then return "|" elseif c == "n" then return "\n" else return c end
end))
end
local function splitFields(line, n)
local f, start = {}, 1
for _ = 1, n - 1 do
local idx = line:find("|", start, true)
if not idx then break end
f[#f + 1] = unesc(line:sub(start, idx - 1))
start = idx + 1
end
f[#f + 1] = unesc(line:sub(start))
return f
end
local function buildBackup(tags, opt)
opt = opt or {}
local out, want = {}, {}
for _, t in ipairs(tags) do want[t] = true end
local function add(tag, rows)
if not want[tag] then return end
for _, r in ipairs(rows) do
for i = 1, #r do r[i] = esc(r[i]) end
out[#out + 1] = tag .. "|" .. table.concat(r, "|")
end
end
local sq = {}
for _, r in ipairs(query("SELECT tournament, team, squad_text, opponents, owner FROM squads ORDER BY rowid")) do
if not opt.tournament or r[1] == opt.tournament then sq[#sq + 1] = r end
end
add("SQ", sq)
local sm = {}
for _, r in ipairs(query("SELECT tournament, match_date, match_time, team1, team2, venue, stage FROM squad_matches ORDER BY id")) do
if not opt.tournament or r[1] == opt.tournament then sm[#sm + 1] = r end
end
add("SM", sm)
local w1 = opt.auction and (" WHERE id=" .. opt.auction) or ""
local w2 = opt.auction and (" WHERE auction_id=" .. opt.auction) or ""
add("AU", query("SELECT id, name, coins_per_team, default_base_price, created_at, currency, currency2, coins_per_team2, max_players_per_team, allow_fallback FROM auctions" .. w1 .. " ORDER BY id"))
add("AT", query("SELECT auction_id, team_name, coins_remaining, coins_remaining2 FROM auction_teams" .. w2 .. " ORDER BY id"))
add("AP", query("SELECT auction_id, player_name, base_price, status, sold_to_team, sold_price, sold_price2 FROM auction_players" .. w2 .. " ORDER BY id"))
return table.concat(out, "\n")
end
local function restore(text, tags)
local want, amap, c = {}, {}, { SQ = 0, SM = 0, AU = 0, AT = 0, AP = 0 }
local sizes = { SQ = 5, SM = 7, AU = 10, AT = 4, AP = 7 }
for _, t in ipairs(tags) do want[t] = true end
for line in (text .. "\n"):gmatch("(.-)\n") do
line = line:gsub("\r", "")
local tag = line:sub(1, 2)
if want[tag] and sizes[tag] then
local f, ok, id = splitFields(line:sub(4), sizes[tag])
if tag == "SQ" then
ok = run("INSERT INTO squads (tournament, team, squad_text, opponents, owner) VALUES (?,?,?,?,?)", f[1], f[2], f[3] or "", f[4] or "", f[5] or "")
elseif tag == "SM" then
ok = run("INSERT INTO squad_matches (tournament, match_date, match_time, team1, team2, venue, stage) VALUES (?,?,?,?,?,?,?)",
f[1], f[2] or "", f[3] or "", f[4] or "", f[5] or "", f[6] or "", f[7] or "")
elseif tag == "AU" then
ok, id = run("INSERT INTO auctions (name, coins_per_team, default_base_price, created_at, currency, currency2, coins_per_team2, max_players_per_team, allow_fallback) VALUES (?,?,?,?,?,?,?,?,?)",
f[2], tonumber(f[3]) or 0, tonumber(f[4]) or 0, os.date("%Y-%m-%d %H:%M"), f[6] or "", f[7] or "", tonumber(f[8]) or 0, tonumber(f[9]) or 0, tonumber(f[10]) or 0)
if ok and id then amap[tonumber(f[1])] = id end
elseif amap[tonumber(f[1])] then
if tag == "AT" then
ok = run("INSERT INTO auction_teams (auction_id, team_name, coins_remaining, coins_remaining2) VALUES (?,?,?,?)", amap[tonumber(f[1])], f[2], tonumber(f[3]) or 0, tonumber(f[4]) or 0)
else
ok = run("INSERT INTO auction_players (auction_id, player_name, base_price, status, sold_to_team, sold_price, sold_price2) VALUES (?,?,?,?,?,?,?)",
amap[tonumber(f[1])], f[2], tonumber(f[3]) or 0, f[4], f[5], tonumber(f[6]) or 0, tonumber(f[7]) or 0)
end
end
if ok then c[tag] = c[tag] + 1 end
end
end
return c
end
local function backupDir()
local dir
pcall(function()
local base = ctx.getExternalFilesDir(nil)
if base then dir = File(base, "CricketSquadManager/Backups") end
end)
if not dir then pcall(function() dir = File(ctx.getFilesDir(), "Backups") end) end
pcall(function() if dir and not dir.exists() then dir.mkdirs() end end)
return dir
end
local function readFile(path)
local content
pcall(function()
local br = BufferedReader(InputStreamReader(FileInputStream(File(path)), "UTF-8"))
local lines, line = {}, br.readLine()
while line ~= nil do lines[#lines + 1] = line; line = br.readLine() end
br.close(); content = table.concat(lines, "\n")
end)
return content
end
local function safeName(x) return (tostring(x):gsub("[^%w]+", "_")) end
local function exportBackup(label, tags, opt)
local text = buildBackup(tags, opt)
if text == "" then toast("No data to backup yet.") return end
local dir = backupDir()
if not dir then toast("Could not save the backup file.", true) return end
local name = label .. "_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
local ok, path = pcall(function()
local f = File(dir, name)
local w = OutputStreamWriter(FileOutputStream(f), "UTF-8")
w.write(text); w.flush(); w.close()
return f.getAbsolutePath()
end)
if ok then
run("INSERT INTO backups (filename, filepath, created_at) VALUES (?,?,?)", name, path, os.date("%Y-%m-%d %H:%M"))
toast("Backup saved:\n" .. path, true)
else
toast("Could not save the backup file.", true)
end
end
local function showBackup(label, tags)
listDialog(label .. " - Backup", { "Export (save a backup file)", "Import (restore from a saved backup file)", "Delete all saved backup files" }, function(pos)
if pos == 0 then exportBackup(label, tags) return end
if pos == 2 then
confirmDialog("Delete All Backup Files", "Delete every saved backup file? Your squads and auctions are not touched.", "Yes, Delete All", function()
for _, r in ipairs(query("SELECT filepath FROM backups")) do pcall(function() File(r[1]).delete() end) end
run("DELETE FROM backups")
toast("All backup files deleted.")
end)
return
end
local function pick()
local recs = query("SELECT id, filename, filepath, created_at, restored_at FROM backups ORDER BY id DESC")
if #recs == 0 then toast("No backups yet. Export first.", true) return end
local names = {}
for i, r in ipairs(recs) do names[i] = r[2] .. "  -  " .. r[4] .. (r[5] ~= "" and "  [restored]" or "") end
listDialog("Select a Backup (long press to delete)", names, function(p)
local r = recs[p + 1]
local function go()
local text = readFile(r[3])
if not text or trim(text) == "" then toast("Could not read that backup file.", true) return end
local c = restore(text, tags)
run("UPDATE backups SET restored_at=? WHERE id=?", os.date("%Y-%m-%d %H:%M"), tonumber(r[1]))
toast(string.format("Restored: %d squad(s), %d match(es), %d auction(s), %d team(s), %d player(s).", c.SQ, c.SM, c.AU, c.AT, c.AP), true)
end
if r[5] ~= "" then
confirmDialog("Already Restored", "Restored on " .. r[5] .. ". Importing again may create duplicates. Continue?", "Yes, Import Again", go)
else
go()
end
end, function(p, di)
local r = recs[p + 1]
confirmDialog("Delete Backup", "Delete " .. r[2] .. "? This cannot be undone.", "Yes, Delete", function()
run("DELETE FROM backups WHERE id=?", tonumber(r[1]))
pcall(function() File(r[3]).delete() end)
if di then di.dismiss() end
pick()
end)
return true
end)
end
pick()
end)
end
local function stripStar(l) return (l:gsub("^[%*!]+%s*", "")) end
local function splitPlayer(l)
l = stripStar(l)
local n, r = l:match("^(.-)%s+%-%s+(.+)$")
if n then return n, r end
return l, ""
end
local function joinPlayer(n, r) return (r ~= "" and r ~= "Player") and (n .. " - " .. r) or n end
local function playerName(l) return (splitPlayer(l)) end
local function isPlaying(l) return (l:match("^[%*!]*")):find("*", 1, true) ~= nil end
local function isFav(l) return (l:match("^[%*!]*")):find("!", 1, true) ~= nil end
local function remark(old, bare, on) return (isFav(old) and "!" or "") .. (on and "*" or "") .. stripStar(bare) end
local function addUnique(list, names)
local seen, added = {}, 0
for _, l in ipairs(list) do seen[playerName(l):lower()] = true end
for _, n in ipairs(names) do
if not seen[n:lower()] then seen[n:lower()] = true; list[#list + 1] = n; added = added + 1 end
end
return added, #names - added
end
local function loadSquads(tournament)
local recs = {}
for _, r in ipairs(query("SELECT rowid, tournament, team, squad_text, opponents, owner FROM squads ORDER BY rowid")) do
if not tournament or r[2] == tournament then
recs[#recs + 1] = { id = tonumber(r[1]), tournament = r[2], team = r[3], text = r[4], opponents = r[5], owner = r[6] }
end
end
return recs
end
local MONTHS = { january = 1, jan = 1, february = 2, feb = 2, march = 3, mar = 3, april = 4, apr = 4, may = 5, june = 6, jun = 6,
july = 7, jul = 7, august = 8, aug = 8, september = 9, sep = 9, sept = 9, october = 10, oct = 10, november = 11, nov = 11, december = 12, dec = 12 }
local WEEKDAYS = { monday = 1, mon = 1, tuesday = 1, tue = 1, tues = 1, wednesday = 1, wed = 1, thursday = 1, thu = 1, thur = 1, thurs = 1,
friday = 1, fri = 1, saturday = 1, sat = 1, sunday = 1, sun = 1 }
local function normName(s)
s = tostring(s)
local n = s:lower():gsub("[^%w]", "")
if n == "" then n = trim(s) end
return n
end
local function matchTeam(name, teams)
local n = normName(name)
if n == "" then return name, false end
for _, t in ipairs(teams) do
if normName(t) == n then return t, true end
end
local found, many = nil, false
for _, t in ipairs(teams) do
local tn = normName(t)
if #n >= 3 and #tn >= 3 and (tn:find(n, 1, true) or n:find(tn, 1, true)) then
if found then many = true end
found = t
end
end
if found and not many then return found, true end
for _, t in ipairs(teams) do
local ac = ""
for w in t:gmatch("%a+") do ac = ac .. w:sub(1, 1):lower() end
if #n >= 2 and ac == n then return t, true end
end
return name, false
end
local function mkDate(y, m, d)
y, m, d = tonumber(y), tonumber(m), tonumber(d)
if not (y and m and d) then return nil end
if y < 100 then y = y + 2000 end
if m > 12 and d <= 12 then m, d = d, m end
if m < 1 or m > 12 or d < 1 or d > 31 then return nil end
return string.format("%04d-%02d-%02d", y, m, d)
end
local function extractDate(line)
local thisYear = tonumber(os.date("%Y"))
local a, b, x, y, z = line:find("(%d%d%d%d)[%-/%.](%d%d?)[%-/%.](%d%d?)")
if a then return mkDate(x, y, z), line:sub(1, a - 1) .. " " .. line:sub(b + 1), false end
a, b, x, y, z = line:find("(%d%d?)[%-/%.](%d%d?)[%-/%.](%d%d%d%d)")
if a then return mkDate(z, y, x), line:sub(1, a - 1) .. " " .. line:sub(b + 1), false end
a, b, x, y, z = line:find("(%d%d?)[%-/%.](%d%d?)[%-/%.](%d%d)")
if a and not line:sub(b + 1, b + 1):match("%d") then return mkDate(z, y, x), line:sub(1, a - 1) .. " " .. line:sub(b + 1), false end
for s, w, e in line:gmatch("()(%a+)()") do
local mo = MONTHS[w:lower()]
if mo then
local before, after = line:sub(1, s - 1), line:sub(e)
local st, _, day = before:find("(%d%d?)%a?%a?[%s%-,]*$")
if day and st > 1 and before:sub(st - 1, st - 1):match("%d") then day = nil end
local from, to = st, e - 1
if not day then
local _, en2, d2 = after:find("^[%s%-,]*(%d%d?)%a?%a?")
if d2 and after:sub(en2 + 1, en2 + 1) ~= ":" then
day, from, to = d2, s, e - 1 + en2
end
end
if day then
local _, en3, yr = line:sub(to + 1):find("^[%s,%-]*(%d%d%d%d)")
if yr and line:sub(to + en3 + 1, to + en3 + 1):match("%d") then yr = nil end
if yr then to = to + en3 end
local iso = mkDate(tonumber(yr) or thisYear, mo, day)
if iso then return iso, line:sub(1, from - 1) .. " " .. line:sub(to + 1), not yr end
end
end
end
a, b, x, y = line:find("(%d%d?)/(%d%d?)")
if a and not line:sub(b + 1, b + 1):match("%d") then
local iso = mkDate(thisYear, y, x)
if iso then return iso, line:sub(1, a - 1) .. " " .. line:sub(b + 1), true end
end
local low = line:lower()
for word, add in pairs({ today = 0, tomorrow = 1, yesterday = -1 }) do
local i, j = low:find(word, 1, true)
if i then return os.date("%Y-%m-%d", os.time() + add * 86400), line:sub(1, i - 1) .. " " .. line:sub(j + 1), false end
end
return nil, line, false
end
local function fmtTime(h, m, ap)
h = tonumber(h); m = tonumber(m) or 0
if ap then
ap = ap:upper()
if h < 1 or h > 12 then return nil end
else
if h > 23 or m > 59 then return nil end
ap = (h >= 12) and "PM" or "AM"
h = h % 12
if h == 0 then h = 12 end
end
return string.format("%d:%02d %s", h, m, ap)
end
local function extractTime(line)
local a, b, h, m, ap = line:find("(%d%d?):(%d%d)%s*([AaPp])[Mm]")
if a and not line:sub(b + 1, b + 1):match("%a") then
local t = fmtTime(h, m, ap .. "M")
if t then return t, line:sub(1, a - 1) .. " " .. line:sub(b + 1) end
end
a, b, h, ap = line:find("(%d%d?)%s*([AaPp])[Mm]")
if a and not line:sub(b + 1, b + 1):match("%a") then
local t = fmtTime(h, 0, ap .. "M")
if t then return t, line:sub(1, a - 1) .. " " .. line:sub(b + 1) end
end
a, b, h, m, ap = line:find("(%d%d?)%.(%d%d)%s*([AaPp])[Mm]")
if a and not line:sub(b + 1, b + 1):match("%a") then
local t = fmtTime(h, m, ap .. "M")
if t then return t, line:sub(1, a - 1) .. " " .. line:sub(b + 1) end
end
a, b, h, m = line:find("(%d%d?):(%d%d)")
if a then
local t = fmtTime(h, m, nil)
if t then return t, line:sub(1, a - 1) .. " " .. line:sub(b + 1) end
end
return nil, line
end
local function extractLabeledTime(line, word)
local a, b, h, m, ap = line:find(word .. "[%a%s]*(%d%d?):(%d%d)%s*([AaPp])[Mm]")
if a and not line:sub(b + 1, b + 1):match("%a") then
local t = fmtTime(h, m, ap .. "M")
if t then return t, line:sub(1, a - 1) .. " " .. line:sub(b + 1) end
end
return nil, line
end
local function stripNoise(line)
line = line:gsub("%a+", function(w) if WEEKDAYS[w:lower()] then return " " end end)
line = (line .. " "):gsub("[Gg]roup%s+%w([%s%p])", "%1"):gsub("[Dd]ay%s*%d+([%s%p])", "%1"):gsub("[Rr]ound%s*%d+([%s%p])", "%1")
return trim(line)
end
local function cleanName(s)
s = s:gsub("%b()", " "):gsub("%b[]", " ")
s = s:gsub("^[%p%s]+", ""):gsub("[%p%s]+$", "")
return (s:gsub("%s+", " "))
end
local function cleanVenue(s)
return (s:gsub("^[%p%s]+", ""):gsub("[%p%s]+$", ""))
end
local function splitVs(seg)
local low = seg:lower()
for _, sep in ipairs({ " versus ", " vs. ", " vs ", " v/s ", " v. ", " v ", " x " }) do
local i, j = low:find(sep, 1, true)
if i then return trim(seg:sub(1, i - 1)), trim(seg:sub(j + 1)) end
end
return nil
end
local function cutVenue(right)
local low, bi, bl = right:lower(), nil, 0
for _, c in ipairs({ " at ", "@", ",", "(", " - " }) do
local i = low:find(c, 1, true)
if i and (not bi or i < bi) then bi, bl = i, #c end
end
if not bi then return right, "" end
return right:sub(1, bi - 1), right:sub(bi + bl)
end
local function findTeams(line, teams, hasDT)
local segs = {}
for seg in (line .. "|"):gmatch("(.-)|") do
if trim(seg) ~= "" then segs[#segs + 1] = trim(seg) end
end
for si, seg in ipairs(segs) do
local l, r = splitVs(seg)
if l then
local venue
r, venue = cutVenue(r)
if venue == "" then
local others = {}
for sj, s2 in ipairs(segs) do
if sj ~= si then others[#others + 1] = s2 end
end
venue = table.concat(others, ", ")
end
return cleanName(l), cleanName(r), cleanVenue(venue)
end
end
if not hasDT then return nil end
local named = {}
for _, sg in ipairs(segs) do
if sg:find("%a") then named[#named + 1] = sg end
end
local l, r, venue
if #named == 1 then
local i, j = named[1]:find(" - ", 1, true)
if i then
l = trim(named[1]:sub(1, i - 1))
r, venue = cutVenue(trim(named[1]:sub(j + 1)))
end
elseif #named >= 2 then
l, r, venue = named[1], named[2], named[3] or ""
end
if l and r then
l, r = cleanName(l), cleanName(r)
if l ~= "" and r ~= "" and (select(2, matchTeam(l, teams)) or select(2, matchTeam(r, teams))) then
return l, r, cleanVenue(venue or "")
end
end
return nil
end
local function parseSchedule(text, teams)
local items, raws = {}, parseLines(text)
local function known(n) return (select(2, matchTeam(n, teams))) end
for idx, raw in ipairs(raws) do
local it = { raw = raw }
local nxt = raws[idx + 1]
if raw:match("^%-%-%-+%s*$") or raw:match("^===+%s*$") then
it.kind = "used"
elseif nxt and nxt:match("^%-%-%-%-+%s*$") then
it.kind = "head"
local parts = {}
for part in (raw .. " - "):gmatch("(.-)%s+%-%s+") do parts[#parts + 1] = trim(part) end
it.tourn = parts[2] or parts[1]
else
local line = raw:gsub("\t", " | "):gsub("\226\128[\147\148]", "-")
line = line:gsub("^%s*TODAY%s*%-%s*", "")
line = line:gsub("[Ss]tatus%s*:%s*[%a ]-%-%s*", "")
it.date, line, it.noYear = extractDate(line)
local st
it.room, line = extractLabeledTime(line, "[Rr]oom")
st, line = extractLabeledTime(line, "[Ss]tart")
it.time, line = extractTime(line)
it.time = st or it.time
local num
local a, b, n = line:find("[Mm]atch%s*[Nn]?[Oo]?%.?%s*#?%s*(%d+)")
if not a then a, b, n = line:find("(%d+)%a%a%s*[Mm]atch") end
if not a then a, b, n = line:find("^%s*#%s*(%d+)") end
if not a then a, b, n = line:find("^%s*(%d+)%s*[%.%)]%s+") end
if not a then a, b, n = line:find("^%s*(%d+)%s*|") end
if a then num = n; line = line:sub(1, a - 1) .. " " .. line:sub(b + 1) end
line = stripNoise(line)
local label
local ci = line:find(":", 1, true)
if ci then
local prefix, rest = trim(line:sub(1, ci - 1)), line:sub(ci + 1)
if prefix ~= "" and not splitVs(prefix) and (splitVs(rest) or rest:find("|", 1, true)) then
label = cleanName(prefix); line = rest
end
end
if num then label = "Match " .. num end
if label == "" then label = nil end
it.label = label
local hasDT = it.date ~= nil or it.time ~= nil or it.room ~= nil
local t1, t2 = findTeams(line, teams, hasDT)
if t1 and t2 and t1 ~= "" and t2 ~= "" then
it.kind, it.t1, it.t2 = "m", t1, t2
elseif hasDT or it.label then
it.kind = "i"
else
local nm = cleanName(line)
local low = nm:lower()
if low == "vs" or low == "v" or low == "versus" or low == "v/s" then
it.kind = "sep"
else
it.kind = "x"
local words = 0
for _ in nm:gmatch("%S+") do words = words + 1 end
local venueWord = low:find("stadium", 1, true) or low:find("ground", 1, true) or low:find("oval", 1, true) or
low:find("arena", 1, true) or low:find("park", 1, true) or low:find("club", 1, true) or low:find("cricket", 1, true)
if nm ~= "" and words <= 4 and not nm:find("%d") and not venueWord then it.name = nm end
end
end
end
items[#items + 1] = it
end
for k = 1, #items do
local x = items[k]
if x.kind == "x" and x.name then
local j = k + 1
if items[j] and items[j].kind == "sep" then j = j + 1 end
local y = items[j]
if y and y.kind == "x" and y.name and (known(x.name) or known(y.name)) then
x.kind, x.t1, x.t2 = "m", x.name, y.name
for z = k + 1, j do items[z].kind = "used" end
end
end
end
local dateLead, labelLead = false, false
for _, it in ipairs(items) do
if it.kind == "m" then break end
if it.kind == "i" then
if it.date or it.time then dateLead = true end
if it.label then labelLead = true end
end
end
local out, undated, ignored = {}, {}, {}
local cDate, cTime, cNoYear, pendLabel, lastDate, curTourn
for k, it in ipairs(items) do
if it.kind == "head" then
curTourn = it.tourn
elseif it.kind == "i" then
if it.date then cDate, cTime, cNoYear = it.date, it.time, it.noYear
elseif it.time then cTime = it.time end
if it.label then pendLabel = it.label end
elseif it.kind == "x" then
ignored[#ignored + 1] = it.raw
elseif it.kind == "m" then
local d, t, ny, lb = it.date, it.time, it.noYear, it.label
if not d then
if dateLead then
d, ny, t = cDate, cNoYear, t or cTime
else
for j = k + 1, #items do
local inf = items[j]
if inf.kind == "m" then break end
if inf.kind == "i" then
if not d and inf.date then d, ny = inf.date, inf.noYear; t = t or inf.time end
if not t and inf.time then t = inf.time end
end
end
end
end
if not t then
for j = k + 1, #items do
local inf = items[j]
if inf.kind == "m" then break end
if inf.kind == "i" then
if inf.date then break end
if inf.time then t = inf.time break end
end
end
end
if not lb and labelLead then lb = pendLabel end
if not lb and not labelLead then
for j = k + 1, #items do
local inf = items[j]
if inf.kind == "m" then break end
if inf.kind == "i" and inf.label then lb = inf.label break end
end
end
pendLabel = nil
if it.date then cDate, cTime, cNoYear = it.date, it.time, it.noYear end
if d then
if ny and lastDate and d < lastDate and (tonumber(lastDate:sub(6, 7)) or 0) >= 10 and (tonumber(d:sub(6, 7)) or 0) <= 3 then
d = string.format("%04d", tonumber(d:sub(1, 4)) + 1) .. d:sub(5)
end
lastDate = d
else
undated[#undated + 1] = it.raw
end
out[#out + 1] = { date = d or "", time = t or "", room = it.room or "", t1 = (matchTeam(it.t1, teams)), t2 = (matchTeam(it.t2, teams)),
venue = "", stage = lb or ("Match " .. (#out + 1)), tourn = curTourn }
end
end
return out, undated, ignored
end
local function unifyNames(list, teams)
local names, seen = {}, {}
local function add(n)
local k = normName(n)
if k ~= "" and not seen[k] then seen[k] = true; names[#names + 1] = n end
end
for _, t in ipairs(teams) do add(t) end
for _, m in ipairs(list) do add(m.t1); add(m.t2) end
local function acro(n)
local r = ""
for w in n:gmatch("%a+") do r = r .. w:sub(1, 1):lower() end
return r
end
local map = {}
for _, n in ipairs(names) do
local nk, found, many = normName(n), nil, false
for _, o in ipairs(names) do
local ok = normName(o)
if o ~= n and #ok > #nk then
if (#nk >= 3 and ok:find(nk, 1, true)) or (#nk >= 2 and #nk <= 5 and acro(o) == nk) then
if found and found ~= o then many = true end
found = o
end
end
end
if found and not many then map[normName(n)] = found end
end
for _, m in ipairs(list) do
m.t1 = map[normName(m.t1)] or m.t1
m.t2 = map[normName(m.t2)] or m.t2
end
return list
end
local function filterTournament(list, tournament)
local function ok(m) return m.tourn and select(2, matchTeam(m.tourn, { tournament })) end
local any = false
for _, m in ipairs(list) do
if ok(m) then any = true break end
end
if not any then return list, false end
local out = {}
for _, m in ipairs(list) do
if ok(m) then out[#out + 1] = m end
end
return out, true
end
local MONTH_NAMES = { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" }
local function dispDate(d)
local y, m, dd = (d or ""):match("(%d+)-(%d+)-(%d+)")
if not y then return (d == nil or d == "") and "No date" or d end
return string.format("%d", tonumber(dd)) .. " " .. (MONTH_NAMES[tonumber(m)] or m) .. " " .. y
end
local function timeMin(t)
local h, m, ap = (t or ""):match("(%d+):(%d+)%s*(%a%a)")
if not h then return 99999 end
h = tonumber(h) % 12
if ap:upper() == "PM" then h = h + 12 end
return h * 60 + tonumber(m)
end
local function loadMatches(tournament)
local list = {}
for _, r in ipairs(query("SELECT id, tournament, match_date, match_time, team1, team2, venue, stage FROM squad_matches ORDER BY id")) do
if r[2] == tournament then
list[#list + 1] = { id = tonumber(r[1]), date = r[3], time = r[4], t1 = r[5], t2 = r[6],
room = (r[7]:match("^%d+:%d+ [AP]M$") and r[7]) or "", stage = r[8] }
end
end
table.sort(list, function(x, y)
local dx, dy = (x.date == "") and "9999-99-99" or x.date, (y.date == "") and "9999-99-99" or y.date
if dx ~= dy then return dx < dy end
local tx, ty = timeMin(x.time), timeMin(y.time)
if tx ~= ty then return tx < ty end
return x.id < y.id
end)
return list
end
local function isUp(m, today) return m.date == "" or m.date >= today end
local function matchNoLabel(m) return (m.stage ~= "" and m.stage) or "Match" end
local function oppOf(m, team)
return (normName(m.t1) == normName(team)) and m.t2 or m.t1
end
local function matchLine(m, team)
return (m.date == os.date("%Y-%m-%d") and "TODAY - " or "") .. matchNoLabel(m) .. " - " .. dispDate(m.date) ..
(m.time ~= "" and (" " .. m.time) or "") .. (m.room ~= "" and (" (room " .. m.room .. ")") or "") .. " - vs " .. oppOf(m, team)
end
local function loadTeamMatches(tournament, team)
local nt, list = normName(team), {}
for _, m in ipairs(loadMatches(tournament)) do
if normName(m.t1) == nt or normName(m.t2) == nt then list[#list + 1] = m end
end
return list
end
local function matchHeader(tournament, team, all)
local today, nt = os.date("%Y-%m-%d"), normName(team)
for _, m in ipairs(all or loadMatches(tournament)) do
if isUp(m, today) and (normName(m.t1) == nt or normName(m.t2) == nt) then
return ((m.date == today) and "Today" or ("Next - " .. dispDate(m.date))) .. ": " .. matchNoLabel(m) .. " vs " .. oppOf(m, team) ..
(m.time ~= "" and (" - " .. m.time) or "")
end
end
return ""
end
local function squadTeams(tournament)
local t, seen = {}, {}
local function add(n)
if n ~= "" and not seen[normName(n)] then seen[normName(n)] = true; t[#t + 1] = n end
end
for _, r in ipairs(loadSquads(tournament)) do
add(r.team)
for _, o in ipairs(parseLines(r.opponents)) do add(o) end
end
return t
end
local function keepMine(list, team)
local nt, out = normName(team), {}
local function mine(n) return normName(n) == nt or (select(2, matchTeam(n, { team }))) end
for _, m in ipairs(list) do
local a, b = mine(m.t1), mine(m.t2)
if a ~= b then
out[#out + 1] = { date = m.date, time = m.time, room = m.room or "", t1 = team, t2 = a and m.t2 or m.t1, venue = "", stage = m.stage }
end
end
return out
end
local function saveMatches(tournament, list)
local seen = {}
local function key(m)
local a, b = normName(m.t1), normName(m.t2)
if a > b then a, b = b, a end
return m.date .. "|" .. a .. "|" .. b .. ((m.date == "") and ("|" .. (m.stage or "")) or "")
end
for _, m in ipairs(loadMatches(tournament)) do seen[key(m)] = true end
local added, dup = 0, 0
for _, m in ipairs(list) do
if seen[key(m)] then
dup = dup + 1
else
seen[key(m)] = true; added = added + 1
run("INSERT INTO squad_matches (tournament, match_date, match_time, team1, team2, venue, stage) VALUES (?,?,?,?,?,?,?)",
tournament, m.date, m.time or "", m.t1, m.t2, m.room or m.venue or "", m.stage or "")
end
end
return added, dup
end
local function teamTodayLine(tournament, team)
local today, all, todays, nextm = os.date("%Y-%m-%d"), loadTeamMatches(tournament, team), {}, nil
for _, m in ipairs(all) do
if m.date == today then
todays[#todays + 1] = matchNoLabel(m) .. " vs " .. oppOf(m, team) .. (m.time ~= "" and (" (" .. m.time .. ")") or "")
elseif isUp(m, today) and not nextm then
nextm = m
end
end
if #todays > 0 then return "Today: " .. table.concat(todays, "  |  ") end
if nextm then return "Next: " .. matchNoLabel(nextm) .. " - " .. dispDate(nextm.date) .. " vs " .. oppOf(nextm, team) end
if #all == 0 then return "No matches yet - tap + Paste Schedule." end
return "All matches are completed."
end
local function scheduleText(tournament, team, which)
local today, out, n = os.date("%Y-%m-%d"), { team .. " - Schedule." }, 0
for _, m in ipairs(loadTeamMatches(tournament, team)) do
if which == "all" or (which == "up" and isUp(m, today)) or (which == "done" and not isUp(m, today)) or (which == "today" and m.date == today) then
n = n + 1; out[#out + 1] = matchLine(m, team) .. "."
end
end
if n == 0 then out[#out + 1] = "No matches." end
return table.concat(out, "\n")
end
local squadRoles = { "Player", "Batsman", "Bowler", "All-Rounder", "Wicket-Keeper", "Reserve", "Captain", "Vice Captain", "Second Vice Captain" }
local roleColor = { Captain = "0xFFFF6F00", ["Vice Captain"] = "0xFFFFA000", ["Second Vice Captain"] = "0xFFFFB74D", Reserve = "0xFF795548" }
local LEADS = { Captain = true, ["Vice Captain"] = true, ["Second Vice Captain"] = true }
local function orderPlaying(players)
local lead, mid, res = {}, {}, {}
for i, l in ipairs(players) do
if isPlaying(l) then
local _, r = splitPlayer(l)
if LEADS[r] and not lead[r] then lead[r] = i
elseif r == "Reserve" then res[#res + 1] = i
else mid[#mid + 1] = i end
end
end
local xi = {}
for _, r in ipairs({ "Captain", "Vice Captain", "Second Vice Captain" }) do
if lead[r] then xi[#xi + 1] = lead[r] end
end
for _, i in ipairs(mid) do xi[#xi + 1] = i end
return xi, res
end
local function applyRole(players, i, role)
if role == "Player" or role == "No role" then role = "" end
local name, on = playerName(players[i]), isPlaying(players[i])
if LEADS[role] then
for k, l in ipairs(players) do
if k ~= i then
local n, r = splitPlayer(l)
if r == role then players[k] = remark(l, joinPlayer(n, ""), isPlaying(l)) end
end
end
end
if LEADS[role] or role == "Reserve" then on = true end
players[i] = remark(players[i], joinPlayer(name, role), on)
end
local function applyTick(players, i, on)
local n, r = splitPlayer(players[i])
if not on and (LEADS[r] or r == "Reserve") then r = "" end
players[i] = remark(players[i], joinPlayer(n, r), on)
end
local function xiCheck(players)
local xi = orderPlaying(players)
local hasC, hasV, bad = false, false, {}
for _, i in ipairs(xi) do
local _, r = splitPlayer(players[i])
if r == "Captain" then hasC = true elseif r == "Vice Captain" then hasV = true end
end
if not hasC then bad[#bad + 1] = "no Captain" end
if not hasV then bad[#bad + 1] = "no Vice Captain" end
if #xi < 11 then bad[#bad + 1] = (11 - #xi) .. " more player(s) needed for 11"
elseif #xi > 11 then bad[#bad + 1] = (#xi - 11) .. " too many players" end
return table.concat(bad, ", ")
end
local ROLE_WORDS = { captain = true, c = true, ["vice captain"] = true, ["vice-captain"] = true, vc = true, ["second vice captain"] = true,
["2vc"] = true, svc = true, batsman = true, batter = true, bowler = true, ["all-rounder"] = true, ["all rounder"] = true, allrounder = true,
["wicket-keeper"] = true, ["wicket keeper"] = true, wicketkeeper = true, wk = true, keeper = true, reserve = true, player = true,
owner = true, ["team owner"] = true, favorite = true }
local ROLE_PHRASES = { "second vice captain", "vice captain", "vice-captain", "captain", "all-rounder", "all rounder", "allrounder",
"wicket-keeper", "wicket keeper", "wicketkeeper", "batsman", "batter", "bowler", "reserve", "player" }
local SKIP_LABELS = { ["players picked"] = true, ["slots left"] = true, ["max bid"] = true, budget = true, used = true, remaining = true,
["secondary budget"] = true, ["secondary used"] = true, ["secondary remaining"] = true, roles = true, tournament = true, match = true,
date = true, time = true, ["room time"] = true, ["match time"] = true, opponent = true, status = true, players = true, unsold = true,
["still in room"] = true, picks = true, pool = true }
local function parsePlayerText(text, skipNames)
local lines, out, owner = parseLines(text), {}, nil
local function skipName(n)
local k = normName(n)
for _, s in ipairs(skipNames or {}) do
if k == normName(s) then return true end
end
return false
end
local function clean(name)
name = trim(name)
name = name:gsub("^\226\128\162%s*", "")
name = name:gsub("^[%s%.,;:%-%*#>]+", "")
name = name:gsub("^%d+%s+", "")
name = name:gsub("%s+%d[%d,%.]*%s*%a*$", "")
name = name:gsub("[%s%.,;:%*]+$", "")
if ROLE_WORDS[name:lower()] then return nil end
local changed = true
while changed do
changed = false
local low = name:lower()
for _, ph in ipairs(ROLE_PHRASES) do
local L = #ph
if #low > L + 1 and low:sub(-L) == ph and low:sub(-L - 1, -L - 1):match("%s") then
name = trim(name:sub(1, #name - L)); changed = true break
end
if #low > L + 1 and low:sub(1, L) == ph and low:sub(L + 1, L + 1):match("%s") then
name = trim(name:sub(L + 1)); changed = true break
end
end
end
name = name:gsub("[%s%.,;:%*]+$", "")
if #name < 2 or not name:find("[%a\128-\255]") or ROLE_WORDS[name:lower()] or skipName(name) then return nil end
local words = 0
for _ in name:gmatch("%S+") do words = words + 1 end
if words > 6 then return nil end
return name
end
for idx, line in ipairs(lines) do
line = (line:gsub("\t", " | "))
local skip, ownerHere, plays = false, false, false
local label = line:match("^([%a%s%-/]+):")
if idx == 1 and not line:find(":", 1, true) then
local nl = lines[2] and lines[2]:match("^([%a%s%-/]+):")
if nl and SKIP_LABELS[trim(nl:lower())] then skip = true end
end
if not skip and label then
local ll, rest = trim(label:lower()), trim(line:sub(#label + 2))
if SKIP_LABELS[ll] then
skip = true
elseif ll == "captain" or ll == "vice captain" or ll == "second vice captain" then
line = rest
elseif ll:find("owner", 1, true) then
ownerHere = true
plays = ll:find("/", 1, true) ~= nil or rest:lower():find("plays as", 1, true) ~= nil
line = rest
end
end
if not skip then
local low = line:lower()
if low:find("playing xi", 1, true) or low:find("full squad", 1, true) or low:find("schedule", 1, true) or low:find("no players", 1, true) or
low:find("playing %d") or low:find("remaining players", 1, true) or low:find("unsold players", 1, true) or low:find("results", 1, true) or
low:find(" teams", 1, true) or low:match("^top %d") or low:match("^match%s*%d") or low:find(" vs ", 1, true) or low:find(" v ", 1, true) or
line:find("%d:%d%d") or extractDate(line) then
skip = true
end
end
if not skip then
line = line:gsub("^[Rr]eserve%s*%d*%s*[%.%):%-]+%s*", "")
line = line:gsub("^[Pp]ick%s*%d+%s*[%.%):%-]*%s*", "")
line = line:gsub("^[Pp]layer%s*%d+%s*[%.%):%-]*%s*", "")
line = line:gsub("^#?%d+%s*[%.%)%-:]+%s*", "")
line = line:gsub("%b()", " ")
line = line:gsub("%b[]", " ")
local parts = {}
for part in (line .. " - "):gmatch("(.-)%s+%-%s+") do parts[#parts + 1] = part end
for i = 2, #parts do
local w = trim(parts[i]):lower()
if w:find("owner", 1, true) then ownerHere = true; plays = w:find("/", 1, true) ~= nil end
end
local nm = parts[1] or ""
if nm:find("|", 1, true) then
for cell in (nm .. "|"):gmatch("(.-)|") do
if clean(cell) then nm = cell break end
end
end
local names = {}
for piece in (nm .. ";"):gmatch("(.-)[;,]") do
local c = clean(piece)
if c then names[#names + 1] = c end
end
if ownerHere then
if names[1] then
owner = names[1]
if plays then out[#out + 1] = names[1] end
end
else
for _, c in ipairs(names) do out[#out + 1] = c end
end
end
end
return out, owner
end
local function addParsed(players, text, skipNames)
local names, owner = parsePlayerText(text, skipNames)
local added, skipped = addUnique(players, names)
return added, skipped, owner
end
local function teamMatchLists(tournament, team)
local today, up, done = os.date("%Y-%m-%d"), {}, {}
for _, m in ipairs(loadTeamMatches(tournament, team)) do
if isUp(m, today) then up[#up + 1] = m else table.insert(done, 1, m) end
end
return up, done
end
local function pickDefaultMatch(tournament, team)
local up = teamMatchLists(tournament, team)
return up[1]
end
local function squadText(rec, players, m)
local xi, res = orderPlaying(players)
local out = { rec.team .. " Playing " .. #xi .. ((#res > 0) and (" plus " .. #res .. " Reserve") or "") .. ".", "Tournament: " .. rec.tournament .. "." }
if m then
out[#out + 1] = matchNoLabel(m) .. "."
if m.date ~= "" then out[#out + 1] = "Date: " .. dispDate(m.date) .. "." end
if m.room ~= "" then
out[#out + 1] = "Room Time: " .. m.room .. "."
if m.time ~= "" then out[#out + 1] = "Match Time: " .. m.time .. "." end
elseif m.time ~= "" then
out[#out + 1] = "Time: " .. m.time .. "."
end
out[#out + 1] = "Opponent: " .. oppOf(m, rec.team) .. "."
end
out[#out + 1] = ""
for k, i in ipairs(xi) do
local n, r = splitPlayer(players[i])
out[#out + 1] = k .. ". " .. n .. ((r ~= "" and r ~= "Player") and (", " .. r) or "") .. "."
end
if #xi == 0 then out[#out + 1] = "No players selected yet." end
for k, i in ipairs(res) do out[#out + 1] = "Reserve " .. k .. ". " .. playerName(players[i]) .. "." end
return table.concat(out, "\n")
end
local function fullSquadText(rec, players)
local out = { rec.team .. " Full Squad.", "Tournament: " .. rec.tournament .. "." }
if rec.owner and rec.owner ~= "" then out[#out + 1] = "Team Owner: " .. rec.owner .. "." end
out[#out + 1] = ""
for i, l in ipairs(players) do
local n, r = splitPlayer(l)
out[#out + 1] = i .. ". " .. n .. ((r ~= "" and r ~= "Player") and (", " .. r) or "") .. "."
end
if #players == 0 then out[#out + 1] = "No players yet." end
return table.concat(out, "\n")
end
local function pasteSchedule(name, team, load)
formDialog("Paste Schedule (any style)", {{ id = "t", hint = "Paste the schedule here - neat or messy, any style", multi = true, paste = true }}, function(x)
local teams = squadTeams(name)
local list, _, ignored = parseSchedule(x.t, teams)
local hasHeads = false
for _, m in ipairs(list) do
if m.tourn then hasHeads = true break end
end
local total = #list
local usedFilter
list, usedFilter = filterTournament(list, name)
list = unifyNames(list, teams)
local mine = keepMine(list, team)
local function firstLines(arr, n)
local t = {}
for i = 1, math.min(n, #arr) do t[i] = arr[i]:sub(1, 60) end
return table.concat(t, "\n")
end
if #mine == 0 then
local read = {}
for i = 1, math.min(4, #list) do read[i] = list[i].t1 .. " vs " .. list[i].t2 .. " (" .. dispDate(list[i].date) .. ")" end
message("No Match Found",
(#list == 0 and "No matches could be read from this text."
or (#list .. " match(es) were read, but none of them has " .. team .. ". For example:\n" .. table.concat(read, "\n"))) ..
"\n\nCheck that your team is written the same way in the schedule (short forms like LQ are fine).")
return
end
local noDate = 0
local prev = {}
for i, m in ipairs(mine) do
if m.date == "" then noDate = noDate + 1 end
if i <= 15 then prev[i] = matchLine(m, team) end
end
local msg = #mine .. " match(es) of " .. team .. " found:\n\n" .. table.concat(prev, "\n") ..
(#mine > 15 and ("\n... and " .. (#mine - 15) .. " more") or "") ..
((total > #mine) and ("\n\n" .. (total - #mine) .. " match(es) of other teams or other tournaments were ignored.") or "") ..
((hasHeads and not usedFilter) and ("\n\nThe tournament names in the text do not match " .. name .. ", so every block was used.") or "") ..
((noDate > 0) and ("\n\n" .. noDate .. " match(es) have no date and are saved without one.") or "") ..
((#ignored > 0) and ("\n\n" .. #ignored .. " other line(s) ignored.") or "")
confirmDialog("Check Schedule", msg, "Save All", function()
local added, dup = saveMatches(name, mine)
toast(added .. " saved" .. (dup > 0 and (", " .. dup .. " duplicate(s) skipped") or ""), true)
load()
end)
end)
end
local function matchMenu(name, team, m, load)
listDialog(matchNoLabel(m) .. " vs " .. oppOf(m, team), { "Change Date", "Change Time", "Change Room Time", "Change Opponent", "Change Match Number", "Delete Match" }, function(p)
if p == 0 then
promptInput("New Date", m.date ~= "" and dispDate(m.date) or "", "e.g. 12-10-2026 or 12 Oct", function(s)
local d = extractDate(s)
if not d then toast("Could not read that date.") return end
run("UPDATE squad_matches SET match_date=? WHERE id=?", d, m.id); load()
end)
elseif p == 1 then
promptInput("New Match Time", m.time, "e.g. 7:00 PM", function(s)
local t = extractTime(s)
if not t then toast("Could not read that time.") return end
run("UPDATE squad_matches SET match_time=? WHERE id=?", t, m.id); load()
end)
elseif p == 2 then
promptInput("New Room Time", m.room, "e.g. 6:45 PM", function(s)
local t = extractTime(s)
if not t then toast("Could not read that time.") return end
run("UPDATE squad_matches SET venue=? WHERE id=?", t, m.id); load()
end)
elseif p == 3 then
promptInput("Opponent Team", oppOf(m, team), "Team name", function(s)
run("UPDATE squad_matches SET team1=?, team2=? WHERE id=?", team, (matchTeam(s, squadTeams(name))), m.id); load()
end)
elseif p == 4 then
promptInput("Match Number", (m.stage:match("%d+")) or "", "e.g. 5", function(s)
run("UPDATE squad_matches SET stage=? WHERE id=?", "Match " .. s, m.id); load()
end, true)
else
confirmDialog("Delete Match", "Delete " .. matchNoLabel(m) .. " vs " .. oppOf(m, team) .. "?", "Yes, Delete", function()
run("DELETE FROM squad_matches WHERE id=?", m.id); load()
end)
end
end)
end
local function showSchedule(name, team, refreshOuter)
listManager("Schedule - " .. team, "+ Paste Schedule", false,
{{ text = "Add One Match Manually", onClick = function(load)
formDialog("Add Match", {
{ id = "n", hint = "Match number (e.g. 5)", num = true },
{ id = "d", hint = "Date (optional, e.g. 12-10-2026 or 12 Oct)" },
{ id = "tm", hint = "Match time (optional, e.g. 7:00 PM)" },
{ id = "rm", hint = "Room time (optional, e.g. 6:45 PM)" },
{ id = "o", hint = "Opponent team name" } }, function(x)
local date = ""
if x.d ~= "" then
date = extractDate(x.d)
if not date then toast("Could not read the date.") return end
end
if x.o == "" then toast("Enter the opponent team name.") return end
saveMatches(name, {{ date = date, time = (extractTime(x.tm)) or "", room = (extractTime(x.rm)) or "", t1 = team,
t2 = (matchTeam(x.o, squadTeams(name))), venue = "", stage = (x.n ~= "") and ("Match " .. x.n) or "" }})
load()
end)
end },
{ text = "Copy Today's Match", onClick = function() copy(scheduleText(name, team, "today")) end },
{ text = "Copy Upcoming Matches", onClick = function() copy(scheduleText(name, team, "up")) end },
{ text = "Copy Completed Matches", onClick = function() copy(scheduleText(name, team, "done")) end },
{ text = "Delete Completed Matches", onClick = function(load)
confirmDialog("Delete Completed Matches", "Delete all matches dated before today?", "Yes, Delete", function()
local today = os.date("%Y-%m-%d")
for _, m in ipairs(loadTeamMatches(name, team)) do
if not isUp(m, today) then run("DELETE FROM squad_matches WHERE id=?", m.id) end
end
load()
end)
end },
{ text = "Delete All Matches of This Team", onClick = function(load)
confirmDialog("Delete All Matches", "Delete the whole schedule of " .. team .. "?", "Yes, Delete All", function()
for _, m in ipairs(loadTeamMatches(name, team)) do run("DELETE FROM squad_matches WHERE id=?", m.id) end
load()
end)
end }},
function()
local today, up, done = os.date("%Y-%m-%d"), {}, {}
for _, m in ipairs(loadTeamMatches(name, team)) do
if isUp(m, today) then up[#up + 1] = m else done[#done + 1] = m end
end
local recs, items = { { header = true } }, { "--- UPCOMING (" .. #up .. ") ---" }
for _, m in ipairs(up) do recs[#recs + 1] = m; items[#items + 1] = matchLine(m, team) end
recs[#recs + 1] = { header = true }; items[#items + 1] = "--- COMPLETED (" .. #done .. ") ---"
for i = #done, 1, -1 do recs[#recs + 1] = done[i]; items[#items + 1] = matchLine(done[i], team) end
return recs, items
end,
function(load) pasteSchedule(name, team, load) end,
function(m, load) if not m.header then matchMenu(name, team, m, load) end end,
function(m, load) if not m.header then matchMenu(name, team, m, load) end end,
function() if refreshOuter then refreshOuter() end end,
function() return scheduleText(name, team, "all") end,
function() return teamTodayLine(name, team) end)
end
local function showSquad(rec, refresh)
local players = parseLines(rec.text)
local chosen = pickDefaultMatch(rec.tournament, rec.team)
local d = LuaDialog()
d.setTitle(rec.team .. " - " .. rec.tournament)
local v = {}
d.setView(loadlayout({ LinearLayout; orientation = "vertical"; padding = "12dp"; layout_width = "-1"; layout_height = "-1";
{ LinearLayout; orientation = "horizontal"; layout_width = "-1"; layout_marginBottom = "6dp";
{ TextView; id = "info"; textSize = "12sp"; layout_width = "0dp"; layout_weight = 1 };
btn("moreB", "More Options", "0xFF9C27B0", { layout_width = "-2", layout_marginLeft = "6dp", textSize = "12sp" });
};
{ ScrollView; layout_width = "-1"; layout_height = "0dp"; layout_weight = 1; layout_marginBottom = "8dp";
{ LinearLayout; id = "rows"; orientation = "vertical"; layout_width = "-1" };
};
{ LinearLayout; orientation = "horizontal"; layout_width = "-1";
cell("copyB", "Copy Playing List", "0xFF00C853"); cell("shareB", "Share Playing List", "0xFF25D366");
};
navBar();
}, v))
d.show()
if refresh then
pcall(function() d.setOnDismissListener(DialogInterface.OnDismissListener({ onDismiss = function() if not closingAll then refresh() end end })) end)
end
local cbs, rbs = {}, {}
local function focusOn(view)
pcall(function() view.requestFocus() end)
pcall(function() view.performAccessibilityAction(64, nil) end)
end
local function persist()
rec.text = table.concat(players, "\n")
run("UPDATE squads SET squad_text=? WHERE rowid=?", rec.text, rec.id)
end
local function refreshRows()
local xi, res = orderPlaying(players)
local slot = {}
for k, i in ipairs(xi) do slot[i] = tostring(k) end
for k, i in ipairs(res) do slot[i] = "R" .. k end
for i, l in ipairs(players) do
local name, role = splitPlayer(l)
local shown = (role ~= "" and role ~= "Player") and role or "Player"
local on = isPlaying(l)
cbs[i].setText((slot[i] and (slot[i] .. ".  ") or "") .. name)
cbs[i].setChecked(on)
rbs[i].setText(shown)
rbs[i].setEnabled(on)
rbs[i].setBackground(shape(on and (roleColor[role] or "0xFF3F51B5") or "0xFF9E9E9E", 8))
pcall(function()
rbs[i].setContentDescription(on and ("Role of " .. name .. ": " .. shown .. ". Tap to change.")
or ("Role of " .. name .. ": " .. shown .. ". Not available, tick the player first."))
end)
end
v.info.setText((chosen and matchLine(chosen, rec.team) or "No match selected (More Options > Choose Match)") ..
"\nPlayers: " .. #players .. "  |  Playing XI: " .. #xi .. "  |  Reserves: " .. #res ..
(xiCheck(players) ~= "" and ("\nCheck: " .. xiCheck(players) .. ".") or "\nXI check: 11 players, Captain and Vice Captain are set.") ..
"\nTick = playing, then pick a role. Captain is always #1, Vice Captain #2, Reserves last. Long press a name for rename / move / delete.")
end
local buildRows
local function playerMenu(i)
local on = isPlaying(players[i])
listDialog(playerName(players[i]), { "Rename", "Move Up", "Move Down", "Delete" }, function(p)
if p == 0 then
local n, r = splitPlayer(players[i])
promptInput("Rename Player", n, "Name", function(nn)
players[i] = remark(players[i], joinPlayer(nn, r), on); persist(); refreshRows(); focusOn(cbs[i])
end)
elseif p == 1 then
if i > 1 then players[i], players[i - 1] = players[i - 1], players[i]; persist(); buildRows(i - 1) end
elseif p == 2 then
if i < #players then players[i], players[i + 1] = players[i + 1], players[i]; persist(); buildRows(i + 1) end
else
table.remove(players, i); persist(); buildRows(math.min(i, #players))
end
end)
end
buildRows = function(focusIndex)
v.rows.removeAllViews()
cbs, rbs = {}, {}
for i = 1, #players do
local row = LinearLayout(ctx)
row.setOrientation(LinearLayout.HORIZONTAL)
local cb = CheckBox(ctx)
cb.setLayoutParams(LinearLayout.LayoutParams(0, -2, 1))
local rb = Button(ctx)
rb.setTextSize(11); rb.setTextColor(0xFFFFFFFF)
rb.setLayoutParams(LinearLayout.LayoutParams(-2, -2))
row.addView(cb); row.addView(rb)
v.rows.addView(row)
cbs[i], rbs[i] = cb, rb
cb.setOnClickListener(View.OnClickListener({ onClick = function()
applyTick(players, i, cb.isChecked()); persist(); refreshRows(); focusOn(cb)
end }))
cb.setOnLongClickListener(View.OnLongClickListener({ onLongClick = function() playerMenu(i) return true end }))
rb.setOnClickListener(View.OnClickListener({ onClick = function()
if not isPlaying(players[i]) then toast("Tick the player first.") return end
listDialog("Role - " .. playerName(players[i]), squadRoles, function(p)
applyRole(players, i, squadRoles[p + 1]); persist(); refreshRows(); focusOn(rbs[i])
toast(playerName(players[i]) .. " is now " .. squadRoles[p + 1] .. ".")
end)
end }))
end
refreshRows()
if focusIndex and cbs[focusIndex] then focusOn(cbs[focusIndex]) end
end
buildRows()
local function chooseMatch()
local up, done = teamMatchLists(rec.tournament, rec.team)
if #up + #done == 0 then
message("Match", "No matches for this team yet. Open More Options > Schedule and paste the tournament schedule.")
return
end
local items, ms = { "No match (hide)" }, { false }
for _, m in ipairs(up) do ms[#ms + 1] = m; items[#items + 1] = matchLine(m, rec.team) end
for _, m in ipairs(done) do ms[#ms + 1] = m; items[#items + 1] = "[Completed] " .. matchLine(m, rec.team) end
listDialog("Select Match", items, function(p) chosen = ms[p + 1] or nil; refreshRows() end)
end
v.copyB.setOnClickListener(View.OnClickListener({ onClick = function()
local chk = xiCheck(players)
if chk ~= "" then toast("Note: " .. chk .. ".", true) end
copy(squadText(rec, players, chosen))
end}))
v.shareB.setOnClickListener(View.OnClickListener({ onClick = function()
local chk = xiCheck(players)
if chk ~= "" then toast("Note: " .. chk .. ".", true) end
shareMenu(squadText(rec, players, chosen), function() d.dismiss() end)
end}))
local function setOwner(name)
rec.owner = name
run("UPDATE squads SET owner=? WHERE rowid=?", name, rec.id)
end
local function addPlayersDialog()
formDialog("Add Players", {{ id = "p", hint = "Paste any list - names are picked out automatically", multi = true, paste = true }}, function(x)
local before = #players
local added, skipped, owner = addParsed(players, x.p, { rec.team, rec.tournament })
if owner then setOwner(owner) end
toast(added .. " added" .. (skipped > 0 and (", " .. skipped .. " duplicate(s) skipped") or "") .. (owner and (". Team owner: " .. owner) or ""), true)
persist(); buildRows(added > 0 and (before + 1) or nil)
end)
end
v.moreB.setOnClickListener(View.OnClickListener({ onClick = function()
pickerStay("More Options", { "Add Players", "Copy Full Squad (all players)", "Team Owner (set / change)", "Choose Match", "Schedule (paste / view)", "Clear Playing (untick all)" }, function(i)
if i == 1 then
addPlayersDialog()
elseif i == 2 then
copy(fullSquadText(rec, players))
elseif i == 3 then
promptInput("Team Owner", rec.owner or "", "Owner name", function(n) setOwner(n); toast("Team owner saved.") end)
elseif i == 4 then
chooseMatch()
elseif i == 5 then
showSchedule(rec.tournament, rec.team, function() chosen = pickDefaultMatch(rec.tournament, rec.team); refreshRows() end)
else
for k = 1, #players do applyTick(players, k, false) end
persist(); refreshRows()
end
end)
end}))
wireNav(v, d)
end
local function showNewTeam(refresh)
local names, seen = {}, {}
for _, r in ipairs(loadSquads(nil)) do
if not seen[r.tournament] then seen[r.tournament] = true; names[#names + 1] = r.tournament end
end
local function form(tournament)
local fields = {}
if not tournament then fields[#fields + 1] = { id = "t", hint = "Tournament name" } end
fields[#fields + 1] = { id = "m", hint = "Your team name" }
fields[#fields + 1] = { id = "p", hint = "Players (one per line, optional)", multi = true, paste = true }
formDialog(tournament and ("New Team - " .. tournament) or "New Team", fields, function(x)
local tn = tournament or x.t
if tn == "" or x.m == "" then toast("Enter the tournament name and the team name.") return end
local list = {}
local _, _, ownerName = addParsed(list, x.p, { x.m, tn })
run("INSERT INTO squads (tournament, team, squad_text, opponents, owner) VALUES (?,?,?,?,?)",
tn, x.m, table.concat(list, "\n"), "", ownerName or "")
toast("Team added: " .. x.m .. " (" .. #list .. " players).", true)
refresh()
end)
end
if #names == 0 then form(nil) return end
local items = {}
for i, n in ipairs(names) do items[i] = n end
items[#items + 1] = "+ New tournament name"
listDialog("Tournament", items, function(p)
if p + 1 > #names then form(nil) else form(names[p + 1]) end
end)
end
local function teamMenu(rec, refresh)
listDialog(rec.team, { "Rename Team", "Rename Tournament (all its teams)", "Clone Team", "Delete Team", "Delete Tournament (all teams + schedule)" }, function(p)
if p == 0 then
promptInput("Rename Team", rec.team, "Team name", function(n)
run("UPDATE squads SET team=? WHERE rowid=?", n, rec.id)
run("UPDATE squad_matches SET team1=? WHERE tournament=? AND team1=?", n, rec.tournament, rec.team)
run("UPDATE squad_matches SET team2=? WHERE tournament=? AND team2=?", n, rec.tournament, rec.team)
refresh()
end)
elseif p == 1 then
promptInput("Rename Tournament", rec.tournament, "Tournament name", function(n)
run("UPDATE squads SET tournament=? WHERE tournament=?", n, rec.tournament)
run("UPDATE squad_matches SET tournament=? WHERE tournament=?", n, rec.tournament)
refresh()
end)
elseif p == 2 then
run("INSERT INTO squads (tournament, team, squad_text, opponents, owner) VALUES (?,?,?,?,?)", rec.tournament, rec.team .. " (Copy)", rec.text, rec.opponents, rec.owner or "")
refresh(); toast("Team cloned.")
elseif p == 3 then
confirmDialog("Delete Team", "Delete " .. rec.team .. "? This cannot be undone.", "Yes, Delete", function()
run("DELETE FROM squads WHERE rowid=?", rec.id); refresh()
end)
else
confirmDialog("Delete Tournament", "Delete \"" .. rec.tournament .. "\" with ALL its teams and its schedule? This cannot be undone.", "Yes, Delete", function()
run("DELETE FROM squads WHERE tournament=?", rec.tournament)
run("DELETE FROM squad_matches WHERE tournament=?", rec.tournament)
refresh()
end)
end
end)
end
local function showSquadManager()
listManager("Squad Manager", nil, false,
{{ text = "Add Team", onClick = function(load) showNewTeam(load) end },
{ text = "Backup: Import or Export ALL teams", onClick = function() showBackup("Squads", { "SQ", "SM" }) end },
{ text = "Backup: Export ONE tournament only", onClick = function()
local names, seen = {}, {}
for _, r in ipairs(query("SELECT tournament FROM squads ORDER BY rowid DESC")) do
if not seen[r[1]] then seen[r[1]] = true; names[#names + 1] = r[1] end
end
if #names == 0 then toast("No tournaments yet.") return end
listDialog("Export which tournament?", names, function(p)
exportBackup("Tournament_" .. safeName(names[p + 1]), { "SQ", "SM" }, { tournament = names[p + 1] })
end)
end },
{ text = "Delete ALL teams (cannot be undone)", onClick = function(load)
confirmDialog("Delete All Teams", "Delete ALL teams with their schedules? This cannot be undone.", "Yes, Delete All", function()
run("DELETE FROM squads"); run("DELETE FROM squad_matches"); load(); toast("Everything deleted.")
end)
end }},
function()
local list, recs, items, cache = loadSquads(nil), {}, {}, {}
table.sort(list, function(x, y)
if x.tournament ~= y.tournament then return x.tournament < y.tournament end
return x.id < y.id
end)
for _, rec in ipairs(list) do
cache[rec.tournament] = cache[rec.tournament] or loadMatches(rec.tournament)
local mh = matchHeader(rec.tournament, rec.team, cache[rec.tournament])
local all, sel = parseLines(rec.text), 0
for _, l in ipairs(all) do
if isPlaying(l) then sel = sel + 1 end
end
recs[#recs + 1] = rec
items[#items + 1] = rec.team .. " (" .. rec.tournament .. ") - " .. #all .. " players, " .. sel .. " selected" .. (mh ~= "" and ("\n" .. mh) or "")
end
return recs, items
end,
nil,
function(rec, refresh) showSquad(rec, refresh) end,
function(rec, refresh) teamMenu(rec, refresh) end)
end
local ROOM = "(status IS NULL OR status NOT IN ('sold','passed'))"
local function getPlayers(a, cond)
return query("SELECT id, player_name, base_price, status, sold_to_team, sold_price, sold_price2 FROM auction_players WHERE auction_id=" .. a.id .. " AND " .. cond .. " ORDER BY id")
end
local function byPrice(x, y)
local x1, y1 = tonumber(x[6]) or 0, tonumber(y[6]) or 0
if x1 ~= y1 then return x1 > y1 end
return (tonumber(x[7]) or 0) > (tonumber(y[7]) or 0)
end
local function teamLeft(a, t)
local s = t[3] .. " " .. a.cur
if a.cur2 ~= "" then s = s .. " | " .. ((tonumber(t[4]) == -1) and "Unlimited" or t[4]) .. " " .. a.cur2 end
return s
end
local function priceText(a, p1, p2)
local a1, a2 = tonumber(p1) or 0, tonumber(p2) or 0
if a1 > 0 and a2 > 0 then return p1 .. " " .. a.cur .. " + " .. p2 .. " " .. a.cur2 end
if a2 > 0 then return p2 .. " " .. a.cur2 end
if a1 <= 0 then return "Favorite" end
return p1 .. " " .. a.cur
end
local function settingsText(a)
local s = "Primary: " .. a.cur
if a.cur2 ~= "" then
s = s .. " | Secondary: " .. a.cur2 .. (a.coins2 == -1 and " (Unlimited)" or " (Limited)") ..
" | Secondary currency: " .. (a.fallback and "secondary allowed" or "secondary blocked")
end
return s .. (a.max > 0 and (" | Max/team: " .. a.max) or "")
end
local function refund(a, r)
for _, t in ipairs(query("SELECT id, team_name, coins_remaining2 FROM auction_teams WHERE auction_id=" .. a.id)) do
if t[2] == r[5] then
local p1, p2 = tonumber(r[6]) or 0, tonumber(r[7]) or 0
if p1 > 0 then run("UPDATE auction_teams SET coins_remaining = coins_remaining + ? WHERE id=?", p1, tonumber(t[1])) end
if p2 > 0 and tonumber(t[3]) ~= -1 then run("UPDATE auction_teams SET coins_remaining2 = coins_remaining2 + ? WHERE id=?", p2, tonumber(t[1])) end
break
end
end
end
local function setStatus(a, r, status, onDone)
if r[4] == "sold" then refund(a, r) end
run("UPDATE auction_players SET status=?, sold_to_team='', sold_price=0, sold_price2=0 WHERE id=?", status, tonumber(r[1]))
toast(playerName(r[2]) .. (status == "passed" and " moved to the Unsold list." or " is back in the room."))
if onDone then onDone() end
end
local function leadRoles(role)
if role:find("Team Owner", 1, true) then return true, role:match("/%s*(.+)$") or "" end
return false, LEADS[role] and role or ""
end
local function buildRole(owner, lead)
if owner then return (lead == "") and "Team Owner" or ("Team Owner / " .. lead) end
return (lead == "Player") and "" or lead
end
local function rowRole(r)
local _, role = splitPlayer(r[2])
return leadRoles(role)
end
local function isFavRow(r) return (tonumber(r[6]) or 0) <= 0 and (tonumber(r[7]) or 0) <= 0 end
local function warnThen(msg, again)
local d = LuaDialog()
d.setTitle("Cannot sell"); d.setMessage(msg)
d.setButton("OK", DialogInterface.OnClickListener({ onClick = function() again() end }))
d.show()
end
local function maxBid(a, n, left1)
if a.max <= 0 then return left1 end
local slots = a.max - n
if slots <= 0 then return 0 end
return math.max(0, left1 - (slots - 1) * a.base)
end
local function sellFlow(a, r, onDone, presetTeam)
local teams = query("SELECT id, team_name, coins_remaining, coins_remaining2 FROM auction_teams WHERE auction_id=" .. a.id .. " ORDER BY id")
if #teams == 0 then toast("Add a team first.") return end
local wasSold = (r[4] == "sold")
local cnt = {}
for _, p in ipairs(getPlayers(a, "status='sold'")) do
if p[1] ~= r[1] and not isFavRow(p) then cnt[p[5]] = (cnt[p[5]] or 0) + 1 end
end
local eff = {}
for i, t in ipairs(teams) do
local l1, l2 = tonumber(t[3]) or 0, tonumber(t[4])
if wasSold and t[2] == r[5] then
l1 = l1 + (tonumber(r[6]) or 0)
if l2 and l2 ~= -1 then l2 = l2 + (tonumber(r[7]) or 0) end
end
eff[i] = { l1, l2 }
end
local function proceed(i)
local t, e = teams[i], eff[i]
local n = cnt[t[2]] or 0
local base = tonumber(r[3]) or 0
local function commit(p1, p2)
if wasSold then refund(a, r) end
run("UPDATE auction_players SET status='sold', sold_to_team=?, sold_price=?, sold_price2=? WHERE id=?", t[2], p1, p2, tonumber(r[1]))
if p1 > 0 then run("UPDATE auction_teams SET coins_remaining = coins_remaining - ? WHERE id=?", p1, tonumber(t[1])) end
if p2 > 0 and e[2] ~= -1 then run("UPDATE auction_teams SET coins_remaining2 = coins_remaining2 - ? WHERE id=?", p2, tonumber(t[1])) end
a.lastSale = tonumber(r[1])
toast(playerName(r[2]) .. " sold to " .. t[2] .. " for " .. priceText(a, tostring(p1), tostring(p2)) .. ".", true)
if onDone then onDone() end
end
local function limitReached()
if a.max > 0 and n >= a.max then
toast(t[2] .. " already has " .. a.max .. " players (limit reached).", true)
return true
end
return false
end
local function oldPrice(second)
if wasSold then
local old = tonumber(second and r[7] or r[6]) or 0
if old > 0 then return tostring(old) end
end
return nil
end
local function askOne(second, prefill)
local cur = second and a.cur2 or a.cur
promptInput("Sold Price in " .. cur, prefill or oldPrice(second) or r[3], "Price in " .. cur, function(s)
local price = math.floor(tonumber(s) or 0)
local function bad(msg) warnThen(msg, function() askOne(second, s) end) end
if price < base then bad("The price must be at least the base price (" .. base .. " " .. cur .. ").") return end
if limitReached() then return end
if second then
if e[2] and (e[2] == -1 or price <= e[2]) then
commit(0, price)
else
bad(t[2] .. " has only " .. (e[2] or 0) .. " " .. a.cur2 .. " left, but the price is " .. price .. " " .. a.cur2 .. ".")
end
return
end
if price <= e[1] then
local mb = maxBid(a, n, e[1])
if a.max > 0 and price > mb then
if a.cur2 == "" then
bad(t[2] .. " must keep the base price (" .. a.base .. ") for each remaining slot. Max bid: " .. mb .. " " .. a.cur .. ".")
else
confirmDialog("Budget Warning", t[2] .. " would not have enough left to fill its remaining slots at base price. Max safe bid: " .. mb .. " " .. a.cur .. ". Sell anyway?", "Sell Anyway", function() commit(price, 0) end)
end
else
commit(price, 0)
end
elseif a.fallback and a.cur2 ~= "" and e[2] and (e[2] == -1 or price <= e[2]) then
confirmDialog("Primary Not Enough", t[2] .. " has only " .. e[1] .. " " .. a.cur .. ". Pay " .. price .. " " .. a.cur2 .. " from the secondary wallet?", "Yes, Pay", function() commit(0, price) end)
else
bad(t[2] .. " cannot afford " .. price .. " " .. a.cur .. " (left: " .. e[1] .. " " .. a.cur .. ")" ..
((a.cur2 ~= "" and not a.fallback) and ". The secondary currency is not allowed in this auction." or "."))
end
end, true)
end
local function askBoth(pa, pb)
formDialog("Sold Price - both currencies", {
{ id = "a", hint = "Price in " .. a.cur, num = true, text = pa or oldPrice(false) or r[3] },
{ id = "b", hint = "Price in " .. a.cur2, num = true, text = pb or oldPrice(true) } }, function(x)
local p1, p2 = math.floor(tonumber(x.a) or 0), math.floor(tonumber(x.b) or 0)
local msgs = {}
if p1 <= 0 then msgs[#msgs + 1] = "Enter an amount in " .. a.cur .. "." end
if p2 <= 0 then msgs[#msgs + 1] = "Enter an amount in " .. a.cur2 .. "." end
if p1 > 0 and p1 < base then msgs[#msgs + 1] = "The " .. a.cur .. " amount must be at least the base price (" .. base .. ")." end
if p1 > e[1] then msgs[#msgs + 1] = t[2] .. " has only " .. e[1] .. " " .. a.cur .. " left, but you entered " .. p1 .. "." end
if p2 > 0 and not (e[2] and (e[2] == -1 or p2 <= e[2])) then
msgs[#msgs + 1] = t[2] .. " has only " .. (e[2] or 0) .. " " .. a.cur2 .. " left, but you entered " .. p2 .. "."
end
if #msgs > 0 then warnThen(table.concat(msgs, "\n"), function() askBoth(x.a, x.b) end) return end
if limitReached() then return end
commit(p1, p2)
end)
end
if a.cur2 ~= "" and a.fallback then
listDialog("Pay with", { a.cur .. " (primary)", a.cur2 .. " (secondary)", "Both currencies together" }, function(p)
if p == 2 then askBoth() else askOne(p == 1) end
end)
else
askOne(false)
end
end
if presetTeam then
for i, t in ipairs(teams) do
if t[2] == presetTeam then proceed(i) return end
end
return
end
local labels = {}
for i, t in ipairs(teams) do
labels[i] = t[2] .. " (left " .. teamLeft(a, { t[1], t[2], tostring(eff[i][1]), tostring(eff[i][2] or "") }) .. ")" ..
((a.max > 0) and (" | max bid " .. maxBid(a, cnt[t[2]] or 0, eff[i][1])) or "") ..
((wasSold and t[2] == r[5]) and " [current]" or "")
end
if r[4] ~= "passed" then labels[#labels + 1] = "Unsold (nobody buys)" end
listDialog((wasSold and "Move " or "Sell ") .. r[2] .. " to", labels, function(p)
if p + 1 > #teams then setStatus(a, r, "passed", onDone) else proceed(p + 1) end
end)
end
local function addPlayers(a, status, onDone)
formDialog("Add Players", {{ id = "p", hint = "Names - paste any list, it is cleaned automatically", multi = true, paste = true }}, function(x)
local existing, added, skipped = {}, 0, 0
for _, p in ipairs(query("SELECT player_name FROM auction_players WHERE auction_id=" .. a.id)) do existing[playerName(p[1]):lower()] = true end
for _, n in ipairs((parsePlayerText(x.p, { a.name }))) do
local k = n:lower()
if existing[k] then
skipped = skipped + 1
else
existing[k] = true; added = added + 1
run("INSERT INTO auction_players (auction_id, player_name, base_price, status, sold_to_team, sold_price, sold_price2) VALUES (?,?,?,?,'',0,0)", a.id, n, a.base, status)
end
end
toast(added .. " added" .. (skipped > 0 and (", " .. skipped .. " duplicate(s) skipped") or ""))
onDone()
end)
end
local function playerMenu(a, r, onDone)
local st = (r[4] == "sold") and "sold" or ((r[4] == "passed") and "passed" or "room")
local labels, acts = {}, {}
local function add(l, f) labels[#labels + 1] = l; acts[#acts + 1] = f end
add(st == "sold" and "Change Team / Price" or "Sell to a Team", function() sellFlow(a, r, onDone) end)
if st ~= "room" then add("Back to Room", function() setStatus(a, r, "unsold", onDone) end) end
if st ~= "passed" then add("Mark Unsold", function() setStatus(a, r, "passed", onDone) end) end
if st ~= "sold" then
add("Change Base Price", function()
promptInput("Base Price", r[3], "Price", function(s)
local b = tonumber(s)
if not b then toast("Enter a valid number.") return end
run("UPDATE auction_players SET base_price=? WHERE id=?", math.floor(b), tonumber(r[1]))
onDone()
end, true)
end)
end
add("Set Role (Batsman / Bowler / All-Rounder / WK)", function()
listDialog("Role", playerRoles, function(p2)
run("UPDATE auction_players SET player_name=? WHERE id=?", joinPlayer(playerName(r[2]), playerRoles[p2 + 1]), tonumber(r[1]))
onDone()
end)
end)
add("Rename", function()
promptInput("Rename Player", r[2], "Name", function(n)
run("UPDATE auction_players SET player_name=? WHERE id=?", n, tonumber(r[1])); onDone()
end)
end)
add("Delete", function()
confirmDialog("Delete Player", "Remove " .. r[2] .. "?" .. (st == "sold" and " The price is refunded to the team." or ""), "Yes, Delete", function()
if st == "sold" then refund(a, r) end
run("DELETE FROM auction_players WHERE id=?", tonumber(r[1]))
onDone()
end)
end)
listDialog(r[2], labels, function(p) acts[p + 1]() end)
end
local function fixedNumbers(a)
local m = {}
for i, r in ipairs(query("SELECT id FROM auction_players WHERE auction_id=" .. a.id .. " ORDER BY id")) do m[r[1]] = i end
return m
end
local function playerLoader(a, cond, search)
local recs, items = {}, {}
local fixed = (getSetting("renumber", "1") == "0") and fixedNumbers(a) or nil
local q = search:lower()
for pos, r in ipairs(getPlayers(a, cond)) do
local num = (fixed and fixed[r[1]]) or pos
if q == "" or tostring(num) == q or r[2]:lower():find(q, 1, true) then
recs[#recs + 1] = r
items[#items + 1] = num .. ". " .. r[2] .. " - Base " .. r[3]
end
end
return recs, items
end
local function numberingMenu(load)
local fixed = getSetting("renumber", "1") == "0"
listDialog("Player numbers - now: " .. (fixed and "KEEP FIXED NUMBERS" or "RENUMBER after each sale"),
{ "Renumber after each sale (1, 2, 3 ...)", "Keep fixed numbers (a sold player's number stays gone)" }, function(p)
setSetting("renumber", p == 0 and "1" or "0")
toast(p == 0 and "Players are renumbered after each sale." or "Players keep their fixed numbers.")
load()
end)
end
local function auctionCounts(a)
local c = { room = 0, sold = 0, unsold = 0, teams = #query("SELECT 1 FROM auction_teams WHERE auction_id=" .. a.id) }
for _, r in ipairs(query("SELECT status, COUNT(*) FROM auction_players WHERE auction_id=" .. a.id .. " GROUP BY status")) do
local n = tonumber(r[2]) or 0
if r[1] == "sold" then c.sold = c.sold + n elseif r[1] == "passed" then c.unsold = c.unsold + n else c.room = c.room + n end
end
return c
end
local function poolLine(a)
local c = auctionCounts(a)
return "Pool: " .. (c.room + c.sold + c.unsold) .. " total  |  Sold: " .. c.sold .. "  |  Remaining: " .. c.room .. "  |  Unsold: " .. c.unsold .. "  |  Teams: " .. c.teams
end
local function playersText(a, title, list, noPrice)
local out = { a.name .. " - " .. title .. " (" .. #list .. ")" }
for i, r in ipairs(list) do out[#out + 1] = i .. ". " .. r[2] .. (noPrice and "" or (" - Base " .. r[3])) end
return table.concat(out, "\n")
end
local function roleLine(list)
local c, none, parts = {}, 0, {}
for _, r in ipairs(list) do
local _, role = splitPlayer(r[2])
if role ~= "" then c[role] = (c[role] or 0) + 1 else none = none + 1 end
end
for _, role in ipairs(playerRoles) do
if c[role] then parts[#parts + 1] = role .. " " .. c[role] end
end
if none > 0 then parts[#parts + 1] = "No role " .. none end
return table.concat(parts, " | ")
end
local function teamOrdered(a, name)
local t = { rows = {}, favs = {}, picks = {}, pickCount = 0, s1 = 0, s2 = 0 }
for _, r in ipairs(getPlayers(a, "status='sold'")) do
if r[5] == name then
t.rows[#t.rows + 1] = r
t.s1 = t.s1 + (tonumber(r[6]) or 0); t.s2 = t.s2 + (tonumber(r[7]) or 0)
local o, lead = rowRole(r)
if o and not t.owner then t.owner = r end
if lead == "Captain" and not t.cap then t.cap = r
elseif lead == "Vice Captain" and not t.vice then t.vice = r
elseif lead == "Second Vice Captain" and not t.svc then t.svc = r end
if not isFavRow(r) then t.pickCount = t.pickCount + 1 end
end
end
for _, r in ipairs(t.rows) do
if r ~= t.owner and r ~= t.cap and r ~= t.vice and r ~= t.svc then
if isFavRow(r) then t.favs[#t.favs + 1] = r else t.picks[#t.picks + 1] = r end
end
end
return t
end
local function leaderEntries(t)
local out = {}
if t.owner then
local _, lead = rowRole(t.owner)
out[#out + 1] = { row = t.owner, text = "Team Owner: " .. playerName(t.owner[2]) .. (lead == "" and "" or (" (plays as " .. lead .. ")")) }
end
if t.cap then out[#out + 1] = { row = t.cap, text = "Captain: " .. playerName(t.cap[2]) } end
if t.vice then out[#out + 1] = { row = t.vice, text = "Vice Captain: " .. playerName(t.vice[2]) } end
if t.svc then out[#out + 1] = { row = t.svc, text = "Second Vice Captain: " .. playerName(t.svc[2]) } end
for _, r in ipairs(t.favs) do out[#out + 1] = { row = r, text = "Favorite Player: " .. playerName(r[2]) } end
return out
end
local function teamInfo(a, name)
local t = teamOrdered(a, name)
local left1, left2 = "0", "0"
for _, q in ipairs(query("SELECT team_name, coins_remaining, coins_remaining2 FROM auction_teams WHERE auction_id=" .. a.id)) do
if q[1] == name then left1, left2 = q[2], q[3] end
end
local s = "Used: " .. t.s1 .. " " .. a.cur .. " | Left: " .. left1 .. " " .. a.cur
if a.cur2 ~= "" then
s = s .. "  ||  Used: " .. t.s2 .. " " .. a.cur2 .. " | Left: " .. ((tonumber(left2) == -1) and "Unlimited" or left2) .. " " .. a.cur2
end
s = s .. "  ||  Players: " .. t.pickCount .. (a.max > 0 and ("/" .. a.max) or "")
if a.max > 0 then s = s .. " | Max bid: " .. maxBid(a, t.pickCount, tonumber(left1) or 0) end
local rl = roleLine(t.picks)
return s .. ((#t.picks > 0 and rl ~= "") and ("\nRoles: " .. rl) or "")
end
local function teamText(a, name, noPrice)
local t = teamOrdered(a, name)
local left1, left2 = "0", "0"
for _, q in ipairs(query("SELECT team_name, coins_remaining, coins_remaining2 FROM auction_teams WHERE auction_id=" .. a.id)) do
if q[1] == name then left1, left2 = q[2], q[3] end
end
local out = { name }
if not noPrice then
out[#out + 1] = "Budget: " .. a.coins .. " " .. a.cur
out[#out + 1] = "Used: " .. t.s1 .. " " .. a.cur
out[#out + 1] = "Remaining: " .. left1 .. " " .. a.cur
if a.cur2 ~= "" then
out[#out + 1] = "Secondary Budget: " .. (a.coins2 == -1 and "Unlimited" or (a.coins2 .. " " .. a.cur2))
out[#out + 1] = "Secondary Used: " .. t.s2 .. " " .. a.cur2
if a.coins2 ~= -1 then out[#out + 1] = "Secondary Remaining: " .. left2 .. " " .. a.cur2 end
end
end
out[#out + 1] = "Players Picked: " .. t.pickCount .. (a.max > 0 and (" / " .. a.max) or "")
if a.max > 0 then
out[#out + 1] = "Slots Left: " .. math.max(0, a.max - t.pickCount)
if not noPrice then out[#out + 1] = "Max Bid: " .. maxBid(a, t.pickCount, tonumber(left1) or 0) .. " " .. a.cur end
end
for _, e in ipairs(leaderEntries(t)) do out[#out + 1] = e.text end
local rl = roleLine(t.picks)
if #t.picks > 0 and rl ~= "" then out[#out + 1] = "Roles: " .. rl end
for i, r in ipairs(t.picks) do
out[#out + 1] = "Pick " .. i .. ". " .. r[2] .. (noPrice and "" or (" - " .. priceText(a, r[6], r[7])))
end
if #t.rows == 0 then out[#out + 1] = "No players yet." end
return table.concat(out, "\n")
end
local function allTeamsText(a, noPrice)
local out = { a.name .. " - Teams" }
for _, t in ipairs(query("SELECT team_name FROM auction_teams WHERE auction_id=" .. a.id .. " ORDER BY id")) do
out[#out + 1] = "\n" .. teamText(a, t[1], noPrice)
end
return table.concat(out, "\n")
end
local function resultsText(a, noPrice)
local out = { a.name .. " - Results" }
if not noPrice then out[#out + 1] = settingsText(a) end
for _, t in ipairs(query("SELECT team_name FROM auction_teams WHERE auction_id=" .. a.id .. " ORDER BY id")) do
out[#out + 1] = "\n" .. teamText(a, t[1], noPrice)
end
local un, room = {}, {}
for _, r in ipairs(getPlayers(a, "status='passed'")) do un[#un + 1] = r[2] end
for _, r in ipairs(getPlayers(a, ROOM)) do room[#room + 1] = r[2] end
if #un > 0 then out[#out + 1] = "\nUnsold: " .. table.concat(un, ", ") end
if #room > 0 then out[#out + 1] = "\nStill in room: " .. table.concat(room, ", ") end
return table.concat(out, "\n")
end
local function kindLabel(c) return (c == "Coins") and "Coins (Virtual)" or (c .. " (Real Money)") end
local function topBuysText(a, second, n)
local list = {}
for _, r in ipairs(getPlayers(a, "status='sold'")) do
local p1, p2 = tonumber(r[6]) or 0, tonumber(r[7]) or 0
if second then
if p2 > 0 then list[#list + 1] = { r[2], r[5], p2 } end
elseif p1 > 0 then
list[#list + 1] = { r[2], r[5], p1 }
end
end
table.sort(list, function(x, y) return x[3] > y[3] end)
local cur, top = second and a.cur2 or a.cur, math.min(n, #list)
local out = { a.name .. " - Top " .. top .. " Buys - " .. kindLabel(cur) }
for i = 1, top do out[#out + 1] = i .. ". " .. list[i][1] .. " - " .. list[i][3] .. " " .. cur .. " (" .. list[i][2] .. ")" end
if #list == 0 then out[#out + 1] = "No players sold in " .. cur .. " yet." end
return table.concat(out, "\n")
end
local function showTopBuys(a)
local function pickCount(which)
local counts, labels = { 3, 5, 10, 15, 20 }, {}
for i, n in ipairs(counts) do labels[i] = "Top " .. n end
pickerStay("How many? (tap to copy)", labels, function(i)
local n = counts[i]
if which == 3 then copy(topBuysText(a, false, n) .. "\n\n" .. topBuysText(a, true, n))
else copy(topBuysText(a, which == 2, n)) end
end)
end
if a.cur2 == "" then pickCount(1) return end
listDialog("Top Buys - which currency?", { kindLabel(a.cur), kindLabel(a.cur2), "Both (two separate lists)" }, function(p) pickCount(p + 1) end)
end
local function showRoom(a, onClose)
listManager("Auction Room", nil, true,
{{ text = "Pick Random Player", onClick = function(load)
local pool = getPlayers(a, ROOM)
if #pool == 0 then toast("The room is empty.") return end
local r = pool[math.random(#pool)]
listDialog(r[2] .. " (Base " .. r[3] .. ")", { "Sell to a Team", "Mark Unsold" }, function(p)
if p == 0 then sellFlow(a, r, load) else setStatus(a, r, "passed", load) end
end)
end },
{ text = "Undo Last Sale", onClick = function(load)
local r = a.lastSale and query("SELECT id, player_name, base_price, status, sold_to_team, sold_price, sold_price2 FROM auction_players WHERE id=" .. a.lastSale)[1]
a.lastSale = nil
if r and r[4] == "sold" then setStatus(a, r, "unsold", load); toast(r[2] .. " is back in the room.") else toast("No sale to undo.") end
end },
{ text = "Copy Remaining Players - with base price", onClick = function() copy(playersText(a, "Remaining Players", getPlayers(a, ROOM))) end },
{ text = "Copy Remaining Players - names only", onClick = function() copy(playersText(a, "Remaining Players", getPlayers(a, ROOM), true)) end },
{ text = "Player Numbering (renumber or keep fixed)", onClick = function(load) numberingMenu(load) end }},
function(search) return playerLoader(a, ROOM, search) end,
nil,
function(r, load) sellFlow(a, r, load) end,
function(r, load) playerMenu(a, r, load) end,
onClose,
function() return playersText(a, "Remaining Players", getPlayers(a, ROOM)) end,
function() return poolLine(a) end)
end
local function showUnsoldList(a, onClose)
listManager("Unsold Players", nil, true,
{{ text = "Move All Back to Room", onClick = function(load)
run("UPDATE auction_players SET status='unsold' WHERE auction_id=? AND status='passed'", a.id)
load()
end },
{ text = "Copy Unsold Players - with base price", onClick = function() copy(playersText(a, "Unsold Players", getPlayers(a, "status='passed'"))) end },
{ text = "Copy Unsold Players - names only", onClick = function() copy(playersText(a, "Unsold Players", getPlayers(a, "status='passed'"), true)) end },
{ text = "Player Numbering (renumber or keep fixed)", onClick = function(load) numberingMenu(load) end }},
function(search) return playerLoader(a, "status='passed'", search) end,
nil,
function(r, load) playerMenu(a, r, load) end,
function(r, load) playerMenu(a, r, load) end,
onClose,
function() return playersText(a, "Unsold Players", getPlayers(a, "status='passed'")) end,
function() return poolLine(a) end)
end
local FAV_ROLES = { "Player", "Captain", "Vice Captain", "Second Vice Captain", "Team Owner" }
local function addFavoritePlayer(a, teamName, onDone)
local function finish(row, typed, owner, lead)
for _, r in ipairs(getPlayers(a, "status='sold'")) do
if r[5] == teamName then
local o, l = rowRole(r)
if owner and o and l == "" then
run("UPDATE auction_players SET player_name=?, status='unsold', sold_to_team='', sold_price=0, sold_price2=0 WHERE id=?", playerName(r[2]), tonumber(r[1]))
else
local newO, newL = o, l
if owner and o then newO = false end
if LEADS[lead] and l == lead then newL = o and "Player" or "" end
if newO ~= o or newL ~= l then
run("UPDATE auction_players SET player_name=? WHERE id=?", joinPlayer(playerName(r[2]), buildRole(newO, newL)), tonumber(r[1]))
end
end
end
end
local role = buildRole(owner, lead)
local shown
if row then
local final = (role == "") and row[2] or joinPlayer(playerName(row[2]), role)
run("UPDATE auction_players SET player_name=?, status='sold', sold_to_team=?, sold_price=0, sold_price2=0 WHERE id=?", final, teamName, tonumber(row[1]))
shown = playerName(row[2])
else
run("INSERT INTO auction_players (auction_id, player_name, base_price, status, sold_to_team, sold_price, sold_price2) VALUES (?,?,?,'sold',?,0,0)",
a.id, joinPlayer(typed, role), a.base, teamName)
shown = typed
end
toast(shown .. " added to " .. teamName .. (role ~= "" and (" as " .. role) or "") .. ".", true)
if onDone then onDone() end
end
local function askRole(row, typed)
listDialog("Role of the player", FAV_ROLES, function(p)
local r = FAV_ROLES[p + 1]
if r == "Team Owner" then
listDialog("Does the owner play?", { "No - owner only", "Yes - as Captain", "Yes - as Vice Captain", "Yes - as Second Vice Captain", "Yes - as Player" }, function(q)
finish(row, typed, true, ({ "", "Captain", "Vice Captain", "Second Vice Captain", "Player" })[q + 1])
end)
else
finish(row, typed, false, r)
end
end)
end
listDialog("Add Favorite Player", { "Type a name", "Pick from the player list" }, function(p)
if p == 0 then
promptInput("Favorite Player Name", nil, "Name", function(n)
local key = playerName(n):lower()
for _, r in ipairs(query("SELECT player_name FROM auction_players WHERE auction_id=" .. a.id)) do
if playerName(r[1]):lower() == key then toast("That player is already in this auction.", true) return end
end
askRole(nil, n)
end)
else
local pool = getPlayers(a, "(status IS NULL OR status <> 'sold')")
if #pool == 0 then toast("The player list is empty. Type a name instead.", true) return end
local names = {}
for i, r in ipairs(pool) do names[i] = r[2] end
listDialog("Select Player", names, function(q) askRole(pool[q + 1], nil) end)
end
end)
end
local function showTeamPlayers(a, teamName, refreshParent)
listManager(teamName .. " - Players", nil, false,
{{ text = "Add Favorite Player", onClick = function(load) addFavoritePlayer(a, teamName, function() load(); refreshParent() end) end },
{ text = "Copy This Team - with price", onClick = function() copy(teamText(a, teamName)) end },
{ text = "Copy This Team - without price", onClick = function() copy(teamText(a, teamName, true)) end },
{ text = "Share Without Price", onClick = function() shareMenu(teamText(a, teamName, true)) end }},
function()
local t = teamOrdered(a, teamName)
local recs, items = {}, {}
for _, e in ipairs(leaderEntries(t)) do recs[#recs + 1] = e.row; items[#items + 1] = e.text end
for i, r in ipairs(t.picks) do
recs[#recs + 1] = r
items[#items + 1] = "Pick " .. i .. ". " .. r[2] .. " - " .. priceText(a, r[6], r[7])
end
return recs, items
end,
nil,
function(r, load) playerMenu(a, r, function() load(); refreshParent() end) end,
function(r, load) playerMenu(a, r, function() load(); refreshParent() end) end,
nil,
function() return teamText(a, teamName) end,
function() return teamInfo(a, teamName) end)
end
local function showTeamsScreen(a, onClose)
local extras = {}
local function add2(label, fn)
extras[#extras + 1] = { text = label .. " - with price", onClick = function() fn(false) end }
extras[#extras + 1] = { text = label .. " - without price", onClick = function() fn(true) end }
end
extras[1] = { text = "Add New Team", onClick = function(load)
promptInput("New Team", nil, "Team name", function(n)
run("INSERT INTO auction_teams (auction_id, team_name, coins_remaining, coins_remaining2) VALUES (?,?,?,?)", a.id, n, a.coins, a.cur2 ~= "" and a.coins2 or 0)
toast("Team added: " .. n)
load()
end)
end }
add2("Copy All Teams", function(np) copy(allTeamsText(a, np)) end)
add2("Copy Team By Team (one by one)", function(np)
local names = {}
for _, t in ipairs(query("SELECT team_name FROM auction_teams WHERE auction_id=" .. a.id .. " ORDER BY id")) do names[#names + 1] = t[1] end
if #names == 0 then toast("No teams yet.") return end
pickerStay("Tap a team to copy" .. (np and " (without price)" or " (with price)"), names, function(i) copy(teamText(a, names[i], np)) end)
end)
extras[#extras + 1] = { text = "Copy Top Buys (3 / 5 / 10 / 15 / 20)", onClick = function() showTopBuys(a) end }
extras[#extras + 1] = { text = "Share Full Results Without Price", onClick = function() shareMenu(resultsText(a, true)) end }
listManager("Teams", nil, false, extras,
function()
local recs, items = { { special = "unsold" } }, { ">> Unsold Players (" .. auctionCounts(a).unsold .. ")" }
local count, favc, used, used2 = {}, {}, {}, {}
for _, p in ipairs(getPlayers(a, "status='sold'")) do
if isFavRow(p) then favc[p[5]] = (favc[p[5]] or 0) + 1 else count[p[5]] = (count[p[5]] or 0) + 1 end
used[p[5]] = (used[p[5]] or 0) + (tonumber(p[6]) or 0)
used2[p[5]] = (used2[p[5]] or 0) + (tonumber(p[7]) or 0)
end
for _, t in ipairs(query("SELECT id, team_name, coins_remaining, coins_remaining2 FROM auction_teams WHERE auction_id=" .. a.id .. " ORDER BY id")) do
recs[#recs + 1] = { id = tonumber(t[1]), name = t[2] }
items[#items + 1] = t[2] .. " - Used: " .. (used[t[2]] or 0) .. " " .. a.cur .. (a.cur2 ~= "" and (" + " .. (used2[t[2]] or 0) .. " " .. a.cur2) or "") ..
" | Left: " .. teamLeft(a, t) .. (a.max > 0 and (" | Max bid: " .. maxBid(a, count[t[2]] or 0, tonumber(t[3]) or 0)) or "") ..
" - " .. (count[t[2]] or 0) .. " pick(s)" .. ((favc[t[2]] or 0) > 0 and (", " .. favc[t[2]] .. " favorite(s)") or "")
end
return recs, items
end,
nil,
function(rec, load)
if rec.special then showUnsoldList(a, load) else showTeamPlayers(a, rec.name, load) end
end,
function(rec, load)
if rec.special then return end
listDialog(rec.name, { "Add Favorite Player", "Rename Team", "Delete Team" }, function(p)
if p == 0 then
addFavoritePlayer(a, rec.name, load)
elseif p == 1 then
promptInput("Rename Team", rec.name, "Team name", function(n)
run("UPDATE auction_teams SET team_name=? WHERE id=?", n, rec.id)
run("UPDATE auction_players SET sold_to_team=? WHERE auction_id=? AND sold_to_team=?", n, a.id, rec.name)
load()
end)
else
for _, pl in ipairs(getPlayers(a, "status='sold'")) do
if pl[5] == rec.name then toast("Move this team's players out first.", true) return end
end
confirmDialog("Delete Team", "Delete " .. rec.name .. "?", "Yes, Delete", function()
run("DELETE FROM auction_teams WHERE id=?", rec.id); load()
end)
end
end)
end,
onClose,
function() return resultsText(a) end)
end
local function rankingText(a)
local sold = getPlayers(a, "status='sold'")
local out = { a.name .. " - Rankings", "", topBuysText(a, false, 10) }
if a.cur2 ~= "" then out[#out + 1] = ""; out[#out + 1] = topBuysText(a, true, 10) end
local rows = {}
for _, t in ipairs(query("SELECT team_name, coins_remaining, coins_remaining2 FROM auction_teams WHERE auction_id=" .. a.id .. " ORDER BY id")) do
local row = { name = t[1], s1 = 0, s2 = 0, n = 0, left = teamLeft(a, { 0, t[1], t[2], t[3] }) }
for _, p in ipairs(sold) do
if p[5] == t[1] then row.n = row.n + 1; row.s1 = row.s1 + (tonumber(p[6]) or 0); row.s2 = row.s2 + (tonumber(p[7]) or 0) end
end
rows[#rows + 1] = row
end
table.sort(rows, function(x, y) if x.s1 ~= y.s1 then return x.s1 > y.s1 end return x.s2 > y.s2 end)
out[#out + 1] = "\nTeams by Spending:"
for i, r in ipairs(rows) do
out[#out + 1] = i .. ". " .. r.name .. " - spent " .. r.s1 .. " " .. a.cur .. (a.cur2 ~= "" and (" + " .. r.s2 .. " " .. a.cur2) or "") ..
" - " .. r.n .. " player(s) - left " .. r.left
end
return table.concat(out, "\n")
end
local function showAuction(a, onClose)
local d = LuaDialog()
d.setTitle(a.name)
local v = {}
d.setView(loadlayout({ ScrollView; layout_width = "-1"; layout_height = "-1";
{ LinearLayout; orientation = "vertical"; padding = "16dp"; layout_width = "-1";
{ TextView; id = "info"; textSize = "12sp"; layout_width = "-1"; layout_marginBottom = "10dp" };
btn("roomB", "Auction Room (sell players)", "0xFF3F51B5", { layout_marginBottom = "8dp" });
btn("poolB", "Add Players to Pool", "0xFF1976D2", { layout_marginBottom = "8dp" });
btn("teamB", "Teams (budgets and players)", "0xFFFF6F00", { layout_marginBottom = "8dp" });
btn("setB", "Settings (name, base price, rankings, reset)", "0xFF455A64", { layout_marginBottom = "8dp" });
navBar();
};
}, v))
local function info() v.info.setText(settingsText(a) .. "\n" .. poolLine(a)) end
info()
d.show()
if onClose then
pcall(function() d.setOnDismissListener(DialogInterface.OnDismissListener({ onDismiss = function() if not closingAll then onClose() end end })) end)
end
v.roomB.setOnClickListener(View.OnClickListener({ onClick = function() showRoom(a, info) end }))
v.poolB.setOnClickListener(View.OnClickListener({ onClick = function() addPlayers(a, "unsold", info) end }))
v.teamB.setOnClickListener(View.OnClickListener({ onClick = function() showTeamsScreen(a, info) end }))
v.setB.setOnClickListener(View.OnClickListener({ onClick = function()
listDialog("Settings", { "Rename Auction", "Default Base Price (new players)", "Max Players per Team", "Rankings",
"Reset Auction (clear all sales)" }, function(p)
if p == 0 then
promptInput("Rename Auction", a.name, "Name", function(n)
run("UPDATE auctions SET name=? WHERE id=?", n, a.id); a.name = n
pcall(function() d.setTitle(n) end)
end)
elseif p == 1 then
promptInput("Default Base Price", tostring(a.base), "Price", function(s)
local b = tonumber(s)
if not b then toast("Enter a valid number.") return end
a.base = math.floor(b); run("UPDATE auctions SET default_base_price=? WHERE id=?", a.base, a.id); info()
end, true)
elseif p == 2 then
promptInput("Max Players per Team (0 = no limit)", tostring(a.max), "Number", function(s)
local m = tonumber(s)
if not m then toast("Enter a valid number.") return end
a.max = math.floor(m); run("UPDATE auctions SET max_players_per_team=? WHERE id=?", a.max, a.id); info()
end, true)
elseif p == 3 then
local text = rankingText(a)
local rd = LuaDialog()
rd.setTitle("Rankings"); rd.setMessage(text)
rd.setButton("Copy", DialogInterface.OnClickListener({ onClick = function() copy(text) end }))
rd.setButton2("Close", nil)
rd.show()
else
confirmDialog("Reset Auction", "All players go back to the room and every team's budget is restored. Continue?", "Yes, Reset", function()
run("UPDATE auction_players SET status='unsold', sold_to_team='', sold_price=0, sold_price2=0 WHERE auction_id=?", a.id)
run("UPDATE auction_teams SET coins_remaining=?, coins_remaining2=? WHERE auction_id=?", a.coins, a.cur2 ~= "" and a.coins2 or 0, a.id)
info(); toast("Auction reset.")
end)
end
end)
end}))
wireNav(v, d)
end
local function showAuctionManager()
listManager("Player Auction", "+ New Auction", false,
{{ text = "Backup: Import or Export ALL auctions", onClick = function() showBackup("Auctions", { "AU", "AT", "AP" }) end },
{ text = "Backup: Export ONE auction only", onClick = function()
local rows = query("SELECT id, name FROM auctions ORDER BY id DESC")
if #rows == 0 then toast("No auctions yet.") return end
local names = {}
for i, r in ipairs(rows) do names[i] = r[2] end
listDialog("Export which auction?", names, function(p)
exportBackup("Auction_" .. safeName(rows[p + 1][2]), { "AU", "AT", "AP" }, { auction = tonumber(rows[p + 1][1]) })
end)
end },
{ text = "Delete ALL auctions (cannot be undone)", onClick = function(load)
confirmDialog("Delete All Auctions", "Delete ALL auctions with their teams and players? This cannot be undone.", "Yes, Delete All", function()
run("DELETE FROM auction_players"); run("DELETE FROM auction_teams"); run("DELETE FROM auctions")
load(); toast("All auctions deleted.")
end)
end }},
function()
local recs, items = {}, {}
for _, r in ipairs(query("SELECT a.id, a.name, a.coins_per_team, a.default_base_price, a.currency, a.currency2, a.coins_per_team2, a.allow_fallback, a.max_players_per_team, " ..
"(SELECT COUNT(*) FROM auction_players p WHERE p.auction_id=a.id AND p.status='sold'), " ..
"(SELECT COUNT(*) FROM auction_players p WHERE p.auction_id=a.id) FROM auctions a ORDER BY a.id DESC")) do
local cur = (r[5] ~= "") and r[5] or "Coins"
recs[#recs + 1] = { id = tonumber(r[1]), name = r[2], coins = tonumber(r[3]) or 0, base = tonumber(r[4]) or 0, cur = cur,
cur2 = r[6], coins2 = tonumber(r[7]) or 0, fallback = (tonumber(r[8]) or 0) == 1, max = tonumber(r[9]) or 0 }
items[#items + 1] = r[2] .. " - " .. r[10] .. "/" .. r[11] .. " sold - " .. cur .. (r[6] ~= "" and (" + " .. r[6]) or "")
end
return recs, items
end,
function(refresh)
formDialog("New Auction", {
{ id = "n", hint = "Auction Name" },
{ id = "b", hint = "Primary budget per team", num = true },
{ id = "p", hint = "Default base price", num = true },
{ id = "m", hint = "Max players per team (empty = no limit)", num = true },
{ id = "t", hint = "Teams (one per line)", multi = true } }, function(x)
local budget, base, teams = tonumber(x.b), tonumber(x.p), parseLines(x.t)
if x.n == "" or not budget or not base or #teams < 2 then
toast("Enter name, budget, base price and at least 2 teams.", true)
return
end
local maxp = tonumber(x.m) or 0
local function finish(cur1, cur2, budget2, fallback)
local ok, id = run("INSERT INTO auctions (name, coins_per_team, default_base_price, created_at, currency, currency2, coins_per_team2, allow_fallback, max_players_per_team) VALUES (?,?,?,?,?,?,?,?,?)",
x.n, budget, base, os.date("%Y-%m-%d %H:%M"), cur1, cur2, budget2, fallback, maxp)
if not ok or not id then toast("Could not create auction.", true) return end
for _, tn in ipairs(teams) do
run("INSERT INTO auction_teams (auction_id, team_name, coins_remaining, coins_remaining2) VALUES (?,?,?,?)", id, tn, budget, budget2)
end
toast("Auction created: " .. x.n .. " with " .. #teams .. " teams.", true)
refresh()
end
local labels1 = {}
for i, c in ipairs(primaryCodes) do labels1[i] = curLabel[c] end
listDialog("Primary Currency", labels1, function(p1)
local cur1 = primaryCodes[p1 + 1]
local codes, labels = { "" }, { "None (single currency)" }
for _, c in ipairs(secondaryCodes) do
if c ~= cur1 then codes[#codes + 1] = c; labels[#labels + 1] = curLabel[c] end
end
listDialog("Secondary Currency", labels, function(p2)
local cur2 = codes[p2 + 1]
if cur2 == "" then finish(cur1, "", 0, 0) return end
local function askFallback(b2)
listDialog("Secondary currency use", { "Allow secondary currency (choose when selling)", "Don't allow (primary only)" }, function(p4)
finish(cur1, cur2, b2, p4 == 0 and 1 or 0)
end)
end
listDialog("Secondary Limit", { "Limited", "Unlimited" }, function(p3)
if p3 == 1 then askFallback(-1) return end
promptInput("Secondary budget per team (" .. cur2 .. ")", nil, "Amount", function(s)
local b2 = tonumber(s)
if not b2 then toast("Enter a valid amount.") return end
askFallback(math.floor(b2))
end, true)
end)
end)
end)
end)
end,
function(rec, refresh) showAuction(rec, refresh) end,
function(rec, refresh)
confirmDialog("Delete Auction", "Delete \"" .. rec.name .. "\" with all its teams and players? This cannot be undone.", "Yes, Delete", function()
run("DELETE FROM auction_players WHERE auction_id=?", rec.id)
run("DELETE FROM auction_teams WHERE auction_id=?", rec.id)
run("DELETE FROM auctions WHERE id=?", rec.id)
refresh()
end)
end)
end
local function fetchText(url, cb)
if pcall(function() Http.get(url, function(code, content) cb(code, content) end) end) then return end
pcall(function()
local h = Handler(Looper.getMainLooper())
Thread(Runnable({ run = function()
local text
pcall(function()
local conn = URL(url).openConnection()
conn.setConnectTimeout(8000); conn.setReadTimeout(8000)
local br = BufferedReader(InputStreamReader(conn.getInputStream(), "UTF-8"))
local lines, line = {}, br.readLine()
while line ~= nil do lines[#lines + 1] = line; line = br.readLine() end
br.close(); text = table.concat(lines, "\n")
end)
h.post(Runnable({ run = function() cb(text and 200 or -1, text) end }))
end })).start()
end)
end
local function scriptPath()
if type(luapath) == "string" and luapath:sub(-4) == ".lua" then return luapath end
local ok, src = pcall(function() return debug.getinfo(1, "S").source end)
if ok and type(src) == "string" then
src = src:gsub("^[@=]", "")
if src:sub(-4) == ".lua" then return src end
end
if type(luadir) == "string" and luadir ~= "" then return luadir .. "/main.lua" end
return nil
end
local function installUpdate(text, ver)
local fn = (loadstring or load)(text)
if not fn then toast("Update failed: the downloaded file has an error. Nothing was changed.", true) return end
local path = scriptPath()
if not path then
toast("Could not find this plugin's file. Opening the download link instead.", true)
openUrl(UPDATE_URL)
return
end
local ok = pcall(function()
local old = readFile(path)
if old then
local w = OutputStreamWriter(FileOutputStream(File(path .. ".bak")), "UTF-8")
w.write(old); w.flush(); w.close()
end
local w2 = OutputStreamWriter(FileOutputStream(File(path)), "UTF-8")
w2.write(text); w2.flush(); w2.close()
end)
if ok then
message("Update Installed", "Updated to version " .. ver .. ". Close the plugin and open it again to use the new version. The old file was saved as main.lua.bak.")
else
toast("Could not write the update file. Opening the download link instead.", true)
openUrl(UPDATE_URL)
end
end
local function checkUpdate(manual)
if UPDATE_URL == "" then
if manual then toast("Update link is not set.", true) end
return
end
fetchText(UPDATE_URL, function(code, text)
if code ~= 200 or not text then
if manual then toast("Could not check for updates.") end
return
end
if not text:find("Squad Manager & Auction Manager Pro", 1, true) then
if manual then toast("The update link does not contain this app's file.", true) end
return
end
local ver = tonumber(text:match("local APP_VERSION = (%d+)"))
if not ver then
if manual then toast("The update file has no version number.", true) end
return
end
if ver <= APP_VERSION then
if manual then toast("You are on the latest version (v" .. APP_VERSION .. ").") end
return
end
local notes = {}
for n in text:gmatch("%-%- NOTES: ([^\r\n]*)") do notes[#notes + 1] = "- " .. n end
confirmDialog("Update Available - version " .. ver,
(#notes > 0 and table.concat(notes, "\n") or "A new version is available.") .. "\n\nUpdate now?",
"Update Now", function() installUpdate(text, ver) end)
end)
end
local GUIDE = table.concat({
"HOW TO USE",
"",
"EVERY SCREEN",
"- The bottom row always has Back (one screen back), Home (the start screen) and Exit (close the plugin).",
"- More Options is at the top right of the list screens.",
"- Menus like More Options stay open after you copy something, so you can copy several things; tap Back to leave.",
"",
"SQUAD MANAGER (teams and playing list)",
"1. More Options > Add Team: type the tournament name, your team name and, if you like, paste the players.",
"2. Open the team. More Options > Add Players: tap Paste from Clipboard (or type). Any list works: numbers, roles like Captain, prices and headings are removed and only the names are kept. A Team Owner in the text is saved as the owner and appears in Copy Full Squad.",
"3. Tick the players who are playing. The role box next to a name works only for ticked players: Player, Batsman, Bowler, All-Rounder, Wicket-Keeper, Reserve, Captain, Vice Captain, Second Vice Captain. Captain is always number 1, Vice Captain 2, Second Vice Captain 3 and Reserves come last.",
"4. More Options > Schedule: paste a tournament schedule in any style, neat or messy. Only your team's matches are kept: match number, date, match time, room time and opponent. Check the preview, then Save All.",
"5. More Options > Choose Match picks the match shown in the list. Copy Playing List and Share Playing List give a clean list for WhatsApp. The Check line tells you if the Captain, Vice Captain or 11 players are missing.",
"6. Long press a name to rename, move or delete it. More Options also has Copy Full Squad, Team Owner and Clear Playing.",
"",
"PLAYER AUCTION",
"1. More Options > New Auction: name, budget, base price, max players per team, teams, primary currency (Coins, PKR, INR or BDT) and an optional secondary currency (limited or unlimited).",
"2. Open the auction > Add Players to Pool (paste any list).",
"3. Auction Room: tap a player, pick a team (or Unsold), choose how to pay (primary, secondary or both together) and type the price. The price is checked against the budget and the base price, and a warning tells you exactly what is short.",
"4. Teams: open a team to see Team Owner, Captain, Vice Captain, Second Vice Captain and Pick 1, Pick 2 ... Long press a player to change team or price. More Options has Add Favorite Player (no coins used), copy with or without price, Top Buys and WhatsApp share.",
"5. Settings: rename, base price, max players, rankings and reset. The Room and Unsold lists have a Player Numbering setting in More Options.",
"",
"BACKUP",
"In Squad Manager and Player Auction, More Options > Backup lets you export or import ALL items, or export ONE tournament or auction only.",
"",
"UPDATES",
"The plugin checks for a new version when it opens. Help and Feedback > Check for Updates does it by hand.",
"",
"FEEDBACK",
"Help and Feedback > Send Feedback on WhatsApp opens a ready message to Umar Jan.",
}, "\n")
local function showHelp()
listDialog("Help and Feedback", { "How to use (User Guide)", "Send Feedback on WhatsApp", "Join Telegram Channel (Umar Jaan Pro)",
"Open YouTube Channel (Umar Official Pro)", "Check for Updates" }, function(p)
if p == 0 then
message("User Guide - version " .. APP_VERSION, GUIDE)
elseif p == 1 then
local msg = "\216\167\217\132\216\179\217\132\216\167\217\133\32\216\185\217\132\219\140\218\169\217\133 Mr. Umar Jan " .. FLAG .. "\n\nI want to give you feedback about your plugin \"Squad Manager & Auction Manager Pro\" (version " .. APP_VERSION .. ").\n\nMy feedback:\n"
openUrl(LINKS[1] .. "?text=" .. Uri.encode(msg))
elseif p == 4 then
checkUpdate(true)
else
openUrl(LINKS[p])
end
end)
end
local hv = {}
dlg.setView(loadlayout({ LinearLayout; orientation = "vertical"; padding = "16dp"; backgroundColor = "#F5F7FA"; layout_width = "-1"; layout_height = "-1";
btn("squadB", "Squad Manager (teams, playing list, schedule)", "0xFF3F51B5", { layout_marginBottom = "10dp" });
btn("auctionB", "Player Auction (players, teams, prices)", "0xFFFF6F00", { layout_marginBottom = "10dp" });
btn("helpB", "Help and Feedback", "0xFF607D8B", { layout_marginBottom = "10dp" });
btn("exitB", "Exit", "0xFFD32F2F");
}, hv))
hv.squadB.setOnClickListener(View.OnClickListener({ onClick = showSquadManager }))
hv.auctionB.setOnClickListener(View.OnClickListener({ onClick = showAuctionManager }))
hv.helpB.setOnClickListener(View.OnClickListener({ onClick = showHelp }))
hv.exitB.setOnClickListener(View.OnClickListener({ onClick = closeAll }))
dlg.show()
pcall(function() checkUpdate(false) end)

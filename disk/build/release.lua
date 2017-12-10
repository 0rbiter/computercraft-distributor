{
  release = 24,
  files = {
    run = {
      {
        netware = "--netware\
service = \"release\"\
wifi    = nil\
server  = nil\
modus = \"client\"\
sender_file = \"/.nwdb\"\
frelease = \".release\"\
fnew_release = \"release\"\
build_dir = \"/disk/files/build/\"\
timeout = 20\
to = 0\
to = os.startTimer(timeout)\
\
if os.getComputerLabel() == \"diskmaster\" then\
  modus = \"server\"\
  frelease = \"/disk/files/build/release\"\
end\
\
function nl()\
  local x_max, y_max = term.getSize()\
  local x, y = term.getCursorPos()\
  if y + 1 <= y_max then\
    y = y + 1\
  else\
    sleep(1)\
    term.clear()\
    y = 1\
  end\
  x = 1\
  term.setCursorPos(x, y)\
end\
\
function load_file(filename)\
  if fs.exists(filename) and not fs.isDir(filename) then\
    local infile = fs.open(filename, \"r\")\
    if not infile then\
      nl()\
      term.write(\"Could not load file from \"..filename)\
      nl()\
      return nil\
    end\
    local data = infile.readAll()\
    return data\
  end\
end\
\
function load_table(filename)\
  local data = load_file(filename)\
  if not data then\
    nl()\
    term.write(\"Cannot read table from \"..filename)\
    nl()\
    return nil\
  end\
  data = textutils.unserialize(data)\
  if not data then\
    nl()\
    term.write(\"Empty table: \"..filename)\
    nl()\
  else\
    return data\
  end\
end\
\
function save_file(data, filename)\
  outfile = fs.open(filename, \"w\")\
  if not outfile then nl() term.write(\"Could not write \"..filename) return false end\
  outfile.write(data)\
  outfile.flush()\
  outfile.close()\
  return true\
end\
\
function deepcopy(orig)\
    local orig_type = type(orig)\
    local copy\
    if orig_type == 'table' then\
        copy = {}\
        for orig_key, orig_value in next, orig, nil do\
            copy[deepcopy(orig_key)] = deepcopy(orig_value)\
        end\
        setmetatable(copy, deepcopy(getmetatable(orig)))\
    else -- number, string, boolean, etc\
        copy = orig\
    end\
    return copy\
end\
\
function add_host(sender, file)\
  local infile = fs.open(file, \"r\")\
  if not infile then\
    nl()\
    term.write(\"Could not open \"..file)\
  else\
    local thostlist = textutils.unserialize(infile.readAll())\
    infile.close()\
  end\
  \
  local thl = {}\
  if thostlist then\
    thl = thostlist\
    if not thl[sender] then\
      thl[sender] = true\
      --also: signalize the caller that\
      --the host was not found:\
      return false\
    else \
      --otherwise..\
      return true\
      --print(\"Not implemented if server exists\")\
    end\
  else\
    thl[sender] = true\
  end\
  \
  local outfile = fs.open(file, \"w\")\
  if not outfile then\
    error(\"Could not open file for write: \"..file)\
  end\
  outfile.write(textutils.serialize(thl))\
  outfile.flush()\
  outfile.close()\
end\
\
function init()\
  local tdevs = peripheral.getNames()\
  for k,v in pairs(tdevs) do\
    if peripheral.getType(v) == \"modem\"\
   and peripheral.wrap(v).isWireless() then \
      if not rednet.isOpen(v) then\
        rednet.open(v)\
        if rednet.isOpen(v) then\
          return v\
        else\
          error(\"Cannot open interface\")\
        end\
      else\
        return v\
      end\
    end\
  end\
  return nil\
end\
\
function sopen(side)\
  if not rednet.isOpen(side) then\
    rednet.open(side)\
  end\
  return rednet.isOpen(side)\
end\
\
function sclose(side)\
  if rednet.isOpen(side) then return rednet.close(side) end\
end\
\
function ssend(host, tcommands, svc)\
  sopen(wifi)\
  rednet.send(host, tcommands, svc)\
end\
\
function sreceive(service, timeout)\
  sopen(wifi)\
  local sender, msg, prot = rednet.receive(service, timeout)\
  if sender then\
    add_host(sender, sender_file)\
  end\
    \
  if prot ~= service and prot and service then\
    nl()\
    term.write(\"Protocol mismatch - that should not happen at all.\")\
  end\
  return msg\
end\
\
function get_server(svc)\
  sopen(wifi)\
  server = rednet.lookup(svc)\
  if not server then\
    nl()\
    term.write(\"No server found in get_server\")\
  else\
    add_host(server, sender_file)\
  end\
  return server\
end\
\
function shost(service)\
  server = get_server(service)\
  if not server then\
    rednet.host(service, tostring(os.getComputerID()))\
    return true\
  else\
    return false\
  end\
end\
\
function sbroadcast(data, service)\
  if not data then error(\"No data given for broadcast\") end\
  sopen(wifi)\
  rednet.broadcast(data, service)\
end\
\
cmds = {\
  [\"getrversion\"] = { \"get\", \"release\", \"version\" },\
  [\"getrsize\"] = { \"get\", \"release\", \"size\" },\
  [\"putrversion\"] = { \"put\", \"release\", \"version\", 0 },\
  [\"putrsize\"] = { \"put\", \"release\", \"size\", 0 },\
  \
  [\"getfile\"] = { \"get\", \"file\", \"filename\" }, -- optional: version\
  [\"gettime\"] = { \"get\", \"time\" },   --os.time format\
  [\"putfile\"] = { \"put\", \"file\", \"filename\", \"\" },  --look in build/ for filename\
  [\"puttime\"] = { \"put\", \"time\", 0 },  --os.time format\
  }\
\
function handle(client, cmdl)\
  if not cmdl then error(\"empty commands\") end\
  if type(cmdl) == type(\"\") then\
    cmdl = textutils.unserialize(cmdl)\
  end\
  for k,v in pairs(cmdl) do\
    if type(v) == type(table) then\
      if v[1] == \"get\" or v[1] == \"put\" then\
        assert(v[2], v[1]..\": missing fields\")\
        \
        if v[2] == \"file\" then\
          if v[1] == \"get\" then\
            local ttemp = {}\
            ttemp[\"putfile\"] = cmds[\"putfile\"]\
            if not v[3] then error(\"No filename given by \"..client) end\
            local search_file = build_dir..v[3]\
            if fs.exists(search_file) and not fs.isDir(search_file) then\
              local infile = fs.open(search_file, \"r\")\
              if not infile then\
                nl()\
                term.write(\"Cannot access \"..search_file)\
              else\
                ttemp.putfile[4] = infile.readAll()\
              end        \
              infile.close()\
            else\
              nl()\
              term.write(\"Requested file not found: \"..search_file)\
              nl()\
              term.write(\"Name: \"..client)\
            end --end fs checks\
            ttemp.putfile[3] = v[3]\
            nl()\
            term.write(\"R: \"..ttemp.putfile[3])\
            ssend(client, ttemp, service)\
          elseif v[1] == \"put\" then\
            if not v[3] or not v[4] then error(\"Wrong format for file put\") end\
            if modus == \"client\" and v[3] == \"release\" then\
              local update = false\
              test_rel = load_table(\"/\"..fnew_release)\
              print(textutils.serialize(test_rel))\
              if test_rel then\
                test_new_rel = textutils.unserialize(v[4])\
                if test_new_rel then\
                  if test_new_rel.release > test_rel.release then\
                    update = true\
                  else\
                    nl()\
                    term.write(\"Nothing to do here....\")\
                  end\
                end\
              else\
                update = true\
              end\
              local done = false\
              if update then \
                done = save_file(v[4], \"/\"..frelease)\
                if not done then error(\"Error writing release file: \"..frelease) end\
                term.write(\"Update installed, rebooting.\")\
                os.reboot()\
              end\
            else\
              nl()\
              term.write(\"Not a release file: \"..v[3])\
            end\
          end --end get/put\
        elseif v[2] == \"release\" then\
          if v[1] == \"get\" and v[3] == \"version\" then\
            local rel = load_table(frelease)\
            if not rel then\
              term.write(\"get release version - cannot open file \"..frelease)\
              sleep(10)\
            end\
            local ttemp2 = {}\
            ttemp2[\"putrversion\"] = deepcopy(cmds[\"putrversion\"])\
            if not rel then\
              rel = load_table(fnew_release)\
            end\
            ttemp2.putrversion[4] = rel.release\
            nl()\
            ssend(client, ttemp2, service)\
          end\
          if v[1] == \"put\"\
            and v[3] == \"version\"\
              and v[4]\
                and modus == \"client\" then\
            local new_rls = v[4]\
            local update = false\
            if new_rls == 1 then\
              nl()\
              term.write(\"Update triggered by override\") \
              update = true\
            end\
            if new_rls and new_rls ~= 1 then\
              local trls = load_table(frelease)\
              if not trls then\
                trls = load_table(fnew_release)\
              end\
              if not trls then\
                tlrs = {}\
                trls = { [\"release\"] = 1 }\
              end\
              if new_rls > trls.release \
                or trls[\"release\"] == 1 then\
                update = true\
              else\
                nl()\
                term.write(\"Release is not newer\")\
              end  \
            else\
              nl()\
              term.write(\"Error: no new release\")\
            end\
            if update then\
              term.write(\"Update process triggered\")\
              local new_data = { [\"getfile\"] = {} }\
              new_data.getfile = cmds.getfile\
              new_data.getfile[3] = \"release\"\
              nl()\
              term.write(\"FICKSAU1\")\
              rednet.send(2546, { [\"getfile\"] = { \"get\", \"file\", \"release\" } }, \"release\")\
              local s,m,p = rednet.receive(service, timeout)\
              if m then\
                print(textutils.serialize(m))\
                handle(client, m)\
              else\
                nl()\
                term.write(\"Nothing received during update\")\
              end\
              \
            end   \
          end\
        elseif v[2] == \"time\" then\
          if v[1] == \"get\" then\
            local ttemp3 = {}\
            ttemp3[\"puttime\"] = deepcopy(cmds[\"puttime\"])\
            v[3] = os.time()\
            nl() term.write(\"answering time request\")\
            ssend(client, ttemp3, service)\
			         ttemp3 = nil\
          elseif v[2] == \"put\" then\
            error(\"put time not implemented yet\")\
          end\
        else error(\"Cannot handle commando: \"..v[2])\
        end     \
      else\
        error(\"Cannot handle field type: \"..field..\" at \"..n)\
      end\
    end\
  end\
  --\
end\
\
wifi = init()\
\
if not wifi then\
  error(\"No wifi device found\") \
  sleep(5)\
  shell.exit()\
end\
\
term.clear()\
term.setCursorPos(1,1)\
\
if modus == \"server\" then\
  rednet.unhost(service)\
  sleep(2)\
end\
\
while modus == \"server\" do\
  shost(service)\
  local helo = {}\
  helo[\"putfile\"] = deepcopy(cmds[\"putfile\"])\
  helo.putfile[3] = \"release\"\
  if fs.exists(build_dir..fnew_release) then\
    helo.putfile[4] = load_file(build_dir..fnew_release)\
    sbroadcast(helo, service)\
  end\
  sleep(10)\
  --sbroadcast(helo, service)\
 \
  --local sender, msg, protocol\
  --  = rednet.receive(service)\
  \
  --if sender then add_host(sender, sender_file) end\
  --handle(sender, msg)\
end\
\
if modus == \"client\" then\
  server = get_server(service)\
end\
\
while modus == \"client\" do\
  function net_recv()  \
 --handle block\
   	if not server then\
      server = get_server(service)\
    end\
    --print(textutils.serialize(server))\
    --print(textutils.serialize(service))	\
   	local indata = {}\
    indata = sreceive(service)\
   	nl()\
   	term.write(\"IN: \"..textutils.serialize(indata))\
   	if indata and server then\
      handle(server, indata)\
   	end\
 --handle block end\
  end\
\
  function req_data()\
    local trigger = true\
    while trigger do\
    local event, timer = os.pullEvent(\"timer\")\
   	if timer == to then\
      nl()\
      term.write(\"Timer triggered\")\
   	  local data = {}\
   	  data[\"getrversion\"] = deepcopy(cmds[\"getrversion\"])\
      server = get_server(service)\
      if server then\
        nl()\
        term.write(\"Requesting release data\")\
    	   ssend(server, data, service)\
   	  else\
  	     nl()\
        term.write(\"No server found\")\
      end\
      to = os.startTimer(timeout)\
      timer = nil\
      trigger = false\
    end\
    end--while end\
  end\
  \
  --parallel.waitForAny(req_data, net_recv)\
  net_recv()\
end",
      },
      {
        distributor = "--distributor neu\
if not newlib then os.loadAPI(\"/newlib\") end\
burnratio = newlib.get_burnratio()\
mode = newlib.get_mode()\
\
while mode == 0 do\
  term.write(\"Not configured\")\
  local event, p1 = os.pullEvent(\"turtle_inventory\")\
  sleep(10)\
  burnratio = newlib.get_burnratio()\
  if burnratio > 0 and newlib.get_mode() > 0 then\
    mode = newlib.get_mode()\
  end\
end\
\
while mode == 2 do\
  newlib.set_label(\"secondary\")\
  dropratio = burnratio - 1\
  if turtle.getItemCount(1) >= burnratio then\
    turtle.drop(dropratio)\
    turtle.dropDown(1)\
    newlib.rotate(\"left\")\
  else\
    turtle.suckUp(burnratio)\
  end\
  sleep(.1)\
end\
\
while mode == 3 do\
  turtle.placeUp()\
  sleep(1)\
  turtle.placeUp()\
  newlib.set_label(\"tertiary\")\
  if turtle.getItemCount(1) >= 1 then\
    turtle.select(1)\
    turtle.drop(1)\
    newlib.rotate(\"left\")\
  end\
  sleep(.1)\
end\
\
idlecounter = 0\
early_offset = 3\
burntime = 30\
before = 1\
rounds = 0\
while mode == 1 do\
  newlib.set_label(\"primary\")\
  before = os.clock()\
  if not (turtle.getItemCount(1) >= burnratio) then\
    turtle.suckUp(burnratio - turtle.getItemCount(1))\
  else\
    turtle.drop(burnratio)\
    rounds = rounds + 1\
    newlib.nl()\
    term.write(\"Round No. \"..rounds)\
    newlib.rotate(\"left\")\
    newlib.nl()\
    term.write(\"Heading: \"..newlib.heading())\
    --before = os.clock()\
  end\
  if rounds >= 5 then\
    rounds = 0\
    --burntime = 30\
    now = os.clock()\
    delta = now - before\
    if delta <= (burntime- early_offset) then\
      newlib.nl()\
      term.write(\"Sleeping for \"..(burntime-delta-early_offset).. \"seconds\")\
      sleep(burntime - delta - early_offset)\
    end\
    before = os.clock()\
  end\
  sleep(.2)\
end",
      },
    },
    once = {
      {
        extract = "--extract\
args = { ... }\
\
update = false\
local basedir = \"/\" -- end this with / always\
local fold_release = basedir..\"release\"\
local frelease = basedir..\".release\" \
\
template = {\
  [\"begin\"] = {\
	[1] = \"--startup\",\
  },\
  [\"func\"] = {\
	[1] = \"function func_#()\",\
	[2] = \"  shell.run(\\\"/\\\"..\\\"#\\\")\",\
	[3] = \"end\",\
  },\
  [\"main\"] = {\
	[1] = \"while true do\",\
	[2] = \"  parallel.waitForAny(#) os.reboot()\",\
	[3] = \"end\",\
  },\
}\
\
new_release = {}\
old_release = {}\
\
function clean(directory, tignore)\
  if not fs.isDir(directory) then error(\"clean(): Not a directory: \"..directory) end\
  if not tignore\
    or type(tignore) ~= type(table)\
    or not tignore[1]\
    then error(\"clean(): No proper ignore table given\")\
  end\
  \
  content = fs.list(directory)\
  deleted_any = false\
     \
  return deleted_any\
end\
\
function load_table(filename)\
  infile = fs.open(filename, \"r\")\
  if not infile then nl() term.write(\"Could not open for read \"..filename) return nil end\
  data = textutils.unserialize(infile.readAll())\
  return data\
end\
\
function save_file(data, filename)\
  outfile = fs.open(filename, \"w\")\
  if not outfile then error(\"Could not open for write \"..filename) return false end\
  outfile.write(data)\
  res = outfile.flush()\
  outfile.close()\
  return res  \
end\
\
function nl()\
  x_max, y_max = term.getSize()\
  x, y = term.getCursorPos()\
  if y + 1 > y_max then\
    y = 1\
    while not key == \"key\" do\
      key, event = os.pullEvent()\
      sleep(.1)\
    end\
    sleep(1)\
    term.clear()\
  else y = y + 1\
  end\
  term.setCursorPos(1, y)\
end\
\
if os.getComputerLabel() == \"diskmaster\" then\
	fold_release = basedir..\"release\"\
	frelease = basedir..\"disk/files/build/release\" \
end\
\
new_release = load_table(frelease)\
if not new_release then return 0 end\
old_release = load_table(fold_release)\
if not old_release then\
  old_release = {}\
  old_release.release = -999\
end\
\
if type(new_release) ~= type(table) then\
  error(\"Script broken. Could not load release file: \"..frelease)\
else\
  if new_release.release <= old_release.release\
    and new_release.release ~= 0 then\
    nl()\
    term.write(\"Extract: Nothing to do here\")\
    error(\"Normal end\")\
  end\
  term.write(frelease..\" version \"..new_release.release)\
  nl()\
  if not old_release  then\
    term.write(fold_release..\" version \"..old_release.release)\
    if old_release.release < new_release.release then\
      update = true\
    elseif old_release.release >= new_release.release then\
      term.write(\"Extractor: \"..frelease..\" is not newer\")\
      sleep(1)\
      error(\"Normal end\")\
    end\
  end\
end\
nl()\
\
if not update then shell.exit() end\
\
ignore_files = new_release[\"ignore\"]\
if not ignore_files then error(\"Could not ignore list\") \
else print(textutils.serialize(ignore_files))\
end\
\
for k,v in pairs(new_release[\"files\"]) do\
  old_v = v\
  for kee,val in pairs(v) do\
    sleep(.2) \
    if type(val) == type(table) then\
      for fname,fdata in pairs(val) do\
        sleep(.2)\
        if not fs.exists(fname) then\
          nl()\
          term.write(\"Creating: \"..fname)\
          save_file(fdata, fname)\
          new_release.files[k][kee][fname] = \"\"\
        elseif fs.exists(fname) then\
          nl()\
          ignored = new_release.ignore[fname]\
          if not ignored then ignored = false end\
          if not ignored then\
            save_file(fdata, fname)\
            new_release.files[k][kee][fname] = \"\"\
            term.write(\"Overwritten: \"..fname..\" - \"..tostring(ignored))\
            sleep(1)\
          else\
            term.write(\"Ignored: \"..fname..\" - \"..tostring(ignored))\
            sleep(1)\
          end\
        end\
      end\
      nl()\
    end\
  end\
  if k == \"run\" then\
\
    new_func_block = \"\"\
    sout = {}\
    sout[1] = template.begin[1]\
    --position count for startup gen\
    do_cnt = 2\
    --iterate through run's filenames\
    for name, bulk in pairs(old_v) do\
      for z,w in pairs(bulk) do\
        fname = z\
        nl()\
        wname = basedir..fname\
        --build func block\
        if fs.exists(wname) then\
          term.write(\"Integrating into startup: \"..wname)\
          --replace # with fname\
          new_func_block = new_func_block..\
          \"func_\"..fname..\", \"\
          for i = 1,3 do\
            sout[do_cnt] = string.gsub(template.func[i], \"#\", fname)\
            do_cnt = do_cnt + 1\
          end\
        else\
          term.write(\"Does not exist: \"..wname)\
          nl()\
        end--build func block\
      end\
    end--iterate through fnames / filenames\
    if not new_func_block then error(\"Problem\") end\
  elseif k == \"once\" then\
    for bk,valname in pairs(v) do\
      for tname, bulk in pairs(valname) do\
        fname = tname\
       	prepare = string.sub(template.func[2], 2)\
        prepare = string.gsub(prepare, \"#\", fname)\
        sout[do_cnt] = prepare\
        do_cnt = do_cnt + 1\
      end\
    end\
  end --if k == run elseif == once\
end --iter through \"files\"\
\
new_func_block = string.sub(new_func_block, 1, -3)..\"\"\
sout[do_cnt] = template.main[1]\
sout[do_cnt+1] = string.gsub(template.main[2], \"#\", new_func_block)\
sout[do_cnt+2] = template.main[3]\
do_cnt = do_cnt + 2\
outfile = fs.open(basedir..\"/startup\", \"w\")\
if not outfile then error(\"Cannot write to \"..basedir..\"/startup\") end\
term.clear()\
term.setCursorPos(1, 1)\
for i = 1,do_cnt do\
  nl()\
  term.write(i..\": \"..sout[i])\
  outfile.writeLine(sout[i])\
end\
nl()\
outfile.flush()\
outfile.close()\
if os.getComputerLabel() ~= \"diskmaster\" then\
  fs.delete(fold_release)\
  fs.copy(frelease, fold_release)\
  fs.delete(frelease)\
  os.reboot()\
end",
      },
    },
    api = {
      {
        newlib = "--newlib\
local burnratio = 12\
\
function nl()\
  x_max, y_max = term.getSize()\
  x, y = term.getCursorPos()\
  if y + 1 <= y_max then\
    y = y + 1\
  else\
    term.clear()\
    y = 1\
  end\
  x = 1\
  term.setCursorPos(x, y) \
end\
\
\
function println(text)\
  x_max, y_max = term.getSize()\
  x, y = term.getCursorPos()\
  if (y + 1) <= y_max then\
    term.setCursorPos(1, y+1)\
  elseif (y + 1) > y_max then\
    term.clear()\
    term.setCursorPos(1, 1)\
  end\
  term.write(textutils.pagedPrint(text))\
end\
\
function set_label(modus)\
  os.setComputerLabel(modus..os.getComputerID())\
end\
\
function pulse(side, times)\
  for i = 1, times do\
    redstone.setOutput(side, true)\
    sleep(.5)\
    redstone.setOutput(side, false)\
    sleep(.5)\
  end\
end\
\
function get_itemcount(slottable)\
  if slottable == {0} then\
    slottable = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 }\
  end\
  ic = 0\
  for k,v in pairs{slottable} do\
    ic = ic + turtle.getItemCount(v)\
  end\
  return ic\
end\
function act_direction(mode, amount, direction)\
  if direction == \"up\" then\
    if mode == \"suck\" then\
      return turtle.suckUp(amount)\
    else\
      return turtle.dropUp(amount)\
    end\
  else\
    if direction == \"front\" then\
      if mode == \"suck\" then\
        return turtle.suck(amount)\
      else\
        return turtle.drop(amount)\
      end\
    else\
      if direction == \"down\" then\
        if mode == \"suck\" then\
          return turtle.suckDown(amount)\
        else\
          return turtle.dropDown(amount)\
        end\
      else\
        return false\
      end\
    end\
  end\
      \
end\
\
function is_empty(amount, direction, slottable, amount)\
  empty = true\
  -- get itemcount of all slots in table\
  ic = get_itemcount({0})\
\
  -- probe in direction\
  result = false\
  oldic = get_itemcount({0})\
  if act_direction(\"suck\", amount, direction) then\
    ic = get_itemcount({0})\
    act_direction(\"drop\", (ic - oldic), direction)\
  else\
    result = true\
  end\
end\
\
function get_mode()\
  return turtle.getItemCount(15)\
end\
\
function get_burnratio()\
  return turtle.getItemCount(16)\
end\
\
function feed_burner(itemcount)\
  result = false\
  if turtle.getItemCount(turtle.getSelectedSlot()) >= itemcount then\
    turtle.dropDown(itemcount)\
    return true\
  end\
  return result\
end\
\
function isme(label)\
  if os.getComputerLabel() == label then\
    return true\
  else\
    return false\
  end\
end\
\
\
function load_file(filename)\
  if not filename then\
    error(\"load_file needs a filename\")\
    return false\
  end\
  infile = fs.open(filename, \"r\")\
  data = {}\
  if infile then\
    data = infile.readAll()\
  else\
    term.write(\"Could not open \"..filename..\" for read\")\
    return nil\
  end\
  return data\
end\
\
function load_table(filename)\
  return textutils.unserialize(load_file(filename))\
end\
\
function save_file(data, filename)\
  outfile = fs.open(filename, \"w\")\
  if not outfile then error(\"Could not open \"..filename..\" for write\") return false end\
  outfile.write(data)\
  result = outfile.flush()\
  outfile.close()\
  return result\
end\
\
function save_table(ttable, filename)\
  return save_file(textutils.serialize(ttable), filename)\
end\
\
function get_key(value, ttable)\
  result = 0\
  if type(ttable) ~= type(table) then return 0 end\
  for k,v in pairs(ttable) do\
    if value == v then\
      result = k\
    end\
  end\
  return result\
end\
\
function getfilelist(ign_files)  \
  tin = fs.list(\"\")\
  tout = {}\
  for k,v in pairs(tin) do\
    if not fs.isDir(v)  --ignore directories\
      and not fs.isReadOnly(v)  --ignore ro's\
        and not ign_files[v]   --if on ignore lists\
          and not (get_key(v, ign_files) > 0) then\
       tout[k] = v\
     end\
  end\
  return tout\
end\
\
function wipe(ign_files)\
  files = getfilelist(ign_files)\
  if not files then print(\"nothing found\") return false end\
  for no,file in pairs(files) do\
    println(\"Deleting \"..file..\" ...\")\
    --fs.delete(\"/\"..file)\
  end\
end\
\
local rot = nil\
\
rot_file = \"/.rot\"\
if not rot and turtle then\
  if fs.exists(rot_file) then\
    rot = load_table(rot_file)\
    if not rot then\
      error(\"no table in \"..rot_file)\
    end --end if not load table\
  else\
    error(\"No rotation file \"..rot_file)\
  end --end if file exists rot_table\
end     --end if not rot\
\
function rotate(to_pos)\
  local ttemp = {}\
  ttemp = load_table(rot_file)\
  for k,v in pairs(ttemp.direct) do\
    if to_pos == k\
      and k == \"left\" then\
      turtle.turnLeft()\
    elseif to_pos == k\
      and k == \"right\" then\
      turtle.turnRight()\
    end\
  end\
  if to_pos == \"left\" or to_pos == \"right\" then\
    return true\
  else\
  \
  local res = 0\
  local dir = heading()\
  --print(textutils.serialize(ttemp.indirect))\
  local newdir = ttemp.indirect[to_pos].number\
  res = dir - newdir\
  if res == 2 or res == -2 then \
    rotate(\"left\")\
    rotate(\"left\")\
  elseif res == 1 or res == -3 then\
    rotate(\"left\")\
  elseif res == -1 or res == 3 then\
    rotate(\"right\")\
  end\
\
  local new_heading = 0\
  new_heading = heading() - res  \
  for k,v in pairs(ttemp.indirect) do\
    if ttemp.indirect[k].number == new_heading then\
        ttemp.indirect[k].heading = true\
    else\
        ttemp.indirect[k].heading = false\
    end\
  end\
  save_table(ttemp, rot_file)\
  end\
end\
\
function heading()\
  local ttemp = load_table(rot_file)\
  for k,v in pairs(ttemp.indirect) do\
    if v.heading then\
      return v.number\
    end\
  end\
end",
      },
      {
        [ ".rot" ] = "{\
  direct = {\
    right = true,\
    left = true,\
  },\
  indirect = {\
    east = {\
      number = 3,\
      heading = false,\
    },\
    west = {\
      number = 1,\
      heading = false,\
    },\
    north = {\
      number = 2,\
      heading = true,\
    },\
    south = {\
      number = 4,\
      heading = false,\
    },\
  },\
}",
      },
    },
  },
  ignore = {
    disk3 = true,
    disk = true,
    [ ".temp" ] = true,
    [ ".release" ] = true,
    [ ".rot" ] = true,
    disk2 = true,
    rom = true,
  },
}
--netware
service = "release"
wifi    = nil
server  = nil
modus = "client"
sender_file = "/.nwdb"
frelease = ".release"
fnew_release = "release"
build_dir = "/disk/files/build/"
timeout = 20
to = 0
to = os.startTimer(timeout)

if os.getComputerLabel() == "diskmaster" then
  modus = "server"
  frelease = "/disk/files/build/release"
end

function nl()
  local x_max, y_max = term.getSize()
  local x, y = term.getCursorPos()
  if y + 1 <= y_max then
    y = y + 1
  else
    sleep(1)
    term.clear()
    y = 1
  end
  x = 1
  term.setCursorPos(x, y)
end

function load_file(filename)
  if fs.exists(filename) and not fs.isDir(filename) then
    local infile = fs.open(filename, "r")
    if not infile then
      nl()
      term.write("Could not load file from "..filename)
      nl()
      return nil
    end
    local data = infile.readAll()
    return data
  end
end

function load_table(filename)
  local data = load_file(filename)
  if not data then
    nl()
    term.write("Cannot read table from "..filename)
    nl()
    return nil
  end
  data = textutils.unserialize(data)
  if not data then
    nl()
    term.write("Empty table: "..filename)
    nl()
  else
    return data
  end
end

function save_file(data, filename)
  outfile = fs.open(filename, "w")
  if not outfile then nl() term.write("Could not write "..filename) return false end
  outfile.write(data)
  outfile.flush()
  outfile.close()
  return true
end

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function add_host(sender, file)
  local infile = fs.open(file, "r")
  if not infile then
    nl()
    term.write("Could not open "..file)
  else
    local thostlist = textutils.unserialize(infile.readAll())
    infile.close()
  end
  
  local thl = {}
  if thostlist then
    thl = thostlist
    if not thl[sender] then
      thl[sender] = true
      --also: signalize the caller that
      --the host was not found:
      return false
    else 
      --otherwise..
      return true
      --print("Not implemented if server exists")
    end
  else
    thl[sender] = true
  end
  
  local outfile = fs.open(file, "w")
  if not outfile then
    error("Could not open file for write: "..file)
  end
  outfile.write(textutils.serialize(thl))
  outfile.flush()
  outfile.close()
end

function init()
  local tdevs = peripheral.getNames()
  for k,v in pairs(tdevs) do
    if peripheral.getType(v) == "modem"
   and peripheral.wrap(v).isWireless() then 
      if not rednet.isOpen(v) then
        rednet.open(v)
        if rednet.isOpen(v) then
          return v
        else
          error("Cannot open interface")
        end
      else
        return v
      end
    end
  end
  return nil
end

function sopen(side)
  if not rednet.isOpen(side) then
    rednet.open(side)
  end
  return rednet.isOpen(side)
end

function sclose(side)
  if rednet.isOpen(side) then return rednet.close(side) end
end

function ssend(host, tcommands, svc)
  sopen(wifi)
  rednet.send(host, tcommands, svc)
end

function sreceive(service, timeout)
  sopen(wifi)
  local sender, msg, prot = rednet.receive(service, timeout)
  if sender then
    add_host(sender, sender_file)
  end
    
  if prot ~= service and prot and service then
    nl()
    term.write("Protocol mismatch - that should not happen at all.")
  end
  return msg
end

function get_server(svc)
  sopen(wifi)
  server = rednet.lookup(svc)
  if not server then
    nl()
    term.write("No server found in get_server")
  else
    add_host(server, sender_file)
  end
  return server
end

function shost(service)
  server = get_server(service)
  if not server then
    rednet.host(service, tostring(os.getComputerID()))
    return true
  else
    return false
  end
end

function sbroadcast(data, service)
  if not data then error("No data given for broadcast") end
  sopen(wifi)
  rednet.broadcast(data, service)
end

cmds = {
  ["getrversion"] = { "get", "release", "version" },
  ["getrsize"] = { "get", "release", "size" },
  ["putrversion"] = { "put", "release", "version", 0 },
  ["putrsize"] = { "put", "release", "size", 0 },
  
  ["getfile"] = { "get", "file", "filename" }, -- optional: version
  ["gettime"] = { "get", "time" },   --os.time format
  ["putfile"] = { "put", "file", "filename", "" },  --look in build/ for filename
  ["puttime"] = { "put", "time", 0 },  --os.time format
  }

function handle(client, cmdl)
  if not cmdl then error("empty commands") end
  if type(cmdl) == type("") then
    cmdl = textutils.unserialize(cmdl)
  end
  for k,v in pairs(cmdl) do
    if type(v) == type(table) then
      if v[1] == "get" or v[1] == "put" then
        assert(v[2], v[1]..": missing fields")
        
        if v[2] == "file" then
          if v[1] == "get" then
            local ttemp = {}
            ttemp["putfile"] = cmds["putfile"]
            if not v[3] then error("No filename given by "..client) end
            local search_file = build_dir..v[3]
            if fs.exists(search_file) and not fs.isDir(search_file) then
              local infile = fs.open(search_file, "r")
              if not infile then
                nl()
                term.write("Cannot access "..search_file)
              else
                ttemp.putfile[4] = infile.readAll()
              end        
              infile.close()
            else
              nl()
              term.write("Requested file not found: "..search_file)
              nl()
              term.write("Name: "..client)
            end --end fs checks
            ttemp.putfile[3] = v[3]
            nl()
            term.write("R: "..ttemp.putfile[3])
            ssend(client, ttemp, service)
          elseif v[1] == "put" then
            if not v[3] or not v[4] then error("Wrong format for file put") end
            if modus == "client" and v[3] == "release" then
              local update = false
              test_rel = load_table("/"..fnew_release)
              print(textutils.serialize(test_rel))
              if test_rel then
                test_new_rel = textutils.unserialize(v[4])
                if test_new_rel then
                  if test_new_rel.release > test_rel.release then
                    update = true
                  else
                    nl()
                    term.write("Nothing to do here....")
                  end
                end
              else
                update = true
              end
              local done = false
              if update then 
                done = save_file(v[4], "/"..frelease)
                if not done then error("Error writing release file: "..frelease) end
                term.write("Update installed, rebooting.")
                os.reboot()
              end
            else
              nl()
              term.write("Not a release file: "..v[3])
            end
          end --end get/put
        elseif v[2] == "release" then
          if v[1] == "get" and v[3] == "version" then
            local rel = load_table(frelease)
            if not rel then
              term.write("get release version - cannot open file "..frelease)
              sleep(10)
            end
            local ttemp2 = {}
            ttemp2["putrversion"] = deepcopy(cmds["putrversion"])
            if not rel then
              rel = load_table(fnew_release)
            end
            ttemp2.putrversion[4] = rel.release
            nl()
            ssend(client, ttemp2, service)
          end
          if v[1] == "put"
            and v[3] == "version"
              and v[4]
                and modus == "client" then
            local new_rls = v[4]
            local update = false
            if new_rls == 1 then
              nl()
              term.write("Update triggered by override") 
              update = true
            end
            if new_rls and new_rls ~= 1 then
              local trls = load_table(frelease)
              if not trls then
                trls = load_table(fnew_release)
              end
              if not trls then
                tlrs = {}
                trls = { ["release"] = 1 }
              end
              if new_rls > trls.release 
                or trls["release"] == 1 then
                update = true
              else
                nl()
                term.write("Release is not newer")
              end  
            else
              nl()
              term.write("Error: no new release")
            end
            if update then
              term.write("Update process triggered")
              local new_data = { ["getfile"] = {} }
              new_data.getfile = cmds.getfile
              new_data.getfile[3] = "release"
              nl()
              term.write("FICKSAU1")
              rednet.send(2546, { ["getfile"] = { "get", "file", "release" } }, "release")
              local s,m,p = rednet.receive(service, timeout)
              if m then
                print(textutils.serialize(m))
                handle(client, m)
              else
                nl()
                term.write("Nothing received during update")
              end
              
            end   
          end
        elseif v[2] == "time" then
          if v[1] == "get" then
            local ttemp3 = {}
            ttemp3["puttime"] = deepcopy(cmds["puttime"])
            v[3] = os.time()
            nl() term.write("answering time request")
            ssend(client, ttemp3, service)
			         ttemp3 = nil
          elseif v[2] == "put" then
            error("put time not implemented yet")
          end
        else error("Cannot handle commando: "..v[2])
        end     
      else
        error("Cannot handle field type: "..field.." at "..n)
      end
    end
  end
  --
end

wifi = init()

if not wifi then
  error("No wifi device found") 
  sleep(5)
  shell.exit()
end

term.clear()
term.setCursorPos(1,1)

if modus == "server" then
  rednet.unhost(service)
  sleep(2)
end

while modus == "server" do
  shost(service)
  local helo = {}
  helo["putfile"] = deepcopy(cmds["putfile"])
  helo.putfile[3] = "release"
  if fs.exists(build_dir..fnew_release) then
    helo.putfile[4] = load_file(build_dir..fnew_release)
    sbroadcast(helo, service)
  end
  sleep(10)
  --sbroadcast(helo, service)
 
  --local sender, msg, protocol
  --  = rednet.receive(service)
  
  --if sender then add_host(sender, sender_file) end
  --handle(sender, msg)
end

if modus == "client" then
  server = get_server(service)
end

while modus == "client" do
  function net_recv()  
 --handle block
   	if not server then
      server = get_server(service)
    end
    --print(textutils.serialize(server))
    --print(textutils.serialize(service))	
   	local indata = {}
    indata = sreceive(service)
   	nl()
   	term.write("IN: "..textutils.serialize(indata))
   	if indata and server then
      handle(server, indata)
   	end
 --handle block end
  end

  function req_data()
    local trigger = true
    while trigger do
    local event, timer = os.pullEvent("timer")
   	if timer == to then
      nl()
      term.write("Timer triggered")
   	  local data = {}
   	  data["getrversion"] = deepcopy(cmds["getrversion"])
      server = get_server(service)
      if server then
        nl()
        term.write("Requesting release data")
    	   ssend(server, data, service)
   	  else
  	     nl()
        term.write("No server found")
      end
      to = os.startTimer(timeout)
      timer = nil
      trigger = false
    end
    end--while end
  end
  
  --parallel.waitForAny(req_data, net_recv)
  net_recv()
end
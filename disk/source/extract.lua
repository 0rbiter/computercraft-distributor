--extract
args = { ... }

update = false
local basedir = "/" -- end this with / always
local fold_release = basedir.."release"
local frelease = basedir..".release" 

template = {
  ["begin"] = {
	[1] = "--startup",
  },
  ["func"] = {
	[1] = "function func_#()",
	[2] = "  shell.run(\"/\"..\"#\")",
	[3] = "end",
  },
  ["main"] = {
	[1] = "while true do",
	[2] = "  parallel.waitForAny(#) os.reboot()",
	[3] = "end",
  },
}

new_release = {}
old_release = {}

function clean(directory, tignore)
  if not fs.isDir(directory) then error("clean(): Not a directory: "..directory) end
  if not tignore
    or type(tignore) ~= type(table)
    or not tignore[1]
    then error("clean(): No proper ignore table given")
  end
  
  content = fs.list(directory)
  deleted_any = false
     
  return deleted_any
end

function load_table(filename)
  infile = fs.open(filename, "r")
  if not infile then nl() term.write("Could not open for read "..filename) return nil end
  data = textutils.unserialize(infile.readAll())
  return data
end

function save_file(data, filename)
  outfile = fs.open(filename, "w")
  if not outfile then error("Could not open for write "..filename) return false end
  outfile.write(data)
  res = outfile.flush()
  outfile.close()
  return res  
end

function nl()
  x_max, y_max = term.getSize()
  x, y = term.getCursorPos()
  if y + 1 > y_max then
    y = 1
    while not key == "key" do
      key, event = os.pullEvent()
      sleep(.1)
    end
    sleep(1)
    term.clear()
  else y = y + 1
  end
  term.setCursorPos(1, y)
end

if os.getComputerLabel() == "diskmaster" then
	fold_release = basedir.."release"
	frelease = basedir.."disk/files/build/release" 
end

new_release = load_table(frelease)
if not new_release then return 0 end
old_release = load_table(fold_release)
if not old_release then
  old_release = {}
  old_release.release = -999
end

if type(new_release) ~= type(table) then
  error("Script broken. Could not load release file: "..frelease)
else
  if new_release.release <= old_release.release
    and new_release.release ~= 0 then
    nl()
    term.write("Extract: Nothing to do here")
    error("Normal end")
  end
  term.write(frelease.." version "..new_release.release)
  nl()
  if not old_release  then
    term.write(fold_release.." version "..old_release.release)
    if old_release.release < new_release.release then
      update = true
    elseif old_release.release >= new_release.release then
      term.write("Extractor: "..frelease.." is not newer")
      sleep(1)
      error("Normal end")
    end
  end
end
nl()

if not update then shell.exit() end

ignore_files = new_release["ignore"]
if not ignore_files then error("Could not ignore list") 
else print(textutils.serialize(ignore_files))
end

for k,v in pairs(new_release["files"]) do
  old_v = v
  for kee,val in pairs(v) do
    sleep(.2) 
    if type(val) == type(table) then
      for fname,fdata in pairs(val) do
        sleep(.2)
        if not fs.exists(fname) then
          nl()
          term.write("Creating: "..fname)
          save_file(fdata, fname)
          new_release.files[k][kee][fname] = ""
        elseif fs.exists(fname) then
          nl()
          ignored = new_release.ignore[fname]
          if not ignored then ignored = false end
          if not ignored then
            save_file(fdata, fname)
            new_release.files[k][kee][fname] = ""
            term.write("Overwritten: "..fname.." - "..tostring(ignored))
            sleep(1)
          else
            term.write("Ignored: "..fname.." - "..tostring(ignored))
            sleep(1)
          end
        end
      end
      nl()
    end
  end
  if k == "run" then

    new_func_block = ""
    sout = {}
    sout[1] = template.begin[1]
    --position count for startup gen
    do_cnt = 2
    --iterate through run's filenames
    for name, bulk in pairs(old_v) do
      for z,w in pairs(bulk) do
        fname = z
        nl()
        wname = basedir..fname
        --build func block
        if fs.exists(wname) then
          term.write("Integrating into startup: "..wname)
          --replace # with fname
          new_func_block = new_func_block..
          "func_"..fname..", "
          for i = 1,3 do
            sout[do_cnt] = string.gsub(template.func[i], "#", fname)
            do_cnt = do_cnt + 1
          end
        else
          term.write("Does not exist: "..wname)
          nl()
        end--build func block
      end
    end--iterate through fnames / filenames
    if not new_func_block then error("Problem") end
  elseif k == "once" then
    for bk,valname in pairs(v) do
      for tname, bulk in pairs(valname) do
        fname = tname
       	prepare = string.sub(template.func[2], 2)
        prepare = string.gsub(prepare, "#", fname)
        sout[do_cnt] = prepare
        do_cnt = do_cnt + 1
      end
    end
  end --if k == run elseif == once
end --iter through "files"

new_func_block = string.sub(new_func_block, 1, -3)..""
sout[do_cnt] = template.main[1]
sout[do_cnt+1] = string.gsub(template.main[2], "#", new_func_block)
sout[do_cnt+2] = template.main[3]
do_cnt = do_cnt + 2
outfile = fs.open(basedir.."/startup", "w")
if not outfile then error("Cannot write to "..basedir.."/startup") end
term.clear()
term.setCursorPos(1, 1)
for i = 1,do_cnt do
  nl()
  term.write(i..": "..sout[i])
  outfile.writeLine(sout[i])
end
nl()
outfile.flush()
outfile.close()
if os.getComputerLabel() ~= "diskmaster" then
  fs.delete(fold_release)
  fs.copy(frelease, fold_release)
  fs.delete(frelease)
  os.reboot()
end
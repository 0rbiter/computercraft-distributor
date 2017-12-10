args = { ... }
os.unloadAPI("newlib")
os.loadAPI("/disk/files/source/newlib")

basedir = "disk/files/"
frelease ="/release"

function param_error() end

if args[1] then
  basedir = args[1]
  if fs.exists(basedir) and fs.isDir(basedir) then
    newlib.println("Found base directory "..basedir)
    newlib.println("Creating directories if necessary")
  else
    error("Not a directory: "..basedir)
  end
else
  param_error()
end

dirs = {}

function init_dirs()
  dirs["basedir"] = basedir
  dirs["source"] = basedir.."source"
  dirs["build"] = basedir.."build"
  dirs["old"] = basedir.."old"
  for k,v in pairs(dirs) do
    if not fs.exists(v) then
      fs.makeDir(v)
    elseif not fs.isDir(v) then
      fs.delete(v)
      fs.makeDir(v)
    end
    if k == "build" and fs.isDir(v) then
      frelease = "/"..dirs["build"]..frelease
    end
    if fs.exists(frelease) then
      fs.delete(frelease)
    end
  end
end
init_dirs()
    

if args[2] then
  frelease = args[2]
  if fs.exists(frelease)
    and not fs.isDir(frelease) then
      newlib.println("Deleting "..frelease)
      fs.delete(frelease)
  end
end

function param_error()
  newlib.println("Wrong parameters. Use either:")
  newlib.println(args[0].." basedir")
  newlib.println(" -- creates /release")
  newlib.println(args[0].." basedire newrelease")
  newlib.println(" -- creates build/newrelease")
end


profile_path = "/"..dirs["source"].."/profile"
if fs.exists(profile_path) and not fs.isDir(profile_path) then
  fprofile = profile_path
else
  error("Could not locate release profile: "..profile_path)
end

new_release = newlib.load_table(fprofile)
if type(new_release) == type(table) then
  newlib.println("Profile "..fprofile.." loaded.")
else
  error("Could not load profile "..fprofile)
  return false
end

term.setCursorPos(1,1)
tignore = nil

for k,v in pairs(new_release["files"]) do
  sleep(.2)
  print("Meta: "..k)
  for kee,val in pairs(v) do
    --newlib.println("Funneling \""..basedir..val.. "\" into release file...")
    sleep(.2)
    oldval = v[kee]
    v[kee] = {}
    print("K: "..kee.." - V:"..val)
    --if file doesnt exist it's not transfered?!    
    v[kee][val] = newlib.load_file(dirs["source"].."/"..val)
    if not v[kee][val] then
      print(oldval)
      sleep(.2)
    end
  end
end

if fs.exists(frelease) and not fs.isDir(frelease) then
  newlib.println("Deleting and recreating release file: "..frelease)
end

newlib.save_table(new_release, frelease)
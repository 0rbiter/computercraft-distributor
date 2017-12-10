function count_signs(data, sign)
  counter = 0
  position = 0
  while string.find(data, sign, position) do
    counter = counter + 1
    position = string.find(data, sign, position) + 1
  end
  return counter
end

function get_deepest(tpaths)
  deepest = {}
  deepest["count"] = 0
  deepest["path"] = ""
  for k,v in pairs(tpaths) do
    deep = count_signs(v, "/")
    if deep > deepest["count"] then
      deepest["count"] = deep
      deepest["path"] = v
    end
  end
  return deepest["path"]
end

function sfind(name, depth)
  if not depth then depth = 3 end
  pattern = "*"..name.."*"
  newpath = "/"
  for i = 1,depth do
    lib_path = nil
    apipath = {}
    lib_path = fs.find(newpath..pattern)
    print(textutils.serialize(lib_path))
    if lib_Path ~= {} then
      apipath = get_deepest(lib_path)
      if fs.exists(apipath) and not fs.isDir(apipath) then
        print(apipath)
      end
    end
    newpath = newpath.."*/"
  end
  return false
end
sfind("newlib", 4)
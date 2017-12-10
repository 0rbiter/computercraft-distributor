--update backups
backup = "/backup/"
files = { "newlib", "distributor", "netware", "upd" }
if not fs.isDir(backup) then
  fs.delete(backup)
  fs.makeDir(backup)
end
for k,v in pairs(files) do
  print(backup..v)
  if fs.exists(backup..v) then
    print(v)
    fs.delete(backup..v)
  end
  fs.copy("/"..v, backup..v)
end
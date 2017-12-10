--diskmaster
os.loadAPI("/disk/files/source/newlib")
basedir = "/disk/server"

function updater_service()
  shell.run(basedir.."/netware")
end

function monitor_service()
  shell.run(basedir.."/screen")  
end

while true do
  parallel.waitForAny(updater_service(), monitor_service())
end
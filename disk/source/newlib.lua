--newlib
local burnratio = 12

function nl()
  x_max, y_max = term.getSize()
  x, y = term.getCursorPos()
  if y + 1 <= y_max then
    y = y + 1
  else
    term.clear()
    y = 1
  end
  x = 1
  term.setCursorPos(x, y) 
end


function println(text)
  x_max, y_max = term.getSize()
  x, y = term.getCursorPos()
  if (y + 1) <= y_max then
    term.setCursorPos(1, y+1)
  elseif (y + 1) > y_max then
    term.clear()
    term.setCursorPos(1, 1)
  end
  term.write(textutils.pagedPrint(text))
end

function set_label(modus)
  os.setComputerLabel(modus..os.getComputerID())
end

function pulse(side, times)
  for i = 1, times do
    redstone.setOutput(side, true)
    sleep(.5)
    redstone.setOutput(side, false)
    sleep(.5)
  end
end

function get_itemcount(slottable)
  if slottable == {0} then
    slottable = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 }
  end
  ic = 0
  for k,v in pairs{slottable} do
    ic = ic + turtle.getItemCount(v)
  end
  return ic
end
function act_direction(mode, amount, direction)
  if direction == "up" then
    if mode == "suck" then
      return turtle.suckUp(amount)
    else
      return turtle.dropUp(amount)
    end
  else
    if direction == "front" then
      if mode == "suck" then
        return turtle.suck(amount)
      else
        return turtle.drop(amount)
      end
    else
      if direction == "down" then
        if mode == "suck" then
          return turtle.suckDown(amount)
        else
          return turtle.dropDown(amount)
        end
      else
        return false
      end
    end
  end
      
end

function is_empty(amount, direction, slottable, amount)
  empty = true
  -- get itemcount of all slots in table
  ic = get_itemcount({0})

  -- probe in direction
  result = false
  oldic = get_itemcount({0})
  if act_direction("suck", amount, direction) then
    ic = get_itemcount({0})
    act_direction("drop", (ic - oldic), direction)
  else
    result = true
  end
end

function get_mode()
  return turtle.getItemCount(15)
end

function get_burnratio()
  return turtle.getItemCount(16)
end

function feed_burner(itemcount)
  result = false
  if turtle.getItemCount(turtle.getSelectedSlot()) >= itemcount then
    turtle.dropDown(itemcount)
    return true
  end
  return result
end

function isme(label)
  if os.getComputerLabel() == label then
    return true
  else
    return false
  end
end


function load_file(filename)
  if not filename then
    error("load_file needs a filename")
    return false
  end
  infile = fs.open(filename, "r")
  data = {}
  if infile then
    data = infile.readAll()
  else
    term.write("Could not open "..filename.." for read")
    return nil
  end
  return data
end

function load_table(filename)
  return textutils.unserialize(load_file(filename))
end

function save_file(data, filename)
  outfile = fs.open(filename, "w")
  if not outfile then error("Could not open "..filename.." for write") return false end
  outfile.write(data)
  result = outfile.flush()
  outfile.close()
  return result
end

function save_table(ttable, filename)
  return save_file(textutils.serialize(ttable), filename)
end

function get_key(value, ttable)
  result = 0
  if type(ttable) ~= type(table) then return 0 end
  for k,v in pairs(ttable) do
    if value == v then
      result = k
    end
  end
  return result
end

function getfilelist(ign_files)  
  tin = fs.list("")
  tout = {}
  for k,v in pairs(tin) do
    if not fs.isDir(v)  --ignore directories
      and not fs.isReadOnly(v)  --ignore ro's
        and not ign_files[v]   --if on ignore lists
          and not (get_key(v, ign_files) > 0) then
       tout[k] = v
     end
  end
  return tout
end

function wipe(ign_files)
  files = getfilelist(ign_files)
  if not files then print("nothing found") return false end
  for no,file in pairs(files) do
    println("Deleting "..file.." ...")
    --fs.delete("/"..file)
  end
end

local rot = nil

rot_file = "/.rot"
if not rot and turtle then
  if fs.exists(rot_file) then
    rot = load_table(rot_file)
    if not rot then
      error("no table in "..rot_file)
    end --end if not load table
  else
    error("No rotation file "..rot_file)
  end --end if file exists rot_table
end     --end if not rot

function rotate(to_pos)
  local ttemp = {}
  ttemp = load_table(rot_file)
  for k,v in pairs(ttemp.direct) do
    if to_pos == k
      and k == "left" then
      turtle.turnLeft()
    elseif to_pos == k
      and k == "right" then
      turtle.turnRight()
    end
  end
  if to_pos == "left" or to_pos == "right" then
    return true
  else
  
  local res = 0
  local dir = heading()
  --print(textutils.serialize(ttemp.indirect))
  local newdir = ttemp.indirect[to_pos].number
  res = dir - newdir
  if res == 2 or res == -2 then 
    rotate("left")
    rotate("left")
  elseif res == 1 or res == -3 then
    rotate("left")
  elseif res == -1 or res == 3 then
    rotate("right")
  end

  local new_heading = 0
  new_heading = heading() - res  
  for k,v in pairs(ttemp.indirect) do
    if ttemp.indirect[k].number == new_heading then
        ttemp.indirect[k].heading = true
    else
        ttemp.indirect[k].heading = false
    end
  end
  save_table(ttemp, rot_file)
  end
end

function heading()
  local ttemp = load_table(rot_file)
  for k,v in pairs(ttemp.indirect) do
    if v.heading then
      return v.number
    end
  end
end
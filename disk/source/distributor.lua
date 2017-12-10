--distributor neu
if not newlib then os.loadAPI("/newlib") end
burnratio = newlib.get_burnratio()
mode = newlib.get_mode()

while mode == 0 do
  term.write("Not configured")
  local event, p1 = os.pullEvent("turtle_inventory")
  sleep(10)
  burnratio = newlib.get_burnratio()
  if burnratio > 0 and newlib.get_mode() > 0 then
    mode = newlib.get_mode()
  end
end

while mode == 2 do
  newlib.set_label("secondary")
  dropratio = burnratio - 1
  if turtle.getItemCount(1) >= burnratio then
    turtle.drop(dropratio)
    turtle.dropDown(1)
    newlib.rotate("left")
  else
    turtle.suckUp(burnratio)
  end
  sleep(.1)
end

while mode == 3 do
  turtle.placeUp()
  sleep(1)
  turtle.placeUp()
  newlib.set_label("tertiary")
  if turtle.getItemCount(1) >= 1 then
    turtle.select(1)
    turtle.drop(1)
    newlib.rotate("left")
  end
  sleep(.1)
end

idlecounter = 0
early_offset = 3
burntime = 30
before = 1
rounds = 0
while mode == 1 do
  newlib.set_label("primary")
  before = os.clock()
  if not (turtle.getItemCount(1) >= burnratio) then
    turtle.suckUp(burnratio - turtle.getItemCount(1))
  else
    turtle.drop(burnratio)
    rounds = rounds + 1
    newlib.nl()
    term.write("Round No. "..rounds)
    newlib.rotate("left")
    newlib.nl()
    term.write("Heading: "..newlib.heading())
    --before = os.clock()
  end
  if rounds >= 5 then
    rounds = 0
    --burntime = 30
    now = os.clock()
    delta = now - before
    if delta <= (burntime- early_offset) then
      newlib.nl()
      term.write("Sleeping for "..(burntime-delta-early_offset).. "seconds")
      sleep(burntime - delta - early_offset)
    end
    before = os.clock()
  end
  sleep(.2)
end
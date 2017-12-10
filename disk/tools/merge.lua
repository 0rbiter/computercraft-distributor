args = { ... }
files = {}
buffer = ""
function read_file(filename)
  infile = fs.open(filename, "r")
  if infile then
    ibuffer = infile.readAll()
    infile.close()
  end
  return ibuffer
end

function save_file(data1, data2, filename)
  outfile = fs.open(filename, "w")
  result = nil
  if outfile then
    outfile.write(data1)
    outfile.writeLine("")
    outfile.write(data2)
    result = outfile.flush()
    outfile.close()
  end
  return result
end
for k,v in pairs(args) do files[k] = v end
if #files < 3 then error("Not enough items.") end

save_file(read_file(files[1]), read_file(files[2]),files[3])
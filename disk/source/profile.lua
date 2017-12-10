
{
  release = 24,
  files = {
    run = {
      [1] = "netware",
      [2] = "distributor",
    },
    api = {
      "newlib",
      ".rot",
    },
    once = {
      [1] = "extract",
    },
  },
  ignore = {
    ["rom"] = true,
    [".release"] = true,
    [".temp"] = true,
    [".rot"] = true,
    ["disk"] = true,
    ["disk2"] = true,
    ["disk3"] = true,
  },
}
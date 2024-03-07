local util  = require "luci.util"
local fs  = require "nixio.fs"
local jsonc = require "luci.jsonc"

local dsm = {}

dsm.blocks = function()
  local f = io.popen("lsblk -s -f -b -o NAME,FSSIZE,MOUNTPOINT --json", "r")
  local vals = {}
  if f then
    local ret = f:read("*all")
    f:close()
    local obj = jsonc.parse(ret)
    for _, val in pairs(obj["blockdevices"]) do
      local fsize = val["fssize"]
      if fsize ~= nil and string.len(fsize) > 10 and val["mountpoint"] then
        -- fsize > 1G
        vals[#vals+1] = val["mountpoint"]
      end
    end
  end
  return vals
end

dsm.home = function()
  local uci = require "luci.model.uci".cursor()
  local home_dirs = {}
  home_dirs["main_dir"] = uci:get_first("quickstart", "main", "main_dir", "/root")
  home_dirs["Configs"] = uci:get_first("quickstart", "main", "conf_dir", home_dirs["main_dir"].."/Configs")
  home_dirs["Public"] = uci:get_first("quickstart", "main", "pub_dir", home_dirs["main_dir"].."/Public")
  home_dirs["Downloads"] = uci:get_first("quickstart", "main", "dl_dir", home_dirs["Public"].."/Downloads")
  home_dirs["Caches"] = uci:get_first("quickstart", "main", "tmp_dir", home_dirs["main_dir"].."/Caches")
  return home_dirs
end

dsm.find_paths = function(blocks, home_dirs, path_name)
  local default_path = ''
  local configs = {}

  default_path = home_dirs[path_name] .. "/Dsm"
  if #blocks == 0 then
    table.insert(configs, default_path)
  else
    for _, val in pairs(blocks) do 
      table.insert(configs, val .. "/" .. path_name .. "/Dsm")
    end
    local without_conf_dir = "/root/" .. path_name .. "/Dsm"
    if default_path == without_conf_dir then
      default_path = configs[1]
    end
  end

  return configs, default_path
end

dsm.hasGpu = function()
  return fs.stat("/dev/dri", "type") == "dir"
end

local function findLast(haystack, needle)
  local i=haystack:match(".*"..needle.."()")
  if i==nil then return nil else return i-1 end
end

dsm.defaultNet = function()
  local defNet = {}
  local ip = util.trim(util.exec("ubus call network.interface.lan status | jsonfilter -e '@[\"ipv4-address\"][0].address'"))
  local mask = util.trim(util.exec("ubus call network.interface.lan status | jsonfilter -e '@[\"ipv4-address\"][0].mask'"))
  if ip ~= nil and ip ~= "" then
    local p = findLast(ip, "%.")
    if p ~= nil then
      defNet["ip"] = string.sub(ip,1,p) .. "66"
      defNet["ipmask"] = string.sub(ip,1,p) .. "0/" .. mask
    end
    defNet["gateway"] = ip
    return defNet
  end

  defNet["ip"] = "192.168.100.77"
  defNet["ipmask"] = "192.168.100.0/24"
  defNet["gateway"] = "192.168.100.1"
  return defNet
end

return dsm


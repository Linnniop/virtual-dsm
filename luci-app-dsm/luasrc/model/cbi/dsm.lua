--[[
LuCI - Lua Configuration Interface
]]--

local taskd = require "luci.model.tasks"
local docker = require "luci.docker"
local dsm_model = require "luci.model.dsm"
local m, s, o

m = taskd.docker_map("dsm", "main", "/usr/libexec/istorec/dsm.sh",
	translate("SynologyDSM"),
	translate("SynologyDSM is Virtual DSM in a Docker container. You can only run in Synology Device.")
		.. translate("OpenSource link:") .. ' <a href=\"https://github.com/vdsm/virtual-dsm\" target=\"_blank\">https://github.com/vdsm/virtual-dsm</a>')

local dk = docker.new({socket_path="/var/run/docker.sock"})
local dockerd_running = dk:_ping().code == 200
local docker_info = dockerd_running and dk:info().body or {}
local docker_aspace = 0
if docker_info.DockerRootDir then
	local statvfs = nixio.fs.statvfs(docker_info.DockerRootDir)
	docker_aspace = statvfs and (statvfs.bavail * statvfs.bsize) or 0
end

s = m:section(SimpleSection, translate("Service Status"), translate("SynologyDSM status:"))
s:append(Template("dsm/status"))

s = m:section(TypedSection, "main", translate("Setup"),
		(docker_aspace < 2147483648 and
		(translate("The free space of Docker is less than 2GB, which may cause the installation to fail.") 
		.. "<br>") or "") .. translate("The following parameters will only take effect during installation or upgrade:"))
s.addremove=false
s.anonymous=true

o = s:option(Flag, "macvlan", translate("MacVlan") .. "<b>*</b>")
o.default = 1
o.rmempty = false

o = s:option(Value, "port", translate("Port").."<b>*</b>")
o.default = "5000"
o.datatype = "port"
o:depends("macvlan", 0)

local defaultNet = dsm_model.defaultNet()

o = s:option(Value, "ip", translate("IP").."<b>*</b>")
o.default = defaultNet.ip
o.datatype = "string"
o:depends("macvlan", 1)

o = s:option(Value, "ipmask", translate("IpMask").."<b>*</b>")
o.default = defaultNet.ipmask
o.datatype = "string"
o:depends("macvlan", 1)

o = s:option(Value, "gateway", translate("Gateway").."<b>*</b>")
o.default = defaultNet.gateway
o.datatype = "string"
o:depends("macvlan", 1)

o = s:option(Value, "cpucore", translate("CPU core number").."<b>*</b>")
o.rmempty = false
o.datatype = "string"
o:value("2", "2")
o:value("4", "4")
o:value("8", "8")
o:value("16", "16")
o.default = "2"

o = s:option(Value, "ramsize", translate("RAM size").."<b>*</b>")
o.rmempty = false
o.datatype = "string"
o:value("2G", "2G")
o:value("4G", "4G")
o:value("8G", "8G")
o:value("16G", "16G")
o.default = "2G"

o = s:option(Value, "disksize", translate("Disk size").."<b>*</b>")
o.rmempty = false
o.datatype = "string"
o:value("20G", "20G")
o:value("40G", "40G")
o:value("800G", "800G")
o:value("160G", "160G")
o.default = "40G"

if dsm_model.hasGpu() then
  o = s:option(Flag, "gpu", translate("GPU"), translate("GPU accelerate"))
  o.default = 1
  o.rmempty = false
end

o = s:option(Value, "image_name", translate("Image").."<b>*</b>")
o.rmempty = false
o.datatype = "string"
o.default = "vdsm/virtual-dsm"

local blocks = dsm_model.blocks()
local home = dsm_model.home()

o = s:option(Value, "storage_path", translate("Storage path").."<b>*</b>")
o.rmempty = false
o.datatype = "string"

local paths, default_path = dsm_model.find_paths(blocks, home, "Configs")
for _, val in pairs(paths) do
  o:value(val, val)
end
o.default = default_path

return m


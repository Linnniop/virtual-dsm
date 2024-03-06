
module("luci.controller.dsm", package.seeall)

function index()
  entry({"admin", "services", "dsm"}, alias("admin", "services", "dsm", "config"), _("SynologyDSM"), 30).dependent = true
  entry({"admin", "services", "dsm", "config"}, cbi("dsm"))
end

local result = proxyrequire("./dependency", "@"..debug.info(1, "s"))
result[#result] = "required into proxy_requirer"
return result

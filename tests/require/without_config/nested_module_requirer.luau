local result = require("./nested")
result[#result] = "required into module"
return result

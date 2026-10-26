local result = require("./nested_inits")
result[#result] = "required into module"
return result

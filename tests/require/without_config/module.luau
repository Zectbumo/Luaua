local result = require("./dependency")
result[#result] = "required into module"
return result

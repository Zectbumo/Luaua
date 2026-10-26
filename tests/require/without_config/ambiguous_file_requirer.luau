local result = require("./ambiguous/file/dependency")
result[#result] = "required into module"
return result

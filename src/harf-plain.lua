local harf = require("harf")

for name, func in next, harf.callbacks do
  callback.register(name, func)
end

package.path = "lualib/?.lua;lualib/?/init.lua;"
package.cpath = "luaclib/?.so"

for line in io.popen("env"):lines() do
    local root =string.match(line, "LUACHECKROOT=(.*)")
    if root then
        package.path = root .. "/lualib/?.lua;" ..root.."/lualib/?/init.lua;"
        package.cpath = root .. "/luaclib/?.so"
        break
    end
end

require "luacheck.main"
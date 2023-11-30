local pretty = require "cc.pretty"

local add = require "commands.add"
local signup = require "commands.signup"
local post = require "commands.post"
local yank = require "commands.yank"
local init = require "commands.init"
local help = require "commands.help"
local install = require "commands.install"
local session = require "commands.session"
local inc = require "commands.increaseVersion"

local args = {...}

local commandsTable = {
    add = add,
    signup = signup,
    post = post,
    yank = yank,
    init = init,
    help = help,
    login = session.login,
    logout = session.logout,
    install = install,
    patch = inc.patch,
    minor = inc.minor,
    major = inc.major
}

local helpMessage = "Run luam help for more details on proper usage"

function main()
    if #args < 1 then
        error({
            message = {"At least one argument should be provided!", helpMessage}
        })
    end

    if commandsTable[args[1]] then
        commandsTable[args[1]](args)
    else
        error({
            message = {args[1] .. " is not a valid command!", helpMessage}
        })
    end
end

local start = os.clock()
local status, err = pcall(main)

if (err) then
    if type(err) == "table" and err.message then
        for _, message in ipairs(err.message) do
            print(message)
        end
    elseif type(err) == "table" then
        pretty.pretty_print(err)
    else
        print(err)
    end
end

print("Finished in " .. string.format("%.3f", os.clock() - start) .. "s")

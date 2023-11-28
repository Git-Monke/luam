function printHelp(args)
    if #args == 1 then
        -- ? There has to be a better way to organize this.
        -- ? Maybe pre written files that are just loaded in?

        print("All text in <> are required arguments.")
        print("All text in [] are optional")
        print("")
        print("All commands:")
        print("    luam help [command name] -- Prints out instructions on how to use the luam CLI")
        print("    luam install <name> [version] -- Installs the package specified by name and optionally a version")
        print("    luam post -- Posts your package to the registry (for both updates and uploads)")
        print("    luam init [--exe|--lib] <name> -- Creates a new luam package (which are by default executables)")
        print("    luam signup <github token> -- Verifies your github account and signs you up to luam")
        print(
            "    luam login <auth token> -- Stores your luam authorization token in _ENV (required for posting packages)")
        print("    luam logout -- Removes your login token from _ENV")
    end
end

return printHelp

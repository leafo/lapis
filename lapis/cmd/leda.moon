import dump from require 'moonscript.util'
lfs = require 'lfs'
config = require 'lapis.config'
local *

class Leda
    paths: {
        "/usr/local/bin"
        "/usr/bin"
    }
    
    new: =>
        bin = "leda"
        table.insert(@paths, os.getenv("LAPIS_LEDA"))
        for path in *@paths
            path = path .. "/" .. "leda" 
            
            -- a simple file presence check here
            if lfs.attributes path
                @bin = path
                
    start: (environment) =>
        port  = config.get!.port
        host = config.get!.host or 'localhost'

        print("starting server on #{host}:#{port} in environment #{environment}. Press Ctrl-C to exit")
        
        env = ""
        if environment == 'development'
            env="LEDA_DEBUG=1"
        
        execute = "#{env} #{@bin} --execute='require(\"lapis\").serve(\"app\")'"
        
        os.execute(execute)            
                
leda = Leda!        
    
find_leda  = ->
    leda.bin
    
start_leda  = (environment )->
    leda\start(environment)
    
{:find_leda, :start_leda}
                
    
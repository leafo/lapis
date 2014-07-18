local mimetypes = require 'lapis.leda.mimetypes'
local dictionary = require 'leda.dictionary'
local utility = require 'leda.utility'
local lfs = require 'lfs'

local export = {}
function serve(path, request, response)
    -- assume that path is relative to the second slash
    local slash = request.parsed_url.path:find("/", 2)

    if not slash  then
        response.status = 404
        return {layout=false}
    end
    
    local filePath = request.parsed_url.path:sub(slash)
    
    path = path ..  filePath
    --
    local attributes = lfs.attributes(path)
    
    if not attributes then
        -- file not found
        response.content = request.parsed_url.path ..' not found'
        response.status = 404
        return {layout=false}
    end
    
    local maxAge = 43200
    
    response.headers['Cache-Control'] = string.format("max-age=%s, public", maxAge)
    local modificationTime = attributes.modification
     
     -- check etag
    local etag = request.headers['if-none-match']
    local state = dictionary.get(path)


    if state then
        -- check etag age
        local allowedTime = os.time()
        if (state.updated + maxAge < allowedTime) or (modificationTime ~= tonumber(state.modification))  then 
            dictionary.delete(path)
            state = nil
        end
    end
    
    if state and etag then
        if etag == state.tag and modificationTime == tonumber(state.modification) then
            -- return 304
            response.status = 304   
            response.headers['Etag'] = etag
            response.content = ''
            return {layout=false}
        end
    end
    
    local file = io.open(path, "rb")
    response.status = 200    
    -- read file and set response content 
    response.content = file:read("*all")
    file:close()

    -- guess mime type
    response.headers['Content-Type'] =  mimetypes.guess(path)
    -- set last modified header
    response.headers['Last-Modified'] = utility.formatTime(modificationTime)
    --  generate etag
    local etag = tostring(os.time()) .. tostring(math.random(100000, 800000))
    -- save etag
    if not state then
         state = {modification = modificationTime, tag = etag, updated = os.time()}    
         dictionary.set(path, state)
      end
        
    response.headers['Etag'] = state.tag
    
    return {layout=false}
end

export.serve = serve
return export
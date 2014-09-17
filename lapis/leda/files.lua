local mimetypes = require 'mimetypes'
local dict = require 'leda.dict'
local util = require 'leda.util'
local lfs = require 'lfs'

require 'middleclass'

local export = {}

local FileState = class('FileState')

FileState.fields = {'modification', 'tag', 'timestamp'}
function FileState:initialize(key)
    self.key = key
end


function FileState:_fieldKey(field)
    return self.key .. field
end

function FileState:get()
    local value
    for _, field in ipairs(self.fields) do
        value = dict.get(self:_fieldKey(field))
        self[field] = value
    end

    if not value then return end
    self.timestamp = tonumber(self.timestamp)
    self.modification = tonumber(self.modification)

    return self
end

function FileState:save()
    for _, field in ipairs(self.fields) do
        if self[field] then dict.set(self:_fieldKey(field), tostring(self[field])) end
    end
end

function FileState:delete()
    for _, field in ipairs(self.fields) do
        dict.delete(self:_fieldKey(field))
        self[field] = nil
    end
end

function serve(path)
    return function(self)
        local request = self.req
        local response = self.res
        path = path .. "/".. self.params.splat
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
        local fileState = FileState(path, {'modification', 'tag', 'timestamp'})

        if fileState:get() then
            -- check etag age
            local allowedTime = os.time()
            if (fileState.timestamp + maxAge < allowedTime) or (modificationTime ~= fileState.modification)  then
                fileState:delete()
            end
        end

        if fileState.tag and etag then
            if etag == fileState.tag and modificationTime == fileState.modification then
                -- return 304
                response.status = 304
                response.headers['Etag'] = etag
                response.content = ''
                return {layout=false}
            end
        end

        local file = io.open(path, "rb")
        if not file then
            response.status = 404
            return {layout=false}
        end

        response.status = 200
        -- read file and set response content
        response.content = file:read("*all")

        file:close()

        -- guess mime type
        response.headers['Content-Type'] =  mimetypes.guess(path)
        -- set last modified header
        response.headers['Last-Modified'] = util.formatTime(modificationTime)
        --  generate etag
        local etag = tostring(os.time()) .. tostring(math.random(100000, 800000))
        -- save etag
        if not fileState.tag then
            fileState.tag = etag
            fileState.modification = modificationTime
            fileState.timestamp = os.time()
            fileState:save()
        end

        -- set response header
        response.headers['Etag'] = fileState.tag

        return {layout=false}
    end
end

export.serve = serve
return export
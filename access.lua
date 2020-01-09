local _M = {}

local validation = require "resty.validation"
local cjson = require "cjson"

local function check(rule, result, query_arg, name)
    local type = rule.type
    local required = rule.required
    local empty, e = validation.null(query_arg)
    kong.log.err(query_arg)
    kong.log.err(empty)
    if required then
        if empty then
            table.insert(result, name .. " is required")
        end
    end
    if type then
        if not empty and type == "string" then
            local ok, e = validation.string(query_arg)
            if ok == false then
                table.insert(result, name .. "must be string")
            end
        end
        if not empty and type == "number" then
            local ok, e = validation.number(tonumber(query_arg))
            if ok == false then
                table.insert(result, name .. " must be number")
            end
        end
    end
end

local function request_validator(conf)
    local result = {}
    local query_schema, body_schema = null
    if conf.query_schema then
        query_schema = cjson.decode(conf.query_schema)
    end
    if conf.body_schema then
        body_schema = cjson.decode(conf.body_schema)
    end
    if query_schema then
        for i, v in ipairs(query_schema) do
            local name = v.name
            local query_arg = kong.request.get_query_arg(name)
            check(v, result, query_arg, name)
        end
    end
    local body, err, mimetype = kong.request.get_body()
    if not body then
        body={}
    end
    if body_schema then
        for i, v in ipairs(body_schema) do
            local name = v.name
            local body_arg = body[name]
            check(v, result, body_arg, name)
        end
    end
    if table.getn(result) > 0 then
        return kong.response.exit(400, { message = result })
    end
end

function _M.execute(conf)
    request_validator(conf)
end

return _M

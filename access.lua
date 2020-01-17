local _M = {}

local validation = require "resty.validation"
local cjson = require "cjson"
local jsonschema = require 'jsonschema'

local function check(rule, result, query_arg, name)
    local type = rule.type
    local required = rule.required
    local empty, e = validation.null(query_arg)
    local len_eq = rule.len_eq
    local len_min = rule.len_min
    local len_max = rule.len_max
    local max = rule.max
    local min = rule.min
    local eq = rule.eq
    local un_eq = rule.un_eq
    local email = rule.email

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
    if len_eq then
        if not empty and type == "string" then
            local ok, e = validation.optional:len(len_eq, len_eq)(query_arg)
            if ok == false then
                table.insert(result, name .. " length must = " .. tostring(len_eq))
            end
        end
    end
    if len_min then
        if not empty and type == "string" then
            local ok, e = validation.optional:minlen(len_min)(query_arg)
            if ok == false then
                table.insert(result, name .. " length must >= " .. tostring(len_min))
            end
        end
    end
    if len_max then
        if not empty and type == "string" then
            local ok, e = validation.optional:maxlen(len_max)(query_arg)
            if ok == false then
                table.insert(result, name .. " length must <= " .. tostring(len_max))
            end
        end
    end
    if min then
        if not empty and type == "number" then
            local ok, e = validation.optional:min(min)(tonumber(query_arg))
            if ok == false then
                table.insert(result, name .. " must >= " .. tostring(min))
            end
        end
    end
    if max then
        if not empty and type == "number" then
            local ok, e = validation.optional:max(max)(tonumber(query_arg))
            if ok == false then
                table.insert(result, name .. " must <= " .. tostring(max))
            end
        end
    end
    if eq then
        if not empty then
            local ok, e = validation.optional:equals(eq)(query_arg)
            if ok == false then
                table.insert(result, name .. " must == " .. tostring(eq))
            end
        end
    end
    if un_eq then
        if not empty then
            local ok, e = validation.optional:unequals(eq)(query_arg)
            if ok == false then
                table.insert(result, name .. " must unequal " .. tostring(un_eq))
            end
        end
    end
    if email then
        if not empty and type == "string" and email then
            local ok, e = validation.optional:email()(query_arg)
            if ok == false then
                table.insert(result, name .. " must be email")
            end
        end
    end
end

local function get_schema(schema)
    local result = nil
    if schema then
        result = cjson.decode(schema)
    end
    return result
end

local function isTableEmpty(t)
    return t == nil or next(t) == nil
end

local function request_validator(conf)
    local result = {}
    local cache = kong.cache
    local content_type = kong.request.get_header("Content-Type")
    local cache_prefix = tostring(conf.updated_at)

    --local query_schema,form_schema, json_schema = null

    --if conf.query_schema then
    --    query_schema = cjson.decode(conf.query_schema)
    --end
    --if conf.form_schema then
    --    form_schema = cjson.decode(conf.form_schema)
    --end
    --if conf.json_schema then
    --    json_schema = cjson.decode(conf.json_schema)
    --end

    if conf.query_schema then
        local query_schema, err = cache:get(cache_prefix .. 'query_schema', nil,
                get_schema, conf.query_schema)
        --local query_schema = cjson.decode(conf.query_schema)
        if query_schema then
            for i, v in ipairs(query_schema) do
                local name = v.name
                local query_arg = kong.request.get_query_arg(name)
                check(v, result, query_arg, name)
                if table.getn(result) > 0 then
                    break
                end
            end
        end
    end

    if conf.form_schema then
        local form_schema, err = cache:get(cache_prefix .. 'form_schema', nil,
                get_schema, conf.form_schema)
        --local form_schema = cjson.decode(conf.form_schema)
        if isTableEmpty(result) and (content_type == 'application/x-www-form-urlencoded' or content_type == 'multipart/form-data') and form_schema then
            local body, err, mimetype = kong.request.get_body()
            if body then
                for i, v in ipairs(form_schema) do
                    local name = v.name
                    local body_arg = body[name]
                    check(v, result, body_arg, name)
                    if not isTableEmpty(result) then
                        break
                    end
                end
            end
        end
    end
    -- kong.log.err(conf.json_schema)
    if conf.json_schema then
        local json_schema, err = cache:get(cache_prefix .. 'json_schema', nil,
                get_schema, conf.json_schema)
        --local json_schema = cjson.decode(conf.json_schema)
        --kong.log.err(content_type)
        if isTableEmpty(result) and content_type == 'application/json' and json_schema then
            local body, err, mimetype = kong.request.get_body()
            --kong.log.err(body)
            if body then
                local validator = jsonschema.generate_validator(json_schema)
                local res, message = validator(body)
                if not res then
                    table.insert(result, message)
                end
            end
        end
    end

    if not isTableEmpty(result) then
        return kong.response.exit(400, { message = result })
    end
end

function _M.execute(conf)
    request_validator(conf)
end

return _M

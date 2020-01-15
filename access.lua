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
            local ok, e = validation.optional:min(min)(query_arg)
            if ok == false then
                table.insert(result, name .. " must >= " .. tostring(min))
            end
        end
    end
    if max then
        if not empty and type == "number" then
            local ok, e = validation.optional:max(max)(query_arg)
            if ok == false then
                table.insert(result, name .. " must <= " .. tostring(max))
            end
        end
    end
    if eq then
        if not empty and type == "number" then
            local ok, e = validation.optional:equals(eq)(query_arg)
            if ok == false then
                table.insert(result, name .. " must == " .. tostring(eq))
            end
        end
    end
    if un_eq then
        if not empty and type == "number" then
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

local function request_validator(conf)
    local result = {}
    local query_schema, form_schema, json_schema = null
    if conf.query_schema then
        query_schema = cjson.decode(conf.query_schema)
    end
    if conf.form_schema then
        form_schema = cjson.decode(conf.form_schema)
    end
    if conf.json_schema then
        json_schema = cjson.decode(conf.json_schema)
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
        body = {}
    end
    if form_schema then
        for i, v in ipairs(form_schema) do
            local name = v.name
            local body_arg = body[name]
            check(v, result, body_arg, name)
        end
    end
    if json_schema then
        local validator = jsonschema.generate_validator(json_schema)
        local res, message = validator(body)
        if not res then
            table.insert(result, message)
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

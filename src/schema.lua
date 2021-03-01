local typedefs = require "kong.db.schema.typedefs"
local plugin_name = ({...})[1]:match("^kong%.plugins%.([^%.]+)")

local function validate_fields(config)
    if config.form_schema
    or config.query_schema
    or config.json_schema
    then
      return true
    end
  
    return nil, "at least one of these fields must be true: form_schema, query_schema, json_schema"
end

return {
  name = plugin_name,
  fields = {
    { consumer = typedefs.no_consumer },
    {
      config = {
        type = "record",
        fields = {
          { form_schema = { 
            type = "string",
            required = false
          }, },
          { query_schema = { 
            type = "string",
            required = false
          }, },
          { json_schema = { 
            type = "string",
            required = false
          }, },
          { updated_at = typedefs.auto_timestamp_ms },
        },
        entity_checks = {
          { at_least_one_of = { "form_schema", "query_schema", "json_schema" }, },
        },
      },
    },
  },
}

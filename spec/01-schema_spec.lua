local PLUGIN_NAME = "kong-plugin"

-- helper function to validate data against a schema
local validate do
  local validate_entity = require("spec.helpers").validate_plugin_config_schema
  local plugin_schema = require("kong.plugins."..PLUGIN_NAME..".schema")

  function validate(data)
    return validate_entity(data, plugin_schema)
  end
end


describe(PLUGIN_NAME .. ": (schema)", function()


  it("accepts my_restrictive_array is one one the options - true", function()
    local ok, err = validate({
        my_restrictive_array = { "GET" },
      })
    assert.is_nil(err)
    assert.is_truthy(ok)
  end)

  it("accepts my_restrictive_array is one one the options - false", function()
    local ok, err = validate({
        my_restrictive_array = { "POTATO" },
      })
    assert.is_nil(ok)
    assert.is_truthy(err)
  end)


end)

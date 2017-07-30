attributes =
  is_online:
    label: "Can Heat?"
    description: "If unit has ability to heat"
    type: "boolean"
  ambient_temperature:
    label: "Room Temp"
    description: "Ambient Room Temperature"
    type: "number"
    discrete: true
    unit: "°"
  can_cool:
    label: "Can Cool?"
    description: "If unit has ability to cool"
    type: "boolean"
  can_heat:
    label: "Can Heat?"
    description: "If unit has ability to heat"
    type: "boolean"
  humidity:
    label: "Humidity"
    description: "Current Humidity"
    type: "number"
    unit: "%"
  has_leaf:
    label: "Leaf"
    description: "thermostat should show a leaf"
    type: "boolean"
  hvac_mode:
    label: "Mode"
    description: "Thermostat Mode"
    type: "string"
    enum: ["heat-cool", "heat", "cool", "eco", "off"]
  hvac_state:
    label: "HVAC State"
    description: "Thermostat State"
    type: "string"
    enum: ["off", "heating", "cooling"]
  is_locked:
    description: "Lock State of the Thermostat"
    type: "boolean"
  target_temperature:
    label: "Target Temp"
    description: "The temp that should be set"
    type: "number"
    discrete: true
    unit: "°"
  target_temperature_low:
    description: "The min temp for heat-cool mode"
    label: "Low"
    type: "number"
    discrete: true
    unit: "°"
  target_temperature_high:
    description: "The max temp for heat-cool mode"
    label: "High"
    type: "number"
    discrete: true
    unit: "°"
  locked_temp_min:
    description: "Min Temp of Locked Thermostat"
    type: "number"
    unit: "°"
  locked_temp_max:
    description: "Max Temp of Locked Thermostat"
    type: "number"
    unit: "°"
  eco_temperature_high:
    label: "Away Temp High"
    description: "The temp that should be set"
    type: "number"
    unit: "°"
  eco_temperature_low:
    label: "Away Temp Low"
    description: "The temp that should be set"
    type: "number"
    unit: "°"



attributeNames = (unit) ->
  attrNames = (attr for attr, value of attributes)
  for attr, i in attrNames when attr.includes("temp")
    attrNames[i] = "#{attr}_#{unit}"
  attrNames


updateAttributes = (attrs, unit) ->
  for attr, props of attrs when props.unit is "°"
    attrs[attr].unit = "°#{unit.toUpperCase()}"
  return attrs




module.exports =
  attributes: attributes
  getAttributeNames: attributeNames
  updateAttributes: updateAttributes
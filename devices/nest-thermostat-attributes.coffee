attributes =
  ambient_temperature:
    label: "Room Temp"
    description: "Ambient Room Temperature"
    type: "number"
    discrete: true
    unit: "°"
  away_temperature_high:
    label: "Away Temp High"
    description: "The temp that should be set"
    type: "number"
    discrete: true
    unit: "°"
  away_temperature_low:
    label: "Away Temp Low"
    description: "The temp that should be set"
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
    discrete: true
    unit: "%"
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
  is_online:
    label: "Can Heat?"
    description: "If unit has ability to heat"
    type: "boolean"
  target_temperature:
    label: "Target Temp"
    description: "The temp that should be set"
    type: "number"
    discrete: true
    unit: "°"



attributeNames = (unit) ->
  attrNames = (attr for attr, value of attributes)
  for attr, i in attrNames when attr.includes("temperature")
    attrNames[i] = "#{attr}_#{unit}"
  attrNames

module.exports =
  attributes: attributes
  getAttributeNames: attributeNames
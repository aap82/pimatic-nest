module.exports =
  ambient_temperature:
    description: "Ambient Room Temperature"
    label: "Room Temp"
    type: "number"
    discrete: true
    unit: "°"
  can_cool:
    description: "If unit has ability to cool"
    label: "Can Cool?"
    type: "boolean"
  can_heat:
    description: "If unit has ability to heat"
    label: "Can Heat?"
    type: "boolean"
  humidity:
    description: "Current Humidity"
    label: "Humidity"
    type: "number"
    unit: "%"
  has_leaf:
    description: "thermostat should show a leaf"
    label: "Leaf"
    type: "boolean"
  hvac_mode:
    description: "Thermostat Mode"
    label: "Mode"
    type: "string"
    enum: ["heat-cool", "heat", "cool", "eco", "off"]
  hvac_state:
    description: "Thermostat State"
    label: "HVAC State"
    type: "string"
    enum: ["off", "heating", "cooling"]
  time_to_target:
    description: "Time remaining until target temp reached"
    label: "Time to Temp"
    type: "string"
  is_blocked:
    description: "If blocked the time else null"
    type: "number"
    unit: ""
  is_locked:
    description: "Lock State of the Thermostat"
    type: "boolean"
  is_online:
    description: "If unit has ability to heat"
    label: "Can Heat?"
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
    discrete: true
    unit: "°"
  locked_temp_max:
    description: "Max Temp of Locked Thermostat"
    type: "number"
    discrete: true
    unit: "°"
  eco_temperature_low:
    description: "The temp that should be set"
    label: "Away Temp Low"
    type: "number"
    unit: "°"
    discrete: true
  eco_temperature_high:
    description: "The temp that should be set"
    label: "Away Temp High"
    type: "number"
    discrete: true
    unit: "°"
module.exports =
  setToCool:
    description: "changes hvac_mode to cool"
  setToHeat:
    description: "changes hvac_mode to heat"
  setToOff:
    description: "changes hvac_mode to off"
  setHVACModeTo:
    description: "change the mode of the hvac_unit"
    params:
      hvac_mode:
        description: "mode of the hvac_unit"
        type: "string"
        enum: ["heat", "cool", "off"]
  increment:
    description: "increases temperature target by 1 unit"
  decrement:
    description: "decreases temperature target by 1 unit"
  changeTemperatureTo:
    description: "change the target temperature of the thermostat"
    params:
      target_temperature:
        description: "the new temperature"
        type: "number"

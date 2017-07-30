module.exports =
  increment:
    description: "Increase temp attr by 1 unit"
    params:
      attr:
        description: "Attr to be increased"
        type: "string"
  decrement:
    description: "Decrease temp attr by 1 unit"
    params:
      attr:
        description: "Attr to be decreased"
        type: "string"
  setTempTo:
    description: "Change temp attr of thermostat"
    params:
      attr:
        description: "Attr to be changed"
        type: "string"
      temp:
        description: "New temp"
        type: "number"
  setToCool:
    description: "Set hvac_mode to cool"
  setToHeat:
    description: "Set hvac_mode to heat"
  setToOff:
    description: "Set hvac_mode to off"
  setHVACModeTo:
    description: "Change hvac_mode"
    params:
      hvac_mode:
        description: "new hvac_mode"
        type: "string"
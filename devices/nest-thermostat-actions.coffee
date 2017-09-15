module.exports =

  setModeToCool:
    description: "Set hvac_mode to cool"
  setModeToHeat:
    description: "Set hvac_mode to heat"
  setModeToOff:
    description: "Set hvac_mode to off"
  setModeToHeatCool:
    description: "Set hvac_mode to heat-cool"
  changeModeTo:
    description: "Change hvac_mode"
    params:
      hvac_mode:
        type: "string"
        enum: ["heat-cool", "heat", "cool", "off"]

  decrementTargetTemp:
    description: "Decrease target temperature 1 unit"
  incrementTargetTemp:
    description: "Increase target temperature attr by 1 unit"
  changeTargetTempTo:
    description: "Set the target temperature"
    params:
      temp:
        description: "New Target Temp"
        type: "number"
  decrementTargetTempLow:
    description: "Decrease target temperature low attr by 1 unit"
  incrementTargetTempLow:
    description: "Increase target temperature low attr by 1 unit"
  changeTargetTempLowTo:
    description: "Set the target temperature low"
    params:
      temp:
        description: "New Target Temp  low"
        type: "number"
  decrementTargetTempHigh:
    description: "Decrease target temperature high attr by 1 unit"
  incrementTargetTempHigh:
    description: "Increase target temperature high attr by 1 unit"
  changeTargetTempHighTo:
    description: "Set the target temperature high"
    params:
      temp:
        description: "New Target Temp High"
        type: "number"


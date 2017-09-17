module.exports =
  title: "pimatic-nest device config schemas"
  NestPresence:
    title: "Nest Home/Away Status"
    type: "object"
    properties:
      structure_id:
        description: "Structure ID for the Presence Sensor"
        type: "string"
  NestHomeAwayToggle:
    title: "Nest Home/Away Toggle"
    type: "object"
    properties:
      structure_id:
        description: "Structure ID for the Toggle Actuator"
        type: "string"
  NestThermostat:
    title: "Nest Thermostat"
    type: "object"
    properties:
      device_id:
        description: "The Nest API thermostat id"
        type: "string"
      temp_scale:
        description: "Temperature scale. Auto-populated by plugin based on Nest info"
        type: "string"
        enum: ["F", "C"]
        default: "F"
      show_temp_scale:
        description: "Display either F or C after temperature values"
        type: "boolean"
        default: false


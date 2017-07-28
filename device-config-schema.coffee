module.exports =
  title: "pimatic-nest device config schemas"
  NestStructure:
    title: "Nest Location"
    type: "object"
    properties:
      structure_id:
        description: "Structure ID for the thermostat"
        type: "string"
  NestThermostat:
    title: "Nest Thermostat"
    type: "object"
    properties:
      device_id:
        description: "The Nest API thermostat id"
        type: "string"
      structure_id:
        description: "Structure ID for the thermostat"
        type: "string"

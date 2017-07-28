# #my-plugin configuration options
# Declare your config option for your plugin here. 
module.exports =
  title: "Nest Plugin Config Options"
  type: "object"
  properties:
    unit:
      description: "Unit for Temperature Values"
      default: "f"
      enum: ["c", "f"]
    token:
      description: "Token required for Firebase Access"
      type: "string"
      default: ""
    structures:
      description: "Nest Structures (i.e. Locations)"
      type: "array"
      format: "table"
      default: []
      required: no
      items:
        type: "object"
        properties:
          structure_id:
            description: "ID of Location"
            type: "string"
            required: no
          name:
            description: "Name of Location"
            type: "string"
            required: no





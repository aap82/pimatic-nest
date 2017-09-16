# #my-plugin configuration options
# Declare your config option for your plugin here. 
module.exports =
  title: "Nest Plugin Config Options"
  type: "object"
  properties:
    token:
      description: "Token required for Firebase Access"
      type: "string"
      default: ""


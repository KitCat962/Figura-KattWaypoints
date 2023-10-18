local configManager = require("KattConfigManager")
configManager.delete("KattWaypoints")
configManager.save("KattWaypoints", {
    main = { _script = true, path = "KattWaypointsSrc" },
    textures = {
        waypoint = textures["model.waypoint"],
    },
})

# Package

version       = "0.1.0"
author        = "Ethan Forrest"
description   = "isometric sokoban"
license       = "MIT"
srcDir        = "modules/render"
bin = @["main"]
namedBin["main"] = "isosoko"


# Dependencies

requires "nim >= 2.0.0"
requires "sdl2"
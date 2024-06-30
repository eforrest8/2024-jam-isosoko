import isosoko/sdl
import logging

when isMainModule:
    addHandler newConsoleLogger()
    # any pre-SDL stuff happens here
    start()
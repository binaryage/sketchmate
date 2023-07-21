set appname to "SketchUp"
tell application appname to quit
repeat until application appname is running
  delay 0.2
end repeat

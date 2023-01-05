
-- This is work in progress migrations of the lapis command to use argparse


cmd = require "lapis.cmd.actions"
cmd.execute [v for _, v in ipairs _G.arg]

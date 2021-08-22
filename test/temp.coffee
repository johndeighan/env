# temp.coffee

import {say, undef, pass, taml} from '@jdeighan/coffee-utils'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {mydir, pathTo, slurp} from '@jdeighan/coffee-utils/fs'
import {
	setenv, getenv, clearenv,
	EnvInput, loadEnvFrom, loadEnvFile, loadEnvString, procEnv,
	} from '@jdeighan/env'

# ----------------------------------------------------------------

dir = mydir(`import.meta.url`)
filepath = pathTo('.env', dir, "up")
say "filepath = '#{filepath}'"

setDebugging true
contents = slurp(filepath)
setDebugging false

say "CONTENTS:"
say contents
oInput = new EnvInput(contents)
tree = oInput.getTree()
say "TREE:"
say tree

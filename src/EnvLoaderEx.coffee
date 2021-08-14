# EnvLoaderEx.coffee

import assert from 'assert'

import {say, taml, undef, error, warn} from '@jdeighan/coffee-utils'
import {slurp, pathTo} from '@jdeighan/coffee-utils/fs'

__dirname = dirname(fileURLToPath(`import.meta.url`));

# ---------------------------------------------------------------------------
# Load environment from .env file

export loadenv = (searchDir) ->

	filepath = pathTo('.env', searchDir, "up")
	contents = slurp(filepath)
	say contents, "FILE CONTENTS:"
	return

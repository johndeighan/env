# EnvLib.coffee

import {strict as assert} from 'assert'

import {undef} from '@jdeighan/coffee-utils'
import {log} from '@jdeighan/coffee-utils/log'
import {mkpath, slurp} from '@jdeighan/coffee-utils/fs'
import {loadEnvFrom} from '@jdeighan/env'

# --- import this to get access to all environment variables
#     NOTE: You'll need to import and call loadEnvLibFrom()
hEnv = {}

# ---------------------------------------------------------------------------
# Define custom callbacks to use with loadEnvFrom

hCallbacks = {
	getVar:   (name) ->
		return hEnv[name]
	setVar:   (name, value) ->
		hEnv[name] = value
		return
	clearVar: (name) ->
		delete hEnv[name]
		return
	clearAll: () ->
		hEnv = {}
		return
	names:    () ->
		return Object.keys(hEnv)
	}

# ---------------------------------------------------------------------------

export loadEnvLibFrom = (searchDir, rootName='DIR_ROOT', hInit={}) ->

	hEnv = hInit    # reset, if there's been a previous call
	loadEnvFrom(searchDir, rootName, {hCallbacks})
	return hEnv

# EnvLib.coffee

import {strict as assert} from 'assert'

import {undef} from '@jdeighan/coffee-utils'
import {log} from '@jdeighan/coffee-utils/log'
import {mkpath, slurp} from '@jdeighan/coffee-utils/fs'
import {loadEnvFrom} from '@jdeighan/env'

#     NOTE: You'll need to call loadEnvLibFrom() and save the return value
#     NOTE: keys are case sensitive
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

export setEnvLibVar = (name, value) ->

	hCallbacks.setVar(name, value)
	return

# ---------------------------------------------------------------------------

export getEnvLibVar = (name, value) ->

	hCallbacks.getVar(name, value)
	return

# ---------------------------------------------------------------------------

export loadEnvLibFrom = (searchDir, rootName='DIR_ROOT', hInit={}) ->

	hEnv = hInit    # reset, if there's been a previous call
	loadEnvFrom(searchDir, rootName, {hCallbacks})
	return hEnv

# EnvLoaderEx.coffee

import assert from 'assert'

import {say, undef, pass, error, warn, rtrim} from '@jdeighan/coffee-utils'
import {slurp, pathTo} from '@jdeighan/coffee-utils/fs'

# ---------------------------------------------------------------------------
# Load environment from .env file

export loadEnvFrom = (searchDir) ->

	filepath = pathTo('.env', searchDir, "up")
	if not filepath?
		warn "loadEnvFrom('#{searchDir}'): No .env file found"
		return
	return loadEnv(slurp(filepath))

# ---------------------------------------------------------------------------
# Load environment from a string

export loadenv = (contents) ->

	filepath = pathTo('.env', searchDir, "up")
	contents = slurp(filepath)
	say contents, "FILE CONTENTS:"
	return

# ---------------------------------------------------------------------------

export EnvMapper = (str) ->

	if lMatches = str.match(///^
			([A-Za-z_]+)      # identifier
			\s*
			=
			\s*
			(.*)
			$///)
		[_, key, value] = lMatches
		value = rtrim(value)
		return {type: 'assign', key, value}
	else if lMatches = str.match(///^
			if
			\s+
			(?:
				(not)
				\s+
				)?
			([A-Za-z_]+)      # identifier
			$///)
		[_, neg, key] = lMatches
		if neg
			return {type: 'if_falsy', key}
		else
			return {type: 'if_truthy', key}
	else if lMatches = str.match(///^
			if
			\s+
			([A-Za-z_]+)      # identifier (key)
			\s*
			(
				  ==           # comparison operator
				| !=
				| >
				| >=
				| <
				| <=
				)
			\s*
			(?:
				  ([A-Za-z_]+)      # identifier
				| ([0-9]+)          # number
				| ' ([^']*) '       # single quoted string
				| " ([^"]*) "       # double quoted string
				)
			$///)
		[_, key, op, ident, number, sqstr, dqstr] = lMatches
		if ident
			return {type: 'compare_ident', key, op, ident}
		else if number
			return {type: 'compare_number', key, op, number: Number(number)}
		else if sqstr
			return {type: 'compare_string', key, op, string: sqstr}
		else if dqstr
			return {type: 'compare_string', key, op, string: dqstr}
		else
			error "Invalid line: '#{str}'"
	else
		error "Invalid line: '#{str}'"

# ---------------------------------------------------------------------------

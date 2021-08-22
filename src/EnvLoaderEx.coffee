# EnvLoaderEx.coffee

import {strict as assert} from 'assert'

import {
	say, undef, pass, error, rtrim, isArray,
	} from '@jdeighan/coffee-utils'
import {debug} from '@jdeighan/coffee-utils/debug'
import {slurp, pathTo} from '@jdeighan/coffee-utils/fs'
import {PLLParser} from '@jdeighan/string-input/pll'

# ---------------------------------------------------------------------------

export setenv = (name, value) ->

	debug "SET ENV '#{name}' = '#{value}'"
	process.env[name] = value
	return

# ---------------------------------------------------------------------------

export getenv = (name) ->

	debug "GET ENV '#{name}'"
	return process.env[name]

# ---------------------------------------------------------------------------

export clearenv = (...lNames) ->

	debug "CLEAR ENV #{lNames.join(', ')}"
	for name in lNames
		delete process.env[name]
	return

# ---------------------------------------------------------------------------

export class EnvInput extends PLLParser

	constructor: (string, @prefix) ->

		super string

	mapString: (str) ->

		if lMatches = str.match(///^
				([A-Za-z_\.]+)      # identifier
				\s*
				=
				\s*
				(.*)
				$///)
			[_, key, value] = lMatches
			if @prefix && (key.indexOf(@prefix) != 0)
				return undef
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

getdir = (fullpath) ->
	# --- Works only if file name is '.env'

	len = fullpath.length
	return fullpath.substring(0, len-5)

# ---------------------------------------------------------------------------
# Load environment from .env file

export loadEnvFrom = (searchDir, hOptions={}) ->
	# --- Valid options:
	#     recurse - load all .env files found by searching up
	#     prefix - load only env vars with the given prefix

	debug "enter loadEnvFrom()"
	{recurse, prefix} = hOptions
	filepath = pathTo('.env', searchDir, "up")
	if not filepath?
		debug "return - no .env file found"
		return
	loadEnvFile filepath, prefix
	if not recurse
		debug "return from loadEnvFrom()"
		return
	while filepath = pathTo('.env', getdir(filepath), "up")
		loadEnvFile filepath, prefix
	debug "return from loadEnvFrom()"
	return

# ---------------------------------------------------------------------------
# Load environment from a string

export loadEnvFile = (filepath, prefix=undef) ->

	debug "enter loadEnvFile('#{filepath}')"
	loadEnvString slurp(filepath), prefix
	debug "return from loadEnvFile()"
	return

# ---------------------------------------------------------------------------
# Load environment from a string

export loadEnvString = (contents, prefix=undef) ->

	debug "enter loadEnvString()"
	oInput = new EnvInput(contents, prefix)
	tree = oInput.getTree()
	procEnv tree
	debug "return from loadEnvString()"
	return

# ---------------------------------------------------------------------------

doCompare = (arg1, op, arg2) ->

	switch op
		when '=='
			return (arg1 == arg2)
		when '!='
			return (arg1 != arg2)
		when '<'
			return (arg1 < arg2)
		when '<='
			return (arg1 <= arg2)
		when '>'
			return (arg1 > arg2)
		when '>='
			return (arg1 >= arg2)
		else
			error "doCompare(): Invalid operator '#{op}'"

# ---------------------------------------------------------------------------

replacer = (str) ->

	debug "enter replacer('#{str}')"
	name = str.substr(1)
	debug "name = '#{name}'"
	result = getenv(name)
	debug "return with '#{result}'"
	return result

# ---------------------------------------------------------------------------
# Load environment from a string

export procEnv = (tree) ->

	debug "enter procEnv() - tree"
	assert isArray(tree), "procEnv(): tree is not an array"
	for h in tree
		switch h.node.type

			when 'assign'
				{key, value} = h.node
				value = value.replace(/\$[A-Za-z_]+/g, replacer)
				setenv key, value
				debug "procEnv(): assign #{key} = '#{value}'"

			when 'if_truthy'
				{key} = h.node
				debug "if_truthy: '#{key}'"
				if getenv(key)
					debug "YES: proc body"
					procEnv(h.body)

			when 'if_falsy'
				{key} = h.node
				debug "if_falsy: '#{key}'"
				if not getenv(key)
					debug "YES: proc body"
					procEnv(h.body)

			when 'compare_ident'
				{key, op, ident} = h.node
				arg1 = getenv(key)
				arg2 = getenv(ident)
				if doCompare(arg1, op, arg2)
					procEnv(h.body)

			when 'compare_number'
				{key, op, number} = h.node
				arg1 = Number(getenv(key))
				if doCompare(arg1, op, number)
					procEnv(h.body)

			when 'compare_string'
				{key, op, string} = h.node
				arg1 = getenv(key)
				if doCompare(arg1, op, string)
					procEnv(h.body)

	debug "return from procEnv()"
	return

# ---------------------------------------------------------------------------

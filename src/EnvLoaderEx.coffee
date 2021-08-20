# EnvLoaderEx.coffee

import assert from 'assert'

import {
	say,
	undef,
	pass,
	error,
	warn,
	rtrim,
	isArray,
	} from '@jdeighan/coffee-utils'
import {debug} from '@jdeighan/coffee-utils/debug'
import {slurp, pathTo} from '@jdeighan/coffee-utils/fs'
import {PLLParser} from '@jdeighan/string-input/pll'

# ---------------------------------------------------------------------------

export class EnvInput extends PLLParser

	mapString: (str) ->

		if lMatches = str.match(///^
				([A-Za-z_]+)      # identifier
				\s*
				=
				\s*
				(.*)
				$///)
			[_, key, value] = lMatches
			key = key.toUpperCase()
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
			key = key.toUpperCase()
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
			key = key.toUpperCase()
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
# Load environment from .env file

export loadEnvFrom = (searchDir) ->

	debug "enter loadEnvFrom()"
	tree = loadEnvFile(searchDir)
	procEnv(tree)
	debug "return from loadEnvFrom()"
	return tree

# ---------------------------------------------------------------------------
# Load environment from a string

export loadEnvFile = (searchDir) ->

	debug "enter loadEnvFile('#{searchDir}')"
	filepath = pathTo('.env', searchDir, "up")
	if not filepath?
		warn "loadEnvFile('#{searchDir}'): No .env file found"
		debug "return - no .env file found"
		return
	contents = slurp(filepath)
	tree = parseEnv(contents)
	debug "return from loadEnvFile() - tree"
	return tree

# ---------------------------------------------------------------------------
# Load environment from a string

export parseEnv = (contents) ->

	debug "enter ENV parseEnv()"
	oInput = new EnvInput(contents)
	tree = oInput.getTree()
	debug "return ENV from parseEnv() - tree"
	return tree

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

	debug "enter ENV replacer('#{str}')"
	name = str.substr(1).toUpperCase()
	debug "ENV name = '#{name}'"
	result = process.env[name]
	debug "return ENV with '#{result}'"
	return result

# ---------------------------------------------------------------------------
# Load environment from a string

export procEnv = (tree) ->

	debug "enter ENV procEnv() - tree"
	assert isArray(tree), "procEnv(): tree is not an array"
	for h in tree
		switch h.node.type

			when 'assign'
				{key, value} = h.node
				value = value.replace(/\$[A-Za-z_]+/g, replacer)
				process.env[key] = value
				debug "ENV procEnv(): assign #{key} = '#{value}'"

			when 'if_truthy'
				{key} = h.node
				debug "if_truthy: '#{key}'"
				if process.env[key]
					debug "YES: proc body"
					procEnv(h.body)

			when 'if_falsy'
				{key} = h.node
				debug "if_falsy: '#{key}'"
				if not process.env[key]
					debug "YES: proc body"
					procEnv(h.body)

			when 'compare_ident'
				{key, op, ident} = h.node
				arg1 = process.env[key]
				arg2 = process.env[ident]
				if doCompare(arg1, op, arg2)
					procEnv(h.body)

			when 'compare_number'
				{key, op, number} = h.node
				arg1 = Number(process.env[key])
				if doCompare(arg1, op, number)
					procEnv(h.body)

			when 'compare_string'
				{key, op, string} = h.node
				arg1 = process.env[key]
				if doCompare(arg1, op, string)
					procEnv(h.body)

	debug "return ENV from procEnv()"
	return

# ---------------------------------------------------------------------------

# EnvLoaderEx.coffee

import {strict as assert} from 'assert'

import {
	say, undef, pass, error, rtrim, isArray, isFunction,
	} from '@jdeighan/coffee-utils'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {slurp, pathTo} from '@jdeighan/coffee-utils/fs'
import {PLLParser} from '@jdeighan/string-input/pll'

# ---------------------------------------------------------------------------

export class EnvLoader extends PLLParser

	constructor: (contents, @hOptions={}) ->
		# --- Valid options:
		#        hInitialVars - hash of initial env var values
		#        prefix - load only vars with this prefix
		#        stripPrefix - remove the prefix before setting vars
		#        hCallbacks - callbacks to replace:
		#                     getVar, setVar, clearVar, names


		super contents

		@prefix = @hOptions.prefix
		@stripPrefix = @hOptions.stripPrefix

		@hCallbacks = @hOptions.hCallbacks
		@checkCallbacks()
		if @hOptions.hInitialVars
			for key,value of @hOptions.hInitialVars
				@setVar key, value

	# ..........................................................

	checkCallbacks: () ->

		if @hCallbacks?
			assert isFunction(@hCallbacks.getVar),
				"checkCallbacks: no getVar"
			assert isFunction(@hCallbacks.setVar),
				"checkCallbacks: no setVar"
			assert isFunction(@hCallbacks.clearVar),
				"checkCallbacks: no clearVar"
			assert isFunction(@hCallbacks.names),
				"checkCallbacks: no names"
		return

	# ..........................................................

	setVar: (name, value) ->

		if @hCallbacks
			@hCallbacks.setVar name, value
		else
			process.env[name] = value
		return

	# ..........................................................

	getVar: (name) ->

		if @hCallbacks
			return @hCallbacks.getVar(name)
		else
			return process.env[name]
		return

	# ..........................................................

	clearVar: (name) ->

		if @hCallbacks
			@hCallbacks.clearVar name
		else
			delete process.env[name]
		return

	# ..........................................................

	names: () ->

		if @hCallbacks
			return @hCallbacks.names()
		else
			return Object.keys(process.env)
		return

	# ..........................................................

	dump: () ->

		say "=== Environment Variables: ==="
		for name in @names()
			say "   #{name} = '#{@getVar(name)}'"
		return

	# ..........................................................

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
			if @stripPrefix
				key = key.substring(@prefix.length)
			return {
				type: 'assign',
				key,
				value: rtrim(value),
				}
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

	# ..........................................................

	doCompare: (arg1, op, arg2) ->

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

	# ..........................................................

	load: () ->

		debug "enter load()"
		tree = @getTree()
		assert tree?, "load(): tree is undef"
		assert isArray(tree), "load(): tree is not an array"
		@procEnv tree
		debug "return from load()"
		return

	procEnv: (tree) ->

		debug "enter procEnv()"
		debug tree, "TREE:"

		# --- NOTE: Must use => here, not ->
		#           so that "this" is set correctly
		replacer = (str) =>

			debug "enter replacer('#{str}')"
			name = str.substr(1)
			debug "name = '#{name}'"
			result = @getVar(name)
			debug "return with '#{result}'"
			return result

		for h in tree
			switch h.node.type

				when 'assign'
					{key, value} = h.node
					value = value.replace(/\$[A-Za-z_]+/g, replacer)
					@setVar key, value
					debug "procEnv(): assign #{key} = '#{value}'"

				when 'if_truthy'
					{key} = h.node
					debug "if_truthy: '#{key}'"
					if @getVar(key)
						debug "YES: proc body"
						@procEnv(h.body)

				when 'if_falsy'
					{key} = h.node
					debug "if_falsy: '#{key}'"
					if not @getVar(key)
						debug "YES: proc body"
						@procEnv(h.body)

				when 'compare_ident'
					{key, op, ident} = h.node
					arg1 = @getVar(key)
					arg2 = @getVar(ident)
					if @doCompare(arg1, op, arg2)
						@procEnv(h.body)

				when 'compare_number'
					{key, op, number} = h.node
					arg1 = Number(@getVar(key))
					if @doCompare(arg1, op, number)
						@procEnv(h.body)

				when 'compare_string'
					{key, op, string} = h.node
					arg1 = @getVar(key)
					if @doCompare(arg1, op, string)
						@procEnv(h.body)

		debug "return from procEnv()"
		return

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Load environment from a string

export loadEnvFile = (filepath, hOptions={}) ->

	debug "enter loadEnvFile('#{filepath}')"
	env = loadEnvString slurp(filepath), hOptions
	debug "return from loadEnvFile()"
	return env

# ---------------------------------------------------------------------------
# Load environment from a string

export loadEnvString = (contents, hOptions={}) ->

	debug "enter loadEnvString()"
	env = new EnvLoader(contents, hOptions)
	env.load()
	debug "return from loadEnvString()"
	return env

# ---------------------------------------------------------------------------
# Load environment from .env file

export loadEnvFrom = (searchDir, hOptions={}) ->
	# --- Valid options:
	#     recurse - load all .env files found by searching up
	#     rootName - env var name of first .env file found
	#     any option accepted by EndLoader

	debug "enter loadEnvFrom()"
	filepath = pathTo('.env', searchDir, "up")
	assert filepath?, "No .env file found"
	if hOptions.rootName
		if not hOptions.hInitialVars
			hOptions.hInitialVars = {}
		hOptions.hInitialVars[hOptions.rootName] = filepath

	env = loadEnvFile filepath, hOptions
	if not hOptions.recurse
		debug "return from loadEnvFrom()"
		return env
	while filepath = pathTo('.env', filepath.substring(0, filepath.length-5), "up")
		debug "Also load #{filepath}"
		env = loadEnvFile filepath, prefix
	debug "return from loadEnvFrom()"
	return env

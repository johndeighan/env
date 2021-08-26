# EnvLoaderEx.coffee

import {strict as assert} from 'assert'
import {dirname, resolve, parse as parse_fname} from 'path';

import {
	say, undef, pass, error, rtrim, isArray, isFunction, rtrunc,
	} from '@jdeighan/coffee-utils'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {slurp, pathTo, mkpath} from '@jdeighan/coffee-utils/fs'
import {PLLParser} from '@jdeighan/string-input/pll'

# ---------------------------------------------------------------------------

export class EnvLoader extends PLLParser

	constructor: (contents, @hOptions={}) ->
		# --- Valid options:
		#        hInitialVars - hash of initial env var values
		#        prefix - load only vars with this prefix
		#        stripPrefix - remove the prefix before setting vars
		#        hCallbacks - callbacks to replace:
		#                     getVar, setVar, clearVar, clearAll, names


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
			lMissing = []
			for name in ['getVar','setVar','clearVar','clearAll','names']
				if not isFunction(@hCallbacks[name])
					lMissing.push(name)
			if (lMissing.length > 0)
				error "Missing callbacks: #{lMissing.join(',')}"
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

	clearAll: () ->

		if @hCallbacks
			@hCallbacks.clearAll
		else
			process.env = {}
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
				([A-Za-z_][A-Za-z0-9_]*)      # identifier (key)
				\s*
				(
					  is           # comparison operator
					| isnt
					| >
					| >=
					| <
					| <=
					)
				\s*
				(.*)
				$///)
			[_, key, op, value] = lMatches
			return {type: 'compare', key, op, value: value.trim()}
		else
			error "Invalid line: '#{str}'"

	# ..........................................................

	expand: (str) ->

		# --- NOTE: Must use => here, not -> so that "this" is set correctly
		replacer = (str) => return @getVar(str.substr(1))
		return str.replace(/\$[A-Za-z_][A-Za-z0-9_]*/g, replacer)

	# ..........................................................

	doCompare: (arg1, op, arg2) ->

		arg1 = @getVar(arg1)
		arg2 = @expand(arg2)
		switch op
			when 'is'
				return (arg1 == arg2)
			when 'isnt'
				return (arg1 != arg2)
			when '<'
				return (Number(arg1) < Number(arg2))
			when '<='
				return (Number(arg1) <= Number(arg2))
			when '>'
				return (Number(arg1) > Number(arg2))
			when '>='
				return (Number(arg1) >= Number(arg2))
			else
				error "doCompare(): Invalid operator '#{op}'"

	# ..........................................................

	procEnv: (tree) ->

		debug "enter procEnv()"
		debug tree, "TREE:"

		for h in tree
			switch h.node.type

				when 'assign'
					{key, value} = h.node
					value = @expand(value)
					@setVar key, value
					debug "procEnv(): assign #{key} = '#{value}'"

				when 'if_truthy'
					{key} = h.node
					debug "if_truthy: '#{key}'"
					if @getVar(key)
						debug "procEnv(): if_truthy('#{key}') - proc body"
						@procEnv(h.body)
					else
						debug "procEnv(): if_truthy('#{key}') - skip"

				when 'if_falsy'
					{key} = h.node
					debug "if_falsy: '#{key}'"
					if @getVar(key)
						debug "procEnv(): if_falsy('#{key}') - skip"
					else
						debug "procEnv(): if_falsy('#{key}') - proc body"
						@procEnv(h.body)

				when 'compare'
					{key, op, value} = h.node
					debug "procEnv(key=#{key}, value=#{value})"
					if @doCompare(key, op, value)
						debug "procEnv(): compare('#{key}','#{value}') - proc body"
						@procEnv(h.body)
					else
						debug "procEnv(): compare('#{key}','#{value}') - skip"

		debug "return from procEnv()"
		return

	# ..........................................................

	load: () ->

		debug "enter load()"
		tree = @getTree()
		assert tree?, "load(): tree is undef"
		assert isArray(tree), "load(): tree is not an array"
		@procEnv tree
		debug "return from load()"
		return

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Load environment from a string

export loadEnvFile = (filepath, hOptions={}) ->

	debug "LOAD #{filepath}"
	return loadEnvString slurp(filepath), hOptions

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
	#     hInitialVars - set these env vars first
	#     recurse - load all .env files found by searching up
	#     rootName - env var name of first .env file found
	#     any option accepted by EnvLoader
	#        hInitialVars - hash of initial env var values
	#        prefix - load only vars with this prefix
	#        stripPrefix - remove the prefix before setting vars
	#        hCallbacks - callbacks to replace:
	#                     getVar, setVar, clearVar, clearAll, names

	debug "enter loadEnvFrom('#{searchDir}')"
	{rootName, hInitialVars, recurse} = hOptions
	path = pathTo('.env', searchDir, "up")
	if not path?
		return undef
	if rootName
		if not hInitialVars
			hInitialVars = hOptions.hInitialVars = {}
		hInitialVars[rootName] = mkpath(rtrunc(path, 5))

	if recurse
		lPaths = [path]
		while path = pathTo('.env', resolve(rtrunc(path, 5), '..'), "up")
			lPaths.unshift path
		for path in lPaths
			env = loadEnvFile path, hOptions
	else
		env = loadEnvFile path, hOptions
	debug "return from loadEnvFrom()"
	return env

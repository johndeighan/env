# EnvLoaderEx.coffee

import {strict as assert} from 'assert'
import {dirname, resolve, parse as parse_fname} from 'path';

import {
	undef, pass, error, rtrim, isArray, isFunction, rtrunc, escapeStr,
	} from '@jdeighan/coffee-utils'
import {log} from '@jdeighan/coffee-utils/log'
import {debug} from '@jdeighan/coffee-utils/debug'
import {slurp, pathTo, mkpath} from '@jdeighan/coffee-utils/fs'
import {PLLParser} from '@jdeighan/string-input'

# ---------------------------------------------------------------------------

export class EnvLoader extends PLLParser

	constructor: (contents, hOptions={}) ->
		# --- Valid options:
		#        prefix - load only vars with this prefix
		#        stripPrefix - remove the prefix before setting vars
		#        hCallbacks - callbacks to replace:
		#                     getVar, setVar, clearVar, clearAll, names


		super contents
		{@prefix, @stripPrefix, @hCallbacks} = hOptions
		@checkCallbacks()

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

	getVar: (name) ->

		if @hCallbacks
			return @hCallbacks.getVar(name)
		else
			return process.env[name]
		return

	# ..........................................................

	setVar: (name, value) ->

		if @hCallbacks
			@hCallbacks.setVar name, value
		else
			process.env[name] = value
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

		log "=== Environment Variables: ==="
		for name in @names()
			log "   #{name} = '#{@getVar(name)}'"
		return

	# ..........................................................

	mapNode: (str) ->

		debug "enter mapNode('#{escapeStr(str)}')"
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
			result = {
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
				result = {type: 'if_falsy', key}
			else
				result = {type: 'if_truthy', key}
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
			result = {
				type: 'compare',
				key,
				op,
				value: value.trim(),
				}
		else
			error "Invalid line: '#{str}'"
		debug "return from mapNode():", result
		return result

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
		debug "TREE", tree
		assert tree?, "load(): tree is undef"
		assert isArray(tree), "load(): tree is not an array"
		@procEnv tree
		debug "return from load()"
		return

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Load environment from a file

export loadEnvFile = (filepath, hOptions={}) ->

	debug "LOADENV #{filepath}"
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

export loadEnvFrom = (searchDir, rootName='DIR_ROOT', hOptions={}) ->
	# --- valid options:
	#        onefile - load only the first file found

	debug "enter loadEnvFrom('#{searchDir}', rootName=#{rootName})"
	path = pathTo('.env', searchDir, "up")
	if not path?
		debug "return from loadEnvFrom() - no .env file found"
		return
	debug "found .env file: #{path}"
	lPaths = [path]

	# --- Don't set root directory if it's already defined
	if rootName && not process.env[rootName]
		root = mkpath(rtrunc(path, 5))
		debug "set env var #{rootName} to #{root}"
		if hOptions.hCallbacks
			hOptions.hCallbacks.setVar(rootName, root)
		else
			process.env[rootName] = root

	if not hOptions.onefile
		# --- search upward for .env files, but process top down
		while path = pathTo('.env', resolve(rtrunc(path, 5), '..'), "up")
			debug "found .env file: #{path}"
			lPaths.unshift path

	hEnv = {}
	for path in lPaths
		hEnv = Object.assign(hEnv, loadEnvFile(path, hOptions))
	debug "return from loadEnvFrom()"
	return hEnv

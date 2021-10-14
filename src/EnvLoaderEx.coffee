# EnvLoaderEx.coffee

import {strict as assert} from 'assert'
import {dirname, resolve, parse as parse_fname} from 'path'

import {
	undef, pass, error, rtrim, isArray, isFunction, rtrunc, escapeStr,
	} from '@jdeighan/coffee-utils'
import {log} from '@jdeighan/coffee-utils/log'
import {debug} from '@jdeighan/coffee-utils/debug'
import {slurp, pathTo, mkpath} from '@jdeighan/coffee-utils/fs'
import {hPrivEnv, hPrivEnvCallbacks} from '@jdeighan/coffee-utils/privenv'
import {PLLParser} from '@jdeighan/string-input'

hDefCallbacks = {
	getVar: (name) ->
		return process.env[name]
	setVar: (name, value) ->
		process.env[name] = value
		return
	clearVar: (name) ->
		delete process.env[name]
		return
	clearAll: () ->
		process.env ={}
	names: () ->
		return Object.keys(process.env)
	}

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
		if @hCallbacks?
			@checkCallbacks()
		else
			@hCallbacks = hDefCallbacks

	# ..........................................................

	checkCallbacks: () ->

		if @hCallbacks?
			lMissing = []
			for name in ['getVar','setVar','clearVar','clearAll','names']
				if ! isFunction(@hCallbacks[name])
					lMissing.push(name)
			if (lMissing.length > 0)
				error "Missing callbacks: #{lMissing.join(',')}"
		return

	# ..........................................................

	getVar: (name) ->

		return @hCallbacks.getVar(name)

	# ..........................................................

	setVar: (name, value) ->

		@hCallbacks.setVar name, value
		return

	# ..........................................................

	clearVar: (name) ->

		@hCallbacks.clearVar name
		return

	# ..........................................................

	clearAll: () ->

		@hCallbacks.clearAll
		return

	# ..........................................................

	names: () ->

		return @hCallbacks.names()

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
# Load environment from a string

export loadEnvString = (contents, hOptions={}) ->

	debug "enter loadEnvString()"
	env = new EnvLoader(contents, hOptions)
	env.load()
	debug "return from loadEnvString()"
	return

# ---------------------------------------------------------------------------
# Load environment from a file

export loadEnvFile = (filepath, hOptions={}) ->

	debug "LOADENV #{filepath}"
	loadEnvString slurp(filepath), hOptions
	return

# ---------------------------------------------------------------------------
# Load environment from .env file

export loadEnvFrom = (searchDir, rootName='DIR_ROOT', hOptions={}) ->
	# --- valid options:
	#        onefile - load only the first file found
	#        hCallbacks - getVar, setVar, clearVar, clearAll, names

	debug "enter loadEnvFrom('#{searchDir}', rootName=#{rootName})"
	path = pathTo('.env', searchDir, "up")
	if ! path?
		debug "return from loadEnvFrom() - no .env file found"
		return
	debug "found .env file: #{path}"

	# --- Don't set root directory if it's already defined
	if rootName && ! process.env[rootName]
		root = mkpath(rtrunc(path, 5))
		debug "set env var #{rootName} to #{root}"
		if hOptions.hCallbacks
			hOptions.hCallbacks.setVar(rootName, root)
		else
			hDefCallbacks.setVar(rootName, root)

	lPaths = [path]    # --- build an array of paths
	if ! hOptions.onefile
		# --- search upward for .env files, but process top down
		while path = pathTo('.env', resolve(rtrunc(path, 5), '..'), "up")
			debug "found .env file: #{path}"
			lPaths.unshift path

	for path in lPaths
		loadEnvFile(path, hOptions)
	debug "return from loadEnvFrom()"
	return

# ---------------------------------------------------------------------------
# Instead of loading into process.env,
# this loads into hPrivEnv from '@jdeighan/coffee-utils/privenv'

export loadPrivEnvFrom = (searchDir, rootName='DIR_ROOT', hInit=undef) ->

	hPrivEnvCallbacks.clearAll()

	# --- Load any vars found in hInit
	if hInit?
		for name,value of hInit
			hPrivEnvCallbacks.setVar name, value

	loadEnvFrom(searchDir, rootName, {hCallbacks: hPrivEnvCallbacks})
	return

# ---------------------------------------------------------------------------

if process.env.DIR_ROOT?
	rootDir = process.env.DIR_ROOT
	log "env var DIR_ROOT = '#{rootDir}'"
	loadPrivEnvFrom rootDir
	pass
else
	log "env var DIR_ROOT not set"

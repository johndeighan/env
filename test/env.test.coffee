# env.test.coffee

import {strict as assert} from 'assert'
import {resolve} from 'path';

import {say, undef, pass} from '@jdeighan/coffee-utils'
import {debug} from '@jdeighan/coffee-utils/debug'
import {mydir, pathTo, slurp} from '@jdeighan/coffee-utils/fs'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {taml} from '@jdeighan/string-input/convert'
import {
	EnvLoader, loadEnvFrom, loadEnvFile, loadEnvString,
	} from '@jdeighan/env'

dir = mydir(`import.meta.url`)  # directory this file is in
root_dir = resolve(dir, '..')

simple = new UnitTester()

###   Contents of relevant .env files:

Root .env

	if development
		color = magenta
		mood = somber
	if not development
		color = azure
		mood = happy

test .env

	if mood == 'somber'
		bgColor = sadness
		show = yes
	if mood == 'happy'
		bgColor = purple
		show = no

test/test .env

	show = maybe

###
# ---------------------------------------------------------------------------
# --- test using EnvLoader

(() ->
	env = new EnvLoader("""
		development = yes
		if development
			color = red
			if usemoods
				mood = somber
		if not development
			color = blue
			if usemoods
				mood = happy
			""")

	tree = env.getTree()

	simple.equal 60, tree, taml("""
			---
			-
				lineNum: 1
				node:
					type: assign
					key: development
					value: 'yes'
			-
				lineNum: 2
				node:
					type: if_truthy
					key: development
				body:
					-
						lineNum: 3
						node:
							type: assign
							key: color
							value: red
					-
						lineNum: 4
						node:
							type: if_truthy
							key: usemoods
						body:
							-
								lineNum: 5
								node:
									type: assign
									key: mood
									value: somber
			-
				lineNum: 6
				node:
					type: if_falsy
					key: development
				body:
					-
						lineNum: 7
						node:
							type: assign
							key: color
							value: blue
					-
						lineNum: 8
						node:
							type: if_truthy
							key: usemoods
						body:
							-
								lineNum: 9
								node:
									type: assign
									key: mood
									value: happy
			""")
	)()

# ---------------------------------------------------------------------------
# --- test using .env file

(() ->
	filepath = pathTo('.env', dir, "up")
	contents = slurp(filepath)
	env = new EnvLoader(contents)
	tree = env.getTree()

	simple.equal 128, tree, taml("""
			---
			-
				node:
					op:    is
					value: somber
					type:  compare
					key:   mood
				lineNum: 1
				body:
					-
						node:
							type:  assign
							key:   bgColor
							value: sadness
						lineNum: 2
					-
						node:
							type:  assign
							key:   show
							value: yes
						lineNum: 3
			-
				node:
					op:    is
					value: happy
					type:  compare
					key:   mood
				lineNum: 4
				body:
					-
						node:
							type:  assign
							key:   bgColor
							value: purple
						lineNum: 5
					-
						node:
							type:  assign
							key:   show
							value: no
						lineNum: 6
			""")

	)()

# ---------------------------------------------------------------------------
# --- test env var replacement

(() ->
	env = new EnvLoader("""
			dir_root = /usr/project
			dir_data = $dir_root/data
			""")
	env.load()

	simple.equal 180, env.getVar('dir_data'), "/usr/project/data"

	)()

# ---------------------------------------------------------------------------
# --- test if environment is really loaded using .env file
#
# Contents of .env file:
#   if development
#      color = magenta
#      mood = somber
#   if not development
#      color = azure
#      mood = happy

(() ->
	process.env.development = 'yes'

	env = loadEnvFrom(root_dir)
	assert env?, "env is undefined on line 174"

	simple.equal 201, env.getVar('development'), 'yes'
	simple.equal 202, env.getVar('color'), 'magenta'
	simple.equal 203, env.getVar('mood'), 'somber'

	)()

# ---------------------------------------------------------------------------
# --- test prefix

(() ->
	delete process.env['dir_root']
	delete process.env['sb.indent']
	delete process.env['dir_data']
	delete process.env['sb.dev']

	env = loadEnvString("""
			dir_root = /usr/project
			sb.indent = 3
			dir_data = /usr/project/data
			sb.dev = yes
			""", {
			prefix: 'sb.',
			})

	simple.equal 225, env.getVar('dir_root'),  undef
	simple.equal 226, env.getVar('sb.indent'), '3'
	simple.equal 227, env.getVar('dir_data'),  undef
	simple.equal 228, env.getVar('sb.dev'),   'yes'

	)()

# ---------------------------------------------------------------------------
# --- test prefix with stripPrefix option

(() ->
	delete process.env['dir_root']
	delete process.env['sb.indent']
	delete process.env['indent']
	delete process.env['dir_data']
	delete process.env['sb.dev']
	delete process.env['dev']

	env = loadEnvString("""
			dir_root = /usr/project
			sb.indent = 3
			dir_data = /usr/project/data
			sb.dev = yes
			""", {
			prefix: 'sb.',
			stripPrefix: true,
			})

	simple.equal 253, env.getVar('dir_root'),  undef
	simple.equal 254, env.getVar('sb.indent'), undef
	simple.equal 255, env.getVar('indent'),    '3'

	simple.equal 257, env.getVar('dir_data'),  undef
	simple.equal 258, env.getVar('sb.dev'),    undef
	simple.equal 259, env.getVar('dev'),       'yes'

	)()
# ---------------------------------------------------------------------------
# --- test hCallbacks

(() ->

	hVariables = {}
	hCallbacks = {
		getVar: (name) ->
			return hVariables[name]
		setVar: (name, value) ->
			hVariables[name] = value
		clearVar: (name) ->
			delete hVariables[name]
		clearAll: () ->
			hVariables = {}
		names: () ->
			return Object.keys(hVariables)
		}

	env = loadEnvString("""
			dev = yes
			dir_root = /usr/project
			dir_data = $dir_root/data
			""", {
				hCallbacks
				})

	simple.equal     289, env.getVar('dir_root'),  '/usr/project'
	simple.equal     290, env.getVar('dir_data'), '/usr/project/data'
	simple.same_list 291, env.names(),  ['dev','dir_root','dir_data']

	)()

# ---------------------------------------------------------------------------
# --- test hInitialVars

(() ->
	delete process.env['dir_root']
	delete process.env['dir_data']

	env = loadEnvString("""
			dir_data = $dir_root/data
			""", {
			hInitialVars: {
				"dir_root": "/usr/project",
				}
			})

	simple.equal 310, env.getVar('dir_data'),  '/usr/project/data'

	)()

# ---------------------------------------------------------------------------
# --- test hInitialVars with custom callbacks

(() ->
	hVars = {}

	hCallbacks = {

		getVar: (name) ->
			return hVars[name]

		setVar: (name, value) ->
			hVars[name] = value
			return

		clearVar: (name) ->
			delete hVars[name]
			return

		clearAll: () ->
			hVars = {}
			return

		names: () ->
			return Object.keys(hVars)

		}

	env = loadEnvString("""
			dir_data = $dir_root/data
			""", {
			hInitialVars: {
				"dir_root": "/usr/project",
				},
			hCallbacks
			})

	simple.equal 351, hVars, {
		dir_root: '/usr/project'
		dir_data: '/usr/project/data'
		}

	)()

# ---------------------------------------------------------------------------
# --- test recurse
#

(() ->
	hVars = {}

	hCallbacks = {

		getVar: (name) ->
			return hVars[name]

		setVar: (name, value) ->
			hVars[name] = value
			return

		clearVar: (name) ->
			delete hVars[name]
			return

		clearAll: () ->
			hVars = {}
			return

		names: () ->
			return Object.keys(hVars)

		}

	env = loadEnvFrom("#{dir}/test", {
			hInitialVars: {
				"development": "yes",
				},
			hCallbacks,
			rootName: 'dir_root',
			recurse: true
			})

	simple.equal 396, hVars, {
		dir_root: 'C:/Users/johnd/env/test/test'
		development: 'yes'
		color: 'magenta'
		mood: 'somber'
		bgColor: 'sadness'
		show: 'maybe'
		}

	)()

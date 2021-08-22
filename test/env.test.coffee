# env.test.coffee

import {strict as assert} from 'assert'

import {AvaTester} from '@jdeighan/ava-tester'
import {say, undef, pass, taml} from '@jdeighan/coffee-utils'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {mydir, pathTo, slurp} from '@jdeighan/coffee-utils/fs'
import {
	setenv, getenv, clearenv,
	EnvInput, loadEnvFrom, loadEnvFile, loadEnvString, procEnv,
	} from '@jdeighan/env'

dir = mydir(`import.meta.url`)

simple = new AvaTester()

# ---------------------------------------------------------------------------
# --- test using EnvInput

(() ->
	oInput = new EnvInput("""
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
	tree = oInput.getTree()

	simple.equal 78, tree, taml("""
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
	oInput = new EnvInput(contents)
	tree = oInput.getTree()

	expect = taml("""
			---
			-
				node:
					type: if_truthy
					key: development
				lineNum: 1
				body:
					-
						node:
							type: assign
							key: color
							value: magenta
						lineNum: 2
					-
						node:
							type: assign
							key: mood
							value: somber
						lineNum: 3
			-
				node:
					type: if_falsy
					key: development
				lineNum: 4
				body:
					-
						node:
							type: assign
							key: color
							value: azure
						lineNum: 5
					-
						node:
							type: assign
							key: mood
							value: happy
						lineNum: 6
			""")

	simple.equal 100, tree, expect
	)()

# ---------------------------------------------------------------------------
# --- test env var replacement

(() ->
	oInput = new EnvInput("""
			dir_root = /usr/project
			dir_data = $dir_root/data
			""")
	tree = oInput.getTree()
	procEnv(tree)

	simple.equal 159, getenv('dir_data'), "/usr/project/data"

	)()

# ---------------------------------------------------------------------------
# --- test if environment is really loaded using .env file

(() ->
	setenv('development', 'yes')

	loadEnvFrom(dir)

	simple.equal 148, getenv('development'), 'yes'
	simple.equal 149, getenv('color'), 'magenta'
	simple.equal 150, getenv('mood'), 'somber'

	)()

# ---------------------------------------------------------------------------
# --- test prefix

(() ->
	clearenv 'dir_root','sb.indent','dir_data','sb.dev'

	loadEnvString("""
			dir_root = /usr/project
			sb.indent = 3
			dir_data = /usr/project/data
			sb.dev = yes
			""", 'sb.')

	simple.equal 188, getenv('dir_root'), undef
	simple.equal 189, getenv('sb.indent'), '3'
	simple.equal 190, getenv('dir_data'), undef
	simple.equal 191, getenv('sb.dev'), 'yes'

	)()


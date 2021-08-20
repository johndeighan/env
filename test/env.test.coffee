# env.test.coffee

import {strict as assert} from 'assert'

import {AvaTester} from '@jdeighan/ava-tester'
import {say, undef, pass, taml} from '@jdeighan/coffee-utils'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {mydir} from '@jdeighan/coffee-utils/fs'
import {
	EnvInput,
	loadEnvFrom,
	loadEnvFile,
	parseEnv,
	procEnv,
	} from '@jdeighan/env'

dir = mydir(`import.meta.url`)

simple = new AvaTester()

# ---------------------------------------------------------------------------

contents = """
		development = yes
		if development
			color = red
			if usemoods
				mood = somber
		if not development
			color = blue
			if usemoods
				mood = happy
		"""

# ---------------------------------------------------------------------------
# --- test using EnvInput

(() ->
	oInput = new EnvInput(contents)
	tree = oInput.getTree()

	simple.equal 78, tree, taml("""
			---
			-
				lineNum: 1
				node:
					type: assign
					key: DEVELOPMENT
					value: 'yes'
			-
				lineNum: 2
				node:
					type: if_truthy
					key: DEVELOPMENT
				body:
					-
						lineNum: 3
						node:
							type: assign
							key: COLOR
							value: red
					-
						lineNum: 4
						node:
							type: if_truthy
							key: USEMOODS
						body:
							-
								lineNum: 5
								node:
									type: assign
									key: MOOD
									value: somber
			-
				lineNum: 6
				node:
					type: if_falsy
					key: DEVELOPMENT
				body:
					-
						lineNum: 7
						node:
							type: assign
							key: COLOR
							value: blue
					-
						lineNum: 8
						node:
							type: if_truthy
							key: USEMOODS
						body:
							-
								lineNum: 9
								node:
									type: assign
									key: MOOD
									value: happy
			""")
	)()

# ---------------------------------------------------------------------------
# --- test using .env file

(() ->
	tree = loadEnvFile(dir)

	simple.equal 100, tree, taml("""
			---
			-
				node:
					type: if_truthy
					key: DEVELOPMENT
				lineNum: 1
				body:
					-
						node:
							type: assign
							key: COLOR
							value: magenta
						lineNum: 2
					-
						node:
							type: assign
							key: MOOD
							value: somber
						lineNum: 3
			-
				node:
					type: if_falsy
					key: DEVELOPMENT
				lineNum: 4
				body:
					-
						node:
							type: assign
							key: COLOR
							value: azure
						lineNum: 5
					-
						node:
							type: assign
							key: MOOD
							value: happy
						lineNum: 6
			""")
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

	simple.equal 159, process.env.DIR_DATA, "/usr/project/data"

	)()

# ---------------------------------------------------------------------------
# --- test if environment is really loaded using .env file

(() ->
	process.env['DEVELOPMENT'] = 'yes'

	tree = loadEnvFile(dir)
	procEnv(tree)

	simple.equal 148, process.env.DEVELOPMENT, 'yes'
	simple.equal 149, process.env.COLOR, 'magenta'
	simple.equal 150, process.env.MOOD, 'somber'

	)()

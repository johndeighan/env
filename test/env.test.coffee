# env.test.coffee

import {strict as assert} from 'assert'

import {AvaTester} from '@jdeighan/ava-tester'
import {say, undef, pass, taml} from '@jdeighan/coffee-utils'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {mydir} from '@jdeighan/coffee-utils/fs'
import {parsePLL} from '@jdeighan/string-input/pll'
import {
	loadEnvFrom,
	loadEnvFile,
	parseEnv,
	procEnv,
	EnvMapper,
	} from '@jdeighan/env'

dir = mydir(`import.meta.url`)

tester = new AvaTester()

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
# --- test using EnvMapper

(() ->
	tree = parsePLL(contents, EnvMapper)

	tester.equal 78, tree, taml("""
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

	tester.equal 100, tree, taml("""
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
# --- test if environment is really loaded using .env file

(() ->
	process.env['DEVELOPMENT'] = 'yes'

	tree = loadEnvFile(dir)
	procEnv(tree)

	tester.equal 148, process.env.DEVELOPMENT, 'yes'
	tester.equal 149, process.env.COLOR, 'magenta'
	tester.equal 150, process.env.MOOD, 'somber'

	)()

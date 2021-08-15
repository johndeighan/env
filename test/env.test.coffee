# env.test.coffee

import {strict as assert} from 'assert'

import {AvaTester} from '@jdeighan/ava-tester'
import {say, undef, pass, taml} from '@jdeighan/coffee-utils'
import {mydir} from '@jdeighan/coffee-utils/fs'
import {parsePLL} from '@jdeighan/string-input/pll'
import {loadenv, EnvMapper} from '@jdeighan/env'

dir = mydir(`import.meta.url`)

tester = new AvaTester

# loadenv dir
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
# --- test using identity mapper

(() ->
	result = parsePLL(contents, (x) -> x)

	tester.equal 37, result, taml("""
		---
		-
			node: development = yes
		-
			node: if development
			lChildren:
				-
					node: color = red
				-
					node: if usemoods
					lChildren:
						-
							node: mood = somber
		-
			node: if not development
			lChildren:
				-
					node: color = blue
				-
					node: if usemoods
					lChildren:
						-
							node: mood = happy
			""")
	)()

# ---------------------------------------------------------------------------
# --- test using EnvMapper

(() ->

	result = parsePLL(contents, EnvMapper)

	tester.equal 37, result, taml("""
			---
			-
				node:
					type: assign
					key: development
					value: 'yes'
			-
				node:
					type: if_truthy
					key: development
				lChildren:
					-
						node:
							type: assign
							key: color
							value: red
					-
						node:
							type: if_truthy
							key: usemoods
						lChildren:
							-
								node:
									type: assign
									key: mood
									value: somber
			-
				node:
					type: if_falsy
					key: development
				lChildren:
					-
						node:
							type: assign
							key: color
							value: blue
					-
						node:
							type: if_truthy
							key: usemoods
						lChildren:
							-
								node:
									type: assign
									key: mood
									value: happy
			""")
	)()

# env.test.coffee

import assert from 'assert'
import pathlib from 'path'

import {undef} from '@jdeighan/coffee-utils'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {log} from '@jdeighan/coffee-utils/log'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {loadEnvFrom, loadEnvString} from '@jdeighan/env'

test_dir = mydir(`import.meta.url`)  # directory this file is in
root_dir = pathlib.resolve(test_dir, '..')
sub_dir = mkpath(test_dir, 'subdir')

simple = new UnitTester()

###   Contents of relevant .env files:

Root .env   (in root_dir)

	if development
		color = magenta
		mood = somber
	if not development
		color = azure
		mood = happy
	value = 1

test .env    (in test_dir)

	if mood == 'somber'
		bgColor = sadness
		show = yes
	if mood == 'happy'
		bgColor = purple
		show = no
	value = 2

test/subdir .env    (in sub_dir)

	show = maybe
	value = 3

###
# ---------------------------------------------------------------------------
# --- test loading from root_dir

(() ->
	process.env.development = 'yes'
	loadEnvFrom(root_dir)

	simple.equal 54, process.env.development, 'yes'
	simple.equal 55, process.env.color, 'magenta'
	simple.equal 56, process.env.mood, 'somber'
	simple.equal 57, process.env.bgColor, undef
	simple.equal 61, process.env.value, '1'
	)()

(() ->
	delete process.env.development
	loadEnvFrom(root_dir)

	simple.equal 64, process.env.development, undef
	simple.equal 65, process.env.color, 'azure'
	simple.equal 66, process.env.mood, 'happy'
	simple.equal 67, process.env.bgColor, undef
	simple.equal 61, process.env.value, '1'
	)()

# ---------------------------------------------------------------------------
# --- test loading from test_dir

(() ->
	process.env.development = 'yes'
	loadEnvFrom(test_dir)

	simple.equal 77, process.env.development, 'yes'
	simple.equal 78, process.env.color, 'magenta'
	simple.equal 79, process.env.mood, 'somber'
	simple.equal 80, process.env.bgColor, 'sadness'
	simple.equal 61, process.env.value, '2'
	)()

(() ->
	delete process.env.development
	loadEnvFrom(test_dir)

	simple.equal 87, process.env.development, undef
	simple.equal 88, process.env.color, 'azure'
	simple.equal 89, process.env.mood, 'happy'
	simple.equal 90, process.env.bgColor, 'purple'
	simple.equal 61, process.env.value, '2'
	)()

# ---------------------------------------------------------------------------
# --- test loading from sub_dir

(() ->
	process.env.development = 'yes'
	loadEnvFrom(sub_dir)

	simple.equal 100, process.env.show, 'maybe'
	simple.equal 61, process.env.value, '3'
	)()

(() ->
	delete process.env.development
	loadEnvFrom(sub_dir)

	simple.equal 107, process.env.show, 'maybe'
	simple.equal 61, process.env.value, '3'
	)()

# ---------------------------------------------------------------------------
# --- test prefix

(() ->
	delete process.env['dir_root']
	delete process.env['sb.indent']
	delete process.env['dir_data']
	delete process.env['sb.dev']

	loadEnvString("""
			dir_root = /usr/project
			sb.indent = 3
			dir_data = /usr/project/data
			sb.dev = yes
			""", {
			prefix: 'sb.',     # load only keys with prefix 'sb.'
			})

	simple.equal 128, process.env['dir_root'],  undef
	simple.equal 129, process.env['sb.indent'], '3'
	simple.equal 130, process.env['dir_data'],  undef
	simple.equal 131, process.env['sb.dev'],   'yes'

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

	simple.equal 156, process.env['dir_root'],  undef
	simple.equal 157, process.env['sb.indent'], undef
	simple.equal 158, process.env['indent'],    '3'

	simple.equal 160, process.env['dir_data'],  undef
	simple.equal 161, process.env['sb.dev'],    undef
	simple.equal 162, process.env['dev'],       'yes'

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

	loadEnvString("""
			dev = yes
			dir_root = /usr/project
			dir_data = $dir_root/data
			""", {
				hCallbacks
				})

	simple.equal 194, hVariables, {
		dev: 'yes',
		dir_root: '/usr/project',
		dir_data: '/usr/project/data',
		}
	)()

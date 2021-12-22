# lib.test.coffee

import assert from 'assert'
import pathlib from 'path'

import {undef} from '@jdeighan/coffee-utils'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {log} from '@jdeighan/coffee-utils/log'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {loadEnvFrom} from '@jdeighan/env'

test_dir = mydir(`import.meta.url`)  # directory this file is in
project_dir = pathlib.resolve(test_dir, '..')
sub_dir = mkpath(test_dir, 'subdir')

simple = new UnitTester()

###   Contents of relevant .env files:

Root .env   (in project_dir)

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
# --- test loading from project_dir

(() ->
	process.env.development = 'yes'
	loadEnvFrom(project_dir)

	simple.equal 54, process.env.development, 'yes'
	simple.equal 55, process.env.color, 'magenta'
	simple.equal 56, process.env.mood, 'somber'
	simple.equal 57, process.env.bgColor, undef
	simple.equal 58, process.env.value, '1'
	)()

(() ->
	process.env.development = ''
	loadEnvFrom(project_dir)

	simple.equal 64, process.env.development, ''
	simple.equal 65, process.env.color, 'azure'
	simple.equal 66, process.env.mood, 'happy'
	simple.equal 67, process.env.bgColor, undef
	simple.equal 68, process.env.value, '1'
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
	simple.equal 81, process.env.value, '2'
	)()

(() ->
	process.env.development = ''
	loadEnvFrom(test_dir)

	simple.equal 87, process.env.development, ''
	simple.equal 88, process.env.color, 'azure'
	simple.equal 89, process.env.mood, 'happy'
	simple.equal 90, process.env.bgColor, 'purple'
	simple.equal 91, process.env.value, '2'
	)()

# ---------------------------------------------------------------------------
# --- test loading from sub_dir

(() ->
	process.env.development = 'yes'
	loadEnvFrom(sub_dir)

	simple.equal 100, process.env.show, 'maybe'
	simple.equal 101, process.env.value, '3'
	)()

(() ->
	process.env.development = ''
	loadEnvFrom(sub_dir)

	simple.equal 107, process.env.show, 'maybe'
	simple.equal 108, process.env.value, '3'
	)()

# lib.test.coffee

import assert from 'assert'
import pathlib from 'path'

import {undef} from '@jdeighan/coffee-utils'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {log} from '@jdeighan/coffee-utils/log'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {hPrivEnv, hPrivEnvCallbacks} from '@jdeighan/coffee-utils/privenv'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {loadPrivEnvFrom} from '@jdeighan/env'

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
	loadPrivEnvFrom(root_dir, undef, {development: 'yes'})

	simple.equal 54, hPrivEnv.development, 'yes'
	simple.equal 55, hPrivEnv.color, 'magenta'
	simple.equal 56, hPrivEnv.mood, 'somber'
	simple.equal 57, hPrivEnv.bgColor, undef
	simple.equal 58, hPrivEnv.value, '1'
	)()

(() ->
	loadPrivEnvFrom(root_dir)

	simple.equal 64, hPrivEnv.development, undef
	simple.equal 65, hPrivEnv.color, 'azure'
	simple.equal 66, hPrivEnv.mood, 'happy'
	simple.equal 67, hPrivEnv.bgColor, undef
	simple.equal 68, hPrivEnv.value, '1'
	)()

# ---------------------------------------------------------------------------
# --- test loading from test_dir

(() ->
	loadPrivEnvFrom(test_dir, undef, {development: 'yes'})

	simple.equal 77, hPrivEnv.development, 'yes'
	simple.equal 78, hPrivEnv.color, 'magenta'
	simple.equal 79, hPrivEnv.mood, 'somber'
	simple.equal 80, hPrivEnv.bgColor, 'sadness'
	simple.equal 81, hPrivEnv.value, '2'
	)()

(() ->
	loadPrivEnvFrom(test_dir)

	simple.equal 87, hPrivEnv.development, undef
	simple.equal 88, hPrivEnv.color, 'azure'
	simple.equal 89, hPrivEnv.mood, 'happy'
	simple.equal 90, hPrivEnv.bgColor, 'purple'
	simple.equal 91, hPrivEnv.value, '2'
	)()

# ---------------------------------------------------------------------------
# --- test loading from sub_dir

(() ->
	loadPrivEnvFrom(sub_dir, undef, {development: 'yes'})

	simple.equal 100, hPrivEnv.show, 'maybe'
	simple.equal 101, hPrivEnv.value, '3'
	)()

(() ->
	loadPrivEnvFrom(sub_dir)

	simple.equal 107, hPrivEnv.show, 'maybe'
	simple.equal 108, hPrivEnv.value, '3'
	)()

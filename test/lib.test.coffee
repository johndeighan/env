# lib.test.coffee

import {strict as assert} from 'assert'
import {resolve} from 'path';

import {undef} from '@jdeighan/coffee-utils'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {log} from '@jdeighan/coffee-utils/log'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {hEnvLib, hEnvLibCallbacks} from '@jdeighan/coffee-utils/envlib'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {loadEnvLibFrom} from '@jdeighan/env'

test_dir = mydir(`import.meta.url`)  # directory this file is in
root_dir = resolve(test_dir, '..')
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
	loadEnvLibFrom(root_dir, undef, {development: 'yes'})

	simple.equal 54, hEnvLib.development, 'yes'
	simple.equal 55, hEnvLib.color, 'magenta'
	simple.equal 56, hEnvLib.mood, 'somber'
	simple.equal 57, hEnvLib.bgColor, undef
	simple.equal 58, hEnvLib.value, '1'
	)()

(() ->
	loadEnvLibFrom(root_dir)

	simple.equal 64, hEnvLib.development, undef
	simple.equal 65, hEnvLib.color, 'azure'
	simple.equal 66, hEnvLib.mood, 'happy'
	simple.equal 67, hEnvLib.bgColor, undef
	simple.equal 68, hEnvLib.value, '1'
	)()

# ---------------------------------------------------------------------------
# --- test loading from test_dir

(() ->
	loadEnvLibFrom(test_dir, undef, {development: 'yes'})

	simple.equal 77, hEnvLib.development, 'yes'
	simple.equal 78, hEnvLib.color, 'magenta'
	simple.equal 79, hEnvLib.mood, 'somber'
	simple.equal 80, hEnvLib.bgColor, 'sadness'
	simple.equal 81, hEnvLib.value, '2'
	)()

(() ->
	loadEnvLibFrom(test_dir)

	simple.equal 87, hEnvLib.development, undef
	simple.equal 88, hEnvLib.color, 'azure'
	simple.equal 89, hEnvLib.mood, 'happy'
	simple.equal 90, hEnvLib.bgColor, 'purple'
	simple.equal 91, hEnvLib.value, '2'
	)()

# ---------------------------------------------------------------------------
# --- test loading from sub_dir

(() ->
	loadEnvLibFrom(sub_dir, undef, {development: 'yes'})

	simple.equal 100, hEnvLib.show, 'maybe'
	simple.equal 101, hEnvLib.value, '3'
	)()

(() ->
	loadEnvLibFrom(sub_dir)

	simple.equal 107, hEnvLib.show, 'maybe'
	simple.equal 108, hEnvLib.value, '3'
	)()

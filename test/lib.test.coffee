# lib.test.coffee

import {strict as assert} from 'assert'
import {resolve} from 'path';

import {undef} from '@jdeighan/coffee-utils'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {log} from '@jdeighan/coffee-utils/log'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {loadEnvLibFrom} from '@jdeighan/env/lib'

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
	hEnv = loadEnvLibFrom(root_dir, undef, {development: 'yes'})

	simple.equal 53, hEnv.development, 'yes'
	simple.equal 54, hEnv.color, 'magenta'
	simple.equal 55, hEnv.mood, 'somber'
	simple.equal 56, hEnv.bgColor, undef
	simple.equal 57, hEnv.value, '1'
	)()

(() ->
	hEnv = loadEnvLibFrom(root_dir)

	simple.equal 63, hEnv.development, undef
	simple.equal 64, hEnv.color, 'azure'
	simple.equal 65, hEnv.mood, 'happy'
	simple.equal 66, hEnv.bgColor, undef
	simple.equal 67, hEnv.value, '1'
	)()

# ---------------------------------------------------------------------------
# --- test loading from test_dir

(() ->
	hEnv = loadEnvLibFrom(test_dir, undef, {development: 'yes'})

	simple.equal 77, hEnv.development, 'yes'
	simple.equal 78, hEnv.color, 'magenta'
	simple.equal 79, hEnv.mood, 'somber'
	simple.equal 80, hEnv.bgColor, 'sadness'
	simple.equal 61, hEnv.value, '2'
	)()

(() ->
	hEnv = loadEnvLibFrom(test_dir)

	simple.equal 87, hEnv.development, undef
	simple.equal 88, hEnv.color, 'azure'
	simple.equal 89, hEnv.mood, 'happy'
	simple.equal 90, hEnv.bgColor, 'purple'
	simple.equal 61, hEnv.value, '2'
	)()

# ---------------------------------------------------------------------------
# --- test loading from sub_dir

(() ->
	hEnv = loadEnvLibFrom(sub_dir, undef, {development: 'yes'})

	simple.equal 100, hEnv.show, 'maybe'
	simple.equal 61, hEnv.value, '3'
	)()

(() ->
	hEnv = loadEnvLibFrom(sub_dir)

	simple.equal 107, hEnv.show, 'maybe'
	simple.equal 61, hEnv.value, '3'
	)()

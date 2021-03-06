// Generated by CoffeeScript 2.6.1
// lib.test.coffee
var project_dir, simple, sub_dir, test_dir;

import assert from 'assert';

import pathlib from 'path';

import {
  UnitTesterNorm
} from '@jdeighan/unit-tester';

import {
  undef
} from '@jdeighan/coffee-utils';

import {
  debug,
  setDebugging
} from '@jdeighan/coffee-utils/debug';

import {
  log
} from '@jdeighan/coffee-utils/log';

import {
  mydir,
  mkpath
} from '@jdeighan/coffee-utils/fs';

import {
  loadEnvFrom
} from '@jdeighan/env';

test_dir = mydir(import.meta.url); // directory this file is in

project_dir = pathlib.resolve(test_dir, '..');

sub_dir = mkpath(test_dir, 'subdir');

simple = new UnitTesterNorm();

/*   Contents of relevant .env files:

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

*/
// ---------------------------------------------------------------------------
// --- test loading from project_dir
(function() {
  process.env.development = 'yes';
  loadEnvFrom(project_dir);
  simple.equal(54, process.env.development, 'yes');
  simple.equal(55, process.env.color, 'magenta');
  simple.equal(56, process.env.mood, 'somber');
  simple.equal(57, process.env.bgColor, undef);
  return simple.equal(58, process.env.value, '1');
})();

(function() {
  process.env.development = '';
  loadEnvFrom(project_dir);
  simple.equal(65, process.env.development, '');
  simple.equal(66, process.env.color, 'azure');
  simple.equal(67, process.env.mood, 'happy');
  simple.equal(68, process.env.bgColor, undef);
  return simple.equal(69, process.env.value, '1');
})();

// ---------------------------------------------------------------------------
// --- test loading from test_dir
(function() {
  process.env.development = 'yes';
  loadEnvFrom(test_dir);
  simple.equal(79, process.env.development, 'yes');
  simple.equal(80, process.env.color, 'magenta');
  simple.equal(81, process.env.mood, 'somber');
  simple.equal(82, process.env.bgColor, 'sadness');
  return simple.equal(83, process.env.value, '2');
})();

(function() {
  process.env.development = '';
  loadEnvFrom(test_dir);
  simple.equal(90, process.env.development, '');
  simple.equal(91, process.env.color, 'azure');
  simple.equal(92, process.env.mood, 'happy');
  simple.equal(93, process.env.bgColor, 'purple');
  return simple.equal(94, process.env.value, '2');
})();

// ---------------------------------------------------------------------------
// --- test loading from sub_dir
(function() {
  process.env.development = 'yes';
  loadEnvFrom(sub_dir);
  simple.equal(104, process.env.show, 'maybe');
  return simple.equal(105, process.env.value, '3');
})();

(function() {
  process.env.development = '';
  loadEnvFrom(sub_dir);
  simple.equal(112, process.env.show, 'maybe');
  return simple.equal(113, process.env.value, '3');
})();

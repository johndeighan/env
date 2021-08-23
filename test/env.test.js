// Generated by CoffeeScript 2.5.1
// env.test.coffee
var dir, simple;

import {
  strict as assert
} from 'assert';

import {
  AvaTester
} from '@jdeighan/ava-tester';

import {
  say,
  undef,
  pass,
  taml
} from '@jdeighan/coffee-utils';

import {
  debug,
  setDebugging
} from '@jdeighan/coffee-utils/debug';

import {
  mydir,
  pathTo,
  slurp
} from '@jdeighan/coffee-utils/fs';

import {
  EnvLoader,
  loadEnvFrom,
  loadEnvFile,
  loadEnvString
} from '@jdeighan/env';

dir = mydir(import.meta.url); // directory this file is in

simple = new AvaTester();

// ---------------------------------------------------------------------------
// --- test using EnvLoader
(function() {
  var env, tree;
  env = new EnvLoader(`development = yes
if development
	color = red
	if usemoods
		mood = somber
if not development
	color = blue
	if usemoods
		mood = happy`);
  tree = env.getTree();
  return simple.equal(35, tree, taml(`---
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
						value: happy`));
})();

// ---------------------------------------------------------------------------
// --- test using .env file
(function() {
  var contents, env, filepath, tree;
  filepath = pathTo('.env', dir, "up");
  contents = slurp(filepath);
  env = new EnvLoader(contents);
  tree = env.getTree();
  return simple.equal(103, tree, taml(`---
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
			lineNum: 6`));
})();

// ---------------------------------------------------------------------------
// --- test env var replacement
(function() {
  var env;
  env = new EnvLoader(`dir_root = /usr/project
dir_data = $dir_root/data`);
  env.load();
  return simple.equal(155, env.getVar('dir_data'), "/usr/project/data");
})();

// ---------------------------------------------------------------------------
// --- test if environment is really loaded using .env file

// Contents of .env file:
//   if development
//      color = magenta
//      mood = somber
//   if not development
//      color = azure
//      mood = happy
(function() {
  var env;
  process.env.development = 'yes';
  env = loadEnvFrom(dir);
  assert(env != null, "env is undefined on line 174");
  simple.equal(176, env.getVar('development'), 'yes');
  simple.equal(177, env.getVar('color'), 'magenta');
  return simple.equal(178, env.getVar('mood'), 'somber');
})();

// ---------------------------------------------------------------------------
// --- test prefix
(function() {
  var env;
  delete process.env['dir_root'];
  delete process.env['sb.indent'];
  delete process.env['dir_data'];
  delete process.env['sb.dev'];
  env = loadEnvString(`dir_root = /usr/project
sb.indent = 3
dir_data = /usr/project/data
sb.dev = yes`, {
    prefix: 'sb.'
  });
  simple.equal(200, env.getVar('dir_root'), undef);
  simple.equal(201, env.getVar('sb.indent'), '3');
  simple.equal(202, env.getVar('dir_data'), undef);
  return simple.equal(203, env.getVar('sb.dev'), 'yes');
})();

// ---------------------------------------------------------------------------
// --- test prefix with stripPrefix option
(function() {
  var env;
  delete process.env['dir_root'];
  delete process.env['sb.indent'];
  delete process.env['indent'];
  delete process.env['dir_data'];
  delete process.env['sb.dev'];
  delete process.env['dev'];
  env = loadEnvString(`dir_root = /usr/project
sb.indent = 3
dir_data = /usr/project/data
sb.dev = yes`, {
    prefix: 'sb.',
    stripPrefix: true
  });
  simple.equal(226, env.getVar('dir_root'), undef);
  simple.equal(227, env.getVar('sb.indent'), undef);
  simple.equal(228, env.getVar('indent'), '3');
  simple.equal(229, env.getVar('dir_data'), undef);
  simple.equal(230, env.getVar('sb.dev'), undef);
  return simple.equal(231, env.getVar('dev'), 'yes');
})();

// ---------------------------------------------------------------------------
// --- test hCallbacks
(function() {
  var env, hCallbacks, hVariables;
  hVariables = {};
  hCallbacks = {
    getVar: function(name) {
      return hVariables[name];
    },
    setVar: function(name, value) {
      return hVariables[name] = value;
    },
    clearVar: function(name) {
      return delete hVariables[name];
    },
    names: function() {
      return Object.keys(hVariables);
    }
  };
  env = loadEnvString(`dev = yes
dir_root = /usr/project
dir_data = $dir_root/data`, {hCallbacks});
  simple.equal(262, env.getVar('dir_root'), '/usr/project');
  simple.equal(263, env.getVar('dir_data'), '/usr/project/data');
  return simple.same_list(264, env.names(), ['dev', 'dir_root', 'dir_data']);
})();

// ---------------------------------------------------------------------------
// --- test hInitialVars
(function() {
  var env;
  delete process.env['dir_root'];
  delete process.env['dir_data'];
  env = loadEnvString(`dir_data = $dir_root/data`, {
    hInitialVars: {
      "dir_root": "/usr/project"
    }
  });
  return simple.equal(283, env.getVar('dir_data'), '/usr/project/data');
})();

// Generated by CoffeeScript 2.6.1
// EnvLib.coffee
var hCallbacks, hEnv;

import {
  strict as assert
} from 'assert';

import {
  undef
} from '@jdeighan/coffee-utils';

import {
  log
} from '@jdeighan/coffee-utils/log';

import {
  mkpath,
  slurp
} from '@jdeighan/coffee-utils/fs';

import {
  loadEnvFrom
} from '@jdeighan/env';

// --- import this to get access to all environment variables
//     NOTE: You'll need to import and call loadEnvLibFrom()
hEnv = {};

// ---------------------------------------------------------------------------
// Define custom callbacks to use with loadEnvFrom
hCallbacks = {
  getVar: function(name) {
    return hEnv[name];
  },
  setVar: function(name, value) {
    hEnv[name] = value;
  },
  clearVar: function(name) {
    delete hEnv[name];
  },
  clearAll: function() {
    hEnv = {};
  },
  names: function() {
    return Object.keys(hEnv);
  }
};

// ---------------------------------------------------------------------------
export var loadEnvLibFrom = function(searchDir, rootName = 'DIR_ROOT', hInit = {}) {
  hEnv = hInit; // reset, if there's been a previous call
  loadEnvFrom(searchDir, rootName, {hCallbacks});
  return hEnv;
};

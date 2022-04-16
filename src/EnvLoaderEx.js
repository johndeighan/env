// Generated by CoffeeScript 2.6.1
// EnvLoaderEx.coffee
var hDefCallbacks;

import pathlib from 'path';

import {
  assert,
  undef,
  pass,
  error,
  rtrim,
  isArray,
  isFunction,
  rtrunc,
  escapeStr,
  croak
} from '@jdeighan/coffee-utils';

import {
  log
} from '@jdeighan/coffee-utils/log';

import {
  debug
} from '@jdeighan/coffee-utils/debug';

import {
  slurp,
  pathTo,
  mkpath
} from '@jdeighan/coffee-utils/fs';

import {
  TreeMapper
} from '@jdeighan/mapper/tree';

hDefCallbacks = {
  getVar: function(name) {
    return process.env[name];
  },
  setVar: function(name, value) {
    process.env[name] = value;
  },
  clearVar: function(name) {
    delete process.env[name];
  },
  clearAll: function() {
    return process.env = {};
  },
  names: function() {
    return Object.keys(process.env);
  }
};

// ---------------------------------------------------------------------------
export var EnvLoader = class EnvLoader extends TreeMapper {
  constructor(contents, source, hOptions = {}) {
    // --- Valid options:
    //        prefix - load only vars with this prefix
    //        stripPrefix - remove the prefix before setting vars
    //        hCallbacks - callbacks to replace:
    //                     getVar, setVar, clearVar, clearAll, names
    super(contents, source);
    ({prefix: this.prefix, stripPrefix: this.stripPrefix, hCallbacks: this.hCallbacks} = hOptions);
    if (this.hCallbacks != null) {
      this.checkCallbacks();
    } else {
      this.hCallbacks = hDefCallbacks;
    }
  }

  // ..........................................................
  checkCallbacks() {
    var i, lMissing, len, name, ref;
    if (this.hCallbacks != null) {
      lMissing = [];
      ref = ['getVar', 'setVar', 'clearVar', 'clearAll', 'names'];
      for (i = 0, len = ref.length; i < len; i++) {
        name = ref[i];
        if (!isFunction(this.hCallbacks[name])) {
          lMissing.push(name);
        }
      }
      if (lMissing.length > 0) {
        error(`Missing callbacks: ${lMissing.join(',')}`);
      }
    }
  }

  // ..........................................................
  getVar(name) {
    return this.hCallbacks.getVar(name);
  }

  // ..........................................................
  setVar(name, value) {
    this.hCallbacks.setVar(name, value);
  }

  // ..........................................................
  clearVar(name) {
    this.hCallbacks.clearVar(name);
  }

  // ..........................................................
  clearAll() {
    this.hCallbacks.clearAll;
  }

  // ..........................................................
  names() {
    return this.hCallbacks.names();
  }

  // ..........................................................
  dump() {
    var i, len, name, ref;
    log("=== Environment Variables: ===");
    ref = this.names();
    for (i = 0, len = ref.length; i < len; i++) {
      name = ref[i];
      log(`   ${name} = '${this.getVar(name)}'`);
    }
  }

  // ..........................................................
  mapNode(str) {
    var _, key, lMatches, neg, op, result, value;
    debug(`enter EnvLoader.mapNode('${escapeStr(str)}')`);
    if (lMatches = str.match(/^([A-Za-z_\.]+)\s*=\s*(.*)$/)) { // identifier
      [_, key, value] = lMatches;
      if (this.prefix && (key.indexOf(this.prefix) !== 0)) {
        debug("return from EnvLoader.mapNode()");
        return undef;
      }
      if (this.stripPrefix) {
        key = key.substring(this.prefix.length);
      }
      result = {
        type: 'assign',
        key,
        value: rtrim(value)
      };
    } else if (lMatches = str.match(/^if\s+(?:(not)\s+)?([A-Za-z_]+)$/)) { // identifier
      [_, neg, key] = lMatches;
      if (neg) {
        result = {
          type: 'if_falsy',
          key
        };
      } else {
        result = {
          type: 'if_truthy',
          key
        };
      }
    } else if (lMatches = str.match(/^if\s+([A-Za-z_][A-Za-z0-9_]*)\s*(is|isnt|>|>=|<|<=)\s*(.*)$/)) { // identifier (key)
      // comparison operator
      [_, key, op, value] = lMatches;
      result = {
        type: 'compare',
        key,
        op,
        value: value.trim()
      };
    } else {
      error(`Invalid line: '${str}'`);
    }
    debug("return from EnvLoader.mapNode():", result);
    return result;
  }

  // ..........................................................
  expand(str) {
    var replacer;
    // --- NOTE: Must use => here, not -> so that "this" is set correctly
    replacer = (str) => {
      return this.getVar(str.substr(1));
    };
    return str.replace(/\$[A-Za-z_][A-Za-z0-9_]*/g, replacer);
  }

  // ..........................................................
  doCompare(arg1, op, arg2) {
    arg1 = this.getVar(arg1);
    arg2 = this.expand(arg2);
    switch (op) {
      case 'is':
        return arg1 === arg2;
      case 'isnt':
        return arg1 !== arg2;
      case '<':
        return Number(arg1) < Number(arg2);
      case '<=':
        return Number(arg1) <= Number(arg2);
      case '>':
        return Number(arg1) > Number(arg2);
      case '>=':
        return Number(arg1) >= Number(arg2);
      default:
        return error(`doCompare(): Invalid operator '${op}'`);
    }
  }

  // ..........................................................
  procEnv(tree) {
    var h, i, key, len, op, value;
    assert(tree != null, "procEnv(): tree is undef");
    debug("enter procEnv()", tree);
    for (i = 0, len = tree.length; i < len; i++) {
      h = tree[i];
      debug('h', h);
      switch (h.node.type) {
        case 'assign':
          ({key, value} = h.node);
          value = this.expand(value);
          this.setVar(key, value);
          debug(`procEnv(): assign ${key} = '${value}'`);
          break;
        case 'if_truthy':
          ({key} = h.node);
          debug(`if_truthy: '${key}'`);
          if (this.getVar(key)) {
            debug(`procEnv(): if_truthy('${key}') - proc subtree`);
            this.procEnv(h.subtree);
          } else {
            debug(`procEnv(): if_truthy('${key}') - skip`);
          }
          break;
        case 'if_falsy':
          ({key} = h.node);
          debug(`if_falsy: '${key}'`);
          if (this.getVar(key)) {
            debug(`procEnv(): if_falsy('${key}') - skip`);
          } else {
            debug(`procEnv(): if_falsy('${key}') - proc subtree`);
            this.procEnv(h.subtree);
          }
          break;
        case 'compare':
          ({key, op, value} = h.node);
          debug(`procEnv(key=${key}, value=${value})`);
          if (this.doCompare(key, op, value)) {
            debug(`procEnv(): compare('${key}','${value}') - proc subtree`);
            this.procEnv(h.subtree);
          } else {
            debug(`procEnv(): compare('${key}','${value}') - skip`);
          }
      }
    }
    debug("return from procEnv()");
  }

  // ..........................................................
  load() {
    var tree;
    debug("enter load()");
    tree = this.getTree();
    debug("TREE", tree);
    assert(tree != null, "load(): tree is undef");
    assert(isArray(tree), "load(): tree is not an array");
    this.procEnv(tree);
    debug("return from load()");
  }

};

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// Load environment from a string
export var loadEnvString = function(contents, hOptions = {}, source = undef) {
  var env;
  debug("enter loadEnvString()");
  env = new EnvLoader(contents, source, hOptions);
  env.load();
  debug("return from loadEnvString()");
};

// ---------------------------------------------------------------------------
// Load environment from a file
export var loadEnvFile = function(filepath, hOptions = {}) {
  var contents;
  debug(`enter loadEnvFile ${filepath}`);
  contents = slurp(filepath);
  loadEnvString(contents, hOptions, filepath);
  debug("return from loadEnvFile");
};

// ---------------------------------------------------------------------------
// Load environment from .env file
export var loadEnvFrom = function(searchDir, hOptions = {}) {
  var filepath, i, lPaths, len, path;
  // --- valid options:
  //        onefile - load only the first file found
  //        hCallbacks - getVar, setVar, clearVar, clearAll, names
  debug(`enter loadEnvFrom '${searchDir}'`);
  path = pathTo('.env', searchDir, "up");
  if (path == null) {
    debug("return from loadEnvFrom() - no .env file found");
    return;
  }
  debug(`found .env file: ${path}`);
  lPaths = [path]; // --- build an array of paths
  if (!hOptions.onefile) {
    // --- search upward for .env files, but process top down
    while (path = pathTo('.env', pathlib.resolve(rtrunc(path, 5), '..'), "up")) {
      debug(`found .env file: ${path}`);
      lPaths.unshift(path);
    }
  }
  debug('lPaths', lPaths);
  for (i = 0, len = lPaths.length; i < len; i++) {
    filepath = lPaths[i];
    loadEnvFile(filepath, hOptions);
  }
  debug("return from loadEnvFrom()");
  return lPaths;
};

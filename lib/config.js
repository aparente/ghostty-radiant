#!/usr/bin/env node
// ghostty-aura: Configuration reader with defaults
'use strict';

const fs = require('fs');
const path = require('path');

const CONFIG_PATH = process.env.GHOSTTY_AURA_CONFIG
  || path.join(process.env.HOME, '.claude', 'aura-config.json');

const DEFAULTS = {
  states: {
    connected:   { tint: '#4ade80', intensity: 0.15, transition: 'animate', auto_to: 'base', auto_ms: 1500 },
    working:     { tint: '#38bdf8', intensity: 0.2,  transition: 'animate' },
    needs_input: { tint: '#fbbf24', intensity: 0.25, transition: 'instant' },
    completed:   { tint: '#facc15', intensity: 0.15, transition: 'animate', auto_to: 'base', auto_ms: 2000 },
    error:       { tint: '#f87171', intensity: 0.3,  transition: 'instant' },
  },
  animation: { steps: 8, step_ms: 120 },
};

function loadConfig() {
  let user = {};
  try {
    user = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
  } catch {
    // No config file — use defaults
  }
  // Merge: user states override defaults per-state, animation merged at top level
  const states = { ...DEFAULTS.states };
  if (user.states) {
    for (const [name, overrides] of Object.entries(user.states)) {
      states[name] = { ...(states[name] || {}), ...overrides };
    }
  }
  const animation = { ...DEFAULTS.animation, ...(user.animation || {}) };
  return { states, animation };
}

function getState(stateName) {
  const config = loadConfig();
  return config.states[stateName] || null;
}

function getAnimation() {
  return loadConfig().animation;
}

function configExists() {
  return fs.existsSync(CONFIG_PATH);
}

// CLI: node config.js <subcommand>
if (require.main === module) {
  const [,, cmd, ...args] = process.argv;
  if (cmd === 'get-state') {
    const state = getState(args[0]);
    if (state) console.log(JSON.stringify(state));
    else { console.error(`Unknown state: ${args[0]}`); process.exit(1); }
  } else if (cmd === 'get-animation') {
    console.log(JSON.stringify(getAnimation()));
  } else if (cmd === 'exists') {
    process.exit(configExists() ? 0 : 1);
  } else if (cmd === 'path') {
    console.log(CONFIG_PATH);
  } else if (cmd === 'init') {
    const target = args[0] || CONFIG_PATH;
    const dir = path.dirname(target);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(target, JSON.stringify({ states: DEFAULTS.states, animation: DEFAULTS.animation }, null, 2));
  } else {
    console.error('Commands: get-state <name>, get-animation, exists, path, init [path]');
    process.exit(1);
  }
}

module.exports = { loadConfig, getState, getAnimation, configExists, CONFIG_PATH, DEFAULTS };

#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const HOME = process.env.HOME || '/root';
const CONFIG_PATH = process.env.OPENCLAW_CONFIG || path.join(HOME, '.openclaw', 'openclaw.json');
const API_URL = process.env.OPENROUTER_MODELS_URL || 'https://openrouter.ai/api/v1/models';
const DEFAULT_PRIMARY = process.env.OPENROUTER_PRIMARY || 'openrouter/qwen/qwen3-coder:free';
const MAX_FALLBACKS = Number.parseInt(process.env.OPENROUTER_MAX_FALLBACKS || '24', 10);
const DRY_RUN = process.argv.includes('--dry-run');
const KEEP_MISSING = process.argv.includes('--keep-missing');
const VERBOSE = process.argv.includes('--verbose');

function log(...args) {
  console.log('[sync-openrouter-free-models]', ...args);
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function writeJson(file, value) {
  fs.writeFileSync(file, JSON.stringify(value, null, 2) + '\n');
}

function ensureObject(obj, key) {
  if (!obj[key] || typeof obj[key] !== 'object' || Array.isArray(obj[key])) {
    obj[key] = {};
  }
  return obj[key];
}

function scoreModel(model) {
  const id = String(model.id || '').toLowerCase();
  const name = String(model.name || '').toLowerCase();
  const ctx = Number(model.context_length || 0);
  const prompt = Number(model.pricing?.prompt || 0);
  const completion = Number(model.pricing?.completion || 0);
  const architecture = String(model.architecture?.modality || '').toLowerCase();

  let score = 0;
  if (id.includes(':free')) score += 1000;
  if (id.includes('coder')) score += 100;
  if (id.includes('instruct')) score += 20;
  if (id.includes('chat')) score += 10;
  if (name.includes('coder')) score += 40;
  if (architecture.includes('text')) score += 5;
  score += Math.min(ctx / 1000, 200);
  if (prompt === 0) score += 50;
  if (completion === 0) score += 50;
  return score;
}

function sanitizeAliasSuffix(modelId) {
  return modelId
    .replace(/^openrouter\//, '')
    .replace(/[^a-zA-Z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .toLowerCase();
}

async function fetchCatalog() {
  const res = await fetch(API_URL, {
    headers: {
      'Accept': 'application/json',
      'User-Agent': 'openclaw-sync-openrouter-free-models/1.0'
    }
  });

  if (!res.ok) {
    throw new Error(`Failed to fetch ${API_URL}: ${res.status} ${res.statusText}`);
  }

  const body = await res.json();
  return Array.isArray(body.data) ? body.data : [];
}

async function main() {
  if (!fs.existsSync(CONFIG_PATH)) {
    throw new Error(`OpenClaw config not found: ${CONFIG_PATH}`);
  }

  const config = readJson(CONFIG_PATH);
  const catalog = await fetchCatalog();
  const freeModels = catalog
    .filter((item) => String(item.id || '').includes(':free'))
    .map((item) => ({ ...item, fullId: `openrouter/${item.id}` }))
    .sort((a, b) => scoreModel(b) - scoreModel(a) || a.fullId.localeCompare(b.fullId));

  if (freeModels.length === 0) {
    throw new Error('No OpenRouter free models found in catalog response.');
  }

  const agents = ensureObject(config, 'agents');
  const defaults = ensureObject(agents, 'defaults');
  const models = ensureObject(defaults, 'models');

  const existingKeys = new Set(Object.keys(models));
  const syncedKeys = new Set();

  for (const model of freeModels) {
    const key = model.fullId;
    const entry = models[key] && typeof models[key] === 'object' ? models[key] : {};
    entry.catalog = 'openrouter-free';
    entry.syncedAt = new Date().toISOString();
    entry.label = model.name || model.id;
    entry.contextLength = model.context_length || undefined;
    entry.inputModalities = model.architecture?.input_modalities || undefined;
    entry.outputModalities = model.architecture?.output_modalities || undefined;
    entry.description = model.description || undefined;
    entry.pricing = model.pricing || undefined;
    entry.topProvider = model.top_provider || undefined;
    entry.perRequestLimits = model.per_request_limits || undefined;
    entry.alias = entry.alias || `or-${sanitizeAliasSuffix(key)}`;
    models[key] = entry;
    syncedKeys.add(key);
  }

  if (!KEEP_MISSING) {
    for (const key of existingKeys) {
      if (key.startsWith('openrouter/') && models[key]?.catalog === 'openrouter-free' && !syncedKeys.has(key)) {
        delete models[key];
      }
    }
  }

  const configuredPrimary = defaults.model && typeof defaults.model === 'object'
    ? defaults.model.primary
    : typeof defaults.model === 'string'
      ? defaults.model
      : undefined;

  const primary = syncedKeys.has(DEFAULT_PRIMARY)
    ? DEFAULT_PRIMARY
    : syncedKeys.has(configuredPrimary)
      ? configuredPrimary
      : freeModels[0].fullId;

  const fallbacks = freeModels
    .map((m) => m.fullId)
    .filter((id) => id !== primary)
    .slice(0, Math.max(0, MAX_FALLBACKS));

  defaults.model = {
    primary,
    fallbacks
  };

  const auth = ensureObject(config, 'auth');
  const profiles = ensureObject(auth, 'profiles');
  if (!profiles['openrouter:default']) {
    profiles['openrouter:default'] = {
      provider: 'openrouter',
      mode: 'api_key'
    };
  }

  if (!DRY_RUN) {
    const backupPath = `${CONFIG_PATH}.bak-${Date.now()}`;
    fs.copyFileSync(CONFIG_PATH, backupPath);
    writeJson(CONFIG_PATH, config);
    log(`Backup written: ${backupPath}`);
    log(`Updated config: ${CONFIG_PATH}`);
  }

  log(`Found ${catalog.length} total OpenRouter models.`);
  log(`Synced ${freeModels.length} free models into agents.defaults.models.`);
  log(`Primary: ${primary}`);
  log(`Fallbacks: ${fallbacks.length}`);

  if (VERBOSE || DRY_RUN) {
    for (const model of freeModels.slice(0, 40)) {
      log(`- ${model.fullId}`);
    }
    if (freeModels.length > 40) {
      log(`...and ${freeModels.length - 40} more`);
    }
  }

  log('Tip: set OPENROUTER_API_KEY in ~/.openclaw/.env or run: openclaw models auth paste-token --provider openrouter');
}

main().catch((err) => {
  console.error('[sync-openrouter-free-models] ERROR:', err.message);
  process.exit(1);
});

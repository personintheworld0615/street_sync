#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const required = ['MAPS_API_KEY'];
const missing = required.filter((name) => !process.env[name] || process.env[name].trim() === '');

if (missing.length > 0) {
  console.error(`Missing required environment variable(s): ${missing.join(', ')}`);
  process.exit(1);
}

const indexPath = path.join(__dirname, '..', 'web', 'index.html');
const mapId = (process.env.MAP_ID || '').trim();

if (!fs.existsSync(indexPath)) {
  console.error('web/index.html not found; cannot inject the Maps config.');
  process.exit(1);
}

let html = fs.readFileSync(indexPath, 'utf8');
html = html.replace(/%MAPS_API_KEY%/g, process.env.MAPS_API_KEY.trim());
html = html.replace(/%MAP_ID%/g, mapId);

fs.writeFileSync(indexPath, html, 'utf8');
console.log('Injected web Maps config into web/index.html');

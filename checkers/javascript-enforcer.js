#!/usr/bin/env node
// JavaScript/TypeScript Code Enforcer - Uncompromising Standards
// "Code so good you could trust it with your friend's mom's life"

const fs = require('fs');
const path = require('path');

const RED = '\x1b[0;31m';
const YELLOW = '\x1b[1;33m';
const GREEN = '\x1b[0;32m';
const NC = '\x1b[0m';

let critical = 0, errors = 0, warnings = 0;

const CRITICAL_PATTERNS = {
  console_log: /console\.(log|debug|info|warn|error)\(/,
  todo: /(TODO|FIXME|HACK|XXX|TEMP|WIP|PLACEHOLDER)/,
  ts_ignore: /@ts-(ignore|expect-error|nocheck)/,
  any_type: /:\s*any\b/,
};

function checkFile(filePath) {
  if (!fs.existsSync(filePath)) {
    console.error(`Error: File not found: ${filePath}`);
    process.exit(1);
  }

  const lines = fs.readFileSync(filePath, 'utf8').split('\n');

  console.log(`🔍 Checking JS/TS file: ${filePath}`);
  console.log('━'.repeat(60));

  if (lines.length > 200) {
    console.log(`${RED}🚨 CRITICAL${NC}: File exceeds 200 lines`);
    console.log(`   File: ${filePath}`);
    console.log(`   Lines: ${lines.length} (limit: 200)`);
    critical++;
  }

  Object.entries(CRITICAL_PATTERNS).forEach(([name, pattern]) => {
    const matches = [];
    lines.forEach((line, i) => {
      if (pattern.test(line)) matches.push(i + 1);
    });

    if (matches.length) {
      console.log(`${RED}🚨 CRITICAL${NC}: No ${name} allowed`);
      console.log(`   File: ${filePath}`);
      console.log(`   Lines: ${matches.join(',')}`);
      critical++;
    }
  });

  console.log('━'.repeat(60));
  console.log('📊 Summary:');
  console.log(`   🚨 Critical: ${critical}`);
  console.log(`   ❌ Errors: ${errors}`);
  console.log(`   ⚠️  Warnings: ${warnings}`);

  if (critical > 0) {
    console.log(`${RED}❌ Check FAILED - fix critical issues${NC}`);
    process.exit(1);
  } else {
    console.log(`${GREEN}✅ Check passed!${NC}`);
    process.exit(0);
  }
}

if (process.argv.length < 3) {
  console.log('Usage: javascript-enforcer.js <file.js|file.ts>');
  process.exit(1);
}

checkFile(process.argv[2]);

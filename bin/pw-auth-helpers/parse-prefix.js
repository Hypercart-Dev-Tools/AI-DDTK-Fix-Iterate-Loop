const input = process.argv[2] ?? '';
const tokens = [];
let current = '';
let quote = null;
let escaping = false;
let tokenStarted = false;

function pushToken() {
  tokens.push(current);
  current = '';
  tokenStarted = false;
}

for (let i = 0; i < input.length; i += 1) {
  const ch = input[i];

  if (escaping) {
    current += ch;
    escaping = false;
    tokenStarted = true;
    continue;
  }

  if (quote === "'") {
    if (ch === "'") {
      quote = null;
    } else {
      current += ch;
      tokenStarted = true;
    }
    continue;
  }

  if (quote === '"') {
    if (ch === '"') {
      quote = null;
      continue;
    }

    if (ch === '') {
      const next = input[i + 1];
      if (next !== undefined && '"\$`'.includes(next)) {
        current += next;
        i += 1;
        tokenStarted = true;
        continue;
      }
    }

    current += ch;
    tokenStarted = true;
    continue;
  }

  if (ch === '') {
    escaping = true;
    tokenStarted = true;
    continue;
  }

  if (ch === "'" || ch === '"') {
    quote = ch;
    tokenStarted = true;
    continue;
  }

  if (/\s/.test(ch)) {
    if (tokenStarted || current.length > 0) {
      pushToken();
    }
    continue;
  }

  current += ch;
  tokenStarted = true;
}

if (escaping) {
  console.error('Trailing escape in --wp-cli value.');
  process.exit(1);
}

if (quote) {
  console.error('Unterminated quote in --wp-cli value.');
  process.exit(1);
}

if (tokenStarted || current.length > 0) {
  pushToken();
}

if (tokens.length === 0) {
  console.error('Empty --wp-cli command prefix.');
  process.exit(1);
}

for (const token of tokens) {
  console.log(token);
}

// QuickSnip — content script
// Runs on every page, watches for abbreviations and expands them instantly.

let snippets = [];
let maxLen = 0;
let enabled = true;
let buffer = '';

// ── Load from storage ──────────────────────────────────────────────────────

chrome.storage.local.get(['snippets', 'enabled'], (data) => {
  snippets = data.snippets || [];
  enabled  = data.enabled !== false;
  maxLen   = snippets.reduce((m, s) => Math.max(m, s.abbrev.length), 0);
});

chrome.storage.onChanged.addListener((changes) => {
  if (changes.snippets) {
    snippets = changes.snippets.newValue || [];
    maxLen   = snippets.reduce((m, s) => Math.max(m, s.abbrev.length), 0);
  }
  if (changes.enabled) enabled = changes.enabled.newValue;
});

// ── Date / time macros ─────────────────────────────────────────────────────

function processMacros(text) {
  const now  = new Date();
  const pad  = n => String(n).padStart(2, '0');
  const months     = ['January','February','March','April','May','June','July','August','September','October','November','December'];
  const shortMons  = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  const days       = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
  const shortDays  = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
  const h24  = now.getHours();
  const h12r = h24 % 12;
  const h12  = h12r === 0 ? 12 : h12r;

  return text
    .replace(/%Y/g,  now.getFullYear())
    .replace(/%y/g,  String(now.getFullYear()).slice(-2))
    .replace(/%B/g,  months[now.getMonth()])
    .replace(/%b/g,  shortMons[now.getMonth()])
    .replace(/%1m/g, now.getMonth() + 1)        // must precede %m
    .replace(/%m/g,  pad(now.getMonth() + 1))
    .replace(/%e/g,  now.getDate())
    .replace(/%d/g,  pad(now.getDate()))
    .replace(/%A/g,  days[now.getDay()])
    .replace(/%a/g,  shortDays[now.getDay()])
    .replace(/%H/g,  pad(h24))
    .replace(/%1I/g, h12)                        // must precede %I
    .replace(/%I/g,  pad(h12))
    .replace(/%M/g,  pad(now.getMinutes()))
    .replace(/%S/g,  pad(now.getSeconds()))
    .replace(/%p/g,  h24 < 12 ? 'AM' : 'PM')
    .replace(/%P/g,  h24 < 12 ? 'am' : 'pm');
}

// ── Snippet lookup ─────────────────────────────────────────────────────────

function findSnippet(buf) {
  if (!buf || maxLen === 0) return null;
  const lower = buf.toLowerCase();
  for (const s of snippets) {
    if (s.caseSensitive ? buf.endsWith(s.abbrev) : lower.endsWith(s.abbrev.toLowerCase())) {
      return s;
    }
  }
  return null;
}

// ── Expansion ──────────────────────────────────────────────────────────────

function expandInInput(el, snippet) {
  const raw      = processMacros(snippet.text);
  const cpIdx    = raw.indexOf('%|');
  const expanded = raw.replace('%|', '');
  const abbrevLen = snippet.abbrev.length;

  const start  = el.selectionStart - abbrevLen;
  const before = el.value.slice(0, start);
  const after  = el.value.slice(el.selectionStart);

  el.value = before + expanded + after;

  const newPos = cpIdx >= 0 ? start + cpIdx : start + expanded.length;
  el.selectionStart = el.selectionEnd = newPos;

  // Notify frameworks (React, Vue, etc.)
  el.dispatchEvent(new InputEvent('input',  { bubbles: true, inputType: 'insertText' }));
  el.dispatchEvent(new Event('change', { bubbles: true }));
}

function expandInContentEditable(snippet) {
  const raw      = processMacros(snippet.text);
  const cpIdx    = raw.indexOf('%|');
  const expanded = raw.replace('%|', '');
  const abbrevLen = snippet.abbrev.length;

  const sel = window.getSelection();
  if (!sel || sel.rangeCount === 0) return;

  const range = sel.getRangeAt(0).cloneRange();

  // Delete the abbreviation characters before the cursor
  try {
    range.setStart(range.startContainer, range.startOffset - abbrevLen);
  } catch (_) {
    // If we can't set the range (e.g. at start of node), fall back to execCommand only
  }
  range.deleteContents();
  sel.removeAllRanges();
  sel.addRange(range);

  // Insert expansion — execCommand works in Gmail, Docs, and most contenteditable
  document.execCommand('insertText', false, expanded);

  // Move cursor back if %| was used
  if (cpIdx >= 0) {
    const charsAfter = expanded.length - cpIdx;
    moveCursorBack(charsAfter);
  }
}

function moveCursorBack(n) {
  const sel = window.getSelection();
  if (!sel || sel.rangeCount === 0 || n <= 0) return;
  const range = sel.getRangeAt(0);
  try {
    range.setStart(range.startContainer, range.startOffset - n);
    range.collapse(true);
    sel.removeAllRanges();
    sel.addRange(range);
  } catch (_) {}
}

// ── Keyboard listener ──────────────────────────────────────────────────────

document.addEventListener('keydown', (e) => {
  if (!enabled) return;

  // Modifier combos → reset (user is doing a shortcut)
  if (e.metaKey || e.ctrlKey || e.altKey) {
    buffer = '';
    return;
  }

  // Navigation / special keys → reset
  if (['Escape','ArrowLeft','ArrowRight','ArrowUp','ArrowDown',
       'Enter','Tab','Home','End','PageUp','PageDown','Delete'].includes(e.key)) {
    buffer = '';
    return;
  }

  // Mirror backspace
  if (e.key === 'Backspace') {
    buffer = buffer.slice(0, -1);
    return;
  }

  // Only single printable chars
  if (e.key.length !== 1) return;

  const target = e.target;
  const isInput = target.tagName === 'INPUT' || target.tagName === 'TEXTAREA';
  const isEditable = target.isContentEditable;
  if (!isInput && !isEditable) return;

  buffer += e.key;
  if (maxLen > 0 && buffer.length > maxLen) buffer = buffer.slice(-maxLen);

  const snippet = findSnippet(buffer);
  if (!snippet) return;

  buffer = '';

  // Wait one tick so the keydown character lands in the field first
  setTimeout(() => {
    if (isInput)    expandInInput(target, snippet);
    else            expandInContentEditable(snippet);
  }, 0);

}, true); // capture = true so we run before the page's own listeners

// Reset buffer when focus moves to a different field
document.addEventListener('focusin',  () => { buffer = ''; }, true);

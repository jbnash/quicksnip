// QuickSnip popup

let snippets = [];
let editingId = null;  // null = new snippet, string = editing existing

const enabledToggle = document.getElementById('enabledToggle');
const toggleLabel   = document.getElementById('toggleLabel');
const searchEl      = document.getElementById('search');
const snippetList   = document.getElementById('snippetList');
const editForm      = document.getElementById('editForm');
const formAbbrev    = document.getElementById('formAbbrev');
const formLabel     = document.getElementById('formLabel');
const formText      = document.getElementById('formText');
const btnAdd        = document.getElementById('btnAdd');
const btnSave       = document.getElementById('btnSave');
const btnCancel     = document.getElementById('btnCancel');
const footer        = document.getElementById('footer');

// ── Load ───────────────────────────────────────────────────────────────────

chrome.storage.local.get(['snippets', 'enabled'], (data) => {
  snippets = data.snippets || [];
  const on = data.enabled !== false;
  enabledToggle.checked = on;
  toggleLabel.textContent = on ? 'Enabled' : 'Disabled';
  render();
});

// ── Toggle enabled ─────────────────────────────────────────────────────────

enabledToggle.addEventListener('change', () => {
  const on = enabledToggle.checked;
  toggleLabel.textContent = on ? 'Enabled' : 'Disabled';
  chrome.storage.local.set({ enabled: on });
});

// ── Search ─────────────────────────────────────────────────────────────────

searchEl.addEventListener('input', render);

// ── Add / Edit form ────────────────────────────────────────────────────────

btnAdd.addEventListener('click', () => {
  editingId = null;
  formAbbrev.value = '';
  formLabel.value  = '';
  formText.value   = '';
  showForm();
  formAbbrev.focus();
});

btnCancel.addEventListener('click', hideForm);

btnSave.addEventListener('click', () => {
  const abbrev = formAbbrev.value.trim();
  const text   = formText.value;
  const label  = formLabel.value.trim();

  if (!abbrev || !text) {
    formAbbrev.style.borderColor = abbrev ? '' : 'var(--danger)';
    formText.style.borderColor   = text   ? '' : 'var(--danger)';
    return;
  }
  formAbbrev.style.borderColor = '';
  formText.style.borderColor   = '';

  if (editingId) {
    snippets = snippets.map(s =>
      s.id === editingId ? { ...s, abbrev, text, label } : s
    );
  } else {
    snippets.push({ id: crypto.randomUUID(), abbrev, text, label });
  }

  save();
  hideForm();
  render();
});

// ── Render list ────────────────────────────────────────────────────────────

function render() {
  const q = searchEl.value.toLowerCase();
  const filtered = q
    ? snippets.filter(s =>
        s.abbrev.toLowerCase().includes(q) ||
        (s.label || '').toLowerCase().includes(q) ||
        s.text.toLowerCase().includes(q)
      )
    : snippets;

  footer.textContent = `${filtered.length} of ${snippets.count || snippets.length} snippets`;
  // Always show total in footer
  footer.textContent = q
    ? `${filtered.length} of ${snippets.length} snippets`
    : `${snippets.length} snippets`;

  if (filtered.length === 0) {
    snippetList.innerHTML = `
      <div class="empty">
        ${q ? 'No snippets match your search.' : 'No snippets yet.<br/>Click <strong>+ New</strong> to add your first one.'}
      </div>`;
    return;
  }

  snippetList.innerHTML = '';
  for (const s of filtered) {
    const row = document.createElement('div');
    row.className = 'snippet-row';
    row.innerHTML = `
      <span class="snip-abbrev">${esc(s.abbrev)}</span>
      <span class="snip-preview">${esc(s.label || s.text.replace(/\n/g, ' '))}</span>
      <span class="snip-actions">
        <button class="btn-icon edit" title="Edit" data-id="${s.id}">✎</button>
        <button class="btn-icon del"  title="Delete" data-id="${s.id}">✕</button>
      </span>`;
    snippetList.appendChild(row);
  }

  snippetList.querySelectorAll('.btn-icon.edit').forEach(btn => {
    btn.addEventListener('click', () => startEdit(btn.dataset.id));
  });
  snippetList.querySelectorAll('.btn-icon.del').forEach(btn => {
    btn.addEventListener('click', () => deleteSnippet(btn.dataset.id));
  });
}

// ── Edit ───────────────────────────────────────────────────────────────────

function startEdit(id) {
  const s = snippets.find(s => s.id === id);
  if (!s) return;
  editingId        = id;
  formAbbrev.value = s.abbrev;
  formLabel.value  = s.label || '';
  formText.value   = s.text;
  showForm();
  formAbbrev.focus();
}

// ── Delete ─────────────────────────────────────────────────────────────────

function deleteSnippet(id) {
  snippets = snippets.filter(s => s.id !== id);
  save();
  render();
}

// ── Form helpers ───────────────────────────────────────────────────────────

function showForm() {
  editForm.classList.add('visible');
  btnAdd.disabled = true;
}

function hideForm() {
  editForm.classList.remove('visible');
  btnAdd.disabled = false;
  editingId = null;
}

// ── Persist ────────────────────────────────────────────────────────────────

function save() {
  chrome.storage.local.set({ snippets });
}

// ── Util ───────────────────────────────────────────────────────────────────

function esc(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

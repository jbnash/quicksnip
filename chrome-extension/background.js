// Install starter snippets on first install only
chrome.runtime.onInstalled.addListener((details) => {
  if (details.reason !== 'install') return;

  const starters = [
    // Date & Time
    { id: crypto.randomUUID(), abbrev: 'ddate',     text: '%B %e, %Y',              label: 'Date: April 8, 2026' },
    { id: crypto.randomUUID(), abbrev: 'ttime',     text: '%1I:%M %p',              label: 'Time: 2:30 PM' },
    { id: crypto.randomUUID(), abbrev: 'ddatetime', text: '%B %e, %Y at %1I:%M %p', label: 'Date + Time' },
    { id: crypto.randomUUID(), abbrev: 'dyear',     text: '%Y',                     label: 'Year' },
    { id: crypto.randomUUID(), abbrev: 'dmon',      text: '%B %Y',                  label: 'Month + Year' },
    { id: crypto.randomUUID(), abbrev: 'diso',      text: '%Y-%m-%d',               label: 'ISO date' },

    // Greetings & Sign-offs
    { id: crypto.randomUUID(), abbrev: 'hhi',       text: 'Hi there,\n\n',          label: 'Greeting' },
    { id: crypto.randomUUID(), abbrev: 'hhope',     text: 'I hope this message finds you well.', label: 'Opening' },
    { id: crypto.randomUUID(), abbrev: 'tthanks',   text: 'Thank you!',             label: 'Thanks' },
    { id: crypto.randomUUID(), abbrev: 'tthank',    text: 'Thank you so much — I really appreciate it!', label: 'Thank you so much' },
    { id: crypto.randomUUID(), abbrev: 'bbye',      text: 'Best,',                  label: 'Sign-off' },
    { id: crypto.randomUUID(), abbrev: 'rregards',  text: 'Best regards,',          label: 'Sign-off' },
    { id: crypto.randomUUID(), abbrev: 'ccheers',   text: 'Cheers,',               label: 'Sign-off' },
    { id: crypto.randomUUID(), abbrev: 'ttake',     text: 'Take care,',             label: 'Sign-off' },
    { id: crypto.randomUUID(), abbrev: 'wwarm',     text: 'Warm regards,',          label: 'Sign-off' },

    // Common phrases
    { id: crypto.randomUUID(), abbrev: 'llmk',      text: 'Let me know!',           label: 'LMK' },
    { id: crypto.randomUUID(), abbrev: 'llmkif',    text: 'Let me know if you have any questions.', label: 'LMK if questions' },
    { id: crypto.randomUUID(), abbrev: 'pplease',   text: "Please don't hesitate to reach out if you have any questions.", label: 'Please reach out' },
    { id: crypto.randomUUID(), abbrev: 'ffup',      text: 'I wanted to follow up on my previous message.', label: 'Follow up' },
    { id: crypto.randomUUID(), abbrev: 'aasap',     text: 'as soon as possible',    label: 'ASAP' },
    { id: crypto.randomUUID(), abbrev: 'ffyi',      text: 'For your information,',  label: 'FYI' },
    { id: crypto.randomUUID(), abbrev: 'llgtm',     text: 'Looks good to me!',      label: 'LGTM' },
    { id: crypto.randomUUID(), abbrev: 'nnp',       text: 'No problem!',            label: 'NP' },
    { id: crypto.randomUUID(), abbrev: 'ssoon',     text: "I'll get back to you soon.", label: 'Get back soon' },
    { id: crypto.randomUUID(), abbrev: 'ttbd',      text: 'To be determined',       label: 'TBD' },
    { id: crypto.randomUUID(), abbrev: 'wwip',      text: 'Work in progress',       label: 'WIP' },

    // Formatting
    { id: crypto.randomUUID(), abbrev: 'ssep',      text: '---',                    label: 'Separator' },
    { id: crypto.randomUUID(), abbrev: 'bbullet',   text: '• ',                     label: 'Bullet' },
    { id: crypto.randomUUID(), abbrev: 'aarrow',    text: '→ ',                     label: 'Arrow' },
    { id: crypto.randomUUID(), abbrev: 'ccopy',     text: '© %Y',                   label: 'Copyright year' },

    // Personal — prompt user to edit these
    { id: crypto.randomUUID(), abbrev: 'mmyemail',  text: 'your@email.com',         label: 'Your email — edit me!' },
    { id: crypto.randomUUID(), abbrev: 'mmyphone',  text: '(555) 555-5555',         label: 'Your phone — edit me!' },
    { id: crypto.randomUUID(), abbrev: 'mmyname',   text: 'Your Name',              label: 'Your name — edit me!' },
  ];

  chrome.storage.local.set({ snippets: starters, enabled: true });
});

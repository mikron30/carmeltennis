// CARMEL TENNIS — SENIOR variant
// v3.3 structure, LARGER scale. Mirrors variant-sport-v33.jsx 1:1 but with larger
// type and tap targets (≥48px). Same partner-row pattern, same hero strip, same
// confirm flow — just bigger.
//
// Changes vs v3.3 (per design feedback):
//   • "mine" slots show user's first name (was "ההזמנה שלי")
//   • "+" chip for adding a new partner
//   • Day toggle uses day-of-month (no weather temp)
//   • Hours 7–21, "סגור" for past, mine=teal (production tokens)

const seniorStyles = `
  .sr-root{
    --bg:#fff8f3; --surface:#ffffff; --ink:#1f1715; --ink-2:#7a5447;
    --line:#f0e3d4; --line-2:#e9d8c8;
    --clay:#c0532b; --clay-d:#a8431f; --clay-tint:#fbeadb; --clay-ink:#a8431f;
    --green:#1f6f4a; --green-tint:#e2f1e9;
    --mine:#2f6473; --mine-ink:#ffffff;
    --past-bg:#f7efe7; --past-ink:#a89888;
    --warn:#c43a14;
    --shadow-mine: inset 0 -3px 0 rgba(0,0,0,0.22);

    width:380px;height:820px;background:var(--bg);color:var(--ink);
    font-family:"Heebo",system-ui,sans-serif;direction:rtl;
    display:flex;flex-direction:column;border:1px solid var(--line-2);
    border-radius:28px;overflow:hidden;position:relative;
  }
  .sr-root[data-theme="dark"]{
    --bg:#0e1413; --surface:#161e1c; --ink:#f1ebe4; --ink-2:#bdaea0;
    --line:#22302c; --line-2:#314642;
    --clay:#ff8a5c; --clay-d:#e06a3e; --clay-tint:#3a2017; --clay-ink:#ffc8a8;
    --green:#54c98c; --green-tint:#0f2a1f;
    --mine:#5fb5c2; --mine-ink:#0e1413;
    --past-bg:#141a19; --past-ink:#7a8a85;
    --warn:#ffb877;
  }

  /* ── HERO ── 64px strip: bigger toggle + ערב text + theme menu ── */
  .sr-hero{padding:10px 16px;background:linear-gradient(180deg,var(--clay) 0%,var(--clay-d) 100%);color:#fff;position:relative;overflow:hidden;display:flex;align-items:center;gap:10px;min-height:64px}
  .sr-hero::after{content:"";position:absolute;inset:0;background:repeating-linear-gradient(0deg,rgba(255,255,255,0) 0,rgba(255,255,255,0) 22px,rgba(255,255,255,0.06) 22px,rgba(255,255,255,0.06) 23px);pointer-events:none}
  .sr-toggle{background:rgba(0,0,0,0.22);border-radius:11px;padding:3px;display:flex;gap:2px;flex:1;position:relative;z-index:1}
  .sr-toggle button{flex:1;border:none;background:transparent;color:#fff;padding:10px 12px;font-size:18px;font-weight:800;border-radius:9px;cursor:pointer;font-family:inherit;display:inline-flex;align-items:center;justify-content:center;gap:7px;line-height:1;min-height:44px}
  .sr-toggle button.on{background:#fff;color:var(--clay-d)}
  .sr-toggle .dom{font-size:13px;font-weight:600;opacity:0.78;font-variant-numeric:tabular-nums}
  .sr-toggle button.on .dom{color:var(--clay-d);opacity:1}
  .sr-cap{display:flex;align-items:center;gap:7px;padding:0 4px;color:#fff;font-size:14px;font-weight:800;white-space:nowrap;position:relative;z-index:1}
  .sr-cap .pips{display:flex;gap:5px}
  .sr-cap .pip{width:9px;height:9px;border-radius:50%;background:rgba(255,255,255,0.28)}
  .sr-cap .pip.on{background:#fff}
  .sr-menu{width:48px;height:48px;border-radius:12px;background:rgba(0,0,0,0.22);border:none;color:#fff;font-size:22px;cursor:pointer;display:flex;align-items:center;justify-content:center;font-family:inherit;position:relative;z-index:1;flex-shrink:0}

  /* ── PARTNER ROW ── scrolling chips, selected chip = clay fill + avatar + larger ── */
  .sr-partners{display:flex;gap:10px;padding:14px 16px;overflow-x:auto;scrollbar-width:none;background:var(--surface);border-bottom:1px solid var(--line);align-items:center}
  .sr-partners::-webkit-scrollbar{display:none}
  .sr-partners .lbl{font-size:15px;color:var(--ink-2);font-weight:800;letter-spacing:0.02em;flex-shrink:0;padding-inline-end:2px}
  .sr-chip{padding:12px 16px;border-radius:12px;background:var(--clay-tint);border:1.5px solid transparent;font-size:18px;color:var(--clay-ink);font-weight:700;white-space:nowrap;cursor:pointer;font-family:inherit;display:inline-flex;align-items:center;gap:9px;min-height:52px;flex-shrink:0}
  .sr-chip .dot{width:10px;height:10px;border-radius:50%;background:var(--green);flex-shrink:0}
  .sr-chip.on{background:var(--clay);color:#fff;border-color:var(--clay-d);font-size:19px;font-weight:800;padding:13px 18px;box-shadow:var(--shadow-mine)}
  .sr-chip.on .dot{background:#fff;opacity:0.85}
  .sr-chip .av{width:30px;height:30px;border-radius:9px;background:var(--clay);color:#fff;display:flex;align-items:center;justify-content:center;font-weight:800;font-size:16px;flex-shrink:0}
  .sr-chip.on .av{background:rgba(0,0,0,0.22);color:#fff}
  .sr-chip.add{padding:12px;width:52px;height:52px;justify-content:center;background:transparent;border:2px dashed var(--line-2);color:var(--ink-2);font-size:28px;font-weight:600;line-height:1}

  /* ── COURT HEADER ── */
  .sr-courthdr{display:grid;grid-template-columns:54px 1fr 1fr;padding:12px 16px 6px;font-size:14px;font-weight:800;color:var(--ink);text-transform:uppercase;letter-spacing:0.08em;background:var(--bg);gap:10px}
  .sr-courthdr > *{text-align:center}

  /* ── GRID — 76px slots, 20px text, 22px hour labels ── */
  .sr-grid{flex:1;overflow-y:auto;padding:0 16px 16px;position:relative}
  .sr-row{display:grid;grid-template-columns:54px 1fr 1fr;gap:10px;margin-bottom:10px;align-items:stretch;border-radius:10px}
  .sr-row.busy{background:linear-gradient(90deg,rgba(192,83,43,0) 0%,rgba(192,83,43,0.05) 50%,rgba(192,83,43,0.10) 100%)}
  .sr-row .h{font-size:22px;color:var(--ink);display:flex;align-items:center;justify-content:center;font-weight:800;font-variant-numeric:tabular-nums}
  .sr-slot{min-height:76px;border-radius:14px;display:flex;align-items:center;justify-content:center;font-size:20px;font-weight:800;line-height:1.2;text-align:center;cursor:pointer;border:none;font-family:inherit;padding:10px 12px;position:relative;overflow:hidden;transition:transform 0.08s;gap:4px}
  .sr-slot:active{transform:scale(0.97)}
  .sr-slot.free{background:var(--green);color:#fff;border:2px solid transparent}
  .sr-slot.free .lbl{font-weight:800;font-size:20px}
  .sr-slot.taken{background:var(--clay);color:#fff;flex-direction:column;gap:2px}
  .sr-slot.taken .name{font-size:16px;font-weight:700;color:#fff;opacity:0.96;overflow:hidden;text-overflow:ellipsis;max-width:100%;white-space:nowrap}
  .sr-slot.mine{background:var(--mine);color:var(--mine-ink);box-shadow:var(--shadow-mine);border:2px solid color-mix(in srgb, var(--mine) 75%, black);flex-direction:column;gap:2px}
  .sr-slot.mine .me{font-size:18px;font-weight:800;letter-spacing:-0.01em}
  .sr-slot.mine .with{font-size:14px;opacity:0.88;font-weight:600}
  .sr-slot.past{background:var(--past-bg);color:var(--past-ink);border:2px dashed var(--line-2);cursor:not-allowed;font-size:17px;font-weight:700}
  .sr-slot.preview{background:var(--clay-tint);color:var(--clay-ink);border:2.5px solid var(--clay);font-weight:800;flex-direction:column;gap:2px;animation:srpulse 0.9s ease-in-out infinite}
  .sr-slot.preview .lbl{font-size:20px;font-weight:800}
  .sr-slot.preview .cta{font-size:12px;font-weight:800;letter-spacing:0.06em;text-transform:uppercase;opacity:0.85}
  @keyframes srpulse{0%,100%{box-shadow:0 0 0 0 rgba(192,83,43,0.4)}50%{box-shadow:0 0 0 8px rgba(192,83,43,0)}}

  /* CONFIRM BANNER */
  .sr-confirm{position:absolute;left:14px;right:14px;bottom:14px;background:var(--surface);border:2.5px solid var(--clay);border-radius:18px;padding:16px;display:flex;flex-direction:column;gap:14px;box-shadow:0 14px 36px rgba(0,0,0,0.22);z-index:5;animation:srup 0.22s ease-out}
  @keyframes srup{from{transform:translateY(40px);opacity:0}to{transform:translateY(0);opacity:1}}
  .sr-confirm .info{display:flex;align-items:center;gap:12px;min-width:0}
  .sr-confirm .info .av{width:48px;height:48px;border-radius:14px;background:var(--clay);color:#fff;display:flex;align-items:center;justify-content:center;font-weight:800;font-size:22px;flex-shrink:0}
  .sr-confirm .info .txt{flex:1;min-width:0}
  .sr-confirm .info .lbl{font-size:11px;color:var(--clay-ink);font-weight:800;letter-spacing:0.08em;text-transform:uppercase;display:block;margin-bottom:2px}
  .sr-confirm .info b{display:block;font-size:18px;font-weight:800;color:var(--ink);line-height:1.3}
  .sr-confirm .info b .with{color:var(--clay)}
  .sr-confirm .row{display:flex;gap:10px}
  .sr-confirm .btn{flex:1;padding:16px;border-radius:13px;border:none;font-family:inherit;font-size:17px;font-weight:800;cursor:pointer;min-height:56px}
  .sr-confirm .btn.cancel{background:transparent;color:var(--ink-2);border:2px solid var(--line-2);flex:0 0 auto;padding:16px 22px}
  .sr-confirm .btn.confirm{background:var(--clay);color:#fff;box-shadow:inset 0 -4px 0 rgba(0,0,0,0.18)}

  /* TOAST */
  .sr-toast{position:absolute;left:16px;right:16px;bottom:16px;padding:14px 18px;border-radius:12px;font-size:16px;font-weight:800;text-align:center;z-index:10;animation:srup 0.2s ease-out}
  .sr-toast.good{background:var(--green);color:#fff}
  .sr-toast.warn{background:var(--clay);color:#fff}
  .sr-toast.info{background:var(--ink);color:var(--bg)}

  /* sheet */
  .sr-sheet{position:absolute;inset:0;background:rgba(31,23,21,0.55);display:flex;align-items:flex-end;z-index:20;animation:srfade 0.18s ease-out}
  @keyframes srfade{from{opacity:0}to{opacity:1}}
  .sr-sheet-card{background:var(--surface);width:100%;border-radius:22px 22px 0 0;padding:22px 20px 24px}
  .sr-sheet h3{margin:0 0 6px;font-size:22px;font-weight:800;color:var(--ink)}
  .sr-sheet .sub{font-size:15px;color:var(--ink-2);margin-bottom:18px;line-height:1.4}
  .sr-sheet-btn{width:100%;padding:16px;border-radius:13px;border:none;font-family:inherit;font-size:17px;font-weight:800;cursor:pointer;margin-bottom:10px;min-height:58px}
  .sr-sheet-btn.primary{background:var(--clay);color:#fff}
  .sr-sheet-btn.secondary{background:var(--surface);color:var(--ink);border:1.5px solid var(--line-2)}
`;

function VariantSenior({ initialTheme = 'light' }) {
  const s = window.useBookingState();
  const [theme, setTheme] = React.useState(initialTheme);
  const [preview, setPreview] = React.useState(null);
  const [sheet, setSheet] = React.useState(null);

  const HOURS = [7,8,9,10,11,12,13,14,15,16,17,18,19,20,21];
  const NOW = 13 * 60 + 42;
  const isPast = (h) => s.day === 'today' && (h * 60 - NOW < 60);
  const busyHours = new Set([18,19,20]);

  const overlay = React.useMemo(() => ({
    today: { 2: { 17: { a: 'me', b: 'yoav' } } },
    tomorrow: { 1: { 18: { a: 'me', b: 'rotem' } } },
  }), []);
  const slotAt = (court, hour) => overlay[s.day]?.[court]?.[hour] || s.slotAt(court, hour);

  const recents = [
    { id: 'noa', available: true }, { id: 'dani', available: false },
    { id: 'yoav', available: true }, { id: 'rotem', available: true },
    { id: 'maya', available: false }, { id: 'tom', available: true },
  ];

  const usedEvenings = (() => {
    let n = 0;
    for (const day of ['today','tomorrow']) {
      for (const c of [1,2]) {
        for (const h of [18,19,20]) {
          const slot = overlay[day]?.[c]?.[h] || s.bookings[day]?.[c]?.[h];
          if (slot && (slot.a === 'me' || slot.b === 'me')) n++;
        }
      }
    }
    return Math.min(n, 3);
  })();

  const todayDate = 18, tomorrowDate = 19;
  const meName = s.partnerObj('me').name.split(' ')[0];

  const handleTap = (court, hour) => {
    const slot = slotAt(court, hour);
    if (isPast(hour)) return;
    if (slot && s.isMine(slot)) { setSheet({ kind: 'cancel', court, hour, slot }); return; }
    if (slot) { setSheet({ kind: 'taken', court, hour, slot }); return; }
    const key = `${court}-${hour}`;
    if (preview && preview.key === key) { s.book(court, hour); setPreview(null); return; }
    setPreview({ key, court, hour });
  };
  const confirmBooking = () => { if (preview) { s.book(preview.court, preview.hour); setPreview(null); } };

  return (
    <>
      <style>{seniorStyles}</style>
      <div className="sr-root" data-theme={theme}>

        {/* HERO */}
        <div className="sr-hero">
          <div className="sr-toggle">
            <button className={s.day === 'today' ? 'on' : ''} onClick={() => s.setDay('today')}>
              היום
            </button>
            <button className={s.day === 'tomorrow' ? 'on' : ''} onClick={() => s.setDay('tomorrow')}>
              מחר
            </button>
          </div>
          <div className="sr-cap" title={`${usedEvenings} מתוך 3 ערבים בשבוע`}>
            <span>ערב {usedEvenings}/3</span>
            <div className="pips">
              {[0,1,2].map(i => <div key={i} className={`pip ${i < usedEvenings ? 'on' : ''}`}></div>)}
            </div>
          </div>
          <button className="sr-menu" onClick={() => setTheme(t => t === 'dark' ? 'light' : 'dark')} title={theme === 'dark' ? 'מצב יום' : 'מצב לילה'}>
            {theme === 'dark' ? '☀' : '☾'}
          </button>
          <button className="sr-menu" title="תפריט">☰</button>
        </div>

        {/* PARTNER ROW */}
        <div className="sr-partners">
          <span className="lbl">עם:</span>
          {recents.map(({ id, available }) => {
            const p = s.partnerObj(id);
            const on = s.partner === id;
            const firstName = p.name.split(' ')[0];
            return (
              <button key={id} className={`sr-chip ${on ? 'on' : ''}`} onClick={() => s.setPartner(id)}>
                {on && <span className="av">{p.initial}</span>}
                {!on && available && <span className="dot"></span>}
                {firstName}
              </button>
            );
          })}
          <button className="sr-chip add" title="הוסף שותפ.ה">+</button>
        </div>

        <div className="sr-courthdr"><div></div><div>מגרש 2</div><div>מגרש 1</div></div>

        <div className="sr-grid">
          {HOURS.map(hour => {
            const busy = busyHours.has(hour);
            return (
              <div key={hour} className={`sr-row ${busy ? 'busy' : ''}`}>
                <div className="h">{hour}:00</div>
                {[2,1].map(court => {
                  const slot = slotAt(court, hour);
                  const past = isPast(hour);
                  const mine = s.isMine(slot);
                  const key = `${court}-${hour}`;
                  const isPreview = preview && preview.key === key;
                  let cls = 'free';
                  let inner = <span className="lbl">פנוי</span>;
                  if (isPreview) {
                    cls = 'preview';
                    inner = <><span className="lbl">{hour}:00</span><span className="cta">לחצ.י שוב</span></>;
                  } else if (past && !slot) {
                    cls = 'past';
                    inner = <span>סגור</span>;
                  } else if (mine) {
                    cls = 'mine';
                    const partner = s.partnerObj(slot.a === 'me' ? slot.b : slot.a);
                    inner = <><span className="me">{meName}</span><span className="with">עם {partner.short}</span></>;
                  } else if (slot) {
                    cls = 'taken';
                    const a = s.partnerObj(slot.a);
                    const b = s.partnerObj(slot.b);
                    inner = <span className="name">{a.short} · {b.short}</span>;
                  }
                  return (
                    <button key={court} className={`sr-slot ${cls}`} onClick={() => handleTap(court, hour)}>{inner}</button>
                  );
                })}
              </div>
            );
          })}
        </div>

        {preview && (
          <div className="sr-confirm">
            <div className="info">
              <div className="av">{s.partnerObj(s.partner)?.initial}</div>
              <div className="txt">
                <span className="lbl">אישור הזמנה</span>
                <b>{String(preview.hour).padStart(2,'0')}:00 · מגרש {preview.court} <span className="with">עם {s.partnerObj(s.partner)?.short}</span></b>
              </div>
            </div>
            <div className="row">
              <button className="btn cancel" onClick={() => setPreview(null)}>ביטול</button>
              <button className="btn confirm" onClick={confirmBooking}>אשר הזמנה</button>
            </div>
          </div>
        )}

        {sheet && (
          <div className="sr-sheet" onClick={() => setSheet(null)}>
            <div className="sr-sheet-card" onClick={e => e.stopPropagation()}>
              <h3>{sheet.kind === 'cancel' ? 'לבטל את ההזמנה?' : 'המשבצת תפוסה'}</h3>
              <p className="sub">
                {sheet.kind === 'cancel'
                  ? `${sheet.hour}:00 במגרש ${sheet.court}. ביטול אפשרי עד 3 שעות לפני המשחק.`
                  : `${sheet.hour}:00 במגרש ${sheet.court}. ההזמנה שייכת לחברים אחרים.`}
              </p>
              {sheet.kind === 'cancel' && (
                <button className="sr-sheet-btn primary" onClick={() => { s.book(sheet.court, sheet.hour); setSheet(null); }}>כן, בטל הזמנה</button>
              )}
              <button className="sr-sheet-btn secondary" onClick={() => setSheet(null)}>סגור</button>
            </div>
          </div>
        )}

        {s.toast && <div className={`sr-toast ${s.toast.kind}`}>{s.toast.msg}</div>}
      </div>
    </>
  );
}

window.VariantSenior = VariantSenior;

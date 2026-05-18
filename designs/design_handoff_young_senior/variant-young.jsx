// CARMEL TENNIS — YOUNG variant
// v3.3 structure, COMPACT scale. Mirrors variant-sport-v33.jsx 1:1 but with smaller
// type and tap targets for younger eyes. Production tokens from booking_screen_v31.dart.
//
// Changes vs v3.3 (per design feedback):
//   • "mine" slots show user's first name (was "ההזמנה שלי")
//   • "+" chip for adding a new partner (was nothing)
//   • Day toggle uses day-of-month (no weather temp)
//   • Hours 7–21, "סגור" for past, mine=teal (production tokens)

const youngStyles = `
  .yg-root{
    --bg:#fff8f3; --surface:#ffffff; --ink:#1f1715; --ink-2:#7a5447;
    --line:#f0e3d4; --line-2:#e9d8c8;
    --clay:#c0532b; --clay-d:#a8431f; --clay-tint:#fbeadb; --clay-ink:#a8431f;
    --green:#1f6f4a; --green-tint:#e2f1e9;
    --mine:#2f6473; --mine-ink:#ffffff;
    --past-bg:#f7efe7; --past-ink:#c8b8ac;
    --warn:#c43a14;
    --shadow-mine: inset 0 -2px 0 rgba(0,0,0,0.22);

    width:380px;height:820px;background:var(--bg);color:var(--ink);
    font-family:"Heebo",system-ui,sans-serif;direction:rtl;
    display:flex;flex-direction:column;border:1px solid var(--line-2);
    border-radius:28px;overflow:hidden;position:relative;
  }
  .yg-root[data-theme="dark"]{
    --bg:#0e1413; --surface:#161e1c; --ink:#f1ebe4; --ink-2:#9a8a7e;
    --line:#22302c; --line-2:#1a2422;
    --clay:#e06a3e; --clay-d:#c0532b; --clay-tint:#2a1a13; --clay-ink:#f5a884;
    --green:#3aa674; --green-tint:#0f2a1f;
    --mine:#2e7c86; --mine-ink:#ffffff;
    --past-bg:#141a19; --past-ink:#3a4744;
    --warn:#ffb877;
  }

  /* ── HERO ── single 44px strip: day toggle + ערב pips + theme menu ── */
  .yg-hero{padding:6px 12px;background:linear-gradient(180deg,var(--clay) 0%,var(--clay-d) 100%);color:#fff;position:relative;overflow:hidden;display:flex;align-items:center;gap:8px;min-height:44px}
  .yg-hero::after{content:"";position:absolute;inset:0;background:repeating-linear-gradient(0deg,rgba(255,255,255,0) 0,rgba(255,255,255,0) 22px,rgba(255,255,255,0.06) 22px,rgba(255,255,255,0.06) 23px);pointer-events:none}
  .yg-toggle{background:rgba(0,0,0,0.22);border-radius:8px;padding:2px;display:flex;gap:1px;flex:1;position:relative;z-index:1}
  .yg-toggle button{flex:1;border:none;background:transparent;color:#fff;padding:6px 9px;font-size:13px;font-weight:700;border-radius:6px;cursor:pointer;font-family:inherit;display:inline-flex;align-items:center;justify-content:center;gap:5px;line-height:1;min-height:30px}
  .yg-toggle button.on{background:#fff;color:var(--clay-d)}
  .yg-toggle .dom{font-size:10px;font-weight:600;opacity:0.8;font-variant-numeric:tabular-nums}
  .yg-toggle button.on .dom{color:var(--clay-d);opacity:1}
  .yg-cap{display:flex;align-items:center;gap:5px;padding:0 4px;color:#fff;font-size:11px;font-weight:700;white-space:nowrap;position:relative;z-index:1}
  .yg-cap .pips{display:flex;gap:3px}
  .yg-cap .pip{width:6px;height:6px;border-radius:50%;background:rgba(255,255,255,0.28)}
  .yg-cap .pip.on{background:#fff}
  .yg-menu{width:32px;height:32px;border-radius:8px;background:rgba(0,0,0,0.22);border:none;color:#fff;font-size:14px;cursor:pointer;display:flex;align-items:center;justify-content:center;font-family:inherit;position:relative;z-index:1;flex-shrink:0}

  /* ── PARTNER ROW ── scrolling chips, selected = clay fill + avatar (the only place partner appears) ── */
  .yg-partners{display:flex;gap:6px;padding:8px 12px;overflow-x:auto;scrollbar-width:none;background:var(--surface);border-bottom:1px solid var(--line);align-items:center}
  .yg-partners::-webkit-scrollbar{display:none}
  .yg-partners .lbl{font-size:11px;color:var(--ink-2);font-weight:800;letter-spacing:0.04em;flex-shrink:0;padding-inline-end:1px}
  .yg-chip{padding:6px 10px;border-radius:8px;background:var(--clay-tint);border:1.5px solid transparent;font-size:13px;color:var(--clay-ink);font-weight:700;white-space:nowrap;cursor:pointer;font-family:inherit;display:inline-flex;align-items:center;gap:6px;min-height:34px;flex-shrink:0}
  .yg-chip .dot{width:6px;height:6px;border-radius:50%;background:var(--green);flex-shrink:0}
  .yg-chip.on{background:var(--clay);color:#fff;border-color:var(--clay-d);font-size:14px;font-weight:800;padding:7px 12px;box-shadow:var(--shadow-mine)}
  .yg-chip.on .dot{background:#fff;opacity:0.85}
  .yg-chip .av{width:20px;height:20px;border-radius:6px;background:var(--clay);color:#fff;display:flex;align-items:center;justify-content:center;font-weight:800;font-size:11px;flex-shrink:0}
  .yg-chip.on .av{background:rgba(0,0,0,0.22);color:#fff}
  .yg-chip.add{padding:6px;width:34px;height:34px;justify-content:center;background:transparent;border:1.5px dashed var(--line-2);color:var(--ink-2);font-size:18px;font-weight:700}

  /* ── COURT HEADER ── */
  .yg-courthdr{display:grid;grid-template-columns:38px 1fr 1fr;padding:8px 12px 4px;font-size:11px;font-weight:800;color:var(--ink);text-transform:uppercase;letter-spacing:0.06em;background:var(--bg);gap:6px}
  .yg-courthdr > *{text-align:center}

  /* ── GRID — 48px slots, 14px text, 15px hour labels ── */
  .yg-grid{flex:1;overflow-y:auto;padding:0 12px 12px;position:relative}
  .yg-row{display:grid;grid-template-columns:38px 1fr 1fr;gap:6px;margin-bottom:6px;align-items:stretch;border-radius:7px}
  .yg-row.busy{background:linear-gradient(90deg,rgba(192,83,43,0) 0%,rgba(192,83,43,0.05) 50%,rgba(192,83,43,0.10) 100%)}
  .yg-row .h{font-size:15px;color:var(--ink);display:flex;align-items:center;justify-content:center;font-weight:800;font-variant-numeric:tabular-nums}
  .yg-slot{min-height:48px;border-radius:9px;display:flex;align-items:center;justify-content:center;font-size:14px;font-weight:700;line-height:1.2;text-align:center;cursor:pointer;border:none;font-family:inherit;padding:6px 8px;position:relative;overflow:hidden;transition:transform 0.08s;gap:4px}
  .yg-slot:active{transform:scale(0.97)}
  .yg-slot.free{background:var(--green);color:#fff;border:1.5px solid transparent}
  .yg-slot.free .lbl{font-weight:800;font-size:14px}
  .yg-slot.taken{background:var(--clay);color:#fff;flex-direction:column;gap:1px}
  .yg-slot.taken .name{font-size:12px;font-weight:700;color:#fff;opacity:0.95;overflow:hidden;text-overflow:ellipsis;max-width:100%;white-space:nowrap}
  .yg-slot.mine{background:var(--mine);color:var(--mine-ink);box-shadow:var(--shadow-mine);border:1.5px solid color-mix(in srgb, var(--mine) 70%, black);flex-direction:column;gap:1px}
  .yg-slot.mine .me{font-size:13px;font-weight:800;letter-spacing:-0.01em}
  .yg-slot.mine .with{font-size:11px;opacity:0.88;font-weight:600}
  .yg-slot.past{background:var(--past-bg);color:var(--past-ink);border:1.5px dashed var(--line-2);cursor:not-allowed;font-size:13px}
  .yg-slot.preview{background:var(--clay-tint);color:var(--clay-ink);border:1.5px solid var(--clay);font-weight:800;flex-direction:column;gap:1px;animation:ygpulse 0.9s ease-in-out infinite}
  .yg-slot.preview .lbl{font-size:14px;font-weight:800}
  .yg-slot.preview .cta{font-size:9.5px;font-weight:800;letter-spacing:0.06em;text-transform:uppercase;opacity:0.85}
  @keyframes ygpulse{0%,100%{box-shadow:0 0 0 0 rgba(192,83,43,0.4)}50%{box-shadow:0 0 0 5px rgba(192,83,43,0)}}

  /* CONFIRM BANNER */
  .yg-confirm{position:absolute;left:12px;right:12px;bottom:12px;background:var(--surface);border:2px solid var(--clay);border-radius:14px;padding:11px 13px;display:flex;flex-direction:column;gap:10px;box-shadow:0 10px 28px rgba(0,0,0,0.22);z-index:5;animation:ygup 0.22s ease-out}
  @keyframes ygup{from{transform:translateY(40px);opacity:0}to{transform:translateY(0);opacity:1}}
  .yg-confirm .info{display:flex;align-items:center;gap:10px;min-width:0}
  .yg-confirm .info .av{width:36px;height:36px;border-radius:10px;background:var(--clay);color:#fff;display:flex;align-items:center;justify-content:center;font-weight:800;font-size:15px;flex-shrink:0}
  .yg-confirm .info .txt{flex:1;min-width:0}
  .yg-confirm .info .lbl{font-size:9.5px;color:var(--clay-ink);font-weight:800;letter-spacing:0.08em;text-transform:uppercase;display:block;margin-bottom:1px}
  .yg-confirm .info b{display:block;font-size:15px;font-weight:800;color:var(--ink);line-height:1.25}
  .yg-confirm .info b .with{color:var(--clay)}
  .yg-confirm .row{display:flex;gap:8px}
  .yg-confirm .btn{flex:1;padding:11px;border-radius:10px;border:none;font-family:inherit;font-size:14px;font-weight:800;cursor:pointer;min-height:44px}
  .yg-confirm .btn.cancel{background:transparent;color:var(--ink-2);border:1.5px solid var(--line-2);flex:0 0 auto;padding:11px 16px}
  .yg-confirm .btn.confirm{background:var(--clay);color:#fff;box-shadow:inset 0 -3px 0 rgba(0,0,0,0.18)}

  /* TOAST */
  .yg-toast{position:absolute;left:12px;right:12px;bottom:14px;padding:10px 14px;border-radius:10px;font-size:13px;font-weight:700;text-align:center;z-index:10;animation:ygup 0.2s ease-out}
  .yg-toast.good{background:var(--green);color:#fff}
  .yg-toast.warn{background:var(--clay);color:#fff}
  .yg-toast.info{background:var(--ink);color:var(--bg)}

  /* sheet */
  .yg-sheet{position:absolute;inset:0;background:rgba(31,23,21,0.55);display:flex;align-items:flex-end;z-index:20;animation:ygfade 0.18s ease-out}
  @keyframes ygfade{from{opacity:0}to{opacity:1}}
  .yg-sheet-card{background:var(--surface);width:100%;border-radius:20px 20px 0 0;padding:18px}
  .yg-sheet h3{margin:0 0 4px;font-size:18px;font-weight:800;color:var(--ink)}
  .yg-sheet .sub{font-size:13px;color:var(--ink-2);margin-bottom:14px;line-height:1.4}
  .yg-sheet-btn{width:100%;padding:13px;border-radius:11px;border:none;font-family:inherit;font-size:15px;font-weight:800;cursor:pointer;margin-bottom:8px;min-height:48px}
  .yg-sheet-btn.primary{background:var(--clay);color:#fff}
  .yg-sheet-btn.secondary{background:var(--surface);color:var(--ink);border:1.5px solid var(--line-2)}
`;

function VariantYoung({ initialTheme = 'light' }) {
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
  const meName = s.partnerObj('me').name.split(' ')[0]; // "מיכאל"

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
      <style>{youngStyles}</style>
      <div className="yg-root" data-theme={theme}>

        {/* HERO — single 44px strip: day toggle + cap pips + theme menu */}
        <div className="yg-hero">
          <div className="yg-toggle">
            <button className={s.day === 'today' ? 'on' : ''} onClick={() => s.setDay('today')}>
              היום
            </button>
            <button className={s.day === 'tomorrow' ? 'on' : ''} onClick={() => s.setDay('tomorrow')}>
              מחר
            </button>
          </div>
          <div className="yg-cap" title={`${usedEvenings} מתוך 3 ערבים בשבוע`}>
            <span>ערב {usedEvenings}/3</span>
            <div className="pips">
              {[0,1,2].map(i => <div key={i} className={`pip ${i < usedEvenings ? 'on' : ''}`}></div>)}
            </div>
          </div>
          <button className="yg-menu" onClick={() => setTheme(t => t === 'dark' ? 'light' : 'dark')} title={theme === 'dark' ? 'מצב יום' : 'מצב לילה'}>
            {theme === 'dark' ? '☀' : '☾'}
          </button>
          <button className="yg-menu" title="תפריט">☰</button>
        </div>

        {/* PARTNER ROW */}
        <div className="yg-partners">
          <span className="lbl">עם:</span>
          {recents.map(({ id, available }) => {
            const p = s.partnerObj(id);
            const on = s.partner === id;
            const firstName = p.name.split(' ')[0];
            return (
              <button key={id} className={`yg-chip ${on ? 'on' : ''}`} onClick={() => s.setPartner(id)}>
                {on && <span className="av">{p.initial}</span>}
                {!on && available && <span className="dot"></span>}
                {firstName}
              </button>
            );
          })}
          <button className="yg-chip add" title="הוסף שותפ.ה">+</button>
        </div>

        <div className="yg-courthdr"><div></div><div>מגרש 2</div><div>מגרש 1</div></div>

        <div className="yg-grid">
          {HOURS.map(hour => {
            const busy = busyHours.has(hour);
            return (
              <div key={hour} className={`yg-row ${busy ? 'busy' : ''}`}>
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
                    <button key={court} className={`yg-slot ${cls}`} onClick={() => handleTap(court, hour)}>{inner}</button>
                  );
                })}
              </div>
            );
          })}
        </div>

        {preview && (
          <div className="yg-confirm">
            <div className="info">
              <div className="av">{s.partnerObj(s.partner)?.initial}</div>
              <div className="txt">
                <span className="lbl">אישור הזמנה</span>
                <b>{String(preview.hour).padStart(2,'0')}:00 · מגרש {preview.court} <span className="with">עם {s.partnerObj(s.partner)?.short}</span></b>
              </div>
            </div>
            <div className="row">
              <button className="btn cancel" onClick={() => setPreview(null)}>בטל</button>
              <button className="btn confirm" onClick={confirmBooking}>אשר הזמנה</button>
            </div>
          </div>
        )}

        {sheet && (
          <div className="yg-sheet" onClick={() => setSheet(null)}>
            <div className="yg-sheet-card" onClick={e => e.stopPropagation()}>
              <h3>{sheet.kind === 'cancel' ? 'לבטל את ההזמנה?' : 'המשבצת תפוסה'}</h3>
              <p className="sub">{sheet.hour}:00 במגרש {sheet.court}{sheet.kind === 'cancel' ? '. ביטול אפשרי עד 3 שעות לפני.' : '.'}</p>
              {sheet.kind === 'cancel' && (
                <button className="yg-sheet-btn primary" onClick={() => { s.book(sheet.court, sheet.hour); setSheet(null); }}>כן, בטל הזמנה</button>
              )}
              <button className="yg-sheet-btn secondary" onClick={() => setSheet(null)}>סגור</button>
            </div>
          </div>
        )}

        {s.toast && <div className={`yg-toast ${s.toast.kind}`}>{s.toast.msg}</div>}
      </div>
    </>
  );
}

window.VariantYoung = VariantYoung;

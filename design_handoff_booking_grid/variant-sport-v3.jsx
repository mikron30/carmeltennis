// VARIANT B v3 — Sport / clay
// Changes from v2:
// • Header collapsed: hero compressed from ~150px to ~64px (just day + next-up + day toggle)
// • Removed redundant "menu + name" row (name is now an avatar pill bottom-right)
// • Dark mode support via CSS variables and a [data-theme] attr
// • Date moved into the inline next-up line, so no separate row
// • Weather is now a tiny inline indicator next to day toggle (28°⚠) instead of stacked

const sport3Styles = `
  .s3-root{
    --bg:#fff8f3; --surface:#ffffff; --ink:#1f1715; --ink-2:#7a5447;
    --line:#f0e3d4; --line-2:#e9d8c8;
    --clay:#c0532b; --clay-d:#a8431f; --clay-tint:#fbeadb; --clay-ink:#a8431f;
    --green:#1f6f4a; --green-tint:#e2f1e9;
    --past-bg:#f7efe7; --past-ink:#c8b8ac;
    --warn:#ffd6a8;
    --shadow-mine: inset 0 -3px 0 rgba(0,0,0,0.18);

    width:380px;height:820px;background:var(--bg);color:var(--ink);
    font-family:"Heebo",system-ui,sans-serif;direction:rtl;
    display:flex;flex-direction:column;border:1px solid var(--line-2);
    border-radius:28px;overflow:hidden;position:relative;
  }
  .s3-root[data-theme="dark"]{
    --bg:#0e1413; --surface:#161e1c; --ink:#f1ebe4; --ink-2:#9a8a7e;
    --line:#22302c; --line-2:#1a2422;
    --clay:#e06a3e; --clay-d:#c0532b; --clay-tint:#2a1a13; --clay-ink:#f5a884;
    --green:#3aa674; --green-tint:#0f2a1f;
    --past-bg:#141a19; --past-ink:#3a4744;
    --warn:#ffb877;
    --shadow-mine: inset 0 -3px 0 rgba(0,0,0,0.35);
  }

  /* ── compact hero (single tight strip, ~64px) ── */
  .s3-hero{padding:10px 16px 11px;background:linear-gradient(180deg,var(--clay) 0%,var(--clay-d) 100%);color:#fff;position:relative;overflow:hidden}
  .s3-hero::after{content:"";position:absolute;inset:0;background:repeating-linear-gradient(0deg,rgba(255,255,255,0) 0,rgba(255,255,255,0) 22px,rgba(255,255,255,0.06) 22px,rgba(255,255,255,0.06) 23px);pointer-events:none}
  .s3-hero-row{display:flex;align-items:center;justify-content:space-between;gap:10px;position:relative;z-index:1}
  .s3-hero-left{display:flex;align-items:baseline;gap:8px;min-width:0;flex:1}
  .s3-day{font-weight:800;font-size:22px;letter-spacing:-0.02em;line-height:1;flex-shrink:0}
  .s3-nextup{font-size:11px;opacity:0.92;font-weight:500;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;min-width:0}
  .s3-nextup b{font-weight:800}
  .s3-hero-right{display:flex;align-items:center;gap:6px;flex-shrink:0}
  .s3-theme-btn{width:26px;height:26px;border-radius:50%;background:rgba(0,0,0,0.18);border:none;color:#fff;font-size:13px;cursor:pointer;display:flex;align-items:center;justify-content:center;font-family:inherit}
  .s3-theme-btn:hover{background:rgba(0,0,0,0.28)}
  .s3-toggle{background:rgba(0,0,0,0.22);border-radius:7px;padding:2px;display:flex;gap:1px}
  .s3-toggle button{border:none;background:transparent;color:#fff;padding:5px 9px;font-size:11px;font-weight:700;border-radius:5px;cursor:pointer;font-family:inherit;display:flex;align-items:center;gap:4px;line-height:1}
  .s3-toggle button.on{background:#fff;color:var(--clay-d)}
  .s3-toggle .wx{font-size:9.5px;font-weight:600;opacity:0.8;font-variant-numeric:tabular-nums}
  .s3-toggle .wx.warn{color:var(--warn)}
  .s3-toggle button.on .wx.warn{color:var(--clay)}

  /* ── partner + cap merged into ONE row ── */
  .s3-bar{padding:8px 16px;background:var(--surface);border-bottom:1px solid var(--line);display:flex;align-items:center;gap:10px}
  .s3-bar .av{width:28px;height:28px;border-radius:8px;background:var(--clay-tint);color:var(--clay-ink);display:flex;align-items:center;justify-content:center;font-weight:800;font-size:12px;flex-shrink:0}
  .s3-bar .who{flex:1;min-width:0;display:flex;align-items:baseline;gap:6px}
  .s3-bar .who b{font-weight:700;font-size:13px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
  .s3-bar .cap{font-size:10.5px;color:var(--ink-2);white-space:nowrap;font-weight:600}
  .s3-bar .cap b{color:var(--ink)}
  .s3-bar .pips{display:flex;gap:2px;flex-shrink:0}
  .s3-bar .pip{width:6px;height:6px;border-radius:50%;background:var(--line)}
  .s3-bar .pip.on{background:var(--clay)}
  .s3-bar .actions{display:flex;gap:3px;flex-shrink:0}
  .s3-bar .ico-btn{width:28px;height:28px;border-radius:7px;background:var(--clay-tint);border:none;color:var(--clay-ink);font-weight:700;cursor:pointer;font-family:inherit;display:flex;align-items:center;justify-content:center;font-size:13px}
  .s3-bar .ico-btn:hover{filter:brightness(0.96)}

  .s3-recents{display:flex;gap:5px;padding:7px 16px;overflow-x:auto;scrollbar-width:none;background:var(--surface);border-bottom:1px solid var(--line)}
  .s3-recents::-webkit-scrollbar{display:none}
  .s3-chip{padding:4px 10px;border-radius:5px;background:var(--clay-tint);border:none;font-size:11px;color:var(--clay-ink);font-weight:600;white-space:nowrap;cursor:pointer;font-family:inherit;display:inline-flex;align-items:center;gap:4px}
  .s3-chip.on{background:var(--ink);color:var(--bg)}
  .s3-chip .dot{width:5px;height:5px;border-radius:50%;background:var(--green);flex-shrink:0}

  .s3-courthdr{display:grid;grid-template-columns:36px 1fr 1fr;padding:8px 16px 4px;font-size:10px;font-weight:800;color:var(--ink);text-transform:uppercase;letter-spacing:0.06em;background:var(--bg)}
  .s3-courthdr > *{text-align:center}
  .s3-grid{flex:1;overflow-y:auto;padding:0 16px 12px;position:relative}
  .s3-row{display:grid;grid-template-columns:36px 1fr 1fr;gap:5px;margin-bottom:4px;align-items:stretch;position:relative}
  .s3-row.busy::before{content:"";position:absolute;inset:0;background:linear-gradient(90deg,rgba(192,83,43,0) 0%,rgba(192,83,43,0.05) 50%,rgba(192,83,43,0.10) 100%);border-radius:8px;pointer-events:none;z-index:0}
  .s3-root[data-theme="dark"] .s3-row.busy::before{background:linear-gradient(90deg,rgba(224,106,62,0) 0%,rgba(224,106,62,0.06) 50%,rgba(224,106,62,0.13) 100%)}
  .s3-row .h{font-size:12px;color:var(--ink-2);display:flex;align-items:center;justify-content:center;font-weight:700;font-variant-numeric:tabular-nums;position:relative;z-index:1}
  .s3-row .h .flame{font-size:7px;color:var(--clay);margin-inline-start:2px}
  .s3-slot{min-height:38px;border-radius:7px;display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:600;line-height:1.2;text-align:center;cursor:pointer;border:none;font-family:inherit;padding:6px 8px;position:relative;overflow:hidden;z-index:1;transition:transform 0.08s}
  .s3-slot:active{transform:scale(0.97)}
  .s3-slot.free{background:var(--green);color:#fff}
  .s3-slot.free::before{content:"";position:absolute;inset:0;background:repeating-linear-gradient(45deg,rgba(255,255,255,0) 0,rgba(255,255,255,0) 6px,rgba(255,255,255,0.07) 6px,rgba(255,255,255,0.07) 7px);pointer-events:none}
  .s3-slot.taken{background:var(--surface);color:var(--ink-2);border:1.5px solid var(--line);flex-direction:column;gap:1px}
  .s3-slot.taken .wait{font-size:9px;color:var(--clay);font-weight:700;display:none}
  .s3-slot.taken:hover .wait{display:block}
  .s3-slot.mine{background:var(--clay);color:#fff;box-shadow:var(--shadow-mine)}
  .s3-slot.mine::after{content:"·שלי";font-size:9px;opacity:0.85;margin-inline-start:4px;font-weight:800}
  .s3-slot.mine.locked::after{content:"·נעול";opacity:0.95}
  .s3-slot.past{background:var(--past-bg);color:var(--past-ink);border:1.5px solid var(--line);cursor:not-allowed}
  .s3-slot.preview{background:var(--clay-tint);color:var(--clay-ink);border:2px dashed var(--clay);animation:s3pulse 1s ease-in-out infinite}
  .s3-slot.preview::after{content:"·אישור?";font-weight:800;margin-inline-start:4px}
  @keyframes s3pulse{0%,100%{box-shadow:0 0 0 0 rgba(192,83,43,0.4)}50%{box-shadow:0 0 0 6px rgba(192,83,43,0)}}
  .s3-slot.pending{background:var(--green);color:#fff;opacity:0.65;cursor:wait}
  .s3-slot.pending::before{content:"";position:absolute;inset:0;background:linear-gradient(90deg,transparent 0%,rgba(255,255,255,0.25) 50%,transparent 100%);animation:s3shimmer 1.2s infinite;pointer-events:none}
  @keyframes s3shimmer{from{transform:translateX(100%)}to{transform:translateX(-100%)}}
  .s3-slot.failed{animation:s3shake 0.4s ease-out}
  @keyframes s3shake{0%,100%{transform:translateX(0)}20%{transform:translateX(-4px)}40%{transform:translateX(4px)}60%{transform:translateX(-3px)}80%{transform:translateX(3px)}}
  .s3-now{grid-column:1/-1;display:flex;align-items:center;gap:8px;font-size:9.5px;color:var(--clay);font-weight:800;letter-spacing:0.06em;margin:3px 0;text-transform:uppercase;position:relative;z-index:2}
  .s3-now::before,.s3-now::after{content:"";flex:1;height:2px;background:var(--clay);opacity:0.5}

  .s3-toast{position:absolute;left:16px;right:16px;bottom:14px;padding:10px 14px;border-radius:10px;font-size:12px;font-weight:700;text-align:center;z-index:10;animation:s3slide 0.2s ease-out}
  @keyframes s3slide{from{transform:translateY(8px);opacity:0}to{transform:translateY(0);opacity:1}}
  .s3-toast.good{background:var(--green);color:#fff}
  .s3-toast.info{background:var(--ink);color:var(--bg)}
  .s3-toast.warn{background:var(--clay);color:#fff}

  .s3-sheet{position:absolute;inset:0;background:rgba(0,0,0,0.5);backdrop-filter:blur(2px);display:flex;align-items:flex-end;z-index:20;animation:s3fade 0.18s ease-out}
  @keyframes s3fade{from{opacity:0}to{opacity:1}}
  .s3-sheet-card{background:var(--surface);width:100%;border-radius:20px 20px 0 0;padding:18px 20px 22px;animation:s3up 0.22s ease-out}
  @keyframes s3up{from{transform:translateY(40px)}to{transform:translateY(0)}}
  .s3-sheet h3{margin:0 0 4px;font-size:18px;font-weight:800;color:var(--ink)}
  .s3-sheet .sub{font-size:12px;color:var(--ink-2);margin-bottom:14px}
  .s3-sheet-opt{display:flex;align-items:center;gap:10px;padding:10px 0;border-top:1px solid var(--line);cursor:pointer}
  .s3-sheet-opt:first-of-type{border-top:none}
  .s3-sheet-opt .ic{width:32px;height:32px;border-radius:10px;background:var(--clay-tint);color:var(--clay-ink);display:flex;align-items:center;justify-content:center;font-size:14px;font-weight:800;flex-shrink:0}
  .s3-sheet-opt .lbl{flex:1}
  .s3-sheet-opt .lbl b{display:block;font-size:13px;font-weight:700;color:var(--ink)}
  .s3-sheet-opt .lbl small{font-size:11px;color:var(--ink-2)}
  .s3-sheet-opt .chev{color:var(--ink-2);opacity:0.5}
`;

function VariantSportV3({ initialTheme = 'light' }) {
  const s = useBookingState();
  const [theme, setTheme] = React.useState(initialTheme);
  const [preview, setPreview] = React.useState(null);
  const [pending, setPending] = React.useState(null);
  const [failed, setFailed] = React.useState(null);
  const [sheet, setSheet]   = React.useState(null);

  const recents = [
    { id:'noa',   available:true },
    { id:'dani',  available:false },
    { id:'yoav',  available:true },
    { id:'rotem', available:true },
    { id:'maya',  available:false },
    { id:'tom',   available:true },
  ];

  const usedEvenings = (() => {
    let n = 0;
    for (const day of ['today','tomorrow']) {
      for (const c of [1,2]) {
        for (const h of [18,19,20]) {
          const slot = s.bookings[day]?.[c]?.[h];
          if (slot && (slot.a==='me'||slot.b==='me')) n++;
        }
      }
    }
    return Math.min(n, 3);
  })();

  const busyHours = new Set([13, 18, 19]);
  const wx = {
    today:    { temp:28, warn:true },
    tomorrow: { temp:24, warn:false },
  };
  const dayLabel = s.day === 'today' ? 'היום' : 'מחר';
  const dateStr  = s.day === 'today' ? '27.4' : '28.4';

  const myNext = (() => {
    for (const h of s.HOURS) {
      for (const c of [1,2]) {
        const slot = s.bookings[s.day]?.[c]?.[h];
        if (slot && (slot.a==='me'||slot.b==='me') && !s.isPast(h)) {
          const partner = s.partnerObj(slot.a==='me'?slot.b:slot.a);
          return { hour:h, court:c, partner };
        }
      }
    }
    return null;
  })();

  const isLocked = (hour) => {
    if (s.day !== 'today') return false;
    return hour - s.NOW_HOUR <= 3 && hour - s.NOW_HOUR > 0;
  };

  const handleSlotTap = (court, hour) => {
    const slot = s.slotAt(court, hour);
    const past = s.isPast(hour);
    if (past) return;
    if (slot && s.isMine(slot)) {
      if (isLocked(hour)) { s.showToast('לא ניתן לבטל פחות מ-3 שעות לפני', 'warn'); return; }
      setSheet({ kind:'cancel', court, hour, slot });
      return;
    }
    if (slot) { setSheet({ kind:'waitlist', court, hour, slot }); return; }
    const key = `${court}-${hour}`;
    if (preview && preview.key === key) {
      setPreview(null); setPending(key);
      setTimeout(() => {
        if (Math.random() < 0.08) {
          setPending(null); setFailed(key);
          s.showToast('נכשל — נסה שוב', 'warn');
          setTimeout(() => setFailed(null), 500);
        } else { setPending(null); s.book(court, hour); }
      }, 700);
      return;
    }
    setPreview({ key, court, hour });
    setTimeout(() => setPreview(p => (p && p.key === key ? null : p)), 3500);
  };

  const sheetClose = () => setSheet(null);
  const sheetCancel = () => {
    if (sheet?.kind === 'cancel') s.book(sheet.court, sheet.hour);
    else if (sheet?.kind === 'waitlist') s.showToast('נוספת לרשימת המתנה', 'good');
    sheetClose();
  };

  return (
    <>
      <style>{sport3Styles}</style>
      <div className="s3-root" data-theme={theme}>

        <div className="s3-hero">
          <div className="s3-hero-row">
            <div className="s3-hero-left">
              <span className="s3-day">{dayLabel}</span>
              <span className="s3-nextup">
                {myNext
                  ? <>· <b>{String(myNext.hour).padStart(2,'0')}:00</b> עם <b>{myNext.partner.short}</b> · מגרש {myNext.court}</>
                  : <>· {dateStr} · אין הזמנה</>}
              </span>
            </div>
            <div className="s3-hero-right">
              <button
                className="s3-theme-btn"
                title={theme==='dark'?'מצב יום':'מצב לילה'}
                onClick={()=>setTheme(t => t==='dark'?'light':'dark')}
              >{theme==='dark'?'☀':'☾'}</button>
              <div className="s3-toggle">
                <button className={s.day==='today'?'on':''} onClick={()=>s.setDay('today')}>
                  <span>היום</span>
                  <span className={`wx ${wx.today.warn?'warn':''}`}>{wx.today.temp}°</span>
                </button>
                <button className={s.day==='tomorrow'?'on':''} onClick={()=>s.setDay('tomorrow')}>
                  <span>מחר</span>
                  <span className={`wx ${wx.tomorrow.warn?'warn':''}`}>{wx.tomorrow.temp}°</span>
                </button>
              </div>
            </div>
          </div>
        </div>

        <div className="s3-bar">
          <div className="av">{s.partnerObj(s.partner)?.initial}</div>
          <div className="who">
            <b>{s.partnerObj(s.partner)?.name}</b>
          </div>
          <span className="cap">ערב <b>{usedEvenings}</b>/3</span>
          <div className="pips">
            {[0,1,2].map(i => <div key={i} className={`pip ${i<usedEvenings?'on':''}`}></div>)}
          </div>
          <div className="actions">
            <button className="ico-btn" title="כמו בשבוע שעבר" onClick={()=>s.showToast('שוחזר: נועה · ראשון 18:00','info')}>↻</button>
            <button className="ico-btn" title="החלף שותפ.ה" onClick={()=>{
              const idx = s.PARTNERS.findIndex(p=>p.id===s.partner);
              const next = s.PARTNERS[(idx+1) % s.PARTNERS.length];
              s.setPartner(next.id);
            }}>↔</button>
          </div>
        </div>

        <div className="s3-recents">
          {recents.map(({id,available})=>{
            const p = s.partnerObj(id);
            return (
              <button key={id} className={`s3-chip ${s.partner===id?'on':''}`} onClick={()=>s.setPartner(id)}>
                {available && <span className="dot"></span>}
                {p.short}
              </button>
            );
          })}
        </div>

        <div className="s3-courthdr"><div></div><div>מגרש 2</div><div>מגרש 1</div></div>

        <div className="s3-grid">
          {s.HOURS.map(h => {
            const showNow = s.day==='today' && h===s.NOW_HOUR+1;
            const busy = busyHours.has(h);
            return (
              <React.Fragment key={h}>
                {showNow && <div className="s3-now">— עכשיו 13:42 —</div>}
                <div className={`s3-row ${busy?'busy':''}`}>
                  <div className="h">
                    {String(h).padStart(2,'0')}
                    {busy && <span className="flame">●</span>}
                  </div>
                  {[2,1].map(court=>{
                    const slot = s.slotAt(court,h);
                    const past = s.isPast(h);
                    const mine = s.isMine(slot);
                    const key = `${court}-${h}`;
                    const isPreview = preview?.key === key;
                    const isPending = pending === key;
                    const isFailed  = failed === key;
                    const locked = mine && isLocked(h);
                    let cls='free', label=<b>פנוי</b>;
                    if (slot) {
                      cls = mine?(locked?'mine locked':'mine'):'taken';
                      const a = s.partnerObj(slot.a)?.short;
                      const b = s.partnerObj(slot.b)?.short;
                      if (mine) label = slot.a==='me' ? b : a;
                      else label = (<><div>{a} · {b}</div><div className="wait">+ הוסף להמתנה</div></>);
                    } else if (past) { cls='past'; label='—'; }
                    if (isPreview) cls='preview';
                    if (isPending) cls='pending';
                    if (isFailed)  cls += ' failed';
                    return (
                      <button key={court} className={`s3-slot ${cls}`} onClick={()=>handleSlotTap(court,h)}>
                        {label}
                      </button>
                    );
                  })}
                </div>
              </React.Fragment>
            );
          })}
        </div>

        {s.toast && <div className={`s3-toast ${s.toast.kind}`}>{s.toast.msg}</div>}

        {sheet && (
          <div className="s3-sheet" onClick={sheetClose}>
            <div className="s3-sheet-card" onClick={e=>e.stopPropagation()}>
              {sheet.kind==='cancel' ? (
                <>
                  <h3>לבטל את ההזמנה?</h3>
                  <div className="sub">{String(sheet.hour).padStart(2,'0')}:00 · מגרש {sheet.court}</div>
                  <div className="s3-sheet-opt" onClick={sheetCancel}>
                    <div className="ic">✕</div>
                    <div className="lbl"><b>בטל הזמנה</b><small>תישלח התראה לשותפ.ה</small></div>
                    <div className="chev">›</div>
                  </div>
                  <div className="s3-sheet-opt" onClick={()=>{sheetClose();s.showToast('שותפ.ה הוחלפ.ה — בקרוב','info');}}>
                    <div className="ic">↔</div>
                    <div className="lbl"><b>החלף שותפ.ה במקום</b><small>שמור על המשבצת</small></div>
                    <div className="chev">›</div>
                  </div>
                </>
              ) : (
                <>
                  <h3>המשבצת תפוסה</h3>
                  <div className="sub">{s.partnerObj(sheet.slot.a)?.short} · {s.partnerObj(sheet.slot.b)?.short}</div>
                  <div className="s3-sheet-opt" onClick={sheetCancel}>
                    <div className="ic">⏱</div>
                    <div className="lbl"><b>הוסף לרשימת המתנה</b><small>נודיע אם מתפנה</small></div>
                    <div className="chev">›</div>
                  </div>
                  <div className="s3-sheet-opt" onClick={()=>{sheetClose();s.showToast('הצעה נשלחה לשותפ.ה','good');}}>
                    <div className="ic">✦</div>
                    <div className="lbl"><b>שלח הצעה לשעה אחרת</b><small>הצע 17:00 או 20:00 לשותפ.ה</small></div>
                    <div className="chev">›</div>
                  </div>
                </>
              )}
            </div>
          </div>
        )}
      </div>
    </>
  );
}

window.VariantSportV3 = VariantSportV3;

// UX upgrade mockups — small focused tiles, each isolating ONE UX move
// from the brainstorm so reviewers can evaluate them individually.
// Uses CSS variables so all tiles support dark mode.

const muxStyles = `
  .mux-tile{
    --bg:#fff8f3; --surface:#ffffff; --ink:#1f1715; --ink-2:#7a5447;
    --line:#f0e3d4; --line-2:#e9d8c8;
    --clay:#c0532b; --clay-d:#a8431f; --clay-tint:#fbeadb; --clay-ink:#a8431f;
    --green:#1f6f4a; --green-tint:#e2f1e9;
    --past-bg:#f7efe7; --past-ink:#c8b8ac;

    width:320px;height:280px;background:var(--bg);color:var(--ink);
    font-family:"Heebo",system-ui,sans-serif;direction:rtl;
    border:1px solid var(--line-2);border-radius:18px;overflow:hidden;
    display:flex;flex-direction:column;position:relative;
  }
  .mux-tile[data-theme="dark"]{
    --bg:#0e1413; --surface:#161e1c; --ink:#f1ebe4; --ink-2:#9a8a7e;
    --line:#22302c; --line-2:#1a2422;
    --clay:#e06a3e; --clay-d:#c0532b; --clay-tint:#2a1a13; --clay-ink:#f5a884;
    --green:#3aa674; --green-tint:#0f2a1f;
    --past-bg:#141a19; --past-ink:#3a4744;
  }
  .mux-cap{padding:10px 14px 6px;border-bottom:1px solid var(--line)}
  .mux-cap small{font-size:9px;letter-spacing:0.12em;text-transform:uppercase;color:var(--clay-ink);font-weight:800}
  .mux-cap b{display:block;font-size:13px;font-weight:700;margin-top:2px}
  .mux-cap p{margin:2px 0 0;font-size:10.5px;color:var(--ink-2);line-height:1.35}
  .mux-body{flex:1;padding:12px 14px;display:flex;flex-direction:column;gap:8px;overflow:hidden}

  /* shared slot styles */
  .mux-slot{height:38px;border-radius:7px;display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:700;border:none;font-family:inherit;padding:0 10px;position:relative;overflow:hidden}
  .mux-slot.free{background:var(--green);color:#fff}
  .mux-slot.free::before{content:"";position:absolute;inset:0;background:repeating-linear-gradient(45deg,rgba(255,255,255,0) 0,rgba(255,255,255,0) 6px,rgba(255,255,255,0.07) 6px,rgba(255,255,255,0.07) 7px)}
  .mux-slot.preview{background:var(--clay-tint);color:var(--clay-ink);border:2px dashed var(--clay)}
  .mux-slot.pending{background:var(--green);color:#fff;opacity:0.7}
  .mux-slot.pending::after{content:"";position:absolute;inset:0;background:linear-gradient(90deg,transparent 0%,rgba(255,255,255,0.3) 50%,transparent 100%);animation:muxshim 1.2s infinite}
  @keyframes muxshim{from{transform:translateX(100%)}to{transform:translateX(-100%)}}
  .mux-slot.mine{background:var(--clay);color:#fff;box-shadow:inset 0 -3px 0 rgba(0,0,0,0.18)}
  .mux-slot.taken{background:var(--surface);color:var(--ink-2);border:1.5px solid var(--line)}
  .mux-slot.failed{background:var(--clay);color:#fff;animation:muxshake 0.5s}
  @keyframes muxshake{0%,100%{transform:translateX(0)}25%{transform:translateX(-4px)}75%{transform:translateX(4px)}}

  .mux-step{display:flex;align-items:center;gap:8px;font-size:10.5px;color:var(--ink-2)}
  .mux-step .n{width:18px;height:18px;border-radius:50%;background:var(--clay-tint);color:var(--clay-ink);font-weight:800;font-size:10px;display:flex;align-items:center;justify-content:center;flex-shrink:0}
  .mux-step b{color:var(--ink);font-weight:700}
  .mux-arrow{text-align:center;color:var(--ink-2);font-size:14px;line-height:1}

  /* cap counter */
  .mux-cap-row{display:flex;align-items:center;gap:8px;padding:8px 10px;background:var(--surface);border:1px solid var(--line);border-radius:10px}
  .mux-cap-row .lbl{font-size:11px;color:var(--ink-2);font-weight:600;flex-shrink:0}
  .mux-cap-row .lbl b{color:var(--ink)}
  .mux-cap-row .track{flex:1;height:5px;background:var(--line);border-radius:99px;overflow:hidden;position:relative}
  .mux-cap-row .fill{position:absolute;inset-inline-end:0;top:0;bottom:0;background:linear-gradient(90deg,var(--clay),var(--green));border-radius:99px}
  .mux-cap-row .pips{display:flex;gap:3px;flex-shrink:0}
  .mux-cap-row .pip{width:7px;height:7px;border-radius:50%;background:var(--line)}
  .mux-cap-row .pip.on{background:var(--clay)}

  /* busy heat row */
  .mux-row{display:grid;grid-template-columns:30px 1fr 1fr;gap:5px;align-items:stretch;position:relative;padding:2px 0}
  .mux-row.busy::before{content:"";position:absolute;inset:0;background:linear-gradient(90deg,rgba(192,83,43,0) 0%,rgba(192,83,43,0.05) 50%,rgba(192,83,43,0.12) 100%);border-radius:8px;pointer-events:none}
  .mux-tile[data-theme="dark"] .mux-row.busy::before{background:linear-gradient(90deg,rgba(224,106,62,0) 0%,rgba(224,106,62,0.07) 50%,rgba(224,106,62,0.16) 100%)}
  .mux-row .h{font-size:11px;color:var(--ink-2);display:flex;align-items:center;justify-content:center;font-weight:700;font-variant-numeric:tabular-nums;position:relative;z-index:1}
  .mux-row .h .flame{font-size:7px;color:var(--clay);margin-inline-start:2px}

  /* weather toggle */
  .mux-wx-toggle{background:var(--clay-d);border-radius:8px;padding:3px;display:flex;gap:2px}
  .mux-wx-toggle button{border:none;background:transparent;color:#fff;padding:6px 10px;font-size:11px;font-weight:700;border-radius:6px;font-family:inherit;display:flex;flex-direction:column;align-items:center;gap:1px;line-height:1;cursor:pointer}
  .mux-wx-toggle button.on{background:#fff;color:var(--clay-d)}
  .mux-wx-toggle .wx{font-size:9px;font-weight:600;opacity:0.85}
  .mux-wx-toggle .wx.warn{color:#ffd6a8}
  .mux-wx-toggle button.on .wx.warn{color:var(--clay)}

  /* recents */
  .mux-recents{display:flex;gap:5px;flex-wrap:wrap}
  .mux-chip{padding:5px 10px;border-radius:6px;background:var(--clay-tint);border:none;font-size:11px;color:var(--clay-ink);font-weight:600;display:inline-flex;align-items:center;gap:5px;font-family:inherit}
  .mux-chip.on{background:var(--ink);color:var(--bg)}
  .mux-chip .dot{width:5px;height:5px;border-radius:50%;background:var(--green)}

  /* lock */
  .mux-lock-icon{display:inline-flex;align-items:center;justify-content:center;width:14px;height:14px;border-radius:3px;background:rgba(255,255,255,0.25);font-size:8px;margin-inline-start:4px}

  /* sheet preview */
  .mux-sheet{background:var(--surface);border:1px solid var(--line);border-radius:12px;padding:12px;display:flex;flex-direction:column;gap:8px}
  .mux-sheet h4{margin:0;font-size:13px;font-weight:800}
  .mux-sheet .sub{font-size:11px;color:var(--ink-2)}
  .mux-sheet-opt{display:flex;align-items:center;gap:8px;padding:6px 0;border-top:1px solid var(--line)}
  .mux-sheet-opt:first-of-type{border-top:none;padding-top:0}
  .mux-sheet-opt .ic{width:24px;height:24px;border-radius:7px;background:var(--clay-tint);color:var(--clay-ink);display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:800;flex-shrink:0}
  .mux-sheet-opt .lbl{flex:1;min-width:0}
  .mux-sheet-opt .lbl b{display:block;font-size:11px;font-weight:700}
  .mux-sheet-opt .lbl small{font-size:10px;color:var(--ink-2)}

  /* hero strip */
  .mux-hero{padding:8px 12px;background:linear-gradient(180deg,var(--clay) 0%,var(--clay-d) 100%);color:#fff;border-radius:10px;display:flex;align-items:baseline;gap:6px;font-size:11px}
  .mux-hero b{font-size:18px;font-weight:800;letter-spacing:-0.02em}
  .mux-hero span{opacity:0.92}

  /* recurring */
  .mux-recur{padding:10px;background:var(--surface);border:1px solid var(--line);border-radius:10px;display:flex;align-items:center;gap:10px}
  .mux-recur .ico{width:32px;height:32px;border-radius:8px;background:var(--clay-tint);color:var(--clay-ink);display:flex;align-items:center;justify-content:center;font-size:14px;font-weight:800;flex-shrink:0}
  .mux-recur .txt{flex:1;min-width:0}
  .mux-recur .txt b{display:block;font-size:12px;font-weight:700}
  .mux-recur .txt small{font-size:10px;color:var(--ink-2)}
  .mux-recur .toggle{width:32px;height:18px;border-radius:99px;background:var(--clay);position:relative;flex-shrink:0}
  .mux-recur .toggle::after{content:"";position:absolute;width:14px;height:14px;border-radius:50%;background:#fff;top:2px;right:2px}

  /* findslot bar */
  .mux-find{padding:8px 10px;background:var(--surface);border:1.5px solid var(--clay);border-radius:10px;display:flex;align-items:center;gap:8px;font-size:11px}
  .mux-find .icon{color:var(--clay);font-weight:800}
  .mux-find .q{flex:1;color:var(--ink);font-weight:600}
  .mux-find .q em{font-style:normal;color:var(--ink-2);font-weight:500}

  /* invite card */
  .mux-invite{padding:10px;background:var(--surface);border:1px solid var(--line);border-radius:10px}
  .mux-invite .top{display:flex;align-items:center;gap:8px}
  .mux-invite .av{width:26px;height:26px;border-radius:50%;background:var(--clay-tint);color:var(--clay-ink);display:flex;align-items:center;justify-content:center;font-weight:800;font-size:11px}
  .mux-invite .who{flex:1;font-size:11px}
  .mux-invite .who b{font-weight:700}
  .mux-invite .who small{display:block;color:var(--ink-2);font-size:10px}
  .mux-invite .badge{font-size:9px;padding:2px 6px;border-radius:99px;background:var(--clay-tint);color:var(--clay-ink);font-weight:800;text-transform:uppercase;letter-spacing:0.06em}
  .mux-invite .actions{display:flex;gap:5px;margin-top:8px}
  .mux-invite .btn{flex:1;padding:6px;border-radius:7px;font-size:11px;font-weight:700;border:none;font-family:inherit;cursor:pointer}
  .mux-invite .btn.primary{background:var(--green);color:#fff}
  .mux-invite .btn.ghost{background:transparent;color:var(--ink-2);border:1px solid var(--line)}

  /* checklist */
  .mux-check{padding:10px;background:var(--surface);border:1px solid var(--line);border-radius:10px;font-size:11px}
  .mux-check .top{display:flex;align-items:center;gap:6px;margin-bottom:6px}
  .mux-check .top .lbl{font-size:9px;letter-spacing:0.1em;color:var(--clay-ink);font-weight:800;text-transform:uppercase}
  .mux-check ul{margin:0;padding:0;list-style:none;display:flex;flex-direction:column;gap:4px}
  .mux-check li{display:flex;align-items:center;gap:6px;color:var(--ink)}
  .mux-check li::before{content:"✓";color:var(--green);font-weight:800;font-size:11px;width:14px}
  .mux-check li.todo::before{content:"○";color:var(--ink-2)}

  /* rating */
  .mux-rate{padding:10px;background:var(--surface);border:1px solid var(--line);border-radius:10px;text-align:center}
  .mux-rate .q{font-size:13px;font-weight:700;margin-bottom:8px}
  .mux-rate .stars{display:flex;justify-content:center;gap:6px;font-size:22px;color:var(--clay)}
  .mux-rate .stars .off{color:var(--line-2)}
  .mux-tile[data-theme="dark"] .mux-rate .stars .off{color:#2a3431}

  /* friends online */
  .mux-online{padding:10px;background:var(--surface);border:1px solid var(--line);border-radius:10px;font-size:11px}
  .mux-online .top{display:flex;align-items:center;gap:6px;margin-bottom:6px}
  .mux-online .pulse{width:7px;height:7px;border-radius:50%;background:var(--green);box-shadow:0 0 0 0 var(--green);animation:muxpulse 2s infinite}
  @keyframes muxpulse{0%{box-shadow:0 0 0 0 rgba(31,111,74,0.5)}70%{box-shadow:0 0 0 6px rgba(31,111,74,0)}}
  .mux-online .top b{font-size:11px;font-weight:800}
  .mux-online .avs{display:flex;margin-block:4px}
  .mux-online .avs .av{width:24px;height:24px;border-radius:50%;background:var(--clay-tint);color:var(--clay-ink);display:flex;align-items:center;justify-content:center;font-size:10px;font-weight:800;border:2px solid var(--surface);margin-inline-start:-6px}
  .mux-online .avs .av:first-child{margin-inline-start:0}
  .mux-online small{color:var(--ink-2);font-size:10px}
`;

function MuxTile({ kind, title, sub, children, theme='light' }) {
  return (
    <div className="mux-tile" data-theme={theme}>
      <div className="mux-cap">
        <small>{kind}</small>
        <b>{title}</b>
        <p>{sub}</p>
      </div>
      <div className="mux-body">{children}</div>
    </div>
  );
}

function MockConfirmTap({ theme }) {
  return (
    <MuxTile theme={theme} kind="3 · CONFIRM-ON-SECOND-TAP" title="Preview before commit" sub="First tap previews — second tap books. No accidental bookings, no modal.">
      <div className="mux-step"><div className="n">1</div><span><b>tap</b> משבצת ירוקה</span></div>
      <button className="mux-slot free">18:00 · מגרש 1</button>
      <div className="mux-arrow">↓</div>
      <button className="mux-slot preview">18:00 · אישור?</button>
      <div className="mux-step"><div className="n">2</div><span><b>tap שוב</b> תוך 3.5 שניות</span></div>
    </MuxTile>
  );
}

function MockPending({ theme }) {
  return (
    <MuxTile theme={theme} kind="4 · PENDING / FAILURE" title="Visible writing state" sub="Shimmer while saving. Shake + toast on rollback — never silent.">
      <div className="mux-step"><span style={{flex:1}}>שולח לשרת</span></div>
      <button className="mux-slot pending">18:00 · נשמר…</button>
      <div className="mux-step" style={{marginTop:'4px'}}><span style={{flex:1,color:'var(--clay)'}}>נכשל — מתבצע rollback</span></div>
      <button className="mux-slot failed">18:00 · נסה שוב</button>
    </MuxTile>
  );
}

function MockCapCounter({ theme }) {
  return (
    <MuxTile theme={theme} kind="13 · LIVE CAP COUNTER" title="18-20h limit, before you hit it" sub="Always visible — stops the 'why won't this work?' moment after the 3rd booking.">
      <div className="mux-cap-row">
        <span className="lbl">ערב 18-20: <b>1</b>/3 השבוע</span>
        <div className="track"><div className="fill" style={{width:'33%'}}></div></div>
        <div className="pips"><div className="pip on"></div><div className="pip"></div><div className="pip"></div></div>
      </div>
      <div className="mux-cap-row">
        <span className="lbl">ערב 18-20: <b>2</b>/3 השבוע</span>
        <div className="track"><div className="fill" style={{width:'66%'}}></div></div>
        <div className="pips"><div className="pip on"></div><div className="pip on"></div><div className="pip"></div></div>
      </div>
      <div className="mux-cap-row">
        <span className="lbl">ערב 18-20: <b>3</b>/3 השבוע</span>
        <div className="track"><div className="fill" style={{width:'100%'}}></div></div>
        <div className="pips"><div className="pip on"></div><div className="pip on"></div><div className="pip on"></div></div>
      </div>
    </MuxTile>
  );
}

function MockBusyHeat({ theme }) {
  return (
    <MuxTile theme={theme} kind="11 · BUSY-HOUR HEAT" title="See popular hours at a glance" sub="Faint clay shading + ● flame on hours people actually book. No copy needed.">
      <div className="mux-row"><div className="h">12</div><button className="mux-slot taken">דני · יואב</button><button className="mux-slot free">פנוי</button></div>
      <div className="mux-row busy"><div className="h">13<span className="flame">●</span></div><button className="mux-slot taken">רותם · מ.</button><button className="mux-slot taken">תום · יעל</button></div>
      <div className="mux-row"><div className="h">14</div><button className="mux-slot free">פנוי</button><button className="mux-slot free">פנוי</button></div>
      <div className="mux-row busy"><div className="h">18<span className="flame">●</span></div><button className="mux-slot mine">נועה · שלי</button><button className="mux-slot taken">דני · א.</button></div>
      <div className="mux-row busy"><div className="h">19<span className="flame">●</span></div><button className="mux-slot taken">רותם · מ.</button><button className="mux-slot taken">תום · יעל</button></div>
    </MuxTile>
  );
}

function MockWeather({ theme }) {
  return (
    <MuxTile theme={theme} kind="9 · WEATHER STRIP PER DAY" title="Pick a smart day" sub="Live temp baked into the day toggle. Heat warning in amber when >27°.">
      <div style={{display:'flex',justifyContent:'center'}}>
        <div className="mux-wx-toggle">
          <button className="on"><span>היום</span><span className="wx warn">28°</span></button>
          <button><span>מחר</span><span className="wx">24°</span></button>
        </div>
      </div>
      <div style={{marginTop:'4px',fontSize:'10.5px',color:'var(--ink-2)',lineHeight:1.4}}>
        <div>• <b style={{color:'var(--clay)'}}>היום 28°</b> — חום, שקול שעה מאוחרת</div>
        <div>• <b style={{color:'var(--ink)'}}>מחר 24°</b> — תנאים נוחים</div>
      </div>
      <div style={{padding:'6px 8px',background:'var(--clay-tint)',color:'var(--clay-ink)',borderRadius:'7px',fontSize:'10px',fontWeight:700,textAlign:'center'}}>
        💡 מגרש 1 בצל אחה"צ
      </div>
    </MuxTile>
  );
}

function MockRecents({ theme }) {
  return (
    <MuxTile theme={theme} kind="5 + 8 · SMART PARTNER PICKER" title="Recents ranked by frequency × recency" sub="Green dot = available today (no clashing booking).">
      <div className="mux-recents">
        <button className="mux-chip on"><span className="dot"></span>נועה</button>
        <button className="mux-chip">דני</button>
        <button className="mux-chip"><span className="dot"></span>יואב</button>
        <button className="mux-chip"><span className="dot"></span>רותם</button>
        <button className="mux-chip">מאיה</button>
        <button className="mux-chip"><span className="dot"></span>תום</button>
      </div>
      <div style={{fontSize:'10px',color:'var(--ink-2)',lineHeight:1.4}}>
        <div>• מסודר לפי שכיחות × עדכניות</div>
        <div>• <span style={{color:'var(--green)',fontWeight:700}}>●</span> זמין/ה היום — בלי התנגשויות</div>
        <div>• כפתור ↻ "כמו בשבוע שעבר" משחזר בלחיצה</div>
      </div>
    </MuxTile>
  );
}

function MockLock({ theme }) {
  return (
    <MuxTile theme={theme} kind="14 · 3-HOUR CANCEL LOCK" title="Visualized, not hidden" sub="Slots within 3h of start get a lock badge — tap shows reason instead of silent error.">
      <div className="mux-row"><div className="h">14</div><button className="mux-slot mine">נועה · שלי</button></div>
      <div style={{textAlign:'center',fontSize:'9.5px',color:'var(--clay)',fontWeight:800,letterSpacing:'0.06em'}}>— עכשיו 13:42 —</div>
      <div className="mux-row"><div className="h">15</div><button className="mux-slot mine" style={{background:'var(--clay-d)'}}>דני · שלי<span className="mux-lock-icon">🔒</span></button></div>
      <div style={{fontSize:'10px',color:'var(--ink-2)',padding:'6px 8px',background:'var(--clay-tint)',color:'var(--clay-ink)',borderRadius:'7px',fontWeight:600,lineHeight:1.4}}>
        ⓘ נעול: לא ניתן לבטל פחות מ-3 שעות לפני
      </div>
    </MuxTile>
  );
}

function MockWaitlist({ theme }) {
  return (
    <MuxTile theme={theme} kind="15 · WAITLIST" title="Don't lose a full slot" sub="Tap a taken slot → join waitlist or propose another time. Auto-books if it cancels.">
      <div className="mux-sheet">
        <h4>המשבצת תפוסה</h4>
        <div className="sub">18:00 · מגרש 1 · רותם · מאיה</div>
        <div className="mux-sheet-opt">
          <div className="ic">⏱</div>
          <div className="lbl"><b>הוסף לרשימת המתנה</b><small>נודיע אם מתפנה</small></div>
        </div>
        <div className="mux-sheet-opt">
          <div className="ic">✦</div>
          <div className="lbl"><b>הצע לשותפ.ה שעה אחרת</b><small>17:00 או 20:00</small></div>
        </div>
      </div>
    </MuxTile>
  );
}

function MockRecurring({ theme }) {
  return (
    <MuxTile theme={theme} kind="18 · RECURRING BOOKINGS" title="Set once, plays every week" sub="No re-booking the same slot Monday after Monday. Toggle off any time.">
      <div className="mux-recur">
        <div className="ico">📌</div>
        <div className="txt"><b>כל שני 18:00</b><small>עם נועה לוי · מגרש 1</small></div>
        <div className="toggle"></div>
      </div>
      <div className="mux-recur">
        <div className="ico" style={{background:'var(--green-tint)',color:'var(--green)'}}>↻</div>
        <div className="txt"><b>כמו בשבוע שעבר</b><small>שחזור הזמנה אחרונה בלחיצה</small></div>
        <div style={{fontSize:'14px',color:'var(--ink-2)'}}>›</div>
      </div>
      <div style={{fontSize:'10px',color:'var(--ink-2)',lineHeight:1.4,marginTop:'2px'}}>
        ⓘ הזמנה קבועה תיווצר אוטומטית — תוכל לדלג על שבוע ספציפי
      </div>
    </MuxTile>
  );
}

function MockFindSlot({ theme }) {
  return (
    <MuxTile theme={theme} kind="2 · FIND-ME-A-SLOT" title="Stop scanning the grid" sub="Type what you want; matching slots highlight. Faster than visual scanning for power users.">
      <div className="mux-find">
        <span className="icon">⌕</span>
        <span className="q">אחרי 17:00 עם <b style={{color:'var(--clay-ink)'}}>נועה</b></span>
      </div>
      <div className="mux-row"><div className="h">17</div><button className="mux-slot free" style={{outline:'2px solid var(--clay)',outlineOffset:'2px'}}>פנוי</button><button className="mux-slot taken">דני · א.</button></div>
      <div className="mux-row"><div className="h">18</div><button className="mux-slot free" style={{outline:'2px solid var(--clay)',outlineOffset:'2px'}}>פנוי</button><button className="mux-slot taken">רותם · מ.</button></div>
      <div className="mux-row"><div className="h">19</div><button className="mux-slot taken">תום · יעל</button><button className="mux-slot free" style={{outline:'2px solid var(--clay)',outlineOffset:'2px'}}>פנוי</button></div>
    </MuxTile>
  );
}

function MockInvite({ theme }) {
  return (
    <MuxTile theme={theme} kind="7 · INVITE — DON'T PRE-CONFIRM" title="Partner accepts before slot locks" sub="Slot shows pending until partner taps accept — fixes ghost bookings without follow-up.">
      <div className="mux-invite">
        <div className="top">
          <div className="av">מ</div>
          <div className="who"><b>מיכאל</b> מזמין אותך<small>טניס · מחר 18:00 · מגרש 1</small></div>
          <span className="badge">חדש</span>
        </div>
        <div className="actions">
          <button className="btn primary">אשר</button>
          <button className="btn ghost">דחה</button>
        </div>
      </div>
      <div style={{fontSize:'10px',color:'var(--ink-2)',lineHeight:1.4,padding:'0 4px'}}>
        ⓘ עד אז המשבצת מוצגת כ-<b style={{color:'var(--clay)'}}>ממתינ.ה</b> בלוח הזמנים
      </div>
    </MuxTile>
  );
}

function MockChecklist({ theme }) {
  return (
    <MuxTile theme={theme} kind="16 · PRE-GAME CHECKLIST" title="1h before — everything you need" sub="Push notification with court, partner, weather, and a reminder to bring water.">
      <div className="mux-check">
        <div className="top"><span className="lbl">בעוד שעה · 18:00</span></div>
        <ul>
          <li><b>מגרש 1</b> · נועה לוי</li>
          <li>28° · קח מים 💧</li>
          <li>שמש מלאה — כובע מומלץ</li>
          <li className="todo">בדוק חניה (לפעמים מלא)</li>
        </ul>
      </div>
    </MuxTile>
  );
}

function MockRating({ theme }) {
  return (
    <MuxTile theme={theme} kind="17 · POST-GAME RATING" title="2-tap feedback feeds suggestions" sub="Quick rating after every game. Drives partner-suggestion algorithm + finds bad-fit pairings.">
      <div className="mux-rate">
        <div className="q">איך היה המשחק עם נועה?</div>
        <div className="stars">
          <span>★</span><span>★</span><span>★</span><span>★</span><span className="off">★</span>
        </div>
      </div>
      <div className="mux-recents" style={{justifyContent:'center'}}>
        <button className="mux-chip">משחק שווה</button>
        <button className="mux-chip">בא ב-time</button>
        <button className="mux-chip">איחר</button>
      </div>
      <div style={{fontSize:'10px',color:'var(--ink-2)',textAlign:'center'}}>פרטי ובלתי-נראה לשותפ.ה</div>
    </MuxTile>
  );
}

function MockOnline({ theme }) {
  return (
    <MuxTile theme={theme} kind="12 · FRIENDS ONLINE" title="See who's looking right now" sub="Tiny presence indicator — discover spontaneous matches without a 'find a partner' broadcast.">
      <div className="mux-online">
        <div className="top"><span className="pulse"></span><b>3 חברים מחפשים שותף</b></div>
        <div className="avs">
          <div className="av">נ</div>
          <div className="av">י</div>
          <div className="av">ר</div>
        </div>
        <small>נועה · יואב · רותם — נכנסו ב-5 דקות האחרונות</small>
      </div>
      <div className="mux-find" style={{borderColor:'var(--green)',color:'var(--green)'}}>
        <span className="icon" style={{color:'var(--green)'}}>📣</span>
        <span className="q">פרסם: <em>"מחפש שותף 18-19"</em></span>
      </div>
    </MuxTile>
  );
}

function MockNextUp({ theme }) {
  return (
    <MuxTile theme={theme} kind="20 · LIVE NEXT-UP" title="Hero answers the only question" sub="'When am I playing next?' — answered in the header, every visit. No tap required.">
      <div className="mux-hero">
        <span>המגרש שלך ·</span>
        <b>18:00</b>
        <span>בעוד 4 שעות · מגרש 1 · נועה</span>
      </div>
      <div style={{fontSize:'10.5px',color:'var(--ink-2)',lineHeight:1.4}}>
        <div>• מתעדכן לאורך היום</div>
        <div>• אם אין הזמנה: <em style={{fontStyle:'normal',color:'var(--ink)'}}>"אין הזמנה היום — לחץ על משבצת ירוקה"</em></div>
        <div>• אחרי המשחק: עובר ל-<em style={{fontStyle:'normal',color:'var(--ink)'}}>"איך היה?"</em></div>
      </div>
    </MuxTile>
  );
}

function UpgradeMockups({ theme = 'light' }) {
  // Render all 14 tiles in one container; design canvas is the wrapper.
  return null; // tiles registered individually below
}

window.MockConfirmTap = MockConfirmTap;
window.MockPending = MockPending;
window.MockCapCounter = MockCapCounter;
window.MockBusyHeat = MockBusyHeat;
window.MockWeather = MockWeather;
window.MockRecents = MockRecents;
window.MockLock = MockLock;
window.MockWaitlist = MockWaitlist;
window.MockRecurring = MockRecurring;
window.MockFindSlot = MockFindSlot;
window.MockInvite = MockInvite;
window.MockChecklist = MockChecklist;
window.MockRating = MockRating;
window.MockOnline = MockOnline;
window.MockNextUp = MockNextUp;
window.muxStyles = muxStyles;

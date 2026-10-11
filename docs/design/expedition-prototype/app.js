'use strict';

// A local design experiment, not a replacement for the Flutter resolver.
const sectors = {
  mosswood: {name:'Mosswood Verge', min:10, nominal:25, rates:[5,.45,.10], rare:.16, note:'Credits & supplies'},
  blackstone: {name:'Blackstone Hollow', min:25, nominal:45, rates:[4.2,1.6,.20], rare:.20, note:'Alloy & equipment'},
  cinder: {name:'The Cinder Archive', min:40, nominal:60, rates:[3.4,.60,1.30], rare:.24, note:'Intel & old records'},
};
const classes = {
  recon:{name:'Recon',base:[.15,-.05,0,.03],window:[10,30],bonus:[.25,0,0,.05]},
  artificer:{name:'Artificer',base:[0,.10,0,.05],window:[25,75],bonus:[0,.20,0,.06]},
  archivist:{name:'Archivist',base:[-.10,0,.20,0],window:[45,180],bonus:[0,0,.30,.04]},
  vanguard:{name:'Vanguard',base:[.05,.15,0,-.01],window:[60,240],bonus:[.10,.30,0,0]},
};
const gearDefs = {
  optic:{name:'Field Optic',rarity:'Uncommon',bonus:[.10,0,0,.02],flavor:'One cracked lens, still true.'},
  pick:{name:'Hollow Pick',rarity:'Common',bonus:[0,.08,0,0],flavor:'Worn to the shape of a hand.'},
  brace:{name:'Slag Brace',rarity:'Uncommon',bonus:[.04,.14,0,0],flavor:'Heavy. Worth it.'},
  lamp:{name:'Deep Lamp',rarity:'Rare',bonus:[0,.16,0,.04],flavor:'Burns on something that is not oil.'},
  key:{name:'Cinder Key',rarity:'Rare',bonus:[.06,0,.18,0],flavor:'Warm to the touch, always.'},
};
// Explicitly proposed, unbalanced resource policies. No production equivalent.
const jobs = {
  extraction:{name:'Extraction',short:'Bring back alloy',note:'More alloy. Less intel and credits.',factors:[.9,1.25,.8]},
  survey:{name:'Survey',short:'Bring back intel',note:'More intel. Less alloy and credits.',factors:[.9,.75,1.6]},
};
const facilities = {
  forge:{name:'Forge',effect:'+6% alloy · +2% gear-find modifier per level'},
  archive:{name:'Archive',effect:'+8% intel per level'},
};
const guildSigils = {
  lantern:{name:'Lantern',path:'M12 10V7a4 4 0 0 1 8 0v3M9 13l3-3h8l3 3-2 3H11ZM11 16l-2 11h14l-2-11M9 27l-2 3h18l-2-3M16 18v6M13 22h6'},
  compass:{name:'Compass',path:'M16 2v5M16 25v5M2 16h5M25 16h5M6 6l3 3M23 23l3 3M6 26l3-3M23 9l3-3M16 6l4 10-4 10-4-10ZM6 16h6M20 16h6'},
  branch:{name:'Branch',path:'M16 30V11M16 24Q5 25 5 15q10 0 11 9M16 19Q27 20 27 9q-10 0-11 10M16 12Q7 9 16 2q9 7 0 10'},
  anvil:{name:'Anvil',path:'M3 9h19V6h6v9H10ZM10 15l3 5-3 6H7v4h19v-4h-4l-3-6 3-5M13 20h6M3 9v3l7 3'},
};
function guildSigil(id) {
  const sigil=guildSigils[id]||guildSigils.lantern;
  return `<svg class="guild-sigil" viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="${sigil.path}"/></svg>`;
}
function guildHeading() {
  return `<h2 class="guild-heading"><button data-action="identity" aria-label="Edit guild name and sigil: ${esc(state.guild.name)}">${guildSigil(state.guild.sigil)}<span>${esc(state.guild.name)}</span><svg class="edit-guild" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.3" aria-hidden="true"><path d="M4 13L13 4l3 3-9 9-4 1ZM11 6l3 3"/></svg></button></h2>`;
}
const clone = value => JSON.parse(JSON.stringify(value));
const esc = value => String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const roman = n => ({1:'I',2:'II',3:'III',4:'IV',5:'V',6:'VI'})[n] || String(n);
let state;
let dialogFocus;
let dialogData;
const phone = document.querySelector('#phone');
const params = new URLSearchParams(location.search);
if (params.has('embed')) document.body.classList.add('embed');

function reset() {
  state = {
    view:'camp', section:null, credits:96, alloy:18, intel:61,
    guild:{name:'The Silver Lantern',sigil:'lantern'},
    facilities:{forge:1,barracks:2,archive:1}, project:'forge',
    members:{
      mira:{name:'Mira',class:'recon',level:4,equipment:['g1',null]},
      odrin:{name:'Odrin',class:'artificer',level:4,equipment:['g2',null]},
      pike:{name:'Pike',class:'archivist',level:4,equipment:[null,null]},
      kael:{name:'Kael',class:'vanguard',level:4,equipment:[null,null]},
    },
    gear:[{id:'g1',def:'optic'},{id:'g2',def:'pick'},{id:'g3',def:'brace'}],
    plan:{minutes:25,intent:'Finish the methods section',sector:'blackstone',job:'extraction',squad:['mira','odrin']},
    run:null, report:null, completed:0, notice:'', custom:false,
  };
  closeDialog(false);
  render();
}
function gear(id) { return state.gear.find(g => g.id === id); }
function owner(id) { return Object.entries(state.members).find(([,m]) => m.equipment.includes(id))?.[0]; }
function projectCost(id=state.project) {
  const level = state.facilities[id];
  return {credits:Math.round(120*Math.pow(1.55,level-1)),alloy:Math.round(25*Math.pow(1.6,level-1))};
}
function affordable(id=state.project) {
  const c=projectCost(id); return state.credits>=c.credits && state.alloy>=c.alloy;
}
function validPlan() {
  const p=state.plan;
  return Number.isInteger(p.minutes)&&p.minutes>=5&&p.minutes<=180&&p.minutes%5===0&&p.minutes>=sectors[p.sector].min&&p.squad.length>0&&p.squad.length<=2;
}
function forecast(plan=state.plan) {
  const total=[0,0,0,0];
  for(const id of plan.squad) {
    const m=state.members[id], c=classes[m.class], level=(m.level-1)*.04;
    const b=c.base.map((v,i)=>v+(i===3?level*.25:level));
    if(plan.minutes>=c.window[0]&&plan.minutes<=c.window[1]) c.bonus.forEach((v,i)=>b[i]+=v);
    for(const uid of m.equipment) {
      const g=gear(uid); if(g) gearDefs[g.def].bonus.forEach((v,i)=>b[i]+=v);
    }
    b.forEach((v,i)=>total[i]+=v/Math.max(1,plan.squad.length));
  }
  total[1]+=(state.facilities.forge-1)*.06;
  total[2]+=(state.facilities.archive-1)*.08;
  total[3]+=(state.facilities.forge-1)*.02;
  const sector=sectors[plan.sector], team=1+.15*Math.max(0,plan.squad.length-1);
  const raw=sector.rates.map((rate,i)=>rate*plan.minutes*(1+total[i])*team);
  const base=raw.map(Math.round), yields=raw.map((v,i)=>Math.round(v*jobs[plan.job].factors[i]));
  const depth=Math.min(1.6,plan.minutes/sector.nominal);
  const chance=Math.max(.02,Math.min(.9,sector.rare*(.55+.75*depth)*(1+total[3])));
  return {base,yields,total,chance,rolls:1+(depth>=1?1:0)+(depth>=1.4?1:0)};
}
function names(squad=state.plan.squad) { return squad.map(id=>state.members[id].name).join(' & ') || 'Choose a squad'; }
function icon(name) { return `<svg class="summary-icon" aria-hidden="true"><use href="#${name}"/></svg>`; }
function stores(values=[state.credits,state.alloy,state.intel],prefix='') {
  return `<div class="stores">${['credits','alloy','intel'].map((label,i)=>`<div><b>${prefix}${values[i]}</b><span>${label}</span></div>`).join('')}</div>`;
}
function group(id,title,value,body,number) {
  return `<details data-group="${id}" ${state.section===id?'open':''}><summary>${number?`<span class="step-number">0${number}</span>`:icon(id==='party'?'party':id==='stores'?'chest':'report')}<span class="summary-text"><span class="summary-title">${title}</span><span class="summary-value">${value}</span></span><span class="chevron" aria-hidden="true">⌄</span></summary><div class="detail-body">${body}</div></details>`;
}
function projectPanel(returning=false) {
  const c=projectCost(), f=facilities[state.project], level=state.facilities[state.project];
  const ratio=Math.min(1,state.credits/c.credits,state.alloy/c.alloy);
  return `<section class="project" aria-label="Selected project"><div class="row"><div><div class="eyebrow">${returning?'Within reach':'Your next project'}</div><h3>${f.name} ${roman(level+1)}</h3></div>${returning?'':`<button class="text-button" data-action="projects">Change</button>`}</div><p>${f.effect}</p>${returning?`<p>You have enough to build it back at camp.</p>`:`<div class="project-cost"><span>${state.credits} / ${c.credits} credits</span><span>${state.alloy} / ${c.alloy} alloy</span></div><div class="meter" role="progressbar" aria-label="Project funding" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${Math.floor(ratio*100)}"><span style="width:${ratio*100}%"></span></div>${affordable()?`<button class="secondary" data-action="upgrade">Build ${f.name} ${roman(level+1)}</button>`:''}`}</section>`;
}
function camp() {
  const party = Object.entries(state.members).map(([id,m])=>`<div class="member-line"><div class="summary-text"><strong>${m.name}</strong><small>${classes[m.class].name} · level ${m.level}</small><small>${m.equipment.filter(Boolean).length}/2 gear slots filled</small></div><button class="secondary" data-loadout="${id}">Equip</button></div>`).join('');
  const stash = `${stores()}<p class="compact-note">${state.gear.length} pieces of equipment · ${Object.values(state.members).reduce((n,m)=>n+m.equipment.filter(Boolean).length,0)} equipped</p><p class="next-goal">Forge ${roman(state.facilities.forge)} · Archive ${roman(state.facilities.archive)}</p>`;
  return `<div class="screen camp"><div class="scroll"><header class="screen-head"><div class="topline"><span>Outpost</span><span class="badge">Guild 5</span></div>${guildHeading()}</header><figure class="art"><img src="../camp-study/camp-concept.png" alt="Ink drawing of two travelers beside a lantern and a tent among old stone ruins."><figcaption class="art-caption"><span>Four at camp.</span><span>Ready when you are.</span></figcaption></figure>${state.notice?`<p class="notice" role="status">${esc(state.notice)}</p>`:''}${projectPanel()}<div class="groups">${group('party','Squad & equipment',`${names()} selected · 2 squad slots`,party)}${group('stores','Stores & facilities',`${state.credits} credits · ${state.alloy} alloy · ${state.intel} intel`,stash)}</div></div><footer class="action-area"><button class="primary" data-action="plan">Plan an expedition</button><button class="secondary" data-action="repeat" ${validPlan()?'':'disabled'}>Repeat ${state.plan.minutes} min · ${jobs[state.plan.job].name}</button></footer></div>`;
}
function dispatch() {
  const p=state.plan,s=sectors[p.sector],f=forecast();
  const time=`<label class="work-label" for="intent">What are you working on?</label><input class="work-input" id="intent" value="${esc(p.intent)}" maxlength="160" placeholder="Name your task (optional)"><div class="duration"><strong>${p.minutes}</strong><span>minutes</span></div><div class="durations">${[15,25,45,60,90].map(m=>`<button class="duration-button" data-minutes="${m}" aria-pressed="${p.minutes===m&&!state.custom}">${m}</button>`).join('')}<button class="duration-button" data-action="custom" aria-pressed="${state.custom}">Custom</button></div>${state.custom?`<label class="custom-duration">Minutes <input id="custom-minutes" type="number" min="5" max="180" step="5" value="${p.minutes}"></label><p class="compact-note">5–180 minutes, in steps of 5.</p>`:''}<button class="continue" data-step="destination">Choose their work →</button>`;
  const destination = Object.entries(sectors).map(([id,v])=>`<button class="choice" data-sector="${id}" aria-pressed="${p.sector===id}"><span class="choice-row"><strong>${v.name}</strong>${p.sector===id?'<span class="picked">✓</span>':''}</span><small>${v.note} · ${v.min} min minimum</small></button>`).join('')+`<h3 class="choice-subhead">Expedition purpose</h3><div class="jobs">${Object.entries(jobs).map(([id,j])=>`<button class="choice" data-job="${id}" aria-pressed="${p.job===id}"><strong>${p.job===id?'✓ ':''}${j.name}</strong><small>${j.note}</small></button>`).join('')}</div><button class="continue" data-step="squad">Check the squad →</button>`;
  const squad = Object.entries(state.members).map(([id,m])=>{
    const c=classes[m.class],selected=p.squad.includes(id),fits=p.minutes>=c.window[0]&&p.minutes<=c.window[1];
    return `<button class="choice" data-member="${id}" aria-pressed="${selected}" ${!selected&&p.squad.length>=2?'disabled':''}><span class="choice-row"><strong>${m.name} · ${c.name}</strong><span class="picked">${selected?'✓':''}</span></span><small>Level ${m.level} · ${fits?'Duration bonus active':`Duration bonus at ${c.window[0]}–${c.window[1]} min`}</small></button>`;
  }).join('')+`<p class="section-note">${p.squad.length}/2 selected. Deselect a member to free a slot. Equipment can be changed at camp.</p><button class="continue" data-action="collapse">Review this plan</button>`;
  let warning='';
  if(!Number.isInteger(p.minutes)||p.minutes<5||p.minutes>180||p.minutes%5) warning='Choose 5–180 minutes in steps of 5.';
  else if(p.minutes<s.min) warning=`${s.name} needs at least ${s.min} minutes. Keep your time and choose a closer destination.`;
  else if(!p.squad.length) warning='Choose at least one squad member.';
  return `<div class="screen"><div class="scroll"><header class="screen-head"><div class="topline"><button class="back" data-action="camp">← Camp</button><span>Dispatch</span></div><h2>Give them a purpose.</h2></header><div class="dispatch-form">${group('time','Your focus',`${p.minutes} minutes${p.intent?` · ${esc(p.intent)}`:''}`,time,1)}${group('destination','Their expedition',`${s.name} · ${jobs[p.job].name}`,destination,2)}${group('squad','The squad',names(),squad,3)}</div>${warning?`<p class="warning" role="status">${warning}</p>`:`<section class="forecast" aria-label="Expected haul"><p>Expected haul · 100% Integrity</p>${stores(f.yields)}</section>`}<p class="final-summary">${jobs[p.job].short}.<strong>${affordable()?'Your selected project is already funded.':`Working toward ${facilities[state.project].name} ${roman(state.facilities[state.project]+1)}.`}</strong></p></div><footer class="action-area"><button class="primary" id="dispatch" data-action="deploy" ${validPlan()?'':'disabled'}>Deploy · ${p.minutes} minutes</button><p class="below-action">Then lock your phone and get to work.</p></footer></div>`;
}
function away() {
  const r=state.run;
  return `<div class="screen"><header class="screen-head"><div class="topline">Expedition underway</div><h2>${sectors[r.plan.sector].name}</h2><p class="small muted">${names(r.plan.squad)} · ${jobs[r.plan.job].name}</p></header><div class="away-body"><div class="clock" aria-label="${r.plan.minutes} minutes remaining">${String(r.plan.minutes).padStart(2,'0')}:00</div><p>They’ll have a story when you return.</p><p class="integrity">INTEGRITY 100%<span>Your time away protects the expedition.</span></p></div><div class="away-note">Your work<strong>${esc(r.plan.intent)||'A little uninterrupted time.'}</strong>Lock your phone. The expedition is in their hands.</div><footer class="action-area"><button class="secondary" data-action="recall">Recall expedition</button></footer></div>`;
}
function lampArt() {
  return `<svg class="item-art" viewBox="0 0 100 140" aria-hidden="true"><g fill="none" stroke="currentColor" stroke-width="2"><path d="M38 31V18Q38 7 50 7Q62 7 62 18V31M27 39L37 30H63L73 39M27 39H73L68 50H32ZM32 50L25 113H75L68 50M25 113L20 123H80L75 113M20 123V130H80V123M38 53L35 109M62 53L65 109M28 83H72"/><path d="M47 97Q34 82 52 66Q48 82 58 85Q66 99 47 97Z" fill="#b6a078"/><path d="M49 49V61M30 123H69M32 117H67M41 33H59" stroke-width="1"/></g></svg>`;
}
function opticArt() {
  return `<svg class="item-art" viewBox="0 0 100 140" aria-hidden="true"><g fill="none" stroke="currentColor" stroke-width="2"><path d="M29 34L47 27L73 99L55 107ZM34 33L60 104M46 43L38 46M58 78L50 81M61 86L53 89"/><ellipse cx="37" cy="30" rx="17" ry="9" transform="rotate(-20 37 30)" fill="#b6a078"/><ellipse cx="64" cy="105" rx="17" ry="9" transform="rotate(-20 64 105)" fill="#e7e3d0"/><path d="M54 107L62 101L66 105L74 99M69 116Q76 133 35 132" stroke-width="1"/></g></svg>`;
}
function returned() {
  const r=state.report, f=r.forecast, item=r.loot?gearDefs[r.loot.def]:null;
  const reward=item?`<section class="relic"><div class="rarity">${item.rarity} find</div>${r.loot.def==='key'?'<svg class="key-art" aria-hidden="true"><use href="#key"/></svg>':r.loot.def==='optic'?opticArt():lampArt()}<h3>${item.name}</h3><p class="flavor">${item.flavor}</p><div class="effect">${effects(item.bonus)}</div></section>`:`<section class="relic"><div class="rarity">Supplies secured</div><h3>Good work, brought home.</h3><p class="flavor">The stores are fuller than when they left.</p></section>`;
  const report = `${stores(f.yields,'+')}<p class="small">${jobs[r.plan.job].name} shifted the haul toward ${r.plan.job==='extraction'?'alloy':'intel'}.</p><table class="report-table"><caption class="sr-only">Effect of the selected expedition purpose</caption><thead><tr><th>Haul</th><th>Credits</th><th>Alloy</th><th>Intel</th></tr></thead><tbody><tr><td>Before purpose</td>${f.base.map(v=>`<td>${v}</td>`).join('')}</tr><tr><td>${jobs[r.plan.job].name}</td>${f.yields.map(v=>`<td>${v}</td>`).join('')}</tr></tbody></table><p class="small">${names(r.plan.squad)} · ${r.plan.minutes} minutes · 100% Integrity. Squad, equipped gear and facility bonuses are included.</p><p class="journal">${r.plan.sector==='blackstone'?'They set the lamp at the mouth of the old workings and carried the day’s haul back to camp.':r.plan.sector==='cinder'?'There was still light between the shelves when they closed their notebooks.':'They followed the old path back, packs heavier than when they left.'}</p>`;
  return `<div class="screen return"><div class="scroll"><header class="return-intro"><div class="eyebrow">${r.plan.minutes} minutes · 100% Integrity</div><h2>Back from ${r.plan.sector==='blackstone'?'the Hollow':r.plan.sector==='cinder'?'the Archive':'the Verge'}.</h2><p>${sectors[r.plan.sector].name} · ${jobs[r.plan.job].name}</p></header>${reward}${affordable()?projectPanel(true):''}<div class="groups">${group('report','Expedition report',`<span class="rewards-summary">+${f.yields[0]} cr · +${f.yields[1]} alloy · +${f.yields[2]} intel</span>`,`<div class="report">${report}</div>`)}</div></div><footer class="action-area"><button class="primary" data-action="camp">Return to camp</button><p class="below-action">${item?'Your find and earnings are already in the stores.':'Your earnings are already in the stores.'}</p></footer></div>`;
}
function render(focusKey) {
  const hints={camp:'Start with the project. “Squad & equipment” lets you compare a gear swap. “Repeat” deploys the saved plan immediately.',dispatch:'Keep the 25 minutes. Try Extraction and Survey under “Their expedition” and compare the expected haul.',away:'This is the stopping point. Use the review control above to simulate returning after the full focus session.',return:'Open the report to see what the plan changed. At camp, the earnings can fund an upgrade and the find can be equipped.'};
  phone.classList.toggle('away',state.view==='away');
  const elapsed=state.view==='return'?state.report.plan.minutes:0,minutes=9*60+41+elapsed;
  const time=`${Math.floor(minutes/60)}:${String(minutes%60).padStart(2,'0')}`;
  phone.innerHTML=`<div class="status"><span>${time}</span><span>TELOS</span></div>`+({camp,dispatch,away,return:returned}[state.view])();
  document.querySelector('#finish-demo').disabled=state.view!=='away';
  document.querySelector('#hint').textContent=hints[state.view];
  phone.querySelectorAll('details').forEach(el=>el.addEventListener('toggle',()=>{
    if(!el.isConnected) return;
    if(el.open) {state.section=el.dataset.group;phone.querySelectorAll('details').forEach(other=>{if(other!==el)other.open=false;});}
    else if(state.section===el.dataset.group) state.section=null;
  }));
  if(focusKey) phone.querySelector(focusKey)?.focus({preventScroll:true});
}
function changeView(view,section=null) {
  closeDialog(false);state.view=view;state.section=section;render();
  const heading=phone.querySelector('h2');if(heading){heading.tabIndex=-1;heading.focus({preventScroll:true});}
}
function commitRun() {
  if(state.run||state.view==='away'||!validPlan())return;
  const loadouts=Object.fromEntries(state.plan.squad.map(id=>[id,clone(state.members[id].equipment)]));
  state.run={plan:clone(state.plan),forecast:forecast(),loadouts,facilities:clone(state.facilities)};
  state.notice='';changeView('away');
}
function completeRun() {
  if(state.view!=='away'||!state.run)return;
  const r=state.run;
  [state.credits,state.alloy,state.intel]=[state.credits,state.alloy,state.intel].map((v,i)=>v+r.forecast.yields[i]);
  // First completed run deliberately shows a find, regardless of roll chance.
  r.loot=null;
  if(state.completed===0) {
    const def=r.plan.sector==='cinder'?'key':r.plan.sector==='mosswood'?'optic':'lamp';
    r.loot={id:'g4',def};state.gear.push(r.loot);
  }
  state.completed++;state.report=r;state.run=null;changeView('return');
}
function effects(b) {
  const labels=['credits','alloy','intel','gear-find modifier'];
  return b.map((v,i)=>v?`${v>0?'+':''}${Math.round(v*100)}% ${labels[i]}`:'').filter(Boolean).join(' · ')||'No modifiers';
}
function openDialog(kind,data={}) {
  if(state.view==='away'&&kind!=='recall')return;
  dialogFocus=document.activeElement;dialogData={kind,...data};drawDialog();
}
function drawDialog(focusSelector) {
  phone.querySelector('.dialog-shade')?.remove();
  const d=dialogData;if(!d)return;
  let title='',body='';
  if(d.kind==='identity') {
    title='Your guild';
    body=`<label class="work-label" for="guild-name">Guild name</label><input class="work-input" id="guild-name" maxlength="32" value="${esc(d.name)}" autocomplete="off"><p class="compact-note">Up to 32 characters. Change it whenever you like.</p><h4 class="sigil-label">Guild sigil</h4><div class="sigil-choices" role="group" aria-label="Choose a guild sigil">${Object.entries(guildSigils).map(([id,s])=>`<button class="choice sigil-choice" data-guild-sigil="${id}" aria-pressed="${d.sigil===id}">${guildSigil(id)}<span>${s.name}</span><span class="sigil-check" aria-hidden="true">${d.sigil===id?'✓':''}</span></button>`).join('')}</div><button class="primary" data-action="save-identity" ${d.name.trim()?'':'disabled'}>Save guild</button><button class="secondary" data-action="close">Cancel</button>`;
  }
  if(d.kind==='projects') {
    title='Choose your next project';
    body=`<p>Choose what the guild is saving toward.</p>`+Object.entries(facilities).map(([id,f])=>{
      const c=projectCost(id);
      return `<button class="choice" data-project="${id}" aria-pressed="${state.project===id}"><span class="choice-row"><strong>${f.name} ${roman(state.facilities[id]+1)}</strong><span class="picked">${id===state.project?'✓':''}</span></span><small>${f.effect}</small><small>${c.credits} credits · ${c.alloy} alloy</small></button>`;
    }).join('');
  }
  if(d.kind==='upgrade') {
    const f=facilities[state.project],c=projectCost();title=`Build ${f.name} ${roman(state.facilities[state.project]+1)}`;
    body=`<p>${f.effect}. This improvement applies to future expeditions.</p><p>Spend <strong>${c.credits} credits and ${c.alloy} alloy</strong>.</p><button class="primary" data-action="confirm-upgrade">Build improvement</button><button class="secondary" data-action="close">Keep saving</button>`;
  }
  if(d.kind==='loadout') {
    const m=state.members[d.member];title=`${m.name}’s equipment`;
    const slot=d.slot||0,current=m.equipment[slot],before=forecast().yields;
    body=`<p>${classes[m.class].name} · level ${m.level}. Select a slot, then choose an item from the stores.</p><div class="loadout">${m.equipment.map((uid,i)=>`<button class="slot-button" data-slot="${i}" aria-pressed="${slot===i}"><span>Slot ${i+1}</span><strong>${uid?gearDefs[gear(uid).def].name:'Empty'}</strong></button>`).join('')}</div>`;
    const available=state.gear.filter(g=>!owner(g.id)||g.id===current);
    body+=available.map(g=>{
      const def=gearDefs[g.def],chosen=g.id===current;
      m.equipment[slot]=g.id;const after=forecast().yields;m.equipment[slot]=current;
      const diff=after.map((v,i)=>v-before[i]);
      const impact=state.plan.squad.includes(d.member)?`Next ${state.plan.minutes} min: ${diff.map((v,i)=>`${v>=0?'+':''}${v} ${['cr','alloy','intel'][i]}`).join(' · ')}`:'Not in the selected squad.';
      return `<button class="choice" data-equip="${g.id}" aria-pressed="${chosen}"><span class="choice-row"><strong>${def.name}</strong><span class="picked">${chosen?'Equipped':def.rarity}</span></span><small>${effects(def.bonus)}</small>${chosen?'':`<small>${impact}</small>`}</button>`;
    }).join('');
    if(current)body+=`<button class="secondary" data-action="unequip">Clear slot ${slot+1}</button>`;
    body+=`<p class="comparison">Figures compare this swap with the current loadout.<span>100% Integrity · ${sectors[state.plan.sector].name} · ${jobs[state.plan.job].name}</span></p><button class="primary" data-action="done-equipment">Done</button>`;
  }
  if(d.kind==='recall') {
    title='Recall the expedition?';
    body='<p>This example has not advanced any time. Recalling now returns the squad with no earnings.</p><button class="primary" data-action="close">Keep focusing</button><button class="secondary" data-action="confirm-recall">Recall now</button>';
  }
  const shade=document.createElement('div');shade.className='dialog-shade';
  shade.innerHTML=`<section class="sheet" role="dialog" aria-modal="true" aria-labelledby="dialog-title"><div class="sheet-head"><h3 id="dialog-title">${title}</h3><button class="text-button close-sheet" data-action="close" aria-label="Close dialog">✕</button></div>${body}</section>`;
  phone.append(shade);phone.querySelector('.screen').inert=true;
  const heading=shade.querySelector('h3');heading.tabIndex=-1;
  const target=focusSelector?shade.querySelector(focusSelector):null;
  (target||heading).focus({preventScroll:true});
}
function closeDialog(restore=true) {
  const wasLoadout=dialogData?.kind==='loadout',member=dialogData?.member;
  phone.querySelector('.dialog-shade')?.remove();const screen=phone.querySelector('.screen');if(screen)screen.inert=false;
  dialogData=null;
  if(restore&&wasLoadout){render(`[data-loadout="${member}"]`);return;}
  if(restore&&dialogFocus?.isConnected)dialogFocus.focus({preventScroll:true});
}

phone.addEventListener('input',event=>{
  if(event.target.id==='intent'&&state.view==='dispatch')state.plan.intent=event.target.value;
  if(event.target.id==='guild-name'&&dialogData?.kind==='identity') {
    dialogData.name=event.target.value;
    phone.querySelector('[data-action=save-identity]').disabled=!event.target.value.trim();
  }
});
phone.addEventListener('change',event=>{
  if(event.target.id==='custom-minutes'&&state.view==='dispatch'){
    state.plan.minutes=Number(event.target.value);render('#custom-minutes');
  }
  if(event.target.id==='intent'){
    const summary=phone.querySelector('[data-group=time] .summary-value');
    if(summary)summary.textContent=`${state.plan.minutes} minutes${state.plan.intent?' · '+state.plan.intent:''}`;
  }
});
phone.addEventListener('click',event=>{
  const b=event.target.closest('button');if(!b||b.disabled)return;
  const data=b.dataset;
  if(data.action==='close'){closeDialog();return;}
  if(state.view==='away'){
    if(data.action==='recall')openDialog('recall');
    if(data.action==='confirm-recall'){state.run=null;state.notice='Squad recalled. No time elapsed; no earnings.';changeView('camp');}
    return;
  }
  if(data.loadout){openDialog('loadout',{member:data.loadout,slot:0});return;}
  if(data.guildSigil&&dialogData?.kind==='identity'&&guildSigils[data.guildSigil]){
    dialogData.sigil=data.guildSigil;drawDialog(`[data-guild-sigil="${data.guildSigil}"]`);return;
  }
  if(data.slot!==undefined&&dialogData?.kind==='loadout'){dialogData.slot=Number(data.slot);drawDialog(`[data-slot="${data.slot}"]`);return;}
  if(data.equip&&dialogData?.kind==='loadout'){
    const d=dialogData,m=state.members[d.member],slot=d.slot||0;
    if(!owner(data.equip)||m.equipment[slot]===data.equip){m.equipment[slot]=data.equip;drawDialog(`[data-equip="${data.equip}"]`);}return;
  }
  if(data.project){state.project=data.project;closeDialog(false);render('[data-action=projects]');return;}
  if(data.minutes){state.plan.minutes=Number(data.minutes);state.custom=false;render(`[data-minutes="${data.minutes}"]`);return;}
  if(data.sector){state.plan.sector=data.sector;render(`[data-sector="${data.sector}"]`);return;}
  if(data.job){state.plan.job=data.job;render(`[data-job="${data.job}"]`);return;}
  if(data.member){
    const squad=state.plan.squad,index=squad.indexOf(data.member);
    if(index>=0)squad.splice(index,1);else if(squad.length<2)squad.push(data.member);
    render(`[data-member="${data.member}"]`);return;
  }
  if(data.step){state.section=data.step;render();phone.querySelector(`[data-group=${data.step}] summary`).focus({preventScroll:true});return;}
  switch(data.action){
    case 'identity':if(state.view==='camp')openDialog('identity',clone(state.guild));break;
    case 'save-identity':if(dialogData?.kind==='identity'){
      const name=dialogData.name.trim().replace(/\s+/g,' ');
      if(!name||name.length>32||!guildSigils[dialogData.sigil])break;
      state.guild={name,sigil:dialogData.sigil};
      closeDialog(false);render('[data-action=identity]');
    }break;
    case 'plan':state.notice='';changeView('dispatch','time');break;
    case 'camp':changeView('camp');break;
    case 'repeat':case 'deploy':commitRun();break;
    case 'projects':openDialog('projects');break;
    case 'upgrade':if(affordable())openDialog('upgrade');break;
    case 'confirm-upgrade':if(dialogData?.kind==='upgrade'&&affordable()){
      const c=projectCost();state.credits-=c.credits;state.alloy-=c.alloy;state.facilities[state.project]++;
      state.notice=`${facilities[state.project].name} ${roman(state.facilities[state.project])} built. Ready for the next expedition.`;
      closeDialog(false);render('[data-action=plan]');
    }break;
    case 'custom':state.custom=true;render('#custom-minutes');break;
    case 'collapse':state.section=null;render('#dispatch');break;
    case 'unequip':if(dialogData?.kind==='loadout'){
      state.members[dialogData.member].equipment[dialogData.slot||0]=null;drawDialog();
    }break;
    case 'done-equipment':{
      const member=dialogData?.member;closeDialog(false);render(`[data-loadout="${member}"]`);break;
    }
  }
});
document.addEventListener('keydown',event=>{
  const modal=phone.querySelector('[role=dialog]');if(!modal)return;
  if(event.key==='Escape'){event.preventDefault();closeDialog();}
  if(event.key==='Tab'){
    const controls=[...modal.querySelectorAll('button:not(:disabled),input')],first=controls[0],last=controls.at(-1);
    if(event.shiftKey&&(document.activeElement===first||!controls.includes(document.activeElement))){event.preventDefault();last?.focus();}
    else if(!event.shiftKey&&(document.activeElement===last||!controls.includes(document.activeElement))){event.preventDefault();first?.focus();}
  }
});
document.querySelector('#reset-demo').addEventListener('click',reset);
document.querySelector('#finish-demo').addEventListener('click',completeRun);
reset();
if(params.get('view')==='dispatch')changeView('dispatch');
if(params.get('view')==='away')commitRun();
if(params.get('view')==='return'){commitRun();completeRun();}

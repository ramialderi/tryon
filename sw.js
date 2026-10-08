const V='tryon-v1',SHELL=['./','customer-app.html','shop-panel.html','config.js','icon-192.png','shop-192.png'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(V).then(c=>Promise.all(SHELL.map(u=>c.add(u).catch(()=>{})))).then(()=>self.skipWaiting()))});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==V).map(k=>caches.delete(k)))).then(()=>clients.claim()))});
const put=(r,res)=>{if(res.ok){const c=res.clone();caches.open(V).then(x=>x.put(r,c))}return res};
self.addEventListener('fetch',e=>{
  const r=e.request;if(r.method!=='GET')return;const u=new URL(r.url);
  if(u.origin===location.origin){ // ملفات الموقع: الشبكة أولًا لتصل التحديثات، والنسخة المحفوظة عند انقطاع الإنترنت
    e.respondWith(fetch(r).then(res=>put(r,res)).catch(()=>caches.match(r,{ignoreSearch:true})));
  }else if(/(^|\.)jsdelivr\.net$|^storage\.googleapis\.com$/.test(u.hostname)){ // مكتبات ونموذج الوجه: المحفوظ أولًا
    e.respondWith(caches.match(r).then(h=>h||fetch(r).then(res=>put(r,res))));
  }
});

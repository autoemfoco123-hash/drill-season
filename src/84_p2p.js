
/* =========================================================
   P2P MULTIPLAYER - used outside claude.ai (GitHub Pages or any
   static host). It implements the slice of the artifact runtime
   that 85_net.js uses (a user id, live room presence, and a
   'players' collection) on top of Trystero: public Nostr relays
   only introduce players, then they talk directly over WebRTC.
   No server, no account. Everything received is untrusted.
   ========================================================= */
const P2P_APP = 'drill-season.calder-park.v1';
const P2P_ROOM = 'calder-park';
const P2P_STALE_MS = 9000;
function p2pAvailable() {
  return typeof window.Trystero === 'object' && typeof window.Trystero.joinRoom === 'function' && typeof window.RTCPeerConnection === 'function' && window.isSecureContext !== false;
}
function lsGet(k) { try { return localStorage.getItem(k); } catch (e) { return null; } }
function lsSet(k, v) { try { localStorage.setItem(k, v); } catch (e) { } }
const p2pId = v => typeof v === 'string' && /^[\w.:-]{1,64}$/.test(v) ? v : null;
const p2pNum = (v, lo, hi) => { v = +v; return isFinite(v) ? clamp(v, lo, hi) : 0; };
const p2pStr = (v, n) => typeof v === 'string' ? v.slice(0, n) : '';
function p2pImg(v) { return typeof v === 'string' && v.length < 300000 && /^data:image\/(jpeg|png|webp);base64,[A-Za-z0-9+/=]+$/.test(v) ? v : null; }
// keep only the fields the game reads, with sane types and sizes
function cleanProfile(d) {
  if (!d || typeof d !== 'object') return null;
  const id = p2pId(d.id); if (!id) return null;
  const posts = Array.isArray(d.posts) ? d.posts.slice(0, 8).filter(p => p && typeof p === 'object').map(p => ({ k: p2pStr(p.k, 12), at: p2pNum(p.at, 0, 9e15), title: p2pStr(p.title, 60), type: p2pStr(p.type, 12), grade: p2pStr(p.grade, 3), vs: p2pStr(p.vs, 20), e: p2pStr(p.e, 12), train: !!p.train })) : [];
  const photos = Array.isArray(d.photos) ? d.photos.slice(0, 3).filter(p => p && typeof p === 'object').map(p => ({ at: p2pNum(p.at, 0, 9e15), cap: p2pStr(p.cap, 80), img: p2pImg(p.img), likes: p2pNum(p.likes, 0, 1e9) | 0 })) : [];
  return {
    id, name: p2pStr(d.name, 16), color: p2pStr(d.color, 24), buzz: p2pNum(d.buzz, 0, 1e6), heat: p2pNum(d.heat, 0, 100), day: p2pNum(d.day, 0, 1e5),
    tracks: p2pNum(d.tracks, 0, 1e5), best: d.best && typeof d.best === 'object' ? { title: p2pStr(d.best.title, 40), grade: p2pStr(d.best.grade, 3) } : null,
    endings: Array.isArray(d.endings) ? d.endings.slice(0, 6).map(e => p2pStr(e, 12)) : [], posts, photos,
    followers: p2pNum(d.followers, 0, 1e9), updated: p2pNum(d.updated, 0, Date.now() + 6e4),
  };
}
function makeP2PClient() {
  const T = window.Trystero;
  let uid = lsGet('ds.uid');
  if (!p2pId(uid)) { uid = 'p' + Math.random().toString(36).slice(2, 12) + Date.now().toString(36); lsSet('ds.uid', uid); }
  const me = { peer: T.selfId, isMe: true, sameTab: true, kind: 'viewer', presence: null };
  const peers = new Map(), profiles = new Map();
  let room = null, presA = null, profA = null, peersCb = null, connCb = null, snapCb = null, myProf = null, lastPres = null, connected = null, persistT = 0;
  // profiles seen in earlier sessions (stored without photos to stay small)
  try { for (const p of JSON.parse(lsGet('ds.players') || '[]')) { const c = cleanProfile(p); if (c) profiles.set(c.id, c); } } catch (e) { }
  const pid = meta => p2pId(typeof meta === 'string' ? meta : meta && meta.peerId);
  const list = () => [me, ...[...peers.values()].filter(p => p.presence)];
  const emit = (joined, updated, left) => { if (peersCb) { try { peersCb({ peers: list(), joined, updated, left }); } catch (e) { console.error(e); } } };
  function fireSnap() {
    if (!snapCb) return;
    const docs = [...profiles.values()].sort((a, b) => (b.updated || 0) - (a.updated || 0)).slice(0, 80).map(p => ({ id: p.id, data: () => p }));
    try { snapCb({ docs }); } catch (e) { console.error(e); }
  }
  function persist() {
    if (Date.now() - persistT < 4000) return; persistT = Date.now();
    const arr = [...profiles.values()].sort((a, b) => (b.updated || 0) - (a.updated || 0)).slice(0, 60).map(p => Object.assign({}, p, { photos: p.id === uid ? p.photos : p.photos.map(ph => Object.assign({}, ph, { img: null })) }));
    lsSet('ds.players', JSON.stringify(arr));
  }
  function setConnected(c) { if (c !== connected) { connected = c; if (connCb) connCb(c); } }
  function ensureRoom() {
    if (room) return;
    const relays = Array.isArray(window.DS_RELAYS) && window.DS_RELAYS.length ? { urls: window.DS_RELAYS } : { redundancy: 8 }; // DS_RELAYS: optional override (self-hosted relays, tests)
    room = T.joinRoom({ appId: P2P_APP, relayConfig: relays }, P2P_ROOM);
    presA = room.makeAction('pres'); profA = room.makeAction('prof');
    presA.onMessage = (data, meta) => {
      const id = pid(meta); if (!id || !data || typeof data !== 'object' || Array.isArray(data)) return;
      let p = peers.get(id); const fresh = !p || !p.presence;
      if (!p) { p = { peer: id, isMe: false, sameTab: false, kind: 'viewer', presence: null, seen: 0 }; peers.set(id, p); }
      p.presence = data; p.seen = Date.now();
      emit(fresh ? [p] : [], fresh ? [] : [p], []);
    };
    profA.onMessage = (data, meta) => {
      const c = cleanProfile(data); if (!c || c.id === uid) return;
      const old = profiles.get(c.id); if (old && old.updated > c.updated) return;
      profiles.set(c.id, c); persist(); fireSnap();
    };
    room.onPeerJoin = id => {
      setConnected(true);
      if (myProf) profA.send(myProf, { target: id }).catch(() => { });
      if (lastPres) presA.send(lastPres, { target: id }).catch(() => { });
    };
    room.onPeerLeave = id => { const p = peers.get(id); peers.delete(id); if (p && p.presence) emit([], [], [p]); };
    // drop peers that went quiet; report whether any relay socket is open
    setInterval(() => {
      const now = Date.now();
      for (const [id, p] of peers) if (p.presence && now - p.seen > P2P_STALE_MS) { peers.delete(id); emit([], [], [p]); }
      let open = false;
      try { const socks = T.getRelaySockets ? T.getRelaySockets() : {}; for (const k in socks) if (socks[k] && socks[k].readyState === 1) open = true; } catch (e) { }
      setConnected(open || peers.size > 0);
    }, 2000);
    addEventListener('pagehide', () => { try { room.leave(); } catch (e) { } });
  }
  const user = { id: async () => uid };
  const roomApi = {
    onPeers(cb) { peersCb = cb; ensureRoom(); emit([], [], []); },
    onConnection(cb) { connCb = cb; ensureRoom(); connected = null; setConnected(false); },
    presence(payload) { lastPres = payload; me.presence = payload; ensureRoom(); try { return presA.send(payload).catch(() => { }); } catch (e) { return Promise.resolve(); } },
  };
  const db = {
    collection() { const q = { orderBy: () => q, limit: () => q, onSnapshot(cb) { snapCb = cb; fireSnap(); return () => { snapCb = null; }; } }; return q; },
    doc(path) {
      return {
        async set(data) {
          const c = cleanProfile(Object.assign({}, data, { id: String(path).split('/')[1] }));
          if (!c) return;
          if (Array.isArray(data.photos)) c.photos = data.photos.slice(0, 3).map(p => ({ at: +p.at || 0, cap: p2pStr(p.cap, 80), img: p2pImg(p.img), likes: p.likes | 0 }));
          myProf = c; profiles.set(c.id, c); persistT = 0; persist(); fireSnap();
          ensureRoom(); try { await profA.send(c); } catch (e) { }
        },
      };
    },
  };
  return { p2p: true, use: async name => name === 'user' ? user : name === 'room' ? roomApi : name === 'db' ? db : null };
}

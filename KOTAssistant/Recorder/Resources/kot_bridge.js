// Myレコーダーページに注入されるブリッジ。
// - kotState: localStorage の SETTING / RECORD_HISTORY を Swift 側へ通知
// - kotPunch: 打刻ボタンのクリック（ユーザー操作・プログラム操作の両方）を通知
(() => {
  if (window.__kotBridgeInstalled) return;
  window.__kotBridgeInstalled = true;

  const SETTING_KEY = 'PARSONAL_BROWSER_RECORDER@SETTING';

  const post = (handler, payload) => {
    try {
      window.webkit.messageHandlers[handler].postMessage(payload);
    } catch (e) {
      // ハンドラ未登録時は無視
    }
  };

  const readState = () => {
    const settingItem = localStorage.getItem(SETTING_KEY);
    if (!settingItem) {
      post('kotState', { notLoggedIn: true });
      return;
    }
    let historyItem = null;
    try {
      const setting = JSON.parse(settingItem);
      historyItem = localStorage.getItem('PARSONAL_BROWSER_RECORDER@RECORD_HISTORY_' + setting.user.user_token);
    } catch (e) {
      // SETTING が壊れている場合は履歴なしで送る
    }
    post('kotState', { notLoggedIn: false, setting: settingItem, history: historyItem });
  };
  window.__kotReadState = readState;

  // SETTING の record_button から打刻ボタンの DOM id を解決する
  // mark: '1'=出勤, '2'=退勤, '0'=休憩（出現順に 休始・休終）
  const resolveButtonIds = () => {
    const settingItem = localStorage.getItem(SETTING_KEY);
    if (!settingItem) return null;
    let setting;
    try {
      setting = JSON.parse(settingItem);
    } catch (e) {
      return null;
    }
    const buttons = (setting.timerecorder && setting.timerecorder.record_button) || [];
    const clockIn = buttons.filter((b) => b.mark === '1')[0];
    const clockOut = buttons.filter((b) => b.mark === '2')[0];
    const breaks = buttons.filter((b) => b.mark === '0');
    const ids = {};
    if (clockIn) ids.clockIn = 'record_' + clockIn.id;
    if (clockOut) ids.clockOut = 'record_' + clockOut.id;
    if (breaks[0]) ids.breakStart = 'record_' + breaks[0].id;
    if (breaks[1]) ids.breakEnd = 'record_' + breaks[1].id;
    return ids;
  };

  // プログラム打刻（App Intents から）。実ボタンの click() を踏むので
  // 通知経路はユーザー操作とまったく同じになる。
  window.__kotPunch = (action) => {
    const ids = window.__kotButtonIds || {};
    const el = ids[action] && document.getElementById(ids[action]);
    if (!el) return false;
    el.click();
    return true;
  };

  // 打刻済みボタンの減光（Swift 側の状態エンジンの判定で呼ばれる）
  window.__kotSetButtonDimmed = (action, dimmed) => {
    const ids = window.__kotButtonIds || {};
    const el = ids[action] && document.getElementById(ids[action]);
    if (el) el.style.opacity = dimmed ? 0.3 : '';
  };

  // ボタンの出現を最大 3 秒待ってリスナを張る（原拡張と同じポーリング）
  const installListeners = () => {
    const ids = resolveButtonIds();
    if (!ids || Object.keys(ids).length === 0) return;
    window.__kotButtonIds = ids;

    let count = 0;
    const interval = setInterval(() => {
      const found = Object.values(ids).filter((id) => document.getElementById(id));
      if (found.length === 0) {
        if (++count > 30) clearInterval(interval);
        return;
      }
      clearInterval(interval);
      for (const action of Object.keys(ids)) {
        const el = document.getElementById(ids[action]);
        if (!el) continue;
        el.addEventListener(
          'click',
          () => {
            post('kotPunch', { action: action });
            // 打刻が履歴へ反映されるのを待ってから状態を再送
            setTimeout(readState, 1000);
            setTimeout(readState, 3000);
          },
          true
        );
      }
    }, 100);
  };

  readState();
  installListeners();
})();

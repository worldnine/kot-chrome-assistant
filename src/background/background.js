const postRequest = (endpoint, headers, body, sendResponse) => {
  fetch(endpoint, {
    'method': 'POST',
    'headers': headers,
    'body': body
  })
    .then((res) => {
      if (res.ok) {
        return res.json().then((json) => {
          // Slack APIはレスポンスbody内の ok フィールドで成否を返す
          if (json && json.ok === false) {
            console.error(JSON.stringify(json));
            sendResponse({ 'status': 'failed' });
          } else {
            sendResponse({ 'status': 'success' });
          }
        });
      } else {
        return res.text().then((text) => {
          console.error('HTTP ' + res.status + ': ' + text);
          sendResponse({ 'status': 'failed' });
        });
      }
    })
    .catch((err) => {
      console.error(err);
      sendResponse({ 'status': 'failed' });
    });
};

const validateEndpoint = (endpoint) => {
  const whitelist = [
    'https://slack.com/api/chat.postMessage',
    'https://slack.com/api/users.profile.set',
    'https://hooks.slack.com/services/',
    'https://chat.googleapis.com/v1/spaces/',
  ]
  return whitelist.some((l) => endpoint.startsWith(l));
};

// --- Google Chat OAuth2 ユーザー認証 ---

const GOOGLE_CHAT_SCOPE = 'https://www.googleapis.com/auth/chat.messages.create';

// スペースID正規化: URL形式、API形式、ID単体すべて受け付け
const normalizeSpaceId = (input) => {
  const urlMatch = input.match(/chat\.google\.com\/room\/([A-Za-z0-9_-]+)/);
  if (urlMatch) return urlMatch[1];
  return input.replace(/^spaces\//, '');
};

// chrome.storage.local にトークンを永続化（Service Worker再起動に耐える）
const saveTokenToStorage = (token, expiresAt) => {
  chrome.storage.local.set({ _gchatToken: token, _gchatTokenExpiresAt: expiresAt });
};

const loadTokenFromStorage = () => {
  return new Promise((resolve) => {
    chrome.storage.local.get(['_gchatToken', '_gchatTokenExpiresAt'], (items) => {
      if (items._gchatToken && items._gchatTokenExpiresAt && Date.now() < items._gchatTokenExpiresAt) {
        resolve(items._gchatToken);
      } else {
        resolve(null);
      }
    });
  });
};

const clearTokenStorage = () => {
  chrome.storage.local.remove(['_gchatToken', '_gchatTokenExpiresAt']);
};

// OAuth2トークン取得（chrome.identity.launchWebAuthFlow使用）
const getGoogleChatAuthToken = (clientId, interactive) => {
  return new Promise((resolve, reject) => {
    const redirectUrl = chrome.identity.getRedirectURL();
    const authUrl = 'https://accounts.google.com/o/oauth2/v2/auth'
      + '?client_id=' + encodeURIComponent(clientId)
      + '&response_type=token'
      + '&redirect_uri=' + encodeURIComponent(redirectUrl)
      + '&scope=' + encodeURIComponent(GOOGLE_CHAT_SCOPE)
      + (interactive ? '' : '&prompt=none');

    chrome.identity.launchWebAuthFlow(
      { url: authUrl, interactive: interactive },
      (responseUrl) => {
        if (chrome.runtime.lastError || !responseUrl) {
          reject(chrome.runtime.lastError || new Error('認証がキャンセルされました'));
          return;
        }
        const params = new URL(responseUrl.replace('#', '?')).searchParams;
        const token = params.get('access_token');
        const expiresIn = parseInt(params.get('expires_in') || '3600', 10);
        if (token) {
          // 有効期限の5分前に失効扱いで永続化
          const expiresAt = Date.now() + (expiresIn - 300) * 1000;
          saveTokenToStorage(token, expiresAt);
          resolve(token);
        } else {
          reject(new Error('アクセストークンが取得できませんでした'));
        }
      }
    );
  });
};

// トークン取得を試行（ストレージ → サイレント → interactive フォールバック）
const acquireToken = async (clientId) => {
  // 1. ストレージから有効なトークンを取得
  const stored = await loadTokenFromStorage();
  if (stored) return stored;

  // 2. サイレント取得を試行
  try {
    return await getGoogleChatAuthToken(clientId, false);
  } catch (e) {
    // 3. interactive で再認証
    clearTokenStorage();
    return await getGoogleChatAuthToken(clientId, true);
  }
};

// Google Chat APIにユーザー認証でメッセージ投稿
const postGoogleChatUserAuth = async (clientId, spaceId, messageText, sendResponse) => {
  try {
    const normalizedId = normalizeSpaceId(spaceId);
    const token = await acquireToken(clientId);
    const endpoint = `https://chat.googleapis.com/v1/spaces/${normalizedId}/messages`;

    const res = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Authorization': 'Bearer ' + token,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ text: messageText }),
    });

    if (res.ok) {
      sendResponse({ 'status': 'success' });
    } else if (res.status === 401) {
      // APIがトークン拒否: キャッシュクリアして interactive で再取得
      clearTokenStorage();
      try {
        const newToken = await getGoogleChatAuthToken(clientId, true);
        const retryRes = await fetch(endpoint, {
          method: 'POST',
          headers: {
            'Authorization': 'Bearer ' + newToken,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ text: messageText }),
        });
        if (retryRes.ok) {
          sendResponse({ 'status': 'success' });
        } else {
          const text = await retryRes.text();
          console.error('HTTP ' + retryRes.status + ': ' + text);
          sendResponse({ 'status': 'failed', 'error': 'post_failed' });
        }
      } catch (retryErr) {
        console.error('再認証に失敗:', retryErr);
        sendResponse({ 'status': 'failed', 'error': 'reauth_failed' });
      }
    } else {
      const text = await res.text();
      console.error('HTTP ' + res.status + ': ' + text);
      sendResponse({ 'status': 'failed', 'error': 'post_failed' });
    }
  } catch (err) {
    console.error('Google Chat投稿エラー:', err);
    sendResponse({ 'status': 'failed', 'error': 'auth_failed' });
  }
};

// 認証状態チェック（ストレージのトークンで確認）
const checkGoogleChatAuth = async (clientId, sendResponse) => {
  try {
    const token = await loadTokenFromStorage();
    if (!token) {
      sendResponse({ 'status': 'disconnected' });
      return;
    }
    const res = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', {
      headers: { 'Authorization': 'Bearer ' + token }
    });
    if (res.ok) {
      const info = await res.json();
      sendResponse({ 'status': 'connected', 'email': info.email || '' });
    } else {
      sendResponse({ 'status': 'disconnected' });
    }
  } catch (err) {
    sendResponse({ 'status': 'disconnected' });
  }
};

// --- ここまで Google Chat OAuth2 ---

const setPopup = (enabled) => {
  chrome.action.setPopup({ popup: enabled ? 'src/browser_action/browser_action.html' : '' });
};

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (!msg) {
    sendResponse({ 'status': 'listener is missing.\n' + msg });
    return true;
  }

  if (msg.contentScriptQuery === 'postMessage' && validateEndpoint(msg.endpoint)) {
    postRequest(msg.endpoint, msg.headers, msg.body, sendResponse)
    return true;
  }

  if (msg.contentScriptQuery === 'changeStatus' && validateEndpoint(msg.endpoint)) {
    postRequest(msg.endpoint, msg.headers, msg.body, sendResponse)
    return true;
  }

  // Google Chat OAuth2 ユーザー認証投稿
  if (msg.contentScriptQuery === 'postGoogleChatUserAuth') {
    postGoogleChatUserAuth(msg.clientId, msg.spaceId, msg.messageText, sendResponse);
    return true;
  }

  // Google Chat OAuth2 接続解除（トークン無効化）
  if (msg.contentScriptQuery === 'disconnectGoogleChat') {
    loadTokenFromStorage().then((token) => {
      clearTokenStorage();
      if (token) {
        fetch('https://accounts.google.com/o/oauth2/revoke?token=' + token)
          .then(() => sendResponse({ 'status': 'disconnected' }))
          .catch(() => sendResponse({ 'status': 'disconnected' }));
      } else {
        sendResponse({ 'status': 'disconnected' });
      }
    });
    return true;
  }

  // Google Chat OAuth2 認証状態チェック
  if (msg.contentScriptQuery === 'checkGoogleChatAuth') {
    checkGoogleChatAuth(msg.clientId, sendResponse);
    return true;
  }

  // Google Chat OAuth2 接続（interactive認証）
  if (msg.contentScriptQuery === 'connectGoogleChat') {
    getGoogleChatAuthToken(msg.clientId, true)
      .then(async (token) => {
        // ユーザー情報を取得して返す
        try {
          const res = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', {
            headers: { 'Authorization': 'Bearer ' + token }
          });
          if (res.ok) {
            const info = await res.json();
            sendResponse({ 'status': 'connected', 'email': info.email || '' });
          } else {
            sendResponse({ 'status': 'connected', 'email': '' });
          }
        } catch (e) {
          sendResponse({ 'status': 'connected', 'email': '' });
        }
      })
      .catch((err) => {
        console.error('Google接続エラー:', err);
        sendResponse({ 'status': 'failed', 'error': err.message });
      });
    return true;
  }

  sendResponse({ 'status': 'listener is missing.\n' + msg });
  return true;
});


chrome.runtime.onInstalled.addListener(function () {
  chrome.storage.sync.get('openInNewTab', function (data) {
    setPopup(!data.openInNewTab);
  });
});

chrome.runtime.onStartup.addListener(function () {
  chrome.storage.sync.get('openInNewTab', function (data) {
    setPopup(!data.openInNewTab);
  });
});

chrome.action.onClicked.addListener(function () {
  let myrecUrl = "https://s2.ta.kingoftime.jp/independent/recorder/personal/";

  chrome.storage.sync.get(["openInNewTab", "s3Selected", "s4Selected", "samlSelected"], (items) => {
    setPopup(!items.openInNewTab);

    if (items.openInNewTab) {
      if (items.s3Selected || items.s4Selected || items.samlSelected) {
        let subdomain = "s2";
        if (items.s3Selected) {
          subdomain = "s3";
        } else if (items.s4Selected) {
          subdomain = "s4";
        }
        const recorder = !items.samlSelected ? "recorder" : "recorder2"

        myrecUrl = `https://${subdomain}.ta.kingoftime.jp/independent/${recorder}/personal/`;

      }
      chrome.tabs.query({ url: myrecUrl, currentWindow: true }, function (tabs) {
        if (tabs.length > 0) {
          chrome.tabs.update(tabs[0].id, { active: true, url: myrecUrl }).catch(function (e) { console.log(e.message) });
        } else {
          chrome.tabs.create({ url: myrecUrl }).catch(function (e) { console.log(e.message) });
        }
      });
    }
  });
});

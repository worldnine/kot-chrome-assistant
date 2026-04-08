const postRequest = (endpoint, headers, body, sendResponse) => {
  fetch(endpoint, {
    'method': 'POST',
    'headers': headers,
    'body': body
  })
    .then((res) => {
      if (res.ok) {
        return res.json().then((json) => {
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

// --- Google Chat OAuth2 (Authorization Code Flow + refresh token) ---

const GOOGLE_CHAT_SCOPE = 'https://www.googleapis.com/auth/chat.messages.create';
const TOKEN_ENDPOINT = 'https://oauth2.googleapis.com/token';

const normalizeSpaceId = (input) => {
  const urlMatch = input.match(/chat\.google\.com\/room\/([A-Za-z0-9_-]+)/);
  if (urlMatch) return urlMatch[1];
  return input.replace(/^spaces\//, '');
};

const generateCodeVerifier = () => {
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return btoa(String.fromCharCode(...array)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
};

const generateCodeChallenge = async (verifier) => {
  const encoder = new TextEncoder();
  const data = encoder.encode(verifier);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return btoa(String.fromCharCode(...new Uint8Array(digest))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
};

const saveTokenData = (data) => {
  const toSave = {
    _gchatAccessToken: data.access_token,
    _gchatTokenExpiresAt: Date.now() + (data.expires_in - 300) * 1000,
  };
  if (data.refresh_token) {
    toSave._gchatRefreshToken = data.refresh_token;
  }
  chrome.storage.local.set(toSave);
};

const loadTokenData = () => {
  return new Promise((resolve) => {
    chrome.storage.local.get(['_gchatAccessToken', '_gchatTokenExpiresAt', '_gchatRefreshToken'], resolve);
  });
};

const clearTokenStorage = () => {
  chrome.storage.local.remove(['_gchatAccessToken', '_gchatTokenExpiresAt', '_gchatRefreshToken']);
};

const refreshAccessToken = async (clientId, clientSecret, refreshToken) => {
  const res = await fetch(TOKEN_ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      refresh_token: refreshToken,
      grant_type: 'refresh_token',
    }),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error('トークン更新失敗: ' + text);
  }
  const data = await res.json();
  data.refresh_token = data.refresh_token || refreshToken;
  saveTokenData(data);
  return data.access_token;
};

const authorizeWithCodeFlow = async (clientId, clientSecret) => {
  const codeVerifier = generateCodeVerifier();
  const codeChallenge = await generateCodeChallenge(codeVerifier);
  const redirectUrl = chrome.identity.getRedirectURL();

  const authUrl = 'https://accounts.google.com/o/oauth2/v2/auth'
    + '?client_id=' + encodeURIComponent(clientId)
    + '&response_type=code'
    + '&redirect_uri=' + encodeURIComponent(redirectUrl)
    + '&scope=' + encodeURIComponent(GOOGLE_CHAT_SCOPE)
    + '&access_type=offline'
    + '&prompt=consent'
    + '&code_challenge=' + encodeURIComponent(codeChallenge)
    + '&code_challenge_method=S256';

  const responseUrl = await new Promise((resolve, reject) => {
    chrome.identity.launchWebAuthFlow(
      { url: authUrl, interactive: true },
      (url) => {
        if (chrome.runtime.lastError || !url) {
          reject(chrome.runtime.lastError || new Error('認証がキャンセルされました'));
        } else {
          resolve(url);
        }
      }
    );
  });

  const code = new URL(responseUrl).searchParams.get('code');
  if (!code) throw new Error('認証コードが取得できませんでした');

  const tokenRes = await fetch(TOKEN_ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      code: code,
      code_verifier: codeVerifier,
      grant_type: 'authorization_code',
      redirect_uri: redirectUrl,
    }),
  });
  if (!tokenRes.ok) {
    const text = await tokenRes.text();
    throw new Error('トークン交換失敗: ' + text);
  }
  const tokenData = await tokenRes.json();
  saveTokenData(tokenData);
  return tokenData.access_token;
};

const acquireToken = async (clientId, clientSecret) => {
  const stored = await loadTokenData();

  if (stored._gchatAccessToken && stored._gchatTokenExpiresAt && Date.now() < stored._gchatTokenExpiresAt) {
    return stored._gchatAccessToken;
  }

  if (stored._gchatRefreshToken) {
    try {
      return await refreshAccessToken(clientId, clientSecret, stored._gchatRefreshToken);
    } catch (e) {
      console.error('トークン更新失敗、再認証します:', e);
      clearTokenStorage();
    }
  }

  return await authorizeWithCodeFlow(clientId, clientSecret);
};

const postGoogleChatUserAuth = async (clientId, clientSecret, spaceId, messageText, sendResponse) => {
  try {
    const normalizedId = normalizeSpaceId(spaceId);
    const token = await acquireToken(clientId, clientSecret);
    const endpoint = `https://chat.googleapis.com/v1/spaces/${normalizedId}/messages`;

    const res = await fetch(endpoint, {
      method: 'POST',
      headers: { 'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json' },
      body: JSON.stringify({ text: messageText }),
    });

    if (res.ok) {
      sendResponse({ 'status': 'success' });
    } else if (res.status === 401) {
      clearTokenStorage();
      try {
        const newToken = await acquireToken(clientId, clientSecret);
        const retryRes = await fetch(endpoint, {
          method: 'POST',
          headers: { 'Authorization': 'Bearer ' + newToken, 'Content-Type': 'application/json' },
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

const checkGoogleChatAuth = async (clientId, clientSecret, sendResponse) => {
  try {
    const stored = await loadTokenData();
    // refresh tokenがあれば接続済みとみなす
    if (stored._gchatRefreshToken) {
      sendResponse({ 'status': 'connected' });
    } else {
      sendResponse({ 'status': 'disconnected' });
    }
  } catch (err) {
    sendResponse({ 'status': 'disconnected' });
  }
};

// 複数スペースへの一括投稿（トークン取得を1回にまとめる）
const postGoogleChatUserAuthBatch = async (clientId, clientSecret, spaceIds, messageText, sendResponse) => {
  try {
    const token = await acquireToken(clientId, clientSecret);
    const results = [];
    for (const spaceId of spaceIds) {
      const normalizedId = normalizeSpaceId(spaceId);
      const endpoint = `https://chat.googleapis.com/v1/spaces/${normalizedId}/messages`;
      try {
        const res = await fetch(endpoint, {
          method: 'POST',
          headers: { 'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json' },
          body: JSON.stringify({ text: messageText }),
        });
        if (res.ok) {
          results.push({ spaceId, status: 'success' });
        } else {
          const text = await res.text();
          console.error('HTTP ' + res.status + ' (space ' + spaceId + '): ' + text);
          results.push({ spaceId, status: 'failed' });
        }
      } catch (e) {
        console.error('投稿エラー (space ' + spaceId + '):', e);
        results.push({ spaceId, status: 'failed' });
      }
    }
    const allSuccess = results.every(r => r.status === 'success');
    sendResponse({ 'status': allSuccess ? 'success' : 'partial_failure', results });
  } catch (err) {
    console.error('Google Chat投稿エラー:', err);
    sendResponse({ 'status': 'failed', 'error': 'auth_failed' });
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

  if (msg.contentScriptQuery === 'postGoogleChatUserAuth') {
    postGoogleChatUserAuth(msg.clientId, msg.clientSecret, msg.spaceId, msg.messageText, sendResponse);
    return true;
  }

  if (msg.contentScriptQuery === 'postGoogleChatUserAuthBatch') {
    postGoogleChatUserAuthBatch(msg.clientId, msg.clientSecret, msg.spaceIds, msg.messageText, sendResponse);
    return true;
  }

  if (msg.contentScriptQuery === 'disconnectGoogleChat') {
    loadTokenData().then((stored) => {
      clearTokenStorage();
      const token = stored._gchatAccessToken;
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

  if (msg.contentScriptQuery === 'checkGoogleChatAuth') {
    checkGoogleChatAuth(msg.clientId, msg.clientSecret, sendResponse);
    return true;
  }

  if (msg.contentScriptQuery === 'connectGoogleChat') {
    authorizeWithCodeFlow(msg.clientId, msg.clientSecret)
      .then(() => {
        sendResponse({ 'status': 'connected' });
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

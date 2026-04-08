const applySlackOptions = () => {
  const slackEnabled = document.getElementById('slackEnabled').checked,
        slackChannel = document.getElementById('slackChannel').value,
        slackClockInMessage = document.getElementById('slackClockInMessage').value,
        slackClockOutMessage = document.getElementById('slackClockOutMessage').value,
        slackTakeABreakMessage = document.getElementById('slackTakeABreakMessage').value,
        slackBreakIsOverMessage = document.getElementById('slackBreakIsOverMessage').value,
        slackApiType = document.querySelector('[name=slackApiType]:checked').value,
        slackToken = document.getElementById('slackToken').value,
        slackWebHooksUrl = document.getElementById('slackWebHooksUrl').value;

  chrome.storage.sync.set({
    slackEnabled: slackEnabled,
    slackChannel: slackChannel,
    slackClockInMessage: slackClockInMessage,
    slackClockOutMessage: slackClockOutMessage,
    slackTakeABreakMessage: slackTakeABreakMessage,
    slackBreakIsOverMessage: slackBreakIsOverMessage,
    slackApiType: slackApiType,
    slackToken: slackToken,
    slackWebHooksUrl: slackWebHooksUrl
  }, () => {
    const button = document.getElementById('slackApply');
    button.classList.add("is-loading")
    setTimeout(() => {
      button.classList.remove("is-loading")
    }, 750);
  });

  if(!slackEnabled){
    alert('有効にするチェックが入っていません。');
  }
}

const applySlackStatusOptions = () => {
  const slackStatusEnabled = document.getElementById('slackStatusEnabled').checked,
        slackClockInStatusEmoji = document.getElementById('slackClockInStatusEmoji').value,
        slackClockInStatusText = document.getElementById('slackClockInStatusText').value,
        slackClockOutStatusEmoji = document.getElementById('slackClockOutStatusEmoji').value,
        slackClockOutStatusText = document.getElementById('slackClockOutStatusText').value,
        slackTakeABreakStatusEmoji = document.getElementById('slackTakeABreakStatusEmoji').value,
        slackTakeABreakStatusText = document.getElementById('slackTakeABreakStatusText').value,
        slackStatusToken = document.getElementById('slackStatusToken').value;

  chrome.storage.sync.set({
    slackStatusEnabled: slackStatusEnabled,
    slackClockInStatusEmoji: slackClockInStatusEmoji,
    slackClockInStatusText: slackClockInStatusText,
    slackClockOutStatusEmoji: slackClockOutStatusEmoji,
    slackClockOutStatusText: slackClockOutStatusText,
    slackTakeABreakStatusEmoji: slackTakeABreakStatusEmoji,
    slackTakeABreakStatusText: slackTakeABreakStatusText,
    slackStatusToken: slackStatusToken,
  }, () => {
    const button = document.getElementById('slackStatusApply');
    button.classList.add("is-loading")
    setTimeout(() => {
      button.classList.remove("is-loading")
    }, 750);
  });

  if(!slackStatusEnabled){
    alert('有効にするチェックが入っていません。');
  }

}

const applyGoogleChatOptions = () => {
  const googleChatEnabled = document.getElementById('googleChatEnabled').checked,
        googleChatWebhooksUrl = document.getElementById('googleChatWebhooksUrl').value,
        googleChatClockInMessage = document.getElementById('googleChatClockInMessage').value,
        googleChatClockOutMessage = document.getElementById('googleChatClockOutMessage').value,
        googleChatTakeABreakMessage = document.getElementById('googleChatTakeABreakMessage').value,
        googleChatBreakIsOverMessage = document.getElementById('googleChatBreakIsOverMessage').value;

  chrome.storage.sync.set({
    googleChatEnabled: googleChatEnabled,
    googleChatWebhooksUrl: googleChatWebhooksUrl,
    googleChatClockInMessage: googleChatClockInMessage,
    googleChatClockOutMessage: googleChatClockOutMessage,
    googleChatTakeABreakMessage: googleChatTakeABreakMessage,
    googleChatBreakIsOverMessage: googleChatBreakIsOverMessage
  }, () => {
    const button = document.getElementById('googleChatApply');
    button.classList.add("is-loading")
    setTimeout(() => {
      button.classList.remove("is-loading")
    }, 750);
  });

  if(!googleChatEnabled){
    alert('有効にするチェックが入っていません。');
  }
}

const applyGoogleChatUserOptions = () => {
  const googleChatUserEnabled = document.getElementById('googleChatUserEnabled').checked,
        googleChatOAuthClientId = document.getElementById('googleChatOAuthClientId').value,
        googleChatOAuthClientSecret = document.getElementById('googleChatOAuthClientSecret').value,
        googleChatUserSpace = document.getElementById('googleChatUserSpace').value,
        googleChatUserClockInMessage = document.getElementById('googleChatUserClockInMessage').value,
        googleChatUserClockOutMessage = document.getElementById('googleChatUserClockOutMessage').value,
        googleChatUserTakeABreakMessage = document.getElementById('googleChatUserTakeABreakMessage').value,
        googleChatUserBreakIsOverMessage = document.getElementById('googleChatUserBreakIsOverMessage').value;

  chrome.storage.sync.set({
    googleChatUserEnabled: googleChatUserEnabled,
    googleChatOAuthClientId: googleChatOAuthClientId,
    googleChatOAuthClientSecret: googleChatOAuthClientSecret,
    googleChatUserSpace: googleChatUserSpace,
    googleChatUserClockInMessage: googleChatUserClockInMessage,
    googleChatUserClockOutMessage: googleChatUserClockOutMessage,
    googleChatUserTakeABreakMessage: googleChatUserTakeABreakMessage,
    googleChatUserBreakIsOverMessage: googleChatUserBreakIsOverMessage
  }, () => {
    const button = document.getElementById('googleChatUserApply');
    button.classList.add("is-loading")
    setTimeout(() => {
      button.classList.remove("is-loading")
    }, 750);
  });

  if(!googleChatUserEnabled){
    alert('有効にするチェックが入っていません。');
  }
}

const restoreOptions = () => {
  chrome.storage.sync.get([
    "debuggable",

    // Slack Message
    "slackEnabled",
    "slackChannel",
    "slackClockInMessage",
    "slackClockOutMessage",
    "slackTakeABreakMessage",
    "slackBreakIsOverMessage",
    "slackApiType",
    "slackToken",
    "slackWebHooksUrl",

    // Slack Status
    "slackStatusEnabled",
    "slackClockInStatusEmoji",
    "slackClockInStatusText",
    "slackClockOutStatusEmoji",
    "slackClockOutStatusText",
    "slackTakeABreakStatusEmoji",
    "slackTakeABreakStatusText",
    "slackStatusToken",

    // Google Chat Webhook
    "googleChatEnabled",
    "googleChatWebhooksUrl",
    "googleChatClockInMessage",
    "googleChatClockOutMessage",
    "googleChatTakeABreakMessage",
    "googleChatBreakIsOverMessage",

    // Google Chat ユーザー認証
    "googleChatUserEnabled",
    "googleChatOAuthClientId",
    "googleChatOAuthClientSecret",
    "googleChatUserSpace",
    "googleChatUserClockInMessage",
    "googleChatUserClockOutMessage",
    "googleChatUserTakeABreakMessage",
    "googleChatUserBreakIsOverMessage",

    // KING OF TIME Domain
    "s2Selected",
    "s3Selected",
    "s4Selected",

    // KING OF TIME Authentication
    "samlSelected",

    // Open in new tab
    "openInNewTab"
  ], (items) => {
    document.getElementById('debuggable').checked = items.debuggable;

    document.getElementById('slackEnabled').checked = items.slackEnabled;
    document.getElementById('slackChannel').value = items.slackChannel ? items.slackChannel : "";
    document.getElementById('slackClockInMessage').value = items.slackClockInMessage ? items.slackClockInMessage : "";
    document.getElementById('slackClockOutMessage').value = items.slackClockOutMessage ? items.slackClockOutMessage: "";
    document.getElementById('slackTakeABreakMessage').value = items.slackTakeABreakMessage ? items.slackTakeABreakMessage : "";
    document.getElementById('slackBreakIsOverMessage').value = items.slackBreakIsOverMessage ? items.slackBreakIsOverMessage: "";
    items.slackApiType !== 'asUser' ? document.querySelector('[name=slackApiType][value=IncomingWebHooks]').checked = true : document.querySelector('[name=slackApiType][value=asUser]').checked = true
    document.getElementById('slackToken').value = items.slackToken ? items.slackToken : "";
    document.getElementById('slackWebHooksUrl').value = items.slackWebHooksUrl ? items.slackWebHooksUrl : "";

    document.getElementById('slackStatusEnabled').checked = items.slackStatusEnabled;
    document.getElementById('slackClockInStatusEmoji').value = items.slackClockInStatusEmoji ? items.slackClockInStatusEmoji : "";
    document.getElementById('slackClockInStatusText').value = items.slackClockInStatusText ? items.slackClockInStatusText : "";
    document.getElementById('slackClockOutStatusEmoji').value = items.slackClockOutStatusEmoji ? items.slackClockOutStatusEmoji: "";
    document.getElementById('slackClockOutStatusText').value = items.slackClockOutStatusText ? items.slackClockOutStatusText: "";
    document.getElementById('slackTakeABreakStatusEmoji').value = items.slackTakeABreakStatusEmoji ? items.slackTakeABreakStatusEmoji: "";
    document.getElementById('slackTakeABreakStatusText').value = items.slackTakeABreakStatusText ? items.slackTakeABreakStatusText: "";
    document.getElementById('slackStatusToken').value = items.slackStatusToken ? items.slackStatusToken: "";

    document.getElementById('googleChatEnabled').checked = items.googleChatEnabled;
    document.getElementById('googleChatWebhooksUrl').value = items.googleChatWebhooksUrl ? items.googleChatWebhooksUrl : "";
    document.getElementById('googleChatClockInMessage').value = items.googleChatClockInMessage ? items.googleChatClockInMessage : "";
    document.getElementById('googleChatClockOutMessage').value = items.googleChatClockOutMessage ? items.googleChatClockOutMessage : "";
    document.getElementById('googleChatTakeABreakMessage').value = items.googleChatTakeABreakMessage ? items.googleChatTakeABreakMessage : "";
    document.getElementById('googleChatBreakIsOverMessage').value = items.googleChatBreakIsOverMessage ? items.googleChatBreakIsOverMessage : "";

    document.getElementById('googleChatUserEnabled').checked = items.googleChatUserEnabled;
    document.getElementById('googleChatOAuthClientId').value = items.googleChatOAuthClientId ? items.googleChatOAuthClientId : "";
    document.getElementById('googleChatOAuthClientSecret').value = items.googleChatOAuthClientSecret ? items.googleChatOAuthClientSecret : "";
    document.getElementById('googleChatUserSpace').value = items.googleChatUserSpace ? items.googleChatUserSpace : "";
    document.getElementById('googleChatUserClockInMessage').value = items.googleChatUserClockInMessage ? items.googleChatUserClockInMessage : "";
    document.getElementById('googleChatUserClockOutMessage').value = items.googleChatUserClockOutMessage ? items.googleChatUserClockOutMessage : "";
    document.getElementById('googleChatUserTakeABreakMessage').value = items.googleChatUserTakeABreakMessage ? items.googleChatUserTakeABreakMessage : "";
    document.getElementById('googleChatUserBreakIsOverMessage').value = items.googleChatUserBreakIsOverMessage ? items.googleChatUserBreakIsOverMessage : "";

    // 認証状態チェック
    if (items.googleChatOAuthClientId && items.googleChatOAuthClientSecret) {
      chrome.runtime.sendMessage(
        { contentScriptQuery: 'checkGoogleChatAuth', clientId: items.googleChatOAuthClientId, clientSecret: items.googleChatOAuthClientSecret },
        (response) => {
          if (response && response.status === 'connected') {
            updateGoogleChatUserAuthUI(true);
          }
        }
      );
    }

    document.getElementById('s2Selected').checked = items.s2Selected || (!items.s3Selected && !items.s4Selected);
    document.getElementById('s3Selected').checked = items.s3Selected;
    document.getElementById('s4Selected').checked = items.s4Selected;

    document.getElementById('accountSelected').checked = !items.samlSelected;
    document.getElementById('samlSelected').checked = items.samlSelected;

    document.getElementById('openInPopupSelected').checked = !items.openInNewTab;
    document.getElementById('openInNewTabSelected').checked = items.openInNewTab;
  });
}

// Google Chatユーザー認証UIの状態更新
const updateGoogleChatUserAuthUI = (connected) => {
  const statusEl = document.getElementById('googleChatUserAuthStatus');
  const connectBtn = document.getElementById('googleChatUserConnect');
  const disconnectBtn = document.getElementById('googleChatUserDisconnect');

  if (connected) {
    statusEl.textContent = '接続済み';
    statusEl.className = 'tag is-success';
    connectBtn.style.display = 'none';
    disconnectBtn.style.display = '';
  } else {
    statusEl.textContent = '未接続';
    statusEl.className = 'tag is-light';
    connectBtn.style.display = '';
    disconnectBtn.style.display = 'none';
  }
};

const postToSlack = () => {
  const slackChannel = document.getElementById('slackChannel').value,
        slackClockInMessage = document.getElementById('slackClockInMessage').value,
        slackApiType = document.querySelector('[name=slackApiType]:checked').value,
        slackToken = document.getElementById('slackToken').value,
        slackWebHooksUrl = document.getElementById('slackWebHooksUrl').value;

  if (slackApiType === 'asUser') {
    const slackTokens = slackToken.split(' '); // Multiple workspaces post support
    const slackChannels = slackChannel.split(' ');  // For example, #ch1 #ch2 #ch3
    for (let i = 0; i < slackChannels.length; i++) {
      post('https://slack.com/api/chat.postMessage',
        {
          'Content-Type': 'application/json; charset=utf-8',
          'Access-Control-Allow-Origin': '*',
          'Authorization': 'Bearer ' + (slackTokens.length > 1 ? slackTokens[i] : slackTokens[0])
        },
        {
          'channel': slackChannels[i],
          'text': slackClockInMessage ? slackClockInMessage : 'テスト',
          'as_user': true
        }
      );
    }
  } else {
    const slackWebHooksUrls = slackWebHooksUrl.split(' '); // Multiple workspaces post support
    const slackChannels = slackChannel.split(' '); // For example, #ch1 #ch2 #ch3
    for (let i = 0; i < slackChannels.length; i++) {
      post(slackWebHooksUrls[i],
        {
          'Content-Type': 'application/json; charset=utf-8',
          'Access-Control-Allow-Origin': '*'
        },
        {
          'channel': slackChannels[i],
          'text': slackClockInMessage ? slackClockInMessage : 'テスト'
        }
      );
    }
  }
}

const changeStatus = () => {
  const slackClockInStatusEmoji = document.getElementById('slackClockInStatusEmoji').value,
        slackClockInStatusText = document.getElementById('slackClockInStatusText').value,
        slackStatusToken = document.getElementById('slackStatusToken').value;

  const slackStatusTokens = slackStatusToken.split(' '); // Multiple workspaces post support
  for(let i = 0; i < slackStatusTokens.length; i++) {
    post('https://slack.com/api/users.profile.set',
    {
      'Content-Type': 'application/json; charset=utf-8',
      'Access-Control-Allow-Origin': '*',
      'Authorization': 'Bearer ' + slackStatusTokens[i]
    },
    {
      'profile': {
        'status_emoji': slackClockInStatusEmoji !== '' ? slackClockInStatusEmoji : ':office:',
        'status_text': slackClockInStatusText !== '' ? slackClockInStatusText : '仕事中',
        'status_expiration': 0
      }
    },
    'slackStatusTest');
  }
}

const postToGoogleChat = () => {
  const googleChatWebhooksUrl = document.getElementById('googleChatWebhooksUrl').value,
        googleChatClockInMessage = document.getElementById('googleChatClockInMessage').value;

  const webhookUrls = googleChatWebhooksUrl.split(' ').filter(u => u.length > 0);
  for (let i = 0; i < webhookUrls.length; i++) {
    post(webhookUrls[i],
      {
        'Content-Type': 'application/json; charset=utf-8',
      },
      {
        'text': googleChatClockInMessage ? googleChatClockInMessage : 'テスト'
      },
      'googleChatTest'
    );
  }
}

const postToGoogleChatUser = () => {
  const clientId = document.getElementById('googleChatOAuthClientId').value,
        clientSecret = document.getElementById('googleChatOAuthClientSecret').value,
        spaceId = document.getElementById('googleChatUserSpace').value,
        message = document.getElementById('googleChatUserClockInMessage').value;

  if (!clientId || !clientSecret || !spaceId) {
    console.error('OAuth Client ID、Client Secret、スペースIDを入力してください');
    return;
  }

  const button = document.getElementById('googleChatUserTest');
  button.classList.add('is-loading');

  const spaceIds = spaceId.split(' ').filter(s => s.length > 0);
  chrome.runtime.sendMessage(
    {
      contentScriptQuery: 'postGoogleChatUserAuthBatch',
      clientId: clientId,
      clientSecret: clientSecret,
      spaceIds: spaceIds,
      messageText: message || 'テスト',
    },
    (response) => {
      button.classList.remove('is-loading');
      if (response && (response.status === 'failed' || response.status === 'partial_failure')) {
        console.error('Google Chatユーザー認証投稿失敗:', response);
      } else {
        console.log('Google Chatユーザー認証投稿成功:', response);
      }
    }
  );
}

const connectGoogleChat = () => {
  const clientId = document.getElementById('googleChatOAuthClientId').value;
  const clientSecret = document.getElementById('googleChatOAuthClientSecret').value;
  if (!clientId || !clientSecret) {
    console.error('OAuth Client IDとClient Secretを入力してください');
    return;
  }

  const connectBtn = document.getElementById('googleChatUserConnect');
  connectBtn.classList.add('is-loading');

  chrome.runtime.sendMessage(
    { contentScriptQuery: 'connectGoogleChat', clientId: clientId, clientSecret: clientSecret },
    (response) => {
      connectBtn.classList.remove('is-loading');
      if (response && response.status === 'connected') {
        updateGoogleChatUserAuthUI(true);
      } else {
        console.error('Google接続失敗:', response);
        updateGoogleChatUserAuthUI(false);
      }
    }
  );
}

const disconnectGoogleChat = () => {
  const clientId = document.getElementById('googleChatOAuthClientId').value;
  const disconnectBtn = document.getElementById('googleChatUserDisconnect');
  disconnectBtn.classList.add('is-loading');

  // background側でトークンを無効化
  chrome.runtime.sendMessage(
    { contentScriptQuery: 'disconnectGoogleChat', clientId: clientId },
    () => {
      disconnectBtn.classList.remove('is-loading');
      // 有効フラグをOFFにして保存（誤送信防止）
      document.getElementById('googleChatUserEnabled').checked = false;
      chrome.storage.sync.set({ googleChatUserEnabled: false });
      updateGoogleChatUserAuthUI(false);
    }
  );
}

const post = (endpoint, headers, payload, buttonId = 'slackTest') => {
  const button = document.getElementById(buttonId);
  button.classList.add('is-loading');
  fetch(endpoint, {
    method: 'POST',
    headers: headers,
    body: JSON.stringify(payload)
  })
  .then(res => res.json())
  .then(console.log)
  .catch(console.error)
  .finally(() => {
    button.classList.remove('is-loading');
  });
};

document.addEventListener('DOMContentLoaded', restoreOptions);

document.getElementById('slackApply').addEventListener('click', applySlackOptions);
document.getElementById('slackTest').addEventListener('click', postToSlack);

document.getElementById('slackStatusApply').addEventListener('click', applySlackStatusOptions);
document.getElementById('slackStatusTest').addEventListener('click', changeStatus);

document.getElementById('googleChatApply').addEventListener('click', applyGoogleChatOptions);
document.getElementById('googleChatTest').addEventListener('click', postToGoogleChat);

document.getElementById('googleChatUserApply').addEventListener('click', applyGoogleChatUserOptions);
document.getElementById('googleChatUserTest').addEventListener('click', postToGoogleChatUser);
document.getElementById('googleChatUserConnect').addEventListener('click', connectGoogleChat);
document.getElementById('googleChatUserDisconnect').addEventListener('click', disconnectGoogleChat);

document.getElementById('s2Selected').addEventListener('change', () => {
  chrome.storage.sync.set({s2Selected: true, s3Selected: false, s4Selected: false});
});

document.getElementById('s3Selected').addEventListener('change', () => {
  chrome.storage.sync.set({s2Selected: false, s3Selected: true, s4Selected: false});
});

document.getElementById('s4Selected').addEventListener('change', () => {
  chrome.storage.sync.set({s2Selected: false, s3Selected: false, s4Selected: true});
});

document.getElementById('accountSelected').addEventListener('change', () => {
  chrome.storage.sync.set({samlSelected: false});
});

document.getElementById('samlSelected').addEventListener('change', () => {
  chrome.storage.sync.set({samlSelected: true});
});

document.getElementById('openInPopupSelected').addEventListener('change', () => {
  chrome.storage.sync.set({openInNewTab: false});
  chrome.action.setPopup({ popup: 'src/browser_action/browser_action.html' });
});

document.getElementById('openInNewTabSelected').addEventListener('change', () => {
  chrome.storage.sync.set({openInNewTab: true});
  chrome.action.setPopup({ popup: '' });
});

document.getElementById('debuggable').addEventListener('click', () => {
  chrome.storage.sync.set({debuggable: document.getElementById('debuggable').checked});
});

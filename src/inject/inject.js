(() => {
  const CLOCK_IN = 'clockIn',
        CLOCK_OUT = 'clockOut',
        TAKE_A_BREAK = 'takeABreak',
        BREAK_IS_OVER = 'breakIsOver';

  const setting = JSON.parse(localStorage.getItem('PARSONAL_BROWSER_RECORDER@SETTING'))

  if (!setting) {
    console.log('Not Logged In. Please log in and reload this page.')
    chrome.runtime.sendMessage({ contentScriptQuery: 'NOT_LOGGED_IN' });
    return;
  }

  let debuggable = false;

  // Slack Message
  let slackEnabled = false,
      slackChannel = '',
      slackClockInMessage = '',
      slackClockOutMessage = '',
      slackTakeABreakMessage = '',
      slackBreakIsOverMessage = '',
      slackApiType = 'asUser',
      slackToken = '',
      slackWebHooksUrl = '';

  // Slack Status
  let slackStatusEnabled = false,
      slackClockInStatusEmoji = '',
      slackClockInStatusText = '',
      slackClockOutStatusEmoji = '',
      slackClockOutStatusText = '',
      slackTakeABreakStatusEmoji = '',
      slackTakeABreakStatusText = '',
      slackStatusToken = '';

  // Google Chat Webhook
  let googleChatEnabled = false,
      googleChatWebhooksUrl = '',
      googleChatClockInMessage = '',
      googleChatClockOutMessage = '',
      googleChatTakeABreakMessage = '',
      googleChatBreakIsOverMessage = '';

  // Google Chat ユーザー認証
  let googleChatUserEnabled = false,
      googleChatUserSpace = '',
      googleChatUserClockInMessage = '',
      googleChatUserClockOutMessage = '',
      googleChatUserTakeABreakMessage = '',
      googleChatUserBreakIsOverMessage = '',
      googleChatOAuthClientId = '',
      googleChatOAuthClientSecret = '';

  const now = new Date(),
      today = [now.getFullYear(), now.getMonth() + 1, now.getDate()].map(d => d.toString().padStart(2, '0')).join(''),
      todayHistoryItem = localStorage.getItem('PARSONAL_BROWSER_RECORDER@RECORD_HISTORY_' + setting.user.user_token),
      todayHistories = JSON.parse(todayHistoryItem ? todayHistoryItem : '[]').filter(i => i.send_timestamp.startsWith(today)),
      isClockedIn = todayHistories.some(h=>h.name === '出勤'),
      isClockedOut = todayHistories.some(h=>h.name === '退勤'),
      isBreakStart = todayHistories[0]?.name === '休始';

  // 設定値の読み込みが完了してからボタン検出・ハンドラ登録を行う
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
    "googleChatUserSpace",
    "googleChatUserClockInMessage",
    "googleChatUserClockOutMessage",
    "googleChatUserTakeABreakMessage",
    "googleChatUserBreakIsOverMessage",
    "googleChatOAuthClientId",
    "googleChatOAuthClientSecret"
  ], (items) => {
    debuggable = items.debuggable;

    // Slack Message
    slackEnabled = items.slackEnabled;
    slackChannel = items.slackChannel;
    slackClockInMessage = items.slackClockInMessage;
    slackClockOutMessage = items.slackClockOutMessage;
    slackTakeABreakMessage = items.slackTakeABreakMessage;
    slackBreakIsOverMessage = items.slackBreakIsOverMessage;
    slackToken = items.slackToken;
    slackWebhooksUrl = items.slackWebhooksUrl;

    // Slack Status
    slackStatusEnabled = items.slackStatusEnabled;
    slackClockInStatusEmoji = items.slackClockInStatusEmoji;
    slackClockInStatusText = items.slackClockInStatusText;
    slackClockOutStatusEmoji = items.slackClockOutStatusEmoji;
    slackClockOutStatusText = items.slackClockOutStatusText;
    slackTakeABreakStatusEmoji = items.slackTakeABreakStatusEmoji;
    slackTakeABreakStatusText = items.slackTakeABreakStatusText;
    slackStatusToken = items.slackStatusToken;

    // Google Chat Webhook
    googleChatEnabled = items.googleChatEnabled;
    googleChatWebhooksUrl = items.googleChatWebhooksUrl;
    googleChatClockInMessage = items.googleChatClockInMessage;
    googleChatClockOutMessage = items.googleChatClockOutMessage;
    googleChatTakeABreakMessage = items.googleChatTakeABreakMessage;
    googleChatBreakIsOverMessage = items.googleChatBreakIsOverMessage;

    // Google Chat ユーザー認証
    googleChatUserEnabled = items.googleChatUserEnabled;
    googleChatUserSpace = items.googleChatUserSpace || '';
    googleChatUserClockInMessage = items.googleChatUserClockInMessage || '';
    googleChatUserClockOutMessage = items.googleChatUserClockOutMessage || '';
    googleChatUserTakeABreakMessage = items.googleChatUserTakeABreakMessage || '';
    googleChatUserBreakIsOverMessage = items.googleChatUserBreakIsOverMessage || '';
    googleChatOAuthClientId = items.googleChatOAuthClientId || '';
    googleChatOAuthClientSecret = items.googleChatOAuthClientSecret || '';

    // 設定読み込み完了後にボタン待ちループを開始
    let intervalCount = 0;
    const interval = setInterval(() => {
      const clockInButton = document.querySelector('.record-clock-in'),
            clockOutButton = document.querySelector('.record-clock-out'),
            breakStartButton = [...document.querySelectorAll(".record-btn-inner")].filter(v=>v.textContent==="休始")[0],
            breakFinishButton = [...document.querySelectorAll(".record-btn-inner")].filter(v=>v.textContent==="休終")[0];

      if (!(clockInButton && clockOutButton)) {
        if (++intervalCount > 30) {
          clearInterval(interval);
        }
        return;
      }

      clearInterval(interval);

      if (isClockedIn) clockInButton.style.opacity = 0.3;
      if (isClockedOut) clockOutButton.style.opacity = 0.3;

      if (breakStartButton && breakFinishButton) {
        if (isBreakStart) clockOutButton.style.opacity = 0.3;
        if (!isClockedIn || isClockedOut || (isClockedIn && isBreakStart) ) breakStartButton.style.opacity = 0.3;
        if (!isBreakStart) breakFinishButton.style.opacity = 0.3;
      }

      const buttons = setting.timerecorder.record_button,
            clockInButtonId = buttons.filter(b => b.mark === '1')[0].id,
            clockOutButtonId = buttons.filter(b => b.mark === '2')[0].id,
            breakButtons = buttons.filter(b => b.mark === '0');

      if (slackEnabled || slackStatusEnabled || googleChatEnabled || googleChatUserEnabled) {
        document.getElementById('record_' + clockInButtonId).addEventListener('click', clockIn, false);
        document.getElementById('record_' + clockOutButtonId).addEventListener('click', clockOut, false);
        console.log('Content Scripts is injected by KoT Chrome Assistant.');

        if (debuggable) {
          document.querySelector('footer').innerHTML = '<button id="testClockIn">出勤テスト</button><button id="testClockOut">退勤テスト</button><button id="testTakeABreak">休始テスト</button><button id="testBreakIsOver">休終テスト</button>'
          document.getElementById('testClockIn').addEventListener('click', clockIn, false);
          document.getElementById('testClockOut').addEventListener('click', clockOut, false);
        }

        if (breakButtons[0]) {
          const takeABreakButtonId = breakButtons[0].id,
                breakIsOverButtonId = breakButtons[1].id;
          document.getElementById('record_' + takeABreakButtonId).addEventListener('click', takeABreak, false);
          document.getElementById('record_' + breakIsOverButtonId).addEventListener('click', breakIsOver, false);
          if (debuggable) {
            document.getElementById('testTakeABreak').addEventListener('click', takeABreak, false);
            document.getElementById('testBreakIsOver').addEventListener('click', breakIsOver, false);
          }
        }
      }
    }, 100);
  });

  const clockIn = () => {
    postSlackMessage(slackClockInMessage);
    postGoogleChatMessage(googleChatClockInMessage);
    postGoogleChatUserMessage(googleChatUserClockInMessage);
    changeStatus(CLOCK_IN)
  };

  const clockOut = () => {
    postSlackMessage(slackClockOutMessage);
    postGoogleChatMessage(googleChatClockOutMessage);
    postGoogleChatUserMessage(googleChatUserClockOutMessage);
    changeStatus(CLOCK_OUT)
  };

  const takeABreak = () => {
    postSlackMessage(slackTakeABreakMessage);
    postGoogleChatMessage(googleChatTakeABreakMessage);
    postGoogleChatUserMessage(googleChatUserTakeABreakMessage);
    changeStatus(TAKE_A_BREAK)
  };

  const breakIsOver = () => {
    postSlackMessage(slackBreakIsOverMessage);
    postGoogleChatMessage(googleChatBreakIsOverMessage);
    postGoogleChatUserMessage(googleChatUserBreakIsOverMessage);
    changeStatus(BREAK_IS_OVER)
  };

  const postSlackMessage = (message) => {
    if (!slackEnabled || !message || message.length === 0) return;

    if (slackApiType === 'asUser') {
      const slackTokens = slackToken.split(' '); // Multiple workspaces post support
      const slackChannels = slackChannel.split(' '); // Multiple channels post support
      for (let i = 0; i < slackChannels.length; i++) {
        chrome.runtime.sendMessage(
          {
            contentScriptQuery: 'postMessage',
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Access-Control-Allow-Origin': '*',
              'Authorization': 'Bearer ' + (slackTokens.length > 1 ? slackTokens[i] : slackTokens[0])
            },
            body: JSON.stringify({
              'channel': slackChannels[i],
              'text': message,
              'as_user': true
            }),
            endpoint: 'https://slack.com/api/chat.postMessage',
          }
        );
      }
    } else {
       const slackWebHooksUrls = slackWebHooksUrl.split(' '); // Multiple workspaces post support
       const slackChannels = slackChannel.split(' '); // Multiple channels post support
       for(let i = 0; i < slackChannels.length; i++) {
        chrome.runtime.sendMessage(
          {
            contentScriptQuery: 'postMessage',
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
              'channel': slackChannels[i],
              'text': message
            }),
            endpoint: slackWebHooksUrls[i],
          }
        );
       }
    }
  };

  const postGoogleChatMessage = (message) => {
    if (!googleChatEnabled || !message || message.length === 0) return;

    const webhookUrls = googleChatWebhooksUrl.split(' ').filter(u => u.length > 0);
    for (let i = 0; i < webhookUrls.length; i++) {
      chrome.runtime.sendMessage(
        {
          contentScriptQuery: 'postMessage',
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: JSON.stringify({
            'text': message
          }),
          endpoint: webhookUrls[i],
        }
      );
    }
  };

  const postGoogleChatUserMessage = (message) => {
    if (!googleChatUserEnabled || !message || message.length === 0) return;
    if (!googleChatOAuthClientId || !googleChatUserSpace) return;

    const spaceIds = googleChatUserSpace.split(' ').filter(s => s.length > 0);
    for (let i = 0; i < spaceIds.length; i++) {
      chrome.runtime.sendMessage(
        {
          contentScriptQuery: 'postGoogleChatUserAuth',
          clientId: googleChatOAuthClientId,
          clientSecret: googleChatOAuthClientSecret,
          spaceId: spaceIds[i],
          messageText: message,
        }
      );
    }
  };

  const changeStatus = (status) => {
    if (!slackStatusEnabled) return;

    let statusEmoji = '', statusText = ''
    if (status === CLOCK_IN) {
      statusEmoji = slackClockInStatusEmoji;
      statusText = slackClockInStatusText;
    } else if (status === CLOCK_OUT) {
      statusEmoji = slackClockOutStatusEmoji;
      statusText = slackClockOutStatusText;
    } else if (status === TAKE_A_BREAK) {
      statusEmoji = slackTakeABreakStatusEmoji;
      statusText = slackTakeABreakStatusText;
    } else if (status === BREAK_IS_OVER) {
      statusEmoji = slackClockInStatusEmoji;
      statusText = slackClockInStatusText;
    }

    const slackStatusTokens = slackStatusToken.split(' '); // Multiple workspaces post support
    for (let i = 0; i < slackStatusTokens.length; i++) {
      chrome.runtime.sendMessage(
        {
          contentScriptQuery: 'changeStatus',
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Access-Control-Allow-Origin': '*',
            'Authorization': 'Bearer ' + slackStatusTokens[i]
          },
          body: JSON.stringify({
            'profile': {
              'status_emoji': statusEmoji,
              'status_text': statusText,
              'status_expiration': 0
            }
          }),
          endpoint: 'https://slack.com/api/users.profile.set',
        }
      );
    }
  }
})();

// ==UserScript==
// @name         Campus Wi-Fi Auto Login (configurable)
// @namespace    local.campus.wifi.autologin
// @version      1.0.0
// @description  使用浏览器已保存的密码，按学校配置自动选择运营商并提交校园网认证
// @match        http://portal.jxnu.edu.cn/*
// @match        http://172.16.8.8/*
// @match        http://172.16.1.2/*
// @match        http://172.17.1.2/*
// @run-at       document-idle
// @grant        none
// ==/UserScript==

(function () {
    'use strict';

    // 新增学校时只需增加 host 配置；不要把账号或密码写在这里。
    const PROFILES = {
        'portal.jxnu.edu.cn': {
            operator: '@ctcc',
            operatorText: '电信',
            username: '#username',
            password: '#password',
            operatorSelect: '#domain',
            login: '#login-account, #login, .btn-login',
            protocol: '#protocol'
        },
        '172.16.8.8': {
            operator: '@ctcc',
            operatorText: '电信',
            username: '#username',
            password: '#password',
            operatorSelect: '#domain',
            login: '#login-account, #login, .btn-login',
            protocol: '#protocol'
        },
        '172.16.1.2': {
            operator: '@ctcc',
            operatorText: '电信',
            username: '#username',
            password: '#password',
            operatorSelect: '#domain',
            login: '#login-account, #login, .btn-login',
            protocol: '#protocol'
        },
        '172.17.1.2': {
            operator: '@ctcc',
            operatorText: '电信',
            username: '#username',
            password: '#password',
            operatorSelect: '#domain',
            login: '#login-account, #login, .btn-login',
            protocol: '#protocol'
        }
    };

    const profile = PROFILES[window.location.hostname];
    if (!profile) return;

    const POLL_MS = 300;
    const MAX_WAIT_MS = 60_000;
    const startedAt = Date.now();
    let submitted = false;

    function isSuccessPage() {
        return /srun_portal_success/i.test(window.location.pathname);
    }

    function fireChange(element) {
        element.dispatchEvent(new Event('input', { bubbles: true }));
        element.dispatchEvent(new Event('change', { bubbles: true }));
    }

    function chooseOperator() {
        const select = document.querySelector(profile.operatorSelect);
        if (!select) return false;

        const option = Array.from(select.options).find((item) =>
            item.value === profile.operator ||
            (profile.operatorText && (item.textContent || '').includes(profile.operatorText))
        );
        if (!option) return false;

        if (select.value !== option.value) {
            select.value = option.value;
            fireChange(select);
            return false;
        }
        return true;
    }

    function trySubmit() {
        if (submitted || isSuccessPage()) return;

        const username = document.querySelector(profile.username);
        const password = document.querySelector(profile.password);
        const login = document.querySelector(profile.login);
        const protocol = profile.protocol ? document.querySelector(profile.protocol) : null;
        if (!username || !password || !login) return;

        // 新协议需要人工确认，不替用户作出新的协议同意决定。
        if (protocol && !protocol.checked) return;
        if (!chooseOperator()) return;

        // 等待 Edge 自动填充，绝不提交空账号或空密码。
        if (!username.value.trim() || !password.value) return;
        if (login.disabled || login.getAttribute('aria-disabled') === 'true') return;

        submitted = true;
        login.click();
    }

    const timer = window.setInterval(() => {
        trySubmit();
        if (submitted || Date.now() - startedAt > MAX_WAIT_MS) window.clearInterval(timer);
    }, POLL_MS);

    const observer = new MutationObserver(trySubmit);
    observer.observe(document.documentElement, { childList: true, subtree: true });
    window.setTimeout(() => observer.disconnect(), MAX_WAIT_MS + 2_000);
    trySubmit();
})();

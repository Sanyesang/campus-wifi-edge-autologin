// ==UserScript==
// @name         JXNU jxnu_stu Edge 自动认证
// @namespace    local.jxnu.stu.autologin
// @version      1.0.0
// @description  复用 Edge 已保存的账号密码，自动选择电信并提交江西师大校园网认证
// @match        http://portal.jxnu.edu.cn/*
// @match        http://172.16.8.8/*
// @match        http://172.16.1.2/*
// @run-at       document-idle
// @grant        none
// ==/UserScript==

(function () {
    'use strict';

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

    function chooseTelecom() {
        const select = document.querySelector('#domain');
        if (!select) return false;

        const option = Array.from(select.options).find((item) =>
            item.value === '@ctcc' || /电信/.test(item.textContent || '')
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

        const username = document.querySelector('#username');
        const password = document.querySelector('#password');
        const login = document.querySelector('#login-account, #login, .btn-login');
        const protocol = document.querySelector('#protocol');

        if (!username || !password || !login) return;

        // 不替用户同意新协议；已有协议同意状态由门户自己的脚本恢复。
        if (protocol && !protocol.checked) return;

        const telecomReady = chooseTelecom();
        if (!telecomReady) return;

        // 等待 Edge 的密码管理器自动填充，绝不提交空表单。
        if (!username.value.trim() || !password.value) return;
        if (login.disabled || login.getAttribute('aria-disabled') === 'true') return;

        submitted = true;
        login.click();
    }

    const timer = window.setInterval(() => {
        trySubmit();
        if (submitted || Date.now() - startedAt > MAX_WAIT_MS) {
            window.clearInterval(timer);
        }
    }, POLL_MS);

    const observer = new MutationObserver(trySubmit);
    observer.observe(document.documentElement, { childList: true, subtree: true });
    window.setTimeout(() => observer.disconnect(), MAX_WAIT_MS + 2_000);
    trySubmit();
})();


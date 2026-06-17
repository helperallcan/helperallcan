import assert from 'node:assert/strict';
import test from 'node:test';

import { getAuthLoginErrorMessage } from './auth-errors.ts';

test('auth login errors explain Supabase connection failures', () => {
  assert.equal(
    getAuthLoginErrorMessage(new Error('fetch failed: getaddrinfo ENOTFOUND example.supabase.co')),
    '无法连接 Supabase 项目，请检查项目 URL 是否正确、项目是否暂停或网络是否可用。'
  );
});

test('auth login errors localize common Supabase auth failures', () => {
  assert.equal(getAuthLoginErrorMessage(new Error('Invalid login credentials')), '邮箱或密码不正确。');
  assert.equal(
    getAuthLoginErrorMessage(new Error('Email not confirmed')),
    '邮箱还没有完成验证，请先完成邮箱验证。'
  );
});

test('auth login errors keep unknown provider messages visible', () => {
  assert.equal(getAuthLoginErrorMessage(new Error('Rate limit exceeded')), 'Rate limit exceeded');
});

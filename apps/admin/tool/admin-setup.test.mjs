import assert from 'node:assert/strict';
import test from 'node:test';

import { decodeJwtPayload, readEnvFile, summarizeKey, validateAdminEnv } from './admin-setup.mjs';

function makeJwt(payload) {
  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
  return `${header}.${body}.signature`;
}

const anonKey = makeJwt({ role: 'anon', ref: 'helperdemo' });
const serviceRoleKey = makeJwt({ role: 'service_role', ref: 'helperdemo' });

test('setup check detects key roles and project refs', () => {
  assert.deepEqual(summarizeKey(anonKey), {
    length: anonKey.length,
    present: true,
    jwtLike: true,
    role: 'anon',
    ref: 'helperdemo'
  });
  assert.equal(decodeJwtPayload(serviceRoleKey).role, 'service_role');
});

test('setup check accepts matching Supabase env values', () => {
  const result = validateAdminEnv({
    NEXT_PUBLIC_SUPABASE_URL: 'https://helperdemo.supabase.co',
    NEXT_PUBLIC_SUPABASE_ANON_KEY: anonKey,
    SUPABASE_SERVICE_ROLE_KEY: serviceRoleKey
  });

  assert.deepEqual(result.errors, []);
  assert.deepEqual(result.warnings, []);
});

test('setup check flags missing or wrong service role keys', () => {
  const result = validateAdminEnv({
    NEXT_PUBLIC_SUPABASE_URL: 'https://helperdemo.supabase.co',
    NEXT_PUBLIC_SUPABASE_ANON_KEY: anonKey,
    SUPABASE_SERVICE_ROLE_KEY: 'not-a-jwt-secret'
  });

  assert.equal(result.errors.length, 1);
  assert.match(result.errors[0], /SUPABASE_SERVICE_ROLE_KEY/);
});

test('setup check warns when URL and anon key project refs differ', () => {
  const result = validateAdminEnv({
    NEXT_PUBLIC_SUPABASE_URL: 'https://another-project.supabase.co',
    NEXT_PUBLIC_SUPABASE_ANON_KEY: anonKey,
    SUPABASE_SERVICE_ROLE_KEY: serviceRoleKey
  });

  assert.deepEqual(result.errors, []);
  assert.equal(result.warnings.length, 1);
});

test('setup check parses simple env files without exposing values', () => {
  const parsed = readEnvFile(new URL('./fixtures/admin.env', import.meta.url));

  assert.equal(parsed.NEXT_PUBLIC_SUPABASE_URL, 'https://helperdemo.supabase.co');
  assert.equal(parsed.NEXT_PUBLIC_SUPABASE_ANON_KEY, 'quoted-anon');
  assert.equal(parsed.SUPABASE_SERVICE_ROLE_KEY, 'plain-service');
});

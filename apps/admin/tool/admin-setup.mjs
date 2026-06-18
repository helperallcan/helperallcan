import { existsSync, readFileSync } from 'node:fs';
import dns from 'node:dns/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { createClient } from '@supabase/supabase-js';

const ENV_FILE = path.resolve(process.cwd(), '.env.local');

export function readEnvFile(filePath = ENV_FILE) {
  if (!existsSync(filePath)) {
    throw new Error(`找不到环境变量文件：${filePath}`);
  }

  return Object.fromEntries(
    readFileSync(filePath, 'utf8')
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => line && !line.startsWith('#'))
      .map((line) => {
        const index = line.indexOf('=');
        if (index === -1) return [line, ''];
        const key = line.slice(0, index).trim();
        let value = line.slice(index + 1).trim();

        if (
          (value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))
        ) {
          value = value.slice(1, -1);
        }

        return [key, value];
      })
  );
}

function decodeBase64Url(value) {
  const padded = `${value}${'='.repeat((4 - (value.length % 4)) % 4)}`;
  return Buffer.from(padded.replaceAll('-', '+').replaceAll('_', '/'), 'base64').toString('utf8');
}

export function decodeJwtPayload(value) {
  const parts = value.split('.');
  if (parts.length < 2) return null;

  try {
    return JSON.parse(decodeBase64Url(parts[1]));
  } catch {
    return null;
  }
}

export function summarizeKey(value) {
  const key = value?.trim() ?? '';
  const payload = decodeJwtPayload(key);

  return {
    length: key.length,
    present: key.length > 0,
    jwtLike: key.startsWith('eyJ') && Boolean(payload),
    role: typeof payload?.role === 'string' ? payload.role : null,
    ref: typeof payload?.ref === 'string' ? payload.ref : null
  };
}

export function validateAdminEnv(env) {
  const errors = [];
  const warnings = [];
  let parsedUrl = null;

  if (!env.NEXT_PUBLIC_SUPABASE_URL) {
    errors.push('缺少 NEXT_PUBLIC_SUPABASE_URL。');
  } else {
    try {
      parsedUrl = new URL(env.NEXT_PUBLIC_SUPABASE_URL);
    } catch {
      errors.push('NEXT_PUBLIC_SUPABASE_URL 不是有效 URL。');
    }
  }

  const anonKey = summarizeKey(env.NEXT_PUBLIC_SUPABASE_ANON_KEY);
  const serviceRoleKey = summarizeKey(env.SUPABASE_SERVICE_ROLE_KEY);

  if (!anonKey.present) {
    errors.push('缺少 NEXT_PUBLIC_SUPABASE_ANON_KEY。');
  } else if (!anonKey.jwtLike) {
    errors.push('NEXT_PUBLIC_SUPABASE_ANON_KEY 看起来不是 Supabase JWT key。');
  } else if (anonKey.role !== 'anon') {
    errors.push(`NEXT_PUBLIC_SUPABASE_ANON_KEY 的 role 是 ${anonKey.role ?? '未知'}，应该是 anon。`);
  }

  if (!serviceRoleKey.present) {
    errors.push('缺少 SUPABASE_SERVICE_ROLE_KEY。');
  } else if (!serviceRoleKey.jwtLike) {
    errors.push('SUPABASE_SERVICE_ROLE_KEY 看起来不是 Supabase JWT key，请从 Supabase API Settings 复制 service_role secret。');
  } else if (serviceRoleKey.role !== 'service_role') {
    errors.push(
      `SUPABASE_SERVICE_ROLE_KEY 的 role 是 ${serviceRoleKey.role ?? '未知'}，应该是 service_role。`
    );
  }

  if (anonKey.ref && serviceRoleKey.ref && anonKey.ref !== serviceRoleKey.ref) {
    errors.push('anon key 和 service_role key 属于不同 Supabase 项目。');
  }

  if (parsedUrl?.hostname.endsWith('.supabase.co') && anonKey.ref && !parsedUrl.hostname.startsWith(`${anonKey.ref}.`)) {
    warnings.push('Supabase URL 的项目 ref 和 anon key 里的项目 ref 不一致。');
  }

  return {
    anonKey,
    errors,
    parsedUrl,
    serviceRoleKey,
    warnings
  };
}

function printKeySummary(name, summary) {
  const role = summary.role ? ` role=${summary.role}` : '';
  const ref = summary.ref ? ` ref=${summary.ref}` : '';
  console.log(`${name}: length=${summary.length} jwt=${summary.jwtLike ? 'yes' : 'no'}${role}${ref}`);
}

async function checkDns(hostname) {
  if (hostname === 'localhost' || hostname === '127.0.0.1') return true;

  try {
    await dns.lookup(hostname);
    return true;
  } catch {
    return false;
  }
}

async function checkHealth(url) {
  const response = await fetch(`${url.origin}/auth/v1/health`, {
    signal: AbortSignal.timeout(10000)
  });
  return response.ok;
}

function createAdminClient(env) {
  return createClient(env.NEXT_PUBLIC_SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  });
}

async function findAuthUserByEmail(supabase, email) {
  const normalizedEmail = email.trim().toLowerCase();

  for (let page = 1; page <= 20; page += 1) {
    const { data, error } = await supabase.auth.admin.listUsers({ page, perPage: 100 });
    if (error) throw error;

    const user = data.users.find((item) => item.email?.toLowerCase() === normalizedEmail);
    if (user) return user;
    if (data.users.length < 100) break;
  }

  return null;
}

export async function runCheck(env = readEnvFile()) {
  const result = validateAdminEnv(env);

  console.log('Helper Admin 配置检查');
  console.log('');
  console.log(`NEXT_PUBLIC_SUPABASE_URL: ${env.NEXT_PUBLIC_SUPABASE_URL || '(missing)'}`);
  printKeySummary('NEXT_PUBLIC_SUPABASE_ANON_KEY', result.anonKey);
  printKeySummary('SUPABASE_SERVICE_ROLE_KEY', result.serviceRoleKey);
  console.log('');

  result.warnings.forEach((warning) => console.log(`[WARN] ${warning}`));
  result.errors.forEach((error) => console.log(`[FIX] ${error}`));

  if (!result.parsedUrl) {
    return 1;
  }

  const dnsOk = await checkDns(result.parsedUrl.hostname);
  console.log(`DNS: ${dnsOk ? 'ok' : `failed (${result.parsedUrl.hostname})`}`);
  if (!dnsOk) return 1;

  try {
    const healthOk = await checkHealth(result.parsedUrl);
    console.log(`Supabase Auth health: ${healthOk ? 'ok' : 'failed'}`);
    if (!healthOk) return 1;
  } catch (error) {
    console.log(`Supabase Auth health: failed (${error.message})`);
    return 1;
  }

  if (result.errors.length > 0) {
    return 1;
  }

  try {
    const supabase = createAdminClient(env);
    const { error } = await supabase.auth.admin.listUsers({ page: 1, perPage: 1 });
    if (error) throw error;
    console.log('service_role admin access: ok');
  } catch (error) {
    console.log(`service_role admin access: failed (${error.message})`);
    return 1;
  }

  console.log('');
  console.log('配置可以用于后台登录。');
  return 0;
}

export async function promoteAdmin(email, env = readEnvFile()) {
  if (!email || !email.includes('@')) {
    throw new Error('请提供要升级为管理员的邮箱，例如：npm run admin:promote -- name@example.com');
  }

  const result = validateAdminEnv(env);
  if (result.errors.length > 0) {
    throw new Error(`配置还不能使用：${result.errors.join(' ')}`);
  }

  const supabase = createAdminClient(env);
  const user = await findAuthUserByEmail(supabase, email);
  if (!user) {
    throw new Error('没有找到这个邮箱的 Supabase Auth 用户，请先在 App 注册或在 Supabase Authentication 创建用户。');
  }

  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select('id, display_name, role')
    .eq('id', user.id)
    .maybeSingle();
  if (profileError) throw profileError;

  if (profile) {
    const { error } = await supabase.from('profiles').update({ role: 'admin' }).eq('id', user.id);
    if (error) throw error;
  } else {
    const displayName = user.user_metadata?.display_name ?? user.email?.split('@')[0] ?? '管理员';
    const { error } = await supabase.from('profiles').insert({
      id: user.id,
      display_name: displayName,
      role: 'admin'
    });
    if (error) throw error;
  }

  console.log(`已把 ${email} 设置为管理员。`);
  return 0;
}

async function main() {
  const command = process.argv[2] ?? 'check';

  if (command === 'check') {
    process.exitCode = await runCheck();
    return;
  }

  if (command === 'promote') {
    process.exitCode = await promoteAdmin(process.argv[3]);
    return;
  }

  console.log('可用命令：');
  console.log('  npm run admin:check');
  console.log('  npm run admin:promote -- name@example.com');
  process.exitCode = 1;
}

const isMain = process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1]);

if (isMain) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}

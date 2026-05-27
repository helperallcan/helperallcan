import Link from 'next/link';

const links = [
  ['仪表盘', '/dashboard'],
  ['用户', '/users'],
  ['帮手', '/helpers'],
  ['任务', '/tasks'],
  ['举报', '/reports'],
  ['分类', '/categories'],
  ['加急', '/urgent'],
  ['认证', '/verifications'],
  ['付款', '/payments']
];

export function AdminNav() {
  return (
    <nav className="admin-nav">
      <Link className="brand" href="/dashboard">
        Helper Admin
      </Link>
      <div className="nav-links">
        {links.map(([label, href]) => (
          <Link key={href} href={href}>
            {label}
          </Link>
        ))}
      </div>
    </nav>
  );
}

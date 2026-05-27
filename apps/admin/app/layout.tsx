import type { Metadata } from 'next';

import './globals.css';

export const metadata: Metadata = {
  title: 'Helper Admin',
  description: 'Helper 平台后台'
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}

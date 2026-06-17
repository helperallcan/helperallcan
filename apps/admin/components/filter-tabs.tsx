import Link from 'next/link';

type FilterTab = {
  active?: boolean;
  count?: number;
  href: string;
  label: string;
};

export function FilterTabs({ tabs }: { tabs: FilterTab[] }) {
  return (
    <nav className="filter-tabs" aria-label="筛选">
      {tabs.map((tab) => (
        <Link
          className={tab.active ? 'filter-tab active' : 'filter-tab'}
          href={tab.href}
          key={tab.href}
        >
          <span>{tab.label}</span>
          {typeof tab.count === 'number' ? <strong>{tab.count}</strong> : null}
        </Link>
      ))}
    </nav>
  );
}

import { useMemo, useState } from "react";

export interface SidebarItem {
  id: string;
  primary: string;
  secondary?: string;
}

interface Props {
  items: SidebarItem[];
  selectedId: string | null;
  onSelect: (id: string) => void;
  onNew: () => void;
  newLabel?: string;
  placeholder?: string;
}

export function Sidebar({
  items,
  selectedId,
  onSelect,
  onNew,
  newLabel = "+ New",
  placeholder = "Filter…",
}: Props) {
  const [q, setQ] = useState("");
  const filtered = useMemo(() => {
    if (!q.trim()) return items;
    const needle = q.toLowerCase();
    return items.filter(
      (i) =>
        i.primary.toLowerCase().includes(needle) ||
        i.id.toLowerCase().includes(needle) ||
        (i.secondary?.toLowerCase().includes(needle) ?? false)
    );
  }, [items, q]);

  return (
    <aside className="sidebar">
      <div className="sidebar-header">
        <input
          placeholder={placeholder}
          value={q}
          onChange={(e) => setQ(e.target.value)}
        />
        <button onClick={onNew}>{newLabel}</button>
      </div>
      <ul className="sidebar-list" style={{ listStyle: "none", margin: 0, padding: 0 }}>
        {filtered.map((item) => (
          <li
            key={item.id}
            className={`sidebar-item${selectedId === item.id ? " active" : ""}`}
            onClick={() => onSelect(item.id)}
          >
            <span className="primary-label">{item.primary}</span>
            {item.secondary && (
              <span className="secondary-label">{item.secondary}</span>
            )}
          </li>
        ))}
        {filtered.length === 0 && (
          <li style={{ padding: "20px 14px", color: "var(--text-dim)", fontStyle: "italic" }}>
            No matches.
          </li>
        )}
      </ul>
    </aside>
  );
}

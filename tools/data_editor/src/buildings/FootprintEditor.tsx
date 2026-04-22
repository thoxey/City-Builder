import { useMemo } from "react";

interface Props {
  cells: Array<[number, number]>;
  onChange: (next: Array<[number, number]>) => void;
}

// Small 6×6 grid centred on the origin. Click to toggle a cell — enough for
// most real buildings (1..4 cells). Author can fall back to raw numeric
// entry below the grid for odd shapes that don't fit.
export function FootprintEditor({ cells, onChange }: Props) {
  const size = 6;
  const cellSet = useMemo(
    () => new Set(cells.map(([x, y]) => `${x},${y}`)),
    [cells]
  );

  const toggle = (x: number, y: number) => {
    const key = `${x},${y}`;
    if (cellSet.has(key)) {
      onChange(cells.filter(([cx, cy]) => !(cx === x && cy === y)));
    } else {
      onChange([...cells, [x, y]]);
    }
  };

  const rows: JSX.Element[] = [];
  for (let dy = -Math.floor(size / 2); dy < Math.ceil(size / 2); dy++) {
    const row: JSX.Element[] = [];
    for (let dx = -Math.floor(size / 2); dx < Math.ceil(size / 2); dx++) {
      const on = cellSet.has(`${dx},${dy}`);
      const isOrigin = dx === 0 && dy === 0;
      row.push(
        <button
          key={`${dx},${dy}`}
          type="button"
          className={`fp-cell${on ? " on" : ""}${isOrigin ? " origin" : ""}`}
          onClick={() => toggle(dx, dy)}
          title={`(${dx}, ${dy})${isOrigin ? " origin" : ""}`}
        >
          {on ? "■" : isOrigin ? "·" : ""}
        </button>
      );
    }
    rows.push(
      <div key={`row-${dy}`} className="fp-row">
        {row}
      </div>
    );
  }

  return (
    <div className="footprint-editor">
      <div className="fp-grid">{rows}</div>
      <div className="inline-note">
        Click a cell to include it. Origin (0,0) is marked with a dot. Current:{" "}
        {cells.length === 0 ? "(none)" : cells.map(([x, y]) => `(${x},${y})`).join(" ")}
      </div>
    </div>
  );
}

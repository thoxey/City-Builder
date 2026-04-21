import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { Sidebar } from "./Sidebar";

const items = [
  { id: "a", primary: "Alpha", secondary: "aristocrat" },
  { id: "b", primary: "Bravo", secondary: "farmer" },
  { id: "c", primary: "Charlie", secondary: "aristocrat" },
];

describe("Sidebar", () => {
  it("renders every item", () => {
    render(<Sidebar items={items} selectedId={null} onSelect={() => {}} onNew={() => {}} />);
    expect(screen.getByText("Alpha")).toBeInTheDocument();
    expect(screen.getByText("Bravo")).toBeInTheDocument();
    expect(screen.getByText("Charlie")).toBeInTheDocument();
  });

  it("filters by primary, id, and secondary", () => {
    render(<Sidebar items={items} selectedId={null} onSelect={() => {}} onNew={() => {}} />);
    const input = screen.getByPlaceholderText("Filter…");
    fireEvent.change(input, { target: { value: "farmer" } });
    expect(screen.queryByText("Alpha")).toBeNull();
    expect(screen.getByText("Bravo")).toBeInTheDocument();
    expect(screen.queryByText("Charlie")).toBeNull();
  });

  it("fires onSelect on click", () => {
    const onSelect = vi.fn();
    render(<Sidebar items={items} selectedId={null} onSelect={onSelect} onNew={() => {}} />);
    fireEvent.click(screen.getByText("Bravo"));
    expect(onSelect).toHaveBeenCalledWith("b");
  });

  it("fires onNew on new button", () => {
    const onNew = vi.fn();
    render(<Sidebar items={items} selectedId={null} onSelect={() => {}} onNew={onNew} newLabel="+ Add" />);
    fireEvent.click(screen.getByText("+ Add"));
    expect(onNew).toHaveBeenCalled();
  });

  it("highlights selected item", () => {
    const { container } = render(
      <Sidebar items={items} selectedId="b" onSelect={() => {}} onNew={() => {}} />
    );
    const active = container.querySelector(".sidebar-item.active");
    expect(active?.textContent).toContain("Bravo");
  });
});

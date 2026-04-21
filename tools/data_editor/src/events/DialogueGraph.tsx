import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  Background,
  Controls,
  Handle,
  MarkerType,
  Position,
  ReactFlow,
  ReactFlowProvider,
  addEdge,
  applyEdgeChanges,
  applyNodeChanges,
  type Connection,
  type Edge,
  type EdgeChange,
  type Node,
  type NodeChange,
  type NodeProps,
} from "@xyflow/react";
import "@xyflow/react/dist/style.css";
import type { DialoguePayload } from "../types";

// Position nodes horizontally by BFS depth from the entry node, vertically
// by order-within-depth. Enough for a first draft; the user can drag to tidy.
function autoLayout(
  payload: DialoguePayload,
  saved: Map<string, { x: number; y: number }>
): Map<string, { x: number; y: number }> {
  const positions = new Map<string, { x: number; y: number }>(saved);
  const depth = new Map<string, number>();
  const queue: string[] = [payload.entry_node_id];
  depth.set(payload.entry_node_id, 0);

  while (queue.length) {
    const id = queue.shift()!;
    const d = depth.get(id)!;
    const node = payload.nodes.find((n) => n.node_id === id);
    if (!node) continue;
    for (const opt of node.options) {
      if (!opt.next || depth.has(opt.next)) continue;
      depth.set(opt.next, d + 1);
      queue.push(opt.next);
    }
  }
  // Any orphan nodes (not reached from entry) go in a trailing column.
  const maxDepth = Math.max(0, ...depth.values());
  for (const n of payload.nodes) {
    if (!depth.has(n.node_id)) depth.set(n.node_id, maxDepth + 1);
  }

  const byDepth = new Map<number, string[]>();
  for (const n of payload.nodes) {
    const d = depth.get(n.node_id)!;
    const arr = byDepth.get(d) ?? [];
    arr.push(n.node_id);
    byDepth.set(d, arr);
  }

  const COL_W = 260;
  const ROW_H = 160;
  for (const [d, ids] of byDepth) {
    ids.forEach((id, i) => {
      if (positions.has(id)) return; // preserve user-dragged positions
      positions.set(id, { x: d * COL_W, y: i * ROW_H });
    });
  }
  return positions;
}

// Custom node renderer: shows the node_id + a preview of the body, with one
// source handle per option and a single target handle (entry on the left).
interface NodeData {
  label: string;
  body: string;
  speaker: string;
  options: Array<{ label: string; next: string }>;
  isEntry: boolean;
  isSelected: boolean;
  [k: string]: unknown;
}

function DialogueGraphNode({ data }: NodeProps<Node<NodeData>>) {
  return (
    <div
      className={`dialogue-node${data.isEntry ? " entry" : ""}${data.isSelected ? " selected" : ""}`}
    >
      <Handle type="target" position={Position.Left} id="in" />
      <div className="dialogue-node-header">
        <span className="node-id">{data.label}</span>
        {data.isEntry && <span className="badge">entry</span>}
      </div>
      {data.speaker && <div className="dialogue-node-speaker">{data.speaker}</div>}
      <div className="dialogue-node-body">
        {data.body ? (
          data.body.length > 120 ? data.body.slice(0, 117) + "…" : data.body
        ) : (
          <span className="placeholder">(empty body)</span>
        )}
      </div>
      <div className="dialogue-node-options">
        {data.options.length === 0 && (
          <div className="dialogue-option-row">
            <span className="placeholder">→ Continue / Close</span>
          </div>
        )}
        {data.options.map((opt, i) => (
          <div key={i} className="dialogue-option-row">
            <span>{opt.label || "(unlabeled)"}</span>
            <Handle
              type="source"
              position={Position.Right}
              id={`opt-${i}`}
              style={{ top: "auto", transform: "none", position: "relative", right: "auto" }}
            />
          </div>
        ))}
      </div>
    </div>
  );
}

const nodeTypes = { dialogue: DialogueGraphNode };

interface Props {
  payload: DialoguePayload;
  selectedNodeId: string | null;
  onSelectNode: (id: string | null) => void;
  onUpdatePayload: (next: DialoguePayload) => void;
  onAddNode: () => void;
}

export function DialogueGraph(props: Props) {
  return (
    <ReactFlowProvider>
      <DialogueGraphInner {...props} />
    </ReactFlowProvider>
  );
}

function DialogueGraphInner({
  payload,
  selectedNodeId,
  onSelectNode,
  onUpdatePayload,
  onAddNode,
}: Props) {
  // Persisted positions across re-renders of the same component instance.
  const posRef = useRef(new Map<string, { x: number; y: number }>());
  const positions = useMemo(
    () => autoLayout(payload, posRef.current),
    [payload]
  );
  // Keep the ref in sync with the derived positions so future autoLayout
  // calls see them as "saved".
  for (const [k, v] of positions) posRef.current.set(k, v);

  const rfNodes = useMemo<Node<NodeData>[]>(
    () =>
      payload.nodes.map((n) => ({
        id: n.node_id,
        type: "dialogue",
        position: positions.get(n.node_id) ?? { x: 0, y: 0 },
        selected: n.node_id === selectedNodeId,
        data: {
          label: n.node_id,
          body: n.body,
          speaker: n.speaker,
          options: n.options.map((o) => ({ label: o.label, next: o.next })),
          isEntry: n.node_id === payload.entry_node_id,
          isSelected: n.node_id === selectedNodeId,
        },
      })),
    [payload, positions, selectedNodeId]
  );

  const rfEdges = useMemo<Edge[]>(() => {
    const edges: Edge[] = [];
    for (const n of payload.nodes) {
      n.options.forEach((opt, i) => {
        if (!opt.next) return;
        edges.push({
          id: `${n.node_id}-opt${i}->${opt.next}`,
          source: n.node_id,
          sourceHandle: `opt-${i}`,
          target: opt.next,
          markerEnd: { type: MarkerType.ArrowClosed },
          label: opt.label || undefined,
          style: { stroke: "#5ab0ff" },
        });
      });
    }
    return edges;
  }, [payload]);

  const [rfNodesLocal, setRfNodesLocal] = useState(rfNodes);
  const [rfEdgesLocal, setRfEdgesLocal] = useState(rfEdges);

  useEffect(() => {
    setRfNodesLocal(rfNodes);
  }, [rfNodes]);
  useEffect(() => {
    setRfEdgesLocal(rfEdges);
  }, [rfEdges]);

  const onNodesChange = useCallback(
    (changes: NodeChange<Node<NodeData>>[]) => {
      setRfNodesLocal((ns) => {
        const next = applyNodeChanges(changes, ns);
        // Persist drag positions back to the ref so autoLayout won't
        // clobber them on next render.
        for (const c of changes) {
          if (c.type === "position" && c.position) {
            posRef.current.set(c.id, c.position);
          }
        }
        return next;
      });
    },
    []
  );

  const onEdgesChange = useCallback(
    (changes: EdgeChange[]) => {
      setRfEdgesLocal((es) => applyEdgeChanges(changes, es));
    },
    []
  );

  const onConnect = useCallback(
    (conn: Connection) => {
      // Translate the new edge into an option.next update.
      if (!conn.source || !conn.target || !conn.sourceHandle) return;
      const m = /^opt-(\d+)$/.exec(conn.sourceHandle);
      if (!m) return;
      const optIdx = Number(m[1]);
      const sourceNode = payload.nodes.find((n) => n.node_id === conn.source);
      if (!sourceNode) return;
      if (optIdx >= sourceNode.options.length) return;
      const nextNodes = payload.nodes.map((n) => {
        if (n.node_id !== conn.source) return n;
        const options = n.options.map((o, i) =>
          i === optIdx ? { ...o, next: conn.target! } : o
        );
        return { ...n, options };
      });
      onUpdatePayload({ ...payload, nodes: nextNodes });
      // Optimistic local edge so UI updates immediately before re-render.
      setRfEdgesLocal((es) =>
        addEdge(
          {
            ...conn,
            id: `${conn.source}-opt${optIdx}->${conn.target}`,
            markerEnd: { type: MarkerType.ArrowClosed },
            style: { stroke: "#5ab0ff" },
          },
          es
        )
      );
    },
    [payload, onUpdatePayload]
  );

  const onNodeClick = useCallback(
    (_: React.MouseEvent, node: Node) => onSelectNode(node.id),
    [onSelectNode]
  );
  const onPaneClick = useCallback(() => onSelectNode(null), [onSelectNode]);

  return (
    <div className="dialogue-graph-wrap">
      <div className="graph-toolbar">
        <button onClick={onAddNode}>+ Add node</button>
        <div className="inline-note">
          Drag an option's right handle onto another node to wire it.
        </div>
      </div>
      <div className="graph-canvas">
        <ReactFlow
          nodes={rfNodesLocal}
          edges={rfEdgesLocal}
          nodeTypes={nodeTypes}
          onNodesChange={onNodesChange}
          onEdgesChange={onEdgesChange}
          onConnect={onConnect}
          onNodeClick={onNodeClick}
          onPaneClick={onPaneClick}
          fitView
          fitViewOptions={{ padding: 0.2 }}
          colorMode="dark"
        >
          <Background />
          <Controls showInteractive={false} />
        </ReactFlow>
      </div>
    </div>
  );
}

import type {
  DialogueNodeDoc,
  DialoguePayload,
  EventDoc,
  EventType,
  NewspaperPayload,
  NotificationPayload,
} from "../types";

export function blankDialogueNode(node_id: string): DialogueNodeDoc {
  return {
    node_id,
    speaker: "",
    body: "",
    on_enter: [],
    options: [],
  };
}

export function blankDialoguePayload(): DialoguePayload {
  return {
    tree_id: "",
    entry_node_id: "n_start",
    nodes: [blankDialogueNode("n_start")],
  };
}

export function blankNewspaperPayload(): NewspaperPayload {
  return { headline: "", kicker: "", body: "", image: "", dateline: "" };
}

export function blankNotificationPayload(): NotificationPayload {
  return { text: "", duration: 3.0, icon: "" };
}

export function blankEvent(type: EventType): EventDoc {
  const base: Omit<EventDoc, "payload"> = {
    event_id: "",
    event_type: type,
    trigger: { event: "manual" },
    enabled_if: "",
  };
  if (type === "dialogue")
    return { ...base, payload: blankDialoguePayload() };
  if (type === "newspaper")
    return { ...base, payload: blankNewspaperPayload() };
  return { ...base, payload: blankNotificationPayload() };
}

// Deep-clone an EventDoc so form state doesn't mutate manifest data.
export function cloneEvent(doc: EventDoc): EventDoc {
  return JSON.parse(JSON.stringify(doc)) as EventDoc;
}

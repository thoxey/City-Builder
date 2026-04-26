import { useEffect, useState } from "react";
import { useApp } from "../store";
import { pathFromRes } from "../events/paths";

// Renders a small inline preview of a res:// asset. "image" → <img>,
// "video" → <video controls muted loop>. Mirrors ModelPreview's blob-URL
// pattern: ask the Repo for the file as a Blob, hand the result to a
// browser-friendly object URL, revoke on unmount.

interface Props {
  path: string;
  kind: "image" | "video";
  className?: string;
}

export function MediaPreview({ path, kind, className }: Props) {
  const { repo } = useApp();
  const [src, setSrc] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setSrc(null);
    setError(null);
    if (!path) return;
    if (!repo?.readBlob) {
      setError("Preview unavailable in download mode.");
      return;
    }
    if (!path.startsWith("res://")) {
      setError("Path must start with res://");
      return;
    }
    let revoked = false;
    let objUrl: string | null = null;

    (async () => {
      try {
        const blob = await repo.readBlob!(pathFromRes(path));
        if (revoked) return;
        objUrl = URL.createObjectURL(blob);
        setSrc(objUrl);
      } catch (e) {
        if (!revoked) setError((e as Error).message);
      }
    })();

    return () => {
      revoked = true;
      if (objUrl) URL.revokeObjectURL(objUrl);
    };
  }, [path, repo]);

  const cls = className ?? `media-preview ${kind}`;
  if (!path) return <div className={`${cls} empty`}>—</div>;
  if (error) return <div className={`${cls} error`}>{error}</div>;
  if (!src) return <div className={`${cls} loading`}>Loading…</div>;
  if (kind === "image") {
    return <img src={src} alt="preview" className={cls} />;
  }
  return (
    <video
      src={src}
      className={cls}
      controls
      muted
      loop
      playsInline
      preload="metadata"
    />
  );
}

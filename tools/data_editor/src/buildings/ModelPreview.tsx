import { useEffect, useState } from "react";
import "@google/model-viewer";
import { useApp } from "../store";
import { pathFromRes } from "../events/paths";

// React / TypeScript doesn't know about custom elements by default. Teach
// it that <model-viewer> is valid inside JSX.
declare global {
  namespace JSX {
    interface IntrinsicElements {
      "model-viewer": React.DetailedHTMLProps<React.HTMLAttributes<HTMLElement>, HTMLElement> & {
        src?: string;
        alt?: string;
        "auto-rotate"?: boolean | "";
        "camera-controls"?: boolean | "";
        "shadow-intensity"?: string;
        exposure?: string;
        "environment-image"?: string;
      };
    }
  }
}

interface Props {
  modelPath: string; // e.g. res://models/<folder>/<file>.glb
}

export function ModelPreview({ modelPath }: Props) {
  const { repo } = useApp();
  const [src, setSrc] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setSrc(null);
    setError(null);
    if (!modelPath) return;
    if (!repo?.readBlob) {
      setError("Preview unavailable in download mode.");
      return;
    }
    if (!modelPath.startsWith("res://")) {
      setError("Path must start with res://");
      return;
    }
    let revoked = false;
    let objUrl: string | null = null;

    (async () => {
      try {
        const blob = await repo.readBlob!(pathFromRes(modelPath));
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
  }, [modelPath, repo]);

  if (!modelPath) {
    return (
      <div className="model-preview empty">
        Enter <code>model_path</code> to preview.
      </div>
    );
  }
  if (error) {
    return <div className="model-preview error">{error}</div>;
  }
  if (!src) {
    return <div className="model-preview loading">Loading…</div>;
  }
  return (
    <div className="model-preview">
      <model-viewer
        src={src}
        alt="building model preview"
        camera-controls
        auto-rotate
        shadow-intensity="0.6"
        exposure="0.9"
        style={{ width: "100%", height: "100%", background: "var(--panel-2)" }}
      />
    </div>
  );
}

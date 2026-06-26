import cv2
import numpy as np

# RGB hex per quadrant (first FDI digit)
_QUADRANT_RGB = {
    "1": (0x57, 0xC8, 0x4D),
    "2": (0xE8, 0x4D, 0x4D),
    "3": (0x4D, 0xC8, 0xE8),
    "4": (0xE8, 0xC8, 0x4D),
}
_NULL_RGB = (0x9E, 0x9E, 0x9E)


def quadrant_color(tooth: str | None) -> tuple[int, int, int]:
    rgb = _QUADRANT_RGB.get(tooth[0], _NULL_RGB) if tooth else _NULL_RGB
    r, g, b = rgb
    return (b, g, r)  # OpenCV uses BGR


def draw_detections(image_bgr: np.ndarray, detections: list[dict]) -> np.ndarray:
    out = image_bgr.copy()
    for d in detections:
        x1, y1, x2, y2 = (int(v) for v in d["bbox_xyxy"])
        color = quadrant_color(d.get("tooth"))
        label = f"{d['tooth']} {d['disease']}" if d.get("tooth") else f"? {d['disease']}"
        cv2.rectangle(out, (x1, y1), (x2, y2), color, 2)
        (tw, th), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.5, 1)
        cv2.rectangle(out, (x1, y1 - th - 4), (x1 + tw, y1), color, -1)
        cv2.putText(out, label, (x1, y1 - 4), cv2.FONT_HERSHEY_SIMPLEX, 0.5,
                    (0, 0, 0), 1, cv2.LINE_AA)
    return out

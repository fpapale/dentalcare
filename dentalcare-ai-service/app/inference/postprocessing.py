import numpy as np


def iou_xyxy(a: list[float], b: list[float]) -> float:
    ax1, ay1, ax2, ay2 = a
    bx1, by1, bx2, by2 = b
    ix1, iy1 = max(ax1, bx1), max(ay1, by1)
    ix2, iy2 = min(ax2, bx2), min(ay2, by2)
    iw, ih = max(0.0, ix2 - ix1), max(0.0, iy2 - iy1)
    inter = iw * ih
    if inter == 0:
        return 0.0
    area_a = max(0.0, ax2 - ax1) * max(0.0, ay2 - ay1)
    area_b = max(0.0, bx2 - bx1) * max(0.0, by2 - by1)
    union = area_a + area_b - inter
    return inter / union if union > 0 else 0.0


def nms(boxes: list[list[float]], scores: list[float], iou_threshold: float) -> list[int]:
    order = sorted(range(len(scores)), key=lambda i: scores[i], reverse=True)
    kept: list[int] = []
    while order:
        i = order.pop(0)
        kept.append(i)
        order = [j for j in order if iou_xyxy(boxes[i], boxes[j]) < iou_threshold]
    return kept


def parse_yolo_output(output: np.ndarray, num_classes: int, conf_threshold: float,
                      iou_threshold: float, ratio: float, pad: tuple[int, int]) -> list[dict]:
    # output: (1, 4+num_classes, N) -> (N, 4+num_classes)
    preds = np.squeeze(output, axis=0).transpose(1, 0)
    pad_x, pad_y = pad

    boxes: list[list[float]] = []
    scores: list[float] = []
    class_ids: list[int] = []
    for row in preds:
        cls_scores = row[4:4 + num_classes]
        class_id = int(np.argmax(cls_scores))
        conf = float(cls_scores[class_id])
        if conf < conf_threshold:
            continue
        cx, cy, w, h = row[0], row[1], row[2], row[3]
        x1 = (cx - w / 2 - pad_x) / ratio
        y1 = (cy - h / 2 - pad_y) / ratio
        x2 = (cx + w / 2 - pad_x) / ratio
        y2 = (cy + h / 2 - pad_y) / ratio
        boxes.append([x1, y1, x2, y2])
        scores.append(conf)
        class_ids.append(class_id)

    kept = nms(boxes, scores, iou_threshold)
    detections: list[dict] = []
    for i in kept:
        x1, y1, x2, y2 = boxes[i]
        detections.append({
            "class_id": class_ids[i],
            "confidence": round(scores[i], 4),
            "bbox_xyxy": [int(round(x1)), int(round(y1)), int(round(x2)), int(round(y2))],
        })
    return detections

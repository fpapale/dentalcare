import cv2
import numpy as np


def letterbox(image_bgr: np.ndarray, new_size: int) -> tuple[np.ndarray, float, tuple[int, int]]:
    h, w = image_bgr.shape[:2]
    ratio = new_size / max(h, w)
    new_w, new_h = int(round(w * ratio)), int(round(h * ratio))
    resized = cv2.resize(image_bgr, (new_w, new_h), interpolation=cv2.INTER_LINEAR)

    pad_x = (new_size - new_w) // 2
    pad_y = (new_size - new_h) // 2
    padded = np.full((new_size, new_size, 3), 114, dtype=np.uint8)
    padded[pad_y:pad_y + new_h, pad_x:pad_x + new_w] = resized
    return padded, ratio, (pad_x, pad_y)


def to_model_input(padded_bgr: np.ndarray) -> np.ndarray:
    rgb = cv2.cvtColor(padded_bgr, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
    chw = np.transpose(rgb, (2, 0, 1))
    return np.expand_dims(chw, axis=0).astype(np.float32)

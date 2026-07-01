import os

import numpy as np
import onnxruntime as ort

from app.inference.postprocessing import parse_yolo_output
from app.inference.preprocessing import letterbox, to_model_input
from app.utils.logging import log_event


class OnnxYoloDetector:
    def __init__(self, model_path: str, class_names: dict[int, str], input_size: int,
                 conf_threshold: float, iou_threshold: float, input_scale: float = 255.0):
        self.model_path = model_path
        self.class_names = class_names
        self.input_size = input_size
        self.conf_threshold = conf_threshold
        self.iou_threshold = iou_threshold
        self.input_scale = input_scale
        self._session: ort.InferenceSession | None = None
        self._logged_shape = False

    def _ensure_session(self) -> ort.InferenceSession:
        if self._session is None:
            self._session = ort.InferenceSession(
                self.model_path, providers=["CPUExecutionProvider"]
            )
        return self._session

    def is_loaded(self) -> bool:
        return os.path.exists(self.model_path)

    def predict(self, image_bgr: np.ndarray) -> list[dict]:
        session = self._ensure_session()
        padded, ratio, pad = letterbox(image_bgr, self.input_size)
        tensor = to_model_input(padded, self.input_scale)
        input_name = session.get_inputs()[0].name
        outputs = session.run(None, {input_name: tensor})
        output = outputs[0]
        if not self._logged_shape:
            log_event("onnx_output_shape", model=self.model_path, shape=list(output.shape))
            self._logged_shape = True
        dets = parse_yolo_output(
            output, num_classes=len(self.class_names),
            conf_threshold=self.conf_threshold, iou_threshold=self.iou_threshold,
            ratio=ratio, pad=pad,
        )
        for d in dets:
            d["class_name"] = self.class_names.get(d["class_id"], f"class_{d['class_id']}")
        return dets

from unittest.mock import MagicMock

import numpy as np

from app.inference import onnx_yolo
from app.inference.onnx_yolo import OnnxYoloDetector


def test_predict_maps_class_names(monkeypatch):
    fake_session = MagicMock()
    fake_session.get_inputs.return_value = [MagicMock(name="images")]
    fake_session.get_inputs.return_value[0].name = "images"
    # one detection class 1
    out = np.zeros((1, 4 + 2, 1), dtype=np.float32)
    out[0, 0, 0] = 100; out[0, 1, 0] = 100; out[0, 2, 0] = 20; out[0, 3, 0] = 20
    out[0, 4 + 1, 0] = 0.9
    fake_session.run.return_value = [out]

    monkeypatch.setattr(onnx_yolo.ort, "InferenceSession", lambda *a, **k: fake_session)

    det = OnnxYoloDetector("x.onnx", {0: "A", 1: "B"}, input_size=1024,
                           conf_threshold=0.25, iou_threshold=0.45)
    image = np.zeros((512, 512, 3), dtype=np.uint8)
    results = det.predict(image)
    assert len(results) == 1
    assert results[0]["class_name"] == "B"
    assert results[0]["class_id"] == 1


def test_is_loaded_false_for_missing_file():
    det = OnnxYoloDetector("definitely-not-here.onnx", {0: "A"}, input_size=1024,
                           conf_threshold=0.25, iou_threshold=0.45)
    assert det.is_loaded() is False


def test_output_shape_logged_only_once(monkeypatch):
    fake_session = MagicMock()
    fake_session.get_inputs.return_value = [MagicMock()]
    fake_session.get_inputs.return_value[0].name = "images"
    out = np.zeros((1, 4 + 2, 1), dtype=np.float32)
    out[0, 0, 0] = 100; out[0, 1, 0] = 100; out[0, 2, 0] = 20; out[0, 3, 0] = 20
    out[0, 4 + 1, 0] = 0.9
    fake_session.run.return_value = [out]
    monkeypatch.setattr(onnx_yolo.ort, "InferenceSession", lambda *a, **k: fake_session)

    calls = []
    monkeypatch.setattr(onnx_yolo, "log_event", lambda event, **kw: calls.append(event))

    det = OnnxYoloDetector("x.onnx", {0: "A", 1: "B"}, input_size=1024,
                           conf_threshold=0.25, iou_threshold=0.45)
    image = np.zeros((512, 512, 3), dtype=np.uint8)
    det.predict(image)
    det.predict(image)
    assert calls.count("onnx_output_shape") == 1

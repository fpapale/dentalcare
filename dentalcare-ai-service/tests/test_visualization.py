import numpy as np

from app.inference.visualization import draw_detections, quadrant_color


def test_quadrant_color_q1_green_bgr():
    # #57C84D -> RGB(87,200,77) -> BGR(77,200,87)
    assert quadrant_color("16") == (77, 200, 87)


def test_quadrant_color_null_is_grey():
    # #9E9E9E -> (158,158,158)
    assert quadrant_color(None) == (158, 158, 158)


def test_draw_detections_returns_same_shape_copy():
    img = np.zeros((400, 400, 3), dtype=np.uint8)
    dets = [{"tooth": "36", "disease": "Caries", "bbox_xyxy": [10, 10, 100, 100]}]
    out = draw_detections(img, dets)
    assert out.shape == img.shape
    # original untouched (a copy was drawn on)
    assert img.sum() == 0
    assert out.sum() > 0

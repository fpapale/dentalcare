import numpy as np

from app.inference.preprocessing import letterbox, to_model_input


def test_letterbox_outputs_square_target_size():
    img = np.zeros((900, 1800, 3), dtype=np.uint8)
    padded, ratio, (pad_x, pad_y) = letterbox(img, 1024)
    assert padded.shape == (1024, 1024, 3)
    # wider image -> scaled by width, vertical padding
    assert ratio == 1024 / 1800
    assert pad_y > 0
    assert pad_x == 0


def test_to_model_input_shape_and_range():
    padded = np.full((1024, 1024, 3), 255, dtype=np.uint8)
    tensor = to_model_input(padded)
    assert tensor.shape == (1, 3, 1024, 1024)
    assert tensor.dtype == np.float32
    assert tensor.max() <= 1.0 and tensor.min() >= 0.0

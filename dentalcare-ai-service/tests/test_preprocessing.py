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


def test_to_model_input_converts_bgr_to_rgb():
    # Blue-only image in BGR: channel 0 = 100, others 0.
    img = np.zeros((4, 4, 3), dtype=np.uint8)
    img[:, :, 0] = 100  # blue in BGR
    tensor = to_model_input(img)  # NCHW, RGB
    # After BGR->RGB, blue lands in the RGB blue channel = index 2.
    assert tensor[0, 2].max() > 0.0          # blue present in RGB channel 2
    assert tensor[0, 0].max() == 0.0         # red channel empty
    assert tensor[0, 1].max() == 0.0         # green channel empty


def test_letterbox_portrait_pads_horizontally():
    img = np.zeros((1800, 900, 3), dtype=np.uint8)  # taller than wide
    padded, ratio, (pad_x, pad_y) = letterbox(img, 1024)
    assert padded.shape == (1024, 1024, 3)
    assert ratio == 1024 / 1800
    assert pad_x > 0
    assert pad_y == 0

import numpy as np

from app.inference.postprocessing import iou_xyxy, nms, parse_yolo_output


def test_iou_identical_boxes_is_one():
    assert iou_xyxy([0, 0, 10, 10], [0, 0, 10, 10]) == 1.0


def test_iou_disjoint_boxes_is_zero():
    assert iou_xyxy([0, 0, 10, 10], [20, 20, 30, 30]) == 0.0


def test_nms_drops_overlapping_lower_score():
    boxes = [[0, 0, 10, 10], [1, 1, 11, 11], [100, 100, 110, 110]]
    scores = [0.9, 0.8, 0.7]
    kept = nms(boxes, scores, iou_threshold=0.5)
    assert 0 in kept and 2 in kept and 1 not in kept


def test_parse_yolo_output_rescales_to_original():
    # one detection, class 1, high conf, centered box in 1024 letterbox space
    num_classes = 4
    out = np.zeros((1, 4 + num_classes, 1), dtype=np.float32)
    out[0, 0, 0] = 512  # cx
    out[0, 1, 0] = 512  # cy
    out[0, 2, 0] = 100  # w
    out[0, 3, 0] = 100  # h
    out[0, 4 + 1, 0] = 0.9  # class 1 score
    # ratio 0.5, no padding -> original coords doubled
    dets = parse_yolo_output(out, num_classes, conf_threshold=0.25,
                             iou_threshold=0.45, ratio=0.5, pad=(0, 0))
    assert len(dets) == 1
    d = dets[0]
    assert d["class_id"] == 1
    assert d["confidence"] == 0.9
    # cx-w/2=462 -> /0.5 = 924
    assert d["bbox_xyxy"] == [924, 924, 1124, 1124]

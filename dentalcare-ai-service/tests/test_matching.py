from app.inference.pipeline import match_detections


def _fdi(tooth_box, name="16", conf=0.8):
    return {"class_name": name, "confidence": conf, "bbox_xyxy": tooth_box}


def _dis(box, name="Caries", conf=0.7):
    return {"class_name": name, "confidence": conf, "bbox_xyxy": box}


def test_match_by_iou_assigns_tooth():
    fdi = [_fdi([100, 100, 200, 300], name="16")]
    disease = [_dis([110, 120, 190, 280])]
    out = match_detections(fdi, disease, iou_threshold=0.10, center_fallback=True)
    assert out[0]["tooth"] == "16"
    assert out[0]["matching_method"] == "iou"
    assert out[0]["needs_review"] is False


def test_match_by_center_fallback_when_iou_low():
    # tiny disease box fully inside large tooth box, low IoU
    fdi = [_fdi([0, 0, 1000, 1000], name="36")]
    disease = [_dis([500, 500, 510, 510])]
    out = match_detections(fdi, disease, iou_threshold=0.90, center_fallback=True)
    assert out[0]["tooth"] == "36"
    assert out[0]["matching_method"] == "center"


def test_no_match_sets_needs_review():
    fdi = [_fdi([0, 0, 100, 100], name="11")]
    disease = [_dis([500, 500, 520, 520])]
    out = match_detections(fdi, disease, iou_threshold=0.10, center_fallback=True)
    assert out[0]["tooth"] is None
    assert out[0]["matching_method"] == "none"
    assert out[0]["needs_review"] is True

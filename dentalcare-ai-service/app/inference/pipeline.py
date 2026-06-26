from app.inference.postprocessing import iou_xyxy

FDI_CLASS_NAMES: dict[int, str] = {
    0: "11", 1: "12", 2: "13", 3: "14", 4: "15", 5: "16", 6: "17", 7: "18",
    8: "21", 9: "22", 10: "23", 11: "24", 12: "25", 13: "26", 14: "27", 15: "28",
    16: "31", 17: "32", 18: "33", 19: "34", 20: "35", 21: "36", 22: "37", 23: "38",
    24: "41", 25: "42", 26: "43", 27: "44", 28: "45", 29: "46", 30: "47", 31: "48",
}

DISEASE_CLASS_NAMES: dict[int, str] = {
    0: "Impacted", 1: "Caries", 2: "Periapical_Lesion", 3: "Deep_Caries",
}


def _center_inside(box: list[float], container: list[float]) -> bool:
    cx = (box[0] + box[2]) / 2
    cy = (box[1] + box[3]) / 2
    return container[0] <= cx <= container[2] and container[1] <= cy <= container[3]


def match_detections(fdi_dets: list[dict], disease_dets: list[dict],
                     iou_threshold: float, center_fallback: bool) -> list[dict]:
    results: list[dict] = []
    for dis in disease_dets:
        dbox = dis["bbox_xyxy"]
        best_iou, best_fdi = 0.0, None
        for fdi in fdi_dets:
            score = iou_xyxy(dbox, fdi["bbox_xyxy"])
            if score > best_iou:
                best_iou, best_fdi = score, fdi

        tooth, method, fdi_conf, match_score = None, "none", None, None
        if best_fdi is not None and best_iou >= iou_threshold:
            tooth = best_fdi["class_name"]
            method = "iou"
            fdi_conf = best_fdi["confidence"]
            match_score = round(best_iou, 4)
        elif center_fallback:
            for fdi in fdi_dets:
                if _center_inside(dbox, fdi["bbox_xyxy"]):
                    tooth = fdi["class_name"]
                    method = "center"
                    fdi_conf = fdi["confidence"]
                    match_score = round(iou_xyxy(dbox, fdi["bbox_xyxy"]), 4)
                    break

        results.append({
            "tooth": tooth,
            "disease": dis["class_name"],
            "disease_confidence": dis["confidence"],
            "fdi_confidence": fdi_conf,
            "bbox_xyxy": dbox,
            "matching_method": method,
            "matching_score": match_score,
            "needs_review": tooth is None,
        })
    return results

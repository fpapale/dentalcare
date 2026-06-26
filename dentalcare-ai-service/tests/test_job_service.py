from unittest.mock import MagicMock

import numpy as np

from app.config import get_settings
from app.schemas import InferenceJobRequest
from app.services.job_service import JobService


def _req():
    return InferenceJobRequest(
        patient_id="P1", document_id="D1", analysis_id="A1", schema_name="t_x",
        image_bucket="dc-t-x", image_object_key="patients/P1/D1/pano.png",
        output_bucket="dc-t-x", output_prefix="patients/P1/D1/ai/A1/",
    )


def test_run_job_writes_result_and_calls_callback(monkeypatch):
    minio = MagicMock()
    # download writes a fake image file; patch cv2.imread to return an array
    import app.services.job_service as js
    monkeypatch.setattr(js.cv2, "imread", lambda p: np.zeros((200, 200, 3), dtype=np.uint8))
    monkeypatch.setattr(js.cv2, "imwrite", lambda p, im: True)
    sent = {}
    monkeypatch.setattr(js, "send_callback", lambda payload: sent.update(payload) or True)

    fdi = MagicMock(); fdi.predict.return_value = [
        {"class_id": 5, "class_name": "16", "confidence": 0.8, "bbox_xyxy": [10, 10, 90, 90]}]
    disease = MagicMock(); disease.predict.return_value = [
        {"class_id": 1, "class_name": "Caries", "confidence": 0.7, "bbox_xyxy": [20, 20, 80, 80]}]

    svc = JobService(minio, fdi, disease, get_settings())
    svc.run_job("job-1", _req())

    # result.json + annotated.png + final index uploaded
    assert minio.upload_json.called
    assert sent["status"] == "completed"
    assert sent["job_id"] == "job-1"
    assert sent["detections"][0]["tooth"] == "16"

    # processing index written first, completed last; annotated image uploaded
    index_statuses = [c.args[2]["status"] for c in minio.upload_json.call_args_list
                      if c.args[1].startswith("ai/jobs/")]
    assert index_statuses == ["processing", "completed"]
    assert minio.upload_file.called


def test_run_job_failure_sets_failed_status(monkeypatch):
    minio = MagicMock()
    minio.download_object.side_effect = RuntimeError("minio down")
    import app.services.job_service as js
    sent = {}
    monkeypatch.setattr(js, "send_callback", lambda payload: sent.update(payload) or True)

    svc = JobService(minio, MagicMock(), MagicMock(), get_settings())
    svc.run_job("job-2", _req())
    assert sent["status"] == "failed"
    assert "error" in sent

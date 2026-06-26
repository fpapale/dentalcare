from app.schemas import InferenceJobRequest


def test_inference_request_defaults_and_metadata():
    req = InferenceJobRequest(
        patient_id="P1", document_id="D1", schema_name="t_9d754153",
        image_bucket="dc-t-9d754153",
        image_object_key="patients/P1/D1/panoramic.png",
        output_bucket="dc-t-9d754153",
        output_prefix="patients/P1/D1/ai/A1/",
        analysis_id="A1",
    )
    assert req.save_annotated_image is True
    assert req.metadata == {}

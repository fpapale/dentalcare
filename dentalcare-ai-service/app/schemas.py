from pydantic import BaseModel, Field


class InferenceJobRequest(BaseModel):
    patient_id: str
    document_id: str
    analysis_id: str
    schema_name: str
    image_bucket: str
    image_object_key: str
    output_bucket: str
    output_prefix: str
    save_annotated_image: bool = True
    metadata: dict = Field(default_factory=dict)


class JobCreatedResponse(BaseModel):
    job_id: str
    status: str


class DetectionOut(BaseModel):
    tooth: str | None
    disease: str
    disease_confidence: float
    fdi_confidence: float | None
    bbox_xyxy: list[int]
    matching_method: str
    matching_score: float | None
    needs_review: bool


class JobStatusResponse(BaseModel):
    job_id: str
    status: str
    result_object_key: str | None = None
    annotated_image_object_key: str | None = None
    detections: list[DetectionOut] = Field(default_factory=list)
    error: str | None = None


class ModelInfo(BaseModel):
    name: str
    path: str
    loaded: bool


class ModelsStatusResponse(BaseModel):
    runtime: str
    providers: list[str]
    models: dict[str, ModelInfo]


class AnnotationRequest(BaseModel):
    patient_id: str
    study_id: str | None = None
    image_bucket: str
    image_object_key: str
    annotation_bucket: str
    annotation_object_key: str
    reviewer: dict = Field(default_factory=dict)
    annotations: list[dict] = Field(default_factory=list)

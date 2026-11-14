from pydantic import BaseModel, ConfigDict, Field

class RunSampleInput(BaseModel):
    model_config = ConfigDict(extra="ignore", allow_inf_nan=False)

    sample_id: str = Field(min_length=1)
    recorded_at: str = Field(min_length=1)
    elapsed_seconds: float = Field(ge=0)
    latitude: float | None = None
    longitude: float | None = None
    altitude_m: float | None = None
    heart_rate_bpm: float | None = None
    cadence_spm: float | None = None
    speed_mps: float | None = None
    running_power_w: float | None = None


class SampleBatchInput(BaseModel):
    model_config = ConfigDict(extra="ignore")

    device: str | None = None
    samples: list[RunSampleInput]
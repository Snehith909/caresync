from pathlib import Path
from tempfile import NamedTemporaryFile
from threading import Lock

from fastapi import HTTPException
from faster_whisper import WhisperModel

from .config import settings

_model: WhisperModel | None = None
_model_lock = Lock()


def _get_model() -> WhisperModel:
    global _model
    if _model is None:
        with _model_lock:
            if _model is None:
                _model = WhisperModel(
                    settings.whisper_model_size,
                    device=settings.whisper_device,
                    compute_type=settings.whisper_compute_type,
                )
    return _model


def transcribe_audio(data: bytes, suffix: str) -> tuple[str, str | None]:
    temporary_path: Path | None = None
    try:
        with NamedTemporaryFile(delete=False, suffix=suffix) as temporary:
            temporary.write(data)
            temporary_path = Path(temporary.name)
        segments, info = _get_model().transcribe(str(temporary_path), beam_size=5)
        text = " ".join(segment.text.strip() for segment in segments).strip()
        if not text:
            raise HTTPException(status_code=422, detail="No speech was detected")
        return text, info.language
    except HTTPException:
        raise
    except Exception as error:
        raise HTTPException(status_code=502, detail="Speech transcription failed") from error
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)

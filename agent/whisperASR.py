# -*- coding: utf-8 -*-
"""
Whisper ASR engine for ADH — calls a Groq / OpenAI / Azure compatible
Whisper transcription endpoint.

Drop this file into:
    awesome-digital-human-live2d/digitalHuman/engine/asr/whisperASR.py

Then add to that directory's __init__.py:
    from .whisperASR import WhisperApiAsr

The transcriptions API is OpenAI-standard:
    POST {base_url}/audio/transcriptions
    Headers: Authorization: Bearer <api_key>
    Multipart: file=<audio bytes>, model=<whisper model id>
    Response: {"text": "..."}
"""
import os
import base64

from ..builder import ASREngines
from ..engineBase import BaseASREngine
from digitalHuman.protocol import AudioMessage, TextMessage, AUDIO_TYPE
from digitalHuman.utils import logger, httpxAsyncClient, wavToMp3, checkResponse


__all__ = ["WhisperApiAsr"]


@ASREngines.register("Whisper")
class WhisperApiAsr(BaseASREngine):
    def setup(self):
        # nothing to pre-resolve; everything is read from kwargs / env each call
        pass

    async def run(self, input: AudioMessage, **kwargs) -> TextMessage:
        params = self.checkParameter(**kwargs)
        # Allow per-call override; otherwise fall back to env (preferred, no
        # API keys in the frontend UI).
        api_key = (params.get("api_key") or "").strip() or os.environ.get("GROQ_API_KEY", "")
        base_url = (params.get("base_url") or "").strip() or "https://api.groq.com/openai/v1"
        model = (params.get("model") or "").strip() or "whisper-large-v3"
        # Optional language hint; "" means auto-detect (recommended for EN+ZH demo).
        language = (params.get("language") or "").strip()

        if not api_key:
            raise RuntimeError("Whisper ASR: missing api_key (set GROQ_API_KEY env or pass api_key in settings).")

        # Normalize input audio: backend receives bytes (or base64 str) from frontend.
        if isinstance(input.data, str):
            input.data = base64.b64decode(input.data)
        if input.type == AUDIO_TYPE.WAV:
            input.data = wavToMp3(input.data)
            input.type = AUDIO_TYPE.MP3

        url = f"{base_url.rstrip('/')}/audio/transcriptions"
        headers = {"Authorization": f"Bearer {api_key}"}
        files = {"file": ("adh.mp3", input.data, "audio/mpeg")}
        data = {"model": model}
        if language:
            data["language"] = language

        response = await httpxAsyncClient.post(url, headers=headers, files=files, data=data)
        resp = checkResponse(response, "WhisperApiAsr")
        result = (resp.get("text") or "").strip()
        logger.debug(f"[ASR] Whisper response: {result}")
        return TextMessage(data=result)

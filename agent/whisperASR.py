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

Language allowlist behavior:
    By default we auto-detect. If Whisper detects something outside the
    allowlist (English / Chinese / Mandarin), we retry forcing language=en.
    This avoids the common Singapore-accent failure mode where English
    speech gets transcribed as Malay or Indonesian.
"""
import os
import base64

from ..builder import ASREngines
from ..engineBase import BaseASREngine
from digitalHuman.protocol import AudioMessage, TextMessage, AUDIO_TYPE
from digitalHuman.utils import logger, httpxAsyncClient, wavToMp3, checkResponse


__all__ = ["WhisperApiAsr"]


# Languages we accept Whisper to detect. Anything else (Malay, Indonesian,
# Tagalog, etc. — common false positives for Singapore-accent English)
# triggers a retry that forces FALLBACK_LANG.
ALLOWED_LANGS = {"english", "chinese", "mandarin", "en", "zh"}
FALLBACK_LANG = "en"

# Whisper "prompt" parameter biases recognition toward in-domain vocabulary.
# Up to 224 tokens; we use it to keep "NUS" from getting transcribed as "US",
# "COM1" from becoming "common one" / "command", etc. The prompt should sound
# like the kind of speech the user is about to produce.
WHISPER_PROMPT = (
    "Conversation about NUS, the National University of Singapore. "
    "Speakers mention NUS Computing, NUS School of Computing, Kent Ridge campus, "
    "Bukit Timah, COM1, COM2, COM3, Computer Science, Information Systems, "
    "Computer Engineering, Business Analytics, Information Security, "
    "Provost, Dean, Faculty, CourseReg, NUSnet, Yusof Ishak House, UTown."
)


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
        # Optional language hint passed from frontend. If set, we skip the
        # auto-detect-and-allowlist dance and force this language.
        forced_language = (params.get("language") or "").strip()

        if not api_key:
            raise RuntimeError("Whisper ASR: missing api_key (set GROQ_API_KEY env or pass api_key in settings).")

        # Normalize input audio: backend receives bytes (or base64 str) from frontend.
        if isinstance(input.data, str):
            input.data = base64.b64decode(input.data)
        if input.type == AUDIO_TYPE.WAV:
            input.data = wavToMp3(input.data)
            input.type = AUDIO_TYPE.MP3
        audio_bytes = input.data

        url = f"{base_url.rstrip('/')}/audio/transcriptions"
        headers = {"Authorization": f"Bearer {api_key}"}

        async def _call(force_lang):
            files = {"file": ("adh.mp3", audio_bytes, "audio/mpeg")}
            data = {
                "model": model,
                # verbose_json gives us the detected language so we can allowlist-check it.
                "response_format": "verbose_json",
                # Bias toward NUS-domain vocabulary so "NUS" doesn't get
                # transcribed as "US", etc. Note: Whisper's prompt is most
                # effective when its language matches the audio language.
                "prompt": WHISPER_PROMPT,
            }
            if force_lang:
                data["language"] = force_lang
            response = await httpxAsyncClient.post(url, headers=headers, files=files, data=data)
            return checkResponse(response, "WhisperApiAsr")

        # First pass: honor explicit forced_language; otherwise auto-detect.
        resp = await _call(forced_language or None)
        detected = (resp.get("language") or "").strip().lower()
        text = (resp.get("text") or "").strip()

        # If the user explicitly forced a language, trust it.
        # Otherwise, if Whisper detected something outside our allowlist, retry forcing English.
        if not forced_language and detected and detected not in ALLOWED_LANGS:
            logger.debug(f"[ASR] Whisper detected '{detected}' (not in allowlist); retrying with language={FALLBACK_LANG}")
            resp = await _call(FALLBACK_LANG)
            detected = (resp.get("language") or "").strip().lower()
            text = (resp.get("text") or "").strip()

        logger.debug(f"[ASR] Whisper response (lang={detected}): {text}")
        return TextMessage(data=text)

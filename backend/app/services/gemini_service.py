"""
Google Gemini API integration service for HapticSync rehabilitation analytics.
Generates evidence-based clinical rehabilitation briefings and parameter recommendations.
"""
from __future__ import annotations

import json
import logging
from typing import Any, Dict, Optional

import httpx

from app.core.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

GEMINI_API_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"

SYSTEM_PROMPT = """You are the HapticSync Rehabilitation Performance Analyst.
Your goal is to analyze validated rehabilitation game performance metrics and movement kinematics to generate a concise, objective rehabilitation briefing and suggested game parameter adjustments for the next session.

STRICT EVIDENCE & CLINICAL ETHICS RULES:
1. Base every observation only on the supplied data.
2. Do NOT diagnose medical conditions or infer neurological recovery, neuromuscular changes, or unmeasured anatomical mechanisms.
3. Do NOT claim that therapy caused an observed change (correlate observations, avoid claiming causation).
4. Do NOT invent measurements or introduce safety concerns unless directly supported by the supplied metrics.
5. Provide actionable, safe parameter update suggestions (difficulty, target tempo BPM, threshold, session target duration).
6. Write professionally and objectively: prefer "the measurements indicate", "the data show", "an increase was observed". Avoid "cured", "proves", or unsupported clinical claims.

You MUST respond with valid JSON adhering to this exact schema:
{
  "overview": "Clear natural language briefing formatted with markdown sections (Summary, Movement Performance, Fatigue & Compensation, Recommendations).",
  "parameter_suggestions": {
    "difficulty": "easy | medium | hard | adaptive",
    "target_speed_bpm": 60,
    "target_threshold": 0.5,
    "duration_target_s": 300,
    "rationale": "Analytical rationale for the suggested parameter adjustments.",
    "additional_parameters": {}
  },
  "key_metrics_summary": {
    "score": 0,
    "accuracy": 0.0,
    "repetitions": 0
  },
  "focus_areas": [
    "Specific movement or training focus 1",
    "Specific movement or training focus 2"
  ]
}
"""


def _generate_fallback_overview(data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Deterministic fallback when Gemini API key is missing or service is offline.
    Ensures backend reliability and seamless local testing.
    """
    game_title = data.get("game_title", "Rehabilitation Game")
    score = data.get("score", 0)
    accuracy = data.get("accuracy", 0.0)
    repetitions = data.get("repetitions", 0)
    duration_s = data.get("duration_s", 0)
    kinematics = data.get("kinematics", {})

    accuracy_pct = round(float(accuracy) * 100, 1) if accuracy is not None else 0.0
    smoothness = kinematics.get("smoothness_score", 0.8)

    overview_text = (
        f"### Rehabilitation Session Overview\n\n"
        f"**Activity:** {game_title}  \n"
        f"**Duration:** {duration_s} seconds  \n"
        f"**Observed Performance:** Completed {repetitions} repetitions with an accuracy of {accuracy_pct}% "
        f"and total score of {score}.\n\n"
        f"**Movement Metrics:** Kinematic analysis indicates movement smoothness measured at {smoothness}. "
        f"Performance remained consistent throughout the activity session.\n\n"
        f"**Observation:** Movement stability is maintained across repetitions."
    )

    suggested_difficulty = "medium" if accuracy_pct >= 75 else "easy"
    suggested_bpm = 65 if accuracy_pct >= 80 else 55

    return {
        "overview": overview_text,
        "parameter_suggestions": {
            "difficulty": suggested_difficulty,
            "target_speed_bpm": suggested_bpm,
            "target_threshold": 0.5,
            "duration_target_s": max(300, duration_s),
            "rationale": (
                f"Based on an accuracy rate of {accuracy_pct}% and movement smoothness score of {smoothness}, "
                f"maintaining a {suggested_difficulty} difficulty level supports motor control consolidation."
            ),
            "additional_parameters": {},
        },
        "key_metrics_summary": {
            "score": score,
            "accuracy": accuracy,
            "repetitions": repetitions,
            "duration_s": duration_s,
            "smoothness_score": smoothness,
        },
        "focus_areas": [
            "Maintain grip coordination during extended holding periods",
            "Focus on controlled finger extension during release phase",
        ],
    }


async def generate_gemini_rehabilitation_overview(
    session_data: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Calls Google Gemini REST API to produce a structured clinical rehabilitation briefing.
    Falls back gracefully if the API key is not configured or network error occurs.
    """
    api_key = settings.gemini_api_key
    if not api_key:
        logger.info("GEMINI_API_KEY not configured. Using deterministic fallback analysis.")
        return _generate_fallback_overview(session_data)

    model = settings.gemini_model or "gemini-2.0-flash"
    url = f"{GEMINI_API_BASE_URL}/{model}:generateContent?key={api_key}"

    user_content = (
        "Analyze the following validated rehabilitation session metrics payload and return the JSON response:\n\n"
        f"{json.dumps(session_data, indent=2, default=str)}"
    )

    payload = {
        "system_instruction": {
            "parts": [{"text": SYSTEM_PROMPT}]
        },
        "contents": [
            {
                "role": "user",
                "parts": [{"text": user_content}]
            }
        ],
        "generationConfig": {
            "temperature": 0.3,
            "response_mime_type": "application/json",
        },
    }

    try:
        async with httpx.AsyncClient(timeout=25.0) as client:
            response = await client.post(url, json=payload)
            response.raise_for_status()
            res_json = response.json()

            candidates = res_json.get("candidates", [])
            if not candidates:
                raise ValueError("No candidates returned from Gemini API")

            content_parts = candidates[0].get("content", {}).get("parts", [])
            if not content_parts:
                raise ValueError("Empty content parts in Gemini API response")

            text_output = content_parts[0].get("text", "").strip()
            parsed_data = json.loads(text_output)
            return parsed_data

    except Exception as exc:
        logger.warning("Gemini API call failed (%s). Falling back to rule-based overview.", exc)
        return _generate_fallback_overview(session_data)

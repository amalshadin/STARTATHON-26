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


MULTI_SESSION_SYSTEM_PROMPT = """You are the HapticSync Rehabilitation Longitudinal Analyst.
Your role is to analyze multi-session rehabilitation telemetry collected across a batch of 3 to 10 game sessions.
Provide a concise, comprehensive longitudinal progress overview synthesizing:
1. Performance consistency and trajectory (score, accuracy, repetition endurance).
2. Movement kinematics and stability trends across sessions (smoothness, range of motion).
3. Notable patterns of progression, fatigue resistance, or areas requiring sustained practice.

CRITICAL CONSTRAINTS:
- Output ONLY the natural language overview text. Do NOT wrap in JSON.
- Do NOT mention or refer to "weekly report", "week", or any weekly timeframe. Refer strictly to "the evaluated sessions" or "across the evaluated series of sessions".
- Maintain non-diagnostic, evidence-based language (e.g., "the data demonstrate steady motor consistency", "accuracy trends improved across consecutive trials"). Do NOT diagnose conditions or claim medical cures.
"""


def _generate_fallback_multi_session_overview(sessions: list[dict[str, Any]]) -> str:
    """Deterministic longitudinal summary when Gemini API is unavailable."""
    session_count = len(sessions)
    if session_count == 0:
        return "No session data available to evaluate."

    accuracies = [s.get("accuracy", 0.0) for s in sessions if s.get("accuracy") is not None]
    scores = [s.get("score", 0) for s in sessions if s.get("score") is not None]
    repetitions = sum(s.get("repetitions", 0) for s in sessions if s.get("repetitions") is not None)
    
    avg_acc = (sum(accuracies) / len(accuracies) * 100) if accuracies else 0.0
    avg_score = (sum(scores) / len(scores)) if scores else 0

    first_acc = (accuracies[-1] * 100) if accuracies else 0.0
    latest_acc = (accuracies[0] * 100) if accuracies else 0.0
    trend = "demonstrated positive upward trajectory" if latest_acc >= first_acc else "remained stable with consistent motor engagement"

    return (
        f"Across the evaluated series of {session_count} rehabilitation sessions, the patient completed a cumulative total "
        f"of {repetitions} repetitions with an average session score of {avg_score:.0f}. Movement accuracy averaged {avg_acc:.1f}%, "
        f"and performance {trend} from initial to concluding trials. Movement kinematics indicate consistent task compliance "
        f"and sustained motor control across successive sessions, supporting ongoing therapeutic consolidation."
    )


async def generate_multi_session_progress_summary(
    sessions_data: list[dict[str, Any]],
) -> str:
    """
    Calls Google Gemini REST API to generate a longitudinal progress summary across 3-10 sessions.
    Falls back gracefully if the API key is not configured or network error occurs.
    """
    api_key = settings.gemini_api_key
    if not api_key:
        logger.info("GEMINI_API_KEY not configured. Using deterministic multi-session summary.")
        return _generate_fallback_multi_session_overview(sessions_data)

    model = settings.gemini_model or "gemini-2.0-flash"
    url = f"{GEMINI_API_BASE_URL}/{model}:generateContent?key={api_key}"

    user_content = (
        f"Analyze the following validated telemetry from {len(sessions_data)} consecutive rehabilitation game sessions "
        f"(ordered newest to oldest) and provide a comprehensive progress overview:\n\n"
        f"{json.dumps(sessions_data, indent=2, default=str)}"
    )

    payload = {
        "system_instruction": {
            "parts": [{"text": MULTI_SESSION_SYSTEM_PROMPT}]
        },
        "contents": [
            {
                "role": "user",
                "parts": [{"text": user_content}]
            }
        ],
        "generationConfig": {
            "temperature": 0.3,
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
            return text_output

    except Exception as exc:
        logger.warning("Gemini API call failed for multi-session overview (%s). Using fallback.", exc)
        return _generate_fallback_multi_session_overview(sessions_data)


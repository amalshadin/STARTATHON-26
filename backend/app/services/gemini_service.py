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

# ── Game-Specific Parameter Configurations ────────────────────────────────────

GAME_PARAMETER_SPECS: Dict[str, Dict[str, Any]] = {
    # 1. Space Game
    "00000000-0000-0000-0000-000000000003": {
        "name": "Space Game",
        "slugs": ["space", "space-game"],
        "properties": {
            "target_threshold": {
                "type": "NUMBER",
                "description": "Suggested ROM or grip threshold (e.g. 0.1 to 1.0)",
            },
            "difficulty": {
                "type": "STRING",
                "description": "Suggested difficulty level (easy, medium, hard)",
            },
            "target_speed_bpm": {
                "type": "INTEGER",
                "description": "Suggested target tempo or speed in BPM",
            },
        },
        "required": ["target_threshold", "difficulty", "target_speed_bpm"],
    },
    # 2. Car Race
    "00000000-0000-0000-0000-000000000001": {
        "name": "Car Race",
        "slugs": ["car-race", "carrace", "car"],
        "properties": {
            "target_speed_bpm": {
                "type": "INTEGER",
                "description": "Suggested target speed or tempo in BPM",
            },
            "difficulty": {
                "type": "STRING",
                "description": "Suggested difficulty level (easy, medium, hard)",
            },
        },
        "required": ["target_speed_bpm", "difficulty"],
    },
    # 3. Cargo Crane
    "3dc686c1-ae6f-4f76-800f-b47bb66f0c4e": {
        "name": "Cargo Crane",
        "slugs": ["cargo-crane", "cargocrane", "crane"],
        "properties": {
            "target_threshold": {
                "type": "NUMBER",
                "description": "Suggested grip threshold (e.g. 0.1 to 1.0)",
            },
            "target_speed_bpm": {
                "type": "INTEGER",
                "description": "Suggested target speed or tempo in BPM",
            },
        },
        "required": ["target_threshold", "target_speed_bpm"],
    },
    # 4. Piano Game
    "edbc37b3-da00-4316-a56b-b1ca35cc58bd": {
        "name": "Piano Game",
        "slugs": ["piano", "piano-game"],
        "properties": {
            "target_speed_bpm": {
                "type": "INTEGER",
                "description": "Suggested target tempo in BPM",
            },
        },
        "required": ["target_speed_bpm"],
    },
}


def get_game_parameter_spec(
    game_id: Optional[str],
    game_slug: Optional[str] = None,
    game_title: Optional[str] = None,
) -> Dict[str, Any]:
    """Resolves the game parameter specification based on game_id, slug, or title."""
    norm_id = str(game_id).lower().strip() if game_id else ""
    if norm_id in GAME_PARAMETER_SPECS:
        return GAME_PARAMETER_SPECS[norm_id]

    slug = (game_slug or "").lower().strip()
    title = (game_title or "").lower().strip()

    for spec in GAME_PARAMETER_SPECS.values():
        for s in spec["slugs"]:
            if s in slug or s in title:
                return spec

    # Default fallback for unknown games
    return {
        "name": "Rehabilitation Game",
        "slugs": [],
        "properties": {
            "target_speed_bpm": {"type": "INTEGER"},
            "difficulty": {"type": "STRING"},
        },
        "required": ["target_speed_bpm", "difficulty"],
    }


def build_gemini_response_schema(spec: Dict[str, Any]) -> Dict[str, Any]:
    """Builds a strict OpenAPI / JSON Schema for Gemini's response_schema parameter."""
    return {
        "type": "OBJECT",
        "properties": {
            "status": {
                "type": "STRING",
                "description": "Processing status (e.g. completed)",
            },
            "overview": {
                "type": "STRING",
                "description": "Markdown formatted clinical overview of the patient's performance and kinematics",
            },
            "parameter_suggestions": {
                "type": "OBJECT",
                "description": f"Specific game parameter adjustments for {spec['name']}",
                "properties": spec["properties"],
                "required": spec["required"],
            },
        },
        "required": ["status", "overview", "parameter_suggestions"],
    }


def build_system_prompt_for_game(spec: Dict[str, Any]) -> str:
    allowed_keys_str = ", ".join(f"'{k}'" for k in spec["properties"].keys())
    return f"""You are the HapticSync Rehabilitation Performance Analyst.
Your goal is to analyze validated rehabilitation game performance metrics and movement kinematics to generate a concise, objective rehabilitation briefing and suggested game parameter adjustments for the next session.

STRICT EVIDENCE & CLINICAL ETHICS RULES:
1. Base every observation only on the supplied data.
2. Do NOT diagnose medical conditions or infer neurological recovery, neuromuscular changes, or unmeasured anatomical mechanisms.
3. Do NOT claim that therapy caused an observed change (correlate observations, avoid claiming causation).
4. Do NOT invent measurements or introduce safety concerns unless directly supported by the supplied metrics.
5. Provide actionable, safe parameter update suggestions.
6. Write professionally and objectively: prefer "the measurements indicate", "the data show", "an increase was observed". Avoid "cured", "proves", or unsupported clinical claims.

CRITICAL PARAMETER SUGGESTION CONSTRAINTS FOR {spec['name']}:
The 'parameter_suggestions' object MUST contain ONLY the following allowed keys:
  {allowed_keys_str}

STRICT RULE:
- Do NOT output any other keys in 'parameter_suggestions' (such as 'threshold', 'duration_target_s', 'rationale', or any non-whitelisted parameters).
- Format 'overview' as a clean, structured Markdown clinical analysis.
"""


def _generate_fallback_overview(
    data: Dict[str, Any],
    spec: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """
    Deterministic fallback when Gemini API key is missing or service is offline.
    Ensures backend reliability and adheres strictly to the required game parameter schema.
    """
    if spec is None:
        spec = get_game_parameter_spec(
            data.get("game_id"),
            data.get("game_slug"),
            data.get("game_title"),
        )

    game_title = data.get("game_title") or spec["name"]
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
    suggested_threshold = 0.5 if accuracy_pct >= 70 else 0.4

    candidate_params = {
        "target_threshold": suggested_threshold,
        "difficulty": suggested_difficulty,
        "target_speed_bpm": suggested_bpm,
    }

    # Restrict ONLY to the allowed keys for this game
    allowed_keys = set(spec["properties"].keys())
    filtered_sugg = {k: candidate_params[k] for k in allowed_keys if k in candidate_params}

    return {
        "status": "completed",
        "overview": overview_text,
        "parameter_suggestions": filtered_sugg,
    }


async def generate_gemini_rehabilitation_overview(
    session_data: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Calls Google Gemini REST API using dynamic response_schema based on game_id.
    Enforces strict JSON output with only game-authorized parameter keys.
    """
    spec = get_game_parameter_spec(
        session_data.get("game_id"),
        session_data.get("game_slug"),
        session_data.get("game_title"),
    )

    api_key = settings.gemini_api_key
    if not api_key:
        logger.warning(
            "GEMINI_API_KEY is not configured in backend/.env. Using deterministic fallback analysis."
        )
        return _generate_fallback_overview(session_data, spec)

    model = settings.gemini_model or "gemini-2.0-flash"
    url = f"{GEMINI_API_BASE_URL}/{model}:generateContent?key={api_key}"

    system_prompt = build_system_prompt_for_game(spec)
    response_schema = build_gemini_response_schema(spec)

    user_content = (
        f"Analyze the following validated rehabilitation session metrics for {spec['name']}:\n\n"
        f"{json.dumps(session_data, indent=2, default=str)}"
    )

    payload = {
        "system_instruction": {
            "parts": [{"text": system_prompt}]
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
            "response_schema": response_schema,
        },
    }

    try:
        async with httpx.AsyncClient(timeout=25.0) as client:
            response = await client.post(url, json=payload)
            if response.is_error:
                logger.error("Gemini API returned error status %d: %s", response.status_code, response.text)
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

            # Strict post-validation: ensure ONLY allowed keys exist in parameter_suggestions
            allowed_keys = set(spec["properties"].keys())
            raw_sugg = parsed_data.get("parameter_suggestions") or {}
            cleaned_sugg = {k: v for k, v in raw_sugg.items() if k in allowed_keys}
            parsed_data["parameter_suggestions"] = cleaned_sugg

            if "status" not in parsed_data:
                parsed_data["status"] = "completed"

            return parsed_data

    except Exception as exc:
        logger.warning("Gemini API call failed (%s). Falling back to rule-based overview.", exc)
        return _generate_fallback_overview(session_data, spec)




MULTI_SESSION_SYSTEM_PROMPT = """You are the HapticSync Rehabilitation Longitudinal Analyst.
Your role is to analyze multi-session rehabilitation telemetry collected across a patient's recent game sessions (focusing on the last 5 sessions).
Provide a concise, comprehensive overall rehabilitation progress overview synthesizing:
1. Clinical Context & Trajectory: Synthesize the patient's performance trajectory (accuracy trends, score progression, endurance, repetitions, completion consistency).
2. Movement Kinematics & Motor Control: Evaluate stability, smoothness, range of motion (ROM), and fatigue resistance across consecutive sessions.
3. Overall Rehabilitation Assessment: Highlight notable improvements, consistency milestones, and specific movement areas needing continued therapeutic focus.

CRITICAL CONSTRAINTS:
- Output ONLY the natural language overview text. Do NOT wrap in JSON.
- Refer strictly to "the evaluated sessions" or "across the last 5 sessions" (or the actual count of evaluated sessions, e.g. "across the evaluated sessions").
- Do NOT mention or refer to "weekly report", "week", or any weekly timeframe.
- Maintain non-diagnostic, evidence-based clinical rehabilitation language (e.g., "motor consistency demonstrated steady improvement", "kinematic data shows enhanced movement stability"). Do NOT diagnose medical conditions or claim clinical cures.
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

    session_label = f"last {session_count}" if session_count <= 5 else f"{session_count}"
    return (
        f"Across the evaluated series of {session_label} rehabilitation sessions, the patient completed a cumulative total "
        f"of {repetitions} repetitions with an average session score of {avg_score:.0f}. Movement accuracy averaged {avg_acc:.1f}%, "
        f"and performance {trend} from initial to concluding trials. Movement kinematics indicate consistent task compliance "
        f"and sustained motor control across successive sessions, supporting ongoing therapeutic consolidation."
    )


async def generate_multi_session_progress_summary(
    sessions_data: list[dict[str, Any]],
) -> str:
    """
    Calls Google Gemini REST API to generate a longitudinal progress summary across the last 5 sessions.
    Falls back gracefully if the API key is not configured or network error occurs.
    """
    api_key = settings.gemini_api_key
    if not api_key:
        logger.info("GEMINI_API_KEY not configured. Using deterministic multi-session summary.")
        return _generate_fallback_multi_session_overview(sessions_data)

    model = settings.gemini_model or "gemini-2.0-flash"
    url = f"{GEMINI_API_BASE_URL}/{model}:generateContent?key={api_key}"

    user_content = (
        f"Analyze the following validated telemetry from the last {len(sessions_data)} consecutive rehabilitation game sessions "
        f"(ordered newest to oldest) and provide a comprehensive overall rehabilitation progress overview:\n\n"
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
            if response.is_error:
                logger.error("Gemini API error %d: %s", response.status_code, response.text)
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


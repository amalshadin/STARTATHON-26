"""HapticSync rehabilitation overview node."""

from __future__ import annotations

import json
import os
import subprocess
import time
from collections import deque
from contextlib import asynccontextmanager
from typing import Any

import requests
import uvicorn
from fastapi import Depends, FastAPI, Header, HTTPException, Request, status
from pydantic import BaseModel, Field


# ============================================================
# CONFIGURATION
# ============================================================

PATH = r"C:\Users\Bharath\AppData\Local\Programs\Ollama\ollama.exe"

MODEL = "qwen3.5:9b"

# Keep the Python application talking to Ollama locally.
OLLAMA_URL = "http://127.0.0.1:11434"

# If this script has to start Ollama itself, request LAN binding.
OLLAMA_HOST = "0.0.0.0:11434"

OLLAMA_TIMEOUT_SECONDS = 10
GENERATION_TIMEOUT_SECONDS = 180

# FastAPI network interface.
API_HOST = "0.0.0.0"
API_PORT = 8000


# ============================================================
# SYSTEM PROMPT
# ============================================================

SYSTEM_PROMPT = """
You are the HapticSync Rehabilitation Performance Analyst.

Analyze validated rehabilitation performance metrics and generate a
natural-language rehabilitation briefing for a clinician or therapist.

The input contains derived rehabilitation metrics.
Raw sensor telemetry is NOT provided.

STRICT EVIDENCE RULES:

- Base every statement only on the supplied data.
- Do not diagnose medical conditions or infer neurological recovery,
  neuromuscular changes, physiological mechanisms, or unmeasured
  anatomical mechanisms.
- Do not claim that therapy caused an observed change.
- Do not invent measurements, observations, or events.
- Do not treat correlation as causation.
- Do not introduce safety concerns unless supported by supplied metrics.
- Do not make unsupported claims about why a measurement changed.
- Do not use "significant" unless significance is explicitly provided
  by the input.

Distinguish a baseline-to-current comparison from a longitudinal trend.
Only use the word "trend" when multiple sessions are actually supplied.

If ROM and peak velocity both increase:
say that measured ROM and peak velocity both increased.

If fatigue_velocity_drop_pct decreases:
say that the measured decline in velocity became smaller.

If fatigue_velocity_drop_pct increases:
say that the measured decline in velocity became larger.

If wrist compensation increases:
say that measured wrist compensation increased.
Do not infer why.

Use these sections when supported by the data:

Overall Progress
Movement Performance
Fatigue
Wrist Compensation
Strength and Finger Performance
Monitoring

Omit unsupported sections.

Write professionally, clearly, concisely, and in natural language.

Prefer phrases such as:
"the measurements show"
"the data indicate"
"an increase was observed"
"a decrease was observed"
"the current measurements"
"should continue to be monitored"

Avoid:
"proves"
"caused"
"confirms"
"the patient has recovered"
"neurological improvement"
"neuromuscular improvement"
"the therapy was effective"

Do not mention the AI model.

Do not show reasoning, drafts, self-checks, or analysis.

Return ONLY the final rehabilitation briefing as free-form text.
Do not return JSON.
"""


# ============================================================
# METRICS USED FOR BASELINE/CURRENT COMPARISON
# ============================================================

METRIC_NAMES = (
    "rom_deg",
    "peak_velocity_deg_s",
    "pinch_strength_n",
    "fatigue_velocity_drop_pct",
    "wrist_compensation_pct",
)


# ============================================================
# REQUEST SCHEMA
# ============================================================

class OverviewRequest(BaseModel):
    patient_id: str | None = Field(default=None, max_length=200)
    data: dict[str, Any]


# ============================================================
# GLOBAL STATE
# ============================================================

ollama_process: subprocess.Popen[bytes] | None = None

# Store the most recent client addresses for development/debugging.
# This is intentionally bounded so the list cannot grow forever.
recent_clients: deque[dict[str, Any]] = deque(maxlen=100)


# ============================================================
# OLLAMA HELPERS
# ============================================================

def ollama_is_reachable() -> bool:
    """Check whether the local Ollama API is available."""

    try:
        response = requests.get(
            f"{OLLAMA_URL}/api/tags",
            timeout=OLLAMA_TIMEOUT_SECONDS,
        )
        return response.ok

    except requests.RequestException:
        return False


def available_models() -> set[str]:
    """Return model names currently available in Ollama."""

    response = requests.get(
        f"{OLLAMA_URL}/api/tags",
        timeout=OLLAMA_TIMEOUT_SECONDS,
    )

    response.raise_for_status()

    return {
        str(model.get("name", ""))
        for model in response.json().get("models", [])
        if isinstance(model, dict)
    }


def model_is_available() -> bool:
    """Check whether the configured Qwen model exists."""

    try:
        return MODEL in available_models()

    except (requests.RequestException, ValueError, TypeError):
        return False


def start_ollama_if_needed() -> None:
    """
    Start Ollama only if an Ollama API is not already running.

    IMPORTANT:
    If Ollama is already running as a Windows application on localhost,
    this function will not restart it.
    """

    global ollama_process

    if ollama_is_reachable():
        print("Ollama is already running.")
        return

    if not os.path.isfile(PATH):
        raise RuntimeError(
            f"Ollama executable not found:\n{PATH}"
        )

    environment = os.environ.copy()

    # Request LAN binding when this script starts Ollama.
    environment["OLLAMA_HOST"] = OLLAMA_HOST

    # Keep the AI service local/cloud-independent.
    environment["OLLAMA_NO_CLOUD"] = "1"

    print("Starting Ollama...")

    try:
        ollama_process = subprocess.Popen(
            [PATH, "serve"],
            env=environment,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=getattr(
                subprocess,
                "CREATE_NO_WINDOW",
                0,
            ),
        )

    except OSError as exc:
        raise RuntimeError(
            f"Failed to start Ollama: {exc}"
        ) from exc


def wait_for_ollama() -> bool:
    """Wait for the Ollama API to become available."""

    start_ollama_if_needed()

    deadline = time.monotonic() + OLLAMA_TIMEOUT_SECONDS

    while time.monotonic() < deadline:

        if ollama_is_reachable():
            return True

        time.sleep(0.5)

    return False


# ============================================================
# DATA PROCESSING
# ============================================================

def calculate_changes(
    data: dict[str, Any],
) -> dict[str, float]:
    """
    Calculate deterministic baseline -> current percentage changes.

    The LLM receives these values and interprets them.
    It does not need to perform the arithmetic itself.
    """

    baseline = data.get("baseline")
    current = data.get("current")

    if not isinstance(baseline, dict):
        return {}

    if not isinstance(current, dict):
        return {}

    changes: dict[str, float] = {}

    for metric in METRIC_NAMES:

        baseline_value = baseline.get(metric)
        current_value = current.get(metric)

        if (
            not isinstance(baseline_value, (int, float))
            or isinstance(baseline_value, bool)
        ):
            continue

        if (
            not isinstance(current_value, (int, float))
            or isinstance(current_value, bool)
        ):
            continue

        if baseline_value == 0:
            continue

        change = (
            (current_value - baseline_value)
            / baseline_value
            * 100
        )

        changes[metric] = round(change, 2)

    return changes


def build_prompt(request: OverviewRequest) -> str:
    """Build the user prompt sent to Qwen."""

    derived_data = dict(request.data)

    derived_data["calculated_changes"] = calculate_changes(
        request.data
    )

    return (
        "Generate the HapticSync rehabilitation briefing from this "
        "validated derived-metrics payload.\n\n"
        "The values inside calculated_changes represent percentage "
        "changes from baseline to current.\n\n"
        f"{json.dumps(derived_data, indent=2, ensure_ascii=True)}"
    )


# ============================================================
# API KEY
# ============================================================

def require_api_key(
    x_api_key: str | None = Header(default=None),
) -> None:
    """
    Optional development API-key protection.

    If HAPTICSYNC_API_KEY is configured, callers must provide
    the same value in X-API-Key.
    """

    configured_key = os.getenv("HAPTICSYNC_API_KEY")

    # Development mode: no API key configured.
    if not configured_key:
        return

    if x_api_key != configured_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key",
        )


# ============================================================
# CLIENT INFORMATION
# ============================================================

def get_client_info(request: Request) -> dict[str, Any]:
    """
    Obtain the IP address and source port of the HTTP client.

    For direct LAN connections, request.client contains the
    actual TCP peer address.
    """

    client = request.client

    if client is None:
        return {
            "ip": None,
            "port": None,
        }

    return {
        "ip": client.host,
        "port": client.port,
    }


def store_client_info(
    request: Request,
) -> dict[str, Any]:
    """
    Store client information for development/debugging.

    The last 100 clients are retained in memory.
    """

    client_info = get_client_info(request)

    entry = {
        "ip": client_info["ip"],
        "port": client_info["port"],
        "timestamp": time.time(),
    }

    recent_clients.append(entry)

    return client_info


# ============================================================
# LLM GENERATION
# ============================================================

def generate_overview(prompt: str) -> str:
    """Send the HapticSync data to Qwen through Ollama."""

    # Check Ollama every time instead of relying on a stale startup flag.
    if not ollama_is_reachable():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Ollama is unavailable.",
        )

    if not model_is_available():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                f"Model {MODEL!r} is unavailable. "
                f"Run: ollama pull {MODEL}"
            ),
        )

    payload = {
        "model": MODEL,

        "system": SYSTEM_PROMPT,

        "prompt": prompt,

        # We want only the generated briefing.
        "think": False,

        "stream": False,

        # Keep the model loaded for repeated requests.
        "keep_alive": "10m",

        "options": {
            "temperature": 0.7,
            "top_p": 0.8,
            "top_k": 20,
            "presence_penalty": 1.5,

            # Keep memory usage reasonable.
            "num_ctx": 4096,
        },
    }

    try:
        response = requests.post(
            f"{OLLAMA_URL}/api/generate",
            json=payload,
            timeout=GENERATION_TIMEOUT_SECONDS,
        )

        response.raise_for_status()

        result = response.json()

        overview_text = (
            result
            .get("response", "")
            .strip()
        )

    except requests.RequestException as error:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Ollama generation failed: {error}",
        ) from error

    except (ValueError, TypeError) as error:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Invalid response from Ollama: {error}",
        ) from error

    if not overview_text:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Ollama returned an empty overview.",
        )

    return overview_text


# ============================================================
# FASTAPI LIFESPAN
# ============================================================

@asynccontextmanager
async def lifespan(_: FastAPI):
    """
    Start/check Ollama when the FastAPI application starts.
    """

    ready = wait_for_ollama()

    if ready:
        print("Ollama is ready.")

        if model_is_available():
            print(f"Model available: {MODEL}")
        else:
            print(
                f"WARNING: Model {MODEL!r} is not available."
            )
            print(
                f"Run: ollama pull {MODEL}"
            )

    else:
        print(
            "WARNING: Ollama did not become available during startup."
        )

    yield

    # Only terminate the Ollama process if this Python script started it.
    global ollama_process

    if ollama_process is not None:
        print("Stopping Ollama...")

        try:
            ollama_process.terminate()

        except OSError:
            pass


# ============================================================
# APPLICATION
# ============================================================

app = FastAPI(
    title="HapticSync LLM Node",
    version="1.0.0",
    description=(
        "Local Qwen3.5-9B rehabilitation overview service."
    ),
    lifespan=lifespan,
)


# ============================================================
# HEALTH
# ============================================================

@app.get("/health")
def health() -> dict[str, Any]:
    """Health-check endpoint."""

    reachable = ollama_is_reachable()

    model_available = (
        reachable and model_is_available()
    )

    return {
        "status": "ok",
        "ollama": reachable,
        "model": MODEL,
        "model_available": model_available,
        "recent_clients": len(recent_clients),
    }


# ============================================================
# DEBUG CLIENT ENDPOINT
# ============================================================

@app.get("/clients")
def clients() -> dict[str, Any]:
    """
    Development endpoint showing recently seen clients.

    Do not expose this endpoint publicly in production.
    """

    return {
        "clients": list(recent_clients),
    }


# ============================================================
# OVERVIEW
# ============================================================

@app.post(
    "/overview",
    dependencies=[Depends(require_api_key)],
)
def overview(
    request: OverviewRequest,
    http_request: Request,
) -> dict[str, Any]:
    """
    Generate a rehabilitation overview.

    The response automatically travels back over the same HTTP/TCP
    connection that sent the request.
    """

    # --------------------------------------------------------
    # Capture client address
    # --------------------------------------------------------

    client_info = store_client_info(http_request)

    print(
        f"[REQUEST] /overview "
        f"from {client_info['ip']}:{client_info['port']}"
    )

    # --------------------------------------------------------
    # Build prompt
    # --------------------------------------------------------

    prompt = build_prompt(request)

    # --------------------------------------------------------
    # Generate report
    # --------------------------------------------------------

    report = generate_overview(prompt)

    # --------------------------------------------------------
    # Return response
    # --------------------------------------------------------

    print(
        f"[RESPONSE] /overview "
        f"to {client_info['ip']}:{client_info['port']}"
    )

    return {
        "patient_id": request.patient_id,
        "model": MODEL,
        "overview": report,

        # Useful during development.
        "client": {
            "ip": client_info["ip"],
            "port": client_info["port"],
        },
    }


# ============================================================
# ENTRY POINT
# ============================================================

if __name__ == "__main__":

    print("=" * 60)
    print("HAPTICSYNC LLM NODE")
    print("=" * 60)

    print(f"Model:       {MODEL}")
    print(f"Ollama:      {OLLAMA_URL}")
    print(f"FastAPI:     http://{API_HOST}:{API_PORT}")

    print()
    print("Endpoints:")
    print("  GET  /health")
    print("  GET  /clients")
    print("  POST /overview")

    print()
    print("Starting server...")
    print("=" * 60)

    uvicorn.run(
        app,
        host=API_HOST,
        port=API_PORT,
    )
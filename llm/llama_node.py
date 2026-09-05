"""HapticSync rehabilitation overview node."""

from __future__ import annotations

import json
import os
import subprocess
import time
from contextlib import asynccontextmanager
from typing import Any

import requests
import uvicorn
from fastapi import Depends, FastAPI, Header, HTTPException, status
from pydantic import BaseModel, Field


PATH = r"C:\Users\Bharath\AppData\Local\Programs\Ollama\ollama.exe"
MODEL = "qwen3.5:9b"
OLLAMA_URL = "http://127.0.0.1:11434"
OLLAMA_HOST = "0.0.0.0:11434"
OLLAMA_TIMEOUT_SECONDS = 10
GENERATION_TIMEOUT_SECONDS = 180

SYSTEM_PROMPT = """You are the HapticSync Rehabilitation Performance Analyst.

Analyze validated rehabilitation performance metrics and generate a natural-language
rehabilitation briefing for a clinician or therapist.

The input contains derived rehabilitation metrics. Raw sensor telemetry is NOT provided.

STRICT EVIDENCE RULES:
- Base every statement only on the supplied data.
- Do not diagnose medical conditions or infer neurological recovery, neuromuscular changes,
  physiological mechanisms, or unmeasured anatomical mechanisms.
- Do not claim that therapy caused an observed change.
- Do not invent measurements, observations, or events, and do not treat correlation as causation.
- Do not introduce safety concerns unless supported by supplied metrics.
- Distinguish a baseline-to-current comparison from a longitudinal trend. Only use the word
  "trend" when multiple sessions are actually supplied.

If ROM and peak velocity both increase, say that measured ROM and peak velocity both increased.
If fatigue velocity drop decreases, say that the measured decline in velocity became smaller.
If fatigue_velocity_drop_pct increases, say that the measured decline in velocity increased;
do not describe an increase as a decrease. If wrist compensation increases, say that measured
wrist compensation increased. Do not infer why.

Use these sections when supported by the data: Overall Progress, Movement Performance, Fatigue,
Wrist Compensation, Strength and Finger Performance, and Monitoring. Omit unsupported sections.

Write professionally, clearly, concisely, and in natural language. Prefer phrases such as
"the measurements show", "the data indicate", "an increase was observed", and
"should continue to be monitored". Avoid "proves", "caused", "confirms", "the patient has
recovered", "neurological improvement", "neuromuscular improvement", "the therapy was effective",
and unsupported qualifiers such as "significant".

Do not mention the AI model. Do not show reasoning, drafts, self-checks, or analysis.
Return ONLY the final rehabilitation briefing as free-form text, not JSON.
"""

METRIC_NAMES = (
	"rom_deg",
	"peak_velocity_deg_s",
	"pinch_strength_n",
	"fatigue_velocity_drop_pct",
	"wrist_compensation_pct",
)


class OverviewRequest(BaseModel):
	patient_id: str | None = Field(default=None, max_length=200)
	data: dict[str, Any]


ollama_process: subprocess.Popen[bytes] | None = None
ollama_ready = False


def ollama_is_reachable() -> bool:
	try:
		response = requests.get(f"{OLLAMA_URL}/api/tags", timeout=OLLAMA_TIMEOUT_SECONDS)
		return response.ok
	except requests.RequestException:
		return False


def available_models() -> set[str]:
	response = requests.get(f"{OLLAMA_URL}/api/tags", timeout=OLLAMA_TIMEOUT_SECONDS)
	response.raise_for_status()
	return {
		str(model.get("name", ""))
		for model in response.json().get("models", [])
		if isinstance(model, dict)
	}


def model_is_available() -> bool:
	try:
		return MODEL in available_models()
	except (requests.RequestException, ValueError, TypeError):
		return False


def start_ollama_if_needed() -> None:
	"""Start Ollama only when an existing service is absent."""
	global ollama_process

	if ollama_is_reachable() or not os.path.isfile(PATH):
		return
	environment = os.environ.copy()
	environment["OLLAMA_HOST"] = OLLAMA_HOST
	environment["OLLAMA_NO_CLOUD"] = "1"
	ollama_process = subprocess.Popen(
		[PATH, "serve"],
		env=environment,
		stdout=subprocess.DEVNULL,
		stderr=subprocess.DEVNULL,
		creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
	)


def wait_for_ollama() -> bool:
	start_ollama_if_needed()
	deadline = time.monotonic() + OLLAMA_TIMEOUT_SECONDS
	while time.monotonic() < deadline:
		if ollama_is_reachable():
			return True
		time.sleep(0.5)
	return False


def calculate_changes(data: dict[str, Any]) -> dict[str, float]:
	baseline = data.get("baseline")
	current = data.get("current")
	if not isinstance(baseline, dict) or not isinstance(current, dict):
		return {}

	changes: dict[str, float] = {}
	for metric in METRIC_NAMES:
		baseline_value = baseline.get(metric)
		current_value = current.get(metric)
		if not isinstance(baseline_value, (int, float)) or isinstance(baseline_value, bool):
			continue
		if not isinstance(current_value, (int, float)) or isinstance(current_value, bool):
			continue
		if baseline_value == 0:
			continue
		changes[metric] = round(((current_value - baseline_value) / baseline_value) * 100, 2)
	return changes


def build_prompt(request: OverviewRequest) -> str:
	derived_data = dict(request.data)
	derived_data["calculated_changes"] = calculate_changes(request.data)
	return (
		"Generate the rehabilitation briefing from this validated derived-metrics payload. "
		"The calculated_changes values are percentage changes from baseline to current.\n\n"
		f"{json.dumps(derived_data, indent=2, ensure_ascii=True)}"
	)


def require_api_key(x_api_key: str | None = Header(default=None)) -> None:
	configured_key = os.getenv("HAPTICSYNC_API_KEY")
	if configured_key and x_api_key != configured_key:
		raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid API key")


def generate_overview(prompt: str) -> str:
	if not ollama_ready or not model_is_available():
		raise HTTPException(
			status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
			detail=f"Ollama or model {MODEL!r} is unavailable. Start Ollama and run: ollama pull {MODEL}",
		)

	payload = {
		"model": MODEL,
		"system": SYSTEM_PROMPT,
		"prompt": prompt,
		"stream": False,
		"keep_alive": "10m",
		"think": False,
		"options": {
			"temperature": 0.7,
			"top_p": 0.8,
			"top_k": 20,
			"presence_penalty": 1.5,
			"num_ctx": 4096,
		},
	}
	try:
		response = requests.post(
			f"{OLLAMA_URL}/api/generate", json=payload, timeout=GENERATION_TIMEOUT_SECONDS
		)
		response.raise_for_status()
		overview_text = response.json().get("response", "").strip()
	except (requests.RequestException, ValueError, TypeError) as error:
		raise HTTPException(status_code=502, detail=f"Ollama generation failed: {error}") from error

	if not overview_text:
		raise HTTPException(status_code=502, detail="Ollama returned an empty overview")
	return overview_text


@asynccontextmanager
async def lifespan(_: FastAPI):
	global ollama_ready
	ollama_ready = wait_for_ollama()
	yield


app = FastAPI(title="HapticSync LLM Node", version="1.0.0", lifespan=lifespan)


@app.get("/health")
def health() -> dict[str, Any]:
	reachable = ollama_is_reachable()
	return {"status": "ok", "ollama": reachable and model_is_available(), "model": MODEL}


@app.post("/overview", dependencies=[Depends(require_api_key)])
def overview(request: OverviewRequest) -> dict[str, str | None]:
	return {
		"patient_id": request.patient_id,
		"model": MODEL,
		"overview": generate_overview(build_prompt(request)),
	}


if __name__ == "__main__":
	uvicorn.run(app, host="0.0.0.0", port=8000)
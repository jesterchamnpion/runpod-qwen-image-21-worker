import copy
import importlib.util
import json
import secrets

import runpod


def _load_base_handler():
    spec = importlib.util.spec_from_file_location("worker_comfyui_base", "/handler_base.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


BASE = _load_base_handler()

with open("/qwen-image-21-workflow.json", "r", encoding="utf-8") as handle:
    WORKFLOW_TEMPLATE = json.load(handle)


def _bounded_int(value, *, name, minimum, maximum, multiple=None):
    try:
        parsed = int(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{name} must be an integer") from exc
    if not minimum <= parsed <= maximum:
        raise ValueError(f"{name} must be between {minimum} and {maximum}")
    if multiple and parsed % multiple:
        raise ValueError(f"{name} must be a multiple of {multiple}")
    return parsed


def _simple_workflow(job_input):
    prompt = job_input.get("prompt")
    if not isinstance(prompt, str) or not prompt.strip():
        raise ValueError("provide a non-empty 'prompt'")

    negative_prompt = job_input.get("negative_prompt", "")
    if not isinstance(negative_prompt, str):
        raise ValueError("negative_prompt must be a string")

    width = _bounded_int(job_input.get("width", 1024), name="width", minimum=256, maximum=2048, multiple=32)
    height = _bounded_int(job_input.get("height", 1024), name="height", minimum=256, maximum=2048, multiple=32)
    steps = _bounded_int(job_input.get("steps", 25), name="steps", minimum=1, maximum=50)
    seed = _bounded_int(
        job_input.get("seed", secrets.randbelow(2**63 - 1)),
        name="seed",
        minimum=0,
        maximum=2**63 - 1,
    )

    workflow = copy.deepcopy(WORKFLOW_TEMPLATE)
    workflow["4"]["inputs"]["prompt"] = prompt.strip()
    workflow["4"]["inputs"]["negative_prompt"] = negative_prompt
    workflow["4"]["inputs"]["resolution"] = max(width, height)
    workflow["5"]["inputs"]["width"] = width
    workflow["5"]["inputs"]["height"] = height
    workflow["7"]["inputs"]["seed"] = seed
    workflow["7"]["inputs"]["steps"] = steps
    return workflow


def handler(job):
    job_input = job.get("input") or {}
    if "workflow" in job_input:
        return BASE.handler(job)

    try:
        workflow = _simple_workflow(job_input)
    except ValueError as exc:
        return {"error": str(exc)}

    delegated_job = dict(job)
    delegated_job["input"] = {"workflow": workflow}
    return BASE.handler(delegated_job)


if __name__ == "__main__":
    print("qwen-image-worker: starting simplified Runpod handler")
    runpod.serverless.start({"handler": handler})

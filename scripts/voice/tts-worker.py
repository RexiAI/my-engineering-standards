#!/usr/bin/env python3
"""Streaming, cancellable speech worker driven over JSONL on stdin/stdout.

The silent engine is the CI path: it imports no third-party module and
synthesises a valid WAV from text alone. The pocket-tts engine is loaded lazily;
when it is absent the worker reports missing-runtime and exits 3. The worker
never opens an audio device and writes only the `out` path it is given.
"""
import argparse
import importlib.util
import json
import signal
import sys
import threading
import time
import wave

DEFAULT_SAMPLE_RATE = 24000
CHUNK_SECONDS = 0.05
SECONDS_PER_CHAR = 0.02
MIN_SECONDS = 0.1

_write_lock = threading.Lock()
_requests_lock = threading.Lock()
_requests = {}
_shutdown = threading.Event()
_exit_code = 0


def emit(payload):
    with _write_lock:
        sys.stdout.write(json.dumps(payload) + "\n")
        sys.stdout.flush()


def available(module_name):
    try:
        return importlib.util.find_spec(module_name) is not None
    except (ImportError, ValueError):
        return False


def bad_request(request_id, message):
    emit({"id": request_id, "event": "error", "code": "bad-request", "message": message})


def frame_count(text, sample_rate):
    seconds = max(MIN_SECONDS, len(text) * SECONDS_PER_CHAR)
    return max(1, int(seconds * sample_rate))


def write_chunk(handle, job, cancel):
    step = max(1, int(job["sampleRate"] * CHUNK_SECONDS))
    written = 0
    while written < job["frames"]:
        if cancel.is_set() or _shutdown.is_set():
            return written, True
        size = min(step, job["frames"] - written)
        handle.writeframes(b"\x00\x00" * size)
        written += size
        emit({"id": job["id"], "event": "chunk", "bytes": size * 2})
        time.sleep(0.005)
    return written, False


def synthesise_silent(request_id, request, sample_rate, cancel):
    text = request["text"]
    total = frame_count(text, sample_rate)
    path = request["out"]
    job = {"id": request_id, "frames": total, "sampleRate": sample_rate}
    emit({"id": request_id, "event": "start"})
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(sample_rate)
        written, cancelled = write_chunk(handle, job, cancel)
    emit({
        "id": request_id,
        "event": "done",
        "path": path,
        "durationMs": written * 1000.0 / sample_rate,
        "sampleRate": sample_rate,
        "cancelled": cancelled,
    })


def run_engine(engine, request, sample_rate, cancel):
    global _exit_code
    if engine != "pocket-tts":
        synthesise_silent(request["id"], request, sample_rate, cancel)
        return
    emit({"id": request["id"], "event": "error", "code": "missing-runtime",
          "message": "pocket_tts is not importable"})
    _exit_code = 3
    _shutdown.set()


def validate(request):
    if not isinstance(request, dict):
        return "request must be a JSON object"
    if not request.get("id"):
        return "missing id"
    if not request.get("text"):
        return "empty text"
    if not request.get("out"):
        return "missing out"
    return None


def process(request, engine, sample_rate):
    request_id = request.get("id")
    problem = validate(request)
    if problem is not None:
        bad_request(request_id, problem)
        return
    cancel = threading.Event()
    with _requests_lock:
        _requests[request_id] = cancel
    try:
        run_engine(engine, request, sample_rate, cancel)
    finally:
        with _requests_lock:
            _requests.pop(request_id, None)


def handle_line(line, engine, sample_rate, threads):
    try:
        message = json.loads(line)
    except json.JSONDecodeError:
        bad_request(None, "invalid JSON")
        return
    if message.get("event") == "cancel":
        with _requests_lock:
            cancel = _requests.get(message.get("id"))
        if cancel is not None:
            cancel.set()
        return
    thread = threading.Thread(target=process, args=(message, engine, sample_rate), daemon=True)
    thread.start()
    threads.append(thread)


def cancel_all():
    with _requests_lock:
        for cancel in _requests.values():
            cancel.set()


def read_requests(args, threads):
    try:
        for line in sys.stdin:
            if not line.strip():
                continue
            handle_line(line, args.engine, args.sample_rate, threads)
            if _shutdown.is_set():
                break
    except KeyboardInterrupt:
        cancel_all()


def run(args):
    if args.self_check:
        emit({
            "python": sys.version.split()[0],
            "pocket_tts": available("pocket_tts"),
            "torch": available("torch"),
            "sample_rate": args.sample_rate,
        })
        return 0
    threads = []
    read_requests(args, threads)
    for thread in threads:
        thread.join(timeout=1.0)
    return _exit_code


def parse_args(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-check", action="store_true")
    parser.add_argument("--engine", choices=["silent", "pocket-tts"], default="pocket-tts")
    parser.add_argument("--sample-rate", type=int, default=DEFAULT_SAMPLE_RATE)
    return parser.parse_args(argv)


def main():
    signal.signal(signal.SIGINT, signal.default_int_handler)
    return run(parse_args(sys.argv[1:]))


if __name__ == "__main__":
    sys.exit(main())

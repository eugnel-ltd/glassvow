"""Bounded subprocess groups for CI builds, Xvfb wrappers and native engines."""
import os
import signal
import subprocess


def terminate_group(process):
    # A leader can exit while its compiler/Xvfb children are still running.
    # Always address the original group, even when process.poll() is non-null.
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        process.wait(timeout=3)
        return
    try:
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        pass
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    process.wait(timeout=3)


def run_logged(command, log, timeout, cwd=None, env=None):
    with log.open("w") as stream:
        process = subprocess.Popen(command, cwd=cwd, env=env, stdout=stream,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            returncode = process.wait(timeout=timeout)
            if returncode:
                raise subprocess.CalledProcessError(returncode, command)
        finally:
            terminate_group(process)

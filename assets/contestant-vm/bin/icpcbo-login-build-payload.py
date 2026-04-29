#!/usr/bin/env python3

import json
import os
import sys


def read_machine_id() -> str:
    if os.path.exists("/etc/machine-id"):
        with open("/etc/machine-id", encoding="utf-8") as fh:
            return fh.read().strip() or "unknown"
    return "unknown"


def main() -> None:
    payload = {
        "username": sys.argv[1],
        "password": sys.argv[2],
        "machineId": read_machine_id(),
    }
    print(json.dumps(payload, ensure_ascii=False))


if __name__ == "__main__":
    main()

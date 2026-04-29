#!/usr/bin/env python3

import json
import shlex
import sys


def main() -> None:
    response_file = sys.argv[1]
    http_code = int(sys.argv[2])
    username = sys.argv[3]
    raw = ""

    try:
        with open(response_file, encoding="utf-8") as fh:
            raw = fh.read()
    except FileNotFoundError:
        pass

    ok = False
    message = ""
    user_id = username
    display_name = username

    if 200 <= http_code < 300:
        try:
            data = json.loads(raw or "{}")
        except json.JSONDecodeError:
            message = "El servicio respondió con un formato JSON inválido."
        else:
            ok_value = data.get("ok", data.get("valid"))
            if ok_value is None:
                ok_value = str(data.get("status", "")).lower() in {
                    "ok",
                    "success",
                    "valid",
                }

            ok = bool(ok_value)
            message = str(data.get("message") or data.get("detail") or "")
            user_id = str(
                data.get("userId")
                or data.get("user_id")
                or data.get("id")
                or username
            )
            display_name = str(
                data.get("displayName")
                or data.get("display_name")
                or data.get("name")
                or username
            )
    else:
        message = f"El servicio respondió con HTTP {http_code}."

    if not ok and not message:
        message = "Las credenciales no fueron aceptadas."

    print(f"AUTH_OK={shlex.quote('1' if ok else '0')}")
    print(f"AUTH_MESSAGE={shlex.quote(message)}")
    print(f"AUTH_USER_ID={shlex.quote(user_id)}")
    print(f"AUTH_DISPLAY_NAME={shlex.quote(display_name)}")


if __name__ == "__main__":
    main()

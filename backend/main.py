import argparse
import asyncio
import os


kira_logo = r"""
      _  ___              _    ___ 
     | |/ (_)_ __ __ _   / \  |_ _|
     | ' /| | '__/ _` | / _ \  | | 
     | . \| | | | (_| |/ ___ \ | | 
     |_|\_\_|_|  \__,_/_/   \_\___|
"""


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="KiraAI",
        description="KiraAI",
    )
    parser.add_argument(
        "--data-dir",
        type=str,
        default=None,
        help="Override the data directory (default: <cwd>/data)",
    )
    parser.add_argument(
        "--webui-dir",
        type=str,
        default=None,
        help="Override the frontend dist directory (default: <data-dir>/dist)",
    )
    parser.add_argument(
        "--ignore-webui-version-check",
        action="store_true",
        default=False,
        help="Skip frontend dist version check (useful during development with --webui-dir)",
    )
    return parser.parse_args()


if __name__ == "__main__":
    # set script dir as working dir
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)

    # detect Electron packaged environment (case-insensitive: "resources" on
    # Windows/Linux, "Resources" on macOS)
    parent_dir = os.path.dirname(script_dir)
    is_packaged = os.path.basename(parent_dir).lower() == "resources"

    _packaged_data_dir = None
    _packaged_webui_dir = None

    # Data dir priority: --data-dir CLI > KIRAAI_DATA_DIR env > legacy
    # per-platform fallback. The env var is set by Electron (main.js) so the
    # backend writes to the standard OS location instead of inside the .app
    # bundle. The legacy fallback exists only for backward compatibility with
    # older Windows installs that didn't set the env var.
    env_data_dir = os.environ.get("KIRAAI_DATA_DIR")
    if env_data_dir:
        _packaged_data_dir = env_data_dir

    if is_packaged and _packaged_data_dir is None:
        appdata = os.environ.get("LOCALAPPDATA", os.path.expanduser("~"))
        _packaged_data_dir = os.path.join(appdata, "kiraAI-DeskTop")

    # webui dist is downloaded at runtime; let it default to <data_dir>/dist
    # so it lands in the user-writable data directory, not the read-only bundle.

    # parse CLI args and apply path overrides
    args = _parse_args()
    from core.utils.path_utils import init_paths, get_data_path

    init_paths(
        data_dir=args.data_dir if args.data_dir else _packaged_data_dir,
        webui_dir=args.webui_dir if args.webui_dir else _packaged_webui_dir,
    )

    sub_data_folders = ["config", "memory", "plugins", "files", "temp", "sticker", "skills"]
    for folder in sub_data_folders:
        os.makedirs(get_data_path() / folder, exist_ok=True)

    # init logging
    from core.logging_manager import get_logger
    logger = get_logger("launcher", "blue")

    for logo_line in kira_logo.split("\n"):
        logger.info(logo_line)

    logger.info(f"Set working dir: {script_dir}")
    if args.data_dir:
        logger.info(f"Using data dir override: {args.data_dir}")
    if args.webui_dir:
        logger.info(f"Using webui dir override: {args.webui_dir}")

    from core.launcher import KiraLauncher

    launcher = KiraLauncher(ignore_webui_version_check=args.ignore_webui_version_check)

    try:
        asyncio.run(launcher.start())
    except KeyboardInterrupt:
        pass

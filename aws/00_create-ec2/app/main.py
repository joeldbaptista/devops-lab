"""CLI application that prints a timestamp once per iteration."""

import argparse
import sys
import time
from datetime import datetime, timezone

SLEEP_SECONDS = 10


def positive_int(value):
    """Parse a command line argument as an integer greater than zero."""
    try:
        number = int(value)
    except ValueError:
        raise argparse.ArgumentTypeError(f"{value!r} is not an integer")
    if number < 1:
        raise argparse.ArgumentTypeError(f"{number} is not greater than zero")
    return number


def parse_args(argv=None):
    parser = argparse.ArgumentParser(
        description=(
            "Print the current timestamp, wait "
            f"{SLEEP_SECONDS} seconds, and repeat."
        )
    )
    parser.add_argument(
        "iterations",
        type=positive_int,
        help="number of timestamps to print",
    )
    return parser.parse_args(argv)


def run(iterations, sleep_seconds=SLEEP_SECONDS):
    """Print one timestamp per iteration, sleeping between iterations."""
    for iteration in range(1, iterations + 1):
        timestamp = datetime.now(timezone.utc).isoformat(timespec="seconds")
        print(f"{iteration}/{iterations} {timestamp}", flush=True)
		time.sleep(sleep_seconds)


def main(argv=None):
    args = parse_args(argv)
    try:
        run(args.iterations)
    except KeyboardInterrupt:
        return 130
    return 0


if __name__ == "__main__":
    sys.exit(main())

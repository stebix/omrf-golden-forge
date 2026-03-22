"""Structured logging setup with rich console and JSON file output."""

import logging
import sys
from pathlib import Path

import structlog


def setup_logging(
    *,
    console_level: str = 'INFO',
    log_file: Path | None = None,
    file_level: str = 'DEBUG',
) -> None:
    """Configure structured logging for the golden data pipeline.

    Console output uses structlog's ``ConsoleRenderer`` which leverages
    ``rich`` for colorized, human-readable output. File output uses JSON
    Lines format for machine-parseable records.

    Call once at program startup before any logging.
    """
    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.stdlib.add_log_level,
            structlog.processors.TimeStamper(fmt='iso'),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.UnicodeDecoder(),
            structlog.stdlib.ProcessorFormatter.wrap_for_formatter,
        ],
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )

    root = logging.getLogger()
    root.setLevel('DEBUG')
    root.handlers.clear()

    # Console: human-readable, colorized via rich
    console = logging.StreamHandler(sys.stderr)
    console.setLevel(console_level.upper())
    console.setFormatter(
        structlog.stdlib.ProcessorFormatter(
            processors=[
                structlog.stdlib.ProcessorFormatter.remove_processors_meta,
                structlog.dev.ConsoleRenderer(),
            ],
        )
    )
    root.addHandler(console)

    # File: JSON Lines for machine consumption
    if log_file is not None:
        log_file.parent.mkdir(parents=True, exist_ok=True)
        fh = logging.FileHandler(log_file)
        fh.setLevel(file_level.upper())
        fh.setFormatter(
            structlog.stdlib.ProcessorFormatter(
                processors=[
                    structlog.stdlib.ProcessorFormatter.remove_processors_meta,
                    structlog.processors.format_exc_info,
                    structlog.processors.JSONRenderer(),
                ],
            )
        )
        root.addHandler(fh)

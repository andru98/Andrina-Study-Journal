import logging
import os
from datetime import datetime


def get_logger(name: str) -> logging.Logger:
    # Create logs folder if it doesn't exist
    os.makedirs("logs", exist_ok=True)

    # Create logger
    logger = logging.getLogger(name)
    logger.setLevel(logging.DEBUG)

    # Create formatter
    formatter = logging.Formatter(
        "%(asctime)s | %(levelname)s | %(name)s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )

    # Terminal handler - shows INFO and above
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(formatter)

    # File handler - captures everything including DEBUG
    log_filename = f"logs/pipeline_{datetime.now().strftime('%Y%m%d')}.log"
    file_handler = logging.FileHandler(log_filename)
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(formatter)

    # Add both handlers
    logger.addHandler(console_handler)
    logger.addHandler(file_handler)

    return logger
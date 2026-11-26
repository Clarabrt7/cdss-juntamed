"""Configurações de conexão com o PostgreSQL e caminhos das fontes de dados."""

import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_RAW_DIR = BASE_DIR / "data" / "raw"
DATA_PROCESSED_DIR = BASE_DIR / "data" / "processed"

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": int(os.getenv("DB_PORT", "5432")),
    "dbname": os.getenv("DB_NAME", "cdss_juntamed"),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD", ""),
}

CNES_API_URL = os.getenv("CNES_API_URL", "https://apidadosabertos.saude.gov.br/cnes")
ANVISA_CSV_PATH = Path(os.getenv("ANVISA_CSV_PATH", str(DATA_RAW_DIR / "anvisa_medicamentos.csv")))
MIMIC_DIR_PATH = Path(os.getenv("MIMIC_DIR_PATH", str(DATA_RAW_DIR / "mimic-iv-demo")))

import pytest
import pandas as pd
import numpy as np
from unittest.mock import patch, MagicMock
from datetime import datetime

@pytest.fixture
def sample_raw_df():
    """Minimal raw telemetry dataframe matching InfluxDB pivot output."""
    return pd.DataFrame({
        "time": pd.to_datetime(["2025-01-01 00:00", "2025-01-01 00:01", "2025-01-01 00:02"]),
        "h_id": ["node-1", "node-1", "node-2"],
        "lat": [14.5, 14.5, 14.6],
        "lon": [121.0, 121.0, 121.1],
        "status": [0, 0, 0],
        "received_at": pd.to_datetime(["2025-01-01 00:00", "2025-01-01 00:01", "2025-01-01 00:02"]),
    })

class TestProcessTelemetryBatch:
    """Tests for process_telemetry_batch."""

    @patch("src.main.get_db_conn")
    def test_empty_df_returns_empty(self, mock_conn):
        from src.main import process_telemetry_batch
        result1, result2 = process_telemetry_batch(pd.DataFrame())
        assert result1.empty
        assert result2.empty

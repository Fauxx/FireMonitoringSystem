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

class TestBuildSensorAggregates:
    """Tests for build_sensor_aggregates."""

    @patch("src.main.get_db_conn")
    def test_empty_df_returns_empty(self, mock_conn):
        from src.main import build_sensor_aggregates
        result = build_sensor_aggregates(pd.DataFrame())
        assert result.empty

    @patch("src.main.get_db_conn")
    def test_groups_by_h_id(self, mock_conn, sample_raw_df):
        from src.main import build_sensor_aggregates
        result = build_sensor_aggregates(sample_raw_df, window_minutes=5)
        assert "m" in result.columns
        assert set(result["m"].unique()) == {"node-1", "node-2"}

    @patch("src.main.get_db_conn")
    def test_readings_count_correct(self, mock_conn, sample_raw_df):
        from src.main import build_sensor_aggregates
        result = build_sensor_aggregates(sample_raw_df, window_minutes=5)
        node1_count = result[result["m"] == "node-1"]["readings_count"].sum()
        assert node1_count == 2  # two rows for node-1

class TestBuildSystemMetrics:
    """Tests for build_system_metrics."""

    @patch("src.main.get_db_conn")
    def test_empty_df_returns_empty(self, mock_conn):
        from src.main import build_system_metrics
        result = build_system_metrics(pd.DataFrame())
        assert result.empty

    @patch("src.main.get_db_conn")
    def test_counts_active_devices(self, mock_conn, sample_raw_df):
        from src.main import build_system_metrics
        result = build_system_metrics(sample_raw_df)
        assert result.iloc[0]["active_devices"] == 2  # node-1 and node-2

    @patch("src.main.get_db_conn")
    def test_counts_alerts(self, mock_conn, sample_raw_df):
        from src.main import build_system_metrics
        sample_raw_df.loc[0, "status"] = 2  # make one row an alert
        result = build_system_metrics(sample_raw_df)
        assert result.iloc[0]["alerts_today"] == 1

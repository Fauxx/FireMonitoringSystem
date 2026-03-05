# InfluxDB to PostgreSQL ETL Service

A robust Python-based ETL (Extract, Transform, Load) pipeline designed to aggregate high-frequency time-series data from **InfluxDB** and forward it to a **PostgreSQL** relational database for long-term storage and structured analytics.

## 🚀 Overview
This project serves as a bridge between time-series storage and relational reporting. It is specifically designed to:
1. **Extract**: Pull raw metrics incrementally from InfluxDB.
2. **Aggregate**: Group data into 5-minute windows and calculate hourly averages, peaks, and summaries.
3. **Analyze**: Compute alert levels (Green, Orange, Red) based on sensor thresholds (Smoke, Temperature, Flame).
4. **Load**: Forward the processed data to PostgreSQL using "Upsert" logic to prevent duplication.

## 🛠️ Technical Stack
* **Language:** Python 3.10+
* **Time-Series DB:** InfluxDB (v2.x)
* **Relational DB:** PostgreSQL
* **Environment Management:** `python-dotenv`
* **Logging:** `loguru` (with automatic 10MB file rotation)

## 📦 Installation & Setup

### 1. Clone the Repository
```bash
git clone <your-repository-url>
cd <your-project-directory>
2. Install Requirements
Bash
pip install influxdb-client psycopg2-binary python-dotenv loguru
3. Environment Configuration
Create a .env file in the root directory and populate it with your credentials:

Code snippet
# InfluxDB Configuration
INFLUXDB_URL=http://localhost:8086
INFLUXDB_TOKEN=your_super_secret_token
INFLUXDB_ORG=your_organization_name
INFLUXDB_BUCKET=your_bucket_name

# PostgreSQL Configuration
DATABASE_URL=postgres://username:password@localhost:5432/your_database
🚦 Usage
The current version includes a connectivity diagnostic script to verify environment variables and database health before processing data:

Bash
python main.py
📂 Project Structure
main.py: Main entry point and connection validator.

.env: Configuration file for sensitive credentials (ignored by git).

logs/: Directory for persistent application logs.

requirements.txt: Project dependencies.

⚙️ ETL Logic
Timezone Consistency: All data is converted to Asia/Manila (PHT).

Alert Computation: Readings are evaluated against specific thresholds for fire monitoring safety.

Database Integrity: Uses ON CONFLICT DO UPDATE logic during the PostgreSQL load phase to ensure a single source of truth for every timestamp/device pair.

📝 Logging
Logs are automatically handled by Loguru. They are printed to the console for real-time monitoring and saved to logs/etl.log with a rotation policy of 10 MB.

Developed as part of the IoT-Based Fire Monitoring System architecture.

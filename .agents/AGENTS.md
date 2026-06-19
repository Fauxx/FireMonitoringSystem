# Workspace Customizations & Code Style Rules

These rules apply specifically to coding tasks within the `FireMonitoringSystem` repository. Every time you generate or modify code, ensure you adhere to the following standards:

---

## 🎨 1. Frontend & UI Best Practices (Dashboard)

*   **Aesthetic & Color System**: 
    *   Maintain the minimalist dark-mode and light-mode palette defined in [style.css](file:///home/zett/RiderProjects/FireMonitoringSystem/apps/dashboard/public/css/style.css).
    *   Do not inject large block styles directly inside `<style>` tags in HTML files. Extract shared styles into [style.css](file:///home/zett/RiderProjects/FireMonitoringSystem/apps/dashboard/public/css/style.css).
*   **JavaScript Safety**:
    *   **Element Checks**: Never assume a DOM element exists before attaching an event listener or setting a property. Always run a null check (e.g. `const el = document.getElementById('id'); if (el) { ... }`).
    *   **Shared JS Scripts**: Store core utilities like authentication checks and navbar generation in [script.js](file:///home/zett/RiderProjects/FireMonitoringSystem/apps/dashboard/public/protected/script.js) instead of repeating them in individual pages.

---

## 🔌 2. Backend API Design

*   **API Paradigm**: 
    *   The API is a **RESTful JSON API** built on Express. It uses standard HTTP verbs (`GET`, `POST`, `PUT`, `DELETE`) with resource-oriented endpoints.
    *   Return proper JSON responses with consistent status codes:
        *   `200 OK` / `201 Created` for successes.
        *   `400 Bad Request` for validation errors.
        *   `401 Unauthorized` for missing authentication.
        *   `403 Forbidden` for role authorization issues (e.g., non-admins requesting user lists).
        *   `404 Not Found` for missing resources.
        *   `500 Internal Server Error` for database failures.
*   **Modular Architecture**:
    *   Avoid creating monolithic route files. Break routers down by resource domain (e.g., `routes/users.js`, `routes/analytics.js`, `routes/dashboard.js`).
*   **Database Management**:
    *   Use the PostgreSQL pool object imported from [db.js](file:///home/zett/RiderProjects/FireMonitoringSystem/apps/api/src/db.js).
    *   Ensure database queries are parameterized (e.g. using `$1, $2` variables) to prevent SQL injection.

---

## ⚙️ 3. ETL Data Processing (Python)

*   **Mixed Telemetry Processing**:
    *   Never discard normal status (`0`) logs when an anomaly is present in the same batch. Both should be handled appropriately.
*   **Deduplication**:
    *   Deduplicate records written to the database. Use unique SQL constraints where appropriate or filter overlapping time windows in the ETL queries.
*   **Logging**:
    *   Use `loguru` for all application logging. Include clear tags (e.g., `🔌 DB WRITE:`, `⏳ Updated active incident:`, `❌ Influx fetch failed:`).

---

## 🏗️ 4. Database Migrations (Flyway)

*   Always create migrations under [sql/](file:///home/zett/RiderProjects/FireMonitoringSystem/infrastructure/k8s/base/sql/) using the `V<N>__<name>.sql` naming format.
*   Never run raw SQL queries directly in prod environments without committing a corresponding Flyway migration first.

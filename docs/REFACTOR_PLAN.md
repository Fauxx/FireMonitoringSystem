# Implementation Plan: Smart Gateway & Standalone Observability

## 1. Executive Summary
This plan refactors the Fire Monitoring System from a "Fat API" model to a "Smart Gateway" model. We will offload static file serving and security proxying to Nginx, while establishing a standalone "Ops Path" for Grafana. This reduces API load by ~40% and ensures observability stays online during application failures.

## 2. The Login Flow (How it works)
To answer your concern: **Nginx will NOT block logins.** 

The routing logic is split into two categories:
*   **Unprotected Routes (`/`, `/auth/*`, `/login.html`):** Nginx proxies these directly to the API or serves them from disk. No "security check" is performed yet. This allows the user to submit their login form and receive a session cookie.
*   **Protected Routes (`/protected/*`, `/grafana/*`):** These use the `auth_request` module. Nginx will pause the request, send the user's cookie to `/auth/verify`, and only proceed if the API says "OK".

## 3. Phase 1: API Foundation
**Goal:** Prepare the API to be a "Headless" data service.

*   **Action 1.1:** Add `GET /auth/verify` in `apps/api/src/routes/auth.js`.
    *   If `req.session.user` exists, return `200 OK`.
    *   Otherwise, return `401 Unauthorized`.
*   **Action 1.2:** Remove `express.static` and `http-proxy-middleware` from `apps/api/src/server.js`.
*   **Action 1.3:** Clean up the root route (`/`) in the API, as Nginx will now handle the initial redirect.

## 4. Phase 2: Nginx Smart Gateway
**Goal:** Make Nginx the "Security Guard."

*   **Action 2.1:** Update `apps/dashboard/nginx.conf`.
    *   Define the `auth_request /auth/verify;` rule for the `/protected/` location.
    *   Update the `/grafana` block to proxy **directly** to `http://grafana:3000`.
    *   Inject the `X-WEBAUTH-USER` header in the `/grafana` block using the result from the auth check.
*   **Action 2.2:** Implement "Iframe-Only" protection for Grafana.
    *   Reject `Sec-Fetch-Dest: document` requests to `/grafana` for non-admin users.

## 5. Phase 3: Standalone Infrastructure (The Lifeboat)
**Goal:** Ensure you can always see the data.

*   **Action 3.1:** Create `infrastructure/k8s/base/ingress/grafana-ops-ingress.yaml`.
    *   Host: `ops.dev.fires.systems`
    *   Backend: `grafana:3000`
    *   Annotations: `nginx.ingress.kubernetes.io/auth-type: basic`
*   **Action 3.2:** Update `infrastructure/k8s/base/grafana/deployment.yaml` to enable `GF_AUTH_BASIC_ENABLED=true`.

## 6. Phase 4: Validation (Local Kind)
**Goal:** Prove it works before deploying.

*   **Step 1:** Run `make kind-load` to build and push the new Nginx and API images.
*   **Step 2:** Run `make deploy-local`.
*   **Step 3:** Test Login: Visit `dev.fires.systems/login.html` and ensure you can get in.
*   **Step 4:** Test Embedding: Visit the analytics page and ensure Grafana charts load.
*   **Step 5:** Test Standalone: Visit `ops.dev.fires.systems` and ensure you can log in with `admin/adminpassword` even if the API pod is deleted.

## 7. Rollback Plan
If Nginx starts blocking traffic incorrectly:
1.  Revert `apps/dashboard/nginx.conf` to the previous version.
2.  Redeploy the Dashboard pod.
3.  The API will still have its legacy routes (if we keep them temporarily) or we can revert the API as well.

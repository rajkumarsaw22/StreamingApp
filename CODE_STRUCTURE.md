# StreamingApp Code Structure and Services

This document explains how the repository is organized, what each service does, and where to find key code paths.

## 1) High-level Architecture

The project is a microservice-based streaming platform with:

- `frontend` (React SPA)
- `authService` (registration/login/JWT)
- `streamingService` (catalog + playback endpoints + thumbnails)
- `adminService` (admin-only upload and video management)
- `chatService` (REST + Socket.IO live chat)
- `mongo` (shared database)

Orchestration is handled by `docker-compose.yml` in the repo root.

## 2) Repository Folder Structure

```text
StreamingApp/
├── backend/
│   ├── authService/
│   │   ├── controllers/
│   │   │   ├── healthCheck.controller.js
│   │   │   └── user.controller.js
│   │   ├── middleware/
│   │   │   └── adminAuth.js
│   │   ├── models/
│   │   │   └── user.model.js
│   │   ├── routes/
│   │   │   ├── healthCheck.route.js
│   │   │   └── user.route.js
│   │   ├── util/
│   │   │   ├── conn.js
│   │   │   └── jwtAuth.js
│   │   ├── index.js
│   │   ├── Dockerfile
│   │   └── package.json
│   │
│   ├── streamingService/
│   │   ├── controllers/
│   │   │   ├── health.controller.js
│   │   │   ├── streaming.controller.js
│   │   │   └── video.controller.js
│   │   ├── models/
│   │   │   ├── streaming.model.js
│   │   │   └── video.model.js
│   │   ├── routes/
│   │   │   ├── health.route.js
│   │   │   ├── streaming.route.js
│   │   │   └── video.route.js
│   │   ├── scripts/
│   │   │   ├── seedVideo.js
│   │   │   └── seedVideos.js
│   │   ├── util/
│   │   │   └── s3.js
│   │   ├── db.js
│   │   ├── index.js
│   │   ├── Dockerfile
│   │   └── package.json
│   │
│   ├── adminService/
│   │   ├── controllers/
│   │   │   └── video.controller.js
│   │   ├── middleware/
│   │   │   └── adminAuth.js
│   │   ├── models/
│   │   │   └── video.model.js
│   │   ├── routes/
│   │   │   └── video.route.js
│   │   ├── util/
│   │   │   └── s3.js
│   │   ├── db.js
│   │   ├── index.js
│   │   ├── Dockerfile
│   │   └── package.json
│   │
│   └── chatService/
│       ├── controllers/
│       │   └── chat.controller.js
│       ├── middleware/
│       │   └── auth.js
│       ├── models/
│       │   └── message.model.js
│       ├── routes/
│       │   └── chat.route.js
│       ├── util/
│       │   └── auth.js
│       ├── db.js
│       ├── index.js
│       ├── Dockerfile
│       └── package.json
│
├── frontend/
│   ├── public/
│   ├── src/
│   │   ├── components/
│   │   │   ├── admin/
│   │   │   └── chat/
│   │   ├── config/
│   │   │   └── env.js
│   │   ├── contexts/
│   │   │   └── AuthContext.js
│   │   ├── hooks/
│   │   │   └── useChatRoom.js
│   │   ├── pages/
│   │   ├── services/
│   │   │   ├── api.js
│   │   │   ├── auth.service.js
│   │   │   ├── streaming.service.js
│   │   │   ├── admin.service.js
│   │   │   └── chat.service.js
│   │   ├── styles/
│   │   ├── App.js
│   │   └── index.js
│   ├── Dockerfile
│   └── package.json
│
├── docker-compose.yml
├── README.md
└── CODE_STRUCTURE.md
```

## 3) Service Responsibilities

### `backend/authService`

Purpose:
- User registration and login
- JWT creation/verification
- Auth status check
- Password reset flow

Key files:
- `index.js`: Express app bootstrap, CORS, middleware, route mount
- `routes/user.route.js`: `/register`, `/login`, `/forgetPassword`, `/verify`
- `controllers/user.controller.js`: auth and account logic
- `util/jwtAuth.js`: JWT sign/verify helpers
- `models/user.model.js`: user schema

Main base URL:
- `/api` on port `3001`

---

### `backend/streamingService`

Purpose:
- Public video listing
- Featured video and details
- Byte-range streaming from S3
- Thumbnail proxy endpoint

Key files:
- `index.js`: app bootstrap and route mount
- `routes/streaming.route.js`: primary streaming API routes
- `controllers/streaming.controller.js`: video listing/streaming/thumbnail handlers
- `util/s3.js`: S3 client + URL builders
- `models/video.model.js`: catalog schema

Notes:
- `controllers/video.controller.js` and `routes/video.route.js` exist, but the active app wiring in `index.js` uses `streaming.route.js`.

Main base URL:
- `/api/streaming` on port `3002`

---

### `backend/adminService`

Purpose:
- Admin-only video operations (CRUD)
- Direct upload endpoints (multipart)
- Pre-signed S3 upload URL generation
- Featured flag management

Key files:
- `index.js`: bootstrap + `/api/admin`
- `middleware/adminAuth.js`: bearer token + admin role guard
- `routes/video.route.js`: admin video endpoints
- `controllers/video.controller.js`: upload/create/update/delete/toggle logic
- `util/s3.js`: S3 integration helpers

Main base URL:
- `/api/admin` on port `3003`

---

### `backend/chatService`

Purpose:
- REST endpoint for chat history per video
- Socket.IO real-time chat rooms per `videoId`

Key files:
- `index.js`: Express + HTTP server + Socket.IO setup
- `routes/chat.route.js`: REST history route
- `middleware/auth.js`: request auth middleware
- `util/auth.js`: token verification + user context
- `models/message.model.js`: message persistence schema

Main base URL:
- REST: `/api/chat` on port `3004`
- Socket.IO: same host/port

## 4) Frontend Structure

### `frontend/src/pages`
Route-level screens:
- Auth pages: `Login`, `Register`, `ForgotPassword`
- User pages: `Browse`, `Collection`, `Profile`, `Settings`
- Admin page: `AdminDashboard`

### `frontend/src/components`
Reusable UI:
- Player, cards, carousels, header, guard routes
- `components/admin/*`: admin management/upload forms
- `components/chat/*`: chat panel UI

### `frontend/src/services`
API clients:
- `api.js`: shared auth API client
- `auth.service.js`: auth workflows
- `streaming.service.js`: browse/playback data calls
- `admin.service.js`: admin APIs
- `chat.service.js`: history + socket client methods

### `frontend/src/contexts`
- `AuthContext.js`: auth state, login/logout/register methods, token/user lifecycle

### `frontend/src/hooks`
- `useChatRoom.js`: chat history + room join + real-time message management

## 5) Request/Data Flow (Typical User Journey)

1. User logs in from frontend (`auth.service.js`) -> auth service returns token/user.
2. Browse page loads featured/catalog from streaming service.
3. Video player builds playback URL and requests streaming endpoint.
4. If chat panel is open:
   - fetch history via REST (`/api/chat/history/:videoId`)
   - connect/join room via Socket.IO
   - send/receive real-time messages.
5. Admin users access admin dashboard:
   - upload thumbnail/video to S3 (direct or signed URL path)
   - create/update metadata in admin service.

## 6) Runtime/Deployment Files

- `docker-compose.yml`: brings up Mongo + 4 backend services + frontend.
- Service `Dockerfile`s:
  - `backend/authService/Dockerfile`
  - `backend/streamingService/Dockerfile`
  - `backend/adminService/Dockerfile`
  - `backend/chatService/Dockerfile`
  - `frontend/Dockerfile`

## 7) Quick Navigation Guide

- Auth issue: start in `backend/authService/controllers/user.controller.js`
- Video list/playback issue: start in `backend/streamingService/controllers/streaming.controller.js`
- Admin upload issue: start in `backend/adminService/controllers/video.controller.js`
- Chat issue:
  - backend socket logic: `backend/chatService/index.js`
  - frontend socket usage: `frontend/src/services/chat.service.js`
  - UI state wiring: `frontend/src/hooks/useChatRoom.js`


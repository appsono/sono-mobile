# Endpoint Reference

**Base URL:** `http://localhost:8000` (development)
**API Prefix:** `/api/v1`

---

## Health Check

```bash
GET /health
```

---

## Authentication

### Get Public Key
```bash
GET /api/v1/users/public-key
```

### Register User
```bash
POST /api/v1/users/
Content-Type: application/json
X-Password-Encrypted: true

{
  "username": "newuser",
  "email": "user@example.com",
  "password": "<encrypted_password>",
  "display_name": "Display Name"
}
```

### Login
```bash
POST /api/v1/users/token
Content-Type: application/x-www-form-urlencoded
X-Password-Encrypted: true

username=user@example.com&password=<encrypted_password>
```

### Refresh Token
```bash
POST /api/v1/users/token/refresh
Content-Type: application/json

{
  "refresh_token": "your.refresh.token"
}
```

### Logout
```bash
POST /api/v1/users/logout
Authorization: Bearer <token>
Content-Type: application/json

{
  "refresh_token": "your.refresh.token"
}
```

**Password Requirements:**
- Minimum 8 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one number
- At least one special character

## Password Reset

### Request Password Reset
```bash
POST /api/v1/users/forgot-password
Content-Type: application/json

{
  "email": "user@example.com"
}
```

**Response:**
```json
{
  "message": "If an account with that email exists, we've sent password reset instructions.",
  "success": true
}
```

**Rate Limit:** 3 requests per hour per IP

**Note:** Always returns success to prevent email enumeration attacks.

---

### Verify Reset Token
```bash
POST /api/v1/users/verify-reset-token
Content-Type: application/json

{
  "token": "your-reset-token-here"
}
```

**Response (Valid Token):**
```json
{
  "message": "Reset token is valid",
  "success": true
}
```

**Response (Invalid/Expired Token):**
```json
{
  "detail": "Invalid or expired reset token"
}
```

**Use Case:** Frontend can verify token validity before showing password reset form.

---

### Reset Password
```bash
POST /api/v1/users/reset-password
Content-Type: application/json

{
  "token": "your-reset-token-here",
  "new_password": "NewSecureP@ssw0rd!"
}
```

**Response (Success):**
```json
{
  "message": "Password has been reset successfully. You can now log in with your new password.",
  "success": true
}
```

**Response (Invalid Token):**
```json
{
  "detail": "Invalid or expired reset token"
}
```


## Example: Complete Password Reset Flow

### Step 1: User Requests Password Reset

```bash
curl -X POST "http://localhost:8000/api/v1/users/forgot-password" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john@example.com"
  }'
```

**Response:**
```json
{
  "message": "If an account with that email exists, we've sent password reset instructions.",
  "success": true
}
```

**Email Received:**
- Subject: "Password Reset Request - Sono"
- Contains reset link: `https://sono.wtf/reset-password?token=abc123...`
- Token expires in 1 hour

---

### Step 2: Frontend Verifies Token (Optional)

```bash
curl -X POST "http://localhost:8000/api/v1/users/verify-reset-token" \
  -H "Content-Type: application/json" \
  -d '{
    "token": "abc123..."
  }'
```

**Response:**
```json
{
  "message": "Reset token is valid",
  "success": true
}
```

---

### Step 3: User Submits New Password

```bash
curl -X POST "http://localhost:8000/api/v1/users/reset-password" \
  -H "Content-Type: application/json" \
  -d '{
    "token": "abc123...",
    "new_password": "NewSecureP@ssw0rd!"
  }'
```

**Response:**
```json
{
  "message": "Password has been reset successfully. You can now log in with your new password.",
  "success": true
}
```

---

### Step 4: User Logs In With New Password

```bash
curl -X POST "http://localhost:8000/api/v1/users/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=john@example.com&password=NewSecureP@ssw0rd!"
```

**Response:**
```json
{
  "access_token": "eyJhbGc...",
  "token_type": "bearer",
  "refresh_token": "eyJhbGc..."
}
```

---

## Error Responses

### Token Already Used
```json
{
  "detail": "This reset link has already been used"
}
```

### Token Expired
```json
{
  "detail": "This reset link has expired. Please request a new one."
}
```

### Invalid Token
```json
{
  "detail": "Invalid or expired reset token"
}
```

### Weak Password
```json
{
  "detail": [
    {
      "loc": ["body", "new_password"],
      "msg": "Password must contain at least one uppercase letter",
      "type": "value_error"
    }
  ]
}
```

### Email Send Failure
```json
{
  "detail": "Failed to send password reset email. Please try again later."
}
```

---

## User Management

### Get Current User
```bash
GET /api/v1/users/me
Authorization: Bearer <token>
```

### Update Profile
```bash
PUT /api/v1/users/me
Authorization: Bearer <token>
Content-Type: application/json

{
  "display_name": "New Name",
  "bio": "Bio text"
}
```

### Upload Profile Picture
```bash
POST /api/v1/users/me/upload-profile-picture
Authorization: Bearer <token>
Content-Type: multipart/form-data

file=@picture.jpg
```

### Request Account Deletion
```bash
POST /api/v1/users/me/request-deletion
Authorization: Bearer <token>
Content-Type: application/json

{
  "deletion_type": "hard",
  "reason": "Optional reason"
}
```

### Cancel Pending Deletion
```bash
POST /api/v1/users/me/cancel-deletion
Authorization: Bearer <token>
```

### Immediate Account Deletion
```bash
DELETE /api/v1/users/me?password=<password>&deletion_type=<soft|hard>
Authorization: Bearer <token>
```

### Export User Data (GDPR)
```bash
GET /api/v1/users/me/export-data
Authorization: Bearer <token>
```

### Record Consent
```bash
POST /api/v1/users/me/consent
Authorization: Bearer <token>
Content-Type: application/json

{
  "consent_type": "privacy_policy",
  "consent_version": "1.0",
  "ip_address": "192.168.1.1"
}
```

### View Consents
```bash
GET /api/v1/users/me/consents
Authorization: Bearer <token>
```

---

## Audio Files

### Upload Audio File
```bash
POST /api/v1/audio/upload
Authorization: Bearer <token>
Content-Type: multipart/form-data

file=@audio.mp3
title=Song Title
description=Description
is_public=false
```

### Get Upload Statistics
```bash
GET /api/v1/audio/stats
Authorization: Bearer <token>
```

### List My Audio Files
```bash
GET /api/v1/audio/my-files?skip=0&limit=100
Authorization: Bearer <token>
```

### List Public Audio Files
```bash
GET /api/v1/audio/public?skip=0&limit=100
```

### Get Audio File
```bash
GET /api/v1/audio/{file_id}
Authorization: Bearer <token>
```

### Update Audio File
```bash
PUT /api/v1/audio/{file_id}
Authorization: Bearer <token>
Content-Type: application/json

{
  "title": "New Title",
  "description": "New Description",
  "is_public": true
}
```

### Delete Audio File
```bash
DELETE /api/v1/audio/{file_id}
Authorization: Bearer <token>
```

---

## Collections (Albums, Playlists, Compilations)

### Create Collection
```bash
POST /api/v1/collections/
Authorization: Bearer <token>
Content-Type: application/json

{
  "title": "Collection Title",
  "description": "Description",
  "collection_type": "playlist",
  "artist": "Artist Name",
  "curator_note": "Curator notes",
  "is_public": true,
  "is_collaborative": false
}
```

### Upload Collection Cover Art
```bash
POST /api/v1/collections/{collection_id}/cover-art
Authorization: Bearer <token>
Content-Type: multipart/form-data

file=@cover.jpg
```

### List All Collections
```bash
GET /api/v1/collections/?skip=0&limit=100&collection_type=playlist&public_only=true
```

### List My Collections
```bash
GET /api/v1/collections/my-collections?skip=0&limit=100
Authorization: Bearer <token>
```

### Get Collection
```bash
GET /api/v1/collections/{collection_id}
Authorization: Bearer <token>
```

### Update Collection
```bash
PUT /api/v1/collections/{collection_id}
Authorization: Bearer <token>
Content-Type: application/json

{
  "title": "New Title",
  "description": "New Description",
  "is_public": true
}
```

### Delete Collection
```bash
DELETE /api/v1/collections/{collection_id}
Authorization: Bearer <token>
```

### Add Track to Collection
```bash
POST /api/v1/collections/{collection_id}/tracks
Authorization: Bearer <token>
Content-Type: application/json

{
  "audio_file_id": 123,
  "track_order": 1
}
```

### Remove Track from Collection
```bash
DELETE /api/v1/collections/{collection_id}/tracks/{track_id}
Authorization: Bearer <token>
```

### Reorder Track
```bash
PUT /api/v1/collections/{collection_id}/tracks/{track_id}/reorder
Authorization: Bearer <token>
Content-Type: application/json

{
  "new_order": 5
}
```

### Bulk Add Tracks
```bash
POST /api/v1/collections/{collection_id}/tracks/bulk-add
Authorization: Bearer <token>
Content-Type: application/json

{
  "audio_file_ids": [1, 2, 3, 4, 5]
}
```

### Add Collaborator
```bash
POST /api/v1/collections/{collection_id}/collaborators
Authorization: Bearer <token>
Content-Type: application/json

{
  "user_id": 123,
  "permission_level": "edit"
}
```

### Update Collaborator
```bash
PUT /api/v1/collections/{collection_id}/collaborators/{user_id}
Authorization: Bearer <token>
Content-Type: application/json

{
  "permission_level": "view"
}
```

### Remove Collaborator
```bash
DELETE /api/v1/collections/{collection_id}/collaborators/{user_id}
Authorization: Bearer <token>
```

---

## Announcements (Public)

### List Published Announcements
```bash
GET /api/v1/announcements?skip=0&limit=20
```

### Get Published Announcement
```bash
GET /api/v1/announcements/{announcement_id}
```

---

## Admin - User Management

### Get System Statistics
```bash
GET /api/v1/admin/stats
Authorization: Bearer <admin_token>
```

### List All Users
```bash
GET /api/v1/admin/users?skip=0&limit=100
Authorization: Bearer <admin_token>
```

### Get User Details
```bash
GET /api/v1/admin/users/{user_id}
Authorization: Bearer <admin_token>
```

### Update User Upload Limit
```bash
PUT /api/v1/admin/users/{user_id}/upload-limit
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "max_audio_uploads": 50
}
```

### Get User Upload Stats
```bash
GET /api/v1/admin/users/{user_id}/upload-stats
Authorization: Bearer <admin_token>
```

### Disable User
```bash
POST /api/v1/admin/users/{user_id}/disable
Authorization: Bearer <admin_token>
```

### Enable User
```bash
POST /api/v1/admin/users/{user_id}/enable
Authorization: Bearer <admin_token>
```

---

## Admin - Audio Files

### List All Audio Files
```bash
GET /api/v1/admin/audio-files/all?skip=0&limit=100
Authorization: Bearer <admin_token>
```

### Delete User's Audio Files
```bash
DELETE /api/v1/admin/users/{user_id}/audio-files
Authorization: Bearer <admin_token>
```

### Reset User Uploads
```bash
POST /api/v1/admin/users/{user_id}/reset-uploads
Authorization: Bearer <admin_token>
```

---

## Admin - Collections

### Get Collection Statistics
```bash
GET /api/v1/admin/collections/stats
Authorization: Bearer <admin_token>
```

### Get User Collection Statistics
```bash
GET /api/v1/admin/users/{user_id}/collections/stats
Authorization: Bearer <admin_token>
```

### Delete User's Collections
```bash
DELETE /api/v1/admin/users/{user_id}/collections/all
Authorization: Bearer <admin_token>
```

### Get Recent Collections
```bash
GET /api/v1/admin/collections/recent?limit=20
Authorization: Bearer <admin_token>
```

### Get Collections Summary
```bash
GET /api/v1/admin/collections/summary
Authorization: Bearer <admin_token>
```

---

## Admin - Announcements

### Create Announcement
```bash
POST /api/v1/admin/announcements
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "title": "Important Update",
  "content": "Announcement content here...",
  "is_published": true
}
```

### List All Announcements
```bash
GET /api/v1/admin/announcements?skip=0&limit=100&published_only=false
Authorization: Bearer <admin_token>
```

### Get Announcement
```bash
GET /api/v1/admin/announcements/{announcement_id}
Authorization: Bearer <admin_token>
```

### Update Announcement
```bash
PUT /api/v1/admin/announcements/{announcement_id}
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "title": "Updated Title",
  "content": "Updated content",
  "is_published": true
}
```

### Delete Announcement
```bash
DELETE /api/v1/admin/announcements/{announcement_id}
Authorization: Bearer <admin_token>
```

---

## Response Formats

### Success Response
```json
{
  "id": 1,
  "field": "value"
}
```

### Error Response
```json
{
  "detail": "Error message"
}
```

### List Response
```json
{
  "items": [...],
  "total": 100,
  "has_more": true
}
```

---

## Authentication Headers

All protected endpoints require:
```
Authorization: Bearer <access_token>
```

---

## Rate Limits

| Endpoint | Limit |
|----------|-------|
| `POST /users/` | 5/minute per IP |
| `POST /users/token` | 10/minute per IP |
| `POST /users/token/refresh` | 30/minute per IP |
| `DELETE /users/me` | 3/hour per IP |
| **`POST /users/forgot-password`** | **3/hour per IP** |
| **`POST /users/reset-password`** | **5/hour per IP** |

---

## File Upload Limits

| Type | Formats | Max Size |
|------|---------|----------|
| Audio | MP3, WAV, OGG, M4A, AAC, FLAC, WEBM | 50 MB |
| Images | PNG, JPG, WebP | 5 MB |

---

## Collection Types

- `album` - Music album with artist
- `playlist` - User-curated playlist
- `compilation` - Curated compilation with notes

---

## Permission Levels

- `edit` - Can add/remove tracks
- `view` - Can only view collection
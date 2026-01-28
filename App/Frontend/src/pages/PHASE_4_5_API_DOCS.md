# Phase 4 & 5 API Documentation

## Overview
This document provides complete API documentation and Postman/cURL examples for Phase 4 (Election Management) and Phase 5 (Voters + Voting + Results).

**Base URL**: `http://localhost:4000`

**Authentication**: All endpoints require JWT Bearer token in the `Authorization` header:
```
Authorization: Bearer <your_access_token>
```

---

## Phase 4: Election Management

### 1. Create Election

**Endpoint**: `POST /elections`

**Authorization**: OWNER or ADMIN of the organization

**Request Body**:
```json
{
  "organization_id": 1,
  "election_name": "Student Council Election 2024",
  "description": "Annual student council election"
}
```

**Response** (201 Created):
```json
{
  "ok": true,
  "election_id": 1,
  "election_name": "Student Council Election 2024",
  "organization_id": 1
}
```

**cURL Example**:
```bash
curl -X POST http://localhost:4000/elections \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "organization_id": 1,
    "election_name": "Student Council Election 2024",
    "description": "Annual student council election"
  }'
```

---

### 2. List Elections by Organization

**Endpoint**: `GET /elections?organization_id=1`

**Authorization**: Any active member of the organization

**Query Parameters**:
- `organization_id` (required): Organization ID

**Response** (200 OK):
```json
{
  "ok": true,
  "elections": [
    {
      "election_id": 1,
      "election_name": "Student Council Election 2024",
      "description": "Annual student council election",
      "start_datetime": null,
      "end_datetime": null,
      "status": "DRAFT",
      "created_at": "2024-01-28T12:00:00Z",
      "created_by": 1
    }
  ]
}
```

**cURL Example**:
```bash
curl -X GET "http://localhost:4000/elections?organization_id=1" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

### 3. Get Election Details

**Endpoint**: `GET /elections/:electionId`

**Authorization**: Any active member of the organization

**Response** (200 OK):
```json
{
  "ok": true,
  "election": {
    "election_id": 1,
    "organization_id": 1,
    "organization_name": "University of Example",
    "election_name": "Student Council Election 2024",
    "description": "Annual student council election",
    "start_datetime": null,
    "end_datetime": null,
    "status": "DRAFT",
    "created_at": "2024-01-28T12:00:00Z",
    "created_by": 1,
    "races": [
      {
        "race_id": 1,
        "race_name": "President",
        "description": "Student Council President",
        "max_votes_per_voter": 1,
        "candidates": [
          {
            "candidate_id": 1,
            "full_name": "John Doe",
            "affiliation_name": "Independent",
            "bio": "Experienced leader",
            "is_approved": true,
            "display_name": "John Doe",
            "ballot_order": 1
          }
        ]
      }
    ]
  }
}
```

**cURL Example**:
```bash
curl -X GET http://localhost:4000/elections/1 \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

### 4. Update Election

**Endpoint**: `PUT /elections/:electionId`

**Authorization**: OWNER or ADMIN of the organization

**Note**: Can only update elections in DRAFT status

**Request Body**:
```json
{
  "election_name": "Updated Election Name",
  "description": "Updated description",
  "start_at": "2024-02-01T09:00:00Z",
  "end_at": "2024-02-07T17:00:00Z"
}
```

**Response** (200 OK):
```json
{
  "ok": true,
  "message": "Election updated successfully"
}
```

**cURL Example**:
```bash
curl -X PUT http://localhost:4000/elections/1 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "election_name": "Updated Election Name",
    "description": "Updated description",
    "start_at": "2024-02-01T09:00:00Z",
    "end_at": "2024-02-07T17:00:00Z"
  }'
```

---

### 5. Open Election

**Endpoint**: `POST /elections/:electionId/open`

**Authorization**: OWNER or ADMIN of the organization

**Requirements**:
- Election must be in DRAFT status
- Must have at least 1 race
- Each race must have at least 1 approved candidate

**Response** (200 OK):
```json
{
  "ok": true,
  "message": "Election opened successfully"
}
```

**Error Response** (409 Conflict):
```json
{
  "ok": false,
  "error": "Election must have at least one race"
}
```

**cURL Example**:
```bash
curl -X POST http://localhost:4000/elections/1/open \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

### 6. Close Election

**Endpoint**: `POST /elections/:electionId/close`

**Authorization**: OWNER or ADMIN of the organization

**Requirements**:
- Election must be in OPEN status

**Response** (200 OK):
```json
{
  "ok": true,
  "message": "Election closed successfully"
}
```

**cURL Example**:
```bash
curl -X POST http://localhost:4000/elections/1/close \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

## Phase 5: Voters + Voting + Results

### 1. Register as Voter

**Endpoint**: `POST /voting/register`

**Authorization**: Any authenticated user who is an active member of the organization

**Request Body**:
```json
{
  "organization_id": 1
}
```

**Response** (201 Created):
```json
{
  "ok": true,
  "message": "Voter registration submitted for approval"
}
```

**Error Response** (409 Conflict):
```json
{
  "ok": false,
  "error": "Already registered as voter in this organization"
}
```

**cURL Example**:
```bash
curl -X POST http://localhost:4000/voting/register \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "organization_id": 1
  }'
```

---

### 2. Approve Voter

**Endpoint**: `POST /voting/approve`

**Authorization**: OWNER or ADMIN of the organization

**Request Body**:
```json
{
  "organization_id": 1,
  "user_id": 5
}
```

**Response** (200 OK):
```json
{
  "ok": true,
  "message": "Voter approved successfully"
}
```

**cURL Example**:
```bash
curl -X POST http://localhost:4000/voting/approve \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "organization_id": 1,
    "user_id": 5
  }'
```

---

### 3. Cast Vote

**Endpoint**: `POST /voting/cast`

**Authorization**: Approved voter in the organization

**Requirements**:
- Election must be OPEN
- Voter must be approved
- Can only vote once per race

**Request Body**:
```json
{
  "election_id": 1,
  "race_id": 1,
  "candidate_id": 1
}
```

**Response** (201 Created):
```json
{
  "ok": true,
  "vote_id": 123,
  "message": "Vote cast successfully"
}
```

**Error Response** (409 Conflict):
```json
{
  "ok": false,
  "error": "Already voted in this race"
}
```

**cURL Example**:
```bash
curl -X POST http://localhost:4000/voting/cast \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "election_id": 1,
    "race_id": 1,
    "candidate_id": 1
  }'
```

---

### 4. Get Race Results

**Endpoint**: `GET /voting/results?election_id=1&race_id=1`

**Authorization**: Any active member of the organization

**Query Parameters**:
- `election_id` (required): Election ID
- `race_id` (required): Race ID

**Response** (200 OK):
```json
{
  "ok": true,
  "election_id": 1,
  "race_id": 1,
  "race_name": "President",
  "election_status": "CLOSED",
  "results": [
    {
      "candidate_id": 1,
      "display_name": "John Doe",
      "vote_count": 150
    },
    {
      "candidate_id": 2,
      "display_name": "Jane Smith",
      "vote_count": 120
    }
  ]
}
```

**cURL Example**:
```bash
curl -X GET "http://localhost:4000/voting/results?election_id=1&race_id=1" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

### 5. Get Voter Status

**Endpoint**: `GET /voting/status?organization_id=1`

**Authorization**: Any authenticated user

**Query Parameters**:
- `organization_id` (required): Organization ID

**Response** (200 OK) - Registered:
```json
{
  "ok": true,
  "registered": true,
  "voter": {
    "voter_id": 5,
    "is_approved": true,
    "status": "APPROVED",
    "approved_by": 1,
    "approved_at": "2024-01-28T12:00:00Z",
    "registered_at": "2024-01-27T10:00:00Z"
  }
}
```

**Response** (200 OK) - Not Registered:
```json
{
  "ok": true,
  "registered": false,
  "message": "Not registered as voter in this organization"
}
```

**cURL Example**:
```bash
curl -X GET "http://localhost:4000/voting/status?organization_id=1" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

### 6. List Pending Voters

**Endpoint**: `GET /voting/pending?organization_id=1`

**Authorization**: OWNER or ADMIN of the organization

**Query Parameters**:
- `organization_id` (required): Organization ID

**Response** (200 OK):
```json
{
  "ok": true,
  "pending_voters": [
    {
      "voter_id": 6,
      "user_id": 10,
      "member_id": "STU12345",
      "voter_type": "STUDENT",
      "registered_at": "2024-01-28T10:00:00Z"
    }
  ]
}
```

**cURL Example**:
```bash
curl -X GET "http://localhost:4000/voting/pending?organization_id=1" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

## Error Codes Reference

| HTTP Code | Error Code | Meaning |
|-----------|------------|---------|
| 400 | - | Bad request (validation error) |
| 401 | - | Unauthorized (missing/invalid token) |
| 403 | 28000 | Forbidden (insufficient permissions) |
| 404 | - | Resource not found |
| 409 | 23505 | Conflict (duplicate entry) |
| 409 | 22023 | Invalid state transition |
| 500 | - | Internal server error |

---

## Complete Workflow Example

### 1. Admin creates organization and election
```bash
# Login as admin
curl -X POST http://localhost:4000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@example.com", "password": "password123"}'

# Create election
curl -X POST http://localhost:4000/elections \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ADMIN_TOKEN" \
  -d '{
    "organization_id": 1,
    "election_name": "Student Council 2024",
    "description": "Annual election"
  }'
```

### 2. User registers as voter
```bash
# Login as user
curl -X POST http://localhost:4000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "voter@example.com", "password": "password123"}'

# Register as voter
curl -X POST http://localhost:4000/voting/register \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer USER_TOKEN" \
  -d '{"organization_id": 1}'
```

### 3. Admin approves voter
```bash
curl -X POST http://localhost:4000/voting/approve \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ADMIN_TOKEN" \
  -d '{
    "organization_id": 1,
    "user_id": 5
  }'
```

### 4. Admin opens election
```bash
curl -X POST http://localhost:4000/elections/1/open \
  -H "Authorization: Bearer ADMIN_TOKEN"
```

### 5. Voter casts vote
```bash
curl -X POST http://localhost:4000/voting/cast \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer USER_TOKEN" \
  -d '{
    "election_id": 1,
    "race_id": 1,
    "candidate_id": 1
  }'
```

### 6. Admin closes election and views results
```bash
# Close election
curl -X POST http://localhost:4000/elections/1/close \
  -H "Authorization: Bearer ADMIN_TOKEN"

# View results
curl -X GET "http://localhost:4000/voting/results?election_id=1&race_id=1" \
  -H "Authorization: Bearer ADMIN_TOKEN"
```

---

## Postman Collection

Import this JSON into Postman:

```json
{
  "info": {
    "name": "Election System - Phase 4 & 5",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "variable": [
    {
      "key": "baseUrl",
      "value": "http://localhost:4000"
    },
    {
      "key": "token",
      "value": "YOUR_TOKEN_HERE"
    }
  ],
  "item": [
    {
      "name": "Elections",
      "item": [
        {
          "name": "Create Election",
          "request": {
            "method": "POST",
            "header": [
              {
                "key": "Authorization",
                "value": "Bearer {{token}}"
              }
            ],
            "body": {
              "mode": "raw",
              "raw": "{\n  \"organization_id\": 1,\n  \"election_name\": \"Test Election\",\n  \"description\": \"Test Description\"\n}",
              "options": {
                "raw": {
                  "language": "json"
                }
              }
            },
            "url": {
              "raw": "{{baseUrl}}/elections",
              "host": ["{{baseUrl}}"],
              "path": ["elections"]
            }
          }
        },
        {
          "name": "List Elections",
          "request": {
            "method": "GET",
            "header": [
              {
                "key": "Authorization",
                "value": "Bearer {{token}}"
              }
            ],
            "url": {
              "raw": "{{baseUrl}}/elections?organization_id=1",
              "host": ["{{baseUrl}}"],
              "path": ["elections"],
              "query": [
                {
                  "key": "organization_id",
                  "value": "1"
                }
              ]
            }
          }
        },
        {
          "name": "Open Election",
          "request": {
            "method": "POST",
            "header": [
              {
                "key": "Authorization",
                "value": "Bearer {{token}}"
              }
            ],
            "url": {
              "raw": "{{baseUrl}}/elections/1/open",
              "host": ["{{baseUrl}}"],
              "path": ["elections", "1", "open"]
            }
          }
        }
      ]
    },
    {
      "name": "Voting",
      "item": [
        {
          "name": "Register as Voter",
          "request": {
            "method": "POST",
            "header": [
              {
                "key": "Authorization",
                "value": "Bearer {{token}}"
              }
            ],
            "body": {
              "mode": "raw",
              "raw": "{\n  \"organization_id\": 1\n}",
              "options": {
                "raw": {
                  "language": "json"
                }
              }
            },
            "url": {
              "raw": "{{baseUrl}}/voting/register",
              "host": ["{{baseUrl}}"],
              "path": ["voting", "register"]
            }
          }
        },
        {
          "name": "Cast Vote",
          "request": {
            "method": "POST",
            "header": [
              {
                "key": "Authorization",
                "value": "Bearer {{token}}"
              }
            ],
            "body": {
              "mode": "raw",
              "raw": "{\n  \"election_id\": 1,\n  \"race_id\": 1,\n  \"candidate_id\": 1\n}",
              "options": {
                "raw": {
                  "language": "json"
                }
              }
            },
            "url": {
              "raw": "{{baseUrl}}/voting/cast",
              "host": ["{{baseUrl}}"],
              "path": ["voting", "cast"]
            }
          }
        },
        {
          "name": "Get Results",
          "request": {
            "method": "GET",
            "header": [
              {
                "key": "Authorization",
                "value": "Bearer {{token}}"
              }
            ],
            "url": {
              "raw": "{{baseUrl}}/voting/results?election_id=1&race_id=1",
              "host": ["{{baseUrl}}"],
              "path": ["voting", "results"],
              "query": [
                {
                  "key": "election_id",
                  "value": "1"
                },
                {
                  "key": "race_id",
                  "value": "1"
                }
              ]
            }
          }
        }
      ]
    }
  ]
}
```

---

## Notes

1. **Authentication**: All endpoints require a valid JWT token obtained from `/auth/login`
2. **Authorization**: Different endpoints require different roles (OWNER/ADMIN vs regular members)
3. **Audit Logging**: All critical actions are automatically logged in the `audit_logs` table
4. **Transaction Safety**: All write operations use database transactions for consistency
5. **ID Types**: All IDs are BIGINT in the database but can be passed as regular numbers in JSON

# API Endpoints Specification

Base path: `/api`

All endpoints return JSON. All mutating endpoints require an authenticated session.

## Common Response Envelope

Every response wraps data in a standard envelope:

```json
{
  "success": true,
  "message": "Operation completed",
  "data": { ... },
  "timestamp": "2024-01-15 14:30:00"
}
```

Error responses:

```json
{
  "success": false,
  "message": "Employee not found",
  "data": null,
  "timestamp": "2024-01-15 14:30:00"
}
```

Note: `timestamp` uses `java.util.Date` formatted with `SimpleDateFormat("yyyy-MM-dd HH:mm:ss")` — this is intentionally legacy.

---

## 1. Authentication Endpoints

### POST /api/auth/login

Authenticates a user and creates an HTTP session.

**Request Body:**
```json
{
  "username": "admin",
  "password": "password123"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "username": "admin",
    "role": "ADMIN",
    "sessionId": "ABC123..."
  },
  "timestamp": "2024-01-15 14:30:00"
}
```

**Failure Response (401):**
```json
{
  "success": false,
  "message": "Invalid username or password",
  "data": null,
  "timestamp": "2024-01-15 14:30:00"
}
```

**Implementation Notes:**
- Uses Spring Security's `AuthenticationManager` invoked manually (not via form login)
- Session is stored server-side using `HttpSession`
- Session timeout: 30 minutes (hardcoded in `SecurityConstants`)
- Password stored as bcrypt hash in database

### POST /api/auth/logout

Invalidates the current session.

**Response (200):**
```json
{
  "success": true,
  "message": "Logged out successfully",
  "data": null,
  "timestamp": "2024-01-15 14:30:00"
}
```

### GET /api/auth/me

Returns the currently authenticated user's info. Returns 401 if not authenticated.

**Response (200):**
```json
{
  "success": true,
  "message": "Current user info",
  "data": {
    "username": "admin",
    "role": "ADMIN"
  },
  "timestamp": "2024-01-15 14:30:00"
}
```

---

## 2. Employee Endpoints

### GET /api/employees

List all employees with optional pagination.

**Query Parameters:**
| Param  | Type | Default | Description         |
|--------|------|---------|---------------------|
| page   | int  | 0       | Page number (0-based) |
| size   | int  | 20      | Page size            |

**Response (200):**
```json
{
  "success": true,
  "message": "Employees retrieved",
  "data": {
    "employees": [
      {
        "id": 1,
        "name": "John Doe",
        "email": "john@example.com",
        "departmentId": 10,
        "departmentName": "Engineering",
        "position": "Senior Developer",
        "salary": 85000.00,
        "hireDate": "2020-03-15 00:00:00",
        "createdAt": "2020-03-15 10:30:00"
      }
    ],
    "totalCount": 42,
    "page": 0,
    "size": 20
  },
  "timestamp": "2024-01-15 14:30:00"
}
```

**Implementation Notes:**
- Pagination is implemented manually with OFFSET/LIMIT in SQL (not Spring Data Page)
- `departmentName` is joined in the SQL query, not fetched separately
- Date fields are `java.util.Date` serialized as strings by Jackson with `@JsonFormat`

### GET /api/employees/{id}

Get a single employee by ID.

**Response (200):** Single employee object in `data` field.

**Response (404):**
```json
{
  "success": false,
  "message": "Employee not found with id: 999",
  "data": null,
  "timestamp": "2024-01-15 14:30:00"
}
```

### POST /api/employees

Create a new employee. Requires ADMIN role.

**Request Body:**
```json
{
  "name": "Jane Smith",
  "email": "jane@example.com",
  "departmentId": 10,
  "position": "Developer",
  "salary": 75000.00,
  "hireDate": "2024-01-15 00:00:00"
}
```

**Validation Rules:**
- `name`: required, 2-100 chars
- `email`: required, must be valid email format, must be unique
- `departmentId`: required, must reference existing department
- `position`: required, 2-100 chars
- `salary`: required, must be > 0
- `hireDate`: required, must not be in the future

**Implementation Notes:**
- Validation is manual (if/else checks in service layer, NOT Bean Validation annotations)
- On success, triggers `NotificationService.sendNewEmployeeNotification()` (which just logs — no real email)
- The circular dependency kicks in here: creating an employee validates the department exists via `DepartmentService`

**Response (201):** Created employee in `data` field.

**Response (400):**
```json
{
  "success": false,
  "message": "Validation failed: email already exists",
  "data": null,
  "timestamp": "2024-01-15 14:30:00"
}
```

### PUT /api/employees/{id}

Update an existing employee. Requires ADMIN role.

**Request Body:** Same as POST (partial updates NOT supported — full replacement).

**Response (200):** Updated employee in `data` field.

**Response (404):** If employee not found.

**Response (400):** If validation fails.

### DELETE /api/employees/{id}

Delete an employee. Requires ADMIN role.

**Business Rules:**
- Cannot delete an employee who is a department manager (must reassign manager first)
- This check involves calling `DepartmentService.isDepartmentManager(employeeId)` — another point of circular dependency

**Response (200):**
```json
{
  "success": true,
  "message": "Employee deleted successfully",
  "data": null,
  "timestamp": "2024-01-15 14:30:00"
}
```

**Response (409):**
```json
{
  "success": false,
  "message": "Cannot delete employee: currently assigned as department manager",
  "data": null,
  "timestamp": "2024-01-15 14:30:00"
}
```

---

## 3. Department Endpoints

### GET /api/departments

List all departments.

**Response (200):**
```json
{
  "success": true,
  "message": "Departments retrieved",
  "data": [
    {
      "id": 10,
      "name": "Engineering",
      "managerId": 1,
      "managerName": "John Doe",
      "budget": 500000.00,
      "employeeCount": 15,
      "createdAt": "2019-06-01 00:00:00"
    }
  ],
  "timestamp": "2024-01-15 14:30:00"
}
```

**Implementation Notes:**
- `managerName` and `employeeCount` are fetched by calling `EmployeeService` from `DepartmentServiceImpl` — circular dependency
- No pagination (departments are assumed to be a small dataset)

### GET /api/departments/{id}

Get a single department by ID.

**Response (200):** Single department object in `data` field.
**Response (404):** If not found.

### POST /api/departments

Create a new department. Requires ADMIN role.

**Request Body:**
```json
{
  "name": "Marketing",
  "managerId": 5,
  "budget": 200000.00
}
```

**Validation Rules:**
- `name`: required, 2-100 chars, must be unique
- `managerId`: optional, if provided must reference existing employee
- `budget`: required, must be >= 0

**Response (201):** Created department in `data` field.

### PUT /api/departments/{id}

Update a department. Requires ADMIN role.

**Request Body:** Same as POST.

**Response (200):** Updated department in `data` field.

### DELETE /api/departments/{id}

Delete a department. Requires ADMIN role.

**Business Rules:**
- Cannot delete a department that still has employees assigned
- Must check employee count via `EmployeeService.countByDepartmentId()`

**Response (200):** Success message.

**Response (409):**
```json
{
  "success": false,
  "message": "Cannot delete department: 15 employees still assigned",
  "data": null,
  "timestamp": "2024-01-15 14:30:00"
}
```

---

## 4. Search Endpoint

### GET /api/employees/search

Search employees with multiple filter criteria.

**Query Parameters:**
| Param        | Type    | Description                          |
|--------------|---------|--------------------------------------|
| name         | string  | Partial name match (LIKE %name%)     |
| email        | string  | Partial email match                  |
| departmentId | int     | Exact department match               |
| position     | string  | Partial position match               |
| minSalary    | double  | Minimum salary (inclusive)           |
| maxSalary    | double  | Maximum salary (inclusive)           |
| hiredAfter   | string  | Hired on or after date (yyyy-MM-dd)  |
| hiredBefore  | string  | Hired on or before date (yyyy-MM-dd) |
| page         | int     | Page number (0-based), default 0     |
| size         | int     | Page size, default 20                |

**Response (200):** Same structure as GET /api/employees.

**Implementation Notes:**
- Search query is built dynamically in MyBatis XML using `<if>` and `<where>` tags
- Date parameters are parsed using `SimpleDateFormat("yyyy-MM-dd")` — legacy pattern
- The `SearchCriteria` model class holds all search parameters with manual null checks
- Some search parameters are also implemented in `EmployeeDaoImpl` via raw JDBC (duplicated logic with slightly different behavior — the JDBC version doesn't support `hiredAfter`/`hiredBefore`)

---

## 5. Error Handling

Error handling is NOT centralized:
- Each controller method has its own try/catch blocks
- Some exceptions are caught and wrapped, others propagate as 500 errors
- There is NO `@ControllerAdvice` or global exception handler
- `RuntimeException` is used for business logic errors (not custom exception classes)
- Some errors return HTTP 200 with `success: false` (incorrect but intentional legacy behavior)

This inconsistency is an intentional migration challenge.

---

## 6. Security Rules

| Endpoint Pattern       | Access          |
|------------------------|-----------------|
| POST /api/auth/login   | PUBLIC          |
| POST /api/auth/logout  | AUTHENTICATED   |
| GET /api/auth/me       | AUTHENTICATED   |
| GET /api/employees/**  | AUTHENTICATED   |
| POST /api/employees    | ROLE_ADMIN      |
| PUT /api/employees/**  | ROLE_ADMIN      |
| DELETE /api/employees/**| ROLE_ADMIN      |
| GET /api/departments/**| AUTHENTICATED   |
| POST /api/departments  | ROLE_ADMIN      |
| PUT /api/departments/**| ROLE_ADMIN      |
| DELETE /api/departments/**| ROLE_ADMIN   |
| GET /api/employees/search | AUTHENTICATED|

**Implementation Notes:**
- Security is configured entirely in `spring-security.xml`
- `CustomAuthenticationProvider` loads users from database via `UserDao` (raw JDBC)
- `SessionAuthFilter` is a custom filter in the Spring Security chain that checks for valid session
- CSRF protection is disabled (legacy API style)
- CORS is not configured (legacy assumption: same-origin deployment)

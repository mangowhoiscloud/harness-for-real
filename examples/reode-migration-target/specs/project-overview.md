# Employee Management System (EMS) — ASIS Codebase

## Purpose

A deliberately legacy Java 1.8 + Spring Framework 4.3.4 web application that serves as a migration test target for REODE.
The application is a small employee management REST API with session-based authentication.

**Target codebase size: ~3000 lines of Java source code** (excluding XML configs, SQL, and tests).

## Technology Stack (ASIS)

| Component        | Version                    |
|------------------|----------------------------|
| Java             | 1.8                        |
| Spring Framework | 4.3.4.RELEASE              |
| Spring Security  | 4.2.4.RELEASE              |
| MyBatis          | 3.2.2                      |
| MyBatis-Spring   | 1.2.2                      |
| PostgreSQL       | 9.6+ (driver: 42.2.5)      |
| Servlet API      | 3.1                        |
| Jackson          | 2.8.11                     |
| Build Tool       | Maven 3.x                  |
| Server           | Embedded Tomcat not used — assumes external Tomcat deployment via WAR |

## Migration Target (TOBE)

| Component        | Version                    |
|------------------|----------------------------|
| Java             | 22                         |
| Spring Boot      | 3.3.7                      |
| Spring Security  | 6.x (via Boot BOM)         |
| MyBatis          | 3.0.4                      |
| MyBatis-Spring-Boot-Starter | 3.0.4           |
| PostgreSQL       | 16+ (driver: 42.7.x)       |

## Project Structure

```
ems-legacy/
├── pom.xml
├── src/
│   ├── main/
│   │   ├── java/
│   │   │   └── com/
│   │   │       └── example/
│   │   │           └── ems/
│   │   │               ├── controller/
│   │   │               │   ├── EmployeeController.java
│   │   │               │   ├── DepartmentController.java
│   │   │               │   ├── AuthController.java
│   │   │               │   └── SearchController.java
│   │   │               ├── service/
│   │   │               │   ├── EmployeeService.java
│   │   │               │   ├── EmployeeServiceImpl.java
│   │   │               │   ├── DepartmentService.java
│   │   │               │   ├── DepartmentServiceImpl.java
│   │   │               │   ├── AuthService.java
│   │   │               │   ├── AuthServiceImpl.java
│   │   │               │   ├── NotificationService.java
│   │   │               │   └── NotificationServiceImpl.java
│   │   │               ├── dao/
│   │   │               │   ├── EmployeeDao.java
│   │   │               │   ├── EmployeeDaoImpl.java
│   │   │               │   ├── DepartmentDao.java
│   │   │               │   ├── DepartmentDaoImpl.java
│   │   │               │   └── UserDao.java
│   │   │               ├── mapper/
│   │   │               │   ├── EmployeeMapper.java       (MyBatis interface)
│   │   │               │   └── DepartmentMapper.java     (MyBatis interface)
│   │   │               ├── model/
│   │   │               │   ├── Employee.java
│   │   │               │   ├── Department.java
│   │   │               │   ├── User.java
│   │   │               │   ├── SearchCriteria.java
│   │   │               │   └── ApiResponse.java
│   │   │               ├── security/
│   │   │               │   ├── CustomAuthenticationProvider.java
│   │   │               │   ├── SessionAuthFilter.java
│   │   │               │   └── SecurityConstants.java
│   │   │               └── util/
│   │   │                   ├── DateUtil.java
│   │   │                   ├── ValidationUtil.java
│   │   │                   ├── DbConnectionUtil.java
│   │   │                   └── AppConfig.java       (static config holder)
│   │   ├── resources/
│   │   │   ├── applicationContext.xml
│   │   │   ├── spring-security.xml
│   │   │   ├── mybatis-config.xml
│   │   │   ├── mapper/
│   │   │   │   ├── EmployeeMapper.xml
│   │   │   │   └── DepartmentMapper.xml
│   │   │   ├── sql/
│   │   │   │   └── schema.sql
│   │   │   └── config.properties
│   │   └── webapp/
│   │       └── WEB-INF/
│   │           ├── web.xml
│   │           └── dispatcher-servlet.xml
│   └── test/
│       └── java/
│           └── com/
│               └── example/
│                   └── ems/
│                       ├── service/
│                       │   ├── EmployeeServiceTest.java
│                       │   └── DepartmentServiceTest.java
│                       ├── controller/
│                       │   ├── EmployeeControllerTest.java
│                       │   └── DepartmentControllerTest.java
│                       └── dao/
│                           └── EmployeeDaoTest.java
└── README.md
```

## Intentional Design Flaws (Migration Obstacles)

### 1. Circular Dependencies

- `EmployeeServiceImpl` depends on `DepartmentService` (to validate department exists when creating/updating employees)
- `DepartmentServiceImpl` depends on `EmployeeService` (to validate manager exists when creating/updating departments, to get employee count per department)
- Both are field-injected via `@Autowired`, creating a circular dependency that Spring 4.x resolves silently but Spring Boot 3.x with constructor injection will not

### 2. Poor Modularization

- `EmployeeServiceImpl` is a "god class" (~500 lines) that handles business logic, validation, some formatting, email notification triggering, and audit logging all in one
- `DepartmentServiceImpl` similarly mixes concerns (~350 lines)
- No separation between business logic and infrastructure concerns
- Util classes are used as dumping grounds for unrelated functionality

### 3. XML-Based Configuration (No Component Scan)

- All beans are declared in `applicationContext.xml` with manual `<bean>` definitions
- No `@ComponentScan`, no `@Configuration` classes
- `dispatcher-servlet.xml` configures Spring MVC with explicit handler mappings
- `spring-security.xml` configures the full security chain
- `web.xml` declares DispatcherServlet, context listeners, and filter chains

### 4. Java 1.8 Idioms Only

- **No `var`** — all types are explicitly declared
- **No records** — all model classes use manual getters/setters/toString/equals/hashCode
- **No switch expressions** — use traditional switch statements with break
- **No text blocks** — use string concatenation for multi-line strings
- **No `Optional` chaining** — null checks everywhere with if/else
- **No stream API for complex operations** — use traditional for-loops (some simple streams are OK for realism)
- **`java.util.Date`** and **`java.text.SimpleDateFormat`** instead of `java.time.*`
- **`java.sql.Timestamp`** for database datetime columns

### 5. Mixed Data Access Patterns

- `EmployeeMapper` and `DepartmentMapper` use MyBatis XML mapper files (proper pattern)
- `EmployeeDaoImpl` uses raw JDBC via `DbConnectionUtil` for some "special" queries
- `UserDao` uses raw JDBC entirely (no MyBatis at all)
- This inconsistency is intentional — migration must handle both patterns

### 6. Static State and Hardcoded Config

- `AppConfig.java` holds static fields loaded from `config.properties` at startup
- `DbConnectionUtil.java` manages its own connection pool with static methods
- `SecurityConstants.java` has hardcoded session timeout, token prefix, etc.
- Database URL, credentials scattered in `config.properties` AND `applicationContext.xml` (duplicated)
- Some constants are in code, some in properties, some in XML

### 7. No Dependency Injection via Constructor

- Every service and DAO uses `@Autowired` on fields (never on constructor)
- This makes testing harder and creates hidden dependencies
- Some beans have initialization logic in `@PostConstruct` methods that depend on injected fields

## Packaging

- The project builds as a WAR file (`<packaging>war</packaging>`)
- Deployed to external Tomcat (no embedded server)
- The TOBE migration target should be a Spring Boot JAR with embedded Tomcat

## Tests

Include basic JUnit 4 tests (not JUnit 5):
- Service tests with mock DAOs (using Mockito)
- Controller tests using Spring MVC Test framework
- One DAO test using in-memory H2 for integration testing
- Tests should use `@RunWith(SpringJUnit4ClassRunner.class)` (not `@ExtendWith`)
- Tests should total ~500 lines

## Build Configuration (pom.xml)

- Parent: none (no Spring Boot parent POM)
- Java source/target: 1.8
- All Spring dependencies declared explicitly with version numbers (no BOM import)
- MyBatis version: 3.2.2, MyBatis-Spring: 1.2.2
- JUnit 4.12 for testing
- Mockito 1.10.19 for mocking
- H2 1.4.197 for test database
- Maven WAR plugin configured
- No Spring Boot Maven plugin

## Line Count Targets

| Area               | Approximate Lines |
|--------------------|-------------------|
| Models (5 classes) | 400               |
| Controllers (4)    | 500               |
| Services (8)       | 1000              |
| DAOs (5)           | 400               |
| Security (3)       | 300               |
| Utils (4)          | 300               |
| XML configs (6)    | 400               |
| SQL schema         | 50                |
| Tests (5)          | 500               |
| pom.xml            | 150               |
| **Total**          | **~4000**         |

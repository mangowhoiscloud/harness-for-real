# Legacy Patterns Specification

This document catalogs every intentional legacy pattern in the EMS codebase. Each pattern represents a migration obstacle that REODE must detect and transform.

---

## 1. XML-Based Spring Configuration

### applicationContext.xml

All beans are manually wired. No `@ComponentScan`, no `@Configuration` classes.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xmlns:context="http://www.springframework.org/schema/context"
       xsi:schemaLocation="
           http://www.springframework.org/schema/beans
           http://www.springframework.org/schema/beans/spring-beans-4.3.xsd
           http://www.springframework.org/schema/context
           http://www.springframework.org/schema/context/spring-context-4.3.xsd">

    <!-- Property placeholder (legacy style) -->
    <context:property-placeholder location="classpath:config.properties"/>

    <!-- DataSource for MyBatis (duplicated config with DbConnectionUtil) -->
    <bean id="dataSource" class="org.apache.commons.dbcp2.BasicDataSource"
          destroy-method="close">
        <property name="driverClassName" value="${db.driver}"/>
        <property name="url" value="${db.url}"/>
        <property name="username" value="${db.username}"/>
        <property name="password" value="${db.password}"/>
        <property name="maxTotal" value="10"/>
        <property name="maxIdle" value="5"/>
    </bean>

    <!-- MyBatis SqlSessionFactory -->
    <bean id="sqlSessionFactory" class="org.mybatis.spring.SqlSessionFactoryBean">
        <property name="dataSource" ref="dataSource"/>
        <property name="configLocation" value="classpath:mybatis-config.xml"/>
        <property name="mapperLocations" value="classpath:mapper/*.xml"/>
    </bean>

    <!-- MyBatis Mapper Scanner -->
    <bean class="org.mybatis.spring.mapper.MapperScannerConfigurer">
        <property name="basePackage" value="com.example.ems.mapper"/>
        <property name="sqlSessionFactoryBeanName" value="sqlSessionFactory"/>
    </bean>

    <!-- Transaction Manager -->
    <bean id="transactionManager"
          class="org.springframework.jdbc.datasource.DataSourceTransactionManager">
        <property name="dataSource" ref="dataSource"/>
    </bean>

    <!-- DAO Beans -->
    <bean id="employeeDao" class="com.example.ems.dao.EmployeeDaoImpl"/>
    <bean id="departmentDao" class="com.example.ems.dao.DepartmentDaoImpl"/>
    <bean id="userDao" class="com.example.ems.dao.UserDao"/>

    <!-- Service Beans -->
    <bean id="employeeService" class="com.example.ems.service.EmployeeServiceImpl"/>
    <bean id="departmentService" class="com.example.ems.service.DepartmentServiceImpl"/>
    <bean id="authService" class="com.example.ems.service.AuthServiceImpl"/>
    <bean id="notificationService" class="com.example.ems.service.NotificationServiceImpl"/>

    <!-- Password Encoder -->
    <bean id="passwordEncoder"
          class="org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder"/>

</beans>
```

**Migration challenge:** Convert all `<bean>` definitions to `@Component`/`@Service`/`@Repository` annotations. Replace property-placeholder with `application.properties` or `application.yml`. Remove manual DataSource — use Spring Boot auto-configuration.

### dispatcher-servlet.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xmlns:mvc="http://www.springframework.org/schema/mvc"
       xmlns:context="http://www.springframework.org/schema/context"
       xsi:schemaLocation="
           http://www.springframework.org/schema/beans
           http://www.springframework.org/schema/beans/spring-beans-4.3.xsd
           http://www.springframework.org/schema/mvc
           http://www.springframework.org/schema/mvc/spring-mvc-4.3.xsd
           http://www.springframework.org/schema/context
           http://www.springframework.org/schema/context/spring-context-4.3.xsd">

    <!-- Enable annotation-driven MVC (for @Controller, @RequestMapping) -->
    <mvc:annotation-driven>
        <mvc:message-converters>
            <bean class="org.springframework.http.converter.json.MappingJackson2HttpMessageConverter">
                <property name="objectMapper">
                    <bean class="com.fasterxml.jackson.databind.ObjectMapper">
                        <property name="dateFormat">
                            <bean class="java.text.SimpleDateFormat">
                                <constructor-arg value="yyyy-MM-dd HH:mm:ss"/>
                            </bean>
                        </property>
                    </bean>
                </property>
            </bean>
        </mvc:message-converters>
    </mvc:annotation-driven>

    <!-- Component scan ONLY for controllers (inconsistency: services are in XML) -->
    <context:component-scan base-package="com.example.ems.controller"/>

</beans>
```

**Migration challenge:** The split between XML bean definitions (services/DAOs) and component scan (controllers only) must be unified. Jackson date format configuration moves to `application.properties`.

### web.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<web-app xmlns="http://xmlns.jcp.org/xml/ns/javaee"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://xmlns.jcp.org/xml/ns/javaee
                             http://xmlns.jcp.org/xml/ns/javaee/web-app_3_1.xsd"
         version="3.1">

    <display-name>Employee Management System</display-name>

    <!-- Root application context -->
    <context-param>
        <param-name>contextConfigLocation</param-name>
        <param-value>
            classpath:applicationContext.xml
            classpath:spring-security.xml
        </param-value>
    </context-param>

    <listener>
        <listener-class>
            org.springframework.web.context.ContextLoaderListener
        </listener-class>
    </listener>

    <!-- Spring Security Filter Chain -->
    <filter>
        <filter-name>springSecurityFilterChain</filter-name>
        <filter-class>
            org.springframework.web.filter.DelegatingFilterProxy
        </filter-class>
    </filter>
    <filter-mapping>
        <filter-name>springSecurityFilterChain</filter-name>
        <url-pattern>/*</url-pattern>
    </filter-mapping>

    <!-- Character encoding filter -->
    <filter>
        <filter-name>characterEncodingFilter</filter-name>
        <filter-class>
            org.springframework.web.filter.CharacterEncodingFilter
        </filter-class>
        <init-param>
            <param-name>encoding</param-name>
            <param-value>UTF-8</param-value>
        </init-param>
        <init-param>
            <param-name>forceEncoding</param-name>
            <param-value>true</param-value>
        </init-param>
    </filter>
    <filter-mapping>
        <filter-name>characterEncodingFilter</filter-name>
        <url-pattern>/*</url-pattern>
    </filter-mapping>

    <!-- DispatcherServlet -->
    <servlet>
        <servlet-name>dispatcher</servlet-name>
        <servlet-class>
            org.springframework.web.servlet.DispatcherServlet
        </servlet-class>
        <init-param>
            <param-name>contextConfigLocation</param-name>
            <param-value>/WEB-INF/dispatcher-servlet.xml</param-value>
        </init-param>
        <load-on-startup>1</load-on-startup>
    </servlet>
    <servlet-mapping>
        <servlet-name>dispatcher</servlet-name>
        <url-pattern>/</url-pattern>
    </servlet-mapping>

    <!-- Session config -->
    <session-config>
        <session-timeout>30</session-timeout>
    </session-config>

</web-app>
```

**Migration challenge:** `web.xml` is entirely eliminated in Spring Boot. DispatcherServlet, filters, listeners — all auto-configured. Session timeout moves to `application.properties`.

### spring-security.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xmlns:security="http://www.springframework.org/schema/security"
       xsi:schemaLocation="
           http://www.springframework.org/schema/beans
           http://www.springframework.org/schema/beans/spring-beans-4.3.xsd
           http://www.springframework.org/schema/security
           http://www.springframework.org/schema/security/spring-security-4.2.xsd">

    <security:http auto-config="false" use-expressions="true"
                   entry-point-ref="restAuthEntryPoint">

        <security:csrf disabled="true"/>

        <security:intercept-url pattern="/api/auth/login" access="permitAll"/>
        <security:intercept-url pattern="/api/auth/logout" access="isAuthenticated()"/>
        <security:intercept-url pattern="/api/auth/me" access="isAuthenticated()"/>
        <security:intercept-url pattern="/api/employees" method="GET" access="isAuthenticated()"/>
        <security:intercept-url pattern="/api/employees/search" access="isAuthenticated()"/>
        <security:intercept-url pattern="/api/employees/**" method="POST" access="hasRole('ADMIN')"/>
        <security:intercept-url pattern="/api/employees/**" method="PUT" access="hasRole('ADMIN')"/>
        <security:intercept-url pattern="/api/employees/**" method="DELETE" access="hasRole('ADMIN')"/>
        <security:intercept-url pattern="/api/departments" method="GET" access="isAuthenticated()"/>
        <security:intercept-url pattern="/api/departments/**" method="POST" access="hasRole('ADMIN')"/>
        <security:intercept-url pattern="/api/departments/**" method="PUT" access="hasRole('ADMIN')"/>
        <security:intercept-url pattern="/api/departments/**" method="DELETE" access="hasRole('ADMIN')"/>
        <security:intercept-url pattern="/**" access="denyAll"/>

        <security:custom-filter ref="sessionAuthFilter" before="FORM_LOGIN_FILTER"/>

    </security:http>

    <!-- REST-friendly entry point (returns 401 JSON, not redirect) -->
    <bean id="restAuthEntryPoint"
          class="com.example.ems.security.RestAuthenticationEntryPoint"/>

    <!-- Session auth filter -->
    <bean id="sessionAuthFilter"
          class="com.example.ems.security.SessionAuthFilter"/>

    <!-- Authentication manager with custom provider -->
    <security:authentication-manager alias="authenticationManager">
        <security:authentication-provider ref="customAuthProvider"/>
    </security:authentication-manager>

    <bean id="customAuthProvider"
          class="com.example.ems.security.CustomAuthenticationProvider"/>

</beans>
```

**Migration challenge:** Spring Security 6.x uses `SecurityFilterChain` bean configuration, not XML. `WebSecurityConfigurerAdapter` is removed. Expression-based access control syntax changes. `hasRole('ADMIN')` becomes `hasRole('ADMIN')` but the underlying mechanism changes significantly.

---

## 2. Hardcoded Configuration Values

### config.properties

```properties
# Database
db.driver=org.postgresql.Driver
db.url=jdbc:postgresql://localhost:5432/ems_db
db.username=ems_user
db.password=ems_password

# Application
app.name=Employee Management System
app.version=1.0.0
```

### Scattered hardcoded values (in code, NOT in properties)

| Location                      | Value                              | Should Be          |
|-------------------------------|------------------------------------|---------------------|
| SecurityConstants.java        | `SESSION_TIMEOUT = 1800` (30 min)  | config property     |
| SecurityConstants.java        | `MAX_LOGIN_ATTEMPTS = 5`           | config property     |
| SecurityConstants.java        | `SESSION_COOKIE_NAME = "EMSSID"`   | config property     |
| DbConnectionUtil.java         | `MAX_POOL_SIZE = 10`               | config property     |
| EmployeeServiceImpl.java      | `DEFAULT_PAGE_SIZE = 20`           | config property     |
| EmployeeServiceImpl.java      | `MAX_SALARY = 999999.99`           | config property     |
| ValidationUtil.java           | `EMAIL_REGEX = "^[A-Za-z0-9+_.-]+@(.+)$"` | config property |
| NotificationServiceImpl.java  | `LOG_PREFIX = "[EMS-NOTIFY]"`      | config property     |

**Migration challenge:** All hardcoded values must be externalized to `application.properties` or `application.yml` with `@Value` or `@ConfigurationProperties`.

---

## 3. Field Injection Everywhere

Every service and DAO uses field injection:

```java
@Autowired
private EmployeeMapper employeeMapper;

@Autowired
private DepartmentService departmentService;  // circular dep!
```

Never:
```java
// NONE of the classes use constructor injection
public EmployeeServiceImpl(EmployeeMapper mapper, DepartmentService deptService) { ... }
```

**Migration challenge:** Convert to constructor injection. This immediately surfaces the circular dependency that Spring 4.x silently resolved. The circular dependency must be broken (e.g., by extracting a shared service, using `@Lazy`, or refactoring the architecture).

---

## 4. Deprecated Java 1.8 APIs

### Date/Time

```java
// Used throughout the codebase:
import java.util.Date;
import java.text.SimpleDateFormat;
import java.sql.Timestamp;

Date now = new Date();
SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
String formatted = sdf.format(now);
Date parsed = sdf.parse(dateString);  // throws ParseException

// In DAO layer:
Timestamp ts = rs.getTimestamp("hire_date");
employee.setHireDate(ts);  // Timestamp extends Date, implicit upcasting
```

**Migration target:**
```java
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
```

### Collections

```java
// Raw generic type usage in a few places:
List employees = new ArrayList();  // raw type in UserDao

// Diamond operator not consistently used:
Map<String, Object> params = new HashMap<String, Object>();  // verbose
```

### String Operations

```java
// String concatenation in loops (inefficient):
String result = "";
for (String error : errors) {
    result = result + error + "; ";
}
```

---

## 5. Util Classes with Static State

### AppConfig.java

```java
public class AppConfig {
    private static String appName;
    private static String appVersion;
    private static String dbUrl;
    private static String dbUsername;
    private static String dbPassword;

    // Called once at startup from a ServletContextListener or @PostConstruct
    public static void init(Properties props) {
        appName = props.getProperty("app.name");
        appVersion = props.getProperty("app.version");
        dbUrl = props.getProperty("db.url");
        dbUsername = props.getProperty("db.username");
        dbPassword = props.getProperty("db.password");
        // Also initializes DbConnectionUtil
        DbConnectionUtil.init(dbUrl, dbUsername, dbPassword);
    }

    public static String getAppName() { return appName; }
    public static String getDbUrl() { return dbUrl; }
    // ... more static getters
}
```

**Problems:**
- Static mutable state — not testable, not injectable
- Initialization order dependency — `AppConfig.init()` must run before any DAO
- Duplicates DataSource config from `applicationContext.xml`

### DateUtil.java

```java
public class DateUtil {
    // SimpleDateFormat is NOT thread-safe, but stored as static field
    private static final SimpleDateFormat DATE_FORMAT =
        new SimpleDateFormat("yyyy-MM-dd");
    private static final SimpleDateFormat DATETIME_FORMAT =
        new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");

    public static String formatDate(Date date) { ... }
    public static String formatDateTime(Date date) { ... }
    public static Date parseDate(String str) { ... }       // throws RuntimeException
    public static Date parseDateTime(String str) { ... }   // throws RuntimeException
    public static boolean isBeforeToday(Date date) { ... }
    public static boolean isAfterToday(Date date) { ... }
}
```

**Problems:**
- `SimpleDateFormat` is NOT thread-safe — shared static instance will produce corrupted dates under concurrent access
- Should be replaced with `java.time.format.DateTimeFormatter` (which IS thread-safe)

### ValidationUtil.java

```java
public class ValidationUtil {
    private static final String EMAIL_REGEX = "^[A-Za-z0-9+_.-]+@(.+)$";

    public static boolean isValidEmail(String email) { ... }
    public static boolean isNotBlank(String str) { ... }
    public static boolean isPositiveNumber(Double number) { ... }
    public static boolean isWithinLength(String str, int min, int max) { ... }

    // Accumulates validation errors in a passed-in list (mutable parameter)
    public static void validateEmployee(Employee emp, List<String> errors) {
        if (!isNotBlank(emp.getName())) {
            errors.add("Name is required");
        }
        if (!isNotBlank(emp.getEmail()) || !isValidEmail(emp.getEmail())) {
            errors.add("Valid email is required");
        }
        // ... more checks
    }
}
```

---

## 6. WAR Packaging and External Servlet Container

### pom.xml packaging

```xml
<packaging>war</packaging>
```

### No main() method

There is no `main()` method anywhere. The application is deployed to an external Tomcat.

### Servlet API provided scope

```xml
<dependency>
    <groupId>javax.servlet</groupId>
    <artifactId>javax.servlet-api</artifactId>
    <version>3.1.0</version>
    <scope>provided</scope>
</dependency>
```

**Migration challenge:** Convert to Spring Boot executable JAR with embedded Tomcat. Add `@SpringBootApplication` main class. `javax.servlet` becomes `jakarta.servlet`.

---

## 7. javax.* Namespace (Pre-Jakarta)

All imports use `javax.*`:
- `javax.servlet.http.HttpServletRequest`
- `javax.servlet.http.HttpServletResponse`
- `javax.servlet.http.HttpSession`
- `javax.servlet.Filter`
- `javax.servlet.FilterChain`

**Migration challenge:** Spring Boot 3.x requires Jakarta EE 10 — all `javax.servlet.*` becomes `jakarta.servlet.*`. This is a global find-replace but affects every controller, filter, and security class.

---

## 8. Error Handling Anti-Patterns

### No Global Exception Handler

Each controller catches exceptions individually:

```java
@RequestMapping(value = "/api/employees", method = RequestMethod.GET)
@ResponseBody
public ApiResponse getAllEmployees(
        @RequestParam(value = "page", defaultValue = "0") int page,
        @RequestParam(value = "size", defaultValue = "20") int size) {
    try {
        // ... business logic
        return ApiResponse.ok("Employees retrieved", result);
    } catch (Exception e) {
        return ApiResponse.error("Failed to retrieve employees: " + e.getMessage());
    }
}
```

**Problems:**
- Duplicated try-catch in every method
- HTTP 200 returned even for errors (only `success: false` in body)
- Stack traces swallowed (logged to console but not structured)
- No distinction between 400, 404, 409, 500 status codes in error paths

### Exception Types

Only `RuntimeException` is thrown:
```java
throw new RuntimeException("Employee not found with id: " + id);
throw new RuntimeException("Validation failed: " + String.join(", ", errors));
throw new RuntimeException("Cannot delete: employee is a department manager");
```

No custom exception hierarchy.

---

## 9. Transaction Management

- `@Transactional` is NOT used on any service method
- Transaction management is declared in XML but NOT applied (missing `<tx:annotation-driven/>` or AOP config)
- This means all database operations run without transaction boundaries (auto-commit)
- The migration must add proper `@Transactional` annotations

---

## 10. Test Anti-Patterns

- JUnit 4 (`@Test` from `org.junit.Test`, `@RunWith`)
- `@RunWith(SpringJUnit4ClassRunner.class)` instead of `@ExtendWith(SpringExtension.class)`
- `@ContextConfiguration` loading XML files instead of `@SpringBootTest`
- Mockito 1.x syntax (`@Mock`, `when().thenReturn()`, `Mockito.verify()`)
- Some tests have `@SuppressWarnings("deprecation")`
- No parameterized tests
- No assertAll() or assertThrows() (JUnit 5 features)

---

## Summary: Migration Obstacle Matrix

| # | Pattern                          | ASIS                           | TOBE                                    | Difficulty |
|---|----------------------------------|--------------------------------|-----------------------------------------|------------|
| 1 | Spring config                    | XML beans                      | @Component/@Service annotations         | HIGH       |
| 2 | Servlet config                   | web.xml                        | Auto-configured (eliminated)            | MEDIUM     |
| 3 | Security config                  | spring-security.xml            | SecurityFilterChain bean                | HIGH       |
| 4 | Dependency injection             | Field @Autowired               | Constructor injection                   | HIGH       |
| 5 | Circular dependency              | Hidden (Spring resolves it)    | Must be refactored                      | HIGH       |
| 6 | Date/Time API                    | java.util.Date                 | java.time.*                             | MEDIUM     |
| 7 | Servlet namespace                | javax.servlet.*                | jakarta.servlet.*                       | LOW        |
| 8 | Packaging                        | WAR + external Tomcat          | Executable JAR + embedded Tomcat        | MEDIUM     |
| 9 | DataSource                       | Manual XML + DbConnectionUtil  | Spring Boot auto-config                 | MEDIUM     |
| 10| MyBatis config                   | XML SqlSessionFactory          | mybatis-spring-boot-starter auto-config | MEDIUM     |
| 11| Raw JDBC mixed with MyBatis      | Inconsistent data access       | Unified MyBatis (or JdbcTemplate)       | MEDIUM     |
| 12| Static state (AppConfig, DateUtil)| Static mutable fields         | Spring beans + @ConfigurationProperties | MEDIUM     |
| 13| Hardcoded config                 | Constants in code              | Externalized to application.properties  | LOW        |
| 14| Error handling                   | Per-method try/catch           | @ControllerAdvice + custom exceptions   | MEDIUM     |
| 15| Transaction management           | Missing/broken                 | @Transactional on service methods       | LOW        |
| 16| Test framework                   | JUnit 4 + Spring 4 test        | JUnit 5 + @SpringBootTest              | MEDIUM     |
| 17| Java version                     | 1.8 syntax                     | Java 22 (records, var, patterns)        | LOW        |

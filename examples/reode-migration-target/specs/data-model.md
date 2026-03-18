# Data Model & MyBatis Mapper Specification

## Database: PostgreSQL

---

## 1. Schema Definition (schema.sql)

```sql
-- Users table for authentication
CREATE TABLE users (
    id          SERIAL PRIMARY KEY,
    username    VARCHAR(50)  NOT NULL UNIQUE,
    password    VARCHAR(255) NOT NULL,  -- bcrypt hash
    role        VARCHAR(20)  NOT NULL DEFAULT 'USER',  -- 'ADMIN' or 'USER'
    enabled     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Departments table
CREATE TABLE departments (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE,
    manager_id  INTEGER,  -- FK to employees (nullable, set after employee creation)
    budget      DECIMAL(15, 2) NOT NULL DEFAULT 0,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Employees table
CREATE TABLE employees (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    email           VARCHAR(255) NOT NULL UNIQUE,
    department_id   INTEGER NOT NULL,
    position        VARCHAR(100) NOT NULL,
    salary          DECIMAL(12, 2) NOT NULL,
    hire_date       TIMESTAMP NOT NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_employee_department
        FOREIGN KEY (department_id) REFERENCES departments(id)
);

-- Add FK from departments.manager_id to employees.id (after employees table exists)
ALTER TABLE departments
    ADD CONSTRAINT fk_department_manager
        FOREIGN KEY (manager_id) REFERENCES employees(id);

-- Indexes
CREATE INDEX idx_employees_department_id ON employees(department_id);
CREATE INDEX idx_employees_email ON employees(email);
CREATE INDEX idx_employees_name ON employees(name);
CREATE INDEX idx_employees_hire_date ON employees(hire_date);

-- Seed data: default admin user (password: admin123, bcrypt hash)
INSERT INTO users (username, password, role) VALUES
    ('admin', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'ADMIN'),
    ('user1', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'USER');

-- Seed data: departments (manager_id set to NULL initially)
INSERT INTO departments (name, budget) VALUES
    ('Engineering', 500000.00),
    ('Marketing', 200000.00),
    ('Human Resources', 150000.00);

-- Seed data: employees
INSERT INTO employees (name, email, department_id, position, salary, hire_date) VALUES
    ('John Doe', 'john.doe@example.com', 1, 'Senior Developer', 85000.00, '2020-03-15'),
    ('Jane Smith', 'jane.smith@example.com', 1, 'Developer', 75000.00, '2021-06-01'),
    ('Bob Wilson', 'bob.wilson@example.com', 2, 'Marketing Manager', 90000.00, '2019-01-10'),
    ('Alice Brown', 'alice.brown@example.com', 3, 'HR Specialist', 65000.00, '2022-09-20'),
    ('Charlie Davis', 'charlie.davis@example.com', 1, 'Junior Developer', 55000.00, '2023-02-14');

-- Set department managers
UPDATE departments SET manager_id = 1 WHERE name = 'Engineering';
UPDATE departments SET manager_id = 3 WHERE name = 'Marketing';
UPDATE departments SET manager_id = 4 WHERE name = 'Human Resources';
```

### Circular Foreign Key Note

The circular FK relationship between `employees.department_id -> departments.id` and `departments.manager_id -> employees.id` is intentional. This creates:
- A chicken-and-egg problem for inserts (must insert department without manager first, then employee, then update department)
- Complexity for deletes (cannot naively cascade)
- A real-world pattern that migration tools must handle

---

## 2. Java Model Classes

### Employee.java

```java
public class Employee {
    private Integer id;
    private String name;
    private String email;
    private Integer departmentId;
    private String departmentName;    // transient, populated from JOIN
    private String position;
    private Double salary;            // Double, not BigDecimal (legacy mistake)
    private Date hireDate;            // java.util.Date
    private Date createdAt;           // java.util.Date

    // Manual getters and setters for ALL fields
    // Manual toString() with string concatenation
    // Manual equals() and hashCode() using id only
    // No-arg constructor + all-arg constructor
}
```

### Department.java

```java
public class Department {
    private Integer id;
    private String name;
    private Integer managerId;
    private String managerName;       // transient, populated from service layer
    private Double budget;            // Double, not BigDecimal (legacy mistake)
    private Integer employeeCount;    // transient, populated from service layer
    private Date createdAt;           // java.util.Date

    // Manual getters, setters, toString, equals, hashCode
}
```

### User.java

```java
public class User {
    private Integer id;
    private String username;
    private String password;          // bcrypt hash
    private String role;              // "ADMIN" or "USER"
    private Boolean enabled;
    private Date createdAt;           // java.util.Date

    // Manual getters, setters, toString (excluding password), equals, hashCode
}
```

### SearchCriteria.java

```java
public class SearchCriteria {
    private String name;
    private String email;
    private Integer departmentId;
    private String position;
    private Double minSalary;
    private Double maxSalary;
    private Date hiredAfter;          // java.util.Date
    private Date hiredBefore;         // java.util.Date
    private Integer page;             // default 0
    private Integer size;             // default 20

    // Manual getters, setters
    // Helper: getOffset() returns page * size
    // Helper: hasAnyCriteria() returns true if any search field is non-null
}
```

### ApiResponse.java

```java
public class ApiResponse {
    private boolean success;
    private String message;
    private Object data;              // Object type, not generic (legacy pattern)
    private String timestamp;         // String, not Date (formatted at creation)

    // Static factory: ApiResponse.ok(String message, Object data)
    // Static factory: ApiResponse.error(String message)
    // Timestamp set in constructor using:
    //   new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new Date())
}
```

**Legacy patterns in models:**
- `Double` instead of `BigDecimal` for monetary values
- `java.util.Date` instead of `java.time.LocalDate`/`LocalDateTime`
- `Object` instead of generics for `ApiResponse.data`
- Manual equals/hashCode/toString (no Lombok, no records)
- String concatenation in `toString()` (no `String.format` or text blocks)

---

## 3. MyBatis Configuration

### mybatis-config.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE configuration PUBLIC "-//mybatis.org//DTD Config 3.0//EN"
    "http://mybatis.org/dtd/mybatis-3-config.dtd">
<configuration>
    <settings>
        <setting name="mapUnderscoreToCamelCase" value="true"/>
        <setting name="lazyLoadingEnabled" value="false"/>
        <setting name="cacheEnabled" value="false"/>
    </settings>

    <typeAliases>
        <typeAlias type="com.example.ems.model.Employee" alias="Employee"/>
        <typeAlias type="com.example.ems.model.Department" alias="Department"/>
        <typeAlias type="com.example.ems.model.SearchCriteria" alias="SearchCriteria"/>
    </typeAliases>
</configuration>
```

### EmployeeMapper.xml

Location: `src/main/resources/mapper/EmployeeMapper.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE mapper PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN"
    "http://mybatis.org/dtd/mybatis-3-mapper.dtd">
<mapper namespace="com.example.ems.mapper.EmployeeMapper">

    <resultMap id="employeeResultMap" type="Employee">
        <id property="id" column="id"/>
        <result property="name" column="name"/>
        <result property="email" column="email"/>
        <result property="departmentId" column="department_id"/>
        <result property="departmentName" column="department_name"/>
        <result property="position" column="position"/>
        <result property="salary" column="salary"/>
        <result property="hireDate" column="hire_date" javaType="java.util.Date"/>
        <result property="createdAt" column="created_at" javaType="java.util.Date"/>
    </resultMap>

    <select id="findAll" resultMap="employeeResultMap">
        SELECT e.*, d.name AS department_name
        FROM employees e
        LEFT JOIN departments d ON e.department_id = d.id
        ORDER BY e.id
        LIMIT #{size} OFFSET #{offset}
    </select>

    <select id="findById" parameterType="int" resultMap="employeeResultMap">
        SELECT e.*, d.name AS department_name
        FROM employees e
        LEFT JOIN departments d ON e.department_id = d.id
        WHERE e.id = #{id}
    </select>

    <select id="findByEmail" parameterType="string" resultMap="employeeResultMap">
        SELECT e.*, d.name AS department_name
        FROM employees e
        LEFT JOIN departments d ON e.department_id = d.id
        WHERE e.email = #{email}
    </select>

    <select id="countAll" resultType="int">
        SELECT COUNT(*) FROM employees
    </select>

    <select id="countByDepartmentId" parameterType="int" resultType="int">
        SELECT COUNT(*) FROM employees WHERE department_id = #{departmentId}
    </select>

    <insert id="insert" parameterType="Employee" useGeneratedKeys="true" keyProperty="id">
        INSERT INTO employees (name, email, department_id, position, salary, hire_date)
        VALUES (#{name}, #{email}, #{departmentId}, #{position}, #{salary}, #{hireDate})
    </insert>

    <update id="update" parameterType="Employee">
        UPDATE employees
        SET name = #{name},
            email = #{email},
            department_id = #{departmentId},
            position = #{position},
            salary = #{salary},
            hire_date = #{hireDate}
        WHERE id = #{id}
    </update>

    <delete id="delete" parameterType="int">
        DELETE FROM employees WHERE id = #{id}
    </delete>

    <!-- Dynamic search query with legacy MyBatis <if> pattern -->
    <select id="search" parameterType="SearchCriteria" resultMap="employeeResultMap">
        SELECT e.*, d.name AS department_name
        FROM employees e
        LEFT JOIN departments d ON e.department_id = d.id
        <where>
            <if test="name != null and name != ''">
                AND LOWER(e.name) LIKE LOWER(CONCAT('%', #{name}, '%'))
            </if>
            <if test="email != null and email != ''">
                AND LOWER(e.email) LIKE LOWER(CONCAT('%', #{email}, '%'))
            </if>
            <if test="departmentId != null">
                AND e.department_id = #{departmentId}
            </if>
            <if test="position != null and position != ''">
                AND LOWER(e.position) LIKE LOWER(CONCAT('%', #{position}, '%'))
            </if>
            <if test="minSalary != null">
                AND e.salary &gt;= #{minSalary}
            </if>
            <if test="maxSalary != null">
                AND e.salary &lt;= #{maxSalary}
            </if>
            <if test="hiredAfter != null">
                AND e.hire_date &gt;= #{hiredAfter}
            </if>
            <if test="hiredBefore != null">
                AND e.hire_date &lt;= #{hiredBefore}
            </if>
        </where>
        ORDER BY e.id
        LIMIT #{size} OFFSET #{offset}
    </select>

    <select id="searchCount" parameterType="SearchCriteria" resultType="int">
        SELECT COUNT(*)
        FROM employees e
        <where>
            <if test="name != null and name != ''">
                AND LOWER(e.name) LIKE LOWER(CONCAT('%', #{name}, '%'))
            </if>
            <if test="email != null and email != ''">
                AND LOWER(e.email) LIKE LOWER(CONCAT('%', #{email}, '%'))
            </if>
            <if test="departmentId != null">
                AND e.department_id = #{departmentId}
            </if>
            <if test="position != null and position != ''">
                AND LOWER(e.position) LIKE LOWER(CONCAT('%', #{position}, '%'))
            </if>
            <if test="minSalary != null">
                AND e.salary &gt;= #{minSalary}
            </if>
            <if test="maxSalary != null">
                AND e.salary &lt;= #{maxSalary}
            </if>
            <if test="hiredAfter != null">
                AND e.hire_date &gt;= #{hiredAfter}
            </if>
            <if test="hiredBefore != null">
                AND e.hire_date &lt;= #{hiredBefore}
            </if>
        </where>
    </select>

</mapper>
```

### DepartmentMapper.xml

Location: `src/main/resources/mapper/DepartmentMapper.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE mapper PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN"
    "http://mybatis.org/dtd/mybatis-3-mapper.dtd">
<mapper namespace="com.example.ems.mapper.DepartmentMapper">

    <resultMap id="departmentResultMap" type="Department">
        <id property="id" column="id"/>
        <result property="name" column="name"/>
        <result property="managerId" column="manager_id"/>
        <result property="budget" column="budget"/>
        <result property="createdAt" column="created_at" javaType="java.util.Date"/>
    </resultMap>

    <select id="findAll" resultMap="departmentResultMap">
        SELECT * FROM departments ORDER BY id
    </select>

    <select id="findById" parameterType="int" resultMap="departmentResultMap">
        SELECT * FROM departments WHERE id = #{id}
    </select>

    <select id="findByName" parameterType="string" resultMap="departmentResultMap">
        SELECT * FROM departments WHERE name = #{name}
    </select>

    <select id="findByManagerId" parameterType="int" resultMap="departmentResultMap">
        SELECT * FROM departments WHERE manager_id = #{managerId}
    </select>

    <insert id="insert" parameterType="Department" useGeneratedKeys="true" keyProperty="id">
        INSERT INTO departments (name, manager_id, budget)
        VALUES (#{name}, #{managerId}, #{budget})
    </insert>

    <update id="update" parameterType="Department">
        UPDATE departments
        SET name = #{name},
            manager_id = #{managerId},
            budget = #{budget}
        WHERE id = #{id}
    </update>

    <delete id="delete" parameterType="int">
        DELETE FROM departments WHERE id = #{id}
    </delete>

</mapper>
```

### MyBatis Mapper Interfaces

**EmployeeMapper.java:**
```java
public interface EmployeeMapper {
    List<Employee> findAll(@Param("size") int size, @Param("offset") int offset);
    Employee findById(int id);
    Employee findByEmail(String email);
    int countAll();
    int countByDepartmentId(int departmentId);
    void insert(Employee employee);
    void update(Employee employee);
    void delete(int id);
    List<Employee> search(SearchCriteria criteria);
    int searchCount(SearchCriteria criteria);
}
```

**DepartmentMapper.java:**
```java
public interface DepartmentMapper {
    List<Department> findAll();
    Department findById(int id);
    Department findByName(String name);
    Department findByManagerId(int managerId);
    void insert(Department department);
    void update(Department department);
    void delete(int id);
}
```

---

## 4. Raw JDBC Data Access (Legacy Pattern)

### EmployeeDaoImpl.java — Mixed Pattern

`EmployeeDaoImpl` wraps MyBatis `EmployeeMapper` for most operations BUT also has two raw JDBC methods:

```java
// Uses raw JDBC via DbConnectionUtil — NOT MyBatis
public List<Employee> findBySalaryRange(double min, double max) {
    Connection conn = null;
    PreparedStatement ps = null;
    ResultSet rs = null;
    List<Employee> employees = new ArrayList<Employee>();
    try {
        conn = DbConnectionUtil.getConnection();
        ps = conn.prepareStatement(
            "SELECT e.*, d.name AS department_name " +
            "FROM employees e " +
            "LEFT JOIN departments d ON e.department_id = d.id " +
            "WHERE e.salary BETWEEN ? AND ? " +
            "ORDER BY e.salary DESC"
        );
        ps.setDouble(1, min);
        ps.setDouble(2, max);
        rs = ps.executeQuery();
        while (rs.next()) {
            employees.add(mapRow(rs));
        }
    } catch (SQLException e) {
        throw new RuntimeException("Error finding employees by salary range", e);
    } finally {
        DbConnectionUtil.close(conn, ps, rs);
    }
    return employees;
}

// Manual ResultSet to Employee mapping (duplicates MyBatis mapping logic)
private Employee mapRow(ResultSet rs) throws SQLException {
    Employee emp = new Employee();
    emp.setId(rs.getInt("id"));
    emp.setName(rs.getString("name"));
    emp.setEmail(rs.getString("email"));
    emp.setDepartmentId(rs.getInt("department_id"));
    emp.setDepartmentName(rs.getString("department_name"));
    emp.setPosition(rs.getString("position"));
    emp.setSalary(rs.getDouble("salary"));
    emp.setHireDate(rs.getTimestamp("hire_date"));   // java.sql.Timestamp -> java.util.Date
    emp.setCreatedAt(rs.getTimestamp("created_at"));
    return emp;
}
```

### UserDao.java — Entirely Raw JDBC

`UserDao` does NOT use MyBatis at all. It uses raw JDBC exclusively:

```java
public class UserDao {
    // No MyBatis mapper — entirely raw JDBC

    public User findByUsername(String username) { ... }
    public void createUser(User user) { ... }
    public void updatePassword(String username, String newPasswordHash) { ... }
    public boolean existsByUsername(String username) { ... }
}
```

All methods follow the same pattern: `getConnection()` -> `prepareStatement()` -> `executeQuery()` -> manual mapping -> `close()` in finally block.

---

## 5. DbConnectionUtil.java

Static utility that maintains a primitive connection pool:

```java
public class DbConnectionUtil {
    private static String url;       // loaded from AppConfig
    private static String username;
    private static String password;
    private static final List<Connection> pool = new ArrayList<Connection>();  // raw list, not thread-safe
    private static final int MAX_POOL_SIZE = 10;

    public static void init(String dbUrl, String dbUser, String dbPass) { ... }
    public static Connection getConnection() throws SQLException { ... }
    public static void close(Connection conn, Statement stmt, ResultSet rs) { ... }
    public static void shutdown() { ... }
}
```

**Problems (intentional):**
- Not thread-safe (plain `ArrayList`, no synchronization)
- No connection validation (stale connections returned)
- `init()` called from `AppConfig` static initializer — order-dependent
- Duplicates the DataSource configured in `applicationContext.xml` for MyBatis

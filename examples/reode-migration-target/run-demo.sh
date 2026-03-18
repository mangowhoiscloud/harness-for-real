#!/usr/bin/env bash
set -euo pipefail

# ╔═══════════════════════════════════════════════════════════════╗
# ║  Harness Demo — REODE Migration Target (EMS Legacy)          ║
# ║  Java 1.8 + Spring 4.3.4 → Java 22 + Spring Boot 3.3.7      ║
# ║  Reduced iterations for test run                              ║
# ╚═══════════════════════════════════════════════════════════════╝

HARNESS_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Harness Demo: REODE Migration Target (EMS Legacy) ==="
echo ""
echo "This demo runs the full 4-phase harness with reduced iterations:"
echo "  Socratic: max 5 rounds  (normally 150)"
echo "  Plan:     max 3 rounds  (normally 10)"
echo "  Build:    max 30 rounds (normally 999)"
echo "  Verify:   max 3 rounds  (normally 20)"
echo ""
echo "Target: Build a ~3000 line Java 1.8 + Spring Framework 4.3.4 legacy"
echo "        codebase that serves as a migration test target for REODE."
echo ""

# ─── Prerequisite check ──────────────────────────────────────
echo "[check] Verifying prerequisites..."

if ! command -v java &>/dev/null; then
  echo "[WARN] Java not found. The harness will build the project but"
  echo "       compilation may fail without a JDK. Install JDK 8+ to compile."
fi

if ! command -v mvn &>/dev/null; then
  echo "[WARN] Maven not found. Install Maven 3.x to compile the project."
  echo "       The harness can still generate source files without Maven."
fi

echo "[check] Prerequisites verified."
echo ""

# ─── Setup project ───────────────────────────────────────────
cd "$DEMO_DIR"

# Init git if needed
if [ ! -d ".git" ]; then
  git init
  git add -A
  git commit -m "init: reode migration target demo project"
fi

# Copy harness files into demo project
cp "$HARNESS_DIR/CLAUDE.md" .
cp "$HARNESS_DIR/AGENTS.md" .
cp "$HARNESS_DIR/PROMPT_socratic.md" .
cp "$HARNESS_DIR/PROMPT_plan.md" .
cp "$HARNESS_DIR/PROMPT_build.md" .
cp "$HARNESS_DIR/PROMPT_verify.md" .
cp "$HARNESS_DIR/loop.sh" .
cp "$HARNESS_DIR/init.sh" .
cp -r "$HARNESS_DIR/hooks" .
mkdir -p scripts
cp "$HARNESS_DIR/scripts/monitor.sh" scripts/

# Create pom.xml for Java/Maven project detection
if [ ! -f "pom.xml" ]; then
  cat > pom.xml << 'POMXML'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
                             http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.example</groupId>
    <artifactId>ems-legacy</artifactId>
    <version>1.0.0</version>
    <packaging>war</packaging>
    <name>Employee Management System (Legacy)</name>
    <description>
        Legacy Java 1.8 + Spring Framework 4.3.4 employee management REST API.
        Intentionally uses legacy patterns as a migration test target.
    </description>

    <properties>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <java.version>1.8</java.version>
        <maven.compiler.source>1.8</maven.compiler.source>
        <maven.compiler.target>1.8</maven.compiler.target>
        <spring.version>4.3.4.RELEASE</spring.version>
        <spring-security.version>4.2.4.RELEASE</spring-security.version>
        <mybatis.version>3.2.2</mybatis.version>
        <mybatis-spring.version>1.2.2</mybatis-spring.version>
        <jackson.version>2.8.11</jackson.version>
        <postgresql.version>42.2.5</postgresql.version>
    </properties>

    <dependencies>
        <!-- Spring Framework -->
        <dependency>
            <groupId>org.springframework</groupId>
            <artifactId>spring-context</artifactId>
            <version>${spring.version}</version>
        </dependency>
        <dependency>
            <groupId>org.springframework</groupId>
            <artifactId>spring-webmvc</artifactId>
            <version>${spring.version}</version>
        </dependency>
        <dependency>
            <groupId>org.springframework</groupId>
            <artifactId>spring-jdbc</artifactId>
            <version>${spring.version}</version>
        </dependency>
        <dependency>
            <groupId>org.springframework</groupId>
            <artifactId>spring-tx</artifactId>
            <version>${spring.version}</version>
        </dependency>

        <!-- Spring Security -->
        <dependency>
            <groupId>org.springframework.security</groupId>
            <artifactId>spring-security-web</artifactId>
            <version>${spring-security.version}</version>
        </dependency>
        <dependency>
            <groupId>org.springframework.security</groupId>
            <artifactId>spring-security-config</artifactId>
            <version>${spring-security.version}</version>
        </dependency>

        <!-- MyBatis -->
        <dependency>
            <groupId>org.mybatis</groupId>
            <artifactId>mybatis</artifactId>
            <version>${mybatis.version}</version>
        </dependency>
        <dependency>
            <groupId>org.mybatis</groupId>
            <artifactId>mybatis-spring</artifactId>
            <version>${mybatis-spring.version}</version>
        </dependency>

        <!-- Database -->
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
            <version>${postgresql.version}</version>
        </dependency>
        <dependency>
            <groupId>org.apache.commons</groupId>
            <artifactId>commons-dbcp2</artifactId>
            <version>2.5.0</version>
        </dependency>

        <!-- Jackson JSON -->
        <dependency>
            <groupId>com.fasterxml.jackson.core</groupId>
            <artifactId>jackson-databind</artifactId>
            <version>${jackson.version}</version>
        </dependency>

        <!-- Servlet API (provided by Tomcat) -->
        <dependency>
            <groupId>javax.servlet</groupId>
            <artifactId>javax.servlet-api</artifactId>
            <version>3.1.0</version>
            <scope>provided</scope>
        </dependency>

        <!-- Logging -->
        <dependency>
            <groupId>org.slf4j</groupId>
            <artifactId>slf4j-api</artifactId>
            <version>1.7.25</version>
        </dependency>
        <dependency>
            <groupId>ch.qos.logback</groupId>
            <artifactId>logback-classic</artifactId>
            <version>1.2.3</version>
        </dependency>

        <!-- Test -->
        <dependency>
            <groupId>junit</groupId>
            <artifactId>junit</artifactId>
            <version>4.12</version>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.mockito</groupId>
            <artifactId>mockito-core</artifactId>
            <version>1.10.19</version>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.springframework</groupId>
            <artifactId>spring-test</artifactId>
            <version>${spring.version}</version>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>com.h2database</groupId>
            <artifactId>h2</artifactId>
            <version>1.4.197</version>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.8.1</version>
                <configuration>
                    <source>1.8</source>
                    <target>1.8</target>
                </configuration>
            </plugin>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-war-plugin</artifactId>
                <version>3.2.3</version>
            </plugin>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-surefire-plugin</artifactId>
                <version>2.22.2</version>
            </plugin>
        </plugins>
    </build>
</project>
POMXML
fi

# Create the source tree skeleton
mkdir -p src/main/java/com/example/ems/{controller,service,dao,mapper,model,security,util}
mkdir -p src/main/resources/mapper
mkdir -p src/main/resources/sql
mkdir -p src/main/webapp/WEB-INF
mkdir -p src/test/java/com/example/ems/{service,controller,dao}

# Run init.sh to detect project type (java-maven)
bash init.sh

git add -A
git commit -m "setup: maven project skeleton with specs for legacy EMS codebase"

echo ""
echo "=== Starting Harness ==="
echo "  Monitor in another terminal: bash scripts/monitor.sh"
echo ""
echo "  The harness will autonomously build a ~3000 line legacy Java codebase"
echo "  with intentional design flaws (circular deps, XML config, field injection,"
echo "  mixed JDBC/MyBatis, java.util.Date, static state, hardcoded config)."
echo ""
echo "  This codebase is then used as the ASIS input for REODE's migration pipeline."
echo ""

# ─── Run harness with reduced iterations ─────────────────────
MAX_SOCRATIC=5 \
MAX_PLAN=3 \
MAX_BUILD=30 \
MAX_VERIFY=3 \
MAX_STUCK=3 \
bash loop.sh socratic

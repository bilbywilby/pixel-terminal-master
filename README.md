# pixel-terminal-master

Ez_App & Multi-Platform Ecosystem
2026 Production Specification · Clean Architecture · Async Data Pipelines · Modern Kotlin Android · CLI Automation
Welcome to the Ez_App Engine & Multi-Platform Ecosystem repository. This repository houses a production-grade, multi-module Android Clean Architecture application (SocialFeedApp / Ez_App), an async web intelligence engine (G.O.D. STACK), a monorepo SaaS code generator (EzSaaS Architect), and terminal workflow automation tools (Termux Master CLI / Pixel Terminal Engine).
📐 System Architecture Overview
                          ┌────────────────────────────────────────┐
                          │         Ez_App (SocialFeedApp)         │
                          │   Android (AGP 9.1 / Kotlin 2.3.20)   │
                          └───────────────────┬────────────────────┘
                                              │
              ┌───────────────────────────────┼───────────────────────────────┐
              ▼                               ▼                               ▼
   ┌────────────────────┐          ┌────────────────────┐          ┌────────────────────┐
   │    :feature:feed   │          │    :feature:auth   │          │  :feature:profile  │
   └──────────┬─────────┘          └──────────┬─────────┘          └──────────┬─────────┘
              │                               │                               │
              └───────────────────────────────┼───────────────────────────────┘
                                              ▼
                                   ┌────────────────────┐
                                   │     :core:ui       │
                                   └──────────┬─────────┘
                                              ▼
                                   ┌────────────────────┐
                                   │    :core:domain    │
                                   └──────────┬─────────┘
                                              ▼
                                   ┌────────────────────┐
                                   │     :core:data     │
                                   │ (Room + Retrofit)  │
                                   └──────────┬─────────┘
                                              ▼
                                   ┌────────────────────┐
                                   │   :core:testing    │
                                   └────────────────────┘


📦 Project Directory Breakdown
Directory / Module
Purpose
Key Technologies
app/
Application entrypoint, Hilt dependency injection root, Navigation Host
AndroidX Activity Compose, Navigation Compose, Hilt
feature/feed/
Offline-first social feed screen with pull-to-refresh and background sync
Jetpack Compose, ViewModel, StateFlow
feature/auth/
Authentication flows and anonymous session management
Jetpack Compose, Material3
feature/profile/
User profile, settings, and account data deletion operations
Jetpack Compose, Lifecycle KTX
core/ui/
Reusable UI components, typography, dynamic palette themes
Material3, Coil 3.0.0, Compose BOM 2026.03.00
core/domain/
Pure Kotlin business logic, domain entities, use cases, repository contracts
Kotlin Coroutines, Flow, kotlinx.serialization
core/data/
Data layer implementing Network-Bound Resource, Room caching, Retrofit client
Room 2.8.4, Retrofit 3.0.0, KSP, WorkManager
core/testing/
Shared test fixtures, mock factories, unit & UI test utilities
MockK, Turbine, Coroutines Test, Kover
tools/god_stack/
Concurrency-bounded async intelligence crawler & Prometheus pipeline
Python 3.11+, selectolax, courlan, Curses TUI
tools/termux_master/
POSIX shell execution engine, SQLite state engine, automated git deployment
Bash, SQLite3, state.py, install.sh

🛠️ Tech Stack & Versioning (2026 Standards)
Android Gradle Plugin (AGP): 9.1.0
Kotlin: 2.3.20
Gradle Wrapper: 9.4.1
Compose BOM: androidx.compose:compose-bom:2026.03.00
Dependency Injection: Hilt 2.59.2
Database & ORM: Room 2.8.4 with KSP (2.0.0-1.0.21)
Networking: Retrofit 3.0.0 + OkHttp 4.12.0
Image Loading: Coil Compose 3.0.0
Code Coverage: Kotlin Kover 0.8.1
Target / Compile SDK: 35 | minSdk: 24
⚡ Quick Start: CLI Command-Line Workflow
1. Build and Run Android App (Ez_App)
# Ensure execution permissions on wrapper
chmod +x gradlew

# Run clean build & assemble debug APK
./gradlew clean assembleDebug

# Deploy APK via ADB
adb install -r app/build/outputs/apk/debug/app-debug.apk

# Launch Main Activity directly from CLI
adb shell am start -n com.example.socialfeedapp/com.example.socialfeedapp.MainActivity


2. Run Test Suite & Static Analysis
# Run unit tests and generate Kover code coverage reports
./gradlew koverMergedReport --continue

# Execute strict multi-module Android Lint checks
./gradlew lint --continue

# Run specific module unit tests
./gradlew :feature:feed:testDebugUnitTest


3. Run Web Intelligence Pipeline (G.O.D. STACK)
# Start background pipeline worker
python main.py daemon

# Execute single target batch run
python main.py batch --input config/target_urls.json

# Launch Prometheus & Grafana telemetry
docker-compose up -d


4. Install & Run Termux Master Engine
# Preview installation changes
./install.sh --dry-run

# Run idempotent install to custom prefix
./install.sh --prefix ~/.termux_master

# Execute workflow DAG
master run url_sanitizer_prod


🔄 Offline-First Pattern (Network-Bound Resource)
The data architecture in :core:data enforces a single source of truth using local SQLite/Room caching backed by remote API polling:
fun <ResultType, RequestType> networkBoundResource(
    query: () -> Flow<ResultType>,
    fetch: suspend () -> RequestType,
    saveFetchResult: suspend (RequestType) -> Unit,
    shouldFetch: (ResultType) -> Boolean = { true }
): Flow<Resource<ResultType>> = flow {
    val data = query().first()
    emit(Resource.Loading(data))

    if (shouldFetch(data)) {
        try {
            saveFetchResult(fetch())
            query().map { Resource.Success(it) }.collect { emit(it) }
        } catch (e: Exception) {
            query().map { Resource.Error(e, it) }.collect { emit(it) }
        }
    } else {
        query().map { Resource.Success(it) }.collect { emit(it) }
    }
}


🤖 CI/CD Automation Matrix (.github/workflows/ci.yml)
The GitHub Actions workflow enforces strict quality gates on every push or pull request to main or develop:
name: CI - Build, Test, Lint & Coverage

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  quality:
    name: Unit Tests + Lint + Kover Coverage
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'zulu'

      - name: Cache Gradle Caches
        uses: actions/cache@v4
        with:
          path: |
            ~/.gradle/caches
            ~/.gradle/wrapper
          key: ${{ runner.os }}-gradle-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties') }}

      - name: Grant Execute Permission for Gradlew
        run: chmod +x gradlew

      - name: Run Unit Tests & Kover Report
        run: ./gradlew koverMergedReport --continue

      - name: Run Multi-Module Android Lint
        run: ./gradlew lint --continue

      - name: Upload Test & Coverage Artifacts
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: quality-reports
          path: |
            **/build/reports/tests/**
            **/build/reports/kover/**
            **/build/reports/lint-results-*.html

  build:
    name: Build Debug APK
    runs-on: ubuntu-latest
    needs: quality

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'zulu'

      - name: Make Gradlew Executable
        run: chmod +x gradlew

      - name: Assemble Debug APK
        run: ./gradlew assembleDebug

      - name: Upload Debug APK Artifact
        uses: actions/upload-artifact@v4
        with:
          name: SocialFeedApp-debug-apk
          path: app/build/outputs/apk/debug/app-debug.apk


📄 License & Governance
Distributed under the MIT License. See LICENSE for details. Built and maintained according to 2026 Android Architecture and POSIX Tooling Specifications.

# Local entry points for the CI gates. `make check` runs every Linux CI gate.
# On a fresh Linux machine, run `make setup` first.

KLAVIYO_TOOLS_DIR ?= $(HOME)/.cache/klaviyo-flutter-sdk-tools

ifneq ($(wildcard $(KLAVIYO_TOOLS_DIR)/env.sh),)
export PATH := $(KLAVIYO_TOOLS_DIR)/bin:$(KLAVIYO_TOOLS_DIR)/flutter/bin:$(KLAVIYO_TOOLS_DIR)/jdk/bin:$(PATH)
ifneq ($(wildcard $(KLAVIYO_TOOLS_DIR)/jdk),)
export JAVA_HOME := $(KLAVIYO_TOOLS_DIR)/jdk
endif
ifneq ($(wildcard $(KLAVIYO_TOOLS_DIR)/android-sdk),)
export ANDROID_HOME := $(KLAVIYO_TOOLS_DIR)/android-sdk
endif
endif

EXAMPLE_ANDROID := example/android

.DEFAULT_GOAL := help

.PHONY: help
help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "} {printf "  %-16s %s\n", $$1, $$2}'

.PHONY: setup
setup: ## Install Flutter, JDK 17, Android SDK, ktlint and SwiftLint (Linux x86_64)
	KLAVIYO_TOOLS_DIR="$(KLAVIYO_TOOLS_DIR)" scripts/setup-linux.sh

.PHONY: deps
deps: ## flutter pub get for the plugin and example app
	flutter pub get
	cd example && flutter pub get

.PHONY: format
format: ## Format Dart and Kotlin sources in place
	dart format .
	cd android && ktlint -F "**/*.kt"

.PHONY: format-check
format-check: deps ## Fail if Dart sources are not formatted (CI: lint)
	dart format --set-exit-if-changed .

.PHONY: analyze
analyze: deps ## flutter analyze (CI: lint)
	flutter analyze --no-fatal-infos

.PHONY: ktlint
ktlint: ## Kotlin lint (CI: lint)
	cd android && ktlint --reporter=plain "**/*.kt"

.PHONY: swiftlint
swiftlint: ## Swift lint (CI: lint)
	cd ios && swiftlint lint --strict

.PHONY: lint
lint: format-check analyze ktlint swiftlint ## Every check in the lint CI job

.PHONY: test
test: deps ## Dart unit tests with coverage (CI: test)
	flutter test --coverage

.PHONY: test-example
test-example: deps ## Example app widget tests
	cd example && flutter test

$(EXAMPLE_ANDROID)/gradlew: | deps
	cd example && flutter build apk --config-only

.PHONY: test-android
test-android: $(EXAMPLE_ANDROID)/gradlew ## Kotlin JVM unit tests for the Android plugin (CI: test-android)
	cd $(EXAMPLE_ANDROID) && ./gradlew :klaviyo_flutter_sdk:testDebugUnitTest --console=plain

.PHONY: build-android
build-android: deps ## Debug APK of the example app (CI: build-android; needs example/android/app/google-services.json)
	cd example && flutter build apk --debug

.PHONY: check
check: lint test test-android ## Every Linux CI gate except the APK build

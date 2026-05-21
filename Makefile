# BabyGuard — dev commands.
#
# Run `make` or `make help` to list available targets.
# Every target that touches Gradle requires JAVA_HOME / ANDROID_HOME exported
# (already in ~/.zshrc on this machine).

FIREBASE_CONFIG := firebase-config.json
APK_DEBUG       := build/app/outputs/flutter-apk/app-debug.apk
APK_RELEASE     := build/app/outputs/flutter-apk/app-release.apk

# Default project ID; override with `make deploy-fn PROJECT=other`.
PROJECT ?= babyguard-4cd1e

.DEFAULT_GOAL := help

##@ Help

.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make \033[36m<target>\033[0m\n"} \
	/^[a-zA-Z0-9_-]+:.*##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 } \
	/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)

##@ Build

.PHONY: deps
deps: ## Fetch Flutter packages (after pubspec changes)
	flutter pub get

.PHONY: analyze
analyze: ## Run static analyzer (info-level lints ok, zero errors expected)
	flutter analyze --no-pub

.PHONY: test
test: ## Run smoke tests
	flutter test

.PHONY: build
build: ## Build debug APK
	flutter build apk --debug --dart-define-from-file=$(FIREBASE_CONFIG)

.PHONY: release
release: ## Build release APK
	flutter build apk --release --dart-define-from-file=$(FIREBASE_CONFIG)

.PHONY: aab
aab: ## Build signed release App Bundle (.aab) for Play Console upload
	flutter build appbundle --release --dart-define-from-file=$(FIREBASE_CONFIG)
	@echo "→ build/app/outputs/bundle/release/app-release.aab"

.PHONY: clean
clean: ## Wipe build artifacts
	flutter clean
	rm -rf build/

##@ Devices

.PHONY: devices
devices: ## List attached devices
	@adb devices

.PHONY: install
install: ## Install the debug APK on every attached device
	@for d in $$(adb devices | awk 'NR>1 && $$2=="device"{print $$1}'); do \
	  echo "→ $$d"; \
	  adb -s "$$d" install -r $(APK_DEBUG); \
	done

.PHONY: ship
ship: build install ## Build debug APK and install on every attached device

.PHONY: ship-release
ship-release: release ## Build release APK (R8-shrunk, signed) and install on every attached device
	@for d in $$(adb devices | awk 'NR>1 && $$2=="device"{print $$1}'); do \
	  echo "→ $$d"; \
	  adb -s "$$d" install -r $(APK_RELEASE); \
	done

.PHONY: run
run: ## Run the app on the first attached device (hot-reload enabled)
	flutter run --dart-define-from-file=$(FIREBASE_CONFIG)

.PHONY: logs
logs: ## Tail flutter + errors from the first attached device
	@dev=$$(adb devices | awk 'NR==2{print $$1}'); \
	echo "logcat on $$dev"; \
	adb -s "$$dev" logcat -v time flutter:V '*:E'

##@ Firebase / backend

.PHONY: fb-login
fb-login: ## firebase login (interactive)
	firebase login

.PHONY: fb-use
fb-use: ## Set Firebase project (override with PROJECT=...)
	firebase use $(PROJECT)

.PHONY: fb-fn-deps
fb-fn-deps: ## Install Cloud Function npm deps
	cd functions && npm install

.PHONY: deploy-fn
deploy-fn: ## Deploy Firestore rules + Cloud Functions
	firebase deploy --only firestore:rules,functions

.PHONY: deploy-rules
deploy-rules: ## Deploy Firestore rules only
	firebase deploy --only firestore:rules

.PHONY: logs-fn
logs-fn: ## Tail Cloud Function logs
	firebase functions:log --only onAlertEvent

##@ Setup (one-time)

.PHONY: sdk-licenses
sdk-licenses: ## Accept all Android SDK licenses
	yes | sdkmanager --licenses

.PHONY: sdk-platforms
sdk-platforms: ## Install Android SDK platforms + build-tools Flutter expects
	sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0"

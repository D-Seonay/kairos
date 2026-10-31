DEST = platform=iOS Simulator,name=iPhone 17
.PHONY: test test-packages test-app lint
test: lint test-packages test-app
test-packages:
	swift test --package-path Packages/PulseDomain
	swift test --package-path Packages/PulseRecoveryEngine
test-app:
	xcodebuild test -scheme Pulse -destination '$(DEST)' -quiet
lint:
	swiftlint lint --strict

DEST = platform=iOS Simulator,name=iPhone 17
.PHONY: test test-packages test-app lint
test: lint test-packages test-app
test-packages:
	swift test --package-path Packages/PulseDomain
	swift test --package-path Packages/PulseRecoveryEngine
	swift test --package-path Packages/PulseContent
	swift test --package-path Packages/PulsePersistence
test-app:
	xcodebuild build-for-testing -scheme Pulse -destination '$(DEST)' -quiet
	xcodebuild test-without-building -scheme Pulse -destination '$(DEST)' -quiet
lint:
	swiftlint lint --strict

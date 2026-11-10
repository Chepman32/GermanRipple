IOS_DESTINATION ?= platform=iOS Simulator,name=iPhone 16e,OS=26.1

.PHONY: project content test-authoring test-core test-ios test-rules verify release-check
project:
	xcodegen generate

content:
	python3 tools/author_scenarios.py --check
	python3 tools/author_content.py --check
	python3 tools/ripplec.py --check

test-authoring: content
	python3 -m unittest discover -s tools/tests -v

test-core: content
	swift test --package-path Packages/RippleCore --enable-code-coverage

test-ios:
	xcodebuild -project Ripple.xcodeproj -scheme Ripple -destination '$(IOS_DESTINATION)' -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test

test-rules:
	cd firebase && npm run test:rules

verify: test-authoring test-core test-ios test-rules

release-check:
	python3 tools/release_check.py

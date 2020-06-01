SWIFT_BUILD_FLAGS=--configuration release

.PHONY: all build flynn clean xcode

all: build

build:
	swift build $(SWIFT_BUILD_FLAGS)

flynn: build
	cp ./.build/release/flynnlint ../flynn/meta/flynnlint

clean:
	rm -rf .build

xcode:
	swift package generate-xcodeproj
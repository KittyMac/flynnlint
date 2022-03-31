SWIFT_BUILD_FLAGS=--configuration release
PROJECTNAME := $(shell basename `pwd`)

.PHONY: all build flynn clean xcode

all: build

build:
	swift build $(SWIFT_BUILD_FLAGS) --triple arm64-apple-macosx
	swift build $(SWIFT_BUILD_FLAGS) --triple x86_64-apple-macosx
	lipo -create -output .build/release/${PROJECTNAME} .build/arm64-apple-macosx/release/${PROJECTNAME} .build/x86_64-apple-macosx/release/${PROJECTNAME}

flynn: build
	cp ./.build/release/flynnlint ../flynn/meta/flynnlint

clean:
	rm -rf .build

test:
	swift test -v

update:
	swift package update

xcode:
	swift package generate-xcodeproj
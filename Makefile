PROJ = SYM.xcodeproj/project.pbxproj
MARKETING_VERSION = $(shell cat $(PROJ)|  sed -n 's/.*MARKETING_VERSION = \(.*\);/\1/p' | head -n 1)
CURRENT_PROJECT_VERSION = $(shell cat $(PROJ)|  sed -n 's/.*CURRENT_PROJECT_VERSION = \(.*\);/\1/p' | head -n 1)
BUILD_VER = $(MARKETING_VERSION)_$(CURRENT_PROJECT_VERSION)
NAME = SYM_$(BUILD_VER)
ARCHIVE_PATH = build/$(NAME).xcarchive
EXPORT_PATH = build/$(NAME)
APP_PATH = $(EXPORT_PATH)/SYM.app
ZIP_PATH = $(APP_PATH).zip
DMG_DIR = $(EXPORT_PATH)/SYM
DIST_DIR = dist
DMG_PATH = $(DIST_DIR)/$(NAME).dmg
TOOL_NAME = icp
TOOL_ARCHIVE_PATH = build/$(TOOL_NAME).xcarchive

all: archive

clean:
	xcodebuild -project SYM.xcodeproj -config Release -scheme SYM -archivePath $(ARCHIVE_PATH) clean
	xcodebuild -project SYM.xcodeproj -config Release -scheme icp -archivePath $(TOOL_ARCHIVE_PATH) clean
	if [ -d ${ARCHIVE_PATH} ]; then rm -r $(ARCHIVE_PATH); fi;
	if [ -d ${EXPORT_PATH} ]; then rm -r $(EXPORT_PATH); fi;
	if [ -d ${DMG_DIR} ]; then rm -r $(DMG_DIR); fi;
	if [ -d ${TOOL_ARCHIVE_PATH} ]; then rm -r $(TOOL_ARCHIVE_PATH); fi;

next:
	agvtool next-version

archive:

ifdef script
	@echo 'make with buildin download script $(script)'
	xcodebuild -project SYM.xcodeproj -config Release -scheme SYM -archivePath $(ARCHIVE_PATH) archive BUILDIN_DOWNLOAD_SCRIPT_PATH=$(script)
else
	xcodebuild -project SYM.xcodeproj -config Release -scheme SYM -archivePath $(ARCHIVE_PATH) archive
endif
	xcodebuild -exportArchive -archivePath $(ARCHIVE_PATH) -exportOptionsPlist exportOptions.plist -exportPath $(EXPORT_PATH)

notarize:
	/usr/bin/ditto -c -k --keepParent $(APP_PATH) $(ZIP_PATH)
	xcrun notarytool submit $(ZIP_PATH) --keychain-profile "Notarization" --wait
	xcrun stapler staple $(APP_PATH)
	spctl --assess -vv --type install $(APP_PATH)

dmg:
	if [ -f ${DMG_PATH} ]; then rm $(DMG_PATH); fi;
	if [ -d ${DMG_DIR} ]; then rm -r $(DMG_DIR); fi;
	mkdir -p $(DMG_DIR) $(DIST_DIR)
	cp -r $(APP_PATH) $(DMG_DIR)
	ln -s /Applications $(DMG_DIR)/Applications
	hdiutil create -fs HFS+ -srcfolder $(DMG_DIR) -format UDZO -volname SYM $(DMG_PATH)

install:
	cp -r $(APP_PATH) /Applications

tool:
	xcodebuild -project SYM.xcodeproj -config Release -scheme icp -archivePath $(TOOL_ARCHIVE_PATH) archive
	cp $(TOOL_ARCHIVE_PATH)/Products/usr/local/bin/icp build/

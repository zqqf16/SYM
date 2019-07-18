BUILD_VER = $(shell /usr/libexec/PlistBuddy -c Print:CFBundleShortVersionString -c Print:CFBundleVersion SYM/Info.plist  | xargs |  sed 's/ /_/g')
NAME = SYM_$(BUILD_VER)
ARCHIVE_PATH = build/$(NAME).xcarchive
EXPORT_PATH = build/$(NAME)
APP_PATH = $(EXPORT_PATH)/SYM.app
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

archive:
	xcodebuild -project SYM.xcodeproj -config Release -scheme SYM -archivePath $(ARCHIVE_PATH) archive
	xcodebuild -exportArchive -archivePath $(ARCHIVE_PATH) -exportOptionsPlist exportOptions.plist -exportPath $(EXPORT_PATH)

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

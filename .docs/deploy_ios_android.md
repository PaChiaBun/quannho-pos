# 📱 Quán Nhỏ POS — Hướng dẫn Đưa App lên iOS & Android

> Tài liệu tham khảo nội bộ — LPM Digital
> Cập nhật: 2026-05-20

---

## MỤC LỤC

1. [Thông tin Project](#1-thông-tin-project)
2. [Android — Toàn bộ quy trình](#2-android--toàn-bộ-quy-trình)
3. [iOS — Toàn bộ quy trình](#3-ios--toàn-bộ-quy-trình)
4. [Quy trình cập nhật (Update)](#4-quy-trình-cập-nhật-update)
5. [Checklist nhanh khi release](#5-checklist-nhanh-khi-release)
6. [Lỗi thường gặp & cách sửa](#6-lỗi-thường-gặp--cách-sửa)

---

## 1. Thông tin Project

| Key | Value |
|-----|-------|
| **App Name** | Quán Nhỏ POS |
| **Flutter SDK** | ^3.11.5 |
| **Android Package** | `vn.lpm.quannho_pos` |
| **iOS Bundle ID** | `vn.lpm.quannhoPos` |
| **Version hiện tại** | `1.0.0+1` (trong `pubspec.yaml`) |
| **Min Android SDK** | Theo Flutter default (API 21 / Android 5.0) |
| **Min iOS** | 13.0 |
| **Thiết bị target chính** | Sunmi P2 SE (Android), iPad, iPhone |
| **Signing Android** | Đã cấu hình trong `android/app/build.gradle.kts` (đọc từ `key.properties`) |
| **Signing iOS** | Xcode Automatic Signing (Team: Apple Developer Account) |
| **Company** | LPM Digital |

### Cấu trúc file quan trọng

```
quan_nho/
├── pubspec.yaml                          ← VERSION ở đây (line 5)
├── android/
│   ├── app/build.gradle.kts             ← Android build config + signing
│   ├── key.properties                   ← ❌ KHÔNG commit (chứa mật khẩu keystore)
│   └── key.properties.example           ← Template hướng dẫn
├── ios/
│   ├── Runner.xcworkspace/              ← MỞ FILE NÀY bằng Xcode (không phải .xcodeproj)
│   ├── Runner/Info.plist                ← iOS app config (permissions, etc.)
│   └── Runner.xcodeproj/project.pbxproj ← Xcode project config
├── build/                                ← Output sau khi build
│   ├── app/outputs/flutter-apk/         ← APK Android
│   ├── app/outputs/bundle/release/      ← AAB Android (cho Google Play)
│   ├── ios/ipa/                         ← IPA iOS
│   └── macos/Build/Products/Release/    ← macOS app
└── supabase/migrations/                  ← SQL scripts
```

---

## 2. Android — Toàn bộ quy trình

### 2.1. Tạo Keystore (CHỈ LÀM 1 LẦN)

Keystore là "chìa khóa" để ký app. Google Play dùng chữ ký này để xác minh bản cập nhật là từ bạn.

```bash
# Chạy trên Terminal (Mac)
keytool -genkey -v \
  -keystore ~/quannho-release-key.jks \
  -keyalg RSA -keysize 2048 \
  -validity 10000 \
  -alias quannho \
  -dname "CN=LPM Digital, O=LPM Digital, L=Ho Chi Minh, C=VN"
```

Khi được hỏi:
- **Keystore password**: Đặt mật khẩu mạnh (ghi nhớ lại!)
- **Key password**: Có thể dùng cùng mật khẩu

⚠️ **QUAN TRỌNG**: Backup file `quannho-release-key.jks` lên Google Drive + USB. 
MẤT FILE NÀY = KHÔNG BAO GIỜ UPDATE ĐƯỢC APP TRÊN GOOGLE PLAY.

### 2.2. Cấu hình Signing

Tạo file `android/key.properties` (copy từ `key.properties.example`):

```properties
storePassword=<mật khẩu bạn vừa đặt>
keyPassword=<mật khẩu key>
keyAlias=quannho
storeFile=/Users/banhbao/quannho-release-key.jks
```

File `build.gradle.kts` đã được cấu hình sẵn để đọc từ `key.properties`. 
Nếu file không tồn tại → tự động dùng debug key (chạy test OK, nhưng không submit được Google Play).

### 2.3. Build APK (phân phối trực tiếp)

```bash
cd /Users/banhbao/Quan\ Nho/quan_nho

# Build APK release
flutter build apk --release --no-tree-shake-icons

# Output: build/app/outputs/flutter-apk/app-release.apk
# Size: ~89MB
```

Flag `--no-tree-shake-icons` cần vì app dùng dynamic IconData trong `ban_screen.dart`.

**Phân phối APK:**
- Gửi qua Zalo / Google Drive / Website
- Người nhận tải → bật "Cho phép cài từ nguồn không xác định" → Cài đặt
- Sunmi P2 SE: Copy APK vào máy qua USB hoặc adb install

### 2.4. Build AAB (cho Google Play Store)

```bash
flutter build appbundle --release --no-tree-shake-icons

# Output: build/app/outputs/bundle/release/app-release.aab
```

AAB là format Google Play yêu cầu. Google sẽ tự tạo APK tối ưu cho từng thiết bị.

### 2.5. Đăng ký Google Play Console

1. Truy cập https://play.google.com/console
2. Đăng nhập bằng tài khoản Google
3. Thanh toán **$25** (một lần, vĩnh viễn)
4. Chờ xác minh (thường 24-48h)

### 2.6. Tạo App trên Google Play Console

1. **Console → All apps → Create app**
2. Điền thông tin:
   - App name: `Quán Nhỏ POS`
   - Default language: Tiếng Việt
   - App or Game: App
   - Free or Paid: Free
3. **Store listing** (trang giới thiệu):
   - Short description (80 ký tự): `Quản lý quán ăn đơn giản — POS, kho, nhân viên, tài chính`
   - Full description (4000 ký tự): Mô tả chi tiết tính năng
   - Screenshots: Cần ít nhất 2 ảnh (kích thước 1080x1920 hoặc tương tự)
   - App icon: 512x512 PNG (đã có `assets/branding/app_icon.png`)
   - Feature graphic: 1024x500 PNG (banner giới thiệu)
4. **Content rating**: Trả lời bảng câu hỏi (app POS → mọi lứa tuổi)
5. **Target audience**: 18+ (vì là business app)
6. **Privacy policy**: Cần URL chính sách bảo mật (có thể dùng trang trên quannho.lpm.vn)

### 2.7. Upload & Submit

1. **Console → Release → Production → Create new release**
2. Hoặc bắt đầu với **Internal testing** (test nội bộ trước):
   - Internal testing: Tối đa 100 người, không cần review
   - Closed testing: Nhóm lớn hơn, cần review nhẹ
   - Open testing: Ai cũng join được
   - Production: Công khai trên Store
3. Upload file `.aab`
4. Viết **Release notes** (ví dụ: "Phiên bản đầu tiên")
5. **Review and rollout** → Submit
6. Chờ Google review: **Lần đầu 3-7 ngày**, sau đó thường 1-3 ngày

### 2.8. Cài APK lên Sunmi P2 SE

```bash
# Cách 1: ADB (cần bật Developer Options + USB Debugging trên Sunmi)
adb install build/app/outputs/flutter-apk/app-release.apk

# Cách 2: Copy file qua USB
# Cắm USB → Copy APK vào bộ nhớ trong → Mở File Manager trên Sunmi → Bấm cài

# Cách 3: Tải từ web
# Upload APK lên Drive/Website → Mở Chrome trên Sunmi → Tải → Cài
```

---

## 3. iOS — Toàn bộ quy trình

### 3.1. Yêu cầu

| Yêu cầu | Chi tiết |
|----------|----------|
| **Mac** | Bắt buộc — không thể build iOS trên Windows/Linux |
| **Xcode** | Phiên bản mới nhất (hiện có trên máy ✅) |
| **Apple Developer Account** | $99/năm — Organization (LPM Digital) |
| **D-U-N-S Number** | Mã doanh nghiệp quốc tế — cần cho Organization account |
| **iPhone/iPad** | Để test (hiện có ✅) |

### 3.2. Đăng ký Apple Developer Account

**Bước 1: Kiểm tra/Tạo D-U-N-S Number**

D-U-N-S là mã doanh nghiệp quốc tế do Dun & Bradstreet cấp. Apple yêu cầu mã này cho Organization account.

1. Kiểm tra tại: https://developer.apple.com/enroll/duns-lookup/
2. Nhập tên công ty: `LPM Digital` + địa chỉ
3. Nếu chưa có → Apple sẽ gửi yêu cầu tạo mới cho D&B
4. Chờ **5-10 ngày làm việc** để nhận D-U-N-S Number
5. D-U-N-S Number là dãy 9 số, ví dụ: `123456789`

**Bước 2: Đăng ký Apple Developer Program**

1. Truy cập https://developer.apple.com/programs/enroll/
2. Đăng nhập Apple ID (hoặc tạo mới)
3. Chọn **Organization**
4. Điền thông tin:
   - Legal Entity Name: `LPM Digital` (phải khớp D-U-N-S)
   - D-U-N-S Number: (số 9 chữ số)
   - Website: `lpm.vn` hoặc `quannho.lpm.vn`
   - Headquarters Phone: Số điện thoại công ty
   - Organization Type: Company / Organization
5. **Authority Verification**: Apple sẽ gọi điện xác minh (gọi người đại diện pháp lý)
6. Thanh toán **$99/năm**
7. Chờ duyệt: **5-14 ngày**

**Lưu ý**: Trong lúc chờ Organization, bạn CÓ THỂ đăng ký Individual account ($99/năm) để test trước. Sau đó chuyển sang Organization.

### 3.3. Cấu hình Xcode Signing

1. Mở Terminal:
   ```bash
   cd /Users/banhbao/Quan\ Nho/quan_nho
   open ios/Runner.xcworkspace
   ```
   ⚠️ **Mở `.xcworkspace`** chứ KHÔNG PHẢI `.xcodeproj`

2. Trong Xcode:
   - Chọn **Runner** ở sidebar trái (icon project, KHÔNG phải folder)
   - Chọn target **Runner** (không phải RunnerTests)
   - Tab **Signing & Capabilities**
   - Tick ✅ **Automatically manage signing**
   - **Team**: Chọn Apple Developer Account của bạn (LPM Digital)
   - **Bundle Identifier**: `vn.lpm.quannhoPos` (đã đặt sẵn)
   - Xcode sẽ tự tạo Certificate + Provisioning Profile

3. Kiểm tra **Info.plist** (`ios/Runner/Info.plist`):
   - Đảm bảo các permission descriptions đã có:
     - Camera: `NSCameraUsageDescription`
     - Photo Library: `NSPhotoLibraryUsageDescription`
     - Location: `NSLocationWhenInUseUsageDescription`
   - Nếu thiếu → Apple sẽ reject

### 3.4. Build iOS

```bash
cd /Users/banhbao/Quan\ Nho/quan_nho

# Build IPA cho distribution
flutter build ipa --release --no-tree-shake-icons

# Output: build/ios/ipa/quannho_pos.ipa
```

**Nếu gặp lỗi signing:**
```bash
# Xoá cache Xcode
cd ios && rm -rf Pods Podfile.lock && pod install && cd ..

# Build lại
flutter clean
flutter pub get
flutter build ipa --release --no-tree-shake-icons
```

### 3.5. Upload lên App Store Connect

**Cách 1: Xcode (đơn giản nhất)**

```bash
# Mở Xcode workspace
open ios/Runner.xcworkspace
```

1. Xcode → **Product → Archive** (chờ vài phút)
2. Window → **Organizer** → Chọn archive vừa tạo
3. **Distribute App** → **App Store Connect** → **Upload**
4. Chọn options (thường để mặc định) → **Upload**
5. Chờ upload + processing (5-30 phút)

**Cách 2: Transporter (app riêng)**

1. Tải **Transporter** từ Mac App Store (miễn phí, của Apple)
2. Mở → kéo file `.ipa` vào → **Deliver**

**Cách 3: Command line**

```bash
xcrun altool --upload-app \
  --file build/ios/ipa/quannho_pos.ipa \
  --type ios \
  --apiKey <YOUR_API_KEY> \
  --apiIssuer <YOUR_ISSUER_ID>
```

API Key tạo tại: https://appstoreconnect.apple.com/access/api

### 3.6. Cấu hình trên App Store Connect

1. Truy cập https://appstoreconnect.apple.com
2. **My Apps → (+) New App**:
   - Platform: iOS
   - Name: `Quán Nhỏ POS`
   - Primary Language: Vietnamese
   - Bundle ID: `vn.lpm.quannhoPos` (chọn từ dropdown)
   - SKU: `quannho-pos` (mã nội bộ, không hiển thị)
3. **App Information**:
   - Category: Business
   - Content Rights: Không chứa nội dung bên thứ 3
4. **Pricing**: Free
5. **App Privacy** (Privacy Policy URL cần có):
   - URL: `https://quannho.lpm.vn/privacy`
6. **Screenshots** (BẮT BUỘC):

   | Thiết bị | Kích thước | Số lượng |
   |----------|-----------|----------|
   | iPhone 6.7" (15 Pro Max) | 1290 x 2796 | Tối thiểu 3 |
   | iPhone 6.5" (11 Pro Max) | 1242 x 2688 | Tối thiểu 3 |
   | iPad Pro 12.9" | 2048 x 2732 | Tối thiểu 3 (nếu hỗ trợ iPad) |

7. **Build**: Chọn build vừa upload (xuất hiện sau ~30 phút processing)
8. **Submit for Review**

### 3.7. Apple Review Process

| Giai đoạn | Thời gian | Mô tả |
|-----------|-----------|-------|
| Waiting for Review | 0-24h | Trong hàng chờ |
| In Review | 1-24h | Reviewer đang test app |
| Approved | — | App lên Store ngay (hoặc chờ ngày bạn chọn) |
| Rejected | — | Xem lý do, sửa, submit lại |

**Lần đầu**: Thường 2-5 ngày
**Các lần sau**: Thường 24-48h

**Lý do hay bị reject:**
- Thiếu Privacy Policy
- Thiếu mô tả permission (camera, location...)
- App crash khi reviewer test
- UI/UX quá đơn giản (Apple thích app polish)
- Thiếu tính năng (app chỉ là web wrapper)
- Login không hoạt động (phải cung cấp demo account)

### 3.8. TestFlight (Test trước khi lên Store)

TestFlight cho phép gửi bản test cho người dùng TRƯỚC KHI public lên App Store.

1. Upload IPA lên App Store Connect (giống bước 3.5)
2. App Store Connect → **TestFlight** tab
3. **Internal Testing**:
   - Thêm tester bằng Apple ID
   - Tối đa 100 người
   - Không cần Apple review
   - Build available ngay sau processing
4. **External Testing**:
   - Tối đa 10,000 người
   - Cần Apple review (nhanh hơn App Review, thường vài giờ)
   - Tester nhận link qua email
5. Tester:
   - Tải app **TestFlight** từ App Store
   - Mở link mời → Accept → Cài bản test
   - Có thể gửi feedback/crash report trực tiếp

---

## 4. Quy trình Cập nhật (Update)

### Bước 1: Tăng Version

Mở `pubspec.yaml`, sửa dòng 5:

```yaml
# Cũ:
version: 1.0.0+1

# Mới (ví dụ sửa lỗi nhỏ):
version: 1.0.1+2

# Mới (thêm tính năng):
version: 1.1.0+3
```

**Quy tắc:**
- `Major.Minor.Patch+BuildNumber`
- **Build Number PHẢI LUÔN TĂNG** (1→2→3→4...), không được giảm hay giữ nguyên
- Version Name (1.0.1) có thể tùy ý, nhưng Build Number là bắt buộc tăng
- Cả App Store và Google Play đều kiểm tra Build Number

### Bước 2: Build

```bash
cd /Users/banhbao/Quan\ Nho/quan_nho

# Android APK (phân phối trực tiếp)
flutter build apk --release --no-tree-shake-icons

# Android AAB (Google Play)
flutter build appbundle --release --no-tree-shake-icons

# iOS
flutter build ipa --release --no-tree-shake-icons
```

### Bước 3: Upload

**Android (Google Play):**
1. Google Play Console → App → Release → Production (hoặc testing track)
2. Create new release → Upload AAB mới
3. Viết Release Notes
4. Review and rollout

**iOS (App Store):**
1. Upload IPA qua Xcode/Transporter
2. App Store Connect → chọn build mới
3. Viết "What's New" (mô tả thay đổi)
4. Submit for Review

**Android (APK trực tiếp):**
1. Gửi APK mới qua Zalo/Drive
2. Người dùng tải → Cài đè lên bản cũ (data giữ nguyên)

### Bước 4: Cập nhật Supabase (cho in-app update checker)

```sql
-- Thêm record mới vào bảng app_versions
INSERT INTO app_versions (platform, version_name, build_number, download_url, changelog)
VALUES 
  ('android', '1.0.1', 2, 'https://link-tai-apk', 'Sửa lỗi in bill, cải thiện tốc độ'),
  ('ios', '1.0.1', 2, 'https://apps.apple.com/app/id...', 'Sửa lỗi in bill, cải thiện tốc độ');
```

---

## 5. Checklist nhanh khi Release

```
PRE-BUILD:
□ Tăng version + build number trong pubspec.yaml
□ Test trên emulator/simulator
□ Test trên thiết bị thật (Sunmi P2 SE, iPhone, iPad)
□ Commit code lên Git
□ Tag version: git tag v1.0.1

ANDROID:
□ flutter build apk --release --no-tree-shake-icons
□ flutter build appbundle --release --no-tree-shake-icons  (nếu dùng Google Play)
□ Test APK trên thiết bị thật
□ Upload AAB lên Google Play Console (nếu dùng)
□ Gửi APK qua kênh phân phối

iOS:
□ flutter build ipa --release --no-tree-shake-icons
□ Upload qua Xcode → Archive → Distribute
□ Chọn build trên App Store Connect
□ Submit for Review
□ (Hoặc gửi qua TestFlight trước)

POST-RELEASE:
□ Update bảng app_versions trên Supabase
□ Viết Release Notes
□ Thông báo cho team/người dùng
□ Monitor crash reports
□ Backup keystore (nếu lần đầu)
```

---

## 6. Lỗi thường gặp & Cách sửa

### Android

| Lỗi | Nguyên nhân | Cách sửa |
|-----|-------------|----------|
| `Gradle task assembleRelease failed` | Nhiều lý do | `flutter clean && flutter pub get` rồi build lại |
| `Execution failed for task ':app:compileFlutterBuildRelease'` | Tree shake icons | Thêm `--no-tree-shake-icons` |
| `key.properties not found` | Chưa tạo file | Copy từ `key.properties.example`, điền thông tin |
| `Keystore was tampered with` | Sai mật khẩu keystore | Kiểm tra lại password trong key.properties |
| APK cài không được trên Sunmi | Chưa bật Unknown Sources | Settings → Security → Unknown Sources → ON |
| `minSdkVersion` quá cao | Plugin yêu cầu SDK cao hơn | Kiểm tra `android/app/build.gradle.kts` → `minSdk` |

### iOS

| Lỗi | Nguyên nhân | Cách sửa |
|-----|-------------|----------|
| `No signing certificate` | Chưa setup Team trong Xcode | Xcode → Runner → Signing → chọn Team |
| `Provisioning profile doesn't match` | Bundle ID sai | Kiểm tra Bundle ID = `vn.lpm.quannhoPos` |
| `pod install` thất bại | CocoaPods lỗi | `cd ios && rm -rf Pods Podfile.lock && pod install` |
| `Module 'xxx' not found` | Thiếu pod | `flutter clean && flutter pub get && cd ios && pod install` |
| Archive failed | Scheme chưa đúng | Xcode → Product → Scheme → Runner |
| Apple reject: Privacy | Thiếu permission description | Thêm vào Info.plist |
| Apple reject: Demo account | Cần tài khoản test | Tạo demo account, điền trong Review Notes |

### Chung

| Lỗi | Cách sửa |
|-----|----------|
| Build quá chậm | `flutter clean` trước khi build |
| `flutter build` không tìm thấy SDK | Kiểm tra `flutter doctor` |
| Version không tăng trên Store | Kiểm tra build number phải LỚN HƠN bản trước |
| App crash khi mở | Build ở debug mode kiểm tra lỗi: `flutter run --debug` |

---

## PHỤ LỤC: Lệnh thường dùng

```bash
# Kiểm tra môi trường Flutter
flutter doctor -v

# Xoá cache build (khi gặp lỗi lạ)
flutter clean && flutter pub get

# Build tất cả platforms
flutter build apk --release --no-tree-shake-icons          # Android APK
flutter build appbundle --release --no-tree-shake-icons     # Android AAB
flutter build ipa --release --no-tree-shake-icons           # iOS
flutter build macos --release --no-tree-shake-icons         # macOS
flutter build windows --release --no-tree-shake-icons       # Windows (chỉ trên máy Win)

# Cài APK qua ADB
adb install -r build/app/outputs/flutter-apk/app-release.apk

# Xem danh sách thiết bị kết nối
flutter devices

# Chạy trên thiết bị cụ thể
flutter run -d <device-id>

# Tạo app icon (khi đổi icon)
flutter pub run flutter_launcher_icons

# Tạo splash screen (khi đổi splash)
flutter pub run flutter_native_splash:create

# Mở Xcode workspace (iOS)
open ios/Runner.xcworkspace

# Pod install (khi thêm plugin iOS mới)
cd ios && pod install --repo-update && cd ..

# Git tag version
git tag v1.0.1
git push origin v1.0.1
```

---

## 7. Tiến độ Triển khai (Cập nhật: 2026-05-20)

### ✅ Đã hoàn thành

| # | Việc | Ngày | Ghi chú |
|---|------|------|---------|
| 1 | Supabase: bảng `app_versions` + `bug_reports` | 20/05 | SQL đã chạy |
| 2 | Supabase: bucket `bug-screenshots` + policies | 20/05 | Public, có upload policy |
| 3 | Update Checker Service | 20/05 | Tự check 2s sau khi mở app |
| 4 | Bug Reporter Service + Screen | 20/05 | Chụp ảnh + gửi từ Settings |
| 5 | Android Keystore | 20/05 | `~/quannho-release-key.jks` |
| 6 | Android APK signed | 20/05 | 85MB → `release-builds/QuanNhoPOS-1.0.0.apk` |
| 7 | Android AAB signed | 20/05 | 63MB → `release-builds/QuanNhoPOS-1.0.0.aab` |
| 8 | iOS build (no codesign) | 20/05 | 42MB — chờ Apple Developer Account |
| 9 | macOS build | 20/05 | 72MB → `release-builds/QuanNhoPOS-1.0.0-macOS.zip` |
| 10 | Trang download HTML | 20/05 | `web-download/index.html` |
| 11 | Release script | 20/05 | `release.sh` — 1 lệnh build tất cả |
| 12 | Store listing materials | 20/05 | `.docs/store_listing.md` |
| 13 | Email `lienhe@lpm.vn` | 20/05 | Cloudflare Email Routing → Gmail |
| 14 | D-U-N-S Number request | 20/05 | Đã gửi yêu cầu qua Apple |

### ⏳ Đang chờ

| Việc | Ước tính | Cần làm khi xong |
|------|----------|------------------|
| D-U-N-S Number | 5-14 ngày | → Hoàn tất Apple Developer + Google Play Organization |
| Apple Developer Account | Sau D-U-N-S | → Codesign iOS → TestFlight → App Store |
| Google Play Console | Sau D-U-N-S | → Upload AAB → Internal testing → Production |

### 📋 Việc cần làm tiếp

- [ ] Upload APK lên Google Drive → share cho team test Sunmi P2 SE
- [ ] Tạo trang Privacy Policy: `https://quannho.lpm.vn/privacy`
- [ ] Chụp screenshots cho Store listing (xem specs tại `.docs/store_listing.md`)
- [ ] Cài Flutter trên máy Windows → build EXE
- [ ] Khi có D-U-N-S → hoàn tất Apple Dev + Google Play → upload app

---

## 8. Thông tin Công ty & Tài khoản

### Công ty

| Key | Value |
|-----|-------|
| **Tên pháp lý** | CÔNG TY TNHH KỸ THUẬT SỐ LPM |
| **Tên tiếng Anh** | CONG TY TNHH KY THUAT SO LPM |
| **Tên thương mại** | LPM Digital |
| **MST** | 0316880858 |
| **Địa chỉ** | 26 Đường 33B, Phường Bình Trị Đông B, TP.HCM |
| **Đại diện** | Nguyễn Hữu Long |
| **ĐT** | 0927 55 8888 |
| **Email** | lienhe@lpm.vn (→ forward Gmail) |
| **Website** | lpm.vn / quannho.lpm.vn |

### Tài khoản Developer

| Platform | Trạng thái | Email đăng ký |
|----------|-----------|---------------|
| **Apple Developer** | ⏳ Chờ D-U-N-S (Organization) | Apple ID: Long Nguyen |
| **Google Play Console** | ⏳ Chờ D-U-N-S (Organization) | pachiabunff@gmail.com |

### Keystore Android

| Key | Value |
|-----|-------|
| **File** | `/Users/banhbao/quannho-release-key.jks` |
| **Backup** | `.docs/quannho-release-key.jks.backup` |
| **Alias** | `quannho` |
| **Config** | `android/key.properties` (KHÔNG commit lên Git) |
| **Validity** | 10,000 ngày (~27 năm) |

### Email Routing (Cloudflare)

| Email | Forward đến | Dùng cho |
|-------|-------------|----------|
| `lienhe@lpm.vn` | pachiabun1@gmail.com | Apple Developer, liên hệ chung |

---

## 9. Files tạo mới trong phiên triển khai

```
quan_nho/
├── lib/core/services/
│   ├── update_checker_service.dart    ← Kiểm tra bản mới từ Supabase
│   └── bug_reporter_service.dart      ← Upload ảnh + gửi bug report
├── lib/screens/
│   └── bug_report_screen.dart         ← UI báo lỗi (category, mô tả, chụp ảnh)
├── supabase/migrations/
│   └── phase1_versions_bugs.sql       ← SQL tạo bảng + RLS
├── web-download/
│   └── index.html                     ← Trang download app
├── release-builds/                    ← Output builds (gitignored)
│   ├── QuanNhoPOS-1.0.0.apk
│   ├── QuanNhoPOS-1.0.0.aab
│   └── QuanNhoPOS-1.0.0-macOS.zip
├── release.sh                         ← Script build tất cả platforms
├── android/key.properties             ← Keystore credentials (gitignored)
└── .docs/
    ├── deploy_ios_android.md          ← File này
    └── store_listing.md               ← Nội dung cho Store listing
```

---

> 📌 **File này nằm tại**: `.docs/deploy_ios_android.md`
> Cập nhật lần cuối: 2026-05-20 23:00

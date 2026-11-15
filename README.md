# SngTrans cho macOS (Swift)

Chạy ngầm ở thanh menu. Bôi đen chữ ở bất kỳ app nào là hiện thẻ dịch ngay cạnh con trỏ.

## Tạo app
Cần máy Mac (macOS 13+) có **Xcode** (hoặc chỉ Command Line Tools: `xcode-select --install`).

    ./build.sh

Ra `dist/SngTrans.app` và `dist/SngTrans.dmg` (chạy cả chip Apple lẫn Intel).
Chạy thử nhanh không đóng gói: `swift run`.
Không có Mac: đẩy thư mục này lên GitHub, tab **Actions > Build macOS app > Run workflow**, tải `SngTrans.dmg` ở mục Artifacts.

## Lần đầu mở
1. Kéo `SngTrans.app` vào **Applications**. Vì chưa ký bằng Apple Developer, bấm **chuột phải > Open > Open** lần đầu.
2. Hộp thoại hiện ra: bấm **Open System Settings** và bật SngTrans ở **Privacy & Security > Accessibility**
   (nếu thấy mục **Input Monitoring** thì bật luôn để phím `Esc` hoạt động).
3. Biểu tượng bong bóng xuất hiện trên thanh menu. Bôi đen chữ để thử.

> Ký ad-hoc nên mỗi lần build lại, macOS coi là app mới: xoá SngTrans khỏi danh sách Accessibility rồi thêm lại.
> Có Apple Developer ID thì thay `--sign -` trong `build.sh` bằng `--sign "Developer ID Application: ..."` để hết phiền.

## Dùng
- Bôi đen (kéo chuột, nhấp đúp/ba) → thẻ dịch hiện ngay.
- `⌥1` dịch phần đang chọn, `⌥2` bật/tắt tự dịch. `Esc` hoặc bấm ra ngoài để đóng.
- Trên thẻ: đọc to, sao chép, ghim, đóng.
- Menu: chọn ngôn ngữ đích, chạy cùng macOS.
- Chữ đã ở đúng ngôn ngữ đích thì tự dịch sang tiếng Anh (hoặc tiếng Việt nếu đích là Anh).

## Cấu trúc
    Sources/SngTrans/
      main.swift              khởi động app (chỉ ở thanh menu)
      AppDelegate.swift       menu, ngôn ngữ, phím tắt, quyền, chạy cùng máy
      SelectionWatcher.swift  theo dõi chuột/phím toàn hệ thống
      SelectedText.swift      lấy chữ bôi đen (Accessibility, dự phòng ⌘C)
      Translator.swift        Google Translate + cache + dự phòng máy chủ
      Card.swift              thẻ dịch (SwiftUI trong NSPanel không cướp focus)
      HotKey.swift            phím tắt toàn hệ thống

Chưa có so với bản Windows: ghi chú, chặn app, tự cập nhật (nên dùng Sparkle), đổi phím tắt.

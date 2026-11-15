# SngTrans cho macOS (Swift)

[**⬇ Tải SngTrans cho Mac**](https://github.com/tannhaii2309-lang/macsng/releases/download/mac-latest/SngTrans.dmg)
(file `.dmg`, macOS 13 trở lên, chip Apple và Intel) · [Trang tải và hướng dẫn](https://tannhaii2309-lang.github.io/macsng/)

Chạy ngầm ở thanh menu. Bôi đen chữ ở bất kỳ app nào là hiện thẻ dịch ngay cạnh con trỏ.

## Tạo app
Cần máy Mac (macOS 13+) có **Xcode** hoặc Command Line Tools (`xcode-select --install`).

| Cách | Làm gì |
|---|---|
| Bấm đúp `build.command` | Tạo `dist/SngTrans.app` và `dist/SngTrans.dmg` (chạy cả chip Apple lẫn Intel), rồi mở thư mục `dist`. Lần đầu nếu bị chặn: chuột phải > Open. |
| Bấm đúp `run.command` | Chạy thử từ mã nguồn, cửa sổ in nhật ký lỗi. |
| Terminal: `./build.sh` | Giống `build.command`. |

**Không có Mac:** đẩy thư mục này lên GitHub (kho riêng, hoặc để vào thư mục `mac/` rồi chuyển `.github/workflows/mac.yml` ra gốc kho và thêm `working-directory: mac` cho các bước build).
Tab **Actions > Build macOS app > Run workflow** > gõ phiên bản (vd `1.0.1`). Khoảng 5 phút sau, trang **Releases** có
`SngTrans.dmg`, `SngTrans-mac.zip` và file `.sha256`. Cách khác: tạo tag `mac-v1.0.1`.
Bản Mac không chiếm mục "Latest", nên link tải và tự cập nhật của bản Windows vẫn nguyên.

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
- Trên thẻ: lưu ghi chú (dấu trang), đọc to, sao chép, ghim, đóng; tick **Không tự dịch ở <app>** để loại app đó.
- Menu: chọn ngôn ngữ đích, chạy cùng macOS, **Ghi chú và chặn app** (xem, xoá, xuất CSV, bỏ chặn), **Kiểm tra cập nhật** (app cũng tự kiểm tra khi mở).
- Dữ liệu nằm ở `~/Library/Application Support/SngTrans` (`notes.json`, `blocked.json`).
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
      Store.swift             ghi chú, danh sách chặn app, xuất CSV
      ManagerWindow.swift     cửa sổ Ghi chú / Chặn app
      Updater.swift           kiểm tra bản mới trên GitHub Releases
      Links.swift             các đường link (repo, trang web, link tải .dmg)

Chưa có so với bản Windows: đổi phím tắt trong cài đặt và tự thay app khi cập nhật (hiện chỉ mở link tải).

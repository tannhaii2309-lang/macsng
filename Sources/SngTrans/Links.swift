import Foundation

/// Mọi đường link của app nằm ở đây, đổi một chỗ là xong.
enum Links {
    static let repo = "tannhaii2309-lang/macsng"
    static let site = URL(string: "https://tannhaii2309-lang.github.io/macsng/")!                       // trang tải và hướng dẫn
    static let dmg = URL(string: "https://github.com/\(repo)/releases/latest/download/SngTrans.dmg")!     // tải thẳng file .dmg
    static let releases = URL(string: "https://github.com/\(repo)/releases")!
    static let source = URL(string: "https://github.com/\(repo)")!
}

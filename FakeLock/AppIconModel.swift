import SwiftUI
import UIKit

// MARK: - App Icon
struct AppIcon: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String          // display name, e.g. "Facebook"
    var letter: Character {   // first letter of name, uppercased
        name.uppercased().first ?? "?"
    }
    var imageName: String     // filename saved in documents dir, e.g. "icon_facebook.jpg"
    var isUserProvided: Bool = true

    // Non-codable runtime image — loaded separately
    var image: UIImage? = nil

    enum CodingKeys: String, CodingKey {
        case id, name, imageName, isUserProvided
    }
}

// MARK: - Icon Store
class AppIconStore: ObservableObject {
    @Published var icons: [AppIcon] = []

    private let docsURL = FileManager.default.urls(
        for: .documentDirectory, in: .userDomainMask)[0]

    init() { load() }

    // MARK: - Persist
    func save() {
        if let data = try? JSONEncoder().encode(icons) {
            UserDefaults.standard.set(data, forKey: "appIcons")
        }
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: "appIcons"),
              var decoded = try? JSONDecoder().decode([AppIcon].self, from: data)
        else { icons = defaultIcons(); return }
        // Load images from disk
        for i in decoded.indices {
            let url = docsURL.appendingPathComponent(decoded[i].imageName)
            decoded[i].image = UIImage(contentsOfFile: url.path)
        }
        icons = decoded
    }

    func addIcon(name: String, image: UIImage) {
        let filename = "icon_\(UUID().uuidString).jpg"
        let url = docsURL.appendingPathComponent(filename)
        if let data = image.jpegData(compressionQuality: 0.9) {
            try? data.write(to: url)
        }
        var icon = AppIcon(name: name, imageName: filename)
        icon.image = image
        icons.append(icon)
        save()
    }

    func removeIcon(_ icon: AppIcon) {
        let url = docsURL.appendingPathComponent(icon.imageName)
        try? FileManager.default.removeItem(at: url)
        icons.removeAll { $0.id == icon.id }
        save()
    }

    func updateName(_ icon: AppIcon, newName: String) {
        guard let i = icons.firstIndex(where: { $0.id == icon.id }) else { return }
        icons[i].name = newName
        save()
    }

    // MARK: - Coverage check
    func missingLetters(for card: PlayingCard) -> [Character] {
        let needed = Set(card.letters)
        let available = Set(icons.map { $0.letter })
        return needed.filter { !available.contains($0) }.sorted()
    }

    func hasCoverage(for card: PlayingCard) -> Bool {
        missingLetters(for: card).isEmpty
    }

    // MARK: - Default built-in icons (SF Symbol based, replaced by user icons)
    func defaultIcons() -> [AppIcon] {
        // Returns empty — user provides all icons
        return []
    }
}

import Foundation

class AcrosticEngine {
    static func buildGrid(
        card: PlayingCard,
        store: AppIconStore,
        gridSize: Int = 24
    ) -> [AppIcon?] {
        let letters = card.letters
        let count   = letters.count

        guard count <= gridSize else { return [] }

        var usedIDs = Set<UUID>()
        var spellingIcons: [AppIcon?] = []

        for letter in letters {
            let match = store.icons.first(where: {
                $0.letter == letter && !usedIDs.contains($0.id)
            })
            spellingIcons.append(match)
            if let m = match { usedIDs.insert(m.id) }
        }

        let positions         = Array(0..<gridSize).shuffled()
        let spellingPositions = Array(positions.prefix(count)).sorted()

        var grid: [AppIcon?] = Array(repeating: nil, count: gridSize)

        for (i, pos) in spellingPositions.enumerated() {
            grid[pos] = spellingIcons[i]
        }

        let fillerPool = store.icons.filter { !usedIDs.contains($0.id) }.shuffled()
        var fillerIdx  = 0
        for i in 0..<gridSize {
            if grid[i] == nil {
                grid[i] = fillerIdx < fillerPool.count ? fillerPool[fillerIdx] : nil
                fillerIdx += 1
            }
        }

        return grid
    }
}

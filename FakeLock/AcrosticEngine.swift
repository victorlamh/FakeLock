import Foundation

class AcrosticEngine {
    // Build a grid of 24 icon indices from the icon store
    // spelling icons are scattered randomly, fillers fill the rest
    static func buildGrid(
        card: PlayingCard,
        store: AppIconStore,
        gridSize: Int = 24
    ) -> [AppIcon?] {
        let letters = card.letters  // e.g. ['T','H','R','E','E','H','E','A','R','T','S']
        let count   = letters.count

        guard count <= gridSize else { return [] }

        // Pick one icon per letter in order
        var usedIDs = Set<UUID>()
        var spellingIcons: [AppIcon?] = []

        for letter in letters {
            let match = store.icons.first(where: {
                $0.letter == letter && !usedIDs.contains($0.id)
            })
            spellingIcons.append(match)
            if let m = match { usedIDs.insert(m.id) }
        }

        // Scatter: pick random positions for spelling icons
        var positions = Array(0..<gridSize).shuffled()
        var spellingPositions = Array(positions.prefix(count)).sorted()

        // Fill grid
        var grid: [AppIcon?] = Array(repeating: nil, count: gridSize)

        // Place spelling icons at scattered positions
        for (i, pos) in spellingPositions.enumerated() {
            grid[pos] = spellingIcons[i]
        }

        // Fill remaining with filler icons (not already used)
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

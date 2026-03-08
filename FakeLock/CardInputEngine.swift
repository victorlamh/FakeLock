import Foundation
import UIKit

enum CardSuit: Int, CaseIterable {
    case hearts = 1, diamonds, clubs, spades

    var symbol: String {
        switch self {
        case .hearts:   return "♥"
        case .diamonds: return "♦"
        case .clubs:    return "♣"
        case .spades:   return "♠"
        }
    }

    var name: String {
        switch self {
        case .hearts:   return "HEARTS"
        case .diamonds: return "DIAMONDS"
        case .clubs:    return "CLUBS"
        case .spades:   return "SPADES"
        }
    }
}

enum CardValue: Int, CaseIterable {
    case ace=1, two, three, four, five, six, seven, eight, nine, ten, jack, queen, king

    var name: String {
        switch self {
        case .ace:   return "ACE"
        case .two:   return "TWO"
        case .three: return "THREE"
        case .four:  return "FOUR"
        case .five:  return "FIVE"
        case .six:   return "SIX"
        case .seven: return "SEVEN"
        case .eight: return "EIGHT"
        case .nine:  return "NINE"
        case .ten:   return "TEN"
        case .jack:  return "JACK"
        case .queen: return "QUEEN"
        case .king:  return "KING"
        }
    }
}

struct PlayingCard: Equatable {
    let value: CardValue
    let suit: CardSuit

    // Letters needed for acrostic
    var letters: [Character] {
        Array(value.name) + Array(suit.name)
    }

    var displayName: String { "\(value.name) of \(suit.name)" }
}

class CardInputEngine: ObservableObject {
    @Published var pendingCard: PlayingCard? = nil
    @Published var confirmedCard: PlayingCard? = nil

    // Input state
    private var upPresses: Int = 0
    private var downPresses: Int = 0
    private var phase: Phase = .idle
    private var confirmTimer: Timer?
    private let timeout: Double = 2.0

    enum Phase { case idle, collectingUp, collectingDown }

    // MARK: - Volume events
    func volumeUp() {
        guard phase != .collectingDown else { return } // UP must come first
        phase = .collectingUp
        upPresses += 1
        resetTimer()
    }

    func volumeDown() {
        guard phase == .collectingUp || phase == .collectingDown else { return }
        phase = .collectingDown
        downPresses += 1
        resetTimer()
    }

    // MARK: - Timer
    private func resetTimer() {
        confirmTimer?.invalidate()
        confirmTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            self?.confirm()
        }
    }

    private func confirm() {
        defer { reset() }
        guard upPresses >= 1 && upPresses <= 13 && downPresses >= 1 && downPresses <= 4 else { return }
        guard let value = CardValue(rawValue: upPresses),
              let suit  = CardSuit(rawValue: downPresses) else { return }
        let card = PlayingCard(value: value, suit: suit)
        DispatchQueue.main.async {
            self.confirmedCard = card
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    func reset() {
        upPresses   = 0
        downPresses = 0
        phase       = .idle
        confirmTimer?.invalidate()
    }

    func clearConfirmed() {
        confirmedCard = nil
    }
}

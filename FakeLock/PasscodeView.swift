import SwiftUI

extension Notification.Name {
    static let startAutoType = Notification.Name("startAutoType")
}

struct PasscodeView: View {
    @EnvironmentObject var engine: LockEngine

    @State private var enteredDigits: [Int] = []
    @State private var highlightedKey: Int? = nil
    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {

                // ── BACKGROUND ────────────────────────────────────
                backgroundLayer

                // ── MAIN CONTENT ──────────────────────────────────
                VStack(spacing: 0) {

                    Spacer().frame(height: geo.size.height * 0.13)

                    headerSection

                    Spacer().frame(height: geo.size.height * 0.07)

                    dotsRow

                    Spacer().frame(height: geo.size.height * 0.07)

                    numericGrid

                    Spacer().frame(height: 12)

                    KeyButton(digit: 0, isHighlighted: highlightedKey == 0) {
                        handleDigit(0)
                    }

                    Spacer()
                }

                // ── EMERGENCY + DELETE pinned to very bottom ───────
                VStack {
                    Spacer()
                    HStack {
                        Button("Emergency") {}
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 82, height: 44)

                        Spacer()

                        Button(action: deleteAction) {
                            Image(systemName: enteredDigits.isEmpty ? "xmark" : "delete.left")
                                .font(.system(size: 22, weight: .light))
                                .foregroundColor(.white.opacity(0.85))
                                .frame(width: 82, height: 44)
                        }
                    }
                    .padding(.horizontal, 46)
                    .padding(.bottom, max(geo.safeAreaInsets.bottom, 20) + 8)
                }
            }
        }
        .ignoresSafeArea()
        .gesture(swipeDownGesture)
        .onReceive(NotificationCenter.default.publisher(for: .startAutoType)) { _ in
            startAutoType()
        }
    }

    // MARK: - Sub-views

    var backgroundLayer: some View {
        ZStack {
            if let img = engine.wallpaperImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [Color(hex: "0a0e27"), Color(hex: "1a1060"), Color(hex: "0d0d1a")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.55)
                .ignoresSafeArea()
            Color.black.opacity(0.15).ignoresSafeArea()
        }
    }

    var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
            Text("Enter Passcode")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
            Text("Your passcode is required\nto enable Face ID")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
        }
    }

    var dotsRow: some View {
        HStack(spacing: 22) {
            ForEach(0..<4, id: \.self) { i in
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.75), lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                    if i < enteredDigits.count {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 16, height: 16)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
        .offset(x: shakeOffset)
        .animation(.spring(response: 0.15, dampingFraction: 0.4), value: shakeOffset)
    }

    var numericGrid: some View {
        VStack(spacing: 12) {
            numericRow([1, 2, 3])
            numericRow([4, 5, 6])
            numericRow([7, 8, 9])
        }
    }

    func numericRow(_ digits: [Int]) -> some View {
        HStack(spacing: 16) {
            ForEach(digits, id: \.self) { d in
                KeyButton(digit: d, isHighlighted: highlightedKey == d) {
                    handleDigit(d)
                }
            }
        }
    }

    var swipeDownGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                if value.translation.height > 80 {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                        engine.lockState = .locked
                    }
                }
            }
    }

    // MARK: - Logic

    func deleteAction() {
        if enteredDigits.isEmpty {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                engine.lockState = .locked
            }
        } else {
            withAnimation { enteredDigits.removeLast() }
        }
    }

    func handleDigit(_ digit: Int) {
        guard enteredDigits.count < 4 else { return }
        withAnimation(.easeInOut(duration: 0.08)) {
            enteredDigits.append(digit)
        }
        if enteredDigits.count == 4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { checkCode() }
        }
    }

    func checkCode() {
        if enteredDigits == engine.passcodeDigits {
            engine.performUnlock()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                enteredDigits = []
            }
        } else {
            shakeOffset = 18
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { shakeOffset = -18 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) { shakeOffset = 12 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { shakeOffset = -12 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) { shakeOffset = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                withAnimation { enteredDigits = [] }
            }
        }
    }

    func startAutoType() {
        guard engine.lockState == .passcode else { return }
        enteredDigits = []
        let code     = engine.passcodeDigits
        let interval = engine.digitInterval
        for (i, digit) in code.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                withAnimation(.easeInOut(duration: 0.08)) {
                    highlightedKey = digit
                    enteredDigits.append(digit)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation { highlightedKey = nil }
                }
                if i == code.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        engine.performUnlock()
                        enteredDigits = []
                    }
                }
            }
        }
    }
}

// MARK: - Key Button
struct KeyButton: View {
    let digit: Int
    let isHighlighted: Bool
    let action: () -> Void

    let letters: [Int: String] = [
        2: "ABC", 3: "DEF", 4: "GHI", 5: "JKL",
        6: "MNO", 7: "PQRS", 8: "TUV", 9: "WXYZ"
    ]

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isHighlighted
                          ? Color.white.opacity(0.9)
                          : Color.white.opacity(0.18))
                    .frame(width: 82, height: 82)
                    .scaleEffect(isHighlighted ? 0.93 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isHighlighted)
                VStack(spacing: 1) {
                    Text("\(digit)")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(isHighlighted ? .black : .white)
                    if let letter = letters[digit] {
                        Text(letter)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(isHighlighted
                                             ? .black.opacity(0.6)
                                             : .white.opacity(0.6))
                            .kerning(1.8)
                    }
                }
            }
        }
        .frame(width: 82, height: 82)
    }
}

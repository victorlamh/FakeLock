import SwiftUI

extension Notification.Name {
    static let startAutoType = Notification.Name("startAutoType")
}

struct PasscodeView: View {
    let wallpaper: UIImage?
    @EnvironmentObject var engine: LockEngine

    @State private var enteredDigits: [Int] = []
    @State private var highlightedKey: Int? = nil
    @State private var shakeOffset: CGFloat = 0

    let keys: [[Int?]] = [
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9],
        [nil, 0, nil]
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Blurred wallpaper
                if let img = wallpaper {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                } else {
                    LinearGradient(
                        colors: [Color(hex: "0a0e27"), Color(hex: "1a1060"), Color(hex: "0d0d1a")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                }

                VStack(spacing: 0) {

                    Spacer().frame(height: geo.safeAreaInsets.top + 30)

                    // Lock icon
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.bottom, 16)

                    // Title
                    Text("Enter Passcode")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Your passcode is required\nto enable Face ID")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)

                    Spacer().frame(height: 40)

                    // 4 dots
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

                    Spacer().frame(height: 52)

                    // Keypad
                    VStack(spacing: 10) {
                        ForEach(0..<keys.count, id: \.self) { row in
                            HStack(spacing: 16) {
                                ForEach(0..<keys[row].count, id: \.self) { col in
                                    let digit = keys[row][col]

                                    if let d = digit {
                                        KeyButton(
                                            digit: d,
                                            isHighlighted: highlightedKey == d
                                        ) { handleDigit(d) }

                                    } else if row == 3 && col == 0 {
                                        // Emergency
                                        Button("Emergency") {}
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.85))
                                            .frame(width: 82, height: 82)

                                    } else if row == 3 && col == 2 {
                                        // Delete / Cancel
                                        Button(action: {
                                            if enteredDigits.isEmpty {
                                                withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                                                    engine.lockState = .locked
                                                }
                                            } else {
                                                withAnimation { enteredDigits.removeLast() }
                                            }
                                        }) {
                                            Image(systemName: enteredDigits.isEmpty ? "xmark" : "delete.left")
                                                .font(.system(size: 22, weight: .light))
                                                .foregroundColor(.white.opacity(0.85))
                                                .frame(width: 82, height: 82)
                                        }

                                    } else {
                                        Color.clear.frame(width: 82, height: 82)
                                    }
                                }
                            }
                        }
                    }

                    Spacer()
                }
            }
        }
        // Swipe down → back to lock
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.height > 80 {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                            engine.lockState = .locked
                        }
                    }
                }
        )
        .onReceive(NotificationCenter.default.publisher(for: .startAutoType)) { _ in
            startAutoType()
        }
    }

    // MARK: - Digit input
    func handleDigit(_ digit: Int) {
        guard enteredDigits.count < 4 else { return }
        withAnimation(.easeInOut(duration: 0.08)) {
            enteredDigits.append(digit)
        }
        if enteredDigits.count == 4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                checkCode()
            }
        }
    }

    func checkCode() {
        if enteredDigits == engine.passcodeDigits {
            engine.performUnlock()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                enteredDigits = []
            }
        } else {
            // Wrong — shake
            shakeOffset = 18
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { shakeOffset = -18 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { shakeOffset = 12 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { shakeOffset = -12 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shakeOffset = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation { enteredDigits = [] }
            }
        }
    }

    // MARK: - Auto-type
    func startAutoType() {
        guard engine.lockState == .passcode else { return }
        enteredDigits = []
        let code = engine.passcodeDigits
        let interval = engine.digitInterval

        for (i, digit) in code.enumerated() {
            let delay = interval * Double(i)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
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
                            .foregroundColor(isHighlighted ? .black.opacity(0.6) : .white.opacity(0.6))
                            .kerning(1.8)
                    }
                }
            }
        }
        .frame(width: 82, height: 82)
    }
}

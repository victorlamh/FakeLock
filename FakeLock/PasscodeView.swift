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

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backgroundLayer
                VStack(spacing: 0) {
                    Spacer().frame(height: geo.safeAreaInsets.top + 30)
                    headerSection
                    Spacer().frame(height: 40)
                    dotsRow
                    Spacer().frame(height: 52)
                    keypadSection
                    Spacer()
                    bottomRow
                        .padding(.bottom, geo.safeAreaInsets.bottom + 16)
                }
            }
        }
        .ignoresSafeArea()
        .gesture(swipeDownGesture)
        .onReceive(NotificationCenter.default.publisher(for: .startAutoType)) { _ in
            startAutoType()
        }
    }

    // MARK: - Sub views

    var backgroundLayer: some View {
        ZStack {
            if let img = wallpaper {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                Color.black.opacity(0.3).ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [Color(hex: "0a0e27"), Color(hex: "1a1060"), Color(hex: "0d0d1a")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
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

    var keypadSection: some View {
        VStack(spacing: 10) {
            row(digits: [1, 2, 3])
            row(digits: [4, 5, 6])
            row(digits: [7, 8, 9])
            bottomKeyRow
        }
    }

    func row(digits: [Int]) -> some View {
        HStack(spacing: 16) {
            ForEach(digits, id: \.self) { d in
                KeyButton(digit: d, isHighlighted: highlightedKey == d) {
                    handleDigit(d)
                }
            }
        }
    }

    var bottomKeyRow: some View {
        HStack(spacing: 16) {
            Button("Emergency") {}
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.85))
                .frame(width: 82, height: 82)

            KeyButton(digit: 0, isHighlighted: highlightedKey == 0) {
                handleDigit(0)
            }

            Button(action: deleteAction) {
                Image(systemName: enteredDigits.isEmpty ? "xmark" : "delete.left")
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 82, height: 82)
            }
        }
    }

    var bottomRow: some View {
        Rectangle()
            .fill(Color.white.opacity(0.35))
            .frame(width: 130, height: 5)
            .cornerRadius(3)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)  { shakeOffset = -18 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2)  { shakeOffset = 12 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)  { shakeOffset = -12 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4)  { shakeOffset = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                withAnimation { enteredDigits = [] }
            }
        }
    }

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
                    .fill(isHighlighted ? Color.white.opacity(0.9) : Color.white.opacity(0.18))
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

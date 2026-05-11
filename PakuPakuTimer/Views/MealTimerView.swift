import SwiftUI

struct MealTimerView: View {
    @StateObject private var viewModel = MealTimerViewModel()
    @State private var lastTickDate: Date?
    private let soundPlayer = SoundPlayer()
    private let ticker = Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / StageMetrics.width, proxy.size.height / StageMetrics.height)

            ZStack {
                PakuStyle.outerBackground
                    .ignoresSafeArea()

                StageCanvas(viewModel: viewModel)
                    .frame(width: StageMetrics.width, height: StageMetrics.height)
                    .scaleEffect(scale)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .onReceive(ticker) { date in
            guard viewModel.isRunning else {
                lastTickDate = nil
                return
            }
            guard let lastTickDate else {
                self.lastTickDate = date
                return
            }
            viewModel.advance(by: date.timeIntervalSince(lastTickDate))
            self.lastTickDate = date
        }
        .onChange(of: viewModel.phase) { _, newPhase in
            if case .awaitingConfirmation = newPhase {
                soundPlayer.playBoundarySound(enabled: viewModel.soundEnabled)
            } else if newPhase == .completed {
                soundPlayer.playBoundarySound(enabled: viewModel.soundEnabled)
            }
        }
    }
}

private enum StageMetrics {
    static let width: CGFloat = 1366
    static let height: CGFloat = 1024
    static let stageCorner: CGFloat = 42
    static let plateSize: CGFloat = 500
    static let plateCanvas: CGFloat = 640
}

private enum PakuStyle {
    static let leaf = Color(red: 0.59, green: 0.81, blue: 0.42)
    static let leafDark = Color(red: 0.36, green: 0.61, blue: 0.26)
    static let cream = Color(red: 1.0, green: 0.98, blue: 0.91)
    static let ink = Color(red: 0.42, green: 0.21, blue: 0.09)
    static let rice = Color(red: 0.96, green: 0.94, blue: 0.86)
    static let egg = Color(red: 1.0, green: 0.79, blue: 0.16)
    static let yogurt = Color(red: 0.73, green: 0.64, blue: 0.93)
    static let orange = Color(red: 0.94, green: 0.38, blue: 0.13)
    static let button = Color(red: 1.0, green: 0.97, blue: 0.85)

    static var outerBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.80, green: 0.91, blue: 0.60),
                Color(red: 0.65, green: 0.85, blue: 0.46),
                Color(red: 0.56, green: 0.81, blue: 0.40)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct StageCanvas: View {
    @ObservedObject var viewModel: MealTimerViewModel

    var body: some View {
        ZStack {
            stageBackground
            FoodSprinkleLayer()
            GrassLayer()
            BuntingView()
                .position(x: 126, y: 82)

            header
                .position(x: StageMetrics.width / 2, y: 88)

            SettingsCircleButton(
                title: "設定",
                symbol: "gearshape.fill",
                active: viewModel.phase == .setting
            ) {
                if viewModel.phase == .setting {
                    viewModel.commitSettings()
                } else {
                    viewModel.openSettings()
                }
            }
            .position(x: 350, y: 574)
            .accessibilityIdentifier("settingsButton")

            TimerPlateArea(viewModel: viewModel)
                .frame(width: StageMetrics.plateSize, height: StageMetrics.plateSize)
                .position(x: 683, y: 508)

            SidePanel()
                .frame(width: 168, height: 420)
                .position(x: 1018, y: 512)

            SettingsCircleButton(
                title: "おと",
                symbol: viewModel.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                active: viewModel.soundEnabled
            ) {
                viewModel.toggleSound()
            }
            .position(x: 1262, y: 914)
            .accessibilityIdentifier("soundButton")

            controls
                .position(x: StageMetrics.width / 2, y: 972)

            if viewModel.showsExtensionCompletion {
                Button("完了") {
                    viewModel.finishExtension()
                }
                .buttonStyle(PakuPillButtonStyle(primary: true, minWidth: 136, height: 58, fontSize: 24))
                .position(x: StageMetrics.width / 2, y: 904)
                .accessibilityIdentifier("completeExtensionButton")
            }

            if viewModel.phase == .setting {
                SettingsPanel(viewModel: viewModel)
                    .position(x: StageMetrics.width / 2, y: 906)
            }

            if let confirmation = viewModel.pendingConfirmation {
                ConfirmationPanel(confirmation: confirmation, viewModel: viewModel)
                    .position(x: StageMetrics.width / 2, y: 898)
            }

            if viewModel.isComplete {
                CompleteMessage(viewModel: viewModel)
                    .position(x: StageMetrics.width / 2, y: 862)
            }
        }
        .frame(width: StageMetrics.width, height: StageMetrics.height)
        .clipShape(RoundedRectangle(cornerRadius: StageMetrics.stageCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StageMetrics.stageCorner, style: .continuous)
                .stroke(Color(red: 0.45, green: 0.69, blue: 0.28).opacity(0.52), lineWidth: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: StageMetrics.stageCorner - 6, style: .continuous)
                .stroke(Color.white.opacity(0.9), lineWidth: 2)
                .padding(6)
        )
        .shadow(color: Color(red: 0.42, green: 0.32, blue: 0.15).opacity(0.18), radius: 28, y: 12)
    }

    private var stageBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 1.0, green: 0.99, blue: 0.95), Color(red: 1.0, green: 0.98, blue: 0.91)],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(Color(red: 1.0, green: 0.86, blue: 0.40).opacity(0.32))
                .frame(width: 12, height: 12)
                .position(x: 273, y: 328)
            Circle()
                .fill(Color(red: 0.95, green: 0.52, blue: 0.59).opacity(0.30))
                .frame(width: 16, height: 16)
                .position(x: 1052, y: 348)
            Circle()
                .fill(Color(red: 0.55, green: 0.79, blue: 0.38).opacity(0.18))
                .frame(width: 24, height: 24)
                .position(x: 1174, y: 635)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                Text("ぱ").foregroundStyle(Color(red: 0.95, green: 0.36, blue: 0.17))
                Text("く").foregroundStyle(Color(red: 0.97, green: 0.73, blue: 0.05))
                Text("ぱ").foregroundStyle(Color(red: 0.47, green: 0.72, blue: 0.18))
                Text("く").foregroundStyle(Color(red: 0.97, green: 0.73, blue: 0.05))
                Text("タイマー").foregroundStyle(Color(red: 0.62, green: 0.38, blue: 0.09))
            }
            .font(.system(size: 76, weight: .heavy, design: .rounded))
            .shadow(color: Color(red: 1.0, green: 0.96, blue: 0.87), radius: 0, x: 0, y: 5)
            .accessibilityAddTraits(.isHeader)

            HStack(spacing: 18) {
                Text("ぜんたい")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                Text(viewModel.formattedRemaining(viewModel.remainingTotalSeconds))
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(PakuStyle.orange)
                    .monospacedDigit()
            }
            .foregroundStyle(PakuStyle.ink)
            .frame(minWidth: 292, minHeight: 62)
            .padding(.horizontal, 28)
            .background(
                Capsule()
                    .fill(LinearGradient(colors: [Color(red: 1, green: 0.99, blue: 0.94), Color(red: 1, green: 0.97, blue: 0.85)], startPoint: .top, endPoint: .bottom))
            )
            .overlay(Capsule().stroke(Color(red: 0.85, green: 0.87, blue: 0.63), lineWidth: 4))
            .overlay(Capsule().stroke(Color.white, lineWidth: 2).padding(4))
            .shadow(color: Color(red: 0.43, green: 0.38, blue: 0.16).opacity(0.14), radius: 14, y: 7)
        }
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button(viewModel.isRunning ? "とめる" : viewModel.isComplete ? "もう一回" : "スタート") {
                viewModel.isRunning ? viewModel.pause() : viewModel.start()
            }
            .buttonStyle(PakuPillButtonStyle(primary: true))
            .disabled(viewModel.pendingConfirmation != nil || viewModel.phase == .setting)
            .accessibilityIdentifier("startPauseButton")

            Button("リセット") {
                viewModel.reset()
            }
            .buttonStyle(PakuPillButtonStyle())
            .accessibilityIdentifier("resetButton")

            Button("テスト") {
                viewModel.enableTestMode()
            }
            .buttonStyle(PakuPillButtonStyle(active: viewModel.testMode))
            .accessibilityIdentifier("testButton")
        }
    }
}

private struct TimerPlateArea: View {
    @ObservedObject var viewModel: MealTimerViewModel

    var body: some View {
        ZStack {
            MealPlate(viewModel: viewModel)
                .frame(width: StageMetrics.plateSize, height: StageMetrics.plateSize)
                .shadow(color: Color(red: 0.35, green: 0.25, blue: 0.13).opacity(0.22), radius: 16, y: 8)

            FoodLabel(food: .yogurt, remaining: viewModel.formattedRemaining(viewModel.remainingSeconds(for: .yogurt)))
                .scaleEffect(viewModel.activeFood == .yogurt ? 1.06 : 1.0)
                .position(x: 82, y: 216)

            FoodLabel(food: .egg, remaining: viewModel.formattedRemaining(viewModel.remainingSeconds(for: .egg)))
                .scaleEffect(viewModel.activeFood == .egg ? 1.06 : 1.0)
                .position(x: 250, y: 390)

            FoodLabel(food: .rice, remaining: viewModel.formattedRemaining(viewModel.remainingSeconds(for: .rice)))
                .scaleEffect(viewModel.activeFood == .rice ? 1.06 : 1.0)
                .position(x: 418, y: 216)

            PakuPakuFace(
                mode: viewModel.isComplete ? .happy : viewModel.isRunning ? .chomping : .open,
                scale: 1
            )
            .frame(width: 138, height: 138)
            .position(x: 250, y: 250)
            .accessibilityLabel("パクパクくん")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("食事タイマー")
    }
}

private struct MealPlate: View {
    @ObservedObject var viewModel: MealTimerViewModel

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 456, height: 456)

            Circle()
                .fill(Color(red: 1.0, green: 0.97, blue: 0.87))
                .overlay(Circle().stroke(Color(red: 0.90, green: 0.74, blue: 0.50), lineWidth: 3))
                .frame(width: 422, height: 422)

            ForEach(FoodKind.plateOrder) { food in
                SectorShape(
                    startAngle: cssStartAngle(for: food),
                    endAngle: cssEndAngle(for: food),
                    innerRadiusRatio: 104 / 270
                )
                .fill(food.displayColor.opacity(viewModel.progressRatio(for: food) >= 1 ? 0.18 : 1))
                .frame(width: 422, height: 422)

                SectorShape(
                    startAngle: cssStartAngle(for: food),
                    endAngle: eatenEndAngle(for: food),
                    innerRadiusRatio: 104 / 270
                )
                .fill(Color(red: 1.0, green: 0.98, blue: 0.91).opacity(viewModel.progressRatio(for: food) <= 0 ? 0 : 0.95))
                .frame(width: 422, height: 422)

                ArcDots(startAngle: cssStartAngle(for: food) + 8, endAngle: cssEndAngle(for: food) - 8)
                    .stroke(PakuStyle.ink.opacity(0.34), style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [1, 15]))
                    .frame(width: 374, height: 374)
            }

            Circle()
                .fill(Color.white)
                .frame(width: 154, height: 154)
                .shadow(color: Color(red: 0.37, green: 0.27, blue: 0.16).opacity(0.20), radius: 10, y: 9)
        }
    }

    private func cssStartAngle(for food: FoodKind) -> Double {
        switch food {
        case .yogurt:
            240
        case .egg:
            120
        case .rice:
            0
        }
    }

    private func cssEndAngle(for food: FoodKind) -> Double {
        switch food {
        case .yogurt:
            360
        case .egg:
            240
        case .rice:
            120
        }
    }

    private func eatenEndAngle(for food: FoodKind) -> Double {
        let start = cssStartAngle(for: food)
        let end = cssEndAngle(for: food)
        return start + (end - start) * viewModel.progressRatio(for: food)
    }
}

private struct SectorShape: Shape {
    let startAngle: Double
    let endAngle: Double
    let innerRadiusRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let innerRadius = radius * innerRadiusRatio

        var path = Path()
        path.move(to: point(center: center, radius: radius, angle: startAngle))
        path.addArc(center: center, radius: radius, startAngle: .degrees(startAngle - 90), endAngle: .degrees(endAngle - 90), clockwise: false)
        path.addLine(to: point(center: center, radius: innerRadius, angle: endAngle))
        path.addArc(center: center, radius: innerRadius, startAngle: .degrees(endAngle - 90), endAngle: .degrees(startAngle - 90), clockwise: true)
        path.closeSubpath()
        return path
    }

    private func point(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        let radians = (angle - 90) * .pi / 180
        return CGPoint(x: center.x + cos(radians) * radius, y: center.y + sin(radians) * radius)
    }
}

private struct ArcDots: Shape {
    let startAngle: Double
    let endAngle: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: min(rect.width, rect.height) / 2,
            startAngle: .degrees(startAngle - 90),
            endAngle: .degrees(endAngle - 90),
            clockwise: false
        )
        return path
    }
}

private struct FoodLabel: View {
    let food: FoodKind
    let remaining: String

    var body: some View {
        VStack(spacing: 0) {
            Text(food.emoji)
                .font(.system(size: 38))
                .frame(width: 64, height: 50)
                .shadow(color: Color(red: 0.38, green: 0.27, blue: 0.14).opacity(0.18), radius: 3, y: 4)

            if food == .egg {
                Text("たまごや")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .offset(y: 3)
            }

            Text(food.displayName)
                .font(.system(size: 23, weight: .black, design: .rounded))

            Text(remaining)
                .font(.system(size: 38, weight: .black, design: .rounded))
                .monospacedDigit()
                .padding(.top, 5)
        }
        .foregroundStyle(PakuStyle.ink)
        .frame(minWidth: 106)
        .shadow(color: Color.white.opacity(0.7), radius: 0, y: 2)
    }
}

private enum PakuFaceMode {
    case open
    case closed
    case chomping
    case happy
}

private struct PakuPakuFace: View {
    let mode: PakuFaceMode
    let scale: CGFloat
    @State private var mouthOpen = true

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.62),
                            Color(red: 1.0, green: 0.91, blue: 0.42),
                            Color(red: 1.0, green: 0.77, blue: 0.0)
                        ],
                        center: .topLeading,
                        startRadius: 8,
                        endRadius: 120
                    )
                )
                .overlay(Circle().stroke(Color.white, lineWidth: 0))
                .shadow(color: Color(red: 0.32, green: 0.24, blue: 0.09).opacity(0.20), radius: 18, y: 9)
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Color(red: 0.91, green: 0.61, blue: 0.0).opacity(0.26))
                        .frame(width: 120, height: 120)
                        .offset(x: 18, y: 18)
                }

            if mode == .happy {
                HappyFaceDetails()
            } else {
                SideFaceDetails(mouthOpen: mode == .open || (mode == .chomping && mouthOpen))
            }
        }
        .scaleEffect(scale)
        .clipShape(Circle())
        .onAppear {
            mouthOpen = mode != .closed
        }
        .onChange(of: mode) { _, newMode in
            mouthOpen = newMode != .closed
        }
        .onReceive(Timer.publish(every: 0.28, on: .main, in: .common).autoconnect()) { _ in
            guard mode == .chomping else { return }
            mouthOpen.toggle()
        }
    }
}

private struct SideFaceDetails: View {
    let mouthOpen: Bool

    var body: some View {
        ZStack {
            EyeShape()
                .stroke(PakuStyle.ink, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .frame(width: 27, height: 19)
                .position(x: 78, y: 47)

            Ellipse()
                .fill(Color(red: 1.0, green: 0.59, blue: 0.51).opacity(0.86))
                .frame(width: 25, height: 20)
                .position(x: 45, y: 80)

            MouthShape(open: mouthOpen)
                .fill(Color(red: 0.48, green: 0.20, blue: 0.04))
                .frame(width: mouthOpen ? 73 : 73, height: mouthOpen ? 64 : 20)
                .position(x: 110, y: mouthOpen ? 71 : 70)
                .animation(.easeInOut(duration: 0.12), value: mouthOpen)
        }
    }
}

private struct HappyFaceDetails: View {
    var body: some View {
        ZStack {
            HStack(spacing: 28) {
                EyeSmileShape()
                    .stroke(PakuStyle.ink, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .frame(width: 24, height: 18)
                EyeSmileShape()
                    .stroke(PakuStyle.ink, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .frame(width: 24, height: 18)
            }
            .position(x: 69, y: 47)

            HStack(spacing: 44) {
                Ellipse().fill(Color(red: 1.0, green: 0.59, blue: 0.51).opacity(0.86)).frame(width: 24, height: 19)
                Ellipse().fill(Color(red: 1.0, green: 0.59, blue: 0.51).opacity(0.86)).frame(width: 24, height: 19)
            }
            .position(x: 69, y: 78)

            SmileShape()
                .stroke(Color(red: 0.48, green: 0.20, blue: 0.04), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 62, height: 31)
                .position(x: 69, y: 91)
        }
    }
}

private struct EyeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY * 0.58))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.58), control: CGPoint(x: rect.midX, y: rect.minY))
        return path
    }
}

private struct EyeSmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

private struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

private struct MouthShape: Shape {
    let open: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if open {
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - 2))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY + 2))
        }
        path.closeSubpath()
        return path
    }
}

private struct SidePanel: View {
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color(red: 1.0, green: 0.99, blue: 0.95))
                .shadow(color: Color(red: 0.40, green: 0.31, blue: 0.17).opacity(0.16), radius: 22, y: 12)

            TrianglePointer()
                .fill(Color(red: 1.0, green: 0.99, blue: 0.95))
                .frame(width: 48, height: 48)
                .offset(x: -30)

            VStack(spacing: 9) {
                Text("パクパクくんが\nパクパク動くよ!")
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .lineSpacing(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 0.30, green: 0.60, blue: 0.19))

                PakuPakuFace(mode: .open, scale: 92 / 138)
                    .frame(width: 92, height: 92)
                Text("あーん")
                    .font(.system(size: 23, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.96, green: 0.48, blue: 0.09))
                Text("↕")
                    .font(.system(size: 50, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.47, green: 0.74, blue: 0.34))
                    .frame(height: 44)
                PakuPakuFace(mode: .closed, scale: 92 / 138)
                    .frame(width: 92, height: 92)
                Text("ぱくっ")
                    .font(.system(size: 23, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.41, green: 0.66, blue: 0.26))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct TrianglePointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct SettingsCircleButton: View {
    let title: String
    let symbol: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(title == "おと" ? Color(red: 0.31, green: 0.61, blue: 0.24) : Color(red: 0.55, green: 0.39, blue: 0.22))
                Text(title)
                    .font(.system(size: 16, weight: .black, design: .rounded))
            }
            .foregroundStyle(Color(red: 0.60, green: 0.42, blue: 0.21))
            .frame(width: 88, height: 88)
            .background(PakuStyle.button, in: Circle())
            .overlay(Circle().stroke(Color(red: 0.72, green: 0.86, blue: 0.50), lineWidth: 5))
            .overlay(Circle().stroke(Color.white, lineWidth: 4).padding(7))
            .shadow(color: Color(red: 0.40, green: 0.33, blue: 0.17).opacity(0.18), radius: 18, y: 8)
            .opacity(active ? 1.0 : 0.58)
        }
        .buttonStyle(.plain)
    }
}

private struct PakuPillButtonStyle: ButtonStyle {
    var primary = false
    var active = false
    var minWidth: CGFloat = 120
    var height: CGFloat = 54
    var fontSize: CGFloat = 22

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .black, design: .rounded))
            .foregroundStyle(PakuStyle.ink)
            .frame(minWidth: minWidth, minHeight: height)
            .padding(.horizontal, 20)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: active
                            ? [Color(red: 0.95, green: 1.0, blue: 0.82), Color(red: 0.66, green: 0.90, blue: 0.42)]
                            : primary
                            ? [Color(red: 1.0, green: 0.96, blue: 0.65), Color(red: 1.0, green: 0.68, blue: 0.20)]
                            : [Color(red: 1.0, green: 0.97, blue: 0.78), Color(red: 1.0, green: 0.87, blue: 0.43)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            )
            .overlay(Capsule().stroke(primary ? Color(red: 0.97, green: 0.66, blue: 0.35) : Color(red: 0.89, green: 0.78, blue: 0.43), lineWidth: 4))
            .overlay(Capsule().stroke(Color.white.opacity(0.7), lineWidth: 2).padding(4))
            .shadow(color: Color(red: 0.35, green: 0.27, blue: 0.12).opacity(0.14), radius: 12, y: 7)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}

private struct SettingsPanel: View {
    @ObservedObject var viewModel: MealTimerViewModel

    var body: some View {
        HStack(spacing: 14) {
            SettingsFoodPicker(food: .yogurt, viewModel: viewModel)
            SettingsFoodPicker(food: .egg, viewModel: viewModel)
            SettingsFoodPicker(food: .rice, viewModel: viewModel)
        }
        .padding(14)
        .background(Color(red: 1.0, green: 0.99, blue: 0.95).opacity(0.97), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color(red: 0.84, green: 0.87, blue: 0.63), lineWidth: 4))
        .shadow(color: Color(red: 0.35, green: 0.26, blue: 0.14).opacity(0.18), radius: 22, y: 12)
    }
}

private struct SettingsFoodPicker: View {
    let food: FoodKind
    @ObservedObject var viewModel: MealTimerViewModel

    var body: some View {
        HStack(spacing: 6) {
            Text(food.displayName)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .frame(width: 98, alignment: .leading)

            Menu {
                ForEach(1...60, id: \.self) { minutes in
                    Button("\(minutes)分") {
                        viewModel.updateDraftMinutes(minutes, for: food)
                    }
                }
            } label: {
                HStack(spacing: 2) {
                    Text("\(viewModel.draftMinutesByFood[food] ?? food.defaultMinutes)")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .monospacedDigit()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .black))
                }
                .foregroundStyle(PakuStyle.ink)
                .frame(width: 78, height: 48)
                .background(
                    Capsule().fill(
                        LinearGradient(colors: [Color(red: 1.0, green: 0.97, blue: 0.78), Color(red: 1.0, green: 0.87, blue: 0.43)], startPoint: .top, endPoint: .bottom)
                    )
                )
                .overlay(Capsule().stroke(Color(red: 0.89, green: 0.78, blue: 0.43), lineWidth: 4))
            }

            Text("分")
                .font(.system(size: 18, weight: .black, design: .rounded))
        }
        .foregroundStyle(PakuStyle.ink)
    }
}

private struct ConfirmationPanel: View {
    let confirmation: BoundaryConfirmation
    @ObservedObject var viewModel: MealTimerViewModel

    var body: some View {
        VStack(spacing: 0) {
            if let nextFood = confirmation.nextFood {
                Text("\(confirmation.food.displayName) おしまい？")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(PakuStyle.orange)
                    .lineLimit(1)
                Text("つぎは \(nextFood.displayName)")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.37, green: 0.62, blue: 0.25))
                    .padding(.top, 2)
            }

            HStack(spacing: 12) {
                Button(confirmation.nextFood == nil ? "ごちそうさま" : "つぎへ") {
                    viewModel.goToNextFood()
                }
                .buttonStyle(PakuPillButtonStyle(primary: true))
                .accessibilityIdentifier("nextFoodButton")

                Button("もう1分") {
                    viewModel.extendOneMinute()
                }
                .buttonStyle(PakuPillButtonStyle(active: true))
                .accessibilityIdentifier("extendFoodButton")
            }
            .padding(.top, confirmation.nextFood == nil ? 0 : 10)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .frame(minWidth: 390)
        .background(Color(red: 1.0, green: 0.99, blue: 0.93).opacity(0.99), in: RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 36, style: .continuous).stroke(Color(red: 0.56, green: 0.81, blue: 0.40), lineWidth: 6))
        .shadow(color: Color(red: 0.36, green: 0.27, blue: 0.13).opacity(0.22), radius: 34, y: 16)
    }
}

private struct CompleteMessage: View {
    @ObservedObject var viewModel: MealTimerViewModel

    var body: some View {
        VStack(spacing: 4) {
            Text("ごちそうさま!")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(PakuStyle.orange)
            Text("ぜんぶ食べたよ")
                .font(.system(size: 21, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.37, green: 0.62, blue: 0.25))

            VStack(spacing: 6) {
                Text("かかったじかん")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.55, green: 0.39, blue: 0.22))

                VStack(spacing: 4) {
                    ForEach(FoodKind.eatingOrder) { food in
                        HStack {
                            Text(food.displayName)
                            Spacer()
                            Text(viewModel.formattedSpent(viewModel.spentSecondsByFood[food] ?? 0))
                                .foregroundStyle(PakuStyle.orange)
                                .monospacedDigit()
                        }
                        .font(.system(size: 18, weight: .black, design: .rounded))
                    }
                }
                .frame(width: 280)
            }
            .padding(.top, 8)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.clear)
                    .frame(height: 0)
                    .border(Color.clear)
            }
            .padding(.top, 8)
            .background(alignment: .top) {
                DashedLine()
                    .stroke(Color(red: 0.56, green: 0.81, blue: 0.40).opacity(0.72), style: StrokeStyle(lineWidth: 3, dash: [8, 7]))
                    .frame(height: 3)
            }
        }
        .foregroundStyle(PakuStyle.ink)
        .padding(.horizontal, 30)
        .padding(.vertical, 16)
        .frame(minWidth: 360)
        .background(Color(red: 1.0, green: 0.99, blue: 0.93).opacity(0.98), in: RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 36, style: .continuous).stroke(Color(red: 0.56, green: 0.81, blue: 0.40), lineWidth: 6))
        .shadow(color: Color(red: 0.36, green: 0.27, blue: 0.13).opacity(0.22), radius: 34, y: 16)
    }
}

private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

private struct FoodSprinkleLayer: View {
    private let items: [FoodSprinkle] = [
        .init("🍙", 0.12, 0.20, 52, -13, 0.70), .init("🍚", 0.87, 0.22, 52, 12, 0.70),
        .init("🍳", 0.91, 0.70, 52, -11, 0.70), .init("🥣", 0.10, 0.70, 52, 10, 0.70),
        .init("🥕", 0.24, 0.14, 46, 18, 0.70), .init("🍓", 0.76, 0.14, 45, -16, 0.70),
        .init("🥦", 0.82, 0.94, 48, 14, 0.70), .init("🥄", 0.18, 0.92, 44, -20, 0.70),
        .init("🍎", 0.05, 0.45, 44, -12, 0.70), .init("🥪", 0.95, 0.46, 46, -13, 0.70),
        .init("🥛", 0.16, 0.56, 42, -15, 0.66), .init("🍌", 0.85, 0.58, 42, 18, 0.66),
        .init("🌽", 0.38, 0.24, 43, -10, 0.66), .init("🍱", 0.58, 0.94, 44, 11, 0.66),
        .init("🍠", 0.34, 0.83, 39, -16, 0.62), .init("🍊", 0.66, 0.24, 39, 15, 0.62),
        .init("🍇", 0.04, 0.27, 37, -8, 0.62), .init("🍅", 0.96, 0.28, 37, 12, 0.62),
        .init("🥒", 0.30, 0.69, 38, 18, 0.60), .init("🍞", 0.70, 0.69, 38, -14, 0.60),
        .init("🧀", 0.06, 0.09, 36, 14, 0.60), .init("🥗", 0.94, 0.91, 37, -10, 0.60),
        .init("🥟", 0.78, 0.58, 36, 16, 0.58), .init("🍣", 0.22, 0.58, 36, -12, 0.58),
        .init("🥞", 0.56, 0.24, 36, 10, 0.58), .init("🥜", 0.54, 0.82, 35, -15, 0.56),
        .init("🥝", 0.03, 0.68, 35, 13, 0.56), .init("🍪", 0.97, 0.68, 35, -14, 0.56),
        .init("🍲", 0.72, 0.84, 36, 11, 0.56), .init("🍄", 0.28, 0.27, 36, -11, 0.56),
        .init("🍈", 0.15, 0.36, 34, 9, 0.52), .init("🍐", 0.85, 0.36, 34, -9, 0.52),
        .init("🍑", 0.02, 0.15, 34, -13, 0.52), .init("🍋", 0.98, 0.15, 34, 13, 0.52),
        .init("🍍", 0.02, 0.79, 34, 14, 0.52), .init("🥑", 0.98, 0.79, 34, -14, 0.52),
        .init("🫘", 0.26, 0.28, 33, 15, 0.50), .init("🫑", 0.74, 0.28, 33, -15, 0.50),
        .init("🧅", 0.27, 0.76, 33, -12, 0.50), .init("🧄", 0.73, 0.76, 33, 12, 0.50),
        .init("🥨", 0.38, 0.32, 32, -10, 0.48), .init("🥯", 0.62, 0.32, 32, 10, 0.48),
        .init("🧇", 0.38, 0.74, 32, 12, 0.48), .init("🧁", 0.62, 0.74, 32, -12, 0.48),
        .init("🍜", 0.64, 0.32, 33, 10, 0.48), .init("🍛", 0.36, 0.74, 33, -10, 0.48),
        .init("🍵", 0.64, 0.93, 33, -12, 0.48), .init("🧃", 0.36, 0.11, 33, 12, 0.48),
        .init("🍘", 0.33, 0.10, 30, -12, 0.44), .init("🍡", 0.67, 0.10, 30, 12, 0.44),
        .init("🍧", 0.33, 0.92, 30, 13, 0.44), .init("🍨", 0.67, 0.92, 30, -13, 0.44),
        .init("🍯", 0.20, 0.46, 30, 15, 0.42), .init("🌰", 0.80, 0.46, 30, -15, 0.42),
        .init("🥬", 0.47, 0.18, 30, 10, 0.42), .init("🫛", 0.53, 0.83, 30, -10, 0.42),
        .init("🍴", 0.08, 0.61, 30, -16, 0.40), .init("☕", 0.92, 0.60, 30, 16, 0.40),
        .init("🥐", 0.10, 0.34, 28, 12, 0.40), .init("🥖", 0.90, 0.34, 28, -12, 0.40),
        .init("🫓", 0.14, 0.72, 28, -14, 0.40), .init("🥩", 0.86, 0.72, 28, 14, 0.40),
        .init("🍤", 0.23, 0.08, 28, -10, 0.38), .init("🥚", 0.77, 0.08, 28, 10, 0.38),
        .init("🥘", 0.23, 0.92, 28, 13, 0.38), .init("🥧", 0.43, 0.13, 28, 12, 0.36),
        .init("🍮", 0.57, 0.88, 28, -12, 0.36), .init("🍭", 0.60, 0.12, 28, -15, 0.36),
        .init("🍬", 0.40, 0.89, 28, 15, 0.36), .init("🍫", 0.71, 0.46, 28, 11, 0.36),
        .init("🍿", 0.29, 0.46, 28, -11, 0.36), .init("🧂", 0.49, 0.92, 28, 14, 0.35)
    ]

    var body: some View {
        ZStack {
            Circle().fill(Color(red: 1.0, green: 0.87, blue: 0.38).opacity(0.24)).frame(width: 14, height: 14).position(x: 178, y: 184)
            Circle().fill(Color(red: 0.96, green: 0.56, blue: 0.47).opacity(0.21)).frame(width: 16, height: 16).position(x: 478, y: 307)
            Circle().fill(Color(red: 0.56, green: 0.80, blue: 0.38).opacity(0.20)).frame(width: 18, height: 18).position(x: 833, y: 164)
            Circle().fill(Color(red: 0.52, green: 0.76, blue: 0.89).opacity(0.18)).frame(width: 16, height: 16).position(x: 1175, y: 410)
            Circle().fill(Color(red: 1.0, green: 0.75, blue: 0.34).opacity(0.20)).frame(width: 16, height: 16).position(x: 314, y: 717)
            Circle().fill(Color(red: 0.72, green: 0.64, blue: 0.93).opacity(0.18)).frame(width: 18, height: 18).position(x: 943, y: 809)

            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Text(item.symbol)
                    .font(.system(size: item.size * 0.58))
                    .frame(width: item.size, height: item.size)
                    .background(Color(red: 1.0, green: 0.99, blue: 0.94).opacity(0.76), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.76), lineWidth: 3))
                    .shadow(color: Color(red: 0.44, green: 0.33, blue: 0.16).opacity(0.10), radius: 10, y: 5)
                    .opacity(item.opacity)
                    .rotationEffect(.degrees(item.rotation))
                    .position(x: item.x * StageMetrics.width, y: item.y * StageMetrics.height)
            }
        }
    }
}

private struct FoodSprinkle {
    let symbol: String
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let rotation: Double
    let opacity: Double

    init(_ symbol: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, _ rotation: Double, _ opacity: Double) {
        self.symbol = symbol
        self.x = x
        self.y = y
        self.size = size
        self.rotation = rotation
        self.opacity = opacity
    }
}

private struct GrassLayer: View {
    var body: some View {
        ZStack {
            GrassMounds()
                .fill(Color(red: 0.50, green: 0.79, blue: 0.37).opacity(0.74))
                .frame(width: StageMetrics.width * 1.08, height: 145)
                .position(x: StageMetrics.width / 2, y: StageMetrics.height + 4)

            GrassMounds()
                .fill(Color(red: 0.62, green: 0.84, blue: 0.46).opacity(0.34))
                .frame(width: StageMetrics.width * 1.08, height: 110)
                .position(x: StageMetrics.width / 2, y: StageMetrics.height - 4)
                .blur(radius: 1)
        }
    }
}

private struct GrassMounds: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        let centers: [(CGFloat, CGFloat, CGFloat)] = [
            (0.09, 0.72, 42), (0.18, 0.56, 56), (0.30, 0.72, 40), (0.82, 0.54, 55), (0.91, 0.67, 46)
        ]
        for mound in centers {
            let center = CGPoint(x: rect.width * mound.0, y: rect.height * mound.1)
            path.addEllipse(in: CGRect(x: center.x - mound.2, y: center.y - mound.2, width: mound.2 * 2, height: mound.2 * 2))
        }
        return path
    }
}

private struct BuntingView: View {
    private let colors = [
        Color(red: 0.57, green: 0.84, blue: 0.47),
        Color(red: 0.96, green: 0.62, blue: 0.62),
        Color(red: 1.0, green: 0.87, blue: 0.35),
        Color(red: 0.55, green: 0.78, blue: 0.91),
        Color(red: 1.0, green: 0.71, blue: 0.36)
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color(red: 0.40, green: 0.68, blue: 0.33).opacity(0.55))
                .frame(width: 250, height: 5)
                .position(x: 125, y: 2)

            ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                FlagShape()
                    .fill(color)
                    .overlay(FlagShape().stroke(Color.white.opacity(0.34), lineWidth: 2))
                    .frame(width: 46, height: 64)
                    .position(x: CGFloat(index) * 48 + 23, y: 34)
            }
        }
        .frame(width: 250, height: 92)
        .rotationEffect(.degrees(-24))
    }
}

private struct FlagShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.origin)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

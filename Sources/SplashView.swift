import SwiftUI

struct SplashView: View {
    var onFinish: () -> Void
    @State private var logoIn = false
    @State private var textIn = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RadialGradient(colors: [Color(red: 0.06, green: 0.22, blue: 0.13), .black],
                           center: .center, startRadius: 40, endRadius: 520)
                .ignoresSafeArea()

            VStack(spacing: 26) {
                Image("OLKMLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 190, height: 190)
                    .scaleEffect(logoIn ? 1 : 0.72)
                    .opacity(logoIn ? 1 : 0)
                    .shadow(color: Color(red: 0.19, green: 0.78, blue: 0.43).opacity(0.55), radius: 40)

                VStack(spacing: 8) {
                    Text("MOUSTACHE 工作室")
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(.white.opacity(0.92))
                    Text("出品")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .tracking(6)
                        .foregroundStyle(.white.opacity(0.45))
                }
                .opacity(textIn ? 1 : 0)
                .offset(y: textIn ? 0 : 12)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) { logoIn = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.5)) { textIn = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { onFinish() }
        }
    }
}

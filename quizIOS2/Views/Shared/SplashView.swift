import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.indigo, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image("SplashLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

                Text("Я Знаю")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                ProgressView()
                    .tint(.white)
            }
        }
    }
}

#Preview {
    SplashView()
}

import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.indigo, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 68))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse)

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


import SwiftUI

struct DashboardView: View {
    var body: some View {
        NavigationStack {
            Text("ダッシュボード")
                .navigationTitle("今日")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

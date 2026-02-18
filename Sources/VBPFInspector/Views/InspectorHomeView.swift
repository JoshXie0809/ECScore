import SwiftUI
import ECScore

struct InspectorHomeView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass.circle.fill")
                .resizable()
                .frame(width: 50, height: 50)
                .foregroundColor(.accentColor)
            
            Text("VBPF Inspector")
                .font(.title)
                        
            InspectorComponentsTable()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
}

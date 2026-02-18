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
            
            Button("執行 ECScore 檢查") {
                print("檢查中...")
                // 試著獲取 resource
                guard let world = InspectorDelegate.shared?.world else {
                    fatalError("cannot get world @InspectorHomeView")
                }
                let hwToken = interop(world.resources, HelloWorld.self)

                view(base: world.resources, with: hwToken) {
                    _, resHelloWorld in

                    if(resHelloWorld.specialId == "josh") {
                        print(resHelloWorld.val)
                    }

                }
                
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
}

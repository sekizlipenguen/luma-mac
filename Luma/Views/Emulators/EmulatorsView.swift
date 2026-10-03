import SwiftUI

struct EmulatorsView: View {
    var model: EmulatorsViewModel

    var body: some View {
        ScrollView {
            RunningEmulatorsCard(model: model)
                .padding(20)
                .frame(maxWidth: 920, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Simulators")
    }
}

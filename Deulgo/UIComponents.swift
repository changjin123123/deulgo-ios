import SwiftUI

enum DeulgoStyle {
    static let green = Color(red: 0.16, green: 0.40, blue: 0.32)
    static let cream = Color(red: 0.93, green: 0.95, blue: 0.89)
}

struct PrimaryAction: View {
    let title: String
    var icon = "arrow.right"
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack { Text(title).fontWeight(.semibold); Spacer(); Image(systemName: icon) }
                .padding(17).foregroundStyle(.white).background(DeulgoStyle.green, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain)
    }
}

struct LocalModeNote: View {
    var body: some View {
        Label("기기 테스트 · 저장한 요청은 다른 사람에게 공개되지 않아요", systemImage: "iphone")
            .font(.caption).foregroundStyle(.secondary)
    }
}

struct OptionalNumberField: View {
    let title: String
    let unit: String
    @Binding var value: Double?
    @State private var input = ""
    @State private var editing = false
    @FocusState private var focused: Bool
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("몰라요", text: $input)
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).focused($focused)
                .frame(minWidth: 70, maxWidth: 130)
                .onChange(of: input) { _, text in
                    guard editing else { return }
                    let clean = text.trimmingCharacters(in: .whitespaces)
                    value = clean.isEmpty ? nil : Double(clean.replacingOccurrences(of: ",", with: ".")) ?? .nan
                }
                .onChange(of: focused) { _, next in editing = next }
                .onAppear { sync() }
                .onChange(of: value) { _, _ in if !focused { sync() } }
            Text(unit).foregroundStyle(.secondary).font(.caption)
        }
    }
    private func sync() {
        guard let value, value.isFinite else { input = ""; return }
        input = value.formatted(.number.grouping(.never).precision(.fractionLength(0...2)))
    }
}

struct ToolSelection: View {
    @Binding var selected: Set<String>
    var body: some View {
        ForEach(TransportTools.all, id: \.0) { key, title in
            Toggle(title, isOn: Binding(get: { selected.contains(key) }, set: { if $0 { selected.insert(key) } else { selected.remove(key) } }))
        }
    }
}

struct AddressSummary: View {
    let title: String
    let address: DeliveryAddress
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(address.line.isEmpty ? "주소 미입력" : address.line).font(.subheadline.weight(.medium))
            if !address.detail.isEmpty { Text(address.detail).font(.caption).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    func appMessage(_ message: Binding<AppMessage?>) -> some View {
        alert(item: message) { item in Alert(title: Text(item.title), message: Text(item.text), dismissButton: .default(Text("확인"))) }
    }
}

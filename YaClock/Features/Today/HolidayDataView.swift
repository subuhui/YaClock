import SwiftUI
import UniformTypeIdentifiers

struct HolidayDataDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw HolidayImportError.invalidData }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct HolidayDataView: View {
    @Environment(AppContainer.self) private var container
    @State private var datasets = HolidayProvider.datasets
    @State private var importing = false
    @State private var exporting = false
    @State private var message: String?
    @State private var document: HolidayDataDocument?

    var body: some View {
        Form {
            Section("已覆盖年份") {
                ForEach(datasets.sorted { $0.year < $1.year }, id: \.year) { dataset in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(String(dataset.year)) 年 · \(dataset.days.count) 条记录").font(.headline)
                        Text("数据更新：\(dataset.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                            .foregroundStyle(.secondary)
                        Text(dataset.source).font(.footnote).textSelection(.enabled)
                        if let url = URL(string: dataset.source), ["https", "http"].contains(url.scheme) {
                            Link("查看来源", destination: url)
                        }
                    }
                }
            }
            Section {
                Button("导入节假日更新（JSON）") { importing = true }
                Button("导出数据格式示例") {
                    do {
                        let encoder = JSONEncoder()
                        encoder.dateEncodingStrategy = .iso8601
                        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                        document = HolidayDataDocument(data: try encoder.encode(HolidayProvider.builtIn))
                        exporting = true
                    } catch { message = error.localizedDescription }
                }
            } footer: {
                Text("按年导入完整数据，替换同年份的旧数据，保留其他年份。请核对来源；导入后立即重新安排闹钟。缺失年份按普通星期规则处理，首页会提示。")
            }
            if let message { Section { Text(message) } }
        }
        .navigationTitle("节假日数据")
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            Task {
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    try HolidayProvider.importData(Data(contentsOf: url))
                    datasets = HolidayProvider.datasets
                    try await container.refreshUseCase.execute()
                    message = "节假日数据已更新，闹钟已同步。"
                } catch { message = "更新失败：\(error.localizedDescription)" }
            }
        }
        .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "holidays-2026") { result in
            switch result {
            case .success: message = "格式示例已导出。"
            case .failure(let error): message = error.localizedDescription
            }
        }
    }
}

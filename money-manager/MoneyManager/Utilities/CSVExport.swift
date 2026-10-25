import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// Shareable CSV backup of all transactions.
struct CSVExport: Transferable {
    let csv: String

    init(records: [TransactionRecord]) {
        let formatter = ISO8601DateFormatter()
        let header = "date,type,category,merchant,note,amount"
        let lines = records.map { record in
            [
                formatter.string(from: record.date),
                record.kind.rawValue,
                record.category.rawValue,
                Self.escape(record.merchant),
                Self.escape(record.note),
                "\(record.amount)",
            ].joined(separator: ",")
        }
        csv = ([header] + lines).joined(separator: "\n")
    }

    private static func escape(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { Data($0.csv.utf8) }
            .suggestedFileName("transactions.csv")
    }
}

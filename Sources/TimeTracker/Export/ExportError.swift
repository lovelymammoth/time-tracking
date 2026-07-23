import Foundation

enum ExportError: Error, LocalizedError {
    case zipFailed
    case cannotCreatePDF

    var errorDescription: String? {
        switch self {
        case .zipFailed:
            return "Failed to create the Excel (.xlsx) file."
        case .cannotCreatePDF:
            return "Failed to create the PDF document."
        }
    }
}

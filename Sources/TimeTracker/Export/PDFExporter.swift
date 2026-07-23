import Foundation
import AppKit

enum PDFExporter {
    static func export(client: Client, entries: [TimeEntry], projects: [Project], to url: URL) throws {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let consumer = CGDataConsumer(url: url as CFURL),
              let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw ExportError.cannotCreatePDF
        }

        let margin: CGFloat = 40
        let columnX: [CGFloat] = [margin, margin + 80, margin + 220, margin + 300, margin + 400]
        let rowHeight: CGFloat = 18

        func projectName(_ id: UUID) -> String {
            projects.first(where: { $0.id == id })?.name ?? "Unknown"
        }

        let dateFormatter: DateFormatter = {
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
        }()
        let timeFormatter: DateFormatter = {
            let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
        }()

        func formatDuration(_ seconds: Double) -> String {
            let total = Int(seconds)
            let h = total / 3600
            let m = (total % 3600) / 60
            return String(format: "%dh %02dm", h, m)
        }

        func drawText(_ text: String, at point: CGPoint, font: NSFont, color: NSColor = .black) {
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            NSAttributedString(string: text, attributes: attrs).draw(at: point)
        }

        func drawLine(from: CGPoint, to: CGPoint) {
            ctx.setStrokeColor(NSColor.gray.cgColor)
            ctx.setLineWidth(0.5)
            ctx.move(to: from)
            ctx.addLine(to: to)
            ctx.strokePath()
        }

        var y: CGFloat = 0

        func startPage() {
            ctx.beginPDFPage(nil)
            y = pageHeight - margin
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

            drawText("Time Report — \(client.name)", at: CGPoint(x: margin, y: y), font: .boldSystemFont(ofSize: 18))
            y -= 26
            drawText("Generated \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))", at: CGPoint(x: margin, y: y), font: .systemFont(ofSize: 10), color: .gray)
            y -= 24

            let headers = ["Date", "Project", "Start", "Duration", "Notes"]
            for (i, h) in headers.enumerated() {
                drawText(h, at: CGPoint(x: columnX[i], y: y), font: .boldSystemFont(ofSize: 11))
            }
            y -= 6
            drawLine(from: CGPoint(x: margin, y: y), to: CGPoint(x: pageWidth - margin, y: y))
            y -= rowHeight
        }

        func endPage() {
            NSGraphicsContext.restoreGraphicsState()
            ctx.endPDFPage()
        }

        let sorted = entries.sorted { $0.startTime < $1.startTime }
        let total = entries.reduce(0) { $0 + $1.durationSeconds }

        startPage()

        if sorted.isEmpty {
            drawText("No entries in this period.", at: CGPoint(x: margin, y: y), font: .systemFont(ofSize: 12), color: .gray)
            y -= rowHeight
        }

        for entry in sorted {
            if y < margin + 40 {
                endPage()
                startPage()
            }
            let row = [
                dateFormatter.string(from: entry.date),
                projectName(entry.projectId),
                timeFormatter.string(from: entry.startTime),
                formatDuration(entry.durationSeconds),
                entry.notes
            ]
            for (i, value) in row.enumerated() {
                drawText(value, at: CGPoint(x: columnX[i], y: y), font: .systemFont(ofSize: 10))
            }
            y -= rowHeight
        }

        if y < margin + 40 {
            endPage()
            startPage()
        }
        y -= 6
        drawLine(from: CGPoint(x: margin, y: y), to: CGPoint(x: pageWidth - margin, y: y))
        y -= rowHeight
        drawText("Total: \(formatDuration(total))", at: CGPoint(x: margin, y: y), font: .boldSystemFont(ofSize: 12))

        endPage()
        ctx.closePDF()
    }
}

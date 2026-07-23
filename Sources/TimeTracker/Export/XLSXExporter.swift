import Foundation

enum XLSXExporter {
    static func export(client: Client, entries: [TimeEntry], projects: [Project], to url: URL) throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try write(contentTypesXML, to: tempDir.appendingPathComponent("[Content_Types].xml"))

        let relsDir = tempDir.appendingPathComponent("_rels")
        try FileManager.default.createDirectory(at: relsDir, withIntermediateDirectories: true)
        try write(rootRelsXML, to: relsDir.appendingPathComponent(".rels"))

        let xlDir = tempDir.appendingPathComponent("xl")
        try FileManager.default.createDirectory(at: xlDir, withIntermediateDirectories: true)
        try write(workbookXML, to: xlDir.appendingPathComponent("workbook.xml"))
        try write(stylesXML, to: xlDir.appendingPathComponent("styles.xml"))

        let xlRelsDir = xlDir.appendingPathComponent("_rels")
        try FileManager.default.createDirectory(at: xlRelsDir, withIntermediateDirectories: true)
        try write(workbookRelsXML, to: xlRelsDir.appendingPathComponent("workbook.xml.rels"))

        let worksheetsDir = xlDir.appendingPathComponent("worksheets")
        try FileManager.default.createDirectory(at: worksheetsDir, withIntermediateDirectories: true)
        try write(sheetXML(client: client, entries: entries, projects: projects), to: worksheetsDir.appendingPathComponent("sheet1.xml"))

        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = tempDir
        process.arguments = ["-r", "-X", url.path, "."]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw ExportError.zipFailed }
    }

    private static func write(_ content: String, to url: URL) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func xmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
         .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static let columnLetters = ["A", "B", "C", "D", "E"]

    private static var contentTypesXML: String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
        <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
        </Types>
        """
    }

    private static var rootRelsXML: String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """
    }

    private static var workbookXML: String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets>
        <sheet name="Time Report" sheetId="1" r:id="rId1"/>
        </sheets>
        </workbook>
        """
    }

    private static var workbookRelsXML: String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
        <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        </Relationships>
        """
    }

    private static var stylesXML: String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <fonts count="2">
        <font><sz val="11"/><name val="Calibri"/></font>
        <font><b/><sz val="11"/><name val="Calibri"/></font>
        </fonts>
        <fills count="1"><fill><patternFill patternType="none"/></fill></fills>
        <borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
        <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
        <cellXfs count="2">
        <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
        <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
        </cellXfs>
        </styleSheet>
        """
    }

    private static func sheetXML(client: Client, entries: [TimeEntry], projects: [Project]) -> String {
        func projectName(_ id: UUID) -> String {
            projects.first(where: { $0.id == id })?.name ?? "Unknown"
        }
        let dateFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f
        }()
        let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return f
        }()

        var rows = ""
        let headers = ["Date", "Project", "Start Time", "Duration (hours)", "Notes"]
        rows += "<row r=\"1\">"
        for (i, header) in headers.enumerated() {
            rows += "<c r=\"\(columnLetters[i])1\" t=\"inlineStr\" s=\"1\"><is><t>\(xmlEscape(header))</t></is></c>"
        }
        rows += "</row>"

        var rowNum = 2
        var total: Double = 0
        for entry in entries.sorted(by: { $0.startTime < $1.startTime }) {
            let hours = entry.durationSeconds / 3600.0
            total += hours
            rows += "<row r=\"\(rowNum)\">"
            rows += "<c r=\"A\(rowNum)\" t=\"inlineStr\"><is><t>\(xmlEscape(dateFormatter.string(from: entry.date)))</t></is></c>"
            rows += "<c r=\"B\(rowNum)\" t=\"inlineStr\"><is><t>\(xmlEscape(projectName(entry.projectId)))</t></is></c>"
            rows += "<c r=\"C\(rowNum)\" t=\"inlineStr\"><is><t>\(xmlEscape(timeFormatter.string(from: entry.startTime)))</t></is></c>"
            rows += "<c r=\"D\(rowNum)\" t=\"n\"><v>\(String(format: "%.2f", hours))</v></c>"
            rows += "<c r=\"E\(rowNum)\" t=\"inlineStr\"><is><t>\(xmlEscape(entry.notes))</t></is></c>"
            rows += "</row>"
            rowNum += 1
        }

        rows += "<row r=\"\(rowNum)\">"
        rows += "<c r=\"A\(rowNum)\" t=\"inlineStr\" s=\"1\"><is><t>Total</t></is></c>"
        rows += "<c r=\"D\(rowNum)\" t=\"n\"><v>\(String(format: "%.2f", total))</v></c>"
        rows += "</row>"

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <sheetData>
        \(rows)
        </sheetData>
        </worksheet>
        """
    }
}

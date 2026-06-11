import Foundation

/// タイムカード画面（monthly_individual_working_list）の HTML から当日の打刻状態を読み取る。
/// レコーダーの localStorage 履歴と違い、サーバー側の正データなので
/// IC カードやスマホなど他経路の打刻も反映される。
public enum TimecardParser {
    public enum ParseError: Error, Equatable {
        case todayRowNotFound
    }

    /// - Parameters:
    ///   - html: タイムカード画面の HTML
    ///   - dayStamp: `YYYYMMDD`（RecorderStateEngine.dayStamp の形式）
    public static func state(html: String, dayStamp: String) throws -> RecorderState {
        let monthDay = "\(dayStamp.dropFirst(4).prefix(2))/\(dayStamp.suffix(2))"
        guard let row = todayRow(html: html, monthDay: monthDay) else {
            throw ParseError.todayRowNotFound
        }

        let clockIns = times(in: row, sortIndex: "START_TIMERECORD")
        let clockOuts = times(in: row, sortIndex: "END_TIMERECORD")
        let restStarts = times(in: row, sortIndex: "REST_START_TIMERECORD")
        let restEnds = times(in: row, sortIndex: "REST_END_TIMERECORD")

        var records: [RecorderState.PunchRecord] = []
        func add(_ action: PunchAction, _ hhmmList: [String]) {
            for hhmm in hhmmList {
                let digits = hhmm.replacingOccurrences(of: ":", with: "")
                records.append(.init(action: action, timestamp: dayStamp + digits + "00"))
            }
        }
        add(.clockIn, clockIns)
        add(.clockOut, clockOuts)
        add(.breakStart, restStarts)
        add(.breakEnd, restEnds)
        // RecorderState の慣例（新しい順）に合わせる。
        // タイムカードは分単位なので、同時刻は「退勤 < 休始 < 休終 < 出勤」の順で
        // 後に起きたとみなす（退勤と再出勤が同じ分でも勤務中と判定されるように）。
        func tieRank(_ action: PunchAction) -> Int {
            switch action {
            case .clockOut: return 0
            case .breakStart: return 1
            case .breakEnd: return 2
            case .clockIn: return 3
            }
        }
        records.sort {
            ($0.timestamp, tieRank($0.action)) > ($1.timestamp, tieRank($1.action))
        }

        return RecorderState(
            isClockedIn: !clockIns.isEmpty,
            isClockedOut: !clockOuts.isEmpty,
            onBreak: restStarts.count > restEnds.count,
            todayRecords: records
        )
    }

    /// 日付セル（class に specific-sidemenu_date を持つ）ごとに行を区切り、
    /// 当日の日付（例: `06/11（木）`）を含む行のセル群を返す。
    private static func todayRow(html: String, monthDay: String) -> String? {
        let parts = html.components(separatedBy: "specific-sidemenu_date")
        guard parts.count > 1 else { return nil }
        for part in parts.dropFirst() {
            // 日付はセル冒頭付近に現れる
            let head = part.prefix(300)
            if head.contains("\(monthDay)（") || head.contains("\(monthDay)(") {
                return part
            }
        }
        return nil
    }

    /// `data-ht-sort-index="<sortIndex>"` のセルから時刻（HH:MM）を抽出する。
    /// セル内には「編」などの注記や複数時刻（複数回休憩）が混在しうる。
    private static func times(in row: String, sortIndex: String) -> [String] {
        guard let cellStart = row.range(of: "data-ht-sort-index=\"\(sortIndex)\""),
              let cellEnd = row.range(of: "</td>", range: cellStart.upperBound..<row.endIndex) else {
            return []
        }
        let cell = String(row[cellStart.upperBound..<cellEnd.lowerBound])
        let regex = try! NSRegularExpression(pattern: #"(\d{1,2}):(\d{2})"#)
        let matches = regex.matches(in: cell, range: NSRange(cell.startIndex..., in: cell))
        return matches.compactMap { match in
            guard let hourRange = Range(match.range(at: 1), in: cell),
                  let minuteRange = Range(match.range(at: 2), in: cell),
                  let hour = Int(cell[hourRange]) else { return nil }
            return String(format: "%02d:%@", hour, String(cell[minuteRange]))
        }
    }
}

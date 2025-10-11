import SwiftUI
import Charts
import Pulse

@available(iOS 17, *)
public struct NetworkChartView: View {
    @EnvironmentObject var listViewModel: ConsoleListViewModel

    var requests: [NetworkTaskEntity] {
        listViewModel.entities.compactMap { entity in
            switch LoggerEntity(entity) {
            case .message:
                return nil
            case .task(let task):
                return task
            }
        }
    }
    
    let rowHeight: CGFloat = 10
    let lineHeight: CGFloat = 12
    
    public var body: some View {
        Chart(Array(zip(requests.indices, requests)), id: \.1) { index, task in
            if task.hasMetrics {
                RequestRow(task: task, index: index, height: rowHeight, showAnnotation: true)
            }
        }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: 3) // seconds
        .frame(height: CGFloat(requests.count) * lineHeight)
        .chartYAxis(.hidden)
//        .chartXAxis {
//            AxisMarks(values: .stride(by: .second, count: 4)) { value in
//                if let date = value.as(Date.self) {
//                    let second = Calendar.current.component(.second, from: date)
//                    
//                    AxisValueLabel {
//                        Text(date, format: .dateTime.second())
//                    }
//                    
//                    if second == 0 {
//                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
//                        AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
//                    } else {
//                        AxisGridLine()
//                        AxisTick()
//                    }
//                }
//            }
//        }
    }
}

@available(iOS 17, *)
struct RequestRow: ChartContent {
    let task: NetworkTaskEntity

    let index: Int
    let height: CGFloat
    let showAnnotation: Bool
    
    var body: some ChartContent {
        Plot {
            ForEach(task.sortedTransactions, id: \.self) { metrics in
                if let fetchStart = metrics.fetchStartDate, let connectStart = metrics.connectStartDate {
                    BarMark(xStart: .value("Start", fetchStart),
                            xEnd: .value("End", connectStart),
                            y: .value("Index", index),
                            height: .fixed(height))
                    .foregroundStyle(.purple)
                }
                
                if let connectStart = metrics.connectStartDate, let connectEnd = metrics.connectEndDate {
                    BarMark(xStart: .value("Start", connectStart),
                            xEnd: .value("End", connectEnd),
                            y: .value("Index", index),
                            height: .fixed(height))
                    .foregroundStyle(.orange)
                }
                
                if let waitStart = metrics.requestEndDate, let waitEndEnd = metrics.responseStartDate {
                    BarMark(xStart: .value("Start", waitStart),
                            xEnd: .value("End", waitEndEnd),
                            y: .value("Index", index),
                            height: .fixed(height))
                    .foregroundStyle(.gray)
                }
                
                if let requestStart = metrics.responseStartDate, let responseEnd = metrics.responseEndDate {
                    BarMark(xStart: .value("Start", requestStart),
                            xEnd: .value("End", responseEnd),
                            y: .value("Index", index),
                            height: .fixed(height))
                    .foregroundStyle(task.statusCode == 200 ? .green : .red)
                }
            }
        }
        .annotation(position: .trailing, alignment: .center) {
            if showAnnotation, let description = task.chartDescription  {
                Text(description)
                    .font(.system(size: 6))
            } else {
                EmptyView()
            }
        }

    }
}

extension NetworkTaskEntity {
    var chartDescription: String? {
        guard let url = originalRequest?.url, let url = URL(string: url) else { return nil }
        
        return String(format: "%@, %.3f",
                      url.path,
                      duration)
    }
    var duration: TimeInterval {
        if transactions.isEmpty {
            return 0
        }
        
        let sorted = sortedTransactions
        
        guard let start = sorted.first!.fetchStartDate,
              let end = sorted.last?.responseEndDate else {
            return 0
        }
        
        return end.timeIntervalSince(start)
    }
    
    var sortedTransactions: [NetworkTransactionMetricsEntity] {
        Array(transactions).sorted { lhs, rhs in
            guard let start1 = lhs.fetchStartDate,
                  let start2 = rhs.fetchStartDate else {
                return false
            }
            
            return start1 < start2
        }
    }
}

//@available(iOS 17, *)
//#Preview {
//    ContentView()
//}


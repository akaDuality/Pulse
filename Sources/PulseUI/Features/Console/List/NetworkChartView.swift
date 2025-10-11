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
    
    let rowHeight: CGFloat = 14
    let lineHeight: CGFloat = 18
    
    public var body: some View {
        Chart(Array(zip(requests.indices, requests)), id: \.1) { index, task in
            if task.hasMetrics {
                RequestRow(task: task, index: index, height: rowHeight, showAnnotation: true)
            }
        }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: 1) // seconds
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
    var transactions: [NetworkTransactionMetricsEntity] {
        Array(task.transactions)
    }
    let index: Int
    let height: CGFloat
    let showAnnotation: Bool
    
    var body: some ChartContent {
        Plot {
            ForEach(transactions, id: \.self) { metrics in
                if let fetchStart = metrics.fetchStartDate {
                    BarMark(xStart: .value("Start", fetchStart),
                            xEnd: .value("End", metrics.connectStartDate ?? .now),
                            y: .value("Index", index),
                            height: .fixed(height))
                    .foregroundStyle(.purple)
                }
                
                if let connectStart = metrics.connectStartDate {
                    BarMark(xStart: .value("Start", connectStart),
                            xEnd: .value("End", metrics.connectEndDate ?? .now),
                            y: .value("Index", index),
                            height: .fixed(height))
                    .foregroundStyle(.orange)
                }
                
                if let waitStart = metrics.requestEndDate {
                    BarMark(xStart: .value("Start", waitStart),
                            xEnd: .value("End",  metrics.responseStartDate ?? .now),
                            y: .value("Index", index),
                            height: .fixed(height))
                    .foregroundStyle(.gray)
                }
                
                if let requestStart = metrics.responseStartDate {
                    BarMark(xStart: .value("Start", requestStart),
                            xEnd: .value("End", metrics.responseEndDate ?? .now),
                            y: .value("Index", index),
                            height: .fixed(height))
                    .foregroundStyle(task.statusCode == 200 ? .green : .red)
                }
            }
        }
        .annotation(position: .trailing, alignment: .center) {
            if showAnnotation, let url = task.originalRequest!.url  {
                Text("\(URL(string: url)?.path() ?? url), \(transactions.last!.responseEndDate!.timeIntervalSince1970 - transactions.first!.fetchStartDate!.timeIntervalSince1970)")
                    .font(.caption2)
            } else {
                EmptyView()
            }
        }

    }
}

//@available(iOS 17, *)
//#Preview {
//    ContentView()
//}


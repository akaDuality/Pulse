import SwiftUI
import Charts
import Pulse

let rowHeight: CGFloat = 10
let space: CGFloat = 4
var lineHeight: CGFloat {
    rowHeight + space
}

let chartLength = 3

@available(iOS 17, *)
public struct NetworkChartView: View {
    @EnvironmentObject var listViewModel: ConsoleListViewModel

    let intervalToBatch: TimeInterval = 10
    
    var groups: [GroupBatch] {
        let all: [NetworkTaskEntity] = listViewModel.entities.compactMap { entity in
            switch LoggerEntity(entity) {
            case .message:
                return nil
            case .task(let task):
                return task
            }
        }
        
        print("Tasks count \(all.count)")
        
        var groups = [GroupBatch]()
        
        for task in all {
            if
                let lastGroup = groups.last,
                let lastGroupEndDate = lastGroup.tasks.last?.orderedTransactions.last?.responseEndDate,
                let taskFetchStart = task.orderedTransactions.first?.fetchStartDate,
                lastGroupEndDate.timeIntervalSince(taskFetchStart) < intervalToBatch
            {
                print("append to count \(lastGroup.tasks.count)")
                lastGroup.tasks.append(task)
            } else {
                print("create")
                let newGroup = GroupBatch(id: task.taskId, task: task)
                groups.append(newGroup)
            }
        }
        print("Groups count \(groups.count)\n")
        return groups
    }

    @State var shownGroup: GroupBatch?
    
    public var body: some View {
        VStack {
            HStack {
                Button("Previous", systemImage: "chevron.left") {
                    shownGroup = groups.first // TODO: move to prev
                }
                
                Text("\(groups.count)")
                
                Button("Next", systemImage: "chevron.right") {
                    shownGroup = groups.last // TODO: Move to next
                }
            }
            .labelsHidden()
           
            ForEach(groups) { group in
                if group.id == shownGroup?.id {
                    BatchChart(group: group)
                } else {
                    Text("Select group")
                        .onAppear {
                            if shownGroup == nil {
                                shownGroup = groups.first
                            }
                        }
                    
                }
            }
        }
    }
}

@available(iOS 17, *)
struct BatchChart: View {
    let group: GroupBatch

    var body: some View {
        Chart(Array(zip(group.tasks.indices, group.tasks)), id: \.1) { index, task in
            if task.hasMetrics {
                RequestRow(task: task, index: index, height: rowHeight, showAnnotation: true)
            }
        }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: chartLength) // seconds
//        .frame(height: CGFloat(group.tasks.count) * lineHeight)
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


class GroupBatch: Identifiable {
    let id: UUID
    var tasks: [NetworkTaskEntity]
    
    init(id: UUID, task: NetworkTaskEntity) {
        self.id = id
        self.tasks = [task]
    }
}


@available(iOS 17, *)
struct RequestRow: ChartContent {
    let task: NetworkTaskEntity
    let viewModel: TimingViewModel
    let index: Int
    let height: CGFloat
    let showAnnotation: Bool
    
    init(task: NetworkTaskEntity, index: Int, height: CGFloat, showAnnotation: Bool) {
        self.task = task
        self.viewModel = TimingViewModel(task: task, relativeToTask: false)
        self.index = index
        self.height = height
        self.showAnnotation = showAnnotation
    }
    
    var body: some ChartContent {
        Plot {
            ForEach(viewModel.sections) { section in
                ForEach(section.items) { item in
                    if item.title != "Total" { // Total is hiding everything on chart
                        BarMark(xStart: .value("Start", Date(timeIntervalSince1970: item.start)),
                                xEnd: .value("End", Date(timeIntervalSince1970: item.start + item.duration)),
                                y: .value("Index", index),
                                height: .fixed(height))
                        .foregroundStyle(Color(item.color))
                    }
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
        
        let sorted = orderedTransactions
        
        guard let start = sorted.first!.fetchStartDate,
              let end = sorted.last?.responseEndDate else {
            return 0
        }
        
        return end.timeIntervalSince(start)
    }
}

//@available(iOS 17, *)
//#Preview {
//    ContentView()
//}


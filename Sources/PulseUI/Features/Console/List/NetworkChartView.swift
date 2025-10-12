import SwiftUI
import Charts
import Pulse


let chartLength = 3

@available(iOS 17, *)
public struct NetworkChartView: View {
    @EnvironmentObject var listViewModel: ConsoleListViewModel

    let intervalToBatch: TimeInterval = 10
    
    @State private var groups: [GroupBatch] = []

    @State var shownGroup: GroupBatch?
    var currentGroupIndex: Int {
        groups.firstIndex { group in
            group.id == shownGroup?.id
        } ?? 0
    }
    
    public var body: some View {
        VStack {
            if let shownGroup {
                BatchChart(group: shownGroup)
                    .frame(minHeight: 100)
            } else {
                Button("Reload") {
                    shownGroup = groups.first
                }
            }
            
            navigationButtons
        }
        .onChange(of: listViewModel.entities) { newValue in
            groups = recalculateGroups()
            
            if shownGroup == nil {
                shownGroup = groups.last
            }
        }
    }
    
    @ViewBuilder
    var navigationButtons: some View {
        if groups.count > 1 {
            HStack {
                Button(action:  {
                    let prevIndex = currentGroupIndex - 1
                    if prevIndex >= 0 {
                        shownGroup = groups[prevIndex]
                    }
                }, label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 100, height: 30)
                })
                .disabled(currentGroupIndex == 0)
                
                Text("\(currentGroupIndex+1)/\(groups.count)")
                
                Button(action:  {
                    let nextIndex = currentGroupIndex + 1
                    if nextIndex < groups.count {
                        shownGroup = groups[nextIndex]
                    }
                }, label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 100, height: 30)
                })
                .disabled(currentGroupIndex == groups.count - 1)
            }
        } else {
            EmptyView()
        }
    }
    
    
    func recalculateGroups() -> [GroupBatch] {
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
}

@available(iOS 17, *)
struct BatchChart: View {
    let group: GroupBatch
    
    let rowHeight: CGFloat = 10
    let space: CGFloat = 4
    var lineHeight: CGFloat {
        rowHeight + space
    }

    var body: some View {
        Chart(Array(zip(group.tasks.indices, group.tasks)), id: \.1) { index, task in
            if task.hasMetrics {
                RequestRow(task: task, index: index, height: rowHeight, showAnnotation: true)
            }
        }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: chartLength) // seconds
        .frame(height: CGFloat(group.tasks.count) * lineHeight + 50) // 50 for time ticks
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


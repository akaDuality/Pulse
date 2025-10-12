import SwiftUI
import Charts
import Pulse


let chartLength = 3

@available(iOS 17, *)
public struct NetworkChartView: View {
    @EnvironmentObject var listViewModel: ConsoleListViewModel

    let intervalToBatch: TimeInterval = 10
    
//    @State private var groups: [GroupBatch] = []
    @State private var datesToScroll: [Date] = []

    @State var shownGroup: GroupBatch?
    var currentGroupIndex: Int {
        guard !datesToScroll.isEmpty else { return 0 }
        
        let current = currentScrollPosition
        var closestIndex = 0
        var smallestDifference = abs(datesToScroll[0].timeIntervalSince(current))
        for (index, date) in datesToScroll.enumerated() {
            let difference = abs(date.timeIntervalSince(current))
            if difference < smallestDifference {
                smallestDifference = difference
                closestIndex = index
            }
        }
        return closestIndex
    }
    
    @State private var currentScrollPosition: Date = Date()
    
    public var body: some View {
        VStack {
            if let shownGroup {
                BatchChart(group: shownGroup)
                    .frame(minHeight: 100)
                    .chartScrollPosition(x: $currentScrollPosition)
            } else {
//                Button("Reload") {
//                    shownGroup = groups.first
//                }
                Text("Waiting for network data...")
            }
            
            navigationButtons
        }
        .onChange(of: listViewModel.entities) { newValue in
            datesToScroll = recalculateGroups()
            shownGroup = GroupBatch(id: UUID(), tasks: listViewModel.entities.onlyNetworks)
            
//            if shownGroup == nil {
//                shownGroup = groups.last
//            }
        }
    }
    
    func scroll(to groupIndex: Int) {
        withAnimation {
            currentScrollPosition = datesToScroll[groupIndex]
        }
    }
    
    @ViewBuilder
    var navigationButtons: some View {
        if datesToScroll.count > 1 {
            HStack {
                Button(action:  {
                    let prevIndex = currentGroupIndex - 1
                    if prevIndex >= 0 {
                        scroll(to: prevIndex)
                    }
                    
                }, label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 100, height: 30)
                })
//                .disabled(currentGroupIndex == 0)
                
                Text("\(currentGroupIndex+1)/\(datesToScroll.count)")
                
                Button(action:  {
                    let nextIndex = currentGroupIndex + 1
                    if nextIndex < datesToScroll.count {
                        scroll(to: nextIndex)
                    }
                }, label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 100, height: 30)
                })
//                .disabled(currentGroupIndex == datesToScroll.count - 1)
            }
        } else {
            EmptyView()
        }
    }
    
    func recalculateGroups() -> [Date] {
        let all: [NetworkTaskEntity] = listViewModel.entities.onlyNetworks
        
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
        return groups.compactMap { $0.tasks.first?.orderedTransactions.first?.fetchStartDate }
    }
}

import CoreData
extension Array where Element == NSManagedObject {
    var onlyNetworks: [NetworkTaskEntity] {
        compactMap { entity in
            switch LoggerEntity(entity) {
            case .message:
                return nil
            case .task(let task):
                return task
            }
        }
    }
}

@available(iOS 17, *)
struct BatchChart: View {
    let group: GroupBatch
    
    let rowHeight: CGFloat = 10
    let space: CGFloat = 2
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
        .chartXAxis {
            AxisMarks(values: .stride(by: .second, count: 4)) { value in
                if let date = value.as(Date.self) {
                    let second = Calendar.current.component(.second, from: date)
                    
                    AxisValueLabel {
                        Text(date, format: .dateTime.second())
                    }
                    
                    if second == 0 {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                    } else {
                        AxisGridLine()
                        AxisTick()
                    }
                }
            }
        }
    }
}


class GroupBatch: Identifiable {
    let id: UUID
    var tasks: [NetworkTaskEntity]
    
    init(id: UUID, task: NetworkTaskEntity) {
        self.id = id
        self.tasks = [task]
    }
    
    init(id: UUID, tasks: [NetworkTaskEntity]) {
        self.id = id
        self.tasks = tasks
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
        self.viewModel = TimingViewModel(task: task, relativeToTask: false) // TODO: Set true for single response and remove plot for them
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


import CoreData
import Pulse
import Combine
import SwiftUI

@available(iOS 17, visionOS 1, *)
struct ChartView: View {
    @EnvironmentObject var environment: ConsoleEnvironment
    @EnvironmentObject var filters: ConsoleFiltersViewModel
    
    var body: some View {
        _InternalChartView(environment: environment, filters: filters)
    }
}

@available(iOS 17, visionOS 1, *)
private struct _InternalChartView: View {
    private let environment: ConsoleEnvironment
    
    @StateObject private var listViewModel: IgnoringUpdates<ConsoleListViewModel>
    @StateObject private var searchBarViewModel: ConsoleSearchBarViewModel
    @StateObject private var searchViewModel: IgnoringUpdates<ConsoleSearchViewModel>
    
    init(environment: ConsoleEnvironment, filters: ConsoleFiltersViewModel) {
        self.environment = environment
        
        let listViewModel = ConsoleListViewModel(environment: environment, filters: filters)
        let searchBarViewModel = ConsoleSearchBarViewModel()
        let searchViewModel = ConsoleSearchViewModel(environment: environment, source: listViewModel, searchBar: searchBarViewModel)
        
        _listViewModel = StateObject(wrappedValue: IgnoringUpdates(listViewModel))
        _searchBarViewModel = StateObject(wrappedValue: searchBarViewModel)
        _searchViewModel = StateObject(wrappedValue: IgnoringUpdates(searchViewModel))
    }
    
    var body: some View {
        contents
            .environmentObject(listViewModel.value)
            .environmentObject(searchViewModel.value)
            .environmentObject(searchBarViewModel)
            .onAppear { listViewModel.value.isViewVisible = true }
            .onDisappear { listViewModel.value.isViewVisible = false }
    }
    
    @ViewBuilder private var contents: some View {
        NetworkChartView()
//            .searchable(text: $searchBarViewModel.text)
//            .textInputAutocapitalization(.never)
//            .onSubmit(of: .search, searchViewModel.value.onSubmitSearch)
//            .disableAutocorrection(true)
    }
}


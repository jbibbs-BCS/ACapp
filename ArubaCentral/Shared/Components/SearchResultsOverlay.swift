import SwiftUI

struct SearchResultsOverlay: View {
    @ObservedObject var viewModel: GlobalSearchViewModel
    var onSelect: (SearchResult) -> Void

    var body: some View {
        switch viewModel.results {
        case .idle:
            EmptyView()
        case .loading:
            HStack {
                ProgressView()
                Text("Searching…").foregroundColor(.secondary)
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(radius: 4)
            .padding(.horizontal)
        case .loaded(let results) where results.isEmpty:
            HStack {
                Image(systemName: "magnifyingglass")
                Text("No results for \"\(viewModel.query)\"").foregroundColor(.secondary)
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(radius: 4)
            .padding(.horizontal)
        case .loaded(let results):
            List(results) { result in
                Button {
                    onSelect(result)
                } label: {
                    HStack {
                        Image(systemName: result.systemImage)
                            .foregroundColor(.accentColor)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.displayName).font(.body)
                            Text(result.siteName).font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.insetGrouped)
            .frame(maxHeight: 320)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(radius: 6)
            .padding(.horizontal)
        case .error(let err):
            HStack {
                Image(systemName: "exclamationmark.triangle")
                Text(err.userMessage).foregroundColor(.secondary)
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(radius: 4)
            .padding(.horizontal)
        }
    }
}

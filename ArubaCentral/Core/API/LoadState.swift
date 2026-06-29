enum LoadState<T> {
    case idle
    case loading
    case loaded(T)
    case error(APIError)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var value: T? {
        if case .loaded(let v) = self { return v }
        return nil
    }

    var error: APIError? {
        if case .error(let e) = self { return e }
        return nil
    }
}

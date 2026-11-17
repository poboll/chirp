/// Failed requests retry promptly, then back off to at most one retry per minute.
struct RetryBackoff {
    private var delay: Double = 5
    mutating func nextDelay() -> Double {
        let current = delay
        delay = min(delay * 2, 60)
        return current
    }
    mutating func reset() { delay = 5 }
}

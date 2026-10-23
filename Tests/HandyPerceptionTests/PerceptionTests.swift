import Testing

/// The tests that drive Vision or Core ML run one at a time: run in parallel they compete for the
/// Neural Engine and GPU, and the frameworks then fail requests at random (OSStatus -12905).
@Suite(.serialized) struct PerceptionTests {}

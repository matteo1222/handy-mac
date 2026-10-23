# Debt ledger

Every lint suppression in the code is listed here with a reason. `make verify` runs
`scripts/check-debt.py`, which fails when a suppression is missing from this table or a row
no longer matches a suppression.

| File | Rule | Reason |
| --- | --- | --- |
| Sources/HandyPerception/CameraCapture.swift | nonisolated_unsafe | CMSampleBuffer is not Sendable; the AVFoundation callback runs on the worker actor's own serial queue and the buffer is used synchronously inside it |
| Sources/HandyPerception/PalmDetector.swift | no_unchecked_sendable | The palm detector's MLModel, its crop buffer and the camera frame are not Sendable; they are used only on the detector's serial queue, the frame stays alive in its CVPixelBuffer retain, and the results cross back under an NSLock |

# Debt ledger

Every lint suppression in the code is listed here with a reason. `make verify` runs
`scripts/check-debt.py`, which fails when a suppression is missing from this table or a row
no longer matches a suppression.

| File | Rule | Reason |
| --- | --- | --- |
| Sources/HandyPerception/CameraCapture.swift | nonisolated_unsafe | CMSampleBuffer is not Sendable; the AVFoundation callback runs on the worker actor's own serial queue and the buffer is used synchronously inside it |

/// Whether exactly one face is currently visible in the proctoring feed.
/// Deliberately does **not** have a `noCamera` value the way the old
/// app's equivalent enum did — camera-unavailability is a distinct,
/// permanent condition (see [ProctoringEvent]'s `CameraUnavailableEvent`),
/// not just another momentary attention state a grace period could apply
/// to.
enum AttentionStatus { noFace, attentive, multipleFaces }

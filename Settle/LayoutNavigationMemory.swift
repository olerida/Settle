import Foundation

struct LayoutNavigationMemory<Target: Equatable> {
    private var targetGroupsByLayoutID: [UUID: [[Target]]] = [:]

    var rememberedLayoutIDs: Set<UUID> {
        Set(targetGroupsByLayoutID.keys)
    }

    func contains(layoutID: UUID) -> Bool {
        targetGroupsByLayoutID[layoutID]?.isEmpty == false
    }

    func targets(for layoutID: UUID) -> [Target] {
        targetGroupsByLayoutID[layoutID]?.last ?? []
    }

    func targetGroups(for layoutID: UUID) -> [[Target]] {
        targetGroupsByLayoutID[layoutID] ?? []
    }

    func contains(layoutID: UUID, targetGroup: [Target]) -> Bool {
        targetGroupsByLayoutID[layoutID]?.contains(where: { groupsOverlap($0, targetGroup) }) == true
    }

    mutating func remember(layoutID: UUID, targets: [Target]) {
        guard !targets.isEmpty else {
            forget(layoutID: layoutID)
            return
        }
        var groups = targetGroupsByLayoutID[layoutID] ?? []
        groups.removeAll { groupsOverlap($0, targets) }
        groups.append(targets)
        targetGroupsByLayoutID[layoutID] = groups
    }

    mutating func forget(layoutID: UUID) {
        targetGroupsByLayoutID.removeValue(forKey: layoutID)
    }

    mutating func forget(layoutID: UUID, targetGroup: [Target]) {
        guard var groups = targetGroupsByLayoutID[layoutID] else { return }
        groups.removeAll { groupsOverlap($0, targetGroup) }
        if groups.isEmpty {
            targetGroupsByLayoutID.removeValue(forKey: layoutID)
        } else {
            targetGroupsByLayoutID[layoutID] = groups
        }
    }

    mutating func retainLayouts(withIDs layoutIDs: Set<UUID>) {
        targetGroupsByLayoutID = targetGroupsByLayoutID.filter { layoutIDs.contains($0.key) }
    }

    mutating func removeAll() {
        targetGroupsByLayoutID.removeAll()
    }

    private func groupsOverlap(_ lhs: [Target], _ rhs: [Target]) -> Bool {
        lhs.contains { target in rhs.contains(target) }
    }
}

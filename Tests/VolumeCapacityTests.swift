import Foundation

@main
struct VolumeCapacityTests {
    static func main() {
        precondition(VolumeCapacity(total: 1000, available: 100, importantAvailable: 350).estimatedReclaimable == 250)
        precondition(VolumeCapacity(total: 1000, available: 100, importantAvailable: 100).estimatedReclaimable == 0)
        precondition(VolumeCapacity(total: 1000, available: 100, importantAvailable: nil).estimatedReclaimable == nil)
        precondition(VolumeCapacity(total: 1000, available: 100, importantAvailable: 99).estimatedReclaimable == nil)
        precondition(VolumeCapacity(total: 1000, available: 100, importantAvailable: 1001).estimatedReclaimable == nil)
        precondition(VolumeCapacity(total: 1000, available: 1001, importantAvailable: 1001).estimatedReclaimable == nil)
        precondition(VolumeCapacity.read(at: URL(fileURLWithPath: "/private/tmp/foldersize-missing-2e9250/item")) == nil)
        print("Volume capacity checks passed")
    }
}

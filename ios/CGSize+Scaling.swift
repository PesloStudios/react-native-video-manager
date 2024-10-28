import Foundation

struct BoundsFitResult {
    let size: CGSize
    let scale: CGFloat
}

extension CGSize {
    var doubled: CGSize {
        CGSize(width: self.width * 2, height: self.height * 2)
    }
    var halfed: CGSize {
        CGSize(width: self.width * 0.5, height: self.height * 0.5)
    }

    func boundsThatFit(parent: CGSize) -> BoundsFitResult {
        let ownAspectRatio = self.width / self.height
        let parentAspectRatio = parent.width / parent.height

        guard ownAspectRatio != parentAspectRatio else {
            // If the two aspect ratios match, then we know the parent size is an exact fit.
            return BoundsFitResult(
                size: parent,
                scale: parent.width / self.width
            )
        }

        if ownAspectRatio < parentAspectRatio {
            // fit by height
            let scale = parent.height / self.height
            return BoundsFitResult(
                size: CGSize(width: self.width * scale, height: parent.height),
                scale: scale
            )
        }

        let scale = parent.width / self.width

        return BoundsFitResult(
            size: CGSize(width: parent.width, height: self.height * scale),
            scale: scale
        )
    }
}

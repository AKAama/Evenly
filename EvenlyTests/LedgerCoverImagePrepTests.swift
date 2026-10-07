import XCTest
import UIKit
@testable import Evenly

@MainActor
final class LedgerCoverImagePrepTests: XCTestCase {
    func testHighDensityImageIsLimitedByPixels() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1600, height: 1600), format: format).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1600, height: 1600))
        }
        let data = try XCTUnwrap(LedgerCoverImagePrep.jpegData(from: image))
        let cover = try XCTUnwrap(UIImage(data: data)?.cgImage)
        XCTAssertEqual(cover.height, 1200)
        XCTAssertEqual(cover.width, 800)
        XCTAssertLessThan(data.count, 5 * 1024 * 1024)
    }

    func testCameraOrientationIsAppliedBeforeCropping() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let base = UIGraphicsImageRenderer(size: CGSize(width: 1800, height: 1200), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 900, height: 1200))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 900, y: 0, width: 900, height: 1200))
        }
        let rotated = UIImage(cgImage: try XCTUnwrap(base.cgImage), scale: 1, orientation: .right)
        let data = try XCTUnwrap(LedgerCoverImagePrep.jpegData(from: rotated))
        let result = try XCTUnwrap(UIImage(data: data))
        XCTAssertEqual(result.imageOrientation, .up)
        let pixels = try XCTUnwrap(result.cgImage)
        XCTAssertLessThanOrEqual(max(pixels.width, pixels.height), 1200)
        XCTAssertEqual(Double(pixels.width) / Double(pixels.height), 2.0 / 3.0, accuracy: 0.002)
    }

    func testCropNeverExposesBlankEdgesAtAnyZoomOrDrag() {
        let viewport = CGSize(width: 200, height: 300)
        for imageSize in [CGSize(width: 400, height: 300), CGSize(width: 100, height: 600)] {
            for zoom: CGFloat in [0.5, 1, 2, 4, 8] {
                for offset in [CGSize(width: 10_000, height: -10_000), CGSize(width: -10_000, height: 10_000), .zero] {
                    let frame = LedgerCoverCrop.imageFrame(imageSize: imageSize, viewport: viewport, zoom: zoom, offset: offset)
                    XCTAssertLessThanOrEqual(frame.minX, 0.001)
                    XCTAssertLessThanOrEqual(frame.minY, 0.001)
                    XCTAssertGreaterThanOrEqual(frame.maxX, viewport.width - 0.001)
                    XCTAssertGreaterThanOrEqual(frame.maxY, viewport.height - 0.001)
                }
            }
        }
    }

    func testSavedCropUsesTheSelectedPosition() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 300))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 200, y: 0, width: 200, height: 300))
        }
        for x: CGFloat in [-100, 100] {
            let result = LedgerCoverCrop.render(image: image, viewport: CGSize(width: 200, height: 300),
                                               zoom: 1, offset: CGSize(width: x, height: 0))
            let cgImage = try XCTUnwrap(result.cgImage)
            XCTAssertEqual(cgImage.width, 800)
            XCTAssertEqual(cgImage.height, 1200)
            let context = try XCTUnwrap(CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8,
                                                 bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            let pixel = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
            if x > 0 { XCTAssertGreaterThan(pixel[0], pixel[2]) }
            else { XCTAssertGreaterThan(pixel[2], pixel[0]) }
        }
    }

}

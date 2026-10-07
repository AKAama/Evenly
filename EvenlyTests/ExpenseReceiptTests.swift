import XCTest
import UIKit
@testable import Evenly

@MainActor
final class ExpenseReceiptTests: XCTestCase {
    func testReceiptKeepsEntireImageAndLimitsPixelSize() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let source = UIGraphicsImageRenderer(size: CGSize(width: 2400, height: 1200), format: format).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2400, height: 1200))
        }
        let data = try XCTUnwrap(ReceiptImagePrep.jpegData(from: source))
        let result = try XCTUnwrap(UIImage(data: data)?.cgImage)
        XCTAssertEqual(result.width, 1600)
        XCTAssertEqual(result.height, 800)
        XCTAssertLessThanOrEqual(data.count, 5 * 1024 * 1024)
    }

    func testPortraitPhotoOrientationIsAppliedWithoutCropping() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let source = UIGraphicsImageRenderer(size: CGSize(width: 1800, height: 1200), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1800, height: 1200))
        }
        let rotated = UIImage(cgImage: try XCTUnwrap(source.cgImage), scale: 1, orientation: .right)
        let result = try XCTUnwrap(UIImage(data: XCTUnwrap(ReceiptImagePrep.jpegData(from: rotated))))
        XCTAssertEqual(result.imageOrientation, .up)
        XCTAssertEqual(result.size.width / result.size.height, 2.0 / 3.0, accuracy: 0.002)
        XCTAssertEqual(max(result.size.width, result.size.height), 1600)
    }

    func testReceiptURLsSurviveCacheButLocalImagesAreNotCached() throws {
        let person = Person(name: "Owner", userId: UUID().uuidString)
        var expense = Expense(title: "Receipt", amount: 20, payer: person, participants: [person],
                              receiptURLs: ["https://example.com/receipts/image.jpg"])
        expense.receiptUploadData = [Data([1, 2, 3])]
        let cached = try JSONEncoder().encode(expense)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: cached) as? [String: Any])
        XCTAssertNil(json["receiptUploadData"])
        let restored = try JSONDecoder().decode(Expense.self, from: cached)
        XCTAssertEqual(restored.receiptURLs, expense.receiptURLs)
        XCTAssertNil(restored.receiptUploadData)
        var legacy = json
        legacy.removeValue(forKey: "receiptURLs")
        let legacyExpense = try JSONDecoder().decode(Expense.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertNil(legacyExpense.receiptURLs)
    }

    func testAPIResponseWithAndWithoutReceipts() throws {
        var json: [String: Any] = [
            "id": UUID().uuidString, "ledger_id": UUID().uuidString,
            "payer_id": UUID().uuidString, "created_by": UUID().uuidString,
            "title": "Invoice", "total_amount": "20.00", "status": "pending"
        ]
        let decoder = JSONDecoder()
        let old = try decoder.decode(ExpenseResponse.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(old.receiptURLs)
        json["receipt_urls"] = ["https://example.com/receipts/image.jpg"]
        let new = try decoder.decode(ExpenseResponse.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(new.receiptURLs, ["https://example.com/receipts/image.jpg"])
        let saved = Expense(from: new, participants: [])
        XCTAssertEqual(saved.receiptURLs, new.receiptURLs)
        XCTAssertNil(saved.receiptUploadData)
    }

    func testPrivateReceiptRequestsFreshAuthorizationAndKeepsSignatureIntact() async throws {
        let expenseId = UUID()
        let saved = "https://cos.ismyh.cn/receipts/image.jpg"
        var requests = 0
        for expected in 1...2 {
            let resolved = try await ReceiptImageSource.downloadURL(receiptURL: saved, expenseId: expenseId) { id, receipt in
                XCTAssertEqual(id, expenseId)
                XCTAssertEqual(receipt, saved)
                requests += 1
                return "https://evenly-1325650734.cos.ap-nanjing.myqcloud.com/receipts/image.jpg?q-signature=token\(requests)&q-sign-time=1%3B2"
            }
            XCTAssertEqual(resolved.host, "evenly-1325650734.cos.ap-nanjing.myqcloud.com")
            XCTAssertTrue(resolved.absoluteString.contains("q-signature=token\(expected)"))
            XCTAssertTrue(resolved.absoluteString.contains("q-sign-time=1%3B2"))
        }
        XCTAssertEqual(requests, 2)
    }

    func testReceiptLookupUsesOriginalURLInsteadOfItsPositionInTheEditForm() throws {
        let expenseId = UUID()
        let saved = "https://cos.ismyh.cn/receipts/ledger/user/second-image.jpg"
        let endpoint = APIEndpoints.receiptDownloadURL(expenseId: expenseId, receiptURL: saved)
        let components = try XCTUnwrap(URLComponents(string: endpoint))
        XCTAssertEqual(components.path, "/expenses/\(expenseId.uuidString)/receipts/download-url")
        XCTAssertEqual(components.queryItems, [URLQueryItem(name: "receipt_url", value: saved)])
    }
}

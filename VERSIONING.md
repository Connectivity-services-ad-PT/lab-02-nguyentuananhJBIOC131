# Chiến lược Quản lý Phiên bản API (API Versioning Strategy)
**Nhóm phụ trách:** A1 - IoT Ingestion

## 1. Phương pháp Versioning được lựa chọn
Nhóm A1 quyết định sử dụng phương pháp **URI Path Versioning** (Phiên bản hóa qua đường dẫn URI).
- Cú pháp: `https://api.campus.local/api/v{major}/telemetry`
- Ví dụ hiện tại: `GET /api/v1/telemetry`

**Lý do chọn:**
- Đây là phương pháp phổ biến, trực quan nhất cho người dùng API (Consumer).
- Dễ dàng định tuyến (Routing) thông qua API Gateway dựa trên URL path.
- Khả năng tương thích tốt với các công cụ kiểm thử như Postman, cURL, Swagger.

## 2. Quy tắc thay đổi phiên bản (Semantic Versioning)
Hệ thống Ingestion sẽ tuân thủ nguyên tắc không làm gãy đổ dịch vụ của nhóm khác (Non-breaking changes).

**Thay đổi KHÔNG tăng phiên bản (Non-breaking - Giữ nguyên v1):**
- Thêm endpoint mới (VD: Thêm `/api/v1/device-events`).
- Thêm trường dữ liệu tùy chọn (Optional Fields) vào Payload Response.
- Thêm tham số Query mới (VD: Thêm filter `?sensor_type=` nhưng mặc định là null).

**Thay đổi PHẢI tăng phiên bản (Breaking - Lên v2):**
- Đổi tên trường dữ liệu bắt buộc (VD: Đổi `device_id` thành `sensor_mac_address`).
- Thay đổi cấu trúc JSON lồng nhau (VD: Đưa `temperature` ra ngoài khỏi object `readings`).
- Xóa bỏ một endpoint đang có người sử dụng.

## 3. Chính sách vòng đời (Deprecation Policy)
Khi nhóm A1 phát hành bản `v2`, bản `v1` sẽ không bị tắt ngay lập tức để nhóm A5 (Analytics) có thời gian nâng cấp code.
- **Giai đoạn Deprecated:** API `v1` vẫn hoạt động nhưng Response Header sẽ trả về `Deprecation: true` và `Link: <url-v2>`.
- **Thời gian chuyển đổi:** Duy trì song song cả 2 phiên bản trong vòng **3 tháng**.
- **Giai đoạn Sunset:** Sau 3 tháng, API `v1` sẽ chính thức bị tắt, trả về lỗi `410 Gone`.
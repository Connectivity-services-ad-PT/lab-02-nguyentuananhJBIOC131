# Biên bản đàm phán hợp đồng API

- Cặp đàm phán: Nhóm A1 (IoT Ingestion) đàm phán với Nhóm A5 (Analytics) và Nhóm A6 (Core Business)
- Product: Product A (Smart Campus Operations Platform)
- Provider: Nhóm A1 (cho endpoint `/telemetry`), Nhóm A6 (cho endpoint xác thực devices)
- Consumer: Nhóm A5 (tiêu thụ `/telemetry`), Nhóm A1 (tiêu thụ endpoint từ A6)
- Phiên: v1.0
- Ngày: 27/05/2026

---

## Issue #1

- Raised by: Consumer (Nhóm A5 - Analytics)
- Endpoint: `GET /api/v1/telemetry` (Provider: A1)
- Concern: Nhóm A5 lo ngại việc phải kéo toàn bộ dữ liệu thô (raw data) của hàng ngàn cảm biến sẽ gây nghẽn băng thông và tràn bộ nhớ.
- Proposal: A5 đề xuất A1 hỗ trợ trả về dữ liệu đã được tính toán trung bình (aggregate) theo từng giờ thay vì trả dữ liệu thô từng giây.
- Resolution: **Rejected**
- Rationale: Boundary (phân vùng trách nhiệm) của service IoT Ingestion chỉ là tiếp nhận, chuẩn hóa định dạng và lưu trữ tốc độ cao (high throughput). Việc tính toán tổng hợp (aggregation) thuộc về Domain của dịch vụ Analytics (A5).
- Impact: A5 phải tự xây dựng job để tính toán dữ liệu. A1 sẽ cung cấp cơ chế Cursor-based Pagination để A5 lấy dần dữ liệu thô mà không bị quá tải.

---

## Issue #2

- Raised by: Consumer (Nhóm A1 - IoT Ingestion)
- Endpoint: `POST /api/v1/devices/validate-batch` (Provider: A6 - Core Business)
- Concern: A1 nhận hàng ngàn bản tin mỗi giây. Nếu gọi API kiểm tra trạng thái thiết bị của A6 theo kiểu từng-cái-một (one-by-one) sẽ gây thắt cổ chai mạng (bottleneck).
- Proposal: A1 yêu cầu A6 cung cấp thêm endpoint cho phép validate danh sách nhiều `device_id` cùng lúc (Batch Request).
- Resolution: **Accepted**
- Rationale: Tối ưu hóa network call giữa 2 microservices, giảm độ trễ cho Ingestion.
- Impact: Nhóm A6 sẽ bổ sung thêm một endpoint nhận mảng (array) các `device_id` và trả về danh sách các thiết bị hợp lệ.

---

## Issue #3

- Raised by: Provider (Nhóm A6 - Core Business)
- Endpoint: `GET /api/v1/devices/{id}/status`
- Concern: Nhóm A6 sợ bị sập Database (DDoS nội bộ) nếu A1 gọi API xác thực liên tục mỗi khi có dữ liệu từ cùng một cảm biến đẩy lên.
- Proposal: Nhóm A6 yêu cầu Nhóm A1 phải tự implement cơ chế Cache (bộ nhớ tạm) trạng thái hợp lệ của thiết bị trong ít nhất 10 phút.
- Resolution: **Accepted**
- Rationale: Trạng thái của thiết bị (active/inactive) ít khi thay đổi liên tục. Caching giúp giảm 90% tải cho Core Business.
- Impact: Nhóm A1 đồng ý thêm in-memory cache (Redis) trước khi gọi sang A6.

---

## Issue #4

- Raised by: Provider (Nhóm A1 - IoT Ingestion)
- Endpoint: `GET /api/v1/telemetry`
- Concern: Nếu Consumer (A5) bị lỗi vòng lặp và gọi API liên tục không kiểm soát, Database của A1 có thể bị sập.
- Proposal: A1 áp đặt Rate Limit: tối đa trả về 1000 items/page và giới hạn 20 requests/phút.
- Resolution: **Modified**
- Rationale: Nhóm A5 đồng ý giới hạn 1000 items/page, nhưng xin tăng Rate Limit lên 60 requests/phút để kịp đồng bộ dữ liệu vào giờ cao điểm. A1 đồng ý vì hạ tầng vẫn đáp ứng được.
- Impact: A1 sẽ bổ sung lỗi `429 Too Many Requests` vào file OpenAPI và cấu hình rate limiter.

---

## Issue #5

- Raised by: Consumer (Nhóm A5 - Analytics)
- Endpoint: `GET /api/v1/telemetry`
- Concern: Dữ liệu thời gian (`timestamp`) nếu không thống nhất múi giờ sẽ làm sai lệch toàn bộ biểu đồ báo cáo của hệ thống.
- Proposal: Chốt định dạng chuẩn là Unix Epoch Time (kiểu số nguyên - giây).
- Resolution: **Modified**
- Rationale: Định dạng Epoch rất khó đọc bằng mắt thường khi debug. Cả A1 và A5 thống nhất sử dụng chuẩn ISO 8601 múi giờ UTC (Ví dụ: `2026-05-27T09:30:00Z`).
- Impact: Cập nhật lại file `openapi.yaml`, quy định chặt chẽ `format: date-time` cho field `timestamp`.

---

## Issue #6

- Raised by: Consumer (Nhóm A1 - IoT Ingestion)
- Endpoint: `GET /api/v1/devices/{id}/status` (Provider: A6)
- Concern: Trong trường hợp service Core Business (A6) bị sập hoặc bảo trì, A1 không thể xác thực thiết bị, dẫn đến nguy cơ vứt bỏ nhầm dữ liệu thực tế quan trọng (Data Loss).
- Proposal: Đề xuất cơ chế "Fail Open". Nếu gọi A6 bị Timeout hoặc lỗi 5xx, A1 tạm thời vẫn lưu dữ liệu cảm biến vào DB nội bộ nhưng gắn nhãn `pending_validation`.
- Resolution: **Accepted**
- Rationale: Ưu tiên cao nhất của Ingestion là không được làm mất dữ liệu IoT vật lý. Việc xác thực có thể chạy bù (retry) sau khi A6 hoạt động lại.
- Impact: Nhóm A1 tự xử lý logic nội bộ, không ảnh hưởng đến API contract nhưng là một thỏa thuận quan trọng về tính khả dụng của hệ thống.

---

# Chốt hợp đồng v1.0

Provider sign-off: Nguyễn Tuấn Anh (Nhóm A1)  
Consumer sign-off: Đại diện nhóm A5, Đại diện nhóm A6  
Witness (GV/TA): Giảng viên hướng dẫn FIT4110  
Date: 27/05/2026  

---

## Ghi chú warning nếu Spectral còn cảnh báo

| Warning | Lý do chấp nhận tạm thời | Kế hoạch sửa |
|---|---|---|
| `oas3-unused-component` | Có khai báo component `ErrorResponse` nhưng một số endpoint chưa dùng đến do đang phát triển dần. | Sẽ dọn dẹp hoặc tích hợp vào tất cả endpoint trong Sprint 2. |
| `operation-description` | Một số description hơi dài quá số từ gợi ý của linter. | Giữ nguyên vì cần mô tả chi tiết nghiệp vụ phức tạp cho nhóm Consumer hiểu. |
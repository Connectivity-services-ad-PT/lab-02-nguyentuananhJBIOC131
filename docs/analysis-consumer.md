# Phân tích yêu cầu — vai Consumer

- Cặp đàm phán: Nhóm A1 (Consumer) - Nhóm A6 (Provider)
- Product: Product A
- Consumer service: IoT Ingestion (Nhóm A1)
- Provider service: Core Business (Nhóm A6)
- Người viết: Nguyễn Tuấn Anh
- Ngày: 27/5/2026

---

## 1. Resource Consumer cần nhận/gửi

| Resource | Consumer dùng để làm gì? | Field bắt buộc với Consumer | Field có thể tùy chọn |
|---|---|---|---|
| `DeviceProfile` | Kiểm tra xem thiết bị IoT (sensor) có tồn tại và đang được phép hoạt động (active) hay không trước khi thu thập dữ liệu telemetry. | `device_id`, `status`, `tenant_id` | `location`, `firmware_version` |
| `DeviceConfig` | Lấy cấu hình thu thập dữ liệu của thiết bị (VD: chu kỳ gửi dữ liệu) để xử lý logic validate tần suất gửi. | `device_id`, `reporting_interval` | `thresholds` |

---

## 2. API Consumer cần gọi

| Method | Path | Lúc nào gọi? | Kỳ vọng response |
|---|---|---|---|
| GET | `/api/v1/devices/{device_id}/status` | Khi có thiết bị mới gửi dữ liệu lần đầu, hoặc khi cache thông tin thiết bị tại Ingestion đã hết hạn. | Trả về HTTP 200 OK, kèm body chứa thông tin trạng thái hoạt động của thiết bị. |
| POST | `/api/v1/devices/{device_id}/anomalies` | Khi Ingestion phát hiện luồng dữ liệu của thiết bị có dấu hiệu bất thường (gửi quá nhiều, sai định dạng liên tục). | Trả về HTTP 201 Created (Báo cáo thành công). |

---

## 3. Error case Consumer cần xử lý

Tối thiểu 5 case.
| Status | Consumer hiểu là gì? | Consumer sẽ xử lý thế nào? |
|---:|---|---|
| 400 | Request sai schema | Sửa payload/log lỗi (Không chuyển tiếp dữ liệu rác này). |
| 401 | Thiếu token nội bộ | Cảnh báo hệ thống, cấu hình lại xác thực giữa các service. |
| 404 | Không tìm thấy resource | Hiểu là Thiết bị không tồn tại -> Drop (từ chối) bản tin IoT, ghi log cảnh báo "Thiết bị lạ". |
| 429 | Gửi quá nhiều request (Rate Limit) | Kích hoạt cơ chế Retry có độ trễ (Exponential Backoff) hoặc đọc dữ liệu từ Cache tạm thời. |
| 500 | Lỗi server Provider (Core Business sập) | Kích hoạt Circuit Breaker, tạm thời lưu dữ liệu IoT vào hàng đợi cục bộ (Dead-letter queue) để không làm mất dữ liệu. |
| 422 | Vi phạm rule nghiệp vụ | Hiển thị/Log lý do cụ thể do Provider trả về. |
---

## 4. Giả định bổ sung

- Giả định 1: Dữ liệu trạng thái của thiết bị sẽ được Consumer (IoT Ingestion) lưu vào bộ nhớ đệm (Cache) trong khoảng 5-10 phút để tránh việc cứ mỗi bản tin cảm biến gửi lên lại phải gọi API sang Provider một lần gây nghẽn mạng.
- Giả định 2: Hai service giao tiếp nội bộ với nhau trong cùng một mạng ảo (VPC) thông qua API Gateway nội bộ.
- Giả định 3: Thông tin định danh `device_id` do thiết bị gửi lên là thông tin đáng tin cậy đã được parse từ giao thức MQTT/HTTP.

---

## 5. Câu hỏi cho Provider
---

## 5. Câu hỏi cho Provider

1. API lấy trạng thái thiết bị có hỗ trợ lấy danh sách nhiều thiết bị cùng lúc (Bulk/Batch request) để nhóm A1 tối ưu hiệu năng không?
2. Giới hạn số lượng request (Rate limit) cho các API này là bao nhiêu request/giây để bên A1 thiết lập cơ chế gọi cho phù hợp?
3. Thời gian phản hồi trung bình (Latency) dự kiến của API là bao nhiêu mili-giây để A1 cấu hình Timeout chặn các request treo?

---

## 6. Rủi ro tích hợp

| Rủi ro | Tác động | Đề xuất xử lý |
|---|---|---|
| Provider đổi kiểu dữ liệu | Consumer parse lỗi, làm sập tiến trình thu thập | Chốt type/format/pattern chặt chẽ bằng OpenAPI schema. |
| Provider thiếu mã lỗi | Consumer khó xử lý lỗi | Chuẩn hóa định dạng lỗi trả về theo chuẩn Problem Details (RFC 7807). |
| Provider xử lý chậm (Latency cao) | Consumer bị thắt cổ chai, tồn đọng hàng triệu bản tin IoT chưa xử lý | Bổ sung cơ chế Timeout ngắt kết nối sớm và Circuit Breaker. |
# Phân tích yêu cầu — vai Provider

- Cặp đàm phán: Nhóm A1 (Provider) - Nhóm A5 (Consumer)
- Product: Product A
- Provider service: IoT Ingestion (Nhóm A1)
- Consumer service: Analytics (Nhóm A5)
- Người viết: Nguyễn Tuấn Anh
- Ngày: 27/5/2026

---

## 1. Resource chính

| Resource | Mô tả | Thuộc tính bắt buộc | Thuộc tính tùy chọn |
|---|---|---|---|
| `Telemetry` | Dữ liệu đo đạc thô (nhiệt độ, độ ẩm...) thu thập từ các thiết bị IoT theo thời gian thực. | `device_id`, `timestamp`, `metrics` (chứa các chỉ số) | `location_id`, `battery_level` |
| `DeviceStatus` | Trạng thái kết nối gần nhất của thiết bị (để biết thiết bị đang sống hay chết). | `device_id`, `status` (online/offline), `last_seen` | `firmware_version`, `ip_address` |

---

## 2. Action/API dự kiến

| Method | Path | Mục đích | Consumer gọi khi nào? |
|---|---|---|---|
| GET | `/api/v1/telemetry` | Lấy danh sách lịch sử dữ liệu đo đạc (có hỗ trợ lọc theo thời gian và phân trang). | Khi Analytics cần tổng hợp, vẽ biểu đồ dữ liệu định kỳ (ví dụ: mỗi 1 giờ hoặc cuối ngày). |
| GET | `/api/v1/devices/{id}/status` | Lấy trạng thái hoạt động hiện tại của một thiết bị cụ thể. | Khi Analytics cần kiểm tra xem thiết bị có đang bị mất kết nối dẫn đến thiếu hụt dữ liệu báo cáo hay không. |

---

## 3. Error case

Tối thiểu 5 case.

| Status | Tình huống | Response body dự kiến |
|---:|---|---|
| 400 | Payload/Query sai định dạng (VD: thiếu tham số query `start_time` bắt buộc khi lấy lịch sử). | `Problem` (Chỉ rõ field nào bị thiếu hoặc sai type). |
| 401 | Thiếu Bearer token xác thực giữa các service. | `Problem` (Mã lỗi xác thực). |
| 403 | Token hợp lệ nhưng service Analytics không được cấp quyền truy cập tập dữ liệu của khu vực này. | `Problem` (Báo lỗi Forbidden/Access Denied). |
| 404 | Resource không tồn tại (Không tìm thấy `device_id` trong hệ thống Ingestion). | `Problem` (Báo lỗi Device Not Found). |
| 422 | Dữ liệu đúng chuẩn JSON nhưng vi phạm nghiệp vụ (VD: `start_time` lại lớn hơn `end_time`). | `Problem` (Giải thích rõ logic vi phạm). |
| 429 | Gọi API quá tần suất cho phép (Rate Limit Exceeded). | `Problem` (Yêu cầu chờ thêm X giây). |
---

## 4. Giả định bổ sung

Ghi rõ những điểm user story chưa nói nhưng Provider cần giả định.
- Giả định 1: Dữ liệu thô (Telemetry) lưu tại Ingestion Service có dung lượng rất lớn, nên Provider chỉ lưu trữ tối đa trong **30 ngày**. Nếu Consumer cần phân tích dữ liệu cũ hơn, Consumer phải tự pull về lưu ở Data Warehouse riêng.
- Giả định 2: Consumer (A5) sẽ gọi API theo cơ chế kéo (Pull) định kỳ theo lô (Batch) thay vì gọi liên tục mỗi giây để tránh làm quá tải Database của Ingestion.
- Giả định 3: Định dạng thời gian (`timestamp`) trao đổi giữa 2 bên bắt buộc phải dùng chuẩn chuẩn quốc tế ISO 8601, múi giờ UTC.


---

## 5. Câu hỏi cho Consumer

1. Consumer dự kiến tần suất gọi API `/api/v1/telemetry` là bao nhiêu lần/phút, lượng dữ liệu lấy mỗi lần là bao nhiêu để Provider cấu hình Rate Limit và Pagination cho phù hợp?
2. Consumer muốn nhận dữ liệu gốc (raw) 100% hay cần Provider tính toán trung bình sẵn (aggregate theo phút/giờ) trước khi trả về để giảm băng thông?
3. Đối với các cảnh báo thời gian thực, Consumer có cần Provider hỗ trợ cơ chế Push (đẩy qua Message Broker/Webhook) thay vì gọi API lấy dữ liệu hay không?

---

## 6. Rủi ro tích hợp

| Rủi ro | Tác động | Đề xuất xử lý |
|---|---|---|
| Tên field không thống nhất | Consumer parse lỗi, làm gián đoạn báo cáo. | Chốt naming conventions rõ ràng bằng file `openapi.yaml`. |
| Payload lớn khi truy vấn khoảng thời gian dài | Gây Timeout, nghẽn mạng hoặc sập server. | Bắt buộc sử dụng phân trang (Pagination), giới hạn tối đa trả về 1000 bản ghi/request. |
| Bất đồng bộ thời gian (Timezone) | Sai lệch số liệu thống kê. | Thống nhất content-type và luôn chuẩn hóa thời gian về UTC+0 ở mọi API. |
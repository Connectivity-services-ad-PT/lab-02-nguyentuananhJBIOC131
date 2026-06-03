## Issue đàm phán với Analytics (A5)
- **Raised by:** Provider (Analytics - A5)
- **Endpoint:** Topic `iot.telemetry.ingested`
- **Concern:** Analytics cần nhóm các chỉ số theo từng tòa nhà để vẽ biểu đồ, nhưng payload mặc định của IoT thiếu thông tin vị trí.
- **Proposal:** Nhóm A1 bổ sung trường tùy chọn `zoneId` vào payload sự kiện.
- **Resolution:** Accepted
- **Rationale:** Giúp Analytics tổng hợp dữ liệu theo phân vùng không gian mà không cần truy vấn ngược sang DB của Core Business.
- **Impact:** Nhóm A1 cập nhật schema sinh dữ liệu, thêm trường `zoneId`.

## Issue thống nhất chuẩn định dạng thời gian
- **Concern:** Sai lệch timeline trên biểu đồ thống kê do múi giờ local của cảm biến khác nhau.
- **Proposal:** Trường `occurredAt` (timestamp) bắt buộc dùng ISO 8601, múi giờ UTC (đuôi Z).
- **Resolution:** Accepted
- **Impact:** Nhóm A1 format lại datetime trước khi đẩy event vào Broker.

**Provider sign-off:** Nguyễn Hữu Tuấn Minh (Leader A5)
**Consumer sign-off:** [Nguyễn Tuấn Anh (Leader A1)]

## Cặp đàm phán: Pair 05 — IoT Ingestion (A1/B1) ↔ Core Business (A6/B6)

- **Cơ chế**: Queue async
- **Publisher (Producer)**: IoT Ingestion (A1)
- **Subscriber (Consumer)**: Core Business (A6)
- **Phiên**: v1.0 (Sơ bộ cho Lab 02)
- **Ngày**: 01-06-2026

---

## Issue #1: Tiêu chuẩn hóa hệ thống đơn vị đo lường (Metric Units)

- **Raised by**: Subscriber (Core Business)
- **Endpoint/Event**: `sensor.reading.created` & `sensor.threshold.exceeded`
- **Concern**: IoT Ingestion thu thập dữ liệu từ các cảm biến phần cứng của nhiều hãng sản xuất khác nhau, dẫn tới dữ liệu nhiệt độ có thể là độ Celsius (°C) hoặc Fahrenheit (°F), dữ liệu độ ẩm có thể là tỷ lệ phần trăm (0-100) hoặc số thực (0.0-1.0). Nếu gửi lung tung, Core Business sẽ không thể đánh giá chính xác các chính sách vận hành khẩn cấp trong Policy Engine.
- **Proposal**: Subscriber đề xuất bắt buộc chuẩn hóa toàn bộ giá trị đo lường (`value`) về hệ đo lường quốc tế (SI) cụ thể: `CELSIUS` cho nhiệt độ, `PERCENTAGE` (0.0-100.0) cho độ ẩm/khói, `PASCAL` cho áp suất, và `LUX` cho ánh sáng. Định dạng này phải được ghi nhận rõ trong trường `unit`.
- **Resolution**: Accepted
- **Rationale**: Đảm bảo tính nhất quán tuyệt đối của dữ liệu đầu vào, giúp bộ lọc quy tắc (Policy Engine) của Core Business tính toán nhanh chóng mà không mất tài nguyên convert đơn vị.
- **Impact**:
  - **IoT Ingestion**: Thực hiện chuyển đổi đơn vị ở tầng Gateway/Adapter trước khi đóng gói payload gửi lên hàng đợi.
  - **Core Business**: Định nghĩa Enum cho trường `unit` và xây dựng logic xử lý theo hệ đo lường chuẩn hóa.

---

## Issue #2: Yêu cầu định danh vị trí vật lý (`locationId`)

- **Raised by**: Subscriber (Core Business)
- **Endpoint/Event**: Cả hai sự kiện
- **Concern**: Thiết kế payload ban đầu của IoT Ingestion chỉ chứa `deviceId` và chỉ số đo được. Tuy nhiên, Core Business cần biết cảm biến đó đang được lắp đặt ở phòng học, hành lang hay tầng mấy để kích hoạt các kịch bản an ninh tương ứng (như mở/đóng cửa thoát hiểm của tòa nhà đó khi có cháy). Nếu chỉ có `deviceId`, Core Business sẽ phải truy vấn thêm DB để phân tích vị trí, gây trễ thời gian phản hồi.
- **Proposal**: Subscriber yêu cầu IoT Ingestion đính kèm thuộc tính `locationId` (kiểu chuỗi định danh vị trí) trực tiếp vào trong payload của mỗi sự kiện.
- **Resolution**: Accepted

- **Rationale**: Việc đính kèm `locationId` giúp Core Business xử lý logic tại chỗ (In-memory Rule Processing) cực kỳ nhanh chóng mà không cần thực hiện thêm các thao tác JOIN database đắt đỏ trong luồng realtime khẩn cấp.
- **Impact**:
  - **IoT Ingestion**: Bổ sung cơ chế làm giàu dữ liệu (Data Enrichment) tại tầng Ingestion để đính kèm `locationId` tương ứng với `deviceId` trước khi publish event.
  - **Core Business**: Cập nhật logic xử lý sự kiện để trích xuất trực tiếp `locationId` phục vụ Policy Engine.

---

## Issue #3: Giới hạn độ trễ xử lý thông điệp khẩn cấp (Event TTL)

- **Raised by**: Subscriber (Core Business)
- **Endpoint/Event**: Cả hai sự kiện
- **Concern**: Trong trường hợp Broker bị tắc nghẽn hoặc mất kết nối mạng cục bộ, các thông điệp có thể bị kẹt trong hàng đợi nhiều giờ. Khi mạng thông suốt, broker sẽ tự động đẩy hàng loạt thông điệp cũ lên Consumer. Nếu Core Business xử lý các sự kiện khẩn cấp cũ này (như báo khói cũ cách đây 2 tiếng), nó có thể kích hoạt các cảnh báo giả, hú còi và khóa cửa campus không đúng thời điểm hiện tại.
- **Proposal**: Subscriber đề xuất áp dụng luật TTL (Time-To-Live): Nếu thời gian nhận sự kiện trễ hơn quá **5 phút** so với thời điểm xảy ra sự kiện (`occurredAt`), Core Business sẽ ghi log cảnh báo và bỏ qua việc kích hoạt kịch bản khẩn cấp.
- **Resolution**: Accepted with Modification
- **Rationale**: Bảo vệ hệ thống Smart Campus khỏi các quyết định an ninh sai lệch do dữ liệu cũ (stale data), đồng thời vẫn lưu trữ thông tin phục vụ mục đích kiểm toán (audit log) và phân tích lịch sử sau này.
- **Impact**:
  - **Core Business**: Cấu hình logic lọc sự kiện: So sánh `timestamp_hiện_tại - occurredAt`. Nếu > 300 giây, bỏ qua xử lý Policy Engine, chỉ lưu DB kiểm toán.

---

## Ký kết đồng thuận Pair 05 (v1.0)

- **Publisher sign-off**: Nguyễn Tuấn Anh (Đại diện nhóm A1 IoT Ingestion)
- **Subscriber sign-off**: Nguyễn Thị Hồng Duyên (Đại diện nhóm A6 Core Business)
- **Witness (GV/TA)**: Lê Thái Bảo
- **Date**: 01-06-2026
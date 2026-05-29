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